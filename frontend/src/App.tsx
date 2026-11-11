import { Navigate, Route, Routes } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { AuthProvider, useAuth } from './contexts/AuthContext'
import { RequireAuth } from './components/common/RequireAuth'
import Register from './pages/auth/Register'
import Login from './pages/auth/Login'
import CompanySetup from './pages/auth/CompanySetup'
import CompanySelection from './pages/company/CompanySelection'
import CompanyWorkspace from './pages/company/CompanyWorkspace'
import CompanySettings from './pages/company/CompanySettings'
import AccountProfile from './pages/account/AccountProfile'
import './dashboard.css'

const queryClient = new QueryClient({ defaultOptions: { queries: { retry: 1, staleTime: 30_000 } } })

function AuthEntry() {
  const { session, loading } = useAuth()
  if (loading) return <div className="screen-state">Loading LiteBooks…</div>
  return <Navigate to={session ? '/companies' : '/login'} replace />
}

function AppRoutes() {
  return <Routes>
    <Route path="/" element={<AuthEntry />} />
    <Route path="/login" element={<Login />} />
    <Route path="/register" element={<Register />} />
    <Route element={<RequireAuth />}>
      <Route path="/onboarding" element={<CompanySetup />} />
      <Route path="/company/:companyId" element={<CompanyWorkspace />} />
      <Route path="/company/:companyId/settings" element={<CompanySettings />} />
      <Route path="/companies" element={<CompanySelection />} />
      <Route path="/account" element={<AccountProfile />} />
    </Route>
    <Route path="*" element={<Navigate to="/" replace />} />
  </Routes>
}

export default function App() {
  return <QueryClientProvider client={queryClient}><AuthProvider><AppRoutes /></AuthProvider></QueryClientProvider>
}
