from typing import Annotated, Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from supabase import Client, create_client

from app.core.config import get_settings

bearer_scheme = HTTPBearer(auto_error=False)


async def get_authenticated_client(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> tuple[dict[str, Any], Client]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sign in to continue.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    settings = get_settings()
    client = create_client(settings.supabase_url, settings.supabase_anon_key)
    token = credentials.credentials
    try:
        response = client.auth.get_user(token)
        user = response.user
        if user is None:
            raise ValueError("No authenticated user returned")
        # All PostgREST operations use the caller's JWT, so Supabase RLS applies.
        client.postgrest.auth(token)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Your session is invalid or expired. Please sign in again.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    return user.model_dump() if hasattr(user, "model_dump") else user.__dict__, client


CurrentAuth = Annotated[tuple[dict[str, Any], Client], Depends(get_authenticated_client)]
