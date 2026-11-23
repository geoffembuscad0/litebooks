from datetime import date, datetime
from typing import Any, Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.dependencies.auth import CurrentAuth

router = APIRouter(prefix="/api/inventory", tags=["inventory"])


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=10000)
    is_active: bool = True

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Category name cannot be blank.")
        return value

    @field_validator("description", mode="before")
    @classmethod
    def normalize_description(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip() or None
        return value


class UnitCreate(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    abbreviation: str = Field(min_length=1, max_length=15)
    description: str | None = Field(default=None, max_length=10000)
    is_active: bool = True

    @field_validator("name", "abbreviation")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("This field cannot be blank.")
        return value

    @field_validator("description", mode="before")
    @classmethod
    def normalize_description(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip() or None
        return value


class ProductCreate(BaseModel):
    category_id: UUID | None = None
    unit_of_measure_id: UUID | None = None
    sku: str | None = Field(default=None, max_length=100)
    barcode: str | None = Field(default=None, max_length=100)
    name: str = Field(min_length=1, max_length=150)
    description: str | None = Field(default=None, max_length=10000)
    default_cost: float = Field(default=0.0, ge=0)
    selling_price: float = Field(default=0.0, ge=0)
    reorder_level: float = Field(default=0.0, ge=0)
    is_active: bool = True

    @field_validator("name", "sku", "barcode")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return value
        value = value.strip()
        if not value:
            return None
        return value

    @field_validator("description", mode="before")
    @classmethod
    def normalize_description(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip() or None
        return value


class ProductUpdate(BaseModel):
    category_id: UUID | None = None
    unit_of_measure_id: UUID | None = None
    sku: str | None = Field(default=None, max_length=100)
    barcode: str | None = Field(default=None, max_length=100)
    name: str | None = Field(default=None, min_length=1, max_length=150)
    description: str | None = Field(default=None, max_length=10000)
    default_cost: float | None = Field(default=None, ge=0)
    selling_price: float | None = Field(default=None, ge=0)
    reorder_level: float | None = Field(default=None, ge=0)
    is_active: bool | None = None

    @field_validator("name", "sku", "barcode")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return value
        value = value.strip()
        if not value and value is not None:
            return None
        return value

    @field_validator("description", mode="before")
    @classmethod
    def normalize_description(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip() or None
        return value


class InventorySummary(BaseModel):
    company_id: UUID
    product_count: int = 0
    category_count: int = 0
    unit_count: int = 0
    active_product_count: int = 0
    total_inventory_value: float = 0.0

    model_config = ConfigDict(from_attributes=True)


class CategoryResponse(BaseModel):
    id: UUID
    company_id: UUID
    name: str
    description: str | None
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class UnitResponse(BaseModel):
    id: UUID
    company_id: UUID
    name: str
    abbreviation: str
    description: str | None
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ProductResponse(BaseModel):
    id: UUID
    company_id: UUID
    category_id: UUID | None
    unit_of_measure_id: UUID
    sku: str | None
    barcode: str | None
    name: str
    description: str | None
    default_cost: float
    selling_price: float
    reorder_level: float
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class StockMovementCreate(BaseModel):
    product_id: UUID
    movement_type: Literal[
        "opening_stock",
        "adjustment_in",
        "adjustment_out",
    ]
    movement_date: date
    quantity: float = Field(gt=0)

    # Required for opening stock and adjustment-in.
    # Ignored and recalculated by PostgreSQL for adjustment-out.
    unit_cost: float | None = Field(default=None, ge=0)

    notes: str | None = Field(default=None, max_length=10000)

    @field_validator("notes", mode="before")
    @classmethod
    def normalize_notes(cls, value: Any) -> Any:
        return value.strip() or None if isinstance(value, str) else value

def _require_company_access(client: Any, user_id: str, company_id: UUID) -> dict[str, Any]:
    result = (
        client.table("companies")
        .select("id,owner_id,company_name,company_code")
        .eq("id", str(company_id))
        .eq("owner_id", user_id)
        .eq("status", "active")
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Company not found.")
    return result.data


def _ensure_valid_category(client: Any, company_id: UUID, category_id: UUID | None) -> None:
    if category_id is None:
        return
    result = (
        client.table("categories")
        .select("id")
        .eq("company_id", str(company_id))
        .eq("id", str(category_id))
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=400, detail="The selected category does not belong to this company.")


def _ensure_valid_unit(client: Any, company_id: UUID, unit_id: UUID | None) -> None:
    if unit_id is None:
        raise HTTPException(status_code=400, detail="A unit of measure is required.")
    result = (
        client.table("unit_of_measures")
        .select("id")
        .eq("company_id", str(company_id))
        .eq("id", str(unit_id))
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=400, detail="The selected unit of measure does not belong to this company.")


@router.get("/companies/{company_id}/summary")
def get_inventory_summary(
    company_id: UUID,
    auth: CurrentAuth,
) -> dict[str, Any]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)
    try:
        product_count = (
            client.table("products")
            .select("id", count="exact")
            .eq("company_id", str(company_id))
            .execute()
        )

        category_count = (
            client.table("categories")
            .select("id", count="exact")
            .eq("company_id", str(company_id))
            .execute()
        )

        unit_count = (
            client.table("unit_of_measures")
            .select("id", count="exact")
            .eq("company_id", str(company_id))
            .execute()
        )

        active_products = (
            client.table("products")
            .select("id", count="exact")
            .eq("company_id", str(company_id))
            .eq("is_active", True)
            .execute()
        )

        # Obtain actual inventory carrying value from PostgreSQL.
        valuation_result = client.rpc(
            "get_inventory_valuation",
            {
                "p_company_id": str(company_id),
            },
        ).execute()

        total_inventory_value = float(
            valuation_result.data or 0
        )

        return {
            "company_id": str(company_id),
            "product_count": product_count.count or 0,
            "category_count": category_count.count or 0,
            "unit_count": unit_count.count or 0,
            "active_product_count": active_products.count or 0,
            "total_inventory_value": round(
                total_inventory_value,
                2,
            ),
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail="Could not load inventory summary.",
        ) from exc


@router.get("/companies/{company_id}/categories", response_model=list[CategoryResponse])
def list_categories(company_id: UUID, auth: CurrentAuth) -> list[dict[str, Any]]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)
    try:
        result = (
            client.table("categories")
            .select("id,company_id,name,description,is_active,created_at")
            .eq("company_id", str(company_id))
            .order("name")
            .execute()
        )
        return result.data
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load categories.") from exc


@router.post("/companies/{company_id}/categories", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
def create_category(company_id: UUID, payload: CategoryCreate, auth: CurrentAuth) -> dict[str, Any]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)
    row = payload.model_dump()
    row["company_id"] = str(company_id)
    try:
        result = client.table("categories").insert(row).execute()
        if not result.data:
            raise HTTPException(status_code=502, detail="Category was not created.")
        return result.data[0]
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Could not create category.") from exc


@router.get("/companies/{company_id}/units", response_model=list[UnitResponse])
def list_units(company_id: UUID, auth: CurrentAuth) -> list[dict[str, Any]]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)
    try:
        result = (
            client.table("unit_of_measures")
            .select("id,company_id,name,abbreviation,description,is_active,created_at")
            .eq("company_id", str(company_id))
            .order("name")
            .execute()
        )
        return result.data
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load units of measure.") from exc


@router.post("/companies/{company_id}/units", response_model=UnitResponse, status_code=status.HTTP_201_CREATED)
def create_unit(company_id: UUID, payload: UnitCreate, auth: CurrentAuth) -> dict[str, Any]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)
    row = payload.model_dump()
    row["company_id"] = str(company_id)
    try:
        result = client.table("unit_of_measures").insert(row).execute()
        if not result.data:
            raise HTTPException(status_code=502, detail="Unit of measure was not created.")
        return result.data[0]
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Could not create unit of measure.") from exc


@router.get("/companies/{company_id}/products", response_model=list[ProductResponse])
def list_products(company_id: UUID, auth: CurrentAuth) -> list[dict[str, Any]]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)
    try:
        result = (
            client.table("products")
            .select("id,company_id,category_id,unit_of_measure_id,sku,barcode,name,description,default_cost,selling_price,reorder_level,is_active,created_at")
            .eq("company_id", str(company_id))
            .order("name")
            .execute()
        )
        return result.data
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load products.") from exc


@router.post("/companies/{company_id}/products", response_model=ProductResponse, status_code=status.HTTP_201_CREATED)
def create_product(company_id: UUID, payload: ProductCreate, auth: CurrentAuth) -> dict[str, Any]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)
    _ensure_valid_category(client, company_id, payload.category_id)
    _ensure_valid_unit(client, company_id, payload.unit_of_measure_id)
    row = payload.model_dump(exclude_none=True)
    row["company_id"] = str(company_id)
    try:
        result = client.table("products").insert(row).execute()
        if not result.data:
            raise HTTPException(status_code=502, detail="Product was not created.")
        return result.data[0]
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Could not create product.") from exc


