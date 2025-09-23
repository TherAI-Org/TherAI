import uuid
from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import StreamingResponse
from starlette.concurrency import iterate_in_threadpool
import json
import asyncio

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
from ..Database.chat_repo import list_messages_for_session
from ..Database.dialogue_repo import (
    create_dialogue_request,
    create_dialogue_message,
    get_pending_requests_for_user,
    mark_request_as_delivered,
    mark_request_as_accepted,
    get_dialogue_request_by_id,
    list_dialogue_messages_by_session,
    create_new_dialogue_session,
    get_active_request_for_relationship,
    update_dialogue_request_content,
    update_latest_request_message_content,
)
from ..Database.link_repo import get_link_status_for_user, get_partner_user_id
from ..Database.linked_sessions_repo import (
    create_linked_session,
    get_linked_session_by_relationship_and_source_session,
    update_linked_session_partner_session_for_source,
)
from ..Database.session_repo import create_session, assert_session_owned_by_user

router = APIRouter(prefix="/dialogue", tags=["dialogue"])

dialogue_agent = DialogueAgent()

# Constants
MAX_CONTEXT_MESSAGES = 15
MAX_DIALOGUE_HISTORY = 30

# Private helper functions
async def _validate_user_and_session(user_uuid: uuid.UUID, session_id: uuid.UUID) -> None:
    """Validate user authentication and session ownership."""
    try:
        await assert_session_owned_by_user(user_id=user_uuid, session_id=session_id)
    except Exception:
        raise HTTPException(status_code=403, detail="Session does not belong to the current user or does not exist")

async def _get_relationship_info(user_uuid: uuid.UUID) -> tuple[uuid.UUID, uuid.UUID]:
    """Get relationship and partner information for the user."""
    # Check if user is linked to a partner
    linked, relationship_id = await get_link_status_for_user(user_id=user_uuid)
    if not linked or not relationship_id:
        raise HTTPException(status_code=400, detail="User is not linked to a partner")

    # Get partner's user_id
    partner_user_id = await get_partner_user_id(user_id=user_uuid)
    if not partner_user_id:
        raise HTTPException(status_code=400, detail="Could not find partner for the linked relationship")

    return relationship_id, partner_user_id

async def _get_partner_history(linked_session: dict, partner_user_id: uuid.UUID, user_uuid: uuid.UUID) -> list:
    """Get partner's personal chat history if available."""
    if not linked_session:
        return []

    try:
        current_user_id_str = str(user_uuid)
        partner_session_id_str = None

        if linked_session.get("user_a_id") == current_user_id_str:
            partner_session_id_str = linked_session.get("user_b_personal_session_id")
        elif linked_session.get("user_b_id") == current_user_id_str:
            partner_session_id_str = linked_session.get("user_a_personal_session_id")

        if partner_session_id_str:
            return await list_messages_for_session(
                user_id=partner_user_id,
                session_id=uuid.UUID(partner_session_id_str),
                limit=MAX_CONTEXT_MESSAGES,
            )
    except Exception:
        pass

    return []

