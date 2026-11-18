import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../../services/supabase'
import { Brand } from './Register'

export default function ForgotPassword() {
  const [email, setEmail] = useState('')
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState(false)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(''); setMessage(''); setBusy(true)
    try {
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(email.trim(), {
        redirectTo: `${window.location.origin}/reset-password`,
      })
      if (resetError) { setError(resetError.message); return }
      // Keep the response generic so the form does not reveal whether an email is registered.
      setMessage('If an account exists for that email, you’ll receive a password reset link shortly.')
    } catch {
      setError('Unable to request a password reset right now. Please try again.')
    } finally {
      setBusy(false)
    }
  }

  return <main className="auth-shell">
    <section className="auth-card">
      <Brand />
      <p className="eyebrow">ACCOUNT RECOVERY</p>
      <h1>Forgot your password?</h1>
      <p className="muted">Enter the email address associated with your account and we’ll send you a reset link.</p>
      {error && <div className="alert error" role="alert">{error}</div>}
      {message && <div className="alert success" role="status">{message}</div>}
      <form className="form-stack" onSubmit={submit}>
        <label>Email address<input type="email" autoComplete="email" value={email} onChange={e => setEmail(e.target.value)} required /></label>
        <button className="button primary full" disabled={busy}>{busy ? 'Sending…' : 'Send reset link'}</button>
      </form>
      <p className="form-footer"><Link to="/login">Back to sign in</Link></p>
    </section>
  </main>
}
