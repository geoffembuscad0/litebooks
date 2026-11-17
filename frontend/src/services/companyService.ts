const API_URL = import.meta.env.VITE_API_URL ?? 'http://127.0.0.1:8000'

export type Company = {
  id: string
  owner_id: string
  company_name: string
  company_code: string
  address: string | null
  contact_number: string | null
  email: string | null
  currency: string
  fiscal_year_start: number
  timezone: string
  status: string
  created_at: string
}

export type CompanyInput = {
  company_name: string
  company_code?: string
  address?: string
  contact_number?: string
  email?: string
  currency: string
  fiscal_year_start: number
}

export type DashboardTransaction = {
  id: string
  transaction_number: string
  transaction_type: 'purchase' | 'sale' | 'expense'
  transaction_date: string
  status: string
  total_amount: number
}

export type LowStockProduct = {
  id: string
  name: string
  sku: string | null
  stock_quantity: number
  reorder_level: number
}

export type DashboardData = {
  company: Company
  period_start: string
  period_end: string

  // Monthly financial activity
  sales: number
  purchases: number
  expenses: number

  // Transactions
  transaction_count: number
  recent_transactions: DashboardTransaction[]

  // Products
  product_count: number
  active_product_count: number

  // Inventory
  total_stock_quantity: number
  total_inventory_value: number

  // Low stock
  low_stock_product_count: number
  low_stock_products: LowStockProduct[]

  // Accounting
  active_account_count: number
}

export async function apiRequest<T>(path: string, accessToken: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_URL}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${accessToken}`,
      ...init?.headers,
    },
  })
  if (!response.ok) {
    const body = await response.json().catch(() => null)
    const detail = body?.detail
    throw new Error(typeof detail === 'string' ? detail : 'The request could not be completed.')
  }
  return response.json() as Promise<T>
}

export const companyService = {
  list: (token: string) => apiRequest<Company[]>('/api/companies', token),
  create: (token: string, company: CompanyInput) => apiRequest<Company>('/api/companies', token, {
    method: 'POST',
    body: JSON.stringify(company),
  }),
  update: (token: string, companyId: string, company: Partial<CompanyInput> & { timezone: string }) => apiRequest<Company>(`/api/companies/${companyId}`, token, {
    method: 'PATCH',
    body: JSON.stringify(company),
  }),
}

export const dashboardService = {
  get: (token: string, companyId: string) => apiRequest<DashboardData>(`/api/companies/${companyId}/dashboard`, token),
}
