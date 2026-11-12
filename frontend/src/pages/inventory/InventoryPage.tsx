import { useMemo, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, Navigate, useParams } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { companyService } from '../../services/companyService'
import { inventoryService, type Product } from '../../services/inventoryService'

const money = (amount: number) => new Intl.NumberFormat(undefined, { style: 'currency', currency: 'PHP', maximumFractionDigits: 2 }).format(amount)

export default function InventoryPage() {
  const { companyId } = useParams()
  const { session, user, signOut } = useAuth()
  const queryClient = useQueryClient()
  const companies = useQuery({ queryKey: ['companies', user?.id], queryFn: () => companyService.list(session!.access_token), enabled: Boolean(session) })
  const company = useMemo(() => companies.data?.find(item => item.id === companyId), [companies.data, companyId])
  const summary = useQuery({ queryKey: ['inventory-summary', companyId], queryFn: () => inventoryService.getSummary(session!.access_token, companyId!), enabled: Boolean(session && companyId) })
  const categories = useQuery({ queryKey: ['inventory-categories', companyId], queryFn: () => inventoryService.listCategories(session!.access_token, companyId!), enabled: Boolean(session && companyId) })
  const units = useQuery({ queryKey: ['inventory-units', companyId], queryFn: () => inventoryService.listUnits(session!.access_token, companyId!), enabled: Boolean(session && companyId) })
  const products = useQuery({ queryKey: ['inventory-products', companyId], queryFn: () => inventoryService.listProducts(session!.access_token, companyId!), enabled: Boolean(session && companyId) })
  const createCategory = useMutation({ mutationFn: (payload: { name: string; description?: string; is_active?: boolean }) => inventoryService.createCategory(session!.access_token, companyId!, payload), onSuccess: async () => { await queryClient.invalidateQueries({ queryKey: ['inventory-categories', companyId] }); await queryClient.invalidateQueries({ queryKey: ['inventory-summary', companyId] }) } })
  const createUnit = useMutation({ mutationFn: (payload: { name: string; abbreviation: string; description?: string; is_active?: boolean }) => inventoryService.createUnit(session!.access_token, companyId!, payload), onSuccess: async () => { await queryClient.invalidateQueries({ queryKey: ['inventory-units', companyId] }); await queryClient.invalidateQueries({ queryKey: ['inventory-summary', companyId] }) } })
  const createProduct = useMutation({ mutationFn: (payload: { category_id?: string | null; unit_of_measure_id: string; sku?: string | null; barcode?: string | null; name: string; description?: string | null; default_cost?: number; selling_price?: number; reorder_level?: number; is_active?: boolean }) => inventoryService.createProduct(session!.access_token, companyId!, payload), onSuccess: async () => { await queryClient.invalidateQueries({ queryKey: ['inventory-products', companyId] }); await queryClient.invalidateQueries({ queryKey: ['inventory-summary', companyId] }) } })

  if (!session) return <Navigate to="/login" replace />
  if (companies.isPending || summary.isPending) return <div className="screen-state">Loading inventory…</div>
  if (companies.isError) return <main className="center-shell"><div className="alert error">{companies.error.message}</div></main>
  if (!company) return <Navigate to="/companies" replace />

  function submitCategory(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const name = String(form.get('category_name') ?? '').trim()
    if (!name) return
    createCategory.mutate({ name, description: String(form.get('category_description') ?? '').trim() || undefined })
    event.currentTarget.reset()
  }

  function submitUnit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const name = String(form.get('unit_name') ?? '').trim()
    const abbreviation = String(form.get('unit_abbreviation') ?? '').trim()
    if (!name || !abbreviation) return
    createUnit.mutate({ name, abbreviation, description: String(form.get('unit_description') ?? '').trim() || undefined })
    event.currentTarget.reset()
  }

  function submitProduct(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const unitId = String(form.get('unit_of_measure_id') ?? '').trim()
    const name = String(form.get('product_name') ?? '').trim()
    if (!unitId || !name) return
    createProduct.mutate({ category_id: String(form.get('category_id') ?? '') || null, unit_of_measure_id: unitId, sku: String(form.get('sku') ?? '').trim() || null, barcode: String(form.get('barcode') ?? '').trim() || null, name, description: String(form.get('product_description') ?? '').trim() || null, default_cost: Number(form.get('default_cost') ?? 0), selling_price: Number(form.get('selling_price') ?? 0), reorder_level: Number(form.get('reorder_level') ?? 0), is_active: true })
    event.currentTarget.reset()
  }

  const productsList = products.data ?? []
  const categoriesList = categories.data ?? []
  const unitsList = units.data ?? []

  return <main className="app-shell">
    <header className="topbar">
      <Link className="brand" to="/companies">LITE<span>BOOKS</span></Link>
      <nav className="top-nav"><Link className="nav-link" to={`/company/${company.id}`}>Dashboard</Link><Link className="nav-link active" to={`/company/${company.id}/inventory`}>Inventory</Link><Link className="nav-link" to={`/company/${company.id}/contacts`}>Contacts</Link><Link className="nav-link" to={`/company/${company.id}/settings`}>Company settings</Link></nav>
      <div className="user-actions"><Link className="nav-link" to="/account">My profile</Link><Link className="text-button" to="/companies">Switch company</Link><button className="text-button" onClick={() => void signOut()}>Sign out</button></div>
    </header>
    <section className="dashboard-content">
      <div className="page-heading"><div><p className="eyebrow">INVENTORY</p><h1>{company.company_name}</h1><p className="muted">Manage categories, units, and products for this workspace.</p></div></div>
      <div className="metric-grid"><article className="metric-card"><span className="metric-icon blue">▦</span><p>Products</p><strong>{summary.data?.product_count ?? 0}</strong><small>Active and archived records</small></article><article className="metric-card"><span className="metric-icon green">◫</span><p>Categories</p><strong>{summary.data?.category_count ?? 0}</strong><small>Grouped product types</small></article><article className="metric-card"><span className="metric-icon amber">⌁</span><p>Units</p><strong>{summary.data?.unit_count ?? 0}</strong><small>Warehouse measures</small></article><article className="metric-card"><span className="metric-icon rose">₱</span><p>Value</p><strong>{money(summary.data?.total_inventory_value ?? 0)}</strong><small>Based on selling prices</small></article></div>
      <div className="inventory-grid"><div className="panel inventory-panel"><div className="panel-heading"><div><h2>Add category</h2></div></div><form className="mini-form" onSubmit={submitCategory}><label>Category name<input name="category_name" placeholder="Bakery" required /></label><label>Description<input name="category_description" placeholder="Optional notes" /></label><button className="button primary" disabled={createCategory.isPending}>{createCategory.isPending ? 'Saving…' : 'Add category'}</button></form></div><div className="panel inventory-panel"><div className="panel-heading"><div><h2>Add unit</h2></div></div><form className="mini-form" onSubmit={submitUnit}><label>Unit name<input name="unit_name" placeholder="Piece" required /></label><label>Abbreviation<input name="unit_abbreviation" placeholder="pc" required /></label><label>Description<input name="unit_description" placeholder="Optional notes" /></label><button className="button primary" disabled={createUnit.isPending}>{createUnit.isPending ? 'Saving…' : 'Add unit'}</button></form></div></div>
      <div className="panel inventory-panel product-panel"><div className="panel-heading"><div><h2>Add product</h2></div></div><form className="inventory-form" onSubmit={submitProduct}><label>Product name<input name="product_name" placeholder="Rice 5kg" required /></label><label>SKU<input name="sku" placeholder="SKU-001" /></label><label>Barcode<input name="barcode" placeholder="123456" /></label><label>Category<select name="category_id" defaultValue=""><option value="">No category</option>{categoriesList.map(cat => <option key={cat.id} value={cat.id}>{cat.name}</option>)}</select></label><label>Unit of measure<select name="unit_of_measure_id" defaultValue={unitsList[0]?.id ?? ''} required>{unitsList.map(unit => <option key={unit.id} value={unit.id}>{unit.name} ({unit.abbreviation})</option>)}</select></label><label>Default cost<input name="default_cost" type="number" min="0" step="0.01" defaultValue={0} /></label><label>Selling price<input name="selling_price" type="number" min="0" step="0.01" defaultValue={0} /></label><label>Reorder level<input name="reorder_level" type="number" min="0" step="0.01" defaultValue={0} /></label><label className="full-width">Description<textarea name="product_description" rows={3} placeholder="Optional description" /></label><button className="button primary full-width" disabled={createProduct.isPending}>{createProduct.isPending ? 'Creating product…' : 'Save product'}</button></form></div>
      <div className="panel recent-panel"><div className="panel-heading"><div><h2>Products</h2><p>Current inventory items for this company</p></div></div>{productsList.length ? <div className="table-wrap"><table><thead><tr><th>Product</th><th>Category</th><th>SKU</th><th>Unit</th><th>Cost</th><th>Price</th><th>Reorder</th></tr></thead><tbody>{productsList.map((product: Product) => <tr key={product.id}><td>{product.name}</td><td>{categoriesList.find(cat => cat.id === product.category_id)?.name ?? '—'}</td><td>{product.sku ?? '—'}</td><td>{unitsList.find(unit => unit.id === product.unit_of_measure_id)?.abbreviation ?? '—'}</td><td>{money(product.default_cost)}</td><td>{money(product.selling_price)}</td><td>{product.reorder_level}</td></tr>)}</tbody></table></div> : <div className="empty-state"><span className="empty-symbol">◫</span><h3>No products yet</h3><p>Create your first product to begin tracking inventory.</p></div>}</div>
    </section>
  </main>
}
