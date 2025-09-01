import uuid
from datetime import datetime, timezone
from typing import List, Optional
from starlette.concurrency import run_in_threadpool
from .supabase_client import supabase

SESSIONS_TABLE = "user_chat_sessions"

def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


async def create_session(*, user_id: uuid.UUID, title: Optional[str] = None) -> dict:
    payload = {
        "user_id": str(user_id),
        "title": title,
        "last_message_at": _utc_now_iso(),
    }

    def _insert():
        return supabase.table(SESSIONS_TABLE).insert(payload).execute()

    res = await run_in_threadpool(_insert)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase insert session failed: {res.error}")
    return res.data[0]


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
    return res.data


async def get_or_create_default_session(*, user_id: uuid.UUID) -> dict:
    """Find a per-user default session by title, or create one.
    We only create it on first message flow in the calling endpoint.
    """

    def _select():
        return (
            supabase
            .table(SESSIONS_TABLE)
            .select("*")
            .eq("user_id", str(user_id))
            .eq("title", "Default")
            .limit(1)
            .execute()
        )

    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select default session failed: {res.error}")
    if res.data:
        return res.data[0]
    return await create_session(user_id=user_id, title="Default")


async def touch_session(*, session_id: uuid.UUID) -> None:
    """Update session 'last_message_at' to now."""

    def _update():
        return (
            supabase
            .table(SESSIONS_TABLE)
            .update({"last_message_at": _utc_now_iso()})
            .eq("id", str(session_id))
            .execute()
        )

    res = await run_in_threadpool(_update)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase update session failed: {res.error}")


async def assert_session_owned_by_user(*, user_id: uuid.UUID, session_id: uuid.UUID) -> None:
    """Raise if the given session is not owned by the user."""

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


