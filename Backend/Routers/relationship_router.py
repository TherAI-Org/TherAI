import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends

from ..auth import get_current_user
from ..Agents.relationship_health import RelationshipHealthAgent
from ..Agents.relationship_stats import RelationshipStatsAgent
from ..Agents.relationship_health_policy import decide_recompute
from ..Models.requests import RelationshipHealthRequest, RelationshipHealthResponse
from ..Database.session_repo import list_sessions_for_user
from ..Database.chat_repo import list_messages_for_session
from ..Database.link_repo import get_partner_user_id, get_link_status_for_user

from ..Database.relationship_health_repo import (
    get_relationship_health_summary,
    upsert_relationship_health_summary,
    count_new_messages_since,
    get_relationship_stats,
    upsert_relationship_stats,
)


router = APIRouter(prefix = "/relationship", tags = ["relationship"])

health_agent = RelationshipHealthAgent()
stats_agent = RelationshipStatsAgent()


def _iso_now() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _full_transcript_for_user(user_id: uuid.UUID) -> tuple[str, int, int]:
    """Return a joined transcript for all of the user's personal sessions,
    along with total message count and count of user+assistant lines.
    """
    sessions = await list_sessions_for_user(user_id = user_id, limit = 1000, offset = 0)
    total = 0
    lines: list[str] = []
    for s in sessions or []:
        sid = uuid.UUID(s["id"])  # type: ignore[index]
        messages = await list_messages_for_session(user_id = user_id, session_id = sid, limit = 10000, offset = 0)
        for m in messages:
            role = m.get("role", "")
            content = m.get("content", "")
            lines.append(f"{role.upper()}: {content}")
        total += len(messages)
    return ("\n".join(lines).strip(), total, len(lines))


async def _count_new_messages_for_user(user_id: uuid.UUID, since: Optional[datetime]) -> int:
    """Count new messages for a user since the given timestamp."""
    if not since:
        # Count all messages if no since date
        sessions = await list_sessions_for_user(user_id=user_id, limit=1000, offset=0)
        total = 0
        for s in sessions or []:
            sid = uuid.UUID(s["id"])
            messages = await list_messages_for_session(user_id=user_id, session_id=sid, limit=10000, offset=0)
            total += len(messages)
        return total
    else:
        return await count_new_messages_since(user_id, since)


@router.post("/health", response_model = RelationshipHealthResponse)
async def generate_relationship_health(request: RelationshipHealthRequest, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    try:
        # Resolve relationship id (summary is shared for both linked users)
        linked, relationship_id, _ = await get_link_status_for_user(user_id=user_uuid)
        cached_summary = None
        if linked and relationship_id:
            cached_summary = await get_relationship_health_summary(relationship_id)

        # Parse last_run_at for decision making
        last_run_date = None
        if request.last_run_at:
            try:
                last_run_date = datetime.fromisoformat(request.last_run_at)
                if last_run_date.tzinfo is None:
                    last_run_date = last_run_date.replace(tzinfo=timezone.utc)
            except Exception:
                last_run_date = None

        # Count new messages precisely since last run
        a_new_count = await _count_new_messages_for_user(user_uuid, last_run_date)
        try:
            partner_id = await get_partner_user_id(user_id=user_uuid)
            if partner_id:
                b_new_count = await _count_new_messages_for_user(partner_id, last_run_date)
            else:
                b_new_count = 0
        except Exception:
            b_new_count = 0

        combined_new = a_new_count + b_new_count

        # Check if we have any messages at all across both partners
        has_any_messages = (a_new_count > 0) or (b_new_count > 0) or bool(cached_summary and cached_summary.get("has_any_messages", True))

        # If there are no messages at all, short-circuit with the starter prompt
        if not has_any_messages:
            now = datetime.now(timezone.utc)
            summary = "Start talking to your partner"
            if linked and relationship_id:
                await upsert_relationship_health_summary(
                    relationship_id=relationship_id,
                    summary=summary,
                    last_run_at=now,
                    has_any_messages=False,
                )
            return RelationshipHealthResponse(
                summary=summary,
                last_run_at=now.isoformat(),
                reason="never_ran" if not request.last_run_at else "max_interval_reached",
                has_any_messages=False,
            )

        # Make policy decision (time-based)
        decision = decide_recompute(last_run_at_iso=request.last_run_at)

        # If policy says don't run and not forced, return cached summary
        if not decision.should_run and not request.force and cached_summary:
            return RelationshipHealthResponse(
                summary=cached_summary["summary"],
                last_run_at=cached_summary["last_run_at"],
                reason=decision.reason,
                has_any_messages=cached_summary.get("has_any_messages", True)
            )

        # Generate new summary
        a_transcript, a_total, _ = await _full_transcript_for_user(user_uuid)
        try:
            partner_id = await get_partner_user_id(user_id=user_uuid)
        except Exception:
            partner_id = None
        if partner_id:
            b_transcript, b_total, _ = await _full_transcript_for_user(partner_id)
        else:
            b_transcript, b_total = "", 0

        # Call OpenAI
        summary = health_agent.generate_summary(partner_a_transcript=a_transcript, partner_b_transcript=b_transcript)
        if not summary:
            if not has_any_messages:
                summary = "Start talking to your partner to view your relationship health"
            else:
                # Leave blank if the model produced nothing and there are messages
                summary = ""

        # Cache the new summary
        now = datetime.now(timezone.utc)
        # Persist only when we have a concrete summary or when we intentionally store the no-messages prompt
        if linked and relationship_id and (summary != "" or not has_any_messages):
            await upsert_relationship_health_summary(
                relationship_id=relationship_id,
                summary=summary,
                last_run_at=now,
                has_any_messages=has_any_messages,
            )

        return RelationshipHealthResponse(
            summary=summary,
            last_run_at=now.isoformat(),
            reason=decision.reason,
            has_any_messages=has_any_messages
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



@router.post("/stats")
async def generate_relationship_stats(request: RelationshipHealthRequest, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    try:
        linked, relationship_id, _ = await get_link_status_for_user(user_id=user_uuid)
        if not linked or not relationship_id:
            return {
                "communication": "Unknown",
                "trust_level": "Unknown",
                "future_goals": "Unknown",
                "intimacy": "Unknown",
                "last_run_at": datetime.now(timezone.utc).isoformat(),
            }

        cached = await get_relationship_stats(relationship_id)

        # Decide recompute by time only (reuse health policy)
        decision = decide_recompute(last_run_at_iso=request.last_run_at)
        if not decision.should_run and not request.force and cached:
            return {
                "communication": cached.get("communication", "Unknown"),
                "trust_level": cached.get("trust_level", "Unknown"),
                "future_goals": cached.get("future_goals", "Unknown"),
                "intimacy": cached.get("intimacy", "Unknown"),
                "last_run_at": cached.get("last_run_at"),
            }

        # Build transcripts like in health
        a_transcript, _, _ = await _full_transcript_for_user(user_uuid)
        partner_id = await get_partner_user_id(user_id=user_uuid)
        b_transcript = ""
        if partner_id:
            b_transcript, _, _ = await _full_transcript_for_user(partner_id)

        stats = stats_agent.generate_stats(partner_a_transcript=a_transcript, partner_b_transcript=b_transcript)
        now = datetime.now(timezone.utc)
        await upsert_relationship_stats(relationship_id=relationship_id, stats=stats, last_run_at=now)
        stats["last_run_at"] = now.isoformat()
        return stats
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



