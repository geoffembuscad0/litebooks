from datetime import datetime
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator
from postgrest.exceptions import APIError

from app.dependencies.auth import CurrentAuth

router = APIRouter(prefix="/api/companies", tags=["companies"])


class CompanyCreate(BaseModel):
    company_name: str = Field(min_length=1, max_length=150)
    company_code: str = Field(min_length=1, max_length=50)
    address: str | None = Field(default=None, max_length=10000)
    contact_number: str | None = Field(default=None, max_length=30)
    email: EmailStr | None = None
    currency: str = Field(default="PHP", min_length=3, max_length=3)
    fiscal_year_start: int = Field(default=1, ge=1, le=12)

    @field_validator("company_name", "company_code")
    @classmethod
    def strip_required_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("This field cannot be blank.")
        return value

    @field_validator("company_code")
    @classmethod
    def normalize_company_code(cls, value: str) -> str:
        return value.strip().upper()

    @field_validator("address", "contact_number", mode="before")
    @classmethod
    def normalize_optional_text(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip() or None
        return value

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        value = value.strip().upper()
        if not value.isalpha():
            raise ValueError("Currency must be a three-letter code, such as PHP.")
        return value


class CompanyResponse(BaseModel):
    id: UUID
    owner_id: UUID
    company_name: str
    company_code: str
    address: str | None
    contact_number: str | None
    email: str | None
    currency: str
    fiscal_year_start: int
    timezone: str
    status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


@router.get("", response_model=list[CompanyResponse])
def list_companies(auth: CurrentAuth) -> list[dict[str, Any]]:
    user, client = auth
    try:
        result = (
            client.table("companies")
            .select("id,owner_id,company_name,company_code,address,contact_number,email,currency,fiscal_year_start,timezone,status,created_at")
            .eq("owner_id", user["id"])
            .eq("status", "active")
            .order("company_name")
            .execute()
        )
        return result.data
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load your companies.") from exc


@router.post("", response_model=CompanyResponse, status_code=status.HTTP_201_CREATED)
def create_company(payload: CompanyCreate, auth: CurrentAuth) -> dict[str, Any]:
    user, client = auth
    row = payload.model_dump()
    row["owner_id"] = user["id"]
    try:
        result = client.table("companies").insert(row).execute()
        if not result.data:
            raise HTTPException(status_code=502, detail="Company was not returned after creation.")
        return result.data[0]
    except APIError as exc:
        code = getattr(exc, "code", None)
        if code == "23505" or "unique_owner_company_code" in str(exc) or "companies_owner_company_code" in str(exc):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You already use this company code for one of your companies.",
            ) from exc
        if code == "42501":
            raise HTTPException(status_code=403, detail="You are not allowed to create this company.") from exc
        raise HTTPException(status_code=400, detail="Could not create company. Check the submitted details.") from exc
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Company service is temporarily unavailable.") from exc
