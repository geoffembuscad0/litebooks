from datetime import date
from typing import Any
from uuid import UUID

from fastapi import APIRouter, HTTPException

from app.dependencies.auth import CurrentAuth

router = APIRouter(prefix="/api/companies/{company_id}/accounting", tags=["accounting"])


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


@router.get("/balances")
def list_account_balances(company_id: UUID, auth: CurrentAuth) -> list[dict[str, Any]]:
    user, client = auth
    _require_company_owner(client, user["id"], company_id)
    try:
        result = (
            client.table("account_balances")
            .select("company_id,account_id,account_code,account_name,account_type,account_subtype,normal_balance,is_active,debit_total,credit_total,balance")
            .eq("company_id", str(company_id))
            .order("account_code")
            .execute()
        )
        return result.data or []
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load posted account balances.") from exc


@router.get("/trial-balance")
def get_trial_balance(company_id: UUID, auth: CurrentAuth, as_of: date | None = None) -> dict[str, Any]:
    user, client = auth
    _require_company_owner(client, user["id"], company_id)
    report_date = as_of or date.today()
    try:
        result = client.rpc("get_trial_balance", {
            "p_company_id": str(company_id),
            "p_as_of": report_date.isoformat(),
        }).execute()
        if not result.data:
            return {"as_of": report_date.isoformat(), "rows": [], "totals": {"debit_balance": 0, "credit_balance": 0}}
        return result.data
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not generate the Trial Balance.") from exc


@router.get("/profit-and-loss")
def get_profit_and_loss(
    company_id: UUID,
    auth: CurrentAuth,
    start_date: date | None = None,
    end_date: date | None = None,
) -> dict[str, Any]:
    user, client = auth
    _require_company_owner(client, user["id"], company_id)
    period_end = end_date or date.today()
    period_start = start_date or period_end.replace(day=1)
    if period_start > period_end:
        raise HTTPException(status_code=422, detail="Start date must be on or before end date.")
    try:
        result = client.rpc("get_profit_and_loss", {
            "p_company_id": str(company_id),
            "p_start_date": period_start.isoformat(),
            "p_end_date": period_end.isoformat(),
        }).execute()
        if not result.data:
            return {"start_date": period_start.isoformat(), "end_date": period_end.isoformat(), "revenue": 0, "expenses": 0, "net_income": 0, "revenues": [], "expense_accounts": []}
        return result.data
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not generate the Profit & Loss report.") from exc
