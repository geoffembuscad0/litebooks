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

export type DashboardData = {
  company: Company
  period_start: string
  period_end: string
  sales: number
  purchases: number
  expenses: number
  transaction_count: number
  active_account_count: number
  recent_transactions: Array<{ id: string; transaction_number: string; transaction_type: string; transaction_date: string; status: string; total_amount: number }>
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
