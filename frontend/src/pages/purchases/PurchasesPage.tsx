import { useMemo, useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, Navigate, useParams } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { companyService } from '../../services/companyService'
import { contactService, type Contact } from '../../services/contactService'
import { inventoryService, type Product } from '../../services/inventoryService'
import { purchaseService, type PurchaseItemInput } from '../../services/purchaseService.ts'

type DraftLine = { product_id: string; quantity: string; unit_price: string }

const today = new Date().toISOString().slice(0, 10)
const money = (value: number) =>
  new Intl.NumberFormat(undefined, { style: 'currency', currency: 'PHP' }).format(value)

export default function PurchasesPage() {
  const { companyId } = useParams()
  const { session, user, signOut } = useAuth()
  const queryClient = useQueryClient()
  const [lines, setLines] = useState<DraftLine[]>([{ product_id: '', quantity: '1', unit_price: '0' }])
  const [message, setMessage] = useState('')

  const companies = useQuery({
    queryKey: ['companies', user?.id],
    queryFn: () => companyService.list(session!.access_token),
    enabled: Boolean(session),
  })
  const company = useMemo(
    () => companies.data?.find(item => item.id === companyId),
    [companies.data, companyId],
  )
  const suppliers = useQuery({
    queryKey: ['purchase-suppliers', companyId],
    queryFn: () => contactService.list(session!.access_token, companyId!, { role: 'supplier' }),
    enabled: Boolean(session && companyId),
  })
  const products = useQuery({
    queryKey: ['inventory-products', companyId],
    queryFn: () => inventoryService.listProducts(session!.access_token, companyId!),
    enabled: Boolean(session && companyId),
  })
  const purchases = useQuery({
    queryKey: ['purchases', companyId],
    queryFn: () => purchaseService.list(session!.access_token, companyId!),
    enabled: Boolean(session && companyId),
  })

  const refresh = async () => {
    await queryClient.invalidateQueries({ queryKey: ['purchases', companyId] })
    await queryClient.invalidateQueries({ queryKey: ['inventory-stock', companyId] })
    await queryClient.invalidateQueries({ queryKey: ['dashboard', companyId] })
  }

  const create = useMutation({
    mutationFn: (payload: Parameters<typeof purchaseService.create>[2]) =>
      purchaseService.create(session!.access_token, companyId!, payload),
    onSuccess: async () => {
      setMessage('Purchase draft created.')
      setLines([{ product_id: '', quantity: '1', unit_price: '0' }])
      await refresh()
    },
    onError: error => setMessage(error.message),
  })

  const post = useMutation({
    mutationFn: (purchaseId: string) =>
      purchaseService.post(session!.access_token, companyId!, purchaseId),
    onSuccess: async () => {
      setMessage('Purchase posted and stock movements recorded.')
      await refresh()
    },
    onError: error => setMessage(error.message),
  })

  if (!session) return <Navigate to="/login" replace />
  if (companies.isPending) return <div className="screen-state">Loading purchases…</div>
  if (companies.isError) return <main className="center-shell"><div className="alert error">{companies.error.message}</div></main>
  if (!company) return <Navigate to="/companies" replace />

  const supplierList = suppliers.data ?? []
  const productList = (products.data ?? []).filter(product => product.is_active)

  function updateLine(index: number, patch: Partial<DraftLine>) {
    setLines(current => current.map((line, i) => i === index ? { ...line, ...patch } : line))
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const items: PurchaseItemInput[] = lines.map(line => ({
      product_id: line.product_id,
      quantity: Number(line.quantity),
      unit_price: Number(line.unit_price),
    }))

    if (!items.length || items.some(item =>
      !item.product_id || !Number.isFinite(item.quantity) || item.quantity <= 0 ||
      !Number.isFinite(item.unit_price) || item.unit_price < 0
    )) {
      setMessage('Choose a product and enter a positive quantity and non-negative unit price for every line.')
      return
    }

    create.mutate({
      supplier_id: String(form.get('supplier_id') ?? ''),
      transaction_number: String(form.get('transaction_number') ?? '').trim(),
      transaction_date: String(form.get('transaction_date') ?? ''),
      due_date: String(form.get('due_date') ?? '') || null,
      reference_number: String(form.get('reference_number') ?? '').trim() || null,
      notes: String(form.get('notes') ?? '').trim() || null,
      items,
    })
  }

  return <main className="app-shell">
    <header className="topbar">
      <Link className="brand" to="/companies">LITE<span>BOOKS</span></Link>
      <nav className="top-nav">
        <Link className="nav-link" to={`/company/${company.id}`}>Dashboard</Link>
        <Link className="nav-link" to={`/company/${company.id}/inventory`}>Inventory</Link>
        <Link className="nav-link active" to={`/company/${company.id}/purchases`}>Purchases</Link>
        <Link className="nav-link" to={`/company/${company.id}/contacts`}>Contacts</Link>
      </nav>
      <div className="user-actions">
        <Link className="nav-link" to="/companies">Switch company</Link>
        <button className="text-button" onClick={() => void signOut()}>Sign out</button>
      </div>
    </header>

    <section className="dashboard-content">
      <div className="page-heading">
        <div>
          <p className="eyebrow">PURCHASES</p>
          <h1>{company.company_name}</h1>
          <p className="muted">Create a supplier purchase draft, then post it to add stock.</p>
        </div>
      </div>

      <form className="panel inventory-form" onSubmit={submit}>
        <div className="panel-heading"><div><h2>New purchase draft</h2></div></div>

        <div className="contacts-form">
          <label>Supplier
            <select name="supplier_id" required defaultValue="">
              <option value="" disabled>Select supplier</option>
              {supplierList.map((supplier: Contact) =>
                <option key={supplier.id} value={supplier.id}>{supplier.name}</option>
              )}
            </select>
          </label>
          <label>Purchase number<input name="transaction_number" required maxLength={50} /></label>
          <label>Purchase date<input name="transaction_date" type="date" required defaultValue={today} /></label>
          <label>Due date<input name="due_date" type="date" /></label>
          <label>Reference<input name="reference_number" maxLength={100} /></label>
          <label>Notes<input name="notes" /></label>
        </div>

        <h3>Purchase items</h3>
        {lines.map((line, index) => (
          <div className="contacts-form" key={index}>
            <label>Product
              <select required value={line.product_id} onChange={event => updateLine(index, { product_id: event.target.value })}>
                <option value="">Select product</option>
                {productList.map((product: Product) =>
                  <option key={product.id} value={product.id}>{product.name}{product.sku ? ` (${product.sku})` : ''}</option>
                )}
              </select>
            </label>
            <label>Quantity
              <input type="number" min="0.0001" step="0.0001" required value={line.quantity}
                onChange={event => updateLine(index, { quantity: event.target.value })} />
            </label>
            <label>Unit cost
              <input type="number" min="0" step="0.0001" required value={line.unit_price}
                onChange={event => updateLine(index, { unit_price: event.target.value })} />
            </label>
            <button type="button" className="text-button" disabled={lines.length === 1}
              onClick={() => setLines(current => current.filter((_, i) => i !== index))}>
              Remove item
            </button>
          </div>
        ))}
        <button type="button" className="button secondary"
          onClick={() => setLines(current => [...current, { product_id: '', quantity: '1', unit_price: '0' }])}>
          Add item
        </button>

        {message && <div className={`alert ${create.isError || post.isError ? 'error' : 'success'}`} role="status">{message}</div>}
        <div className="settings-actions">
          <button className="button primary" disabled={create.isPending}>
            {create.isPending ? 'Saving…' : 'Save draft'}
          </button>
        </div>
      </form>

      <section className="panel recent-panel">
        <div className="panel-heading"><div><h2>Purchases</h2><p>Drafts do not change stock. Posting a draft records its stock movements.</p></div></div>
        {purchases.isError && <div className="alert error">{purchases.error.message}</div>}
        <div className="table-wrap">
          <table>
            <thead><tr><th>Number</th><th>Date</th><th>Status</th><th className="align-right">Total</th><th /></tr></thead>
            <tbody>
              {(purchases.data ?? []).map(purchase => (
                <tr key={purchase.id}>
                  <td>{purchase.transaction_number}</td>
                  <td>{purchase.transaction_date}</td>
                  <td>{purchase.status}</td>
                  <td className="align-right">{money(Number(purchase.total_amount))}</td>
                  <td>
                    {purchase.status === 'draft' &&
                      <button className="button primary" disabled={post.isPending}
                        onClick={() => post.mutate(purchase.id)}>
                        Post purchase
                      </button>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </section>
  </main>
}