import { useParams, Link, Navigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { useAuth } from '../../contexts/AuthContext'
import { companyService } from '../../services/companyService'

export default function CompanyWorkspace() {
  const { companyId } = useParams()
  const { session, user, signOut } = useAuth()
  const companies = useQuery({ queryKey: ['companies', user?.id], queryFn: () => companyService.list(session!.access_token), enabled: Boolean(session) })
  if (companies.isPending) return <div className="screen-state">Loading company…</div>
  const company = companies.data?.find(item => item.id === companyId)
  if (!company) return <Navigate to="/" replace />
  return <main className="workspace-shell"><header className="topbar"><Link className="brand" to="/">LITE<span>BOOKS</span></Link><button className="text-button" onClick={() => void signOut()}>Sign out</button></header><section className="workspace-card"><p className="eyebrow">COMPANY WORKSPACE</p><h1>{company.company_name}</h1><p className="muted">{company.company_code} · {company.currency} · Fiscal year starts {new Intl.DateTimeFormat('en', { month: 'long' }).format(new Date(2000, company.fiscal_year_start - 1, 1))}</p><p className="notice">Company onboarding is complete. Inventory, transactions, and accounting modules can be added here next.</p><Link className="button secondary" to="/">Switch company</Link></section></main>
}
