import { useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { companyService, type CompanyInput } from '../../services/companyService'
import { Brand } from './Register'

const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']

export default function CompanySetup() {
  const { session, signOut } = useAuth()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [error, setError] = useState('')
  const mutation = useMutation({
    mutationFn: (input: CompanyInput) => companyService.create(session!.access_token, input),
    onSuccess: async company => {
      await queryClient.invalidateQueries({ queryKey: ['companies'] })
      navigate(`/company/${company.id}`, { replace: true })
    },
    onError: (reason: Error) => setError(reason.message),
  })

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError('')
    const form = new FormData(event.currentTarget)
    mutation.mutate({
      company_name: String(form.get('company_name')).trim(),
      company_code: String(form.get('company_code')).trim().toUpperCase(),
      address: String(form.get('address')).trim() || undefined,
      contact_number: String(form.get('contact_number')).trim() || undefined,
      email: String(form.get('email')).trim() || undefined,
      currency: String(form.get('currency')),
      fiscal_year_start: Number(form.get('fiscal_year_start')),
    })
  }

  return <main className="onboarding-shell">
    <header className="topbar"><Brand /><button className="text-button" onClick={() => void signOut()}>Sign out</button></header>
    <section className="onboarding-card">
      <div className="step-badge">STEP 1 OF 1 · COMPANY SETUP</div>
      <h1>Set up your company</h1>
      <p className="muted">Your account is ready. Add a company to continue. You can return and finish this later if needed.</p>
      {error && <div className="alert error" role="alert">{error}</div>}
      <form className="form-stack two-column" onSubmit={submit}>
        <label className="span-two">Company name<input name="company_name" placeholder="ABC Computer Trading" required maxLength={150} /></label>
        <label>Company code<input name="company_code" placeholder="ABC001" required maxLength={50} /></label>
        <label>Currency<select name="currency" defaultValue="PHP"><option value="PHP">PHP — Philippine Peso</option><option value="USD">USD — US Dollar</option><option value="EUR">EUR — Euro</option><option value="GBP">GBP — Pound Sterling</option><option value="CAD">CAD — Canadian Dollar</option><option value="AUD">AUD — Australian Dollar</option><option value="SGD">SGD — Singapore Dollar</option><option value="JPY">JPY — Japanese Yen</option></select></label>
        <label>Business address<input name="address" placeholder="Street, city, region" maxLength={10000} /></label>
        <label>Contact number<input name="contact_number" type="tel" placeholder="+63 …" maxLength={30} /></label>
        <label className="span-two">Business email<input name="email" type="email" placeholder="hello@yourbusiness.com" /></label>
        <label className="span-two">Fiscal year starts<select name="fiscal_year_start" defaultValue="1">{months.map((month, index) => <option value={index + 1} key={month}>{month}</option>)}</select></label>
        <p className="helper span-two">You’ll be set as the owner of this company. Company codes must be unique among your companies.</p>
        <button className="button primary span-two" disabled={mutation.isPending}>{mutation.isPending ? 'Creating company…' : 'Create company and continue'}</button>
      </form>
    </section>
  </main>
}
