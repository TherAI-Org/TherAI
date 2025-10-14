import uuid
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Form
from ..auth import get_current_user
from ..Database.link_repo import get_partner_user_id, get_link_status_for_user
from ..Database.supabase_client import supabase

router = APIRouter(prefix = "/profile", tags = ["profile"])

@router.post("/avatar")
async def upload_avatar(file: UploadFile = File(...), current_user: dict = Depends(get_current_user)):
    try:
        try:
            user_id = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid user ID in token")

        data = await file.read()
        content_type = file.content_type or "application/octet-stream"

        # Preserve original file extension based on content type
        if content_type == "image/jpeg":
            key = f"{user_id}.jpg"
        elif content_type == "image/png":
            key = f"{user_id}.png"
        elif content_type == "image/webp":
            key = f"{user_id}.webp"
        else:
            key = f"{user_id}"

        res = supabase.storage.from_("avatar").upload(
            path = key,
            file = data,
            file_options = {"contentType": content_type, "upsert": "true"},
        )

        if getattr(res, "error", None):
            raise HTTPException(status_code = 500, detail = f"Storage upload failed: {res.error}")

        path_value = f"avatar/{key}"
        up = supabase.table("profiles").upsert({"user_id": str(user_id), "avatar_path": path_value}).execute()
        if getattr(up, "error", None):
            raise HTTPException(status_code = 500, detail = f"Failed to update profile: {up.error}")

        signed = supabase.storage.from_("avatar").create_signed_url(key, 60 * 60 * 24)
        url_value = signed.get("signedURL") if isinstance(signed, dict) else None

        return {"path": path_value, "url": url_value}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code = 500, detail = str(e))

