import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useParams } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { companyService, type CompanyInput } from '../../services/companyService'
import { alertClass, btnPrimary, btnSecondary, cardClass, hintClass, inputClass, labelClass } from '../../components/ui/styles'

const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
const currencies = [['PHP', 'Philippine Peso'], ['USD', 'US Dollar'], ['EUR', 'Euro'], ['GBP', 'Pound Sterling'], ['SGD', 'Singapore Dollar'], ['AUD', 'Australian Dollar'], ['CAD', 'Canadian Dollar'], ['JPY', 'Japanese Yen']]

export default function CompanySettings() {
  const { companyId } = useParams()
  const { session, user } = useAuth()
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

  if (!company) return null

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

  return <div className="max-w-3xl">
    <p className="text-xs font-semibold uppercase tracking-widest text-indigo-600">Workspace preferences</p>
    <h1 className="mt-1 font-display text-3xl font-extrabold tracking-tight text-slate-900">Company settings</h1>
    <p className="mb-8 mt-1 text-sm text-slate-500">Update your company details and accounting preferences.</p>

    <form className={`${cardClass} p-6 sm:p-8`} onSubmit={submit}>
      <div className="border-b border-slate-100 pb-5">
        <h2 className="font-display text-base font-bold text-slate-900">Business details</h2>
        <p className="text-xs text-slate-500">These details are used across your company workspace.</p>
      </div>
      <div className="mt-6 grid gap-5 sm:grid-cols-2">
        <label className={`${labelClass} sm:col-span-2`}>Company name<input className={inputClass} name="company_name" defaultValue={company.company_name} required maxLength={150} /></label>
        <label className={labelClass}>Company code<input className={inputClass} value={company.company_code} readOnly /><small className={hintClass}>Company codes cannot be changed after setup.</small></label>
        <label className={labelClass}>Currency<select className={inputClass} name="currency" defaultValue={company.currency}>{currencies.map(([code, name]) => <option key={code} value={code}>{code} — {name}</option>)}</select></label>
        <label className={labelClass}>Business address<input className={inputClass} name="address" defaultValue={company.address ?? ''} maxLength={10000} /></label>
        <label className={labelClass}>Contact number<input className={inputClass} name="contact_number" type="tel" defaultValue={company.contact_number ?? ''} maxLength={30} /></label>
        <label className={labelClass}>Business email<input className={inputClass} name="email" type="email" defaultValue={company.email ?? ''} /></label>
        <label className={labelClass}>Fiscal year starts<select className={inputClass} name="fiscal_year_start" defaultValue={company.fiscal_year_start}>{months.map((month, index) => <option value={index + 1} key={month}>{month}</option>)}</select></label>
        <label className={`${labelClass} sm:col-span-2`}>Timezone<input className={inputClass} name="timezone" defaultValue={company.timezone} required maxLength={100} placeholder="Asia/Manila" /><small className={hintClass}>Use an IANA timezone, for example Asia/Manila or America/New_York.</small></label>
      </div>
      {message && <div className={`${alertClass(update.isError ? 'error' : 'success')} mt-6`} role="status">{message}</div>}
      <div className="mt-6 flex justify-end gap-3 border-t border-slate-100 pt-5">
        <Link className={btnSecondary} to={`/company/${company.id}`}>Cancel</Link>
        <button className={btnPrimary} disabled={update.isPending}>{update.isPending ? 'Saving…' : 'Save changes'}</button>
      </div>
    </form>
  </div>
}