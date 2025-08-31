import uuid
from typing import List
from starlette.concurrency import run_in_threadpool
from .supabase_client import supabase

TABLE_NAME = "user_chat_messages"

async def save_message(*, user_id: uuid.UUID, role: str, content: str) -> dict:
    payload = {"user_id": str(user_id), "role": role, "content": content}

    def _insert():
        return supabase.table(TABLE_NAME).insert(payload).execute()

    res = await run_in_threadpool(_insert)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase insert failed: {res.error}")
    return res.data[0]

async def list_messages_for_user(*, user_id: uuid.UUID, limit: int = 100, offset: int = 0) -> List[dict]:
    def _select():
        return (
            supabase
            .table(TABLE_NAME)
            .select("*")
            .eq("user_id", str(user_id))
            .order("created_at", desc = False)
            .range(offset, offset + max(limit - 1, 0))
            .execute()
        )

    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select failed: {res.error}")
    return res.data