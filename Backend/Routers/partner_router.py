import uuid
import json
import asyncio
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from starlette.concurrency import iterate_in_threadpool

from ..auth import get_current_user
from ..Database.link_repo import get_link_status_for_user, get_partner_user_id
from ..Database.session_repo import create_session, assert_session_owned_by_user, touch_session
from ..Database.chat_repo import save_message, list_messages_for_session, update_session_last_message
from ..Database.linked_sessions_repo import (
    create_linked_session,
    get_linked_session_by_relationship_and_source_session,
    update_linked_session_partner_session_for_source,
)
from ..Database.partner_requests_repo import (
    create_partner_request,
    list_pending_for_user,
    mark_delivered,
    mark_accepted_and_attach,
    get_request_by_id,
    update_content,
)
from ..Agents.personal import PersonalAgent

from ..Models.requests import (
    PartnerRequestBody,
    PartnerRequestResponse,
    PartnerPendingRequestsResponse,
    PartnerPendingRequestDTO,
)

router = APIRouter(prefix="/partner", tags=["partner"])
agent = PersonalAgent()


@router.post("/request", response_model=PartnerRequestResponse)
async def create_partner_request_endpoint(body: PartnerRequestBody, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")

    # Verify session ownership
    await assert_session_owned_by_user(user_id=user_uuid, session_id=body.session_id)

    # Link + partner
    linked, relationship_id, _ = await get_link_status_for_user(user_id=user_uuid)
    if not linked or not relationship_id:
        raise HTTPException(status_code=400, detail="User is not linked to a partner")
    partner_user_id = await get_partner_user_id(user_id=user_uuid)
    if not partner_user_id:
        raise HTTPException(status_code=400, detail="Could not find partner for the linked relationship")

    # Ensure linked_sessions row exists for this source session
    linked_row = await get_linked_session_by_relationship_and_source_session(
        relationship_id=relationship_id, source_session_id=body.session_id
    )
    if not linked_row:
        await create_linked_session(
            relationship_id=relationship_id,
            user_a_id=user_uuid,
            user_b_id=partner_user_id,
            user_a_personal_session_id=body.session_id,
            user_b_personal_session_id=None,
        )

    # Create request row
    row = await create_partner_request(
        relationship_id=relationship_id,
        sender_user_id=user_uuid,
        recipient_user_id=partner_user_id,
        sender_session_id=body.session_id,
        content=body.message.strip(),
    )
    return PartnerRequestResponse(success=True, request_id=uuid.UUID(row["id"]))


@router.get("/pending", response_model=PartnerPendingRequestsResponse)
async def get_pending_partner_requests(current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")

    rows = await list_pending_for_user(user_id=user_uuid, limit=50)
    return PartnerPendingRequestsResponse(
        requests=[
            PartnerPendingRequestDTO(
                id=uuid.UUID(r["id"]),
                sender_user_id=uuid.UUID(r["sender_user_id"]),
                sender_session_id=uuid.UUID(r["sender_session_id"]),
                content=r["content"],
                created_at=r["created_at"],
                status=r["status"],
            )
            for r in rows
        ]
    )


@router.post("/requests/{request_id}/delivered")
async def mark_delivered_endpoint(request_id: uuid.UUID, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")

    req = await get_request_by_id(request_id=request_id)
    if not req or req.get("recipient_user_id") != str(user_uuid):
        raise HTTPException(status_code=404, detail="Request not found")

    await mark_delivered(request_id=request_id)
    return {"success": True}


@router.post("/requests/{request_id}/accept")
async def accept_request_endpoint(request_id: uuid.UUID, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")

    req = await get_request_by_id(request_id=request_id)
    if not req or req.get("recipient_user_id") != str(user_uuid):
        raise HTTPException(status_code=404, detail="Request not found")

    relationship_id = uuid.UUID(req["relationship_id"])  # type: ignore[arg-type]
    sender_session_id = uuid.UUID(req["sender_session_id"])  # type: ignore[arg-type]

    # Find or create recipient personal session
    linked_row = await get_linked_session_by_relationship_and_source_session(
        relationship_id=relationship_id, source_session_id=sender_session_id
    )
    recipient_session_id: uuid.UUID
    if linked_row and linked_row.get("user_b_personal_session_id"):
        recipient_session_id = uuid.UUID(linked_row["user_b_personal_session_id"])  # type: ignore[index]
    else:
        new_session = await create_session(user_id=user_uuid, title="New Chat")
        recipient_session_id = uuid.UUID(new_session["id"])  # type: ignore[index]
        await update_linked_session_partner_session_for_source(
            relationship_id=relationship_id, source_session_id=sender_session_id, partner_session_id=recipient_session_id
        )

    # Insert delivered message into recipient chat as assistant
    created = await save_message(
        user_id=user_uuid, session_id=recipient_session_id, role="assistant", content=req.get("content", "")
    )
    await update_session_last_message(session_id=recipient_session_id, content=req.get("content", ""))
    await touch_session(session_id=recipient_session_id)

    await mark_accepted_and_attach(
        request_id=request_id,
        recipient_session_id=recipient_session_id,
        created_message_id=uuid.UUID(created["id"])  # type: ignore[index]
    )

    return {"success": True, "recipient_session_id": str(recipient_session_id)}


@router.post("/request/stream")
async def partner_request_stream(body: PartnerRequestBody, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")
    print(f"[PartnerStream] START user={user_uuid} session={body.session_id} msg_len={len((body.message or '').strip())}")

    # Guard: session ownership
    await assert_session_owned_by_user(user_id=user_uuid, session_id=body.session_id)

    # Relationship + partner
    linked, relationship_id, _ = await get_link_status_for_user(user_id=user_uuid)
    if not linked or not relationship_id:
        raise HTTPException(status_code=400, detail="User is not linked to a partner")
    partner_user_id = await get_partner_user_id(user_id=user_uuid)
    if not partner_user_id:
        raise HTTPException(status_code=400, detail="Could not find partner for the linked relationship")
    print(f"[PartnerStream] LINK OK relationship={relationship_id} partner_user_id={partner_user_id}")

    # Ensure mapping row; detect if recipient session already exists (direct delivery mode)
    linked_row = await get_linked_session_by_relationship_and_source_session(
        relationship_id=relationship_id, source_session_id=body.session_id
    )
    recipient_session_id: uuid.UUID | None = None
    if not linked_row:
        await create_linked_session(
            relationship_id=relationship_id,
            user_a_id=user_uuid,
            user_b_id=partner_user_id,
            user_a_personal_session_id=body.session_id,
            user_b_personal_session_id=None,
        )
        print("[PartnerStream] Linked session row created (source->partner mapping stub)")
    else:
        try:
            src = str(body.session_id)
            a_sid = linked_row.get("user_a_personal_session_id")
            b_sid = linked_row.get("user_b_personal_session_id")
            if a_sid and src == a_sid and b_sid:
                recipient_session_id = uuid.UUID(b_sid)
            elif b_sid and src == b_sid and a_sid:
                recipient_session_id = uuid.UUID(a_sid)
            else:
                recipient_session_id = None
        except Exception:
            recipient_session_id = None

    # Load context (sender recent messages)
    try:
        current_history = await list_messages_for_session(user_id=user_uuid, session_id=body.session_id, limit=50)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to load chat history: {e}")

    # Mode select: if recipient session already linked → direct delivery; else pre-create request
    created_request_id: uuid.UUID | None = None
    if recipient_session_id is None:
        try:
            created_req = await create_partner_request(
                relationship_id=relationship_id,
                sender_user_id=user_uuid,
                recipient_user_id=partner_user_id,
                sender_session_id=body.session_id,
                content=body.message.strip(),
            )
            created_request_id = uuid.UUID(created_req["id"])  # type: ignore[index]
            print(f"[PartnerStream] REQUEST PRE-CREATED id={created_request_id}")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to create partner request: {e}")
    else:
        print(f"[PartnerStream] DIRECT MODE recipient_session_id={recipient_session_id}")

    def iter_sse():
        # Anti-buffering prelude
        yield (":" + " " * 2048 + "\n\n").encode()
        parts = []
        final_text = ""
        try:
            # Build prompt for partner message generation using PersonalAgent
            input_messages = []
            if current_history:
                text = "PARTNER MESSAGE CONTEXT:\n" + "\n".join([
                    ("User" if m.get("role") == "user" else "Assistant") + f": {m.get('content','')}" for m in current_history
                ])
                input_messages.append({"role": "system", "content": text})
            input_messages.append({"role": "user", "content": body.message})

            print("[PartnerStream] OPEN LLM stream")
            with agent.client.responses.stream(model=agent.model, input=input_messages) as stream:  # type: ignore[attr-defined]
                try:
                    token_count = 0
                    for delta in stream.text_deltas:  # type: ignore[attr-defined]
                        if delta:
                            parts.append(delta)
                            token_count += 1
                            if token_count % 10 == 0:
                                print(f"[PartnerStream] TOKENS so far={token_count}")
                            yield f"event: token\ndata: {json.dumps(delta)}\n\n".encode()
                except Exception:
                    for event in stream:
                        ev_type = getattr(event, "type", "")
                        if ev_type.endswith("output_text.delta"):
                            delta = getattr(event, "delta", "") or ""
                            if delta:
                                parts.append(delta)
                                yield f"event: token\ndata: {json.dumps(delta)}\n\n".encode()
                final = stream.get_final_response()
                final_text = getattr(final, "output_text", None) or "".join(parts)
                print(f"[PartnerStream] LLM stream DONE tokens={len(parts)} final_len={len(final_text)}")

            # Deliver based on mode
            final_content = (final_text or "").strip() or body.message.strip()
            if created_request_id is not None:
                # Update the pending request content so recipient sees the final version
                try:
                    asyncio.run(update_content(request_id=created_request_id, content=final_content))
                    print(f"[PartnerStream] REQUEST UPDATED id={created_request_id} content_len={len(final_content)}")
                except Exception as e:
                    yield f"event: error\ndata: {json.dumps(str(e))}\n\n".encode()
                    return
            else:
                # Direct insert into recipient's personal session
                try:
                    created = asyncio.run(save_message(
                        user_id=partner_user_id,
                        session_id=recipient_session_id,  # type: ignore[arg-type]
                        role="assistant",
                        content=final_content,
                    ))
                    asyncio.run(update_session_last_message(session_id=recipient_session_id, content=final_content))  # type: ignore[arg-type]
                    asyncio.run(touch_session(session_id=recipient_session_id))  # type: ignore[arg-type]
                    print(f"[PartnerStream] DIRECT DELIVERED message_id={created.get('id')}")
                except Exception as e:
                    print(f"[PartnerStream] DIRECT DELIVERY ERROR: {e}")
                    yield f"event: error\ndata: {json.dumps(str(e))}\n\n".encode()
                    return

            yield b"event: done\ndata: {}\n\n"
            print("[PartnerStream] DONE sent to client")
        except Exception as e:
            print(f"[PartnerStream] ERROR: {e}")
            yield f"event: error\ndata: {json.dumps(str(e))}\n\n".encode()
        finally:
            print("[PartnerStream] STREAM CLOSED (client disconnect or finished)")

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


