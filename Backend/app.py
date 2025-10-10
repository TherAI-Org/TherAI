import uuid
from fastapi import FastAPI, HTTPException, Depends
from fastapi.responses import StreamingResponse
from starlette.background import BackgroundTask
from starlette.concurrency import iterate_in_threadpool
import json
import traceback
from pydantic import BaseModel

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
        state = {"final_text": "", "partner_texts": [], "segments": []}

        async def persist_stream_results():
            try:
                final_text = (state.get("final_text") or "").strip()
                partner_texts = state.get("partner_texts") or []
                segments = state.get("segments") or []
                # Prefer saving ordered segments when they include partner drafts
                if segments:
                    try:
                        has_partner = any((isinstance(s, dict) and s.get("type") == "partner_draft") for s in segments)
                        if has_partner:
                            annotation_obj = {"_therai": {"type": "segments", "segments": segments}}
                            annotation = json.dumps(annotation_obj, ensure_ascii=False)
                            print(f"[SSE][persist] saving segments (ordered) parts={len(segments)}")
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
                # Legacy partner_draft_list persistence removed in favor of ordered segments.
            except Exception as e:
                print(f"[SSE] persist task fatal: {e}")

        def iter_sse():
            yield (":" + " " * 2048 + "\n\n").encode()

            sess_payload = json.dumps({"session_id": str(session_uuid)})
            yield f"event: session\ndata: {sess_payload}\n\n".encode()
            print(f"[SSE] /chat session event sent session_id={session_uuid}")

            full_text_parts = []
            final_text = ""
            # Build ordered segments to reconstruct placement on reload
            segments_list = []
            current_text_segment = ""
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

                # Stream model output WITHOUT OpenAI function calling
                # Instead, we'll parse special markers in the text
                print(f"[SSE] /chat stream start model={personal_agent.model}")
                print(f"[SSE] Number of messages: {len(input_messages)}")

                model_to_use = personal_agent.model
                partner_texts: list[str] = []

                # Regular streaming without tools - model will output special markers
                stream = personal_agent.client.chat.completions.create(
                    model = model_to_use,
                    messages = input_messages,
                    max_tokens = 1000,  # Ensure enough tokens for complete response
                    stream = True
                )

                import re
                # Parse the stream for special markers
                buffer = ""
                in_partner_message = False
                partner_message_content = ""
                chunk_count = 0

                for chunk in stream:
                    try:
                        chunk_count += 1
                        delta = chunk.choices[0].delta if chunk.choices else None
                        finish_reason = chunk.choices[0].finish_reason if chunk.choices else None

                        if finish_reason:
                            print(f"[SSE] Stream finish_reason={finish_reason} at chunk {chunk_count}, in_partner_message={in_partner_message}")

                        if not delta or not delta.content:
                            continue

                        buffer += delta.content

                        # Debug logging - log every chunk when collecting partner message
                        if in_partner_message:
                            print(f"[SSE] In partner msg, chunk {chunk_count}: got '{delta.content}', buffer now: '{buffer[:50]}...'")

                        # Check for partner message markers
                        # Look for pattern: <partner_message>content</partner_message>
                        while True:
                            if not in_partner_message:
                                # Check for start of partner message (with or without attributes)
                                # Match <partner_message> or <partner_message ...>
                                pattern = r'<partner_message(?:\s+[^>]*)?>'
                                match = re.search(pattern, buffer)

                                # Debug: log what we're searching for
                                if '<partner_message' in buffer:
                                    print(f"[SSE] Found '<partner_message' in buffer, regex match: {match is not None}")
                                    if match:
                                        print(f"[SSE] Regex matched: '{buffer[match.start():match.end()]}'")
                                    else:
                                        print(f"[SSE] Buffer around tag: '{buffer[max(0, buffer.index('<partner_message')-10):buffer.index('<partner_message')+50]}'...")
                                if match:
                                    # Split at the marker
                                    start_pos = match.start()
                                    end_pos = match.end()
                                    before = buffer[:start_pos]
                                    after = buffer[end_pos:]

                                    # Stream the text before the marker
                                    if before:
                                        full_text_parts.append(before)
                                        yield f"event: token\ndata: {json.dumps(before)}\n\n".encode()
                                        current_text_segment += before

                                    # Start collecting partner message
                                    buffer = after
                                    in_partner_message = True
                                    partner_message_content = ""
                                    print(f"[SSE] Partner message start detected - collecting content. Initial buffer after tag: '{after}'")
                                else:
                                    # No marker found, stream what we have except the last bit (might be partial marker)
                                    if len(buffer) > 20:
                                        to_stream = buffer[:-20]
                                        buffer = buffer[-20:]
                                        if to_stream:
                                            full_text_parts.append(to_stream)
                                            yield f"event: token\ndata: {json.dumps(to_stream)}\n\n".encode()
                                            current_text_segment += to_stream
                                    break
                            else:
                                # Look for end of partner message
                                end_marker = "</partner_message>"
                                if end_marker in buffer:
                                    # Found the end
                                    content, after = buffer.split(end_marker, 1)
                                    partner_message_content += content

                                    # Emit the complete partner message sequence
                                    partner_texts.append(partner_message_content)

                                    # Send tool_start, partner_message, and tool_done in sequence
                                    yield f"event: tool_start\ndata: {json.dumps({'name': 'emit_partner_message'})}\n\n".encode()
                                    yield f"event: partner_message\ndata: {json.dumps(partner_message_content)}\n\n".encode()
                                    yield b"event: tool_done\ndata: {}\n\n"

                                    print(f"[SSE] Partner message emitted: {partner_message_content[:50]}...")

                                    # Flush accumulated text as a text segment, then append partner segment to preserve order
                                    if current_text_segment:
                                        segments_list.append({"type": "text", "content": current_text_segment})
                                        current_text_segment = ""
                                    segments_list.append({"type": "partner_draft", "text": partner_message_content})

                                    # Continue with remaining content after the closing tag
                                    buffer = after
                                    in_partner_message = False
                                    partner_message_content = ""

                                    # If there's content after the partner message, continue streaming it
                                    # The frontend will append it to the message with the partner draft
                                    # Don't break - continue processing the buffer which may have more text
                                else:
                                    # Still collecting partner message - save partial content
                                    if len(buffer) > 20:
                                        # Keep last 20 chars in case end marker is split across chunks
                                        partner_message_content += buffer[:-20]
                                        buffer = buffer[-20:]
                                    else:
                                        # Buffer too small, keep it all
                                        pass
                                    break

                    except Exception as e:
                        print(f"[SSE] Stream chunk error: {e}")
                        continue

                # Flush any remaining buffer
                if buffer:
                    if in_partner_message:
                        # Stream ended while collecting partner message
                        # The model didn't close the tag properly - emit what we have as a partner message
                        partner_message_content += buffer
                        if partner_message_content:
                            # Emit as a complete partner message even though tag wasn't closed
                            partner_texts.append(partner_message_content)
                            yield f"event: tool_start\ndata: {json.dumps({'name': 'emit_partner_message'})}\n\n".encode()
                            yield f"event: partner_message\ndata: {json.dumps(partner_message_content)}\n\n".encode()
                            yield b"event: tool_done\ndata: {}\n\n"
                            print(f"[SSE] WARNING: Stream ended with incomplete partner message tag. Emitted content as partner message: {partner_message_content[:100]}...")
                    else:
                        full_text_parts.append(buffer)
                        yield f"event: token\ndata: {json.dumps(buffer)}\n\n".encode()
                        current_text_segment += buffer

                # Store the final response
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

                # If there were no tokens streamed (rare), push the full text once
                if not full_text_parts and final_text:
                    yield f"event: token\ndata: {json.dumps(final_text)}\n\n".encode()

                # No synthesis or heuristics: the model decides when to emit drafts via tool calls.

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