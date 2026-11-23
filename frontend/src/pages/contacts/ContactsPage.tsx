import { useMemo, useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Navigate, useParams } from 'react-router-dom'
import { Plus } from 'lucide-react'
import { useAuth } from '../../contexts/AuthContext'
import { companyService } from '../../services/companyService'
import { contactService, type Contact, type ContactInput } from '../../services/contactService'
import { alertClass, btnPrimary, cardClass, inputClass, labelClass } from '../../components/ui/styles'

const emptyForm = (): ContactInput => ({ name: '', contact_type: 'business', is_customer: true, is_supplier: false })
const linkBtn = 'text-sm font-semibold text-indigo-600 transition hover:text-indigo-800'

type Notice = { kind: 'error' | 'success'; text: string } | null

export default function ContactsPage() {
  const { companyId } = useParams()
  const { session, user } = useAuth()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')
  const [role, setRole] = useState<'all' | 'customer' | 'supplier'>('all')
  const [editing, setEditing] = useState<Contact | null>(null)
  const [notice, setNotice] = useState<Notice>(null)
  const [formVersion, setFormVersion] = useState(0)

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
      setNotice({ kind: 'success', text: editing ? 'Contact updated.' : 'Contact created.' })
      setEditing(null)
      setFormVersion(v => v + 1) // remounts the form so fields reset
      await queryClient.invalidateQueries({ queryKey: ['contacts', companyId] })
    },
    onError: (error: Error) => setNotice({ kind: 'error', text: error.message }),
  })

  if (!session) return <Navigate to="/login" replace />
  if (!company) return null // AppShell already redirects when the company is missing

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setNotice(null)
    const form = new FormData(event.currentTarget)
    const isCustomer = form.get('is_customer') === 'yes'
    const isSupplier = form.get('is_supplier') === 'yes'

    if (!isCustomer && !isSupplier) {
      setNotice({ kind: 'error', text: 'Choose at least one role: set Customer or Supplier to Yes.' })
      return
    }
    const input: ContactInput = {
      name: String(form.get('name') ?? '').trim(),
      contact_person: String(form.get('contact_person') ?? '').trim() || null,
      contact_type: String(form.get('contact_type')) as ContactInput['contact_type'],
      is_customer: isCustomer,
      is_supplier: isSupplier,
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
    setNotice(null)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  function toggleActive(contact: Contact) {
    contactService.update(session!.access_token, companyId!, contact.id, { is_active: !contact.is_active })
      .then(() => queryClient.invalidateQueries({ queryKey: ['contacts', companyId] }))
      .catch((error: Error) => setNotice({ kind: 'error', text: error.message }))
  }

  const items = contacts.data ?? []
  const initial = editing ?? emptyForm()

  return <>
    <div className="mb-8">
      <p className="text-xs font-semibold uppercase tracking-widest text-indigo-600">Customers &amp; suppliers</p>
      <h1 className="mt-1 font-display text-3xl font-extrabold tracking-tight text-slate-900">{company.company_name} contacts</h1>
      <p className="mt-1 text-sm text-slate-500">Keep your customer and supplier details organized in this company workspace.</p>
    </div>

    <form key={editing?.id ?? `new-${formVersion}`} className={`${cardClass} mb-6 p-5 sm:p-6`} onSubmit={submit}>
      <div className="mb-5 flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="font-display text-base font-bold text-slate-900">{editing ? 'Edit contact' : 'Add a contact'}</h2>
          <p className="mt-1 text-sm text-slate-500">Choose at least one role: customer, supplier, or both.</p>
        </div>
        {editing && <button type="button" className={linkBtn} onClick={() => { setEditing(null); setNotice(null) }}>Cancel edit</button>}
      </div>

      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <label className={labelClass}>Name<input className={inputClass} name="name" defaultValue={initial.name} required maxLength={150} /></label>
        <label className={labelClass}>Contact type
          <select className={inputClass} name="contact_type" defaultValue={initial.contact_type}>
            <option value="business">Business</option>
            <option value="individual">Individual</option>
          </select>
        </label>
        <label className={labelClass}>Contact person<input className={inputClass} name="contact_person" defaultValue={initial.contact_person ?? ''} maxLength={150} /></label>
        <label className={labelClass}>Email<input className={inputClass} name="email" type="email" defaultValue={initial.email ?? ''} /></label>
        <label className={labelClass}>Phone<input className={inputClass} name="phone" type="tel" defaultValue={initial.phone ?? ''} maxLength={30} /></label>
        <label className={labelClass}>Tax number<input className={inputClass} name="tax_number" defaultValue={initial.tax_number ?? ''} maxLength={50} /></label>
        <label className={labelClass}>Customer
          <select className={inputClass} name="is_customer" defaultValue={initial.is_customer ? 'yes' : 'no'}>
            <option value="yes">Yes</option>
            <option value="no">No</option>
          </select>
        </label>
        <label className={labelClass}>Supplier
          <select className={inputClass} name="is_supplier" defaultValue={initial.is_supplier ? 'yes' : 'no'}>
            <option value="yes">Yes</option>
            <option value="no">No</option>
          </select>
        </label>
        <div className="hidden lg:block" aria-hidden="true" />
        <label className={`${labelClass} sm:col-span-2 lg:col-span-1`}>Billing address<textarea className={inputClass} name="billing_address" rows={3} defaultValue={initial.billing_address ?? ''} /></label>
        <label className={`${labelClass} sm:col-span-2 lg:col-span-1`}>Shipping address<textarea className={inputClass} name="shipping_address" rows={3} defaultValue={initial.shipping_address ?? ''} /></label>
        <label className={`${labelClass} col-span-full`}>Notes<textarea className={inputClass} name="notes" rows={2} defaultValue={initial.notes ?? ''} /></label>
      </div>

      {notice && <div className={`${alertClass(notice.kind)} mt-5`} role="status">{notice.text}</div>}
      <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:justify-end">
        <button className={`${btnPrimary} w-full sm:w-auto`} disabled={save.isPending}>{save.isPending ? 'Saving…' : editing ? 'Save contact' : 'Create contact'}</button>
      </div>
    </form>

    <section className={`${cardClass} overflow-hidden`}>
      <div className="flex flex-col gap-4 border-b border-slate-100 px-5 py-5 sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <div>
          <h2 className="font-display text-base font-bold text-slate-900">Contacts</h2>
          <p className="text-xs text-slate-500">{items.length} {items.length === 1 ? 'record' : 'records'} shown</p>
        </div>
        <div className="flex flex-col gap-3 sm:flex-row">
          <input className={`${inputClass} sm:w-56`} aria-label="Search contacts" value={search} onChange={e => setSearch(e.target.value)} placeholder="Search by name" />
          <select className={`${inputClass} sm:w-40`} aria-label="Filter by role" value={role} onChange={e => setRole(e.target.value as typeof role)}>
            <option value="all">All roles</option>
            <option value="customer">Customers</option>
            <option value="supplier">Suppliers</option>
          </select>
        </div>
      </div>

      {contacts.isPending ? <div className="p-6 text-sm text-slate-500">Loading contacts…</div>
        : contacts.isError ? <div className={`${alertClass('error')} m-5 flex items-center justify-between`} role="alert">{contacts.error.message}<button className="font-semibold underline" onClick={() => void contacts.refetch()}>Try again</button></div>
        : items.length ? <div className="overflow-x-auto">
          <table className="w-full min-w-[720px] text-left text-sm">
            <thead className="bg-slate-50 text-[11px] uppercase tracking-wider text-slate-500">
              <tr><th className="px-6 py-3 font-semibold">Name</th><th className="px-6 py-3 font-semibold">Role</th><th className="px-6 py-3 font-semibold">Contact person</th><th className="px-6 py-3 font-semibold">Email / phone</th><th className="px-6 py-3 font-semibold">Status</th><th className="px-6 py-3 text-right font-semibold">Actions</th></tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {items.map(contact => <tr key={contact.id} className="transition hover:bg-slate-50/70">
                <td className="whitespace-nowrap px-6 py-4 font-semibold text-slate-900">{contact.name}</td>
                <td className="whitespace-nowrap px-6 py-4 text-slate-600">{[contact.is_customer && 'Customer', contact.is_supplier && 'Supplier'].filter(Boolean).join(' · ')}</td>
                <td className="whitespace-nowrap px-6 py-4 text-slate-600">{contact.contact_person ?? '—'}</td>
                <td className="whitespace-nowrap px-6 py-4 text-slate-600">{contact.email ?? contact.phone ?? '—'}</td>
                <td className="whitespace-nowrap px-6 py-4">
                  <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset ${contact.is_active ? 'bg-emerald-50 text-emerald-700 ring-emerald-600/20' : 'bg-slate-100 text-slate-600 ring-slate-500/20'}`}>{contact.is_active ? 'Active' : 'Inactive'}</span>
                </td>
                <td className="whitespace-nowrap px-6 py-4"><div className="flex justify-end gap-4">
                  <button className={linkBtn} onClick={() => startEdit(contact)}>Edit</button>
                  <button className={linkBtn} onClick={() => toggleActive(contact)}>{contact.is_active ? 'Deactivate' : 'Activate'}</button>
                </div></td>
              </tr>)}
            </tbody>
          </table>
        </div>
        : <div className="grid justify-items-center px-6 py-14 text-center">
          <span className="grid size-12 place-items-center rounded-xl bg-indigo-50 text-indigo-600"><Plus size={24} /></span>
          <h3 className="mt-4 font-display text-base font-bold text-slate-900">No contacts found</h3>
          <p className="mt-1 max-w-sm text-sm text-slate-500">Create a contact or adjust the search and role filters.</p>
        </div>}
    </section>
  </>
}