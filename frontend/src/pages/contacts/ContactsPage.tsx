import { useMemo, useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, Navigate, useParams } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { companyService } from '../../services/companyService'
import { contactService, type Contact, type ContactInput } from '../../services/contactService'

const emptyForm = (): ContactInput => ({ name: '', contact_type: 'business', is_customer: true, is_supplier: false })

export default function ContactsPage() {
  const { companyId } = useParams()
  const { session, user, signOut } = useAuth()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')
  const [role, setRole] = useState<'all' | 'customer' | 'supplier'>('all')
  const [editing, setEditing] = useState<Contact | null>(null)
  const [message, setMessage] = useState('')
  const companies = useQuery({ queryKey: ['companies', user?.id], queryFn: () => companyService.list(session!.access_token), enabled: Boolean(session) })
  const company = useMemo(() => companies.data?.find(item => item.id === companyId), [companies.data, companyId])
  const contacts = useQuery({
    queryKey: ['contacts', companyId, search, role],
    queryFn: () => contactService.list(session!.access_token, companyId!, { search, role }),
    enabled: Boolean(session && companyId),
  })
  const save = useMutation({
    mutationFn: (input: ContactInput) => editing
      ? contactService.update(session!.access_token, companyId!, editing.id, input)
      : contactService.create(session!.access_token, companyId!, input),
    onSuccess: async () => {
      setMessage(editing ? 'Contact updated.' : 'Contact created.')
      setEditing(null)
      await queryClient.invalidateQueries({ queryKey: ['contacts', companyId] })
    },
    onError: (error: Error) => setMessage(error.message),
  })

  if (!session) return <Navigate to="/login" replace />
  if (companies.isPending) return <div className="screen-state">Loading company…</div>
  if (companies.isError) return <main className="center-shell"><div className="alert error">{companies.error.message}<button className="text-button" onClick={() => void companies.refetch()}>Try again</button></div></main>
  if (!company) return <Navigate to="/companies" replace />

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setMessage('')
    const form = new FormData(event.currentTarget)
    const input: ContactInput = {
      name: String(form.get('name') ?? '').trim(),
      contact_person: String(form.get('contact_person') ?? '').trim() || null,
      contact_type: String(form.get('contact_type')) as ContactInput['contact_type'],
      is_customer: form.get('is_customer') === 'on',
      is_supplier: form.get('is_supplier') === 'on',
      email: String(form.get('email') ?? '').trim() || null,
      phone: String(form.get('phone') ?? '').trim() || null,
      tax_number: String(form.get('tax_number') ?? '').trim() || null,
      billing_address: String(form.get('billing_address') ?? '').trim() || null,
      shipping_address: String(form.get('shipping_address') ?? '').trim() || null,
      notes: String(form.get('notes') ?? '').trim() || null,
    }
    save.mutate(input)
  }

  function startEdit(contact: Contact) {
    setEditing(contact)
    setMessage('')
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  function toggleActive(contact: Contact) {
    contactService.update(session!.access_token, companyId!, contact.id, { is_active: !contact.is_active })
      .then(() => queryClient.invalidateQueries({ queryKey: ['contacts', companyId] }))
      .catch((error: Error) => setMessage(error.message))
  }

  const items = contacts.data ?? []
  const initial = editing ?? emptyForm()

  return <main className="app-shell">
    <header className="topbar">
      <Link className="brand" to="/companies">LITE<span>BOOKS</span></Link>
      <nav className="top-nav"><Link className="nav-link" to={`/company/${company.id}`}>Dashboard</Link><Link className="nav-link" to={`/company/${company.id}/inventory`}>Inventory</Link><Link className="nav-link active" to={`/company/${company.id}/contacts`}>Contacts</Link><Link className="nav-link" to={`/company/${company.id}/settings`}>Company settings</Link></nav>
      <div className="user-actions"><Link className="nav-link" to="/companies">Switch company</Link><button className="text-button" onClick={() => void signOut()}>Sign out</button></div>
    </header>
    <section className="dashboard-content">
      <div className="page-heading"><div><p className="eyebrow">CUSTOMERS & SUPPLIERS</p><h1>{company.company_name} contacts</h1><p className="muted">Keep your customer and supplier details organized in this company workspace.</p></div></div>
      <form className="panel contacts-editor" onSubmit={submit}>
        <div className="panel-heading"><div><h2>{editing ? 'Edit contact' : 'Add a contact'}</h2><p>Choose at least one role: customer, supplier, or both.</p></div>{editing && <button className="text-button" type="button" onClick={() => { setEditing(null); setMessage('') }}>Cancel edit</button>}</div>
        <div className="contacts-form">
          <label>Name<input name="name" defaultValue={initial.name} required maxLength={150} /></label>
          <label>Contact type<select name="contact_type" defaultValue={initial.contact_type}><option value="business">Business</option><option value="individual">Individual</option></select></label>
          <label>Contact person<input name="contact_person" defaultValue={initial.contact_person ?? ''} maxLength={150} /></label>
          <label>Email<input name="email" type="email" defaultValue={initial.email ?? ''} /></label>
          <label>Phone<input name="phone" type="tel" defaultValue={initial.phone ?? ''} maxLength={30} /></label>
          <label>Tax number<input name="tax_number" defaultValue={initial.tax_number ?? ''} maxLength={50} /></label>
          <label className="contact-role"><input type="checkbox" name="is_customer" defaultChecked={initial.is_customer} /> Customer</label>
          <label className="contact-role"><input type="checkbox" name="is_supplier" defaultChecked={initial.is_supplier} /> Supplier</label>
          <label>Billing address<textarea name="billing_address" rows={2} defaultValue={initial.billing_address ?? ''} /></label>
          <label>Shipping address<textarea name="shipping_address" rows={2} defaultValue={initial.shipping_address ?? ''} /></label>
          <label className="full-width">Notes<textarea name="notes" rows={2} defaultValue={initial.notes ?? ''} /></label>
        </div>
        {message && <div className={`alert ${save.isError ? 'error' : 'success'}`} role="status">{message}</div>}
        <div className="settings-actions"><button className="button primary" disabled={save.isPending}>{save.isPending ? 'Saving…' : editing ? 'Save contact' : 'Create contact'}</button></div>
      </form>

      <section className="panel recent-panel">
        <div className="panel-heading"><div><h2>Contacts</h2><p>{items.length} {items.length === 1 ? 'record' : 'records'} shown</p></div>
          <div className="contact-filters"><input aria-label="Search contacts" value={search} onChange={event => setSearch(event.target.value)} placeholder="Search by name" /><select aria-label="Filter by role" value={role} onChange={event => setRole(event.target.value as typeof role)}><option value="all">All roles</option><option value="customer">Customers</option><option value="supplier">Suppliers</option></select></div>
        </div>
        {contacts.isPending ? <div className="loading-panel">Loading contacts…</div> : contacts.isError ? <div className="alert error" role="alert">{contacts.error.message}<button className="text-button" onClick={() => void contacts.refetch()}>Try again</button></div> : items.length ? <div className="table-wrap"><table><thead><tr><th>Name</th><th>Role</th><th>Contact person</th><th>Email / phone</th><th>Status</th><th>Actions</th></tr></thead><tbody>{items.map(contact => <tr key={contact.id}><td className="transaction-name">{contact.name}</td><td>{[contact.is_customer && 'Customer', contact.is_supplier && 'Supplier'].filter(Boolean).join(' · ')}</td><td>{contact.contact_person ?? '—'}</td><td>{contact.email ?? contact.phone ?? '—'}</td><td><span className={`status-pill ${contact.is_active ? '' : 'status-inactive'}`}>{contact.is_active ? 'Active' : 'Inactive'}</span></td><td><div className="contact-actions"><button className="text-button" onClick={() => startEdit(contact)}>Edit</button><button className="text-button" onClick={() => toggleActive(contact)}>{contact.is_active ? 'Deactivate' : 'Activate'}</button></div></td></tr>)}</tbody></table></div> : <div className="empty-state"><span className="empty-symbol">＋</span><h3>No contacts found</h3><p>Create a contact or adjust the search and role filters.</p></div>}
      </section>
    </section>
  </main>
}
