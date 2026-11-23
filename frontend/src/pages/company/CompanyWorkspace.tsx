import { useQuery } from '@tanstack/react-query'
import { useParams } from 'react-router-dom'
import { ListTree, ReceiptText, ShoppingCart, TrendingUp, Wallet } from 'lucide-react'
import { useAuth } from '../../contexts/AuthContext'
import { companyService, dashboardService } from '../../services/companyService'
import { alertClass, cardClass } from '../../components/ui/styles'

const money = (amount: number, currency: string) => new Intl.NumberFormat(undefined, { style: 'currency', currency, maximumFractionDigits: 2 }).format(amount)
const shortDate = (value: string) => new Date(`${value}T00:00:00`).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })

const statusTone: Record<string, string> = {
  posted: 'bg-emerald-50 text-emerald-700 ring-emerald-600/20',
  draft: 'bg-amber-50 text-amber-700 ring-amber-600/20',
  void: 'bg-slate-100 text-slate-600 ring-slate-500/20',
}

export default function CompanyWorkspace() {
  const { companyId } = useParams()
  const { session, user } = useAuth()
  const companies = useQuery({ queryKey: ['companies', user?.id], queryFn: () => companyService.list(session!.access_token), enabled: Boolean(session) })
  const dashboard = useQuery({
    queryKey: ['company-dashboard', companyId],
    queryFn: () => dashboardService.get(session!.access_token, companyId!),
    enabled: Boolean(session && companyId),
  })
  const company = companies.data?.find(item => item.id === companyId)
  if (!company) return null

  const d = dashboard.data
  const cards = d ? [
    { label: 'Sales', value: money(d.sales, company.currency), hint: 'Posted sales this month', icon: TrendingUp, tone: 'bg-emerald-50 text-emerald-600' },
    { label: 'Purchases', value: money(d.purchases, company.currency), hint: 'Posted purchases this month', icon: ShoppingCart, tone: 'bg-amber-50 text-amber-600' },
    { label: 'Expenses', value: money(d.expenses, company.currency), hint: 'Posted expenses this month', icon: Wallet, tone: 'bg-rose-50 text-rose-600' },
    { label: 'Active accounts', value: String(d.active_account_count), hint: 'In your chart of accounts', icon: ListTree, tone: 'bg-indigo-50 text-indigo-600' },
  ] : []

  return <>
    <div className="mb-8">
      <p className="text-xs font-semibold uppercase tracking-widest text-indigo-600">Company dashboard</p>
      <h1 className="mt-1 font-display text-3xl font-extrabold tracking-tight text-slate-900">{company.company_name}</h1>
      <p className="mt-1 text-sm text-slate-500">
        {d ? new Date(`${d.period_start}T00:00:00`).toLocaleDateString(undefined, { month: 'long', year: 'numeric' }) + ' · ' : ''}A snapshot of your business activity this month.
      </p>
    </div>

    {dashboard.isPending && <div className={`${cardClass} p-6 text-sm text-slate-500`}>Loading your dashboard…</div>}
    {dashboard.isError && <div className={`${alertClass('error')} flex items-center justify-between`}>{dashboard.error.message}<button className="font-semibold underline" onClick={() => void dashboard.refetch()}>Try again</button></div>}

    {d && <>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {cards.map(({ label, value, hint, icon: Icon, tone }) => <article key={label} className={`${cardClass} p-5`}>
          <span className={`grid size-10 place-items-center rounded-lg ${tone}`}><Icon size={20} /></span>
          <p className="mt-4 text-sm font-medium text-slate-500">{label}</p>
          <p className="mt-1 truncate font-display text-2xl font-extrabold text-slate-900">{value}</p>
          <p className="mt-1 text-xs text-slate-400">{hint}</p>
        </article>)}
      </div>

      <section className={`${cardClass} mt-6 overflow-hidden`}>
        <div className="flex items-center justify-between gap-4 border-b border-slate-100 px-6 py-5">
          <div>
            <h2 className="font-display text-base font-bold text-slate-900">Recent transactions</h2>
            <p className="text-xs text-slate-500">Latest posted activity for this month</p>
          </div>
          <span className="rounded-full bg-indigo-50 px-3 py-1 text-xs font-semibold text-indigo-700">{d.transaction_count} this month</span>
        </div>
        {d.recent_transactions.length ? <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-50 text-[11px] uppercase tracking-wider text-slate-500">
              <tr><th className="px-6 py-3 font-semibold">Transaction</th><th className="px-6 py-3 font-semibold">Type</th><th className="px-6 py-3 font-semibold">Date</th><th className="px-6 py-3 text-right font-semibold">Amount</th><th className="px-6 py-3 font-semibold">Status</th></tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {d.recent_transactions.map(tx => <tr key={tx.id} className="transition hover:bg-slate-50/70">
                <td className="whitespace-nowrap px-6 py-4 font-semibold text-slate-900">{tx.transaction_number}</td>
                <td className="whitespace-nowrap px-6 py-4 capitalize text-slate-600">{tx.transaction_type}</td>
                <td className="whitespace-nowrap px-6 py-4 text-slate-600">{shortDate(tx.transaction_date)}</td>
                <td className="whitespace-nowrap px-6 py-4 text-right font-semibold text-slate-900">{money(Number(tx.total_amount), company.currency)}</td>
                <td className="whitespace-nowrap px-6 py-4"><span className={`rounded-full px-2.5 py-1 text-xs font-semibold capitalize ring-1 ring-inset ${statusTone[tx.status] ?? statusTone.void}`}>{tx.status}</span></td>
              </tr>)}
            </tbody>
          </table>
        </div> : <div className="grid justify-items-center px-6 py-14 text-center">
          <span className="grid size-12 place-items-center rounded-xl bg-indigo-50 text-indigo-600"><ReceiptText size={24} /></span>
          <h3 className="mt-4 font-display text-base font-bold text-slate-900">No posted transactions yet</h3>
          <p className="mt-1 max-w-sm text-sm text-slate-500">Your sales, purchases, and expenses will appear here once they’re posted.</p>
        </div>}
      </section>
    </>}
  </>
}