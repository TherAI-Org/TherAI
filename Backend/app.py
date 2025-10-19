import json
import uuid
import traceback
from fastapi import FastAPI, HTTPException, Depends
from fastapi.responses import StreamingResponse
from starlette.background import BackgroundTask
from starlette.concurrency import iterate_in_threadpool

from .Models.requests import ChatRequest, MessagesResponse, MessageDTO, SessionsResponse, SessionDTO
from .Agents.personal import PersonalAgent
from .auth import get_current_user
from .Database.chat_repo import save_message, list_messages_for_session, update_session_last_message, count_user_messages, get_recent_user_messages
from .Database.link_repo import get_link_status_for_user, get_partner_user_id
from .Database.linked_sessions_repo import get_linked_session_by_relationship_and_source_session
from .Database.session_repo import create_session, list_sessions_for_user, assert_session_owned_by_user, update_session_title, delete_session
from .Database.linked_sessions_repo import get_linked_session_by_relationship_and_source_session
from .Routers.aasa_router import router as aasa_router
from .Routers.link_router import router as link_router
from .Routers.partner_router import router as partner_router
from .Routers.profile_router import router as profile_router
from .Routers.notifications_router import router as notifications_router

app = FastAPI()

app.include_router(aasa_router)
app.include_router(link_router)
app.include_router(partner_router)
app.include_router(profile_router)
app.include_router(notifications_router)

personal_agent = PersonalAgent()

