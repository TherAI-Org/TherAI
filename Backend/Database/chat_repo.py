import uuid
from typing import List
from starlette.concurrency import run_in_threadpool
from .supabase_client import supabase

TABLE_NAME = "user_chat_messages"
SESSIONS_TABLE = "user_chat_sessions"

# Save a chat message of a specific user and session
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
    if not hasattr(res, 'data') or not res.data:
        raise RuntimeError("Supabase insert returned no data")
    return res.data[0]

# List user/assistant messages for a specific session (from oldest to newest)
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

# Update the session's last_message_content when a user message is saved
async def update_session_last_message(*, session_id: uuid.UUID, content: str) -> None:
    def _update():
        return (
            supabase
            .table(SESSIONS_TABLE)
            .update({"last_message_content": content})
            .eq("id", str(session_id))
            .execute()
        )
    res = await run_in_threadpool(_update)
    if getattr(res, "error", None):
        raise RuntimeError(f"Failed to update session last_message_content: {res.error}")


# Delete all messages for a specific user's session. Returns number of deleted rows
async def delete_messages_for_session(*, user_id: uuid.UUID, session_id: uuid.UUID) -> int:
    def _delete():
        return (
            supabase
            .table(TABLE_NAME)
            .delete()
            .eq("user_id", str(user_id))
            .eq("session_id", str(session_id))
            .execute()
        )
    res = await run_in_threadpool(_delete)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase delete messages failed: {res.error}")
    # supabase-py returns data of deleted rows when RLS permits; count via len(data) if present
    try:
        return len(res.data or [])
    except Exception:
        return 0


# Check if a session has any messages (returns True if session is empty, False if it has messages)
async def is_session_empty(*, session_id: uuid.UUID) -> bool:
    def _count():
        return (
            supabase
            .table(TABLE_NAME)
            .select("id", count="exact")
            .eq("session_id", str(session_id))
            .limit(1)
            .execute()
        )
    res = await run_in_threadpool(_count)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase count messages failed: {res.error}")
    # Check if any messages exist
    return len(res.data or []) == 0


# Count the number of user messages in a session
async def count_user_messages(*, session_id: uuid.UUID) -> int:
    def _count():
        return (
            supabase
            .table(TABLE_NAME)
            .select("id", count="exact")
            .eq("session_id", str(session_id))
            .eq("role", "user")
            .execute()
        )
    res = await run_in_threadpool(_count)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase count user messages failed: {res.error}")
    # Return the count
    return len(res.data or [])


# Get the last N user messages from a session (for title generation)
async def get_recent_user_messages(*, session_id: uuid.UUID, limit: int = 2) -> List[str]:
    def _select():
        return (
            supabase
            .table(TABLE_NAME)
            .select("content")
            .eq("session_id", str(session_id))
            .eq("role", "user")
            .order("created_at", desc=False)
            .limit(limit)
            .execute()
        )
    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select user messages failed: {res.error}")
    return [row["content"] for row in res.data or []]