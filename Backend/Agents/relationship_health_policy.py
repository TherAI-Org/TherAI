from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Literal, Optional


RecomputeReason = Literal[
    "threshold_met",
    "max_interval_reached",
    "never_ran",
    "not_enough_new_data",
]


@dataclass(frozen=True)
class RecomputeDecision:
    should_run: bool
    reason: RecomputeReason
    next_check_at_iso: Optional[str]


MAX_INTERVAL_HOURS: int = 24


def decide_recompute(
    *,
    last_run_at_iso: Optional[str],
    now: Optional[datetime] = None,
) -> RecomputeDecision:
    current_time = now or datetime.now(timezone.utc)

    # Never ran before: run immediately
    if last_run_at_iso is None:
        return RecomputeDecision(
            should_run=True,
            reason="never_ran",
            next_check_at_iso=None,
        )

    try:
        last_run_at = datetime.fromisoformat(last_run_at_iso)
        if last_run_at.tzinfo is None:
            # Treat naive as UTC
            last_run_at = last_run_at.replace(tzinfo=timezone.utc)
    except Exception:
        # On parse failure, be safe and allow recompute
        return RecomputeDecision(
            should_run=True,
            reason="never_ran",
            next_check_at_iso=None,
        )

    # Max interval rule
    elapsed = current_time - last_run_at
    if elapsed >= timedelta(hours=MAX_INTERVAL_HOURS):
        return RecomputeDecision(
            should_run=True,
            reason="max_interval_reached",
            next_check_at_iso=None,
        )

    # Not enough new data yet
    next_check_at = min(
        last_run_at + timedelta(hours=MAX_INTERVAL_HOURS),
        current_time + timedelta(hours=6),  # suggest a lightweight polling cadence
    )
    return RecomputeDecision(
        should_run=False,
        reason="not_enough_new_data",
        next_check_at_iso=next_check_at.astimezone(timezone.utc).isoformat(),
    )
