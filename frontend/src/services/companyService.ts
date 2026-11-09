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
  company_code: string
  address?: string
  contact_number?: string
  email?: string
  currency: string
  fiscal_year_start: number
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
}
