const API_URL = import.meta.env.VITE_API_URL ?? 'http://127.0.0.1:8000'

export type Category = {
  id: string
  company_id: string
  name: string
  description: string | null
  is_active: boolean
  created_at: string
}

export type UnitOfMeasure = {
  id: string
  company_id: string
  name: string
  abbreviation: string
  description: string | null
  is_active: boolean
  created_at: string
}

export type Product = {
  id: string
  company_id: string
  category_id: string | null
  unit_of_measure_id: string
  sku: string | null
  barcode: string | null
  name: string
  description: string | null
  default_cost: number
  selling_price: number
  reorder_level: number
  is_active: boolean
  created_at: string
}

export type StockMovement = {
  id: string
  product_id: string
  movement_type: 'opening_stock' | 'purchase' | 'sale' | 'adjustment_in' | 'adjustment_out'
  movement_date: string
  quantity: number
  unit_cost: number
  total_cost: number
  reference_number: string | null
  notes: string | null
  created_at: string
}

export type StockMovementInput = {
  product_id: string
  movement_type: 'opening_stock' | 'adjustment_in' | 'adjustment_out'
  movement_date: string
  quantity: number
  unit_cost: number
  notes?: string | null
}

export type InventorySummary = {
  company_id: string
  product_count: number
  category_count: number
  unit_count: number
  active_product_count: number
  total_inventory_value: number
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

export const inventoryService = {
  getSummary: (token: string, companyId: string) => apiRequest<InventorySummary>(`/api/inventory/companies/${companyId}/summary`, token),
  listCategories: (token: string, companyId: string) => apiRequest<Category[]>(`/api/inventory/companies/${companyId}/categories`, token),
  createCategory: (token: string, companyId: string, payload: { name: string; description?: string; is_active?: boolean }) => apiRequest<Category>(`/api/inventory/companies/${companyId}/categories`, token, {
    method: 'POST',
    body: JSON.stringify(payload),
  }),
  listUnits: (token: string, companyId: string) => apiRequest<UnitOfMeasure[]>(`/api/inventory/companies/${companyId}/units`, token),
  createUnit: (token: string, companyId: string, payload: { name: string; abbreviation: string; description?: string; is_active?: boolean }) => apiRequest<UnitOfMeasure>(`/api/inventory/companies/${companyId}/units`, token, {
    method: 'POST',
    body: JSON.stringify(payload),
  }),
  listProducts: (token: string, companyId: string) => apiRequest<Product[]>(`/api/inventory/companies/${companyId}/products`, token),
  createProduct: (token: string, companyId: string, payload: {
    category_id?: string | null
    unit_of_measure_id: string
    sku?: string | null
    barcode?: string | null
    name: string
    description?: string | null
    default_cost?: number
    selling_price?: number
    reorder_level?: number
    is_active?: boolean
  }) => apiRequest<Product>(`/api/inventory/companies/${companyId}/products`, token, {
    method: 'POST',
    body: JSON.stringify(payload),
  }),
  updateProduct: (
    token: string,
    companyId: string,
    productId: string,
    payload: Partial<{
      category_id: string | null
      unit_of_measure_id: string
      sku: string | null
      barcode: string | null
      name: string
      description: string | null
      default_cost: number
      selling_price: number
      reorder_level: number
      is_active: boolean
    }>,
  ) => apiRequest<Product>(
    `/api/inventory/companies/${companyId}/products/${productId}`,
    token,
    { method: 'PATCH', body: JSON.stringify(payload) },
  ),
  listStock: (token: string, companyId: string) =>
    apiRequest<StockMovement[]>(`/api/inventory/companies/${companyId}/stock`, token),
  createStockMovement: (token: string, companyId: string, payload: StockMovementInput) =>
    apiRequest<StockMovement>(`/api/inventory/companies/${companyId}/stock`, token, {
      method: 'POST',
      body: JSON.stringify(payload),
    }),
}
