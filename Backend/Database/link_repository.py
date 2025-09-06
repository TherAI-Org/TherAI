import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional
from starlette.concurrency import run_in_threadpool
from .supabase_client import supabase

RELATIONSHIP_LINKS_TABLE = "link_invites"
RELATIONSHIPS_TABLE = "paired_accounts"


def _utc_in_hours_iso(hours: int) -> str:
    return (datetime.now(timezone.utc) + timedelta(hours = hours)).isoformat()

# Return True if the user appears in `paired_accounts` on either side
async def is_user_linked(*, user_id: uuid.UUID) -> bool:
    user_id_str = str(user_id)

    def _select_rel_by_partner_a():
        return (supabase
                .table(RELATIONSHIPS_TABLE)
                .select("id")
                .eq("partner_a_user_id", user_id_str)
                .limit(1)
                .execute()
                )
    def _select_rel_by_partner_b():
        return (supabase
                .table(RELATIONSHIPS_TABLE)
                .select("id")
                .eq("partner_b_user_id", user_id_str)
                .limit(1)
                .execute()
                )

    res_a = await run_in_threadpool(_select_rel_by_partner_a)
    if getattr(res_a, "error", None):
        raise RuntimeError(f"Supabase select relationship failed: {res_a.error}")
    if res_a.data:
        return True

    res_b = await run_in_threadpool(_select_rel_by_partner_b)
    if getattr(res_b, "error", None):
        raise RuntimeError(f"Supabase select relationship failed: {res_b.error}")
    return bool(res_b.data)

# Create a single-use invite row for the inviter with an expiry
async def create_link_invite(*, inviter_user_id: uuid.UUID, expires_in_hours: int = 24) -> dict:
    if await is_user_linked(user_id = inviter_user_id):
        raise PermissionError("You are already linked to a partner. Please unlink first.")

    invite_token = uuid.uuid4().hex
    payload = {
        "invite_user_id": str(inviter_user_id),
        "invite_token": invite_token,
        "expires_at": _utc_in_hours_iso(expires_in_hours),
        "used_at": None,
        "invitee_user_id": None,
        "paired_account_id": None,
    }

    def _insert():
        return supabase.table(RELATIONSHIP_LINKS_TABLE).insert(payload).execute()
    res = await run_in_threadpool(_insert)
    if getattr(res, "error", None):
        raise RuntimeError(f"Supabase insert link invite failed: {res.error}")
    return res.data[0]

# Accept the invite via transactional RPC and return relationship ID
async def accept_link_invite(*, invite_token: str, invitee_user_id: uuid.UUID) -> uuid.UUID:
    def _rpc_accept():
        return (
            supabase
            .rpc("accept_link_invite_tx",
                 {
                     "invite_token": invite_token,
                     "invitee_user_id": str(invitee_user_id),
                     })
            .execute()
        )

    rpc_res = await run_in_threadpool(_rpc_accept)
    if getattr(rpc_res, "error", None):
        msg = str(rpc_res.error)
        if any(key in msg for key in [
            "Invalid invite token",
            "Invite token already used",
            "Invite token expired",
            "Cannot link to the same user",
            "Inviter already linked to another partner",
            "Invitee already linked to another partner",
            ]):
            raise PermissionError(msg)
        raise RuntimeError(f"RPC accept_link_invite_tx failed: {msg}")

    data = getattr(rpc_res, "data", None)
    relationship_id_str: Optional[str] = None
    if isinstance(data, dict):
        relationship_id_str = data.get("relationship_id") or data.get("id")
    elif isinstance(data, list) and data and isinstance(data[0], dict):
        relationship_id_str = data[0].get("relationship_id") or data[0].get("id")
    elif isinstance(data, str):
        relationship_id_str = data

    if not relationship_id_str:
        raise RuntimeError("RPC accept_link_invite_tx returned no relationship id")

    return uuid.UUID(relationship_id_str)

# Delete the relationship containing the user, if any, and report success
async def unlink_relationship_for_user(*, user_id: uuid.UUID) -> bool:
    user_id_str = str(user_id)

    def _select_rel_by_partner_a():
        return (
            supabase
            .table(RELATIONSHIPS_TABLE)
            .select("*")
            .eq("partner_a_user_id", user_id_str)
            .limit(1)
            .execute()
        )

    def _select_rel_by_partner_b():
        return (
            supabase
            .table(RELATIONSHIPS_TABLE)
            .select("*")
            .eq("partner_b_user_id", user_id_str)
            .limit(1)
            .execute()
        )

    rel_res_a = await run_in_threadpool(_select_rel_by_partner_a)
    if getattr(rel_res_a, "error", None):
        raise RuntimeError(f"Supabase select relationship failed: {rel_res_a.error}")
    relationship = rel_res_a.data[0] if rel_res_a.data else None
    if not relationship:
        rel_res_b = await run_in_threadpool(_select_rel_by_partner_b)
        if getattr(rel_res_b, "error", None):
            raise RuntimeError(f"Supabase select relationship failed: {rel_res_b.error}")
        relationship = rel_res_b.data[0] if rel_res_b.data else None

    if not relationship:
        return False

    rel_id = relationship["id"]

    def _delete_rel():
        return (
            supabase
            .table(RELATIONSHIPS_TABLE)
            .delete()
            .eq("id", rel_id)
            .execute()
        )

    del_res = await run_in_threadpool(_delete_rel)
    if getattr(del_res, "error", None):
        raise RuntimeError(f"Supabase delete relationship failed: {del_res.error}")
    return True


async def get_link_status_for_user(*, user_id: uuid.UUID) -> tuple[bool, Optional[uuid.UUID]]:
    """Return (linked, relationship_id) for the given user."""
    user_id_str = str(user_id)

    def _select_rel_by_partner_a():
        return (
            supabase
            .table(RELATIONSHIPS_TABLE)
            .select("*")
            .eq("partner_a_user_id", user_id_str)
            .limit(1)
            .execute()
        )

    def _select_rel_by_partner_b():
        return (
            supabase
            .table(RELATIONSHIPS_TABLE)
            .select("*")
            .eq("partner_b_user_id", user_id_str)
            .limit(1)
            .execute()
        )

    rel_res_a = await run_in_threadpool(_select_rel_by_partner_a)
    if getattr(rel_res_a, "error", None):
        raise RuntimeError(f"Supabase select relationship failed: {rel_res_a.error}")
    relationship = rel_res_a.data[0] if rel_res_a.data else None
    if not relationship:
        rel_res_b = await run_in_threadpool(_select_rel_by_partner_b)
        if getattr(rel_res_b, "error", None):
            raise RuntimeError(f"Supabase select relationship failed: {rel_res_b.error}")
        relationship = rel_res_b.data[0] if rel_res_b.data else None

    if not relationship:
        return False, None
    return True, uuid.UUID(relationship["id"])  # type: ignore[index]

