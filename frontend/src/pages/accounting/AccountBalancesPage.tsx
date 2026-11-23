import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Navigate, useParams } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { companyService } from '../../services/companyService'
import { accountingService, type AccountBalance } from '../../services/accountingService'

const amount = (value: number | string) => Number(value || 0)
const money = (value: number | string, currency: string) => new Intl.NumberFormat(undefined, { style: 'currency', currency, maximumFractionDigits: 2 }).format(amount(value))

export default function AccountBalancesPage() {
  const { companyId } = useParams()
  const { session, user } = useAuth()
  const companies = useQuery({ queryKey: ['companies', user?.id], queryFn: () => companyService.list(session!.access_token), enabled: Boolean(session) })
  const company = useMemo(() => companies.data?.find(item => item.id === companyId), [companies.data, companyId])
  const balances = useQuery({ queryKey: ['account-balances', companyId], queryFn: () => accountingService.balances(session!.access_token, companyId!), enabled: Boolean(session && companyId && company) })

  if (!session) return <Navigate to="/login" replace />
  if (companies.isPending) return <div className="screen-state">Loading accounting…</div>
  if (companies.isError) return <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{companies.error.message}</div>
  if (!company) return <Navigate to="/companies" replace />

  const accounts = balances.data ?? []
  const totalDebits = accounts.reduce((sum, account) => sum + amount(account.debit_total), 0)
  const totalCredits = accounts.reduce((sum, account) => sum + amount(account.credit_total), 0)
  const difference = Math.abs(totalDebits - totalCredits)

  return <section className="space-y-6">
    <header className="flex flex-wrap items-end justify-between gap-4"><div><p class="text-xs font-semibold uppercase tracking-[.16em] text-indigo-600">ACCOUNTING</p><h1 className="mt-1 text-2xl font-bold text-slate-900">Account balances</h1><p className="mt-1 text-sm text-slate-500">Balances are calculated from posted journal lines for {company.company_name}.</p></div><span className={`rounded-full px-3 py-1.5 text-xs font-semibold ${difference < 0.005 ? 'bg-emerald-50 text-emerald-700' : 'bg-amber-50 text-amber-700'}`}>{difference < 0.005 ? 'Debits and credits balance' : 'Review journal totals'}</span></header>
    <div className="grid gap-4 sm:grid-cols-3"><article className="rounded-xl border border-slate-200 bg-white p-5 shadow-sm"><p className="text-sm text-slate-500">Accounts</p><p className="mt-2 text-2xl font-bold">{accounts.length}</p></article><article className="rounded-xl border border-slate-200 bg-white p-5 shadow-sm"><p className="text-sm text-slate-500">Posted debits</p><p className="mt-2 text-xl font-bold">{money(totalDebits, company.currency)}</p></article><article className="rounded-xl border border-slate-200 bg-white p-5 shadow-sm"><p className="text-sm text-slate-500">Posted credits</p><p className="mt-2 text-xl font-bold">{money(totalCredits, company.currency)}</p></article></div>
    <div className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm"><div className="flex justify-between gap-3 border-b border-slate-200 px-5 py-4"><div><h2 className="font-semibold">Chart of accounts balances</h2><p className="mt-1 text-xs text-slate-500">Draft and void journal entries are excluded.</p></div><button type="button" className="rounded-lg border border-slate-300 px-3 py-2 text-sm" onClick={() => void balances.refetch()} disabled={balances.isFetching}>{balances.isFetching ? 'Refreshing…' : 'Refresh'}</button></div>
      {balances.isPending ? <div className="p-8 text-center text-sm text-slate-500">Loading account balances…</div> : balances.isError ? <div className="m-5 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">{balances.error.message}</div> : accounts.length ? <div className="overflow-x-auto"><table className="w-full min-w-[760px] text-left text-sm"><thead className="bg-slate-50 text-xs uppercase text-slate-500"><tr><th className="px-5 py-3">Code</th><th className="px-5 py-3">Account</th><th className="px-5 py-3">Type</th><th className="px-5 py-3 text-right">Debits</th><th className="px-5 py-3 text-right">Credits</th><th className="px-5 py-3 text-right">Balance</th></tr></thead><tbody className="divide-y divide-slate-100">{accounts.map((account: AccountBalance) => <tr key={account.account_id}><td className="px-5 py-3 font-mono text-xs text-slate-500">{account.account_code}</td><td className="px-5 py-3 font-medium">{account.account_name}</td><td className="px-5 py-3 capitalize text-slate-600">{account.account_type}</td><td className="px-5 py-3 text-right tabular-nums">{money(account.debit_total, company.currency)}</td><td className="px-5 py-3 text-right tabular-nums">{money(account.credit_total, company.currency)}</td><td className="px-5 py-3 text-right font-semibold tabular-nums">{money(account.balance, company.currency)} <span className="text-xs font-normal text-slate-400">{account.normal_balance}</span></td></tr>)}</tbody></table></div> : <div className="p-8 text-center text-sm text-slate-500">No accounts are configured for this company yet.</div>}
    </div>
  </section>
}
