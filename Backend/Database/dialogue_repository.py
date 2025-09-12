import uuid
from datetime import datetime, timezone
from typing import List, Optional
from starlette.concurrency import run_in_threadpool
from .supabase_client import supabase

DIALOGUE_SESSIONS_TABLE = "dialogue_sessions"
DIALOGUE_MESSAGES_TABLE = "dialogue_messages"
DIALOGUE_REQUESTS_TABLE = "dialogue_requests"


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


"""Dialogue repository helpers for sessions and messages."""

# Restore: Get or create a dialogue session for a relationship (legacy global-by-relationship)
async def get_or_create_dialogue_session(*, relationship_id: uuid.UUID) -> dict:
    relationship_id_str = str(relationship_id)

    # First, try to get existing session
    def _select_existing():
        return (supabase
                .table(DIALOGUE_SESSIONS_TABLE)
                .select("*")
                .eq("relationship_id", relationship_id_str)
                .limit(1)
                .execute()
                )

    res = await run_in_threadpool(_select_existing)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select dialogue session failed: {res.error}")

    # Return existing session if found
    if res.data:
        return res.data[0]

    # Create new session if none exists
    payload = {
        "relationship_id": relationship_id_str,
        "last_message_at": _utc_now_iso(),
    }

    def _insert():
        return supabase.table(DIALOGUE_SESSIONS_TABLE).insert(payload).execute()

    create_res = await run_in_threadpool(_insert)
    if getattr(create_res, "error", None):
        raise RuntimeError(f"Supabase insert dialogue session failed: {create_res.error}")
    return create_res.data[0]


# Create a new dialogue session unconditionally (for per-chat mapping)
async def create_new_dialogue_session(*, relationship_id: uuid.UUID) -> dict:
    payload = {
        "relationship_id": str(relationship_id),
        "last_message_at": _utc_now_iso(),
    }

    def _insert():
        return supabase.table(DIALOGUE_SESSIONS_TABLE).insert(payload).execute()

    res = await run_in_threadpool(_insert)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase insert dialogue session failed: {res.error}")
    return res.data[0]


# Check if there's already a pending request for this relationship
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


# Create a dialogue request when user sends summary to partner
async def create_dialogue_request(*, sender_user_id: uuid.UUID, recipient_user_id: uuid.UUID,
                                sender_session_id: uuid.UUID, request_content: str,
                                relationship_id: uuid.UUID) -> dict:
    # Check if there's already a pending request for this relationship
    if await has_pending_request_for_relationship(relationship_id=relationship_id):
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


# Create a dialogue message (appears in dialogue view)
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

    # Update dialogue session last_message_at
    await _update_dialogue_session_timestamp(dialogue_session_id)

    return res.data[0]


# Get all dialogue messages for a relationship
async def get_dialogue_messages(*, relationship_id: uuid.UUID, limit: int = 100, offset: int = 0) -> List[dict]:
    relationship_id_str = str(relationship_id)

    # Get dialogue session first (legacy global-by-relationship)
    dialogue_session = await get_or_create_dialogue_session(relationship_id=relationship_id)
    dialogue_session_id = dialogue_session["id"]

    def _select():
        return (supabase
                .table(DIALOGUE_MESSAGES_TABLE)
                .select("*")
                .eq("dialogue_session_id", dialogue_session_id)
                .order("created_at", desc=False)
                .limit(limit)
                .offset(offset)
                .execute()
                )

    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select dialogue messages failed: {res.error}")
    return res.data


# List messages by dialogue_session_id (per-chat mapping path)
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


# Get dialogue session for a relationship
async def get_dialogue_session_by_relationship(*, relationship_id: uuid.UUID) -> Optional[dict]:
    relationship_id_str = str(relationship_id)

    def _select():
        return (supabase
                .table(DIALOGUE_SESSIONS_TABLE)
                .select("*")
                .eq("relationship_id", relationship_id_str)
                .limit(1)
                .execute()
                )

    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select dialogue session failed: {res.error}")

    return res.data[0] if res.data else None


# Helper function to update dialogue session timestamp
async def _update_dialogue_session_timestamp(dialogue_session_id: uuid.UUID) -> None:
    dialogue_session_id_str = str(dialogue_session_id)

    def _update():
        return (supabase
                .table(DIALOGUE_SESSIONS_TABLE)
                .update({"last_message_at": _utc_now_iso()})
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


# Get dialogue history for relationship context (simplified version)
async def get_dialogue_history_for_context(*, user_id: uuid.UUID, limit: int = 30) -> List[dict]:
    """Get dialogue messages for relationship context in personal/dialogue chats"""
    from .link_repository import get_link_status_for_user

    # Get user's relationship
    linked, relationship_id = await get_link_status_for_user(user_id = user_id)
    if not linked or not relationship_id:
        return []

    # Get dialogue messages for this relationship
    try:
        return await get_dialogue_messages(relationship_id = relationship_id, limit = limit)
    except Exception:
        # If no dialogue exists yet, return empty list
        return []

