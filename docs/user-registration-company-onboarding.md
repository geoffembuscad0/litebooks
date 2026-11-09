# User registration and company onboarding

## Configuration

Copy `backend/.env.example` to `backend/.env` and `frontend/.env.example` to `frontend/.env.local`, then fill in the Supabase project URL and publishable/anon key. Never put a Supabase service-role key in the frontend or commit credentials.

Install backend dependencies from `backend/` with `pip install -r requirements.txt`. Run the API using `fastapi dev app/main.py` from that directory. Install the frontend dependencies from `frontend/` using `npm install`, then run `npm run dev`.

## Flow

Registration and login use Supabase Auth from the React app. Company creation and listing use the FastAPI REST API with the user's Supabase access token. The API validates the token and forwards the same user JWT to Supabase PostgREST, so company RLS policies remain active; the company owner ID is taken from the verified token, never from browser input.

If email confirmation is enabled, Supabase may create the account without returning an active session. The user must confirm their email and log in before completing onboarding. If company creation fails, the Auth account remains valid; the user can sign in again and reach `/onboarding` while they have no active companies.

Company codes are uppercased by the API and unique per owner, case-insensitively. Apply the migration in `supabase/migrations/20261109080000_require_company_code.sql` before using this flow. The migration assumes no existing company rows have a null or blank company code, and that there are no duplicate codes per owner ignoring case.
