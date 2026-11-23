# LiteBooks

LiteBooks is a lightweight, multi-company Inventory and Accounting Management System for small businesses. It brings product and stock management together with purchasing and core accounting foundations, with the goal of making everyday business records easier to maintain and understand.

The application is being developed as a full-stack web application using **React, TypeScript, FastAPI, and Supabase**.

> **Development status:** LiteBooks is actively under development. The core project setup, company-scoped data foundation, authentication and company workflows, inventory management, purchasing foundations, and important inventory-costing safeguards are in place. Features are still being refined; this is not yet a production-ready accounting system.

## Project goals

LiteBooks aims to provide a straightforward way to:

- Manage multiple companies under one user account.
- Maintain product, category, and unit-of-measure records.
- Track inventory movements and stock on hand.
- Record purchases and maintain supplier and customer contacts.
- Value inventory using perpetual weighted-average costing.
- Build company-specific accounting records using double-entry bookkeeping.
- Provide useful business and financial summaries as the application develops.

See [Documentation.md](Documentation.md) for the broader feature descriptions, business workflows, and accounting concepts.

## Current implementation

The repository currently contains the following foundations:

- **Application structure:** React/TypeScript frontend and FastAPI backend.
- **Authentication and company scope:** account-related endpoints, company creation and management, and company-scoped data access foundations.
- **Inventory:** categories, units of measure, products, inventory movement records, and inventory API workflows.
- **Purchasing:** purchase API and database workflow foundations.
- **Contacts:** company-scoped customer and supplier records.
- **Database safeguards:** PostgreSQL constraints, functions, triggers, and Row Level Security policies across the implemented schema.
- **Accounting foundation:** company Chart of Accounts setup, journal-entry and journal-line structures, and double-entry/period-control safeguards.
- **Inventory costing:** perpetual weighted-average costing and safeguards around inventory movement records.

The frontend and backend are still being developed together. Sales, expenses, payments, broader accounting workflows, and financial reports remain part of the ongoing implementation plan. Refer to the source code and [Documentation.md](Documentation.md) for the current scope; planned features should not be assumed to be complete.

## Technology stack

### Frontend

- React
- TypeScript
- Vite
- React Router
- TanStack Query
- Supabase JavaScript client

### Backend

- Python
- FastAPI
- Pydantic
- Pydantic Settings
- Supabase Python client

### Database and services

- Supabase
- PostgreSQL
- Supabase Auth
- PostgreSQL Row Level Security (RLS)
- Supabase CLI for database migrations

## High-level architecture

```text
User
 |
 v
React + TypeScript frontend
 |
 | HTTPS requests
 v
FastAPI backend
 |
 | Authenticated application/database operations
 v
Supabase / PostgreSQL
 |
 +-- User profiles and companies
 +-- Products, categories, and units of measure
 +-- Contacts
 +-- Purchases and inventory movements
 +-- Chart of Accounts and journal records
```

The frontend handles the user interface and communicates with the FastAPI backend for application workflows. FastAPI applies business rules and verifies that the signed-in user is authorized to access the requested company. Supabase provides authentication and PostgreSQL database services.

A company ID supplied by the browser must never be treated as proof of permission. Company ownership checks in the backend and database-level Row Level Security provide separate layers of protection.

## Local development setup

These instructions assume Ubuntu or another Linux environment. Run the frontend and backend in separate terminal windows.

### Prerequisites

- Git
- Node.js and npm
- Python 3
- A Supabase project
- Supabase CLI (the commands below use `npx supabase`)

### 1. Clone the repository

```bash
git clone https://github.com/geoffembuscad0/litebooks.git
cd litebooks
```

### 2. Configure the frontend

The frontend is located in `frontend/`.

```bash
cd frontend
npm install
cp .env.example .env
```

Update `frontend/.env` with the values from your Supabase project and local backend:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-supabase-anon-key
VITE_API_URL=http://127.0.0.1:8000
```

Start the Vite development server:

```bash
npm run dev
```

The frontend normally runs at:

```text
http://localhost:5173
```

### 3. Configure and run the FastAPI backend

The Python backend is located in `backend/`. The virtual environment is used for the backend only.

Open another terminal from the repository root:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Update `backend/.env` with your Supabase project values:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
FRONTEND_ORIGINS=http://localhost:5173
```

With the virtual environment activated and the current directory set to `backend/`, start FastAPI:

```bash
python scripts/seed_demo_users.py
fastapi dev app/main.py
```

The API normally runs at:

```text
http://127.0.0.1:8000
```

Interactive API documentation:

```text
http://127.0.0.1:8000/docs
```

To stop the backend, press `Ctrl+C`. To leave the Python virtual environment, run:

```bash
deactivate
```

