import uuid
from datetime import datetime, timezone
from typing import Optional
from starlette.concurrency import run_in_threadpool
from .supabase_client import supabase

LINKED_SESSIONS_TABLE = "linked_sessions"


# Creates (or upserts) a record that ties each partner's personal session under a relationship
async def create_linked_session(*, relationship_id: uuid.UUID, user_a_id: uuid.UUID,
                               user_b_id: uuid.UUID, user_a_personal_session_id: uuid.UUID,
                               user_b_personal_session_id: Optional[uuid.UUID]) -> dict:
    payload = {
        "relationship_id": str(relationship_id),
        "user_a_id": str(user_a_id),
        "user_b_id": str(user_b_id),
        "user_a_personal_session_id": str(user_a_personal_session_id),
        "user_b_personal_session_id": str(user_b_personal_session_id) if user_b_personal_session_id else None,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    def _upsert():
        return supabase.table(LINKED_SESSIONS_TABLE).upsert(
            payload,
            on_conflict = "relationship_id,user_a_personal_session_id",
        ).execute()

    res = await run_in_threadpool(_upsert)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase upsert linked session failed: {res.error}")
    return res.data[0]

# Finds, for a given relationship and personal session, the linked row (or returns None)
async def get_linked_session_by_relationship_and_source_session(*, relationship_id: uuid.UUID, source_session_id: uuid.UUID) -> Optional[dict]:
    relationship_id_str = str(relationship_id)
    source_session_id_str = str(source_session_id)
    def _select():
        return (supabase
                .table(LINKED_SESSIONS_TABLE)
                .select("*")
                .eq("relationship_id", relationship_id_str)
                .or_(f"user_a_personal_session_id.eq.{source_session_id_str},user_b_personal_session_id.eq.{source_session_id_str}")
                .limit(1)
                .execute()
                )
    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select linked session by relationship and session failed: {res.error}")
    return res.data[0] if res.data else None

# Update partner session for a specific source session row (first-time accept case)
async def update_linked_session_partner_session_for_source(*, relationship_id: uuid.UUID, source_session_id: uuid.UUID, partner_session_id: uuid.UUID) -> None:
    relationship_id_str = str(relationship_id)
    source_session_id_str = str(source_session_id)
    partner_session_id_str = str(partner_session_id)
    def _update():
        return (supabase
                .table(LINKED_SESSIONS_TABLE)
                .update({"user_b_personal_session_id": partner_session_id_str})
                .eq("relationship_id", relationship_id_str)
                .eq("user_a_personal_session_id", source_session_id_str)
                .execute()
                )
    res = await run_in_threadpool(_update)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase update linked session partner session by source failed: {res.error}")


# Count accepted pairs (both partners have personal sessions linked)
async def count_accepted_linked_pairs(*, relationship_id: uuid.UUID) -> int:
    relationship_id_str = str(relationship_id)
    def _select():
        return (
            supabase
            .table(LINKED_SESSIONS_TABLE)
            .select("user_a_personal_session_id,user_b_personal_session_id")
            .eq("relationship_id", relationship_id_str)
            .execute()
        )
    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select accepted pairs failed: {res.error}")
    rows = getattr(res, "data", []) or []
    count = 0
    for row in rows:
        if row.get("user_a_personal_session_id") and row.get("user_b_personal_session_id"):
            count += 1
    return count


# Count total personal sessions in a relationship (unique sessions across both partners)
async def count_relationship_personal_sessions(*, relationship_id: uuid.UUID) -> int:
    relationship_id_str = str(relationship_id)
    def _select():
        return (
            supabase
            .table(LINKED_SESSIONS_TABLE)
            .select("user_a_personal_session_id,user_b_personal_session_id")
            .eq("relationship_id", relationship_id_str)
            .execute()
        )
    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select linked sessions failed: {res.error}")
    seen = set()
    for row in (res.data or []):
        a = row.get("user_a_personal_session_id")
        b = row.get("user_b_personal_session_id")
        if a:
            seen.add(a)
        if b:
            seen.add(b)
    return len(seen)


# Remove any linked_sessions rows that reference a personal session
async def remove_links_for_personal_session(*, session_id: uuid.UUID) -> int:
    session_id_str = str(session_id)
    def _delete():
        return (
            supabase
            .table(LINKED_SESSIONS_TABLE)
            .delete()
            .or_(f"user_a_personal_session_id.eq.{session_id_str},user_b_personal_session_id.eq.{session_id_str}")
            .execute()
        )
    res = await run_in_threadpool(_delete)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase delete linked sessions by personal session failed: {res.error}")
    try:
        return len(res.data or [])
    except Exception:
        return 0