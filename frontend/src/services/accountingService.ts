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

export type TrialBalanceRow = {
  account_id: string
  account_code: string
  account_name: string
  account_type: string
  normal_balance: 'debit' | 'credit'
  debit_total: number | string
  credit_total: number | string
  debit_balance: number | string
  credit_balance: number | string
}

export type TrialBalanceReport = {
  as_of: string
  rows: TrialBalanceRow[]
  totals: {
    debit_total: number | string
    credit_total: number | string
    debit_balance: number | string
    credit_balance: number | string
  }
}

export type ProfitAndLossReport = {
  start_date: string
  end_date: string
  revenue: number | string
  expenses: number | string
  net_income: number | string
  revenues: Array<{ account_id: string; account_code: string; account_name: string; amount: number | string }>
  expense_accounts: Array<{ account_id: string; account_code: string; account_name: string; amount: number | string }>
}

export type BalanceSheetAccount = {
  account_id: string | null
  account_code: string
  account_name: string
  balance: number | string
}

export type BalanceSheetReport = {
  as_of: string
  fiscal_year_start: string | null
  assets: BalanceSheetAccount[]
  liabilities: BalanceSheetAccount[]
  equity: BalanceSheetAccount[]
  current_net_income: number | string
  total_assets: number | string
  total_liabilities: number | string
  total_equity: number | string
  total_liabilities_and_equity: number | string
  balance_difference: number | string
}

export const accountingService = {
  balances: (token: string, companyId: string) => apiRequest<AccountBalance[]>(`/api/companies/${companyId}/accounting/balances`, token),
  trialBalance: (token: string, companyId: string, asOf: string) => apiRequest<TrialBalanceReport>(`/api/companies/${companyId}/accounting/trial-balance?as_of=${encodeURIComponent(asOf)}`, token),
  profitAndLoss: (token: string, companyId: string, startDate: string, endDate: string) => apiRequest<ProfitAndLossReport>(`/api/companies/${companyId}/accounting/profit-and-loss?start_date=${encodeURIComponent(startDate)}&end_date=${encodeURIComponent(endDate)}`, token),
  balanceSheet: (token: string, companyId: string, asOf: string) => apiRequest<BalanceSheetReport>(`/api/companies/${companyId}/accounting/balance-sheet?as_of=${encodeURIComponent(asOf)}`, token),
}
