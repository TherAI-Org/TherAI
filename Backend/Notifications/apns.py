import os
import time
import json
import uuid
from typing import Any, Dict, Iterable, Optional

import httpx
import jwt

from ..Database.device_tokens_repo import list_tokens_for_user, disable_token_by_value


_cached_jwt_token: Optional[str] = None
_cached_jwt_exp: float = 0.0


def _load_apns_auth_key_pem() -> str:
    key_b64 = os.getenv("APNS_AUTH_KEY_BASE64")
    key_path = os.getenv("APNS_KEY_PATH")
    if key_b64:
        try:
            import base64
            pem_bytes = base64.b64decode(key_b64)
            return pem_bytes.decode("utf-8")
        except Exception as e:
            raise RuntimeError(f"Failed to decode APNS_AUTH_KEY_BASE64: {e}")
    if key_path:
        try:
            with open(key_path, "r", encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            raise RuntimeError(f"Failed to read APNS_KEY_PATH: {e}")
    raise RuntimeError("Missing APNS_AUTH_KEY_BASE64 or APNS_KEY_PATH env var for APNs auth key")


def _get_apns_jwt_token() -> str:
    global _cached_jwt_token, _cached_jwt_exp

    now = time.time()
    # Refresh if less than 5 minutes left or missing
    if _cached_jwt_token and now < (_cached_jwt_exp - 300):
        return _cached_jwt_token

    team_id = os.getenv("APNS_TEAM_ID")
    key_id = os.getenv("APNS_KEY_ID")
    if not team_id or not key_id:
        raise RuntimeError("Missing APNS_TEAM_ID or APNS_KEY_ID")

    private_key_pem = _load_apns_auth_key_pem()

    # Debug logging
    print(f"[APNs JWT] Creating token with team_id={team_id} key_id={key_id}")

    headers = {"alg": "ES256", "kid": key_id}
    payload = {
        "iss": team_id,
        "iat": int(now),
        "exp": int(now + 3600)  # Add explicit expiration
    }

    try:
        token = jwt.encode(payload, private_key_pem, algorithm="ES256", headers=headers)  # type: ignore[no-untyped-call]
    except Exception as e:
        print(f"[APNs JWT] Failed to encode JWT: {e}")
        raise

    # APNs allows up to 1 hour; cache for 55 minutes
    _cached_jwt_token = token
    _cached_jwt_exp = now + 55 * 60
    return token


async def _post_apns(device_token: str, payload: Dict[str, Any]) -> tuple[int, str]:
    use_sandbox = (os.getenv("APNS_USE_SANDBOX", "true").lower() == "true")
    host = "api.sandbox.push.apple.com" if use_sandbox else "api.push.apple.com"
    bundle_id = os.getenv("APNS_BUNDLE_ID") or os.getenv("AASA_BUNDLE_ID")
    if not bundle_id:
        raise RuntimeError("Missing APNS_BUNDLE_ID (and AASA_BUNDLE_ID fallback)")

    url = f"https://{host}/3/device/{device_token}"
    auth_token = _get_apns_jwt_token()

    headers = {
        "authorization": f"bearer {auth_token}",
        "apns-topic": bundle_id,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
    }

    async with httpx.AsyncClient(http2=True, timeout=10.0) as client:
        # Debug: log where we are sending
        try:
            print(f"[APNs] POST host={'sandbox' if use_sandbox else 'prod'} topic={bundle_id} token={device_token[:10]}… payload_keys={list(payload.keys())}")
            # Also log auth header length to verify JWT exists
            auth_header = headers.get("authorization", "")
            print(f"[APNs] Auth header length: {len(auth_header)} chars")
        except Exception:
            pass
        resp = await client.post(url, headers=headers, content=json.dumps(payload))
        text = resp.text
        return resp.status_code, text


async def send_partner_request_notification_to_user(
    *,
    recipient_user_id: uuid.UUID,
    request_id: uuid.UUID,
    relationship_id: uuid.UUID,
    preview: str,
    sender_name: Optional[str] = None,
) -> None:
    """Send an APNs alert to all active tokens for the recipient user.

    Keeps payload tiny; app routes using request_id.
    """
    tokens = await list_tokens_for_user(user_id=recipient_user_id)
    if not tokens:
        return

    title = "Partner Request"

    aps = {
        "alert": {"title": title, "body": "Your partner has sent you a request. Tap to open."},
        "sound": "default",
        "category": "PARTNER_REQUEST",
    }
    payload = {
        "aps": aps,
        "request_id": str(request_id),
        "relationship_id": str(relationship_id),
    }

    # Summary log before fanout
    try:
        print(f"[Push] PartnerRequest notify recipient={recipient_user_id} tokens={len(tokens)} request_id={request_id}")
        # Log first token shape for debugging
        sample = tokens[0] if tokens else None
        if isinstance(sample, dict):
            print(f"[Push] sample token keys={list(sample.keys())}")
        else:
            print(f"[Push] sample token type={type(sample)}")
    except Exception:
        pass

    # Fire-and-forget to each device; do not raise if one fails.
    for t in tokens:
        token_val = t.get("token") if isinstance(t, dict) else None
        enabled = (t.get("enabled", True) if isinstance(t, dict) else True)
        if not token_val or not enabled:
            try:
                print(f"[APNs] skip token entry enabled={enabled} keys={list(t.keys()) if isinstance(t, dict) else 'n/a'}")
            except Exception:
                pass
            continue
        try:
            status, resp_text = await _post_apns(device_token=token_val, payload=payload)
            # Basic diagnostics
            if status != 200:
                try:
                    print(f"[APNs] send token={token_val[:10]}… status={status} body={resp_text}")
                except Exception:
                    pass
                # Token is invalid or app uninstalled
                if status in (400, 410) and ("BadDeviceToken" in (resp_text or "") or "Unregistered" in (resp_text or "")):
                    try:
                        await disable_token_by_value(token=token_val)
                    except Exception:
                        pass
            else:
                try:
                    print(f"[APNs] send OK token={token_val[:10]}… status=200")
                except Exception:
                    pass
        except Exception as e:
            # Avoid crashing the request handler on APNs failure, but log details
            try:
                print(f"[APNs] send exception token={token_val[:10]}… err={e}")
            except Exception:
                pass
            continue





