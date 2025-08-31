import os
import jwt
from jwt import PyJWKClient
from typing import Optional
from dotenv import load_dotenv
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

load_dotenv()

security = HTTPBearer()

class SupabaseAuth:
    def __init__(self):
        self.jwks_url: Optional[str] = os.getenv("SUPABASE_JWKS_URL")
        if not self.jwks_url:
            raise ValueError("Missing SUPABASE_JWKS_URL in environment")

        # Some Supabase projects require an API key header for the JWKS endpoint
        headers = None
        supabase_publishable_key = os.getenv("SUPABASE_PUBLISHABLE_KEY")
        if supabase_publishable_key:
            headers = {"apikey": supabase_publishable_key, "Authorization": f"Bearer {supabase_publishable_key}"}

        try:
            self.jwk_client = PyJWKClient(self.jwks_url, headers=headers)
        except Exception as e:
            raise RuntimeError(f"Failed to initialize JWKS client: {e}")

    def _get_signing_key(self, token: str):
        try:
            return self.jwk_client.get_signing_key_from_jwt(token).key
        except Exception as e:
            raise HTTPException(status_code=401, detail=f"Unable to fetch signing key: {str(e)}")

    def verify_jwt(self, token: str) -> dict:
        try:
            public_key = self._get_signing_key(token)
            # Supabase uses ES256 (ECC P-256) for new signing keys
            payload = jwt.decode(
                token,
                public_key,
                algorithms=["ES256"],
                audience="authenticated",  # matches Supabase 'aud' claim
                options={"require": ["exp", "iat", "iss", "sub"]},
            )
            return payload
        except jwt.ExpiredSignatureError:
            raise HTTPException(status_code=401, detail="Token has expired")
        except jwt.InvalidAudienceError:
            raise HTTPException(status_code=401, detail="Invalid token audience")
        except jwt.InvalidIssuerError:
            raise HTTPException(status_code=401, detail="Invalid token issuer")
        except jwt.InvalidTokenError as e:
            raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")

    def get_current_user(self, credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
        # Development bypass for local testing
        if os.getenv("DISABLE_AUTH", "").lower() == "true":
            return {"sub": "dev_user", "role": "authenticated"}
        token = credentials.credentials
        if token.count(".") != 2:
            raise HTTPException(status_code=401, detail="Token is not a valid JWT")
        return self.verify_jwt(token)

# Create auth instance
auth = SupabaseAuth()

# Dependency for protected routes
def get_current_user(user: dict = Depends(auth.get_current_user)) -> dict:
    return user

