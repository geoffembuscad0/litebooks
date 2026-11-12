from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr, Field, field_validator
from postgrest.exceptions import APIError

from app.dependencies.auth import CurrentAuth

router = APIRouter(prefix="/api/companies/{company_id}/contacts", tags=["contacts"])
CONTACT_FIELDS = "id,company_id,name,contact_person,contact_type,is_customer,is_supplier,email,phone,tax_number,billing_address,shipping_address,notes,is_active,created_at,updated_at"


class ContactCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    contact_person: str | None = Field(default=None, max_length=150)
    contact_type: Literal["individual", "business"] = "business"
    is_customer: bool = False
    is_supplier: bool = False
    email: EmailStr | None = None
    phone: str | None = Field(default=None, max_length=30)
    tax_number: str | None = Field(default=None, max_length=50)
    billing_address: str | None = Field(default=None, max_length=10000)
    shipping_address: str | None = Field(default=None, max_length=10000)
    notes: str | None = Field(default=None, max_length=10000)
    is_active: bool = True

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Contact name cannot be blank.")
        return value

    @field_validator("contact_person", "phone", "tax_number", "billing_address", "shipping_address", "notes", mode="before")
    @classmethod
    def clean_optional_text(cls, value: Any) -> Any:
        return value.strip() or None if isinstance(value, str) else value

    @field_validator("email", mode="before")
    @classmethod
    def clean_email(cls, value: Any) -> Any:
        return value.strip() or None if isinstance(value, str) else value


class ContactUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=150)
    contact_person: str | None = Field(default=None, max_length=150)
    contact_type: Literal["individual", "business"] | None = None
    is_customer: bool | None = None
    is_supplier: bool | None = None
    email: EmailStr | None = None
    phone: str | None = Field(default=None, max_length=30)
    tax_number: str | None = Field(default=None, max_length=50)
    billing_address: str | None = Field(default=None, max_length=10000)
    shipping_address: str | None = Field(default=None, max_length=10000)
    notes: str | None = Field(default=None, max_length=10000)
    is_active: bool | None = None

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("Contact name cannot be blank.")
        return value

    @field_validator("contact_person", "phone", "tax_number", "billing_address", "shipping_address", "notes", mode="before")
    @classmethod
    def clean_optional_text(cls, value: Any) -> Any:
        return value.strip() or None if isinstance(value, str) else value

    @field_validator("email", mode="before")
    @classmethod
    def clean_email(cls, value: Any) -> Any:
        return value.strip() or None if isinstance(value, str) else value


def _require_company_owner(client: Any, user_id: str, company_id: UUID) -> None:
    result = (
        client.table("companies")
        .select("id")
        .eq("id", str(company_id))
        .eq("owner_id", user_id)
        .eq("status", "active")
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Company not found.")


def _get_contact(client: Any, company_id: UUID, contact_id: UUID) -> dict[str, Any]:
    result = (
        client.table("contacts")
        .select(CONTACT_FIELDS)
        .eq("company_id", str(company_id))
        .eq("id", str(contact_id))
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Contact not found.")
    return result.data


def _handle_contact_error(exc: APIError) -> HTTPException:
    if getattr(exc, "code", None) == "42501":
        return HTTPException(status_code=403, detail="You are not allowed to manage contacts for this company.")
    return HTTPException(status_code=400, detail="Could not save contact details.")


@router.get("")
def list_contacts(company_id: UUID, auth: CurrentAuth, search: str | None = None, role: Literal["customer", "supplier"] | None = None) -> list[dict[str, Any]]:
    user, client = auth
    try:
        _require_company_owner(client, user["id"], company_id)
        query = client.table("contacts").select(CONTACT_FIELDS).eq("company_id", str(company_id)).order("name")
        if role == "customer":
            query = query.eq("is_customer", True)
        elif role == "supplier":
            query = query.eq("is_supplier", True)
        if search and search.strip():
            term = search.strip().replace("%", "")
            query = query.ilike("name", f"%{term}%")
        return query.execute().data or []
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load company contacts.") from exc


@router.post("", status_code=status.HTTP_201_CREATED)
def create_contact(company_id: UUID, payload: ContactCreate, auth: CurrentAuth) -> dict[str, Any]:
    user, client = auth
    _require_company_owner(client, user["id"], company_id)
    if not payload.is_customer and not payload.is_supplier:
        raise HTTPException(status_code=422, detail="A contact must be marked as a customer, a supplier, or both.")
    row = payload.model_dump()
    row["company_id"] = str(company_id)
    try:
        result = client.table("contacts").insert(row).execute()
        if not result.data:
            raise HTTPException(status_code=502, detail="Contact was not returned after creation.")
        return result.data[0]
    except HTTPException:
        raise
    except APIError as exc:
        raise _handle_contact_error(exc) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Contact service is temporarily unavailable.") from exc


@router.patch("/{contact_id}")
def update_contact(company_id: UUID, contact_id: UUID, payload: ContactUpdate, auth: CurrentAuth) -> dict[str, Any]:
    user, client = auth
    _require_company_owner(client, user["id"], company_id)
    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(status_code=400, detail="Provide at least one contact field to update.")
    try:
        current = _get_contact(client, company_id, contact_id)
        customer = changes.get("is_customer", current["is_customer"])
        supplier = changes.get("is_supplier", current["is_supplier"])
        if not customer and not supplier:
            raise HTTPException(status_code=422, detail="A contact must remain a customer, a supplier, or both.")
        result = (
            client.table("contacts")
            .update(changes)
            .eq("company_id", str(company_id))
            .eq("id", str(contact_id))
            .execute()
        )
        if not result.data:
            raise HTTPException(status_code=404, detail="Contact not found.")
        return result.data[0]
    except HTTPException:
        raise
    except APIError as exc:
        raise _handle_contact_error(exc) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not update contact.") from exc
