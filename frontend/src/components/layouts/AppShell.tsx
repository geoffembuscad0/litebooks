import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link, NavLink, Navigate, Outlet, useParams } from 'react-router-dom'
import { BarChart3, BookOpen, Building2, ChevronsUpDown, LayoutDashboard, LogOut, Menu, Package, Receipt, Settings, UserCircle, Users, X, type LucideIcon } from 'lucide-react'
import { useAuth } from '../../contexts/AuthContext'
import { companyService } from '../../services/companyService'

type NavItem = { label: string; icon: LucideIcon; to?: string; end?: boolean }

const linkClass = ({ isActive }: { isActive: boolean }) =>
  `flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition ${
    isActive ? 'bg-indigo-500/20 text-white ring-1 ring-inset ring-indigo-400/30' : 'text-indigo-200 hover:bg-white/5 hover:text-white'
  }`

export default function AppShell() {
  const { companyId } = useParams()
  const { session, user, signOut } = useAuth()
  const [open, setOpen] = useState(false)
  const companies = useQuery({
    queryKey: ['companies', user?.id],
    queryFn: () => companyService.list(session!.access_token),
    enabled: Boolean(session),
  })

  if (companies.isPending) return <div className="grid min-h-screen place-items-center text-slate-500">Loading workspace…</div>
  const company = companyId ? companies.data?.find(item => item.id === companyId) : undefined
  if (companyId && !company) return <Navigate to="/companies" replace />

  const base = company ? `/company/${company.id}` : ''
  const modules: NavItem[] = company ? [
    { label: 'Dashboard', icon: LayoutDashboard, to: base, end: true },
    { label: 'Inventory', icon: Package },
    { label: 'Contacts', icon: Users },
    { label: 'Transactions', icon: Receipt },
    { label: 'Accounting', icon: BookOpen },
    { label: 'Reports', icon: BarChart3 },
  ] : []
  const manage: NavItem[] = [
    ...(company ? [{ label: 'Company settings', icon: Settings, to: `${base}/settings` }] : []),
    { label: 'My profile', icon: UserCircle, to: '/account' },
    { label: 'All companies', icon: Building2, to: '/companies', end: true },
  ]

  function renderItem(item: NavItem) {
    const Icon = item.icon
    if (!item.to) {
      return <div key={item.label} className="flex cursor-not-allowed items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-indigo-300/40">
        <Icon size={18} />{item.label}
        <span className="ml-auto rounded-full bg-white/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide">Soon</span>
      </div>
    }
    return <NavLink key={item.label} to={item.to} end={item.end} onClick={() => setOpen(false)} className={linkClass}><Icon size={18} />{item.label}</NavLink>
  }

  return <div className="min-h-screen bg-slate-50 text-slate-900">
    {open && <div className="fixed inset-0 z-30 bg-slate-900/50 lg:hidden" onClick={() => setOpen(false)} />}

    <aside className={`fixed inset-y-0 left-0 z-40 flex w-64 flex-col bg-indigo-950 transition-transform duration-200 lg:translate-x-0 ${open ? 'translate-x-0' : '-translate-x-full'}`}>
      <div className="flex h-16 items-center justify-between border-b border-white/10 px-5">
        <Link to="/companies" className="font-display text-lg font-extrabold tracking-widest text-white">LITE<span className="text-indigo-400">BOOKS</span></Link>
        <button className="text-indigo-200 lg:hidden" onClick={() => setOpen(false)} aria-label="Close menu"><X size={20} /></button>
      </div>

      {company && <Link to="/companies" onClick={() => setOpen(false)} className="mx-3 mt-4 flex items-center gap-3 rounded-lg bg-white/5 p-3 transition hover:bg-white/10" title="Switch company">
        <div className="grid size-9 shrink-0 place-items-center rounded-lg bg-indigo-500 font-display text-sm font-bold text-white">{company.company_name.slice(0, 1).toUpperCase()}</div>
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold text-white">{company.company_name}</p>
          <p className="truncate text-xs text-indigo-300">{company.company_code}</p>
        </div>
        <ChevronsUpDown size={16} className="text-indigo-300" />
      </Link>}

      <nav className="mt-5 flex-1 space-y-6 overflow-y-auto px-3 pb-4">
        {modules.length > 0 && <div className="space-y-1">
          <p className="px-3 pb-1 text-[11px] font-semibold uppercase tracking-wider text-indigo-400">Workspace</p>
          {modules.map(renderItem)}
        </div>}
        <div className="space-y-1">
          <p className="px-3 pb-1 text-[11px] font-semibold uppercase tracking-wider text-indigo-400">Manage</p>
          {manage.map(renderItem)}
        </div>
      </nav>

      <div className="border-t border-white/10 p-3">
        <div className="flex items-center gap-3 rounded-lg px-2 py-2">
          <div className="grid size-8 shrink-0 place-items-center rounded-full bg-indigo-400/20 text-xs font-bold text-indigo-100">{(user?.email?.[0] ?? 'U').toUpperCase()}</div>
          <p className="min-w-0 flex-1 truncate text-xs text-indigo-200">{user?.email}</p>
          <button onClick={() => void signOut()} className="rounded-md p-1.5 text-indigo-300 transition hover:bg-white/10 hover:text-white" aria-label="Sign out" title="Sign out"><LogOut size={16} /></button>
        </div>
      </div>
    </aside>

    <div className="lg:pl-64">
      <header className="sticky top-0 z-20 flex h-14 items-center gap-3 border-b border-slate-200 bg-white/90 px-4 backdrop-blur lg:hidden">
        <button onClick={() => setOpen(true)} className="rounded-md p-1.5 text-slate-600 hover:bg-slate-100" aria-label="Open menu"><Menu size={22} /></button>
        <span className="font-display text-base font-extrabold tracking-widest text-indigo-950">LITE<span className="text-indigo-600">BOOKS</span></span>
      </header>
      <main className="mx-auto w-full max-w-6xl px-4 py-8 sm:px-8 lg:py-10"><Outlet /></main>
    </div>
  </div>
}