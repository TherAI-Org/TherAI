import uuid
from datetime import datetime, timezone
from typing import List, Optional
from starlette.concurrency import run_in_threadpool
from .supabase_client import supabase

SESSIONS_TABLE = "user_chat_sessions"


# Create a new chat session row for the user with the given optional title
async def create_session(*, user_id: uuid.UUID, title: Optional[str] = None) -> dict:
    payload = {
        "user_id": str(user_id),
        "title": title,
        "last_message_at": datetime.now(timezone.utc).isoformat(),
    }
    def _insert():
        return supabase.table(SESSIONS_TABLE).insert(payload).execute()
    res = await run_in_threadpool(_insert)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase insert session failed: {res.error}")
    if not hasattr(res, 'data') or not res.data:
        raise RuntimeError("Supabase insert session returned no data")
    return res.data[0]

# List chat sessions for a specific user ordered by recent activity and creation time
async def list_sessions_for_user(*, user_id: uuid.UUID, limit: int = 100, offset: int = 0) -> List[dict]:
    def _select():
        return (
            supabase
            .table(SESSIONS_TABLE)
            .select("*")
            .eq("user_id", str(user_id))
            .order("last_message_at", desc=True)
            .order("created_at", desc=True)
            .range(offset, offset + max(limit - 1, 0))
            .execute()
        )
    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select sessions failed: {res.error}")
    if not hasattr(res, 'data'):
        raise RuntimeError("Supabase select sessions returned invalid response")
    return res.data or []

# Bump the session's last_message_at timestamp to now (needed to order sessions by recent activity)
async def touch_session(*, session_id: uuid.UUID) -> None:
    def _update():
        return (
            supabase
            .table(SESSIONS_TABLE)
            .update({"last_message_at": datetime.now(timezone.utc).isoformat()})
            .eq("id", str(session_id))
            .execute()
        )
    res = await run_in_threadpool(_update)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase update session failed: {res.error}")

# Ensure the session belongs to the given user or raise PermissionError
async def assert_session_owned_by_user(*, user_id: uuid.UUID, session_id: uuid.UUID) -> None:
    def _select():
        return (
            supabase
            .table(SESSIONS_TABLE)
            .select("id")
            .eq("id", str(session_id))
            .eq("user_id", str(user_id))
            .limit(1)
            .execute()
        )
    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase verify session failed: {res.error}")
    if not res.data:
        raise PermissionError("Session not found or not owned by user")