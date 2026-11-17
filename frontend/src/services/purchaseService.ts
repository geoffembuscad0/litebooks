import { apiRequest } from './inventoryService'

export type Purchase = {
  id: string
  company_id: string
  contact_id: string
  transaction_number: string
  transaction_date: string
  due_date: string | null
  status: 'draft' | 'posted' | 'void'
  reference_number: string | null
  notes: string | null
  subtotal: number
  total_amount: number
  created_at: string
}

export type PurchaseItemInput = {
  product_id: string
  quantity: number
  unit_price: number
}

export type PurchaseInput = {
  supplier_id: string
  transaction_number: string
  transaction_date: string
  due_date?: string | null
  reference_number?: string | null
  notes?: string | null
  items: PurchaseItemInput[]
}

export const purchaseService = {
  list: (token: string, companyId: string) =>
    apiRequest<Purchase[]>(`/api/companies/${companyId}/purchases`, token),

  create: (token: string, companyId: string, payload: PurchaseInput) =>
    apiRequest<Purchase>(`/api/companies/${companyId}/purchases`, token, {
      method: 'POST',
      body: JSON.stringify(payload),
    }),

  post: (token: string, companyId: string, purchaseId: string) =>
    apiRequest<Purchase>(`/api/companies/${companyId}/purchases/${purchaseId}/post`, token, {
      method: 'POST',
    }),
}