@router.patch(
    "/companies/{company_id}/products/{product_id}",
    response_model=ProductResponse,
)
def update_product(
    company_id: UUID,
    product_id: UUID,
    payload: ProductUpdate,
    auth: CurrentAuth,
) -> dict[str, Any]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)

    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(status_code=400, detail="Provide at least one product field to update.")

    try:
        if "category_id" in changes:
            _ensure_valid_category(client, company_id, changes["category_id"])
        if "unit_of_measure_id" in changes:
            _ensure_valid_unit(client, company_id, changes["unit_of_measure_id"])

        result = (
            client.table("products")
            .update(changes)
            .eq("company_id", str(company_id))
            .eq("id", str(product_id))
            .execute()
        )
        if not result.data:
            raise HTTPException(status_code=404, detail="Product not found.")
        return result.data[0]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Could not update product.") from exc


@router.get("/companies/{company_id}/stock")
def list_stock(company_id: UUID, auth: CurrentAuth) -> list[dict[str, Any]]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)

    try:
        result = (
            client.table("inventory_movements")
            .select("id,product_id,movement_type,movement_date,quantity,unit_cost,total_cost,reference_number,notes,created_at")
            .eq("company_id", str(company_id))
            .order("movement_date", desc=True)
            .order("created_at", desc=True)
            .execute()
        )
        return result.data or []
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load stock movements.") from exc


