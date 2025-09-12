import uuid
from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import StreamingResponse
from starlette.concurrency import iterate_in_threadpool
import json
from ..Models.requests import (
    DialogueRequestBody,
    DialogueRequestResponse,
    DialogueMessagesResponse,
    DialogueMessageDTO,
    PendingRequestsResponse,
    PendingRequestDTO,
    AcceptDialogueResponse,
)
from ..Agents.dialogue import DialogueAgent
from ..auth import get_current_user
from ..Database.chat_repository import list_messages_for_session, get_partner_chat_history
from ..Database.dialogue_repository import (
    get_or_create_dialogue_session,
    create_dialogue_request,
    create_dialogue_message,
    get_dialogue_history_for_context,
    get_dialogue_messages,
    get_pending_requests_for_user,
    mark_request_as_delivered,
    mark_request_as_accepted,
    get_dialogue_request_by_id,
    list_dialogue_messages_by_session,
    create_new_dialogue_session,
)
from ..Database.link_repository import get_link_status_for_user, get_partner_user_id
from ..Database.linked_sessions_repository import (
    create_linked_session,
    get_linked_session_by_relationship,
    linked_session_exists,
    update_linked_session_partner_session,
    get_linked_session_by_relationship_and_source_session,
    linked_session_exists_for_session,
    update_linked_session_partner_session_for_source,
)
from ..Database.session_repository import create_session, assert_session_owned_by_user, get_or_create_default_session

router = APIRouter(prefix="/dialogue", tags=["dialogue"])

dialogue_agent = DialogueAgent()

@router.post("/request", response_model=DialogueRequestResponse)
async def create_dialogue_request_endpoint(request: DialogueRequestBody, current_user: dict = Depends(get_current_user)):
    """Create a dialogue request with auto-linking logic"""
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")

    try:
        # Debug/guard: ensure the provided session belongs to the caller
        try:
            await assert_session_owned_by_user(user_id=user_uuid, session_id=request.session_id)
        except Exception:
            raise HTTPException(status_code=403, detail="Session does not belong to the current user or does not exist")

        # Check if user is linked to a partner
        linked, relationship_id = await get_link_status_for_user(user_id=user_uuid)
        if not linked or not relationship_id:
            raise HTTPException(status_code=400, detail="User is not linked to a partner")

        # Get partner's user_id
        partner_user_id = await get_partner_user_id(user_id=user_uuid)
        if not partner_user_id:
            raise HTTPException(status_code=400, detail="Could not find partner for the linked relationship")

        # Get current user's personal chat history from the specified session
        try:
            current_personal_history = await list_messages_for_session(
                user_id=user_uuid,
                session_id=request.session_id,
                limit=50
            )
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Failed to retrieve personal chat history for session {request.session_id}: {str(e)}")

        # Get partner's personal chat history
        partner_personal_history = await get_partner_chat_history(user_id=user_uuid)

        # Get existing dialogue history
        dialogue_history = await get_dialogue_history_for_context(user_id=user_uuid)

        # Generate dialogue message using comprehensive context
        dialogue_content = dialogue_agent.generate_dialogue_response(
            current_partner_history=current_personal_history,
            other_partner_history=partner_personal_history,
            dialogue_history=dialogue_history
        )

        # Determine or create the dialogue session mapping for this (relationship, source personal session)
        linked_session = await get_linked_session_by_relationship_and_source_session(
            relationship_id=relationship_id,
            source_session_id=request.session_id
        )

        if not linked_session:
            # First send from this personal session: create a fresh dialogue session and link
            new_dialogue = await create_new_dialogue_session(relationship_id=relationship_id)
            dialogue_session_id = uuid.UUID(new_dialogue["id"])

            await create_linked_session(
                relationship_id=relationship_id,
                user_a_id=user_uuid,
                user_b_id=partner_user_id,
                user_a_personal_session_id=request.session_id,
                user_b_personal_session_id=None,  # set on acceptance
                dialogue_session_id=dialogue_session_id
            )
            first_time_link = True
        else:
            try:
                dialogue_session_id = uuid.UUID(linked_session["dialogue_session_id"])  # type: ignore[index]
            except Exception:
                raise HTTPException(status_code=500, detail="Linked session missing dialogue_session_id")
            first_time_link = False

        # Determine whether partner has already joined (accepted)
        partner_joined = False
        if not first_time_link:
            partner_joined = bool(linked_session.get("user_b_personal_session_id"))

        if first_time_link or not partner_joined:
            # FIRST TIME (or partner not yet accepted): create a pending dialogue request
            try:
                dialogue_request = await create_dialogue_request(
                    sender_user_id=user_uuid,
                    recipient_user_id=partner_user_id,
                    sender_session_id=request.session_id,
                    request_content=dialogue_content,
                    relationship_id=relationship_id
                )
            except ValueError as e:
                if "A pending request already exists" in str(e):
                    raise HTTPException(status_code=400, detail="A dialogue request is already pending for this relationship")
                else:
                    raise HTTPException(status_code=400, detail=str(e))

            # Create dialogue message linked to the request
            await create_dialogue_message(
                dialogue_session_id=dialogue_session_id,
                request_id=uuid.UUID(dialogue_request["id"]),
                content=dialogue_content,
                sender_user_id=user_uuid,
                message_type="request"
            )

            return DialogueRequestResponse(
                success=True,
                request_id=uuid.UUID(dialogue_request["id"]),
                dialogue_session_id=dialogue_session_id
            )
        else:
            # SUBSEQUENT SENDS after partner has joined: no pending request; just add dialogue message
            await create_dialogue_message(
                dialogue_session_id=dialogue_session_id,
                request_id=None,
                content=dialogue_content,
                sender_user_id=user_uuid,
                message_type="request"
            )

            # Return a placeholder request_id (dialogue_session_id) to satisfy client schema
            return DialogueRequestResponse(
                success=True,
                request_id=dialogue_session_id,
                dialogue_session_id=dialogue_session_id
            )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating dialogue request: {str(e)}")