@app.post("/chat/sessions/message/stream")
async def chat_message_stream(request: ChatRequest, current_user: dict = Depends(get_current_user)):
    try:
        try:
            user_uuid = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

        try:
            print(
                f"[SSE] /chat stream REQUEST user={current_user.get('sub')} "
                f"session_in={request.session_id} msg_len={len((request.message or '').strip())} "
                f"history={len(request.chat_history or [])}"
            )
        except Exception:
            print("[SSE] /chat stream REQUEST log-failed")

        if request.session_id is not None:
            try:
                await assert_session_owned_by_user(user_id=user_uuid, session_id=request.session_id)
                session_uuid = request.session_id
            except PermissionError:
                raise HTTPException(status_code = 403, detail = "Forbidden: invalid session")
        else:
            session_row = await create_session(user_id=user_uuid, title=None)
            session_uuid = uuid.UUID(session_row["id"])

        await save_message(user_id = user_uuid, session_id = session_uuid, role = "user", content = request.message)
        await update_session_last_message(session_id = session_uuid, content = request.message)
        user_message_count = await count_user_messages(session_id=session_uuid)

        if user_message_count == 1 or user_message_count == 2:
            try:
                recent_user_messages = await get_recent_user_messages(session_id=session_uuid, limit=2)
                chat_title = personal_agent.generate_chat_title(recent_user_messages)

                if chat_title:
                    await update_session_title(user_id=user_uuid, session_id=session_uuid, title=chat_title)
                    if user_message_count == 1:
                        print(f"[TITLE] Generated initial title for session {session_uuid}: '{chat_title}'")
                    else:
                        print(f"[TITLE] Refined title for session {session_uuid}: '{chat_title}'")
            except Exception as e:
                print(f"[TITLE] Failed to generate chat title: {e}")

        partner_context = None
        linked_session = None
        try:
            linked, relationship_id, _ = await get_link_status_for_user(user_id=user_uuid)
            if linked and relationship_id:
                linked_session = await get_linked_session_by_relationship_and_source_session(relationship_id=relationship_id, source_session_id=session_uuid)
                try:
                    mapped = await get_linked_session_by_relationship_and_source_session(relationship_id=relationship_id, source_session_id=session_uuid)
                    linked_session = mapped if mapped else linked_session
                    partner_session_id_str = None
                    if mapped:
                        cur_id = str(user_uuid)
                        if mapped.get("user_a_id") == cur_id:
                            partner_session_id_str = mapped.get("user_b_personal_session_id")
                        elif mapped.get("user_b_id") == cur_id:
                            partner_session_id_str = mapped.get("user_a_personal_session_id")
                    if partner_session_id_str:
                        partner_user_id = await get_partner_user_id(user_id=user_uuid)
                        if partner_user_id:
                            partner_messages = await list_messages_for_session(
                                user_id=partner_user_id,
                                session_id=uuid.UUID(partner_session_id_str),
                                limit=500
                            )
                            partner_context = partner_messages
                except Exception:
                    partner_context = None
        except Exception as e:
            print(f"Context retrieval warning (stream): {e}")

        try:
            a_id = uuid.UUID(linked_session["user_a_id"]) if linked_session and linked_session.get("user_a_id") else user_uuid
        except Exception:
            a_id = user_uuid

        state = {"final_text": "", "partner_texts": [], "segments": []}

        async def persist_stream_results():
            try:
                final_text = (state.get("final_text") or "").strip()
                partner_texts = state.get("partner_texts") or []
                segments = state.get("segments") or []
                if segments:
                    try:
                        has_partner = any((isinstance(s, dict) and s.get("type") == "partner_draft") for s in segments)
                        if has_partner:
                            annotation_obj = {"_therai": {"type": "segments", "segments": segments}}
                            annotation = json.dumps(annotation_obj, ensure_ascii=False)
                            row_seg = await save_message(user_id = user_uuid, session_id = session_uuid, role = "assistant", content = annotation)
                            print(f"[SSE] persist segments ok id={row_seg.get('id') if isinstance(row_seg, dict) else 'unknown'}")
                            return
                    except Exception as e:
                        print(f"[SSE] persist segments error: {e}")
                if final_text:
                    try:
                        row = await save_message(user_id = user_uuid, session_id = session_uuid, role = "assistant", content = final_text)
                        print(f"[SSE] persist assistant ok id={row.get('id') if isinstance(row, dict) else 'unknown'}")
                    except Exception as e:
                        print(f"[SSE] persist assistant error: {e}")
            except Exception as e:
                print(f"[SSE] persist task fatal: {e}")

        def iter_sse():
            yield (":" + " " * 2048 + "\n\n").encode()

            sess_payload = json.dumps({"session_id": str(session_uuid)})
            yield f"event: session\ndata: {sess_payload}\n\n".encode()
            print(f"[SSE] /chat session event sent session_id={session_uuid}")

            full_text_parts = []
            final_text = ""
            segments_list = []
            current_text_segment = ""
            try:
                input_messages = [{"role": "system", "content": personal_agent.system_prompt}] if hasattr(personal_agent, "system_prompt") else []
                if partner_context:
                    partner_text = "Partner context — treat this as what THEY said; generate a response for the CURRENT USER to send.\n"
                    for msg in partner_context:
                        role = "Partner" if msg.get("role") == "user" else "AI Assistant to Partner"
                        partner_text += f"{role}: {msg.get('content', '')}\n"
                    input_messages.append({"role": "system", "content": partner_text.strip()})
                input_messages.append({
                    "role": "system",
                    "content": "MANDATORY: If you include any message intended for the partner, output it ONLY inside <partner_message>…</partner_message> with 2–3 paragraphs and no duplication outside the tags."
                })
                input_messages.append({"role": "user", "content": request.message})

                print(f"[SSE] /chat stream start (Responses API) model={personal_agent.model}")
                print(f"[SSE] Number of messages: {len(input_messages)}")

                model_to_use = personal_agent.model
                partner_texts: list[str] = []

                resp = personal_agent.client.responses.create(
                    model = model_to_use,
                    input = input_messages,
                    previous_response_id = request.previous_response_id
                )

                # Emit response_id so client can continue chain
                try:
                    rid = getattr(resp, "id", None)
                    if rid:
                        yield f"event: response_id\ndata: {json.dumps({'response_id': rid})}\n\n".encode()
                except Exception:
                    pass

                text = getattr(resp, "output_text", None)
                if not text:
                    parts = []
                    for block in getattr(resp, "output", []) or []:
                        if getattr(block, "type", None) == "output_text" and getattr(block, "text", None):
                            parts.append(block.text)
                    text = "".join(parts)
                text = (text or "")

                import re
                open_pat = re.compile(r"<partner_message(?:\s+[^>]*)?>")
                end_marker = "</partner_message>"
                pos = 0
                n = len(text)

                def stream_tokens(chunk: str):
                    nonlocal current_text_segment
                    if not chunk:
                        return
                    step = 120
                    for i in range(0, len(chunk), step):
                        part = chunk[i:i+step]
                        full_text_parts.append(part)
                        yield f"event: token\ndata: {json.dumps(part)}\n\n".encode()
                        current_text_segment += part

                while True:
                    m = open_pat.search(text, pos)
                    if not m:
                        remaining = text[pos:]
                        for ev in stream_tokens(remaining):
                            yield ev
                        break
                    before = text[pos:m.start()]
                    for ev in stream_tokens(before):
                        yield ev
                    close_idx = text.find(end_marker, m.end())
                    if close_idx == -1:
                        remainder = text[m.start():]
                        for ev in stream_tokens(remainder):
                            yield ev
                        break
                    content = text[m.end():close_idx]
                    partner_texts.append(content)
                    yield f"event: tool_start\ndata: {json.dumps({'name': 'emit_partner_message'})}\n\n".encode()
                    yield f"event: partner_message\ndata: {json.dumps(content)}\n\n".encode()
                    yield b"event: tool_done\ndata: {}\n\n"

                    if current_text_segment:
                        segments_list.append({"type": "text", "content": current_text_segment})
                        current_text_segment = ""
                    segments_list.append({"type": "partner_draft", "text": content})

                    pos = close_idx + len(end_marker)

                final_text = "".join(full_text_parts)
                if current_text_segment:
                    segments_list.append({"type": "text", "content": current_text_segment})
                try:
                    state["final_text"] = final_text or ""
                    if partner_texts:
                        state["partner_texts"] = partner_texts
                    if segments_list:
                        state["segments"] = segments_list
                except Exception:
                    pass

                if not full_text_parts and final_text:
                    yield f"event: token\ndata: {json.dumps(final_text)}\n\n".encode()

                yield b"event: done\ndata: {}\n\n"
                print(f"[SSE] /chat stream done sent for session_id={session_uuid}")
            except Exception as e:
                print(f"[SSE] /chat stream error: {e}\n" + traceback.format_exc())
                yield f"event: error\ndata: {json.dumps(str(e))}\n\n".encode()
            finally:
                print(f"[SSE] /chat stream generator closed session_id={session_uuid}")

        return StreamingResponse(
            iterate_in_threadpool(iter_sse()),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache, no-transform",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
                "Content-Encoding": "identity",
                "Content-Type": "text/event-stream; charset=utf-8",
            },
            background=BackgroundTask(persist_stream_results),
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code = 500, detail = f"Error processing stream: {str(e)}")

