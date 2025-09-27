import uuid
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File
from ..auth import get_current_user
from ..Database.supabase_client import supabase

router = APIRouter(prefix="/profile", tags=["profile"])


@router.post("/avatar")
async def upload_avatar(file: UploadFile = File(...), current_user: dict = Depends(get_current_user)):
    try:
        try:
            user_id = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid user ID in token")

        data = await file.read()
        content_type = file.content_type or "application/octet-stream"

        # Key inside the 'avatar' bucket; policies expect owner to be the uploader
        key = f"{user_id}.jpg" if content_type == "image/jpeg" else f"{user_id}"

        # Upload (upsert = true to overwrite on change)
        res = supabase.storage.from_("avatar").upload(
            path=key,
            file=data,
            file_options={"contentType": content_type, "upsert": "true"},
        )
        if getattr(res, "error", None):
            raise HTTPException(status_code=500, detail=f"Storage upload failed: {res.error}")

        # Save/ensure path in profiles table
        path_value = f"avatar/{key}"
        up = supabase.table("profiles").upsert({"user_id": str(user_id), "avatar_path": path_value}).execute()
        if getattr(up, "error", None):
            raise HTTPException(status_code=500, detail=f"Failed to update profile: {up.error}")

        # Signed URL for immediate display (24h)
        signed = supabase.storage.from_("avatar").create_signed_url(key, 60 * 60 * 24)
        signed_url = getattr(signed, "get", None)
        url_value = None
        try:
            url_value = signed.get("signedURL") if callable(signed.get) else signed["signedURL"]  # type: ignore[index]
        except Exception:
            url_value = signed["signedURL"] if isinstance(signed, dict) else None  # type: ignore[index]

        return {"path": path_value, "url": url_value}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/avatar/url")
async def get_avatar_url(current_user: dict = Depends(get_current_user)):
    try:
        try:
            user_id = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid user ID in token")

        # Fetch the stored path
        sel = supabase.table("profiles").select("avatar_path").eq("user_id", str(user_id)).limit(1).execute()
        if getattr(sel, "error", None):
            raise HTTPException(status_code=500, detail=f"Failed to fetch profile: {sel.error}")
        row = sel.data[0] if sel.data else None
        if not row or not row.get("avatar_path"):
            return {"path": None, "url": None}

        path_value = row["avatar_path"]
        # path_value is like 'avatar/<user_id>.jpg'; extract key after bucket name
        key = path_value.split("/", 1)[1] if "/" in path_value else path_value
        signed = supabase.storage.from_("avatar").create_signed_url(key, 60 * 60 * 24)
        url_value = signed.get("signedURL") if isinstance(signed, dict) else None
        return {"path": path_value, "url": url_value}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def _extract_bucket_key(path_value: str) -> tuple[str, str]:
    if "/" in path_value:
        bucket, key = path_value.split("/", 1)
        return bucket, key
    # If only key provided, assume avatar bucket
    return "avatar", path_value


def _provider_avatar_from_claims(claims: dict) -> str | None:
    # Supabase JWT usually carries raw_user_meta_data under 'user_metadata'
    try:
        meta = claims.get("user_metadata") or {}
        return meta.get("avatar_url") or meta.get("picture") or claims.get("picture")
    except Exception:
        return None


def _provider_avatar_from_admin(user_id: uuid.UUID) -> str | None:
    try:
        res = supabase.auth.admin.get_user_by_id(str(user_id))  # type: ignore[attr-defined]
        user = getattr(res, "user", None) or getattr(res, "data", None)
        if not user:
            return None
        meta = getattr(user, "user_metadata", None) or user.get("user_metadata") if isinstance(user, dict) else None
        if isinstance(meta, dict):
            return meta.get("avatar_url") or meta.get("picture")
        return None
    except Exception:
        return None


def _signed_url_from_path(path_value: str) -> str | None:
    try:
        bucket, key = _extract_bucket_key(path_value)
        signed = supabase.storage.from_(bucket).create_signed_url(key, 60 * 60 * 24)
        return signed.get("signedURL") if isinstance(signed, dict) else None
    except Exception:
        return None


@router.get("/avatars")
async def get_self_and_partner_avatars(current_user: dict = Depends(get_current_user)):
    try:
        try:
            user_id = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid user ID in token")

        # Self: prefer storage path, then provider metadata
        me_sel = supabase.table("profiles").select("avatar_path").eq("user_id", str(user_id)).limit(1).execute()
        me_path = (me_sel.data[0].get("avatar_path") if me_sel.data else None) if not getattr(me_sel, "error", None) else None
        me_url = _signed_url_from_path(me_path) if me_path else (_provider_avatar_from_claims(current_user) or None)
        me_source = "storage" if me_path and me_url else ("provider" if me_url else "default")

        # Partner: use existing repo to find partner id lazily to avoid import cycle
        try:
            from ..Database.link_repo import get_partner_user_id  # inline import
            partner_id = await get_partner_user_id(user_id=user_id)
        except Exception:
            partner_id = None

        partner_url = None
        partner_source = "default"
        if partner_id:
            ps = supabase.table("profiles").select("avatar_path").eq("user_id", str(partner_id)).limit(1).execute()
            p_path = (ps.data[0].get("avatar_path") if ps.data else None) if not getattr(ps, "error", None) else None
            partner_url = _signed_url_from_path(p_path) if p_path else _provider_avatar_from_admin(partner_id)
            partner_source = "storage" if p_path and partner_url else ("provider" if partner_url else "default")

        return {
            "me": {"url": me_url, "source": me_source},
            "partner": {"url": partner_url, "source": partner_source} if partner_id else {"url": None, "source": "default"},
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


