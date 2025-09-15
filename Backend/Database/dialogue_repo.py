import uuid
from datetime import datetime, timezone
from typing import List, Optional
from starlette.concurrency import run_in_threadpool
from .supabase_client import supabase

DIALOGUE_SESSIONS_TABLE = "dialogue_sessions"
DIALOGUE_MESSAGES_TABLE = "dialogue_messages"
DIALOGUE_REQUESTS_TABLE = "dialogue_requests"


# Create a brand-new dialogue session for a specific personal chat (used for first-time or new sessions)
async def create_new_dialogue_session(*, relationship_id: uuid.UUID) -> dict:
    payload = {
        "relationship_id": str(relationship_id),
        "last_message_at": datetime.now(timezone.utc).isoformat(),
    }
    def _insert():
        return supabase.table(DIALOGUE_SESSIONS_TABLE).insert(payload).execute()
    res = await run_in_threadpool(_insert)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase insert dialogue session failed: {res.error}")
    return res.data[0]

# Check for pending/delivered dialogue request for a specific relationship (check against double taps, slow networks, client re-sends, etc)
async def has_pending_request_for_relationship(*, relationship_id: uuid.UUID) -> bool:
    relationship_id_str = str(relationship_id)
    def _select():
        return (supabase
                .table(DIALOGUE_REQUESTS_TABLE)
                .select("id")
                .eq("relationship_id", relationship_id_str)
                .in_("status", ["pending", "delivered"])
                .limit(1)
                .execute()
                )
    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select pending request check failed: {res.error}")
    return len(res.data) > 0

# Get the most recent active (pending or delivered) request for a relationship
async def get_active_request_for_relationship(*, relationship_id: uuid.UUID) -> Optional[dict]:
    relationship_id_str = str(relationship_id)
    def _select():
        return (supabase
                .table(DIALOGUE_REQUESTS_TABLE)
                .select("*")
                .eq("relationship_id", relationship_id_str)
                .in_("status", ["pending", "delivered"])
                .order("created_at", desc = True)
                .limit(1)
                .execute()
                )
    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select active request failed: {res.error}")
    return res.data[0] if res.data else None

# Create a pending dialogue request (on first-time 'send to partner's)
async def create_dialogue_request(*, sender_user_id: uuid.UUID, recipient_user_id: uuid.UUID,
                                  sender_session_id: uuid.UUID, request_content: str,
                                  relationship_id: uuid.UUID) -> dict:
    if await has_pending_request_for_relationship(relationship_id = relationship_id):
        raise ValueError("A pending request already exists for this relationship")
    payload = {
        "relationship_id": str(relationship_id),
        "sender_user_id": str(sender_user_id),
        "recipient_user_id": str(recipient_user_id),
        "sender_session_id": str(sender_session_id),
        "request_content": request_content,
        "status": "pending",
    }
    def _insert():
        return supabase.table(DIALOGUE_REQUESTS_TABLE).insert(payload).execute()
    res = await run_in_threadpool(_insert)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase insert dialogue request failed: {res.error}")
    return res.data[0]

# Overwrite the content of an existing request (used when the same session updates it)
async def update_dialogue_request_content(*, request_id: uuid.UUID, request_content: str) -> None:
    request_id_str = str(request_id)
    def _update():
        return (supabase
                .table(DIALOGUE_REQUESTS_TABLE)
                .update({
                    "request_content": request_content,
                })
                .eq("id", request_id_str)
                .execute()
                )
    res = await run_in_threadpool(_update)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase update dialogue request content failed: {res.error}")

# Save a new dialogue message of a specific dialogue session and user
async def create_dialogue_message(*, dialogue_session_id: uuid.UUID, request_id: Optional[uuid.UUID],
                                content: str, sender_user_id: uuid.UUID,
                                message_type: str = "request") -> dict:
    payload = {
        "dialogue_session_id": str(dialogue_session_id),
        "request_id": str(request_id) if request_id else None,
        "content": content,
        "sender_user_id": str(sender_user_id),
        "message_type": message_type,
    }
    def _insert():
        return supabase.table(DIALOGUE_MESSAGES_TABLE).insert(payload).execute()
    res = await run_in_threadpool(_insert)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase insert dialogue message failed: {res.error}")
    await _update_dialogue_session_timestamp(dialogue_session_id)  # Update dialogue session last_message_at
    return res.data[0]

