import uuid
from typing import List
from starlette.concurrency import run_in_threadpool
from .supabase_client import supabase

TABLE_NAME = "user_chat_messages"


# Save a chat message row for a user and session
async def save_message(*, user_id: uuid.UUID, session_id: uuid.UUID, role: str, content: str) -> dict:
    payload = {
        "user_id": str(user_id),
        "session_id": str(session_id),
        "role": role,
        "content": content,
    }

    def _insert():
        return supabase.table(TABLE_NAME).insert(payload).execute()
    res = await run_in_threadpool(_insert)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase insert failed: {res.error}")
    return res.data[0]

# List messages for a session for a user ordered by creation time
async def list_messages_for_session(*, user_id: uuid.UUID, session_id: uuid.UUID, limit: int = 100, offset: int = 0) -> List[dict]:
    def _select():
        return (
            supabase
            .table(TABLE_NAME)
            .select("*")
            .eq("user_id", str(user_id))
            .eq("session_id", str(session_id))
            .order("created_at", desc = False)
            .range(offset, offset + max(limit - 1, 0))
            .execute()
        )

    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select failed: {res.error}")
    return res.data


# Get partner's personal chat history via relationship
async def get_partner_chat_history(*, user_id: uuid.UUID, limit: int = 50) -> List[dict]:
    """Get the partner's recent personal chat messages for relationship context"""
    from .link_repository import get_link_status_for_user

    # First, get the relationship and partner info
    linked, relationship_id = await get_link_status_for_user(user_id = user_id)
    if not linked or not relationship_id:
        return []

    # Get partner's user_id from paired_accounts
    def _get_partner_id():
        return (
            supabase
            .table("paired_accounts")
            .select("partner_a_user_id, partner_b_user_id")
            .eq("id", str(relationship_id))
            .limit(1)
            .execute()
        )

    partner_res = await run_in_threadpool(_get_partner_id)
    if getattr(partner_res, "error", None) or not partner_res.data:
        return []

    # Determine partner's user_id
    partner_data = partner_res.data[0]
    user_id_str = str(user_id)
    if partner_data["partner_a_user_id"] == user_id_str:
        partner_user_id = partner_data["partner_b_user_id"]
    else:
        partner_user_id = partner_data["partner_a_user_id"]

    # Get partner's recent messages from their most recent session
    def _get_partner_recent_session():
        return (
            supabase
            .table("user_chat_sessions")
            .select("id")
            .eq("user_id", partner_user_id)
            .order("last_message_at", desc = True)
            .limit(1)
            .execute()
        )

    session_res = await run_in_threadpool(_get_partner_recent_session)
    if getattr(session_res, "error", None) or not session_res.data:
        return []

    partner_session_id = session_res.data[0]["id"]

    # Get recent messages from partner's session
    def _get_partner_messages():
        return (
            supabase
            .table(TABLE_NAME)
            .select("*")
            .eq("user_id", partner_user_id)
            .eq("session_id", partner_session_id)
            .order("created_at", desc = True)
            .limit(limit)
            .execute()
        )

    messages_res = await run_in_threadpool(_get_partner_messages)
    if getattr(messages_res, "error", None):
        raise RuntimeError(f"Supabase select partner messages failed: {messages_res.error}")

    # Return in chronological order (oldest first)
    return list(reversed(messages_res.data))