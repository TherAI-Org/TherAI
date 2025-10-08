import uuid
from fastapi import FastAPI, HTTPException, Depends
from fastapi.responses import StreamingResponse
from starlette.background import BackgroundTask
from starlette.concurrency import iterate_in_threadpool
import json
import traceback
from pydantic import BaseModel
from openai import pydantic_function_tool

from .Models.requests import ChatRequest, ChatResponse, MessagesResponse, MessageDTO, SessionsResponse, SessionDTO
from .Agents.personal import PersonalAgent
from .auth import get_current_user
from .Database.chat_repo import save_message, list_messages_for_session, update_session_last_message, is_session_empty, count_user_messages, get_recent_user_messages
from .Database.link_repo import get_link_status_for_user, get_partner_user_id
from .Database.linked_sessions_repo import get_linked_session_by_relationship_and_source_session
from .Database.session_repo import create_session, list_sessions_for_user, touch_session, assert_session_owned_by_user, update_session_title, delete_session
from .Database.linked_sessions_repo import get_linked_session_by_relationship_and_source_session
from .Routers.aasa_router import router as aasa_router
from .Routers.link_router import router as link_router
from .Routers.partner_router import router as partner_router
from .Routers.profile_router import router as profile_router
from .Routers.relationship_router import router as relationship_router

app = FastAPI()

app.include_router(aasa_router)
app.include_router(link_router)
app.include_router(partner_router)
app.include_router(profile_router)
app.include_router(relationship_router)

personal_agent = PersonalAgent()

