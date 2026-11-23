import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Navigate, useParams } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { companyService } from '../../services/companyService'
import { accountingService, type ProfitAndLossReport, type TrialBalanceReport } from '../../services/accountingService'

const today = new Date().toISOString().slice(0, 10)
const monthStart = `${today.slice(0, 8)}01`
const value = (amount: number | string | undefined) => Number(amount ?? 0)
const money = (amount: number | string | undefined, currency: string) => new Intl.NumberFormat(undefined, { style: 'currency', currency, maximumFractionDigits: 2 }).format(value(amount))

export default function ReportsPage() {
  const { companyId } = useParams()
  const { session, user } = useAuth()
  const [asOf, setAsOf] = useState(today)
  const [startDate, setStartDate] = useState(monthStart)
  const [endDate, setEndDate] = useState(today)
  const companies = useQuery({ queryKey: ['companies', user?.id], queryFn: () => companyService.list(session!.access_token), enabled: Boolean(session) })
  const company = useMemo(() => companies.data?.find(item => item.id === companyId), [companies.data, companyId])
  const trial = useQuery({ queryKey: ['trial-balance', companyId, asOf], queryFn: () => accountingService.trialBalance(session!.access_token, companyId!, asOf), enabled: Boolean(session && company) })
  const pnl = useQuery({ queryKey: ['profit-and-loss', companyId, startDate, endDate], queryFn: () => accountingService.profitAndLoss(session!.access_token, companyId!, startDate, endDate), enabled: Boolean(session && company && startDate && endDate && startDate <= endDate) })

  if (!session) return <Navigate to="/login" replace />
  if (companies.isPending) return <div className="screen-state">Loading reports…</div>
  if (companies.isError) return <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700" role="alert">{companies.error.message}</div>
  if (!company) return <Navigate to="/companies" replace />

  const trialData: TrialBalanceReport | undefined = trial.data
  const pnlData: ProfitAndLossReport | undefined = pnl.data
  const totalsAgree = trialData && Math.abs(value(trialData.totals.debit_balance) - value(trialData.totals.credit_balance)) < 0.005

  return <section className="space-y-8">
    <header><p className="text-xs font-semibold uppercase tracking-[.16em] text-indigo-600">FINANCIAL REPORTS</p><h1 className="mt-1 text-2xl font-bold text-slate-900">Reports</h1><p className="mt-1 text-sm text-slate-500">Generated from posted journal entries for {company.company_name}.</p></header>

    <section className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
      <div className="flex flex-wrap items-end justify-between gap-4 border-b border-slate-200 px-5 py-4">
        <div><h2 className="font-semibold text-slate-900">Trial Balance</h2><p className="mt-1 text-xs text-slate-500">Ending debit and credit balances as of the selected date.</p></div>
        <label className="grid gap-1 text-xs font-medium text-slate-600">As of<input className="rounded-lg border border-slate-300 px-3 py-2 text-sm" type="date" value={asOf} onChange={event => setAsOf(event.target.value)} /></label>
      </div>
      {trial.isPending ? <div className="p-6 text-sm text-slate-500">Loading Trial Balance…</div> : trial.isError ? <div className="m-5 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700" role="alert">{trial.error.message}</div> : <>
        <div className={`mx-5 mt-5 rounded-lg px-4 py-3 text-sm font-medium ${totalsAgree ? 'bg-emerald-50 text-emerald-800' : 'bg-amber-50 text-amber-800'}`} role="status">{totalsAgree ? 'Trial Balance reconciles: total debit balances equal total credit balances.' : 'Trial Balance is out of balance. Review posted journal entries.'}</div>
        <div className="overflow-x-auto p-5"><table className="w-full min-w-[680px] text-left text-sm"><thead className="bg-slate-50 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Code</th><th className="px-4 py-3">Account</th><th className="px-4 py-3">Type</th><th className="px-4 py-3 text-right">Debit balance</th><th className="px-4 py-3 text-right">Credit balance</th></tr></thead><tbody className="divide-y divide-slate-100">{(trialData?.rows ?? []).map(row => <tr key={row.account_id}><td className="px-4 py-3 font-mono text-xs text-slate-500">{row.account_code}</td><td className="px-4 py-3 font-medium text-slate-900">{row.account_name}</td><td className="px-4 py-3 capitalize text-slate-600">{row.account_type}</td><td className="px-4 py-3 text-right tabular-nums">{value(row.debit_balance) ? money(row.debit_balance, company.currency) : '—'}</td><td className="px-4 py-3 text-right tabular-nums">{value(row.credit_balance) ? money(row.credit_balance, company.currency) : '—'}</td></tr>)}</tbody><tfoot className="border-t-2 border-slate-200 bg-slate-50 font-semibold"><tr><td className="px-4 py-3" colSpan={3}>Totals</td><td className="px-4 py-3 text-right tabular-nums">{money(trialData?.totals.debit_balance, company.currency)}</td><td className="px-4 py-3 text-right tabular-nums">{money(trialData?.totals.credit_balance, company.currency)}</td></tr></tfoot></table></div>
      </>}
    </section>

    <section className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
      <div className="flex flex-wrap items-end justify-between gap-4 border-b border-slate-200 px-5 py-4"><div><h2 className="font-semibold text-slate-900">Profit &amp; Loss</h2><p className="mt-1 text-xs text-slate-500">Revenue and expenses from posted entries during the selected period.</p></div><div className="flex flex-wrap gap-3"><label className="grid gap-1 text-xs font-medium text-slate-600">From<input className="rounded-lg border border-slate-300 px-3 py-2 text-sm" type="date" value={startDate} max={endDate} onChange={event => setStartDate(event.target.value)} /></label><label className="grid gap-1 text-xs font-medium text-slate-600">To<input className="rounded-lg border border-slate-300 px-3 py-2 text-sm" type="date" value={endDate} min={startDate} onChange={event => setEndDate(event.target.value)} /></label></div></div>
      {startDate > endDate ? <div className="p-5 text-sm text-red-700" role="alert">Start date must be on or before end date.</div> : pnl.isPending ? <div className="p-6 text-sm text-slate-500">Loading Profit &amp; Loss…</div> : pnl.isError ? <div className="m-5 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700" role="alert">{pnl.error.message}</div> : <div className="p-5">
        <div className="mb-5 grid gap-4 sm:grid-cols-3"><article className="rounded-lg bg-slate-50 p-4"><p className="text-sm text-slate-500">Revenue</p><p className="mt-1 text-xl font-bold">{money(pnlData?.revenue, company.currency)}</p></article><article className="rounded-lg bg-slate-50 p-4"><p className="text-sm text-slate-500">Expenses</p><p className="mt-1 text-xl font-bold">{money(pnlData?.expenses, company.currency)}</p></article><article className="rounded-lg bg-indigo-50 p-4"><p className="text-sm text-indigo-700">Net income</p><p className="mt-1 text-xl font-bold text-indigo-950">{money(pnlData?.net_income, company.currency)}</p></article></div>
        <div className="grid gap-6 md:grid-cols-2"><div><h3 className="mb-2 font-semibold text-slate-900">Revenue accounts</h3>{(pnlData?.revenues ?? []).length ? <div className="divide-y divide-slate-100 rounded-lg border border-slate-200">{pnlData!.revenues.map(account => <div key={account.account_id} className="flex justify-between gap-3 px-4 py-3 text-sm"><span><span className="mr-2 font-mono text-xs text-slate-400">{account.account_code}</span>{account.account_name}</span><strong>{money(account.amount, company.currency)}</strong></div>)}</div> : <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">No posted revenue in this period.</p>}</div><div><h3 className="mb-2 font-semibold text-slate-900">Expense accounts</h3>{(pnlData?.expense_accounts ?? []).length ? <div className="divide-y divide-slate-100 rounded-lg border border-slate-200">{pnlData!.expense_accounts.map(account => <div key={account.account_id} className="flex justify-between gap-3 px-4 py-3 text-sm"><span><span className="mr-2 font-mono text-xs text-slate-400">{account.account_code}</span>{account.account_name}</span><strong>{money(account.amount, company.currency)}</strong></div>)}</div> : <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">No posted expenses in this period.</p>}</div></div>
      </div>}
    </section>
  </section>
}
