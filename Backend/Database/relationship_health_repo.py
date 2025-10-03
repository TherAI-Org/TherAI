import uuid
from datetime import datetime, timezone
from typing import Optional
from .supabase_client import supabase


REL_HEALTH_TABLE = "relationship_health"
USER_SESSIONS_TABLE = "user_chat_sessions"
USER_MESSAGES_TABLE = "user_chat_messages"


async def get_relationship_health_summary(relationship_id: uuid.UUID) -> Optional[dict]:
    """Get the cached relationship health summary for a relationship."""
    try:
        result = (
            supabase
            .table(REL_HEALTH_TABLE)
            .select("*")
            .eq("relationship_id", str(relationship_id))
            .limit(1)
            .execute()
        )
        if result.data and len(result.data) > 0:
            return result.data[0]
        return None
    except Exception as e:
        print(f"Error fetching relationship health summary: {e}")
        return None


async def upsert_relationship_health_summary(
    relationship_id: uuid.UUID,
    summary: str,
    last_run_at: datetime,
    has_any_messages: bool = True,
) -> None:
    """Insert or update the relationship health summary for a relationship."""
    try:
        data = {
            "relationship_id": str(relationship_id),
            "summary": summary,
            "last_run_at": last_run_at.isoformat(),
            "has_any_messages": has_any_messages,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        supabase.table(REL_HEALTH_TABLE).upsert(data, on_conflict="relationship_id").execute()
    except Exception as e:
        print(f"Error upserting relationship health summary: {e}")
        raise


async def count_new_messages_since(user_id: uuid.UUID, since: datetime) -> int:
    """Count new messages in all of a user's personal sessions since the timestamp."""
    try:
        sessions_result = (
            supabase
            .table(USER_SESSIONS_TABLE)
            .select("id")
            .eq("user_id", str(user_id))
            .execute()
        )
        if not sessions_result.data:
            return 0

        session_ids = [s["id"] for s in sessions_result.data]

        since_iso = since.isoformat()
        total_count = 0
        for session_id in session_ids:
            result = (
                supabase
                .table(USER_MESSAGES_TABLE)
                .select("id", count="exact")
                .eq("session_id", session_id)
                .gte("created_at", since_iso)
                .execute()
            )
            if getattr(result, "count", None):
                total_count += int(result.count)

        return total_count
    except Exception as e:
        print(f"Error counting new messages: {e}")
        return 0
