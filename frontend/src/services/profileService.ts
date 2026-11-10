import { apiRequest } from './companyService'

export type AccountProfile = {
  id: string
  firstname: string
  lastname: string
  avatar_url?: string | null
  email: string | null
  created_at?: string
  updated_at?: string
}

export const profileService = {
  get: (token: string) => apiRequest<AccountProfile>('/api/auth/profile', token),
  update: (token: string, names: Pick<AccountProfile, 'firstname' | 'lastname'>) => apiRequest<AccountProfile>('/api/auth/profile', token, {
    method: 'PATCH',
    body: JSON.stringify(names),
  }),
}
