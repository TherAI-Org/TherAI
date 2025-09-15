import os
import uuid
from fastapi import APIRouter, Depends, HTTPException

from ..auth import get_current_user
from ..Models.requests import CreateLinkInviteResponse, AcceptLinkInviteRequest, AcceptLinkInviteResponse, UnlinkResponse, LinkStatusResponse
from ..Database.link_repo import accept_link_invite, unlink_relationship_for_user, get_link_status_for_user, get_or_create_link_invite

router = APIRouter(prefix = "/link")

# Create and return a shareable invite link for the current user
@router.post("/send-invite", response_model = CreateLinkInviteResponse)
async def create_invite(current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    try:
        # Idempotent get-or-create behavior: return existing unexpired invite or create a new one
        row = await get_or_create_link_invite(inviter_user_id = user_uuid, expires_in_hours = 24)
        base = os.getenv("SHARE_LINK_BASE_URL", "https://example.com")
        share_url = f"{base.rstrip('/')}/link?code={row['invite_token']}"

        return CreateLinkInviteResponse(invite_token = row["invite_token"], share_url = share_url)
    except PermissionError as e:  # Error if user is already linked (must unlink first)
        raise HTTPException(status_code = 400, detail = str(e))
    except Exception as e:
        raise HTTPException(status_code = 500, detail = f"Error creating invite: {str(e)}")

# Accept a partner's invite token and link the two accounts
@router.post("/accept-invite", response_model = AcceptLinkInviteResponse)
async def accept_invite(request: AcceptLinkInviteRequest, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    try:
        relationship_id = await accept_link_invite(invite_token = request.invite_token, invitee_user_id = user_uuid)

        return AcceptLinkInviteResponse(success = True, relationship_id = relationship_id)
    except PermissionError as e:  # Error if token is invalid/expired/used, self-link occurs, or either user is already linked to someone else
        raise HTTPException(status_code = 400, detail = str(e))
    except Exception as e:
        raise HTTPException(status_code = 500, detail = f"Error accepting invite: {str(e)}")

# Remove the link between the current user and their partner
@router.post("/unlink-pair", response_model = UnlinkResponse)
async def unlink(current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    try:
        deleted = await unlink_relationship_for_user(user_id = user_uuid)
        # Optionally trigger a new invite so the client can immediately fetch a ready link
        try:
            await get_or_create_link_invite(inviter_user_id = user_uuid, expires_in_hours = 24)
        except Exception:
            # Non-fatal for unlink endpoint; log if you add logging
            pass
        return UnlinkResponse(success = True, unlinked = deleted)
    except Exception as e:
        raise HTTPException(status_code = 500, detail = f"Error unlinking: {str(e)}")

# Get whether the current user is linked and the relationship id
@router.get("/status", response_model = LinkStatusResponse)
async def link_status(current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    try:
        linked, rel_id = await get_link_status_for_user(user_id = user_uuid)
        return LinkStatusResponse(success = True, linked = linked, relationship_id = rel_id)
    except Exception as e:
        raise HTTPException(status_code = 500, detail = f"Error fetching link status: {str(e)}")