# Update the latest request-type message's content for a dialogue session
async def update_latest_request_message_content(*, dialogue_session_id: uuid.UUID, content: str) -> None:
    dialogue_session_id_str = str(dialogue_session_id)
    def _select():
        return (supabase
                .table(DIALOGUE_MESSAGES_TABLE)
                .select("id")
                .eq("dialogue_session_id", dialogue_session_id_str)
                .eq("message_type", "request")
                .order("created_at", desc=True)
                .limit(1)
                .execute()
                )
    sel = await run_in_threadpool(_select)
    if getattr(sel, "error", None):
        raise RuntimeError(f"Supabase select latest request message failed: {sel.error}")
    if not sel.data:
        return
    message_id = sel.data[0]["id"]
    def _update():
        return (supabase
                .table(DIALOGUE_MESSAGES_TABLE)
                .update({"content": content})
                .eq("id", message_id)
                .execute()
                )
    res = await run_in_threadpool(_update)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase update latest request message failed: {res.error}")

# List Partner A and Partner B messages for a specific dialogue session
async def list_dialogue_messages_by_session(*, dialogue_session_id: uuid.UUID, limit: int = 100, offset: int = 0) -> List[dict]:
    def _select():
        return (supabase
                .table(DIALOGUE_MESSAGES_TABLE)
                .select("*")
                .eq("dialogue_session_id", str(dialogue_session_id))
                .order("created_at", desc=False)
                .limit(limit)
                .offset(offset)
                .execute()
                )
    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select dialogue messages by session failed: {res.error}")
    return res.data


# Get pending requests for a user (only show requests TO the user, not FROM the user)
async def get_pending_requests_for_user(*, user_id: uuid.UUID, limit: int = 50) -> List[dict]:
    user_id_str = str(user_id)
    def _select():
        return (supabase
                .table(DIALOGUE_REQUESTS_TABLE)
                .select("*")
                .eq("recipient_user_id", user_id_str)  # Only show requests TO the user
                .in_("status", ["pending", "delivered"])  # Include pending and delivered, but not accepted
                .order("created_at", desc=True)
                .limit(limit)
                .execute()
                )
    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select pending requests failed: {res.error}")
    return res.data


# Mark a request as delivered when partner sees it
async def mark_request_as_delivered(*, request_id: uuid.UUID) -> None:
    request_id_str = str(request_id)
    def _update():
        return (supabase
                .table(DIALOGUE_REQUESTS_TABLE)
                .update({"status": "delivered"})
                .eq("id", request_id_str)
                .execute()
                )
    res = await run_in_threadpool(_update)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase update request status failed: {res.error}")


# Mark a request as accepted when partner engages with the dialogue
async def mark_request_as_accepted(*, request_id: uuid.UUID) -> None:
    request_id_str = str(request_id)
    def _update():
        return (supabase
                .table(DIALOGUE_REQUESTS_TABLE)
                .update({"status": "accepted"})
                .eq("id", request_id_str)
                .execute()
                )

    res = await run_in_threadpool(_update)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase update request status to accepted failed: {res.error}")

# Helper function to update dialogue session timestamp
async def _update_dialogue_session_timestamp(dialogue_session_id: uuid.UUID) -> None:
    dialogue_session_id_str = str(dialogue_session_id)
    def _update():
        return (supabase
                .table(DIALOGUE_SESSIONS_TABLE)
                .update({"last_message_at": datetime.now(timezone.utc).isoformat()})
                .eq("id", dialogue_session_id_str)
                .execute()
                )
    res = await run_in_threadpool(_update)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase update dialogue session timestamp failed: {res.error}")

# Get request by ID (for linking messages to requests)
async def get_dialogue_request_by_id(*, request_id: uuid.UUID) -> Optional[dict]:
    request_id_str = str(request_id)
    def _select():
        return (supabase
                .table(DIALOGUE_REQUESTS_TABLE)
                .select("*")
                .eq("id", request_id_str)
                .limit(1)
                .execute()
                )

    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select dialogue request failed: {res.error}")
    return res.data[0] if res.data else None