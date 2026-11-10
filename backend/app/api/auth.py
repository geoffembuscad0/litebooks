from typing import Any

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field, field_validator
from postgrest.exceptions import APIError

from app.dependencies.auth import CurrentAuth

router = APIRouter(prefix="/api/auth", tags=["authentication"])


class ProfileUpdate(BaseModel):
    firstname: str = Field(min_length=1, max_length=150)
    lastname: str = Field(min_length=1, max_length=150)

    @field_validator("firstname", "lastname")
    @classmethod
    def trim_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Name fields cannot be blank.")
        return value


@router.get("/me")
def get_current_user(auth: CurrentAuth) -> dict[str, Any]:
    user, _client = auth
    return {"id": user["id"], "email": user.get("email")}


@router.get("/profile")
def get_profile(auth: CurrentAuth) -> dict[str, Any]:
    user, client = auth
    try:
        result = client.table("profiles").select("id,firstname,lastname,avatar_url,created_at,updated_at").eq("id", user["id"]).maybe_single().execute()
        profile = result.data or {"id": user["id"], "firstname": "", "lastname": "", "avatar_url": None}
        return {**profile, "email": user.get("email")}
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load your account profile.") from exc


@router.patch("/profile")
def update_profile(payload: ProfileUpdate, auth: CurrentAuth) -> dict[str, Any]:
    user, client = auth
    row = {"id": user["id"], **payload.model_dump()}
    try:
        result = client.table("profiles").upsert(row, on_conflict="id").execute()
        if not result.data:
            raise HTTPException(status_code=502, detail="Profile was not returned after saving.")
        return {**result.data[0], "email": user.get("email")}
    except APIError as exc:
        if getattr(exc, "code", None) == "42501":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not allowed to update this profile.") from exc
        raise HTTPException(status_code=400, detail="Could not update your account profile.") from exc
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Profile service is temporarily unavailable.") from exc