# Update user profile information (PUT)
@router.put("/update")
async def update_profile(
    full_name: str = Form(None),
    bio: str = Form(None),
    current_user: dict = Depends(get_current_user)
):
    try:
        try:
            user_id = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid user ID in token")

        # Build update payload with only provided fields
        update_data = {}
        if full_name is not None:
            # Enforce reasonable length limit for full name
            if len(full_name) > 22:
                raise HTTPException(status_code=400, detail="Full name must be 22 characters or fewer")
            update_data["full_name"] = full_name
        if bio is not None:
            update_data["bio"] = bio

        if not update_data:
            raise HTTPException(status_code=400, detail="No fields provided for update")

        # Update the profile
        result = supabase.table("profiles").upsert({
            "user_id": str(user_id),
            **update_data
        }).execute()

        if getattr(result, "error", None):
            raise HTTPException(status_code=500, detail=f"Failed to update profile: {result.error}")

        return {"success": True, "message": "Profile updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Update user profile information (POST mirror for environments that block PUT)
@router.post("/update")
async def update_profile_post(
    full_name: str = Form(None),
    bio: str = Form(None),
    current_user: dict = Depends(get_current_user)
):
    try:
        try:
            user_id = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid user ID in token")

        update_data = {}
        if full_name is not None:
            # Enforce reasonable length limit for full name
            if len(full_name) > 22:
                raise HTTPException(status_code=400, detail="Full name must be 22 characters or fewer")
            update_data["full_name"] = full_name
        if bio is not None:
            update_data["bio"] = bio

        if not update_data:
            raise HTTPException(status_code=400, detail="No fields provided for update")

        result = supabase.table("profiles").upsert({
            "user_id": str(user_id),
            **update_data
        }).execute()

        if getattr(result, "error", None):
            raise HTTPException(status_code=500, detail=f"Failed to update profile: {result.error}")

        return {"success": True, "message": "Profile updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Get user profile information
@router.get("/info")
async def get_profile_info(current_user: dict = Depends(get_current_user)):
    try:
        try:
            user_id = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid user ID in token")

        # Get profile from database
        result = supabase.table("profiles").select("full_name, bio").eq("user_id", str(user_id)).limit(1).execute()
        
        if getattr(result, "error", None):
            raise HTTPException(status_code=500, detail=f"Failed to get profile: {result.error}")

        profile_data = result.data[0] if result.data else {}
        
        # Fallback to auth metadata if profile fields are empty
        auth_metadata = current_user.get("user_metadata", {})
        
        # Derive a sensible fallback full name from auth metadata
        fallback_full = (auth_metadata.get("full_name") or
                         auth_metadata.get("name") or
                         "").strip()

        return {
            "full_name": profile_data.get("full_name") or fallback_full,
            "bio": profile_data.get("bio") or "",
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Get both the current user's and their partner's avatar URLs
@router.get("/avatars")
async def get_self_and_partner_avatars(current_user: dict = Depends(get_current_user)):
    try:
        try:
            user_id = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

        me_sel = supabase.table("profiles").select("avatar_path").eq("user_id", str(user_id)).limit(1).execute()
        me_path = (me_sel.data[0].get("avatar_path") if me_sel.data else None) if not getattr(me_sel, "error", None) else None

        if me_path:
            me_url = _signed_url_from_path(me_path)
        else:
            try:
                meta = current_user.get("user_metadata") or {}
                me_url = meta.get("avatar_url") or meta.get("picture") or current_user.get("picture")
            except Exception:
                me_url = None

        me_source = "storage" if me_path and me_url else ("provider" if me_url else "default")

        try:
            partner_id = await get_partner_user_id(user_id = user_id)
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
        raise HTTPException(status_code = 500, detail = str(e))

 # Create a signed URL from a storage path
def _signed_url_from_path(path_value: str) -> str | None:
    try:
        if "/" in path_value:
            bucket, key = path_value.split("/", 1)
        else:
            bucket, key = "avatar", path_value
        signed = supabase.storage.from_(bucket).create_signed_url(key, 60 * 60 * 24)
        return signed.get("signedURL") if isinstance(signed, dict) else None
    except Exception:
        return None

# Get a user's avatar URL from their auth provider metadata via admin API
def _provider_avatar_from_admin(user_id: uuid.UUID) -> str | None:
    try:
        res = supabase.auth.admin.get_user_by_id(str(user_id))  # type: ignore[attr-defined]
        user = getattr(res, "user", None) or getattr(res, "data", None)
        if not user:
            return None

        def extract_from_meta(meta_dict):
            if not isinstance(meta_dict, dict):
                return None
            return meta_dict.get("avatar_url") or meta_dict.get("picture")

        if isinstance(user, dict):
            meta = user.get("user_metadata")
            url = extract_from_meta(meta)
            if url:
                return url
        else:
            meta = getattr(user, "user_metadata", None)
            url = extract_from_meta(meta if isinstance(meta, dict) else None)
            if url:
                return url
        return None
    except Exception as e:
        print(f"[Avatar] Error fetching partner avatar for {user_id}: {e}")
        return None

# Get partner information including name and avatar
@router.get("/partner-info")
async def get_partner_info(current_user: dict = Depends(get_current_user)):
    try:
        try:
            user_id = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid user ID in token")

        # Check if user is linked
        linked, _, _ = await get_link_status_for_user(user_id=user_id)
        if not linked:
            return {"linked": False, "partner": None}

        # Get partner user ID
        partner_id = await get_partner_user_id(user_id=user_id)
        if not partner_id:
            return {"linked": False, "partner": None}

        # Get partner info from auth provider, but prefer saved profile full_name if present
        try:
            res = supabase.auth.admin.get_user_by_id(str(partner_id))  # type: ignore[attr-defined]
            user = getattr(res, "user", None) or getattr(res, "data", None)

            if not user:
                return {"linked": True, "partner": {"name": "Unknown", "avatar_url": None}}

            # Extract name and avatar from user metadata
            def extract_name_from_meta(meta_dict):
                if not isinstance(meta_dict, dict):
                    return "Unknown"
                return (meta_dict.get("full_name") or
                       meta_dict.get("name") or
                       meta_dict.get("display_name") or
                       "Unknown")

            def extract_avatar_from_meta(meta_dict):
                if not isinstance(meta_dict, dict):
                    return None
                return meta_dict.get("avatar_url") or meta_dict.get("picture")

            if isinstance(user, dict):
                meta = user.get("user_metadata")
                name = extract_name_from_meta(meta)
                avatar_url = extract_avatar_from_meta(meta)
            else:
                meta = getattr(user, "user_metadata", None)
                name = extract_name_from_meta(meta if isinstance(meta, dict) else None)
                avatar_url = extract_avatar_from_meta(meta if isinstance(meta, dict) else None)

            # Prefer partner's saved profile full_name if available
            try:
                prof = supabase.table("profiles").select("full_name").eq("user_id", str(partner_id)).limit(1).execute()
                if not getattr(prof, "error", None) and prof.data:
                    saved_full = (prof.data[0].get("full_name") or "").strip()
                    if saved_full:
                        name = saved_full
            except Exception:
                # ignore profile lookup errors and keep provider-derived name
                pass

            # Try to get custom avatar from storage
            ps = supabase.table("profiles").select("avatar_path").eq("user_id", str(partner_id)).limit(1).execute()
            p_path = (ps.data[0].get("avatar_path") if ps.data else None) if not getattr(ps, "error", None) else None
            custom_avatar_url = _signed_url_from_path(p_path) if p_path else None

            return {
                "linked": True,
                "partner": {
                    "name": name,
                    "avatar_url": custom_avatar_url or avatar_url
                }
            }

        except Exception as e:
            print(f"[Partner Info] Error fetching partner info for {partner_id}: {e}")
            return {"linked": True, "partner": {"name": "Unknown", "avatar_url": None}}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
