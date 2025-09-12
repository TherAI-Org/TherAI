import uuid
from datetime import datetime, timezone
from typing import List, Optional
from starlette.concurrency import run_in_threadpool
from .supabase_client import supabase

SESSIONS_TABLE = "user_chat_sessions"


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

# Create a new chat session row for the user with the given optional title
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
    if not hasattr(res, 'data') or not res.data:
        raise RuntimeError("Supabase insert session returned no data")
    return res.data[0]

# List chat sessions for a user ordered by recent activity and creation time
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

# Find the user's default session by title or create it if missing
async def get_or_create_default_session(*, user_id: uuid.UUID) -> dict:
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

# Bump the session's last_message_at timestamp to now
async def touch_session(*, session_id: uuid.UUID) -> None:
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

async def session_exists(*, user_id: uuid.UUID, session_id: uuid.UUID) -> bool:
    """Check if a session exists without raising an error"""
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

    try:
        res = await run_in_threadpool(_select)
        return getattr(res, "data", None) is not None and len(res.data) > 0
    except Exception:
        return False

# Delete a chat session and all its messages
async def delete_session(*, user_id: uuid.UUID, session_id: uuid.UUID) -> None:
    # First check if the session exists
    if not await session_exists(user_id=user_id, session_id=session_id):
        print(f"ℹ️ Session {session_id} not found, considering it already deleted")
        return  # Session doesn't exist, consider it already deleted
    
    # Verify the session belongs to the user (this will raise PermissionError if not)
    await assert_session_owned_by_user(user_id=user_id, session_id=session_id)
    
    # Delete all messages in the session
    def _delete_messages():
        return (
            supabase
            .table("user_chat_messages")
            .delete()
            .eq("session_id", str(session_id))
            .eq("user_id", str(user_id))
            .execute()
        )
    
    try:
        res = await run_in_threadpool(_delete_messages)
        if hasattr(res, 'error') and res.error:
            raise RuntimeError(f"Supabase delete messages failed: {res.error}")
        print(f"✅ Deleted messages for session {session_id}")
    except Exception as e:
        print(f"⚠️ Error deleting messages: {e}")
        # Continue with session deletion even if messages fail
    
    # Delete the session itself
    def _delete_session():
        return (
            supabase
            .table(SESSIONS_TABLE)
            .delete()
            .eq("id", str(session_id))
            .eq("user_id", str(user_id))
            .execute()
        )
    
    try:
        res = await run_in_threadpool(_delete_session)
        if hasattr(res, 'error') and res.error:
            raise RuntimeError(f"Supabase delete session failed: {res.error}")
        print(f"✅ Deleted session {session_id}")
    except Exception as e:
        print(f"❌ Error deleting session: {e}")
        raise RuntimeError(f"Failed to delete session: {e}")

# Rename a chat session
async def rename_session(*, user_id: uuid.UUID, session_id: uuid.UUID, new_title: str) -> None:
    # First verify the session belongs to the user
    await assert_session_owned_by_user(user_id=user_id, session_id=session_id)
    
    # If new_title is empty, set to None (NULL in database)
    title_value = None if not new_title.strip() else new_title.strip()
    
    def _update():
        return (
            supabase
            .table(SESSIONS_TABLE)
            .update({"title": title_value})
            .eq("id", str(session_id))
            .eq("user_id", str(user_id))
            .execute()
        )
    
    try:
        res = await run_in_threadpool(_update)
        if hasattr(res, 'error') and res.error:
            raise RuntimeError(f"Supabase rename session failed: {res.error}")
        print(f"✅ Renamed session {session_id} to '{title_value or 'NULL'}'")
    except Exception as e:
        print(f"❌ Error renaming session: {e}")
        raise RuntimeError(f"Failed to rename session: {e}")


