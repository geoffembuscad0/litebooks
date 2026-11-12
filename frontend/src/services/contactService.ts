import { apiRequest } from './inventoryService'

export type Contact = {
  id: string
  company_id: string
  name: string
  contact_person: string | null
  contact_type: 'individual' | 'business'
  is_customer: boolean
  is_supplier: boolean
  email: string | null
  phone: string | null
  tax_number: string | null
  billing_address: string | null
  shipping_address: string | null
  notes: string | null
  is_active: boolean
  created_at: string
  updated_at: string
}

export type ContactInput = {
  name: string
  contact_person?: string | null
  contact_type: 'individual' | 'business'
  is_customer: boolean
  is_supplier: boolean
  email?: string | null
  phone?: string | null
  tax_number?: string | null
  billing_address?: string | null
  shipping_address?: string | null
  notes?: string | null
  is_active?: boolean
}

export const contactService = {
  list: (token: string, companyId: string, filters: { search?: string; role?: 'all' | 'customer' | 'supplier' } = {}) => {
    const params = new URLSearchParams()
    if (filters.search?.trim()) params.set('search', filters.search.trim())
    if (filters.role && filters.role !== 'all') params.set('role', filters.role)
    const suffix = params.size ? `?${params.toString()}` : ''
    return apiRequest<Contact[]>(`/api/companies/${companyId}/contacts${suffix}`, token)
  },
  create: (token: string, companyId: string, input: ContactInput) => apiRequest<Contact>(`/api/companies/${companyId}/contacts`, token, {
    method: 'POST',
    body: JSON.stringify(input),
  }),
  update: (token: string, companyId: string, contactId: string, input: Partial<ContactInput>) => apiRequest<Contact>(`/api/companies/${companyId}/contacts/${contactId}`, token, {
    method: 'PATCH',
    body: JSON.stringify(input),
  }),
}