# Get messages for a specific session owned by the current user
@app.get("/chat/sessions/{session_id}/messages", response_model = MessagesResponse)
async def get_messages(session_id: uuid.UUID, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    try:
        await assert_session_owned_by_user(user_id=user_uuid, session_id=session_id)
    except PermissionError:
        raise HTTPException(status_code=403, detail="Forbidden: invalid session")

    rows = await list_messages_for_session(user_id = user_uuid, session_id = session_id, limit = 200, offset = 0)
    return MessagesResponse(
        messages=[
            MessageDTO(
                id=uuid.UUID(r["id"]),
                user_id=uuid.UUID(r["user_id"]),
                session_id=uuid.UUID(r["session_id"]),
                role=r["role"],
                content=r["content"],
            )
            for r in rows
        ]
    )

# List chat sessions for the current user
@app.get("/chat/sessions", response_model = SessionsResponse)
async def get_sessions(current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    rows = await list_sessions_for_user(user_id=user_uuid, limit=100, offset=0)

    return SessionsResponse(
        sessions=[
            SessionDTO(
                id=uuid.UUID(r["id"]),
                user_id=uuid.UUID(r["user_id"]),
                title=r.get("title"),
                last_message_at=r.get("last_message_at"),
                last_message_content=r.get("last_message_content"),
            )
            for r in rows
        ]
    )


# Create an empty personal chat session for the current user
@app.post("/chat/sessions", response_model = SessionDTO)
async def create_empty_session(current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    try:
        row = await create_session(user_id=user_uuid, title=None)
        return SessionDTO(
            id=uuid.UUID(row["id"]),
            user_id=user_uuid,
            title=row.get("title"),
        )
    except Exception as e:
        raise HTTPException(status_code = 500, detail = f"Error creating session: {str(e)}")


# Rename a personal chat session
@app.patch("/chat/sessions/{session_id}")
async def rename_session(session_id: uuid.UUID, payload: dict, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    title = payload.get("title")
    if title is not None and not isinstance(title, str):
        raise HTTPException(status_code=400, detail="title must be a string or null")
    try:
        await update_session_title(user_id=user_uuid, session_id=session_id, title=title)
        return {"success": True}
    except PermissionError:
        raise HTTPException(status_code=403, detail="Forbidden: invalid session")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# Delete a personal chat session and its messages; also remove any links
@app.delete("/chat/sessions/{session_id}")
async def delete_session_route(session_id: uuid.UUID, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    try:
        # Verify ownership and delete. DB is responsible for cascading to dependents.
        await assert_session_owned_by_user(user_id=user_uuid, session_id=session_id)
        await delete_session(user_id=user_uuid, session_id=session_id)
        return {"success": True}
    except PermissionError:
        raise HTTPException(status_code=403, detail="Forbidden: invalid session")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))