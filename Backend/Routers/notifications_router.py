import uuid
from fastapi import APIRouter, Depends, HTTPException

from ..auth import get_current_user
from ..Database.device_tokens_repo import upsert_token, disable_token_by_value


router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.post("/register")
async def register_token(payload: dict, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user ID in token")

    token = payload.get("token")
    platform = payload.get("platform") or "ios"
    bundle_id = payload.get("bundle_id")
    if not token or not isinstance(token, str) or len(token) < 10:
        raise HTTPException(status_code=400, detail="Missing or invalid device token")

    try:
        await upsert_token(user_id=user_uuid, token=token, platform=platform, bundle_id=bundle_id)
        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/unregister")
async def unregister_token(payload: dict, current_user: dict = Depends(get_current_user)):
    # We only require token; ownership is implied by client choice, but no leak occurs.
    token = payload.get("token")
    if not token or not isinstance(token, str):
        raise HTTPException(status_code=400, detail="Missing token")
    try:
        await disable_token_by_value(token=token)
        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))





