from typing import Any

from fastapi import APIRouter

from app.dependencies.auth import CurrentAuth

router = APIRouter(prefix="/api/auth", tags=["authentication"])


@router.get("/me")
def get_current_user(auth: CurrentAuth) -> dict[str, Any]:
    user, _client = auth
    return {"id": user["id"], "email": user.get("email")}
