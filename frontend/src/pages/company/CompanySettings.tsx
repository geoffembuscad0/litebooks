import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, Navigate, useParams } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { companyService, type CompanyInput } from '../../services/companyService'

const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']

export default function CompanySettings() {
  const { companyId } = useParams()
  const { session, user, signOut } = useAuth()
  const queryClient = useQueryClient()
  const companies = useQuery({ queryKey: ['companies', user?.id], queryFn: () => companyService.list(session!.access_token), enabled: Boolean(session) })
  const company = companies.data?.find(item => item.id === companyId)
  const [message, setMessage] = useState('')
  const update = useMutation({
    mutationFn: (input: Partial<CompanyInput> & { timezone: string }) => companyService.update(session!.access_token, companyId!, input),
    onSuccess: async () => {
      setMessage('Company settings saved.')
      await queryClient.invalidateQueries({ queryKey: ['companies', user?.id] })
      await queryClient.invalidateQueries({ queryKey: ['company-dashboard', companyId] })
    },
    onError: (error: Error) => setMessage(error.message),
  })

  if (companies.isPending) return <div className="screen-state">Loading company settings…</div>
  if (!company) return <Navigate to="/companies" replace />

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setMessage('')
    const form = new FormData(event.currentTarget)
    update.mutate({
      company_name: String(form.get('company_name')).trim(),
      address: String(form.get('address')).trim() || undefined,
      contact_number: String(form.get('contact_number')).trim() || undefined,
      email: String(form.get('email')).trim() || undefined,
      currency: String(form.get('currency')),
      fiscal_year_start: Number(form.get('fiscal_year_start')),
      timezone: String(form.get('timezone')).trim(),
    })
  }

  return <main className="app-shell">
    <header className="topbar"><Link className="brand" to="/">LITE<span>BOOKS</span></Link><nav className="top-nav"><Link className="nav-link" to={`/company/${company.id}`}>Dashboard</Link><Link className="nav-link active" to={`/company/${company.id}/settings`}>Company settings</Link></nav><div className="user-actions"><Link className="nav-link" to="/account">My profile</Link><button className="text-button" onClick={() => void signOut()}>Sign out</button></div></header>
    <section className="settings-content">
      <Link className="back-link" to={`/company/${company.id}`}>← Back to dashboard</Link>
      <div className="page-heading settings-heading"><div><p className="eyebrow">WORKSPACE PREFERENCES</p><h1>Company settings</h1><p className="muted">Update your company details and accounting preferences.</p></div></div>
      <form className="panel settings-panel" onSubmit={submit}>
        <div className="settings-section-heading"><h2>Business details</h2><p>These details are used across your company workspace.</p></div>
        <div className="form-stack two-column settings-form">
          <label className="span-two">Company name<input name="company_name" defaultValue={company.company_name} required maxLength={150} /></label>
          <label>Company code<input value={company.company_code} readOnly /><small>Company codes cannot be changed after setup.</small></label>
          <label>Currency<select name="currency" defaultValue={company.currency}><option value="PHP">PHP — Philippine Peso</option><option value="USD">USD — US Dollar</option><option value="EUR">EUR — Euro</option><option value="GBP">GBP — Pound Sterling</option><option value="SGD">SGD — Singapore Dollar</option><option value="AUD">AUD — Australian Dollar</option><option value="CAD">CAD — Canadian Dollar</option><option value="JPY">JPY — Japanese Yen</option></select></label>
          <label>Business address<input name="address" defaultValue={company.address ?? ''} maxLength={10000} /></label>
          <label>Contact number<input name="contact_number" type="tel" defaultValue={company.contact_number ?? ''} maxLength={30} /></label>
          <label>Business email<input name="email" type="email" defaultValue={company.email ?? ''} /></label>
          <label>Fiscal year starts<select name="fiscal_year_start" defaultValue={company.fiscal_year_start}>{months.map((month, index) => <option value={index + 1} key={month}>{month}</option>)}</select></label>
          <label className="span-two">Timezone<input name="timezone" defaultValue={company.timezone} required maxLength={100} placeholder="Asia/Manila" /><small>Use an IANA timezone, for example Asia/Manila or America/New_York.</small></label>
        </div>
        {message && <div className={`alert ${update.isError ? 'error' : 'success'}`} role="status">{message}</div>}
        <div className="settings-actions"><Link className="button secondary" to={`/company/${company.id}`}>Cancel</Link><button className="button primary" disabled={update.isPending}>{update.isPending ? 'Saving…' : 'Save changes'}</button></div>
      </form>
    </section>
  </main>
}