# Stream assistant response as Server-Sent Events (SSE)
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

        # Save the user message first
        await save_message(user_id = user_uuid, session_id = session_uuid, role = "user", content = request.message)  # Persist user message
        await update_session_last_message(session_id = session_uuid, content = request.message)  # Update the session's last_message_content for sidebar preview

        # Count how many user messages now exist (after saving this one)
        user_message_count = await count_user_messages(session_id=session_uuid)

        # Generate/regenerate title on 1st and 2nd user messages
        if user_message_count == 1 or user_message_count == 2:
            try:
                # Get recent user messages for context
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

        chat_history_for_agent = None
        if request.chat_history:
            chat_history_for_agent = [
                {"role": msg.role, "content": msg.content}
                for msg in request.chat_history
            ]

        # Get partner's personal chat messages (for enhanced context)
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
                                limit=50
                            )
                            partner_context = partner_messages
                except Exception:
                    partner_context = None
        except Exception as e:
            print(f"Context retrieval warning (stream): {e}")

        # Gets the user_a_id (for labeling and partner message generation)
        try:
            a_id = uuid.UUID(linked_session["user_a_id"]) if linked_session and linked_session.get("user_a_id") else user_uuid  # type: ignore[index]
        except Exception:
            a_id = user_uuid

        # Shared state for background persistence after stream completes
        state = {"final_text": "", "partner_text": None}

        async def persist_stream_results():
            try:
                final_text = (state.get("final_text") or "").strip()
                partner_text_value = (state.get("partner_text") or "")
                if final_text:
                    try:
                        row = await save_message(user_id = user_uuid, session_id = session_uuid, role = "assistant", content = final_text)
                        print(f"[SSE] persist assistant ok id={row.get('id') if isinstance(row, dict) else 'unknown'}")
                    except Exception as e:
                        print(f"[SSE] persist assistant error: {e}")
                if partner_text_value and partner_text_value.strip():
                    try:
                        # Persist a structured annotation (JSON) alongside the assistant content so UI can reliably render the partner block without content markers
                        annotation = json.dumps({"_therai": {"type": "partner_draft", "text": partner_text_value}}, ensure_ascii=False)
                        preview_pd = partner_text_value[:120].replace("\n", " ")
                        print(f"[SSE][persist] saving partner_draft annotation len={len(partner_text_value)} preview={preview_pd!r}")
                        row2 = await save_message(user_id = user_uuid, session_id = session_uuid, role = "assistant", content = annotation)
                        print(f"[SSE] persist partner_draft annotation ok id={row2.get('id') if isinstance(row2, dict) else 'unknown'} role=assistant")
                    except Exception as e:
                        print(f"[SSE] persist partner_draft error: {e}")
            except Exception as e:
                print(f"[SSE] persist task fatal: {e}")

        def iter_sse():
            yield (":" + " " * 2048 + "\n\n").encode()

            sess_payload = json.dumps({"session_id": str(session_uuid)})
            yield f"event: session\ndata: {sess_payload}\n\n".encode()
            print(f"[SSE] /chat session event sent session_id={session_uuid}")

            full_text_parts = []
            final_text = ""
            try:
                # Build input for a single-call flow
                input_messages = [{"role": "system", "content": personal_agent.system_prompt}] if hasattr(personal_agent, "system_prompt") else []
                if chat_history_for_agent:
                    for msg in chat_history_for_agent:
                        role = "user" if msg.get("role") == "user" else "assistant"
                        input_messages.append({"role": role, "content": msg.get("content", "")})
                if partner_context:
                    partner_text = "PARTNER CONTEXT (Partner's recent personal thoughts):\n"
                    for msg in partner_context:
                        role = "Partner" if msg.get("role") == "user" else "AI Assistant to Partner"
                        partner_text += f"{role}: {msg.get('content', '')}\n"
                    input_messages.append({"role": "system", "content": partner_text.strip()})
                input_messages.append({"role": "user", "content": request.message})

                # Function tool schema (per OpenAI Responses function-calling docs)
                # Tool defined using the SDK helper required by Responses API
                class EmitPartnerMessageArgs(BaseModel):
                    text: str

                tools = [
                    pydantic_function_tool(
                        EmitPartnerMessageArgs,
                        name = "emit_partner_message",
                        description = "Emit a clean first-person message to send to the partner. No quotes.",
                    )
                ]

                # Stream model output with tools so function_call can be emitted mid-stream
                print("[SSE] /chat stream start tools_enabled=True")
                partner_text_value = None
                with personal_agent.client.responses.stream(
                    model = personal_agent.model,
                    input = input_messages,
                    tools = tools,
                ) as stream:  # type: ignore[attr-defined]
                    used_iterator = False
                    fc_args_by_item_id = {}
                    event_count = 0
                    tool_start_emitted = False
                    for event in stream:
                        try:
                            ev_type = getattr(event, "type", "")
                            event_count += 1
                            if event_count <= 15:
                                print(f"[SSE] /chat stream ev#{event_count} type={ev_type}")
                            if ev_type.endswith("output_text.delta"):
                                delta = getattr(event, "delta", "") or ""
                                if delta:
                                    used_iterator = True
                                    full_text_parts.append(delta)
                                    yield f"event: token\ndata: {json.dumps(delta)}\n\n".encode()
                            elif ev_type.endswith("output_item.added"):
                                item = getattr(event, "item", None)
                                if item and getattr(item, "type", "") == "function_call":
                                    name = getattr(item, "name", "")
                                    if name == "emit_partner_message":
                                        item_id = getattr(item, "id", None)
                                        if item_id is not None:
                                            fc_args_by_item_id[item_id] = fc_args_by_item_id.get(item_id, "")
                                            print(f"[SSE] /chat tool-call item added id={item_id}")
                                            try:
                                                payload = json.dumps({"name": name})
                                                yield f"event: tool_start\ndata: {payload}\n\n".encode()
                                                tool_start_emitted = True
                                                print("[SSE] /chat tool_start emitted (from output_item.added)")
                                            except Exception:
                                                pass
                            elif ev_type.endswith("function_call.arguments.delta") or ev_type.endswith("function_call_arguments.delta"):
                                item_id = getattr(event, "item_id", None)
                                delta = getattr(event, "delta", "") or ""
                                if item_id is not None and delta:
                                    fc_args_by_item_id[item_id] = fc_args_by_item_id.get(item_id, "") + delta
                                    if len(fc_args_by_item_id[item_id]) % 64 < len(delta):
                                        print(f"[SSE] /chat tool-call args delta id={item_id} len={len(fc_args_by_item_id[item_id])}")
                                    if not tool_start_emitted:
                                        print("[SSE] /chat WARNING: tool args arrived before tool_start was emitted (name may be delayed)")
                                    # Optionally surface arg deltas to client (not required for final UI)
                                    try:
                                        yield f"event: tool_args\ndata: {json.dumps(delta)}\n\n".encode()
                                    except Exception:
                                        pass
                            elif ev_type.endswith("function_call.arguments.done") or ev_type.endswith("function_call_arguments.done") or ev_type.endswith("output_item.done"):
                                item = getattr(event, "item", None)
                                if item and getattr(item, "type", "") == "function_call":
                                    name = getattr(item, "name", "")
                                    if name == "emit_partner_message":
                                        args_str = getattr(item, "arguments", None)
                                        if not args_str:
                                            item_id = getattr(event, "item_id", None)
                                            if item_id is not None:
                                                args_str = fc_args_by_item_id.get(item_id)
                                        if args_str:
                                            try:
                                                parsed = json.loads(args_str) if isinstance(args_str, str) else args_str
                                                text_val = (parsed.get("text") or "").strip()
                                                text_val = text_val.strip('"').strip('“”')
                                                partner_text_value = text_val
                                                try:
                                                    state["partner_text"] = partner_text_value
                                                    preview = partner_text_value[:120].replace("\n", " ")
                                                    print(f"[SSE][tool] partner_message parsed len={len(partner_text_value)} preview={preview!r}")
                                                except Exception:
                                                    pass
                                                yield f"event: partner_message\ndata: {json.dumps(partner_text_value)}\n\n".encode()
                                                try:
                                                    yield b"event: tool_done\ndata: {}\n\n"
                                                except Exception:
                                                    pass
                                                preview = partner_text_value[:120].replace("\n", " ")
                                                print(f"[SSE] /chat partner_message len={len(partner_text_value)} preview={preview!r}")
                                            except Exception as e:
                                                print(f"[SSE] /chat stream function_call parse error: {e}")
                            elif ev_type.endswith("error"):
                                err = getattr(event, "error", None)
                                if err:
                                    yield f"event: error\ndata: {json.dumps(str(err))}\n\n".encode()
                                    print(f"[SSE] /chat stream model-error: {err}")
                            # ignore other event types
                        except Exception:
                            print("[SSE] /chat stream event-handler exception:\n" + traceback.format_exc())
                            continue

                    final = stream.get_final_response()
                    chat_response = getattr(final, "output_text", None) or "".join(full_text_parts)
                    try:
                        streamed_len = sum(len(p) for p in full_text_parts)
                        print(f"[SSE] /chat stream finished streamed_chars={streamed_len} tool_start_emitted={tool_start_emitted} partner_present={(partner_text_value is not None)}")
                    except Exception:
                        pass

                final_text = chat_response
                try:
                    state["final_text"] = final_text or ""
                    if partner_text_value:
                        state["partner_text"] = partner_text_value
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