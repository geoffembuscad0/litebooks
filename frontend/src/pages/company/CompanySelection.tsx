import { useQuery } from '@tanstack/react-query'
import { Link, Navigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { companyService } from '../../services/companyService'

export default function Home() {
  const { session, user, signOut } = useAuth()
  const companies = useQuery({
    queryKey: ['companies', user?.id],
    queryFn: () => companyService.list(session!.access_token),
    enabled: Boolean(session),
  })

  if (!session) return <Navigate to="/login" replace />
  if (companies.isPending) return <div className="screen-state">Loading your companies…</div>
  if (companies.isError) return <main className="center-shell"><div className="alert error">{companies.error.message}<button className="text-button" onClick={() => void companies.refetch()}>Try again</button></div></main>
  if (!companies.data?.length) return <Navigate to="/onboarding" replace />

  return <main className="company-shell">
    <header className="topbar"><Link className="brand" to="/">LITE<span>BOOKS</span></Link><div className="user-actions"><span>{user?.email}</span><button className="text-button" onClick={() => void signOut()}>Sign out</button></div></header>
    <section className="company-content">
      <p className="eyebrow">YOUR WORKSPACES</p><h1>Select your company</h1>
      <p className="muted">Choose which company you want to manage.</p>
      <div className="company-grid">{companies.data.map(company => <Link className="company-card" to={`/company/${company.id}`} key={company.id}>
        <div className="company-icon">{company.company_name.slice(0, 1).toUpperCase()}</div><div className="company-info"><h2>{company.company_name}</h2><p>{company.company_code}</p></div><span className="arrow">→</span>
      </Link>)}</div>
      <Link to="/onboarding" className="button secondary add-company">＋ Add company</Link>
    </section>
  </main>
}
