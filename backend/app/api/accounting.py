from typing import Any
from uuid import UUID
from fastapi import APIRouter, HTTPException
from app.dependencies.auth import CurrentAuth

router = APIRouter(prefix="/api/companies/{company_id}/accounting", tags=["accounting"])

@router.get("/balances")
def list_account_balances(company_id: UUID, auth: CurrentAuth) -> list[dict[str, Any]]:
    user, client = auth
    company = client.table("companies").select("id").eq("id", str(company_id)).eq("owner_id", user["id"]).eq("status", "active").maybe_single().execute()
    if not company.data:
        raise HTTPException(status_code=404, detail="Company not found.")
    try:
        result = client.table("account_balances").select("company_id,account_id,account_code,account_name,account_type,account_subtype,normal_balance,is_active,debit_total,credit_total,balance").eq("company_id", str(company_id)).order("account_code").execute()
        return result.data or []
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not load posted account balances.") from exc
