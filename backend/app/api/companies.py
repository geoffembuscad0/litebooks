from datetime import date
from typing import Any
from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator
from postgrest.exceptions import APIError
from collections import defaultdict

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
        return value.upper()

    @field_validator("address", "contact_number", mode="before")
    @classmethod
    def normalize_optional_text(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip() or None
        return value

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip() or None
        return value

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        value = value.strip().upper()
        if len(value) != 3 or not value.isalpha():
            raise ValueError("Currency must be a three-letter code, such as PHP.")
        return value


class CompanyUpdate(BaseModel):
    company_name: str | None = Field(default=None, min_length=1, max_length=150)
    company_code: str | None = Field(default=None, min_length=1, max_length=50)
    address: str | None = Field(default=None, max_length=10000)
    contact_number: str | None = Field(default=None, max_length=30)
    email: EmailStr | None = None
    currency: str | None = Field(default=None, min_length=3, max_length=3)
    fiscal_year_start: int | None = Field(default=None, ge=1, le=12)
    timezone: str | None = Field(default=None, min_length=1, max_length=100)

    @field_validator("company_name", "company_code", "timezone")
    @classmethod
    def strip_text(cls, value: str | None) -> str | None:
        if value is None:
            return value
        value = value.strip()
        if not value:
            raise ValueError("This field cannot be blank.")
        return value

    @field_validator("company_code")
    @classmethod
    def normalize_company_code(cls, value: str | None) -> str | None:
        return value.upper() if value is not None else None

    @field_validator("address", "contact_number", mode="before")
    @classmethod
    def normalize_optional_text(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip() or None
        return value

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip() or None
        return value

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str | None) -> str | None:
        if value is None:
            return value
        value = value.strip().upper()
        if len(value) != 3 or not value.isalpha():
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
    created_at: str | Any

    model_config = ConfigDict(from_attributes=True)


COMPANY_FIELDS = "id,owner_id,company_name,company_code,address,contact_number,email,currency,fiscal_year_start,timezone,status,created_at"


def _get_owned_company(client: Any, user_id: str, company_id: UUID) -> dict[str, Any]:
    result = (
        client.table("companies")
        .select(COMPANY_FIELDS)
        .eq("id", str(company_id))
        .eq("owner_id", user_id)
        .eq("status", "active")
        .maybe_single()
        .execute()
    )
    if not result.data:
        # Do not reveal whether a company exists if it is not owned by this user.
        raise HTTPException(status_code=404, detail="Company not found.")
    return result.data


@router.get("", response_model=list[CompanyResponse])
def list_companies(auth: CurrentAuth) -> list[dict[str, Any]]:
    user, client = auth
    try:
        result = (
            client.table("companies")
            .select(COMPANY_FIELDS)
            .eq("owner_id", user["id"])
            .eq("status", "active")
            .order("company_name")
            .execute()
        )
        return result.data
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load your companies.") from exc


@router.get("/{company_id}", response_model=CompanyResponse)
def get_company(company_id: UUID, auth: CurrentAuth) -> dict[str, Any]:
    user, client = auth
    try:
        return _get_owned_company(client, user["id"], company_id)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load company settings.") from exc


@router.patch("/{company_id}", response_model=CompanyResponse)
def update_company(company_id: UUID, payload: CompanyUpdate, auth: CurrentAuth) -> dict[str, Any]:
    user, client = auth
    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Provide at least one setting to update.")
    try:
        # Ownership is checked independently of the company ID supplied by the client.
        _get_owned_company(client, user["id"], company_id)
        result = (
            client.table("companies")
            .update(changes)
            .eq("id", str(company_id))
            .eq("owner_id", user["id"])
            .execute()
        )
        if not result.data:
            raise HTTPException(status_code=404, detail="Company not found.")
        return result.data[0]
    except HTTPException:
        raise
    except APIError as exc:
        error_text = str(exc)
        if getattr(exc, "code", None) == "23505" or "unique_owner_company_code" in error_text or "companies_owner_company_code" in error_text:
            raise HTTPException(status_code=409, detail="You already use this company code for one of your companies.") from exc
        if getattr(exc, "code", None) == "42501":
            raise HTTPException(status_code=403, detail="You are not allowed to update this company.") from exc
        raise HTTPException(status_code=400, detail="Could not update company settings.") from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Company service is temporarily unavailable.") from exc


@router.get("/{company_id}/dashboard", tags=["dashboard"])
def get_company_dashboard(company_id: UUID, auth: CurrentAuth) -> dict[str, Any]:
    user, client = auth

    try:
        company = _get_owned_company(
            client,
            user["id"],
            company_id
        )

        today = date.today()
        month_start = today.replace(day=1).isoformat()
        today_string = today.isoformat()

        company_id_string = str(company_id)

        # --------------------------------------------------
        # 1. Monthly transactions
        # --------------------------------------------------

        transaction_result = (
            client.table("transactions")
            .select(
                "id,transaction_number,transaction_type,"
                "transaction_date,status,total_amount"
            )
            .eq("company_id", company_id_string)
            .eq("status", "posted")
            .gte("transaction_date", month_start)
            .lte("transaction_date", today_string)
            .order("transaction_date", desc=True)
            .execute()
        )

        transactions = transaction_result.data or []

        monthly_totals = {
            "sales": 0.0,
            "purchases": 0.0,
            "expenses": 0.0,
        }

        for transaction in transactions:
            amount = float(
                transaction.get("total_amount") or 0
            )

            transaction_type = transaction.get(
                "transaction_type"
            )

            if transaction_type == "sale":
                monthly_totals["sales"] += amount

            elif transaction_type == "purchase":
                monthly_totals["purchases"] += amount

            elif transaction_type == "expense":
                monthly_totals["expenses"] += amount

        # --------------------------------------------------
        # 2. Product records
        # --------------------------------------------------

        product_result = (
            client.table("products")
            .select(
                "id,name,sku,reorder_level,is_active"
            )
            .eq("company_id", company_id_string)
            .execute()
        )

        products = product_result.data or []

        active_products = [
            product
            for product in products
            if product.get("is_active")
        ]

        # --------------------------------------------------
        # 3. Inventory movements
        # --------------------------------------------------

        movement_result = (
            client.table("inventory_movements")
            .select(
                "product_id,movement_type,quantity,unit_cost"
            )
            .eq("company_id", company_id_string)
            .execute()
        )

        movements = movement_result.data or []

        stock_by_product = defaultdict(
            lambda: {
                "quantity": 0.0,
                "inventory_value": 0.0,
            }
        )

        incoming_movements = {
            "opening_stock",
            "purchase",
            "adjustment_in",
        }

        outgoing_movements = {
            "sale",
            "adjustment_out",
        }

        for movement in movements:
            product_id = movement["product_id"]

            quantity = float(
                movement.get("quantity") or 0
            )

            unit_cost = float(
                movement.get("unit_cost") or 0
            )

            movement_type = movement.get(
                "movement_type"
            )

            movement_value = quantity * unit_cost

            if movement_type in incoming_movements:
                stock_by_product[product_id]["quantity"] += quantity

                stock_by_product[product_id]["inventory_value"] += (
                    movement_value
                )

            elif movement_type in outgoing_movements:
                stock_by_product[product_id]["quantity"] -= quantity

                stock_by_product[product_id]["inventory_value"] -= (
                    movement_value
                )

        # --------------------------------------------------
        # 4. Calculate inventory summary
        # --------------------------------------------------

        total_stock_quantity = 0.0
        total_inventory_value = 0.0

        low_stock_products = []

        for product in active_products:
            product_id = product["id"]

            stock = stock_by_product[product_id]

            quantity = stock["quantity"]

            inventory_value = stock["inventory_value"]

            reorder_level = float(
                product.get("reorder_level") or 0
            )

            total_stock_quantity += quantity

            total_inventory_value += inventory_value

            if quantity <= reorder_level:
                low_stock_products.append({
                    "id": product_id,
                    "name": product["name"],
                    "sku": product.get("sku"),
                    "stock_quantity": round(quantity, 4),
                    "reorder_level": reorder_level,
                })

        # --------------------------------------------------
        # 5. Active accounts
        # --------------------------------------------------

        account_result = (
            client.table("accounts")
            .select("id", count="exact")
            .eq("company_id", company_id_string)
            .eq("is_active", True)
            .execute()
        )

        # --------------------------------------------------
        # 6. Dashboard response
        # --------------------------------------------------

        return {
            "company": company,

            "period_start": month_start,
            "period_end": today_string,

            # Financial activity
            "sales": round(monthly_totals["sales"], 2),
            "purchases": round(monthly_totals["purchases"], 2),
            "expenses": round(monthly_totals["expenses"], 2),

            # Transaction summary
            "transaction_count": len(transactions),

            "recent_transactions": transactions[:6],

            # Product summary
            "product_count": len(products),
            "active_product_count": len(active_products),

            # Inventory summary
            "total_stock_quantity": round(
                total_stock_quantity,
                4
            ),

            "total_inventory_value": round(
                total_inventory_value,
                2
            ),

            # Low-stock summary
            "low_stock_product_count": len(
                low_stock_products
            ),

            "low_stock_products": low_stock_products[:5],

            # Accounting summary
            "active_account_count": account_result.count or 0,
        }

    except HTTPException:
        raise

    except Exception as exc:
        logger.error("dashboard failed: %r", exc)
        raise HTTPException(status_code=502, detail="Could not load the company dashboard.") from exc


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
            raise HTTPException(status_code=409, detail="You already use this company code for one of your companies.") from exc
        if code == "42501":
            raise HTTPException(status_code=403, detail="You are not allowed to create this company.") from exc
        raise HTTPException(status_code=400, detail="Could not create company. Check the submitted details.") from exc
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Company service is temporarily unavailable.") from exc
