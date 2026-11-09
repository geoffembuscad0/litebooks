import { useState, type FormEvent } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { supabase } from '../../services/supabase'
import { Brand } from './Register'

export default function Login() {
  const navigate = useNavigate()
  const location = useLocation()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(''); setBusy(true)
    const { error: signInError } = await supabase.auth.signInWithPassword({ email: email.trim(), password })
    setBusy(false)
    if (signInError) { setError(signInError.message); return }
    const destination = (location.state as { from?: string } | null)?.from
    navigate(destination ?? '/', { replace: true })
  }

  return <main className="auth-shell">
    <section className="auth-card">
      <Brand />
      <p className="eyebrow">WELCOME BACK</p>
      <h1>Sign in</h1>
      <p className="muted">Sign in to continue to your company workspace.</p>
      {error && <div className="alert error" role="alert">{error}</div>}
      <form className="form-stack" onSubmit={submit}>
        <label>Email address<input type="email" autoComplete="email" value={email} onChange={e => setEmail(e.target.value)} required /></label>
        <label>Password<input type="password" autoComplete="current-password" value={password} onChange={e => setPassword(e.target.value)} required /></label>
        <button className="button primary full" disabled={busy}>{busy ? 'Signing in…' : 'Sign in'}</button>
      </form>
      <p className="form-footer">New to LiteBooks? <Link to="/register">Create an account</Link></p>
    </section>
  </main>
}