@router.get("/messages", response_model=DialogueMessagesResponse)
async def get_dialogue_messages_endpoint(source_session_id: uuid.UUID, current_user: dict = Depends(get_current_user)):
    """Get dialogue messages for the current user's relationship"""
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")

    try:
        # Check if user is linked to a partner
        linked, relationship_id = await get_link_status_for_user(user_id=user_uuid)
        if not linked or not relationship_id:
            raise HTTPException(status_code=400, detail="User is not linked to a partner")

        # Gate access for partner B until they accept the first request for this source session
        # If the caller is user_b and their personal session is not yet created (None),
        # return an empty messages list so they do not see dialogue content prematurely.
        linked_session = await get_linked_session_by_relationship_and_source_session(relationship_id=relationship_id, source_session_id=source_session_id)
        if linked_session:
            try:
                is_user_b = linked_session.get("user_b_id") == str(user_uuid)
                partner_session_missing = not linked_session.get("user_b_personal_session_id")
            except Exception:
                is_user_b = False
                partner_session_missing = False

            if is_user_b and partner_session_missing:
                # Return empty messages but include the mapped dialogue_session_id for this source session
                if linked_session and linked_session.get("dialogue_session_id"):
                    return DialogueMessagesResponse(
                        messages=[],
                        dialogue_session_id=uuid.UUID(linked_session["dialogue_session_id"])  # type: ignore[index]
                    )
                else:
                    return DialogueMessagesResponse(messages=[], dialogue_session_id=uuid.uuid4())

        # Determine dialogue_session_id for this source session scope
        if linked_session and linked_session.get("dialogue_session_id"):
            dialogue_session_id = uuid.UUID(linked_session["dialogue_session_id"])
        else:
            # Fallback: should not happen if the link exists; generate a stable id
            dialogue_session_id = uuid.UUID(linked_session["dialogue_session_id"]) if linked_session else uuid.uuid4()  # type: ignore[index]

        # Get dialogue messages for that dialogue session
        messages = await list_dialogue_messages_by_session(dialogue_session_id=dialogue_session_id, limit=100)

        return DialogueMessagesResponse(
            messages=[
                DialogueMessageDTO(
                    id=uuid.UUID(msg["id"]),
                    dialogue_session_id=uuid.UUID(msg["dialogue_session_id"]),
                    request_id=uuid.UUID(msg["request_id"]) if msg.get("request_id") else None,
                    content=msg["content"],
                    message_type=msg["message_type"],
                    sender_user_id=uuid.UUID(msg["sender_user_id"]),
                    created_at=msg["created_at"]
                )
                for msg in messages
            ],
            dialogue_session_id=dialogue_session_id
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving dialogue messages: {str(e)}")


@router.get("/pending-requests", response_model=PendingRequestsResponse)
async def get_pending_requests_endpoint(current_user: dict = Depends(get_current_user)):
    """Get pending dialogue requests for the current user"""
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")

    try:
        # Get pending requests
        requests = await get_pending_requests_for_user(user_id=user_uuid, limit=50)

        return PendingRequestsResponse(
            requests=[
                PendingRequestDTO(
                    id=uuid.UUID(req["id"]),
                    sender_user_id=uuid.UUID(req["sender_user_id"]),
                    sender_session_id=uuid.UUID(req["sender_session_id"]) if req.get("sender_session_id") else uuid.UUID(int=0),
                    request_content=req["request_content"],
                    created_at=req["created_at"],
                    status=req["status"]
                )
                for req in requests
            ]
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving pending requests: {str(e)}")


@router.post("/requests/{request_id}/delivered")
async def mark_request_delivered_endpoint(request_id: uuid.UUID, current_user: dict = Depends(get_current_user)):
    """Mark a dialogue request as delivered when partner sees it"""
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")

    try:
        await mark_request_as_delivered(request_id=request_id)
        return {"success": True}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error marking request as delivered: {str(e)}")


@router.post("/requests/{request_id}/accept", response_model=AcceptDialogueResponse)
async def mark_request_accepted_endpoint(request_id: uuid.UUID, current_user: dict = Depends(get_current_user)):
    """Mark a dialogue request as accepted when partner engages with the dialogue"""
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")

    try:
        # Mark request as accepted
        await mark_request_as_accepted(request_id=request_id)

        # Get the dialogue request to find the relationship
        dialogue_request = await get_dialogue_request_by_id(request_id=request_id)
        if not dialogue_request:
            raise HTTPException(status_code=404, detail="Dialogue request not found")

        # Get the relationship ID from the request
        relationship_id = uuid.UUID(dialogue_request["relationship_id"])

        # Find the specific linked row for this source personal session
        try:
            sender_session_id = uuid.UUID(dialogue_request["sender_session_id"])  # type: ignore[index]
        except Exception:
            raise HTTPException(status_code=500, detail="Dialogue request missing sender_session_id")

        linked_session = await get_linked_session_by_relationship_and_source_session(
            relationship_id=relationship_id,
            source_session_id=sender_session_id,
        )
        if not linked_session:
            raise HTTPException(status_code=404, detail="Linked session for this chat not found")

        # Create a personal session for partner B (if not already created by another path)
        partner_session = await create_session(user_id=user_uuid, title="Chat")
        partner_session_id = uuid.UUID(partner_session["id"])

        # Update only this linked row with partner B's personal session id
        await update_linked_session_partner_session_for_source(
            relationship_id=relationship_id,
            source_session_id=sender_session_id,
            partner_session_id=partner_session_id,
        )

        # Return ids so the client can switch to the correct dialogue session for this chat
        linked_session = await get_linked_session_by_relationship_and_source_session(
            relationship_id=relationship_id,
            source_session_id=sender_session_id,
        )
        if not linked_session:
            raise HTTPException(status_code=404, detail="Linked session not found after update")
        try:
            dialogue_session_id = uuid.UUID(linked_session["dialogue_session_id"])  # type: ignore[index]
        except Exception:
            raise HTTPException(status_code=500, detail="Linked row missing dialogue_session_id")

        return AcceptDialogueResponse(
            success=True,
            partner_session_id=partner_session_id,
            dialogue_session_id=dialogue_session_id,
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error marking request as accepted: {str(e)}")


@router.post("/request/stream")
async def create_dialogue_request_stream(request: DialogueRequestBody, current_user: dict = Depends(get_current_user)):
    """Stream the AI-generated dialogue message (SSE) and persist at the end with linking logic."""
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")

    try:
        # Guard: ensure the provided session belongs to the caller
        try:
            await assert_session_owned_by_user(user_id=user_uuid, session_id=request.session_id)
        except Exception:
            raise HTTPException(status_code=403, detail="Session does not belong to the current user or does not exist")

        # Check link status and compute context
        linked, relationship_id = await get_link_status_for_user(user_id=user_uuid)
        if not linked or not relationship_id:
            raise HTTPException(status_code=400, detail="User is not linked to a partner")

        partner_user_id = await get_partner_user_id(user_id=user_uuid)
        if not partner_user_id:
            raise HTTPException(status_code=400, detail="Could not find partner for the linked relationship")

        # Current user's personal history (from provided session)
        try:
            current_personal_history = await list_messages_for_session(
                user_id=user_uuid,
                session_id=request.session_id,
                limit=50
            )
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Failed to retrieve personal chat history for session {request.session_id}: {str(e)}")

        other_partner_history = await get_partner_chat_history(user_id=user_uuid)
        dialogue_history = await get_dialogue_history_for_context(user_id=user_uuid)

        # Determine or create the dialogue session mapping for this (relationship, source personal session)
        linked_session = await get_linked_session_by_relationship_and_source_session(
            relationship_id=relationship_id,
            source_session_id=request.session_id
        )

        if not linked_session:
            new_dialogue = await create_new_dialogue_session(relationship_id=relationship_id)
            dialogue_session_id = uuid.UUID(new_dialogue["id"])
            await create_linked_session(
                relationship_id=relationship_id,
                user_a_id=user_uuid,
                user_b_id=partner_user_id,
                user_a_personal_session_id=request.session_id,
                user_b_personal_session_id=None,
                dialogue_session_id=dialogue_session_id
            )
            first_time_link = True
        else:
            try:
                dialogue_session_id = uuid.UUID(linked_session["dialogue_session_id"])  # type: ignore[index]
            except Exception:
                raise HTTPException(status_code=500, detail="Linked session missing dialogue_session_id")
            first_time_link = False

        partner_joined = False
        if not first_time_link:
            partner_joined = bool(linked_session.get("user_b_personal_session_id"))

        # Build prompt input similar to DialogueAgent.generate_dialogue_response
        name_context = "Partner's name: Unknown\n"
        current_context = "Current partner's personal thoughts:\n" + "".join([
            ("User" if msg.get("role") == "user" else "AI Assistant") + f": {msg.get('content', '')}\n" for msg in current_personal_history
        ])
        other_context = ""
        if other_partner_history:
            other_context = "\nOther partner's personal thoughts:\n" + "".join([
                ("User" if msg.get("role") == "user" else "AI Assistant") + f": {msg.get('content', '')}\n" for msg in other_partner_history
            ])
        dialogue_context_text = ""
        if dialogue_history:
            dialogue_context_text = "\nPrevious dialogue between partners:\n" + "".join([
                ("Partner" if msg.get('message_type') == 'request' else "AI Mediator") + f": {msg.get('content', '')}\n" for msg in dialogue_history
            ])
        full_context = f"{name_context}\n{current_context}{other_context}{dialogue_context_text}\n\nPlease facilitate this conversation between partners."

        input_messages = [
            {"role": "system", "content": dialogue_agent.dialogue_prompt},
            {"role": "user", "content": full_context}
        ]

        def iter_sse():
            # Anti-buffering prelude
            yield (":" + " " * 2048 + "\n\n").encode()
            # Send dialogue_session_id to client first
            yield f"event: dialogue_session\ndata: {json.dumps(str(dialogue_session_id))}\n\n".encode()
            parts = []
            try:
                print(f"[SSE] /dialogue stream start dialogue_session_id={dialogue_session_id}")
                with dialogue_agent.client.responses.stream(model=dialogue_agent.model, input=input_messages) as stream:  # type: ignore[attr-defined]
                    try:
                        for delta in stream.text_deltas:  # type: ignore[attr-defined]
                            try:
                                if delta:
                                    parts.append(delta)
                                    yield f"event: token\ndata: {json.dumps(delta)}\n\n".encode()
                            except Exception:
                                continue
                    except Exception:
                        for event in stream:
                            try:
                                ev_type = getattr(event, "type", "")
                                if ev_type.endswith("output_text.delta"):
                                    delta = getattr(event, "delta", "") or ""
                                    if delta:
                                        parts.append(delta)
                                        yield f"event: token\ndata: {json.dumps(delta)}\n\n".encode()
                                elif ev_type.endswith("error"):
                                    err = getattr(event, "error", None)
                                    if err:
                                        yield f"event: error\ndata: {json.dumps(str(err))}\n\n".encode()
                            except Exception:
                                continue

                    final = stream.get_final_response()
                    final_text = getattr(final, "output_text", None) or "".join(parts)
                    print(f"[SSE] /dialogue stream completed tokens={len(parts)} final_len={len(final_text)}")

                # If nothing streamed, at least emit the final text once
                if not parts and final_text:
                    yield f"event: token\ndata: {json.dumps(final_text)}\n\n".encode()

                # Persist dialogue message and (possibly) create a pending request
                try:
                    import asyncio
                    if first_time_link or not partner_joined:
                        dialogue_request = asyncio.run(create_dialogue_request(
                            sender_user_id=user_uuid,
                            recipient_user_id=uuid.UUID(str(partner_user_id)),
                            sender_session_id=request.session_id,
                            request_content=final_text,
                            relationship_id=relationship_id
                        ))
                        req_id = dialogue_request["id"]
                        asyncio.run(create_dialogue_message(
                            dialogue_session_id=dialogue_session_id,
                            request_id=uuid.UUID(req_id),
                            content=final_text,
                            sender_user_id=user_uuid,
                            message_type="request"
                        ))
                        yield f"event: request\ndata: {json.dumps(req_id)}\n\n".encode()
                    else:
                        asyncio.run(create_dialogue_message(
                            dialogue_session_id=dialogue_session_id,
                            request_id=None,
                            content=final_text,
                            sender_user_id=user_uuid,
                            message_type="request"
                        ))
                except Exception as e:
                    yield f"event: warn\ndata: {json.dumps(f'Persist failed: {e}')}\n\n".encode()

                yield b"event: done\ndata: {}\n\n"
                print(f"[SSE] /dialogue stream done sent dialogue_session_id={dialogue_session_id}")
            except Exception as e:
                print(f"[SSE] /dialogue stream error: {e}")
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
        raise HTTPException(status_code=500, detail=f"Error streaming dialogue request: {str(e)}")