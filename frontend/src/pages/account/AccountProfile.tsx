import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth } from '../../contexts/AuthContext'
import { profileService } from '../../services/profileService'
import { alertClass, btnPrimary, cardClass, hintClass, inputClass, labelClass } from '../../components/ui/styles'

export default function AccountProfile() {
  const { session, user } = useAuth()
  const queryClient = useQueryClient()
  const [message, setMessage] = useState('')
  const profile = useQuery({ queryKey: ['account-profile', user?.id], queryFn: () => profileService.get(session!.access_token), enabled: Boolean(session) })
  const update = useMutation({
    mutationFn: (names: { firstname: string; lastname: string }) => profileService.update(session!.access_token, names),
    onSuccess: data => {
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

  const p = profile.data
  const initials = p ? (`${p.firstname?.[0] ?? ''}${p.lastname?.[0] ?? ''}`.trim().toUpperCase() || (user?.email?.[0] ?? 'U').toUpperCase()) : ''

  return <div className="max-w-2xl">
    <p className="text-xs font-semibold uppercase tracking-widest text-indigo-600">Account</p>
    <h1 className="mt-1 font-display text-3xl font-extrabold tracking-tight text-slate-900">Your profile</h1>
    <p className="mb-8 mt-1 text-sm text-slate-500">Manage the personal details associated with your LiteBooks account.</p>

    {profile.isPending && <div className={`${cardClass} p-6 text-sm text-slate-500`}>Loading your profile…</div>}
    {profile.isError && <div className={`${alertClass('error')} flex items-center justify-between`}>{profile.error.message}<button className="font-semibold underline" onClick={() => void profile.refetch()}>Try again</button></div>}

    {p && <form className={`${cardClass} p-6 sm:p-8`} onSubmit={submit}>
      <div className="mb-6 flex items-center gap-4 border-b border-slate-100 pb-6">
        <div className="grid size-14 place-items-center rounded-full bg-indigo-100 font-display text-lg font-extrabold text-indigo-700">{initials}</div>
        <div>
          <h2 className="font-display text-base font-bold text-slate-900">{[p.firstname, p.lastname].filter(Boolean).join(' ') || 'Your account'}</h2>
          <p className="text-sm text-slate-500">{p.email}</p>
        </div>
      </div>
      <div className="grid gap-5 sm:grid-cols-2">
        <label className={labelClass}>First name<input className={inputClass} name="firstname" defaultValue={p.firstname} required maxLength={150} autoComplete="given-name" /></label>
        <label className={labelClass}>Last name<input className={inputClass} name="lastname" defaultValue={p.lastname} required maxLength={150} autoComplete="family-name" /></label>
        <label className={`${labelClass} sm:col-span-2`}>Email address<input className={inputClass} value={p.email ?? ''} readOnly /><small className={hintClass}>To change your email, update it through your sign-in provider.</small></label>
      </div>
      {message && <div className={`${alertClass(update.isError ? 'error' : 'success')} mt-6`} role="status">{message}</div>}
      <div className="mt-6 flex justify-end border-t border-slate-100 pt-5">
        <button className={btnPrimary} disabled={update.isPending}>{update.isPending ? 'Saving…' : 'Save profile'}</button>
      </div>
    </form>}
  </div>
}