Whenever you open a new terminal to run the backend, activate the environment again from the `backend/` directory:

```bash
source .venv/bin/activate
```

### 4. Supabase CLI setup

Run Supabase CLI commands from the **repository root**, where the `supabase/` directory is located.

Log in to the CLI:

```bash
npx supabase login
```

Link the local repository to your hosted Supabase project. Replace the placeholder with the project reference shown in your Supabase Dashboard URL:

```bash
npx supabase link --project-ref <your-project-ref>
```

Linking is normally a one-time setup for this local repository. If you work with multiple Supabase projects, verify the linked project before running any remote database command.

## Database migrations

LiteBooks uses timestamped SQL migration files stored in `supabase/migrations/`. Treat these files as the source of truth for the database schema and database-side logic.

### Create a migration

From the repository root:

```bash
npx supabase migration new descriptive_migration_name
```

Add the SQL changes to the generated file in `supabase/migrations/`. Use a new migration for each new database change. Avoid editing migrations that have already been applied to a shared remote database; create a follow-up migration instead.

### Preview pending remote migrations

Before applying changes to the hosted project, preview what the CLI intends to run:

```bash
npx supabase db push --dry-run --remote
```

Review the migration list and SQL changes. Confirm that the linked project is the intended development project.

### Push migrations to the hosted Supabase project

After reviewing the dry run, apply pending migrations:

```bash
npx supabase db push --yes --remote
```

The CLI tracks applied migrations in the remote migration history and skips migrations that have already been applied. The `--yes` flag automatically confirms the operation, so use it only after checking the target project and reviewing the dry-run output.

If you prefer to confirm interactively, omit `--yes`:

```bash
npx supabase db push --remote
```

### Reset the hosted development database

> **WARNING: DESTRUCTIVE OPERATION.** A remote reset removes existing user-created database objects and data in the linked database, then rebuilds the database by replaying the local migrations and configured seed files. Existing application data will be lost. Use this only for a disposable development or staging project—not production.

When you intentionally need to start the linked remote database over:

```bash
npx supabase db reset --remote
```

The CLI asks for confirmation before proceeding. Read the target information and confirm that it is the correct Supabase project before accepting. Do not add `--yes` unless you deliberately want to bypass that confirmation.

To rebuild without running configured seed files:

```bash
npx supabase db reset --remote --no-seed
```

A remote reset is different from pushing migrations:

- `npx supabase db push --remote` applies migrations that have not yet been applied. It does not wipe existing application data.
- `npx supabase db reset --remote` is destructive: it clears user-created database objects/data in the linked remote database and replays the local migration history (and configured seed files unless `--no-seed` is used).

A remote database reset does not delete the Supabase project itself. It is also not a replacement for reviewing project-level services and settings.

### Recommended migration workflow

For ordinary database changes, use this sequence:

1. Create a new migration with `npx supabase migration new descriptive_migration_name`.
2. Write and review the SQL in `supabase/migrations/`.
3. Preview pending remote changes with `npx supabase db push --dry-run --remote`.
4. Apply the reviewed migrations with `npx supabase db push --remote` (or `--yes --remote` when intentionally confirming).
5. Commit the migration file to Git so the schema change is version-controlled.

Use a remote reset only when you intentionally want to rebuild a development database from scratch.

## Repository structure

The main folders are organized as follows:

```text
litebooks/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── core/
│   │   ├── dependencies/
│   │   └── main.py
│   ├── .env.example
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   ├── contexts/
│   │   ├── pages/
│   │   └── services/
│   ├── .env.example
│   ├── package.json
│   └── vite.config.ts
├── supabase/
│   └── migrations/
├── .gitignore
├── README.md
└── Documentation.md
```

The `.venv/`, `node_modules/`, build output, and environment files are local development files and should not be committed.

## Documentation

See [Documentation.md](Documentation.md) for:

- Feature descriptions and planned capabilities.
- Company, inventory, purchase, and accounting workflows.
- Plain-language explanations of inventory costing and double-entry bookkeeping.
- Development stages and future enhancements.

## Security reminders

- Never commit `.env` files, passwords, access tokens, or private keys.
- Never expose a Supabase service-role key in frontend code.
- Use only the appropriate public/publishable key in browser-side configuration.
- Verify user identity and company ownership in the backend.
- Keep Row Level Security enabled and review policies when adding tables.
- Apply database changes through version-controlled migrations rather than making untracked schema changes directly in the hosted database.
- Treat remote database resets as destructive and verify the linked project before running them.

## Project direction

LiteBooks is being developed incrementally. The current priority is to make the core company, inventory, purchasing, and accounting foundations dependable before expanding into broader transaction workflows, financial reporting, and advanced features.