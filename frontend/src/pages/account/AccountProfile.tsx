import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { profileService } from '../../services/profileService'

export default function AccountProfile() {
  const { session, user, signOut } = useAuth()
  const queryClient = useQueryClient()
  const [message, setMessage] = useState('')
  const profile = useQuery({ queryKey: ['account-profile', user?.id], queryFn: () => profileService.get(session!.access_token), enabled: Boolean(session) })
  const update = useMutation({
    mutationFn: (names: { firstname: string; lastname: string }) => profileService.update(session!.access_token, names),
    onSuccess: async data => {
      queryClient.setQueryData(['account-profile', user?.id], data)
      setMessage('Your profile has been updated.')
    },
    onError: (error: Error) => setMessage(error.message),
  })

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setMessage('')
    const form = new FormData(event.currentTarget)
    update.mutate({ firstname: String(form.get('firstname')).trim(), lastname: String(form.get('lastname')).trim() })
  }

  if (profile.isPending) return <div className="screen-state">Loading your profile…</div>

  return <main className="app-shell">
    <header className="topbar"><Link className="brand" to="/">LITE<span>BOOKS</span></Link><nav className="top-nav"><Link className="nav-link" to="/companies">Your companies</Link></nav><div className="user-actions"><span>{user?.email}</span><button className="text-button" onClick={() => void signOut()}>Sign out</button></div></header>
    <section className="settings-content profile-content">
      <Link className="back-link" to="/companies">← Back to companies</Link>
      <div className="page-heading settings-heading"><div><p className="eyebrow">ACCOUNT</p><h1>Your profile</h1><p className="muted">Manage the personal details associated with your LiteBooks account.</p></div></div>
      {profile.isError && <div className="alert error" role="alert">{profile.error.message}<button className="text-button" onClick={() => void profile.refetch()}>Try again</button></div>}
      {profile.data && <form className="panel profile-panel" onSubmit={submit}>
        <div className="profile-identity"><div className="profile-avatar">{`${profile.data.firstname?.[0] ?? ''}${profile.data.lastname?.[0] ?? ''}`.trim().toUpperCase() || (user?.email?.[0] ?? 'U').toUpperCase()}</div><div><h2>{[profile.data.firstname, profile.data.lastname].filter(Boolean).join(' ') || 'Your account'}</h2><p>{profile.data.email}</p></div></div>
        <div className="settings-section-heading"><h2>Personal information</h2><p>Your name appears in your account profile.</p></div>
        <div className="form-stack two-column settings-form">
          <label>First name<input name="firstname" defaultValue={profile.data.firstname} required maxLength={150} autoComplete="given-name" /></label>
          <label>Last name<input name="lastname" defaultValue={profile.data.lastname} required maxLength={150} autoComplete="family-name" /></label>
          <label className="span-two">Email address<input value={profile.data.email ?? ''} readOnly /><small>To change your email, update it through your sign-in provider.</small></label>
        </div>
        {message && <div className={`alert ${update.isError ? 'error' : 'success'}`} role="status">{message}</div>}
        <div className="settings-actions"><button className="button primary" disabled={update.isPending}>{update.isPending ? 'Saving…' : 'Save profile'}</button></div>
      </form>}
    </section>
  </main>
}
