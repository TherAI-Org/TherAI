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

        # Issuer validation
        issuer_env: Optional[str] = os.getenv("SUPABASE_ISSUER") or os.getenv("SUPABASE_URL")
        if not issuer_env:
            raise ValueError("Missing SUPABASE_ISSUER or SUPABASE_URL in environment")
        issuer_env = issuer_env.rstrip("/")
        # Accept either full issuer (ending with /auth/v1) or base URL
        self.issuer: str = issuer_env if issuer_env.endswith("/auth/v1") else f"{issuer_env}/auth/v1"

        # Accepted algorithm (per project JWKS: ES256)
        self.accepted_algorithms = ["ES256"]

        # Small clock skew leeway (seconds)
        self.leeway_seconds = int(os.getenv("JWT_LEEWAY_SECONDS", "60"))

        try:
            self.jwk_client = PyJWKClient(self.jwks_url)
        except Exception as e:
            raise RuntimeError("Failed to initialize JWKS client") from e

    def _get_signing_key(self, token: str):
        try:
            return self.jwk_client.get_signing_key_from_jwt(token).key
        except Exception as e:
            raise HTTPException(status_code=401, detail=f"Unable to fetch signing key: {str(e)}")

    def verify_jwt(self, token: str) -> dict:
        try:
            public_key = self._get_signing_key(token)
            payload = jwt.decode(
                token,
                public_key,
                algorithms=self.accepted_algorithms,
                audience="authenticated",
                issuer=self.issuer,
                options={"require": ["exp", "iat", "iss", "sub"]},
                leeway=self.leeway_seconds,
            )
            return payload
        except jwt.ExpiredSignatureError:
            raise HTTPException(status_code=401, detail="Invalid or expired token")
        except (jwt.InvalidAudienceError, jwt.InvalidIssuerError, jwt.InvalidTokenError):
            raise HTTPException(status_code=401, detail="Invalid or expired token")

    def get_current_user(self, credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
        token = credentials.credentials
        return self.verify_jwt(token)

# Create auth instance
auth = SupabaseAuth()

# Dependency for protected routes
def get_current_user(user: dict = Depends(auth.get_current_user)) -> dict:
    return user