@router.post("/companies/{company_id}/stock",status_code=status.HTTP_201_CREATED,)
def create_stock_movement(
    company_id: UUID,
    payload: "StockMovementCreate",
    auth: CurrentAuth,
) -> dict[str, Any]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)

    try:
        result = client.rpc(
            "record_inventory_movement",
            {
                "p_company_id": str(company_id),
                "p_product_id": str(payload.product_id),
                "p_movement_type": payload.movement_type,
                "p_movement_date": payload.movement_date.isoformat(),
                "p_quantity": payload.quantity,
                "p_unit_cost": payload.unit_cost,
                "p_notes": payload.notes,
                "p_created_by": user["id"],
            },
        ).execute()
        if not result.data:
            raise HTTPException(status_code=502, detail="Stock movement was not returned after creation.")
        return result.data
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Could not record stock movement.") from exc


@router.get("/companies/{company_id}")
def company_inventory_root(company_id: UUID, auth: CurrentAuth) -> dict[str, Any]:
    user, client = auth
    _require_company_access(client, user["id"], company_id)
    return {"company_id": str(company_id), "status": "inventory-ready"}


@router.get("/health")
def inventory_health() -> dict[str, str]:
    return {"status": "healthy"}


__all__ = [
    "router",
    "CategoryCreate",
    "CategoryResponse",
    "UnitCreate",
    "UnitResponse",
    "ProductCreate",
    "ProductResponse",
    "InventorySummary",
    "ProductUpdate",
    "StockMovementCreate",
]


# This module intentionally keeps inventory access tied to the owning user.
# Selecting a company does not grant access by itself; the server verifies ownership before every operation.