async def _get_dialogue_context(user_uuid: uuid.UUID, session_id: uuid.UUID, partner_user_id: uuid.UUID, relationship_id: uuid.UUID) -> tuple[list, list, list, uuid.UUID, bool, uuid.UUID]:
    """Gather all context needed for dialogue generation."""
    # Get current user's personal chat history
    try:
        current_personal_history = await list_messages_for_session(
            user_id=user_uuid,
            session_id=session_id,
            limit=MAX_CONTEXT_MESSAGES
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to retrieve personal chat history for session {session_id}: {str(e)}")

    # Get or create dialogue session
    linked_session = await get_linked_session_by_relationship_and_source_session(
        relationship_id=relationship_id,
        source_session_id=session_id
    )

    if not linked_session:
        # First time: create dialogue session and link
        new_dialogue = await create_new_dialogue_session(relationship_id=relationship_id)
        dialogue_session_id = uuid.UUID(new_dialogue["id"])

        await create_linked_session(
            relationship_id=relationship_id,
            user_a_id=user_uuid,
            user_b_id=partner_user_id,
            user_a_personal_session_id=session_id,
            user_b_personal_session_id=None,  # set on acceptance
            dialogue_session_id=dialogue_session_id
        )
        first_time_link = True
        a_id = user_uuid
    else:
        try:
            dialogue_session_id = uuid.UUID(linked_session["dialogue_session_id"])
        except Exception:
            raise HTTPException(status_code=500, detail="Linked session missing dialogue_session_id")
        first_time_link = False
        a_id = uuid.UUID(linked_session["user_a_id"])

    # Get partner's personal chat history
    partner_personal_history = await _get_partner_history(linked_session, partner_user_id, user_uuid)

    # Get dialogue history
    dialogue_history = await list_dialogue_messages_by_session(
        dialogue_session_id=dialogue_session_id,
        limit=MAX_DIALOGUE_HISTORY
    )

    return current_personal_history, partner_personal_history, dialogue_history, dialogue_session_id, first_time_link, a_id

async def _handle_request_creation(user_uuid: uuid.UUID, session_id: uuid.UUID, partner_user_id: uuid.UUID,
                                 relationship_id: uuid.UUID, dialogue_session_id: uuid.UUID,
                                 dialogue_content: str, first_time_link: bool, linked_session: dict) -> DialogueRequestResponse:
    """Handle the creation or update of dialogue requests."""
    partner_joined = False
    if not first_time_link and linked_session:
        partner_joined = bool(linked_session.get("user_b_personal_session_id"))

    if first_time_link or not partner_joined:
        # Check for active request and handle single request policy
        active_request = await get_active_request_for_relationship(relationship_id=relationship_id)
        if active_request:
            try:
                existing_sender_session = uuid.UUID(active_request.get("sender_session_id"))
            except Exception:
                existing_sender_session = None
            if existing_sender_session and existing_sender_session != session_id:
                raise HTTPException(status_code=400, detail="Another session already has an active request for this relationship")

            # Overwrite existing request
            await update_dialogue_request_content(
                request_id=uuid.UUID(active_request["id"]),
                request_content=dialogue_content,
            )
            await update_latest_request_message_content(
                dialogue_session_id=dialogue_session_id,
                content=dialogue_content,
            )
            return DialogueRequestResponse(
                success=True,
                request_id=uuid.UUID(active_request["id"]),
                dialogue_session_id=dialogue_session_id,
            )
        else:
            # Create new request
            dialogue_request = await create_dialogue_request(
                sender_user_id=user_uuid,
                recipient_user_id=partner_user_id,
                sender_session_id=session_id,
                request_content=dialogue_content,
                relationship_id=relationship_id
            )
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
                dialogue_session_id=dialogue_session_id,
            )
    else:
        # Partner has joined: just add dialogue message
        await create_dialogue_message(
            dialogue_session_id=dialogue_session_id,
            request_id=None,
            content=dialogue_content,
            sender_user_id=user_uuid,
            message_type="request"
        )
        return DialogueRequestResponse(
            success=True,
            request_id=dialogue_session_id,
            dialogue_session_id=dialogue_session_id
        )

# Create a dialogue request with auto-linking logic
@router.post("/request", response_model = DialogueRequestResponse)
async def create_dialogue_request_endpoint(request: DialogueRequestBody, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")

    try:
        # Validate user and session
        await _validate_user_and_session(user_uuid, request.session_id)

        # Get relationship and partner info
        relationship_id, partner_user_id = await _get_relationship_info(user_uuid)

        # Gather dialogue context
        current_personal_history, partner_personal_history, dialogue_history, dialogue_session_id, first_time_link, a_id = await _get_dialogue_context(
            user_uuid, request.session_id, partner_user_id, relationship_id
        )

        # Get linked session for partner joined check
        linked_session = await get_linked_session_by_relationship_and_source_session(
            relationship_id=relationship_id,
            source_session_id=request.session_id
        )

        # Generate dialogue content
        dialogue_content = dialogue_agent.generate_dialogue_response(
            current_partner_history=current_personal_history,
            other_partner_history=partner_personal_history,
            dialogue_history=dialogue_history,
            user_a_id=a_id,
        )

        # Handle request creation/update
        return await _handle_request_creation(
            user_uuid, request.session_id, partner_user_id, relationship_id,
            dialogue_session_id, dialogue_content, first_time_link, linked_session
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
                    raise HTTPException(status_code=500, detail="Linked session missing dialogue_session_id")

        # Determine dialogue_session_id for this source session scope
        if linked_session and linked_session.get("dialogue_session_id"):
            dialogue_session_id = uuid.UUID(linked_session["dialogue_session_id"])
        else:
            raise HTTPException(status_code=404, detail="Dialogue session not found for this personal session")

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
        # Authorization: only the intended recipient within the same relationship can mark delivered
        dialogue_request = await get_dialogue_request_by_id(request_id=request_id)
        if not dialogue_request:
            raise HTTPException(status_code=404, detail="Dialogue request not found")

        # Verify caller is linked and relationship matches
        linked, relationship_id = await get_link_status_for_user(user_id=user_uuid)
        if not linked or not relationship_id:
            raise HTTPException(status_code=403, detail="User is not linked to a partner")
        try:
            req_rel = uuid.UUID(dialogue_request["relationship_id"])  # type: ignore[index]
        except Exception:
            raise HTTPException(status_code=500, detail="Dialogue request missing relationship_id")
        if req_rel != relationship_id:
            raise HTTPException(status_code=404, detail="Dialogue request not found")

        # Verify caller is the recipient of this request
        if dialogue_request.get("recipient_user_id") != str(user_uuid):
            raise HTTPException(status_code=404, detail="Dialogue request not found")

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
        # Load the request for authorization and context
        dialogue_request = await get_dialogue_request_by_id(request_id=request_id)
        if not dialogue_request:
            raise HTTPException(status_code=404, detail="Dialogue request not found")

        # Verify caller is linked and relationship matches
        linked, relationship_id = await get_link_status_for_user(user_id=user_uuid)
        if not linked or not relationship_id:
            raise HTTPException(status_code=403, detail="User is not linked to a partner")
        try:
            req_rel = uuid.UUID(dialogue_request["relationship_id"])  # type: ignore[index]
        except Exception:
            raise HTTPException(status_code=500, detail="Dialogue request missing relationship_id")
        if req_rel != relationship_id:
            raise HTTPException(status_code=404, detail="Dialogue request not found")

        # Verify caller is the recipient of this request
        if dialogue_request.get("recipient_user_id") != str(user_uuid):
            raise HTTPException(status_code=404, detail="Dialogue request not found")

        # Mark request as accepted
        await mark_request_as_accepted(request_id=request_id)

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
        partner_session = await create_session(user_id=user_uuid, title="New Chat")
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

        # Load dialogue history scoped to this dialogue session for prompt context
        dialogue_history = await list_dialogue_messages_by_session(dialogue_session_id=dialogue_session_id, limit=30)

        # Resolve A/B ids for labeling (mirror non-stream logic)
        if linked_session:
            a_id_str = linked_session["user_a_id"]  # type: ignore[index]
        else:
            a_id_str = str(user_uuid)

        # Load partner's personal chat history from the mapped partner session (if available)
        other_partner_history = []
        try:
            current_user_id_str = str(user_uuid)
            partner_session_id_str = None
            if linked_session:
                if linked_session.get("user_a_id") == current_user_id_str:
                    partner_session_id_str = linked_session.get("user_b_personal_session_id")
                elif linked_session.get("user_b_id") == current_user_id_str:
                    partner_session_id_str = linked_session.get("user_a_personal_session_id")

            if partner_session_id_str:
                other_partner_history = await list_messages_for_session(
                    user_id = partner_user_id,
                    session_id = uuid.UUID(partner_session_id_str),
                    limit = 50,
                )
        except Exception:
            other_partner_history = []

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
            lines = []
            for msg in dialogue_history:
                sender_id = str(msg.get('sender_user_id')) if msg.get('sender_user_id') is not None else None
                if sender_id == a_id_str:
                    label = "Partner A:"
                else:
                    label = "Partner B:"
                lines.append(f"{label} {msg.get('content', '')}\n")
            dialogue_context_text = "\nPrevious dialogue between partners:\n" + "".join(lines)
        # Align with DialoguePrompt: do not add extra instructions; provide only context
        full_context = f"{name_context}\n{current_context}{other_context}{dialogue_context_text}"

        input_messages = [
            {"role": "system", "content": dialogue_agent.dialogue_prompt},
            {"role": "user", "content": full_context}
        ]

        # Capture the main event loop to dispatch DB coroutines from the thread
        loop = asyncio.get_running_loop()

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
                    if first_time_link or not partner_joined:
                        # Overwrite-or-create semantics under single active request policy
                        fut_active = asyncio.run_coroutine_threadsafe(
                            get_active_request_for_relationship(relationship_id=relationship_id),
                            loop,
                        )
                        active_request = fut_active.result()
                        if active_request:
                            existing_sender_session = None
                            try:
                                existing_sender_session = uuid.UUID(active_request.get("sender_session_id"))  # type: ignore[arg-type]
                            except Exception:
                                pass
                            if existing_sender_session and existing_sender_session != request.session_id:
                                raise Exception("Another session already has an active request for this relationship")

                            asyncio.run_coroutine_threadsafe(
                                update_dialogue_request_content(
                                    request_id=uuid.UUID(active_request["id"]),
                                    request_content=final_text,
                                ),
                                loop,
                            ).result()
                            asyncio.run_coroutine_threadsafe(
                                update_latest_request_message_content(
                                    dialogue_session_id=dialogue_session_id,
                                    content=final_text,
                                ),
                                loop,
                            ).result()
                            print(f"[SSE] Overwrote active request request_id={active_request['id']} dialogue_session_id={dialogue_session_id}")
                            yield f"event: request\ndata: {json.dumps(active_request['id'])}\n\n".encode()
                        else:
                            fut_req = asyncio.run_coroutine_threadsafe(
                                create_dialogue_request(
                                    sender_user_id=user_uuid,
                                    recipient_user_id=uuid.UUID(str(partner_user_id)),
                                    sender_session_id=request.session_id,
                                    request_content=final_text,
                                    relationship_id=relationship_id
                                ),
                                loop,
                            )
                            dialogue_request = fut_req.result()
                            req_id = dialogue_request["id"]

                            asyncio.run_coroutine_threadsafe(
                                create_dialogue_message(
                                    dialogue_session_id=dialogue_session_id,
                                    request_id=uuid.UUID(req_id),
                                    content=final_text,
                                    sender_user_id=user_uuid,
                                    message_type="request"
                                ),
                                loop,
                            ).result()
                            print(f"[SSE] Created new request and message request_id={req_id} dialogue_session_id={dialogue_session_id}")
                            yield f"event: request\ndata: {json.dumps(req_id)}\n\n".encode()
                    else:
                        fut_msg = asyncio.run_coroutine_threadsafe(
                            create_dialogue_message(
                                dialogue_session_id=dialogue_session_id,
                                request_id=None,
                                content=final_text,
                                sender_user_id=user_uuid,
                                message_type="request"
                            ),
                            loop,
                        )
                        fut_msg.result()
                        print(f"[SSE] Persisted dialogue message dialogue_session_id={dialogue_session_id}")
                except Exception as e:
                    print(f"[SSE] Persist failed: {e}")
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