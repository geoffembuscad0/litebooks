from datetime import date, datetime
from typing import Any
from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field, field_validator

from app.dependencies.auth import CurrentAuth

router = APIRouter(prefix="/api/companies/{company_id}/purchases", tags=["purchases"])


class PurchaseItemInput(BaseModel):
    product_id: UUID
    quantity: float = Field(gt=0)
    unit_price: float = Field(ge=0)


class PurchaseCreate(BaseModel):
    supplier_id: UUID
    transaction_number: str = Field(min_length=1, max_length=50)
    transaction_date: date
    due_date: date | None = None
    reference_number: str | None = Field(default=None, max_length=100)
    notes: str | None = Field(default=None, max_length=10000)
    items: list[PurchaseItemInput] = Field(min_length=1)

    @field_validator("transaction_number")
    @classmethod
    def clean_number(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Purchase number cannot be blank.")
        return value

    @field_validator("reference_number", "notes", mode="before")
    @classmethod
    def clean_optional_text(cls, value: Any) -> Any:
        return value.strip() or None if isinstance(value, str) else value


def _require_company_access(client: Any, user_id: str, company_id: UUID) -> None:
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


@router.get("")
def list_purchases(company_id: UUID, auth: CurrentAuth) -> list[dict[str, Any]]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)

    try:
        result = (
            client.table("transactions")
            .select(
                "id,company_id,contact_id,transaction_number,transaction_date,"
                "due_date,status,reference_number,notes,subtotal,total_amount,created_at"
            )
            .eq("company_id", str(company_id))
            .eq("transaction_type", "purchase")
            .order("transaction_date", desc=True)
            .order("created_at", desc=True)
            .execute()
        )
        return result.data or []
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load purchases.") from exc


@router.get("/{purchase_id}/items")
def list_purchase_items(
    company_id: UUID,
    purchase_id: UUID,
    auth: CurrentAuth,
) -> list[dict[str, Any]]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)

    try:
        result = (
            client.table("transaction_items")
            .select(
                "id,transaction_id,line_number,item_type,product_id,description,sku,"
                "unit_name,unit_abbreviation,quantity,unit_price,line_subtotal,line_total"
            )
            .eq("company_id", str(company_id))
            .eq("transaction_id", str(purchase_id))
            .order("line_number")
            .execute()
        )
        return result.data or []
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load purchase items.") from exc


@router.post("", status_code=status.HTTP_201_CREATED)
def create_purchase(
    company_id: UUID,
    payload: PurchaseCreate,
    auth: CurrentAuth,
) -> dict[str, Any]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)

    try:
        result = client.rpc(
            "create_purchase_draft",
            {
                "p_company_id": str(company_id),
                "p_supplier_id": str(payload.supplier_id),
                "p_transaction_number": payload.transaction_number,
                "p_transaction_date": payload.transaction_date.isoformat(),
                "p_due_date": payload.due_date.isoformat() if payload.due_date else None,
                "p_reference_number": payload.reference_number,
                "p_notes": payload.notes,
                "p_items": [item.model_dump(mode="json") for item in payload.items],
                "p_created_by": user["id"],
            },
        ).execute()
        if not result.data:
            raise HTTPException(status_code=502, detail="Purchase was not returned after creation.")
        return result.data
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Could not create purchase draft.") from exc


@router.post("/{purchase_id}/post")
def post_purchase(
    company_id: UUID,
    purchase_id: UUID,
    auth: CurrentAuth,
) -> dict[str, Any]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)

    try:
        result = client.rpc(
            "post_purchase",
            {
                "p_company_id": str(company_id),
                "p_transaction_id": str(purchase_id),
            },
        ).execute()
        if not result.data:
            raise HTTPException(status_code=502, detail="Posted purchase was not returned.")
        return result.data
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Could not post purchase.") from exc