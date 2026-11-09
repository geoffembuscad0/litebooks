import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { supabase } from '../../services/supabase'

export default function Register() {
  const navigate = useNavigate()
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState(false)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(''); setMessage(''); setBusy(true)
    const { data, error: signUpError } = await supabase.auth.signUp({
      email: email.trim(), password,
      options: { data: { full_name: name.trim() } },
    })
    setBusy(false)
    if (signUpError) { setError(signUpError.message); return }
    if (data.session) navigate('/onboarding', { replace: true })
    else setMessage('Your account was created. Confirm your email, then sign in to finish setting up your company.')
  }

  return <main className="auth-shell">
    <section className="auth-card">
      <Brand />
      <p className="eyebrow">GET STARTED</p>
      <h1>Create your account</h1>
      <p className="muted">Set up your LiteBooks account to start managing your business.</p>
      {error && <div className="alert error" role="alert">{error}</div>}
      {message && <div className="alert success" role="status">{message} <Link to="/login">Sign in</Link></div>}
      <form className="form-stack" onSubmit={submit}>
        <label>Full name<input autoComplete="name" value={name} onChange={e => setName(e.target.value)} required maxLength={150} /></label>
        <label>Email address<input type="email" autoComplete="email" value={email} onChange={e => setEmail(e.target.value)} required /></label>
        <label>Password<input type="password" autoComplete="new-password" value={password} onChange={e => setPassword(e.target.value)} required minLength={8} /></label>
        <button className="button primary full" disabled={busy}>{busy ? 'Creating account…' : 'Create account'}</button>
      </form>
      <p className="form-footer">Already registered? <Link to="/login">Sign in</Link></p>
    </section>
  </main>
}

export function Brand() { return <Link className="brand" to="/">LITE<span>BOOKS</span></Link> }
