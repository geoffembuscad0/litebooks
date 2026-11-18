import { useEffect, useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../../services/supabase'
import { Brand } from './Register'

export default function ResetPassword() {
  const [checkingSession, setCheckingSession] = useState(true)
  const [hasSession, setHasSession] = useState(false)
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    let mounted = true
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (mounted && session) {
        setHasSession(true)
        setCheckingSession(false)
      }
    })

    supabase.auth.getSession().then(({ data, error: sessionError }) => {
      if (!mounted) return
      setHasSession(Boolean(data.session))
      if (sessionError) setError(sessionError.message)
      setCheckingSession(false)
    }).catch(() => {
      if (mounted) {
        setError('Unable to verify this reset link. Please request a new one.')
        setCheckingSession(false)
      }
    })

    return () => {
      mounted = false
      subscription.unsubscribe()
    }
  }, [])

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(''); setMessage('')
    if (password !== confirmPassword) { setError('The passwords do not match.'); return }
    setBusy(true)
    try {
      const { error: updateError } = await supabase.auth.updateUser({ password })
      if (updateError) { setError(updateError.message); return }
      setMessage('Your password has been updated. You can now continue to LiteBooks.')
    } catch {
      setError('Unable to update your password right now. Please try again.')
    } finally {
      setBusy(false)
    }
  }

  return <main className="auth-shell">
    <section className="auth-card">
      <Brand />
      <p className="eyebrow">ACCOUNT RECOVERY</p>
      <h1>Set a new password</h1>
      <p className="muted">Choose a new password for your LiteBooks account.</p>
      {error && <div className="alert error" role="alert">{error}</div>}
      {checkingSession ? <p className="muted" role="status">Verifying your reset link…</p> : !hasSession ? <div className="alert error" role="alert">This password reset link is invalid or has expired. <Link to="/forgot-password">Request a new link</Link>.</div> : message ? <>
        <div className="alert success" role="status">{message}</div>
        <Link className="button primary full" to="/">Continue to LiteBooks</Link>
      </> : <form className="form-stack" onSubmit={submit}>
        <label>New password<input type="password" autoComplete="new-password" value={password} onChange={e => setPassword(e.target.value)} required minLength={8} /></label>
        <label>Confirm new password<input type="password" autoComplete="new-password" value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)} required minLength={8} /></label>
        <button className="button primary full" disabled={busy}>{busy ? 'Updating password…' : 'Update password'}</button>
      </form>}
      {!checkingSession && !message && <p className="form-footer"><Link to="/login">Back to sign in</Link></p>}
    </section>
  </main>
}
