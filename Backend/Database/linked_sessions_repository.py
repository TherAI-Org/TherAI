import uuid
from datetime import datetime, timezone
from typing import Optional
from starlette.concurrency import run_in_threadpool
from .supabase_client import supabase

LINKED_SESSIONS_TABLE = "linked_sessions"


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# Create a new linked session (first time "Send to Partner")
async def create_linked_session(*, relationship_id: uuid.UUID, user_a_id: uuid.UUID,
                               user_b_id: uuid.UUID, user_a_personal_session_id: uuid.UUID,
                               user_b_personal_session_id: Optional[uuid.UUID], dialogue_session_id: uuid.UUID) -> dict:
    """Create a new linked session that bonds personal sessions with dialogue session"""
    payload = {
        "relationship_id": str(relationship_id),
        "user_a_id": str(user_a_id),
        "user_b_id": str(user_b_id),
        "user_a_personal_session_id": str(user_a_personal_session_id),
        "user_b_personal_session_id": str(user_b_personal_session_id) if user_b_personal_session_id else None,
        "dialogue_session_id": str(dialogue_session_id),
        "created_at": _utc_now_iso()
    }

    def _insert():
        return supabase.table(LINKED_SESSIONS_TABLE).insert(payload).execute()

    res = await run_in_threadpool(_insert)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase insert linked session failed: {res.error}")
    return res.data[0]


# Get linked session by relationship_id
async def get_linked_session_by_relationship(*, relationship_id: uuid.UUID) -> Optional[dict]:
    """Get the linked session for a specific relationship"""
    relationship_id_str = str(relationship_id)

    def _select():
        return (supabase
                .table(LINKED_SESSIONS_TABLE)
                .select("*")
                .eq("relationship_id", relationship_id_str)
                .limit(1)
                .execute()
                )

    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select linked session failed: {res.error}")
    return res.data[0] if res.data else None
# Get linked session for a specific personal source session within a relationship
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


# Check if linked session exists for (relationship, source_session)
async def linked_session_exists_for_session(*, relationship_id: uuid.UUID, source_session_id: uuid.UUID) -> bool:
    linked_session = await get_linked_session_by_relationship_and_source_session(
        relationship_id=relationship_id,
        source_session_id=source_session_id,
    )
    return linked_session is not None


# Get linked session by user_id (finds which linked session a user is part of)
async def get_linked_session_by_user(*, user_id: uuid.UUID) -> Optional[dict]:
    """Get the linked session for a specific user"""
    user_id_str = str(user_id)

    def _select():
        return (supabase
                .table(LINKED_SESSIONS_TABLE)
                .select("*")
                .or_(f"user_a_id.eq.{user_id_str},user_b_id.eq.{user_id_str}")
                .limit(1)
                .execute()
                )

    res = await run_in_threadpool(_select)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase select linked session by user failed: {res.error}")
    return res.data[0] if res.data else None


# Get partner's personal session ID from linked session
async def get_partner_personal_session(*, user_id: uuid.UUID, relationship_id: uuid.UUID) -> Optional[uuid.UUID]:
    """Get the partner's personal session ID for a given user and relationship"""
    linked_session = await get_linked_session_by_relationship(relationship_id=relationship_id)
    if not linked_session:
        return None

    user_id_str = str(user_id)

    # Determine which user is the partner
    if linked_session["user_a_id"] == user_id_str:
        partner_session_id = linked_session["user_b_personal_session_id"]
    elif linked_session["user_b_id"] == user_id_str:
        partner_session_id = linked_session["user_a_personal_session_id"]
    else:
        return None

    # Return None if partner session ID is None (partner hasn't accepted yet)
    return uuid.UUID(partner_session_id) if partner_session_id else None


# Check if linked session exists for relationship
async def linked_session_exists(*, relationship_id: uuid.UUID) -> bool:
    """Check if a linked session already exists for this relationship"""
    linked_session = await get_linked_session_by_relationship(relationship_id=relationship_id)
    return linked_session is not None


# Update partner's personal session ID in linked session
async def update_linked_session_partner_session(*, relationship_id: uuid.UUID, partner_session_id: uuid.UUID) -> None:
    """Update the partner's personal session ID when they accept a request"""
    relationship_id_str = str(relationship_id)
    partner_session_id_str = str(partner_session_id)

    def _update():
        return (supabase
                .table(LINKED_SESSIONS_TABLE)
                .update({"user_b_personal_session_id": partner_session_id_str})
                .eq("relationship_id", relationship_id_str)
                .execute()
                )

    res = await run_in_threadpool(_update)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase update linked session partner session failed: {res.error}")


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