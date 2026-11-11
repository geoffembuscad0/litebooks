import { useQuery } from '@tanstack/react-query'
import { Link, Navigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { companyService } from '../../services/companyService'

export default function CompanySelection() {
  const { session, user, signOut } = useAuth()
  const companies = useQuery({
    queryKey: ['companies', user?.id],
    queryFn: () => companyService.list(session!.access_token),
    enabled: Boolean(session),
  })

  if (!session) return <Navigate to="/login" replace />
  if (companies.isPending) return <div className="screen-state">Loading your companies…</div>

  return <main className="company-shell">
    <header className="topbar">
      <Link className="brand" to="/companies">LITE<span>BOOKS</span></Link>
      <div className="user-actions"><Link className="nav-link" to="/account">My profile</Link><span>{user?.email}</span><button className="text-button" onClick={() => void signOut()}>Sign out</button></div>
    </header>
    <section className="company-content">
      <p className="eyebrow">YOUR WORKSPACES</p>
      <h1>Select a company</h1>
      <p className="muted">Choose a company to open its workspace. Your access is verified for each company by the server.</p>
      {companies.isError && <div className="alert error" role="alert">{companies.error.message} <button className="text-button" onClick={() => void companies.refetch()}>Try again</button></div>}
      {companies.data?.length ? <div className="company-grid">{companies.data.map(company => <Link className="company-card" to={`/company/${company.id}`} key={company.id}>
        <div className="company-icon">{company.company_name.slice(0, 1).toUpperCase()}</div>
        <div className="company-info"><h2>{company.company_name}</h2><p>{company.company_code} · {company.currency}</p></div>
        <span className="arrow" aria-hidden="true">→</span>
      </Link>)}</div> : !companies.isError && <div className="panel empty-state"><span className="empty-symbol">＋</span><h3>No companies yet</h3><p>Create your first company workspace to get started.</p></div>}
      <Link to="/onboarding" className="button secondary add-company">＋ Create company</Link>
    </section>
  </main>
}
