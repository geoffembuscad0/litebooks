import { apiRequest } from './inventoryService'

export type AccountBalance = {
  company_id: string
  account_id: string
  account_code: string
  account_name: string
  account_type: 'asset' | 'liability' | 'equity' | 'revenue' | 'expense'
  account_subtype: string | null
  normal_balance: 'debit' | 'credit'
  is_active: boolean
  debit_total: number | string
  credit_total: number | string
  balance: number | string
}

export const accountingService = {
  balances: (token: string, companyId: string) => apiRequest<AccountBalance[]>(`/api/companies/${companyId}/accounting/balances`, token),
}
