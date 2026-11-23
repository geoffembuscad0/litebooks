export const inputClass = 'w-full rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-sm shadow-sm placeholder:text-slate-400 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/20 read-only:bg-slate-50 read-only:text-slate-500'
export const labelClass = 'grid gap-1.5 text-sm font-medium text-slate-700'
export const hintClass = 'text-xs font-normal text-slate-400'
export const cardClass = 'rounded-xl border border-slate-200 bg-white shadow-sm'
export const btnPrimary = 'inline-flex items-center justify-center rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-700 disabled:cursor-wait disabled:opacity-60'
export const btnSecondary = 'inline-flex items-center justify-center rounded-lg border border-slate-300 bg-white px-4 py-2.5 text-sm font-semibold text-slate-700 transition hover:bg-slate-50'
export const alertClass = (kind: 'error' | 'success') =>
  `rounded-lg border px-4 py-3 text-sm ${kind === 'error' ? 'border-rose-200 bg-rose-50 text-rose-700' : 'border-emerald-200 bg-emerald-50 text-emerald-700'}`