import { useQuery } from '@tanstack/react-query'
import { Link, Navigate, useParams } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { companyService, dashboardService } from '../../services/companyService'

const money = (amount: number, currency: string) => new Intl.NumberFormat(undefined, { style: 'currency', currency, maximumFractionDigits: 2 }).format(amount)
const shortDate = (value: string) => new Date(`${value}T00:00:00`).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })

export default function CompanyWorkspace() {
  const { companyId } = useParams()
  const { session, user, signOut } = useAuth()
  const companies = useQuery({ queryKey: ['companies', user?.id], queryFn: () => companyService.list(session!.access_token), enabled: Boolean(session) })
  const dashboard = useQuery({
    queryKey: ['company-dashboard', companyId],
    queryFn: () => dashboardService.get(session!.access_token, companyId!),
    enabled: Boolean(session && companyId),
  })

  if (companies.isPending) return <div className="screen-state">Loading company…</div>
  const company = companies.data?.find(item => item.id === companyId)
  if (!company) return <Navigate to="/companies" replace />

  return <main className="app-shell">
    <header className="topbar">
      <Link className="brand" to="/">LITE<span>BOOKS</span></Link>
      <nav className="top-nav"><Link className="nav-link active" to={`/company/${company.id}`}>Dashboard</Link><Link className="nav-link" to={`/company/${company.id}/settings`}>Company settings</Link></nav>
      <div className="user-actions"><Link className="nav-link" to="/account">My profile</Link><Link className="text-button" to="/companies">Switch company</Link><button className="text-button" onClick={() => void signOut()}>Sign out</button></div>
    </header>
    <section className="dashboard-content">
      <div className="page-heading"><div><p className="eyebrow">COMPANY DASHBOARD</p><h1>{company.company_name}</h1><p className="muted">A snapshot of your business activity for this month.</p></div><Link className="button secondary" to={`/company/${company.id}/settings`}>Manage company</Link></div>
      {dashboard.isPending && <div className="panel loading-panel">Loading your dashboard…</div>}
      {dashboard.isError && <div className="alert error" role="alert">{dashboard.error.message}<button className="text-button" onClick={() => void dashboard.refetch()}>Try again</button></div>}
      {dashboard.data && <>
        <p className="period-label">{new Date(`${dashboard.data.period_start}T00:00:00`).toLocaleDateString(undefined, { month: 'long', year: 'numeric' })}</p>
        <div className="metric-grid">
          <article className="metric-card"><span className="metric-icon green">↗</span><p>Sales</p><strong>{money(dashboard.data.sales, company.currency)}</strong><small>Posted sales this month</small></article>
          <article className="metric-card"><span className="metric-icon amber">↙</span><p>Purchases</p><strong>{money(dashboard.data.purchases, company.currency)}</strong><small>Posted purchases this month</small></article>
          <article className="metric-card"><span className="metric-icon rose">−</span><p>Expenses</p><strong>{money(dashboard.data.expenses, company.currency)}</strong><small>Posted expenses this month</small></article>
          <article className="metric-card"><span className="metric-icon blue">▦</span><p>Active accounts</p><strong>{dashboard.data.active_account_count}</strong><small>In your chart of accounts</small></article>
        </div>
        <section className="panel recent-panel"><div className="panel-heading"><div><h2>Recent transactions</h2><p>Latest posted activity for this month</p></div><span className="count-pill">{dashboard.data.transaction_count} this month</span></div>
          {dashboard.data.recent_transactions.length ? <div className="table-wrap"><table><thead><tr><th>Transaction</th><th>Type</th><th>Date</th><th className="align-right">Amount</th><th>Status</th></tr></thead><tbody>{dashboard.data.recent_transactions.map(tx => <tr key={tx.id}><td className="transaction-name">{tx.transaction_number}</td><td className="capitalize">{tx.transaction_type}</td><td>{shortDate(tx.transaction_date)}</td><td className="align-right amount">{money(Number(tx.total_amount), company.currency)}</td><td><span className="status-pill">{tx.status}</span></td></tr>)}</tbody></table></div> : <div className="empty-state"><span className="empty-symbol">↗</span><h3>No posted transactions yet</h3><p>Your sales, purchases, and expenses will appear here once they’re posted.</p></div>}
        </section>
      </>}
    </section>
  </main>
}
