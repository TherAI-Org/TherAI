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
    if not hasattr(res, 'data') or not res.data:
        raise RuntimeError("Supabase insert returned no data")
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
    if not hasattr(res, 'data'):
        raise RuntimeError("Supabase select returned invalid response")
    return res.data or []