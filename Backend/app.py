import uuid
from fastapi import FastAPI, HTTPException, Depends
from fastapi.responses import StreamingResponse
from starlette.concurrency import iterate_in_threadpool
import json

from .Models.requests import ChatRequest, ChatResponse, MessagesResponse, MessageDTO, SessionsResponse, SessionDTO
from .Agents.personal import PersonalAgent
from .auth import get_current_user
from .Database.chat_repo import save_message, list_messages_for_session
from .Database.dialogue_repo import list_dialogue_messages_by_session
from .Database.link_repo import get_link_status_for_user, get_partner_user_id
from .Database.linked_sessions_repo import get_linked_session_by_relationship_and_source_session
from .Database.session_repo import create_session, list_sessions_for_user, touch_session, assert_session_owned_by_user
from .Routers.aasa_router import router as aasa_router
from .Routers.link_router import router as link_router
from .Routers.dialogue_router import router as dialogue_router

app = FastAPI()

app.include_router(aasa_router)
app.include_router(link_router)
app.include_router(dialogue_router)

personal_agent = PersonalAgent()

# Send a message and receive an assistant response, creating a session if needed
@app.post("/chat/sessions/message", response_model = ChatResponse)
async def chat_message(request: ChatRequest, current_user: dict = Depends(get_current_user)):
    try:
        try:
            user_uuid = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

        # Determine session id: if provided, verify ownership; else create one
        if request.session_id is not None:
            try:
                await assert_session_owned_by_user(user_id=user_uuid, session_id=request.session_id)
                session_uuid = request.session_id
            except PermissionError:
                raise HTTPException(status_code=403, detail="Forbidden: invalid session")
        else:
            session_row = await create_session(user_id=user_uuid, title=None)
            session_uuid = uuid.UUID(session_row["id"])

        await save_message(user_id = user_uuid, session_id = session_uuid, role = "user", content = request.message)

        # Convert chat history to the format expected by the chat agent
        chat_history_for_agent = None
        if request.chat_history:
            chat_history_for_agent = [
                {"role": msg.role, "content": msg.content}
                for msg in request.chat_history
            ]

        # AUTO-ENHANCED CONTEXT: Get linked session context automatically
        dialogue_context = None
        partner_context = None
        linked_session = None

        try:
            linked, relationship_id = await get_link_status_for_user(user_id=user_uuid)
            if linked and relationship_id:
                # Get dialogue history scoped per-dialogue session if mapping exists for this session
                try:
                    mapped = await get_linked_session_by_relationship_and_source_session(relationship_id=relationship_id, source_session_id=session_uuid)
                    linked_session = mapped
                    if mapped and mapped.get("dialogue_session_id"):
                        dialogue_context = await list_dialogue_messages_by_session(dialogue_session_id=uuid.UUID(mapped["dialogue_session_id"]), limit=30)
                except Exception:
                    dialogue_context = None

                # Get partner's personal chat history, but scoped to the mapped row for this source session
                try:
                    mapped = await get_linked_session_by_relationship_and_source_session(relationship_id=relationship_id, source_session_id=session_uuid)
                    # Update cached linked_session if available
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
            print(f"Context retrieval warning: {e}")

        # Resolve Partner A id for labeling (use linked row if present, else caller)
        try:
            a_id = uuid.UUID(linked_session["user_a_id"]) if linked_session else user_uuid  # type: ignore[index]
        except Exception:
            a_id = user_uuid

        response = personal_agent.generate_response(
            request.message,
            chat_history_for_agent,
            dialogue_context = dialogue_context,
            partner_context = partner_context,
            user_a_id = a_id,
        )

        # Persist assistant message
        await save_message(user_id = user_uuid, session_id = session_uuid, role = "assistant", content = response)
        await touch_session(session_id=session_uuid)

        return ChatResponse(
            response = response,
            success = True,
            session_id = session_uuid
        )
    except Exception as e:
        raise HTTPException(status_code = 500, detail = f"Error processing message: {str(e)}")


# Stream assistant response as Server-Sent Events (SSE)
@app.post("/chat/sessions/message/stream")
async def chat_message_stream(request: ChatRequest, current_user: dict = Depends(get_current_user)):
    try:
        try:
            user_uuid = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

        # Determine session id: if provided, verify ownership; else create one
        if request.session_id is not None:
            try:
                await assert_session_owned_by_user(user_id=user_uuid, session_id=request.session_id)
                session_uuid = request.session_id
            except PermissionError:
                raise HTTPException(status_code=403, detail="Forbidden: invalid session")
        else:
            session_row = await create_session(user_id=user_uuid, title=None)
            session_uuid = uuid.UUID(session_row["id"])

        # Persist user message immediately
        await save_message(user_id = user_uuid, session_id = session_uuid, role = "user", content = request.message)

        # Convert chat history to the format expected by the chat agent
        chat_history_for_agent = None
        if request.chat_history:
            chat_history_for_agent = [
                {"role": msg.role, "content": msg.content}
                for msg in request.chat_history
            ]

        # AUTO-ENHANCED CONTEXT
        dialogue_context = None
        partner_context = None
        linked_session = None
        try:
            linked, relationship_id = await get_link_status_for_user(user_id=user_uuid)
            if linked and relationship_id:
                try:
                    mapped = await get_linked_session_by_relationship_and_source_session(relationship_id=relationship_id, source_session_id=session_uuid)
                    linked_session = mapped
                    if mapped and mapped.get("dialogue_session_id"):
                        dialogue_context = await list_dialogue_messages_by_session(dialogue_session_id=uuid.UUID(mapped["dialogue_session_id"]), limit=30)
                except Exception:
                    dialogue_context = None
                try:
                    mapped = await get_linked_session_by_relationship_and_source_session(relationship_id=relationship_id, source_session_id=session_uuid)
                    # Update cached linked_session if available
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

        def iter_sse():
            # Anti-buffering prelude (2KB of comments) to force flush through some proxies/CDNs
            yield (":" + " " * 2048 + "\n\n").encode()
            # Send session id to client first so UI can bind to it
            sess_payload = json.dumps({"session_id": str(session_uuid)})
            yield f"event: session\ndata: {sess_payload}\n\n".encode()

            full_text_parts = []
            try:
                print(f"[SSE] /chat stream start session_id={session_uuid}")
                input_messages = [{"role": "system", "content": personal_agent.system_prompt}] if hasattr(personal_agent, "system_prompt") else []
                if chat_history_for_agent:
                    for msg in chat_history_for_agent:
                        role = "user" if msg.get("role") == "user" else "assistant"
                        input_messages.append({"role": role, "content": msg.get("content", "")})
                if dialogue_context:
                    # Label prior dialogue as Partner A/B
                    try:
                        a_id_str = linked_session["user_a_id"] if linked_session else str(user_uuid)  # type: ignore[index]
                    except Exception:
                        a_id_str = str(user_uuid)
                    dialogue_text = "DIALOGUE CONTEXT (Shared conversations with partner):\n"
                    for msg in dialogue_context:
                        sender_id = str(msg.get("sender_user_id")) if msg.get("sender_user_id") is not None else None
                        if sender_id == a_id_str:
                            label = "Partner A"
                        else:
                            label = "Partner B"
                        dialogue_text += f"{label}: {msg.get('content', '')}\n"
                    input_messages.append({"role": "system", "content": dialogue_text.strip()})
                if partner_context:
                    partner_text = "PARTNER CONTEXT (Partner's recent personal thoughts):\n"
                    for msg in partner_context:
                        role = "Partner" if msg.get("role") == "user" else "AI Assistant to Partner"
                        partner_text += f"{role}: {msg.get('content', '')}\n"
                    input_messages.append({"role": "system", "content": partner_text.strip()})
                input_messages.append({"role": "user", "content": request.message})

                # Use the agent's generation controls if available
                with personal_agent.client.responses.stream(
                    model=personal_agent.model,
                    input=input_messages,
                    max_output_tokens=getattr(personal_agent, "max_output_tokens", None),
                    temperature=getattr(personal_agent, "temperature", None),
                ) as stream:  # type: ignore[attr-defined]
                    used_iterator = False
                    try:
                        for delta in stream.text_deltas:  # type: ignore[attr-defined]
                            used_iterator = True
                            try:
                                if delta:
                                    full_text_parts.append(delta)
                                    yield f"event: token\ndata: {json.dumps(delta)}\n\n".encode()
                            except Exception:
                                continue
                    except Exception:
                        # Fallback to raw event loop if text_deltas isn't available
                        for event in stream:
                            try:
                                ev_type = getattr(event, "type", "")
                                if ev_type.endswith("output_text.delta"):
                                    delta = getattr(event, "delta", "") or ""
                                    if delta:
                                        full_text_parts.append(delta)
                                        yield f"event: token\ndata: {json.dumps(delta)}\n\n".encode()
                                elif ev_type.endswith("error"):
                                    err = getattr(event, "error", None)
                                    if err:
                                        yield f"event: error\ndata: {json.dumps(str(err))}\n\n".encode()
                            except Exception:
                                continue

                    final = stream.get_final_response()
                    final_text = getattr(final, "output_text", None) or "".join(full_text_parts)
                    print(f"[SSE] /chat stream completed tokens={len(full_text_parts)} final_len={len(final_text)}")

                # If no tokens were sent during streaming, emit the final text now so clients show something
                if not full_text_parts and final_text:
                    yield f"event: token\ndata: {json.dumps(final_text)}\n\n".encode()

                # Persist assistant message at the end
                try:
                    import asyncio
                    asyncio.run(save_message(user_id = user_uuid, session_id = session_uuid, role = "assistant", content = final_text))
                    asyncio.run(touch_session(session_id=session_uuid))
                except Exception as e:
                    warn_msg = json.dumps(f"Failed to save message: {e}")
                    yield f"event: warn\ndata: {warn_msg}\n\n".encode()

                yield b"event: done\ndata: {}\n\n"
                print(f"[SSE] /chat stream done sent for session_id={session_uuid}")
            except Exception as e:
                print(f"[SSE] /chat stream error: {e}")
                yield f"event: error\ndata: {json.dumps(str(e))}\n\n".encode()

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