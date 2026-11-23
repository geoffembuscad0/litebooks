# LiteBooks

LiteBooks is a multi-company inventory and accounting system for small businesses. It brings product and stock management together with double-entry accounting, purchase workflows, and financial reporting.

## Repository description

**Inventory and accounting management for small businesses, with multi-company support, weighted-average inventory costing, purchase workflows, posted journal records, account balances, and financial reports.**

## Features

### Implemented

- Multi-company workspaces with company switching and ownership checks
- Registration, sign-in, password recovery, and account profile workflows
- Company settings including currency and fiscal-year configuration
- Product, category, and unit-of-measure management
- Inventory movements and weighted-average inventory costing
- Customer and supplier contact management
- Purchase drafts and purchase posting
- Incoming inventory movements on posted purchases
- Chart of Accounts and journal-entry database foundations
- Double-entry validation and accounting-period posting controls
- Posted account balances derived from journal lines
- Audit trail support for accounting mutations
- Trial Balance
- Profit & Loss statement
- Balance Sheet
- Row Level Security for company-scoped records
- Supabase PostgreSQL migrations and default account seeding

### Core workflows still in progress

- Complete sales drafting, posting, and customer receivable workflows
- Expense entry, posting, and account selection
- Supplier and customer payment tracking
- Partial payment allocation
- Complete Chart of Accounts management UI
- Journal-entry review and General Ledger UI
- Controlled voiding and reversal workflows
- Automated purchase and sale journal UI workflows

## Technology stack

### Frontend

- React 19
- TypeScript
- Vite
- React Router
- TanStack Query
- Tailwind CSS
- Supabase JavaScript client
- Lucide icons

### Backend

- Python
- FastAPI
- Pydantic
- Pydantic Settings
- Supabase Python client

### Database

- Supabase
- PostgreSQL
- Supabase Auth
- PostgreSQL functions and triggers
- Row Level Security
- Timestamped SQL migrations

## Architecture

```text
Browser
  |
  v
React + TypeScript frontend
  |
  | HTTP/JSON with a Supabase access token
  v
FastAPI backend
  |
  | Authenticated Supabase operations
  v
Supabase PostgreSQL
  |
  +-- Profiles and companies
  +-- Products, categories, units, and inventory
  +-- Customers and suppliers
  +-- Purchases and transactions
  +-- Accounts and journal entries
  +-- Payments and accounting audit data
```

Company ownership is enforced in the FastAPI application and by PostgreSQL Row Level Security. A company ID supplied by the browser is never considered proof of access.

## Project structure

```text
litebooks/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── core/
│   │   ├── dependencies/
│   │   └── main.py
│   ├── scripts/
│   ├── .env.example
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   ├── contexts/
│   │   ├── pages/
│   │   └── services/
│   ├── .env.example
│   └── package.json
├── supabase/
│   └── migrations/
├── Documentation.md
└── README.md
```

## Prerequisites

- Git
- Node.js and npm
- Python 3
- A Supabase project
- Supabase CLI

## Local setup

Run the frontend and backend in separate terminals.

### 1. Clone the repository

```bash
git clone https://github.com/geoffembuscad0/litebooks.git
cd litebooks
```

### 2. Configure and run the frontend

```bash
cd frontend
npm install
cp .env.example .env
npm run dev
```

Update `frontend/.env`:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-supabase-anon-key
VITE_API_URL=http://127.0.0.1:8000
```

The frontend normally starts at:

```text
http://localhost:5173
```

### 3. Configure and run the backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
fastapi dev app/main.py
```

Update `backend/.env`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
FRONTEND_ORIGINS=http://localhost:5173
```

The API normally runs at:

```text
http://127.0.0.1:8000
```

Interactive API documentation is available at:

```text
http://127.0.0.1:8000/docs
```

## Supabase setup

Run Supabase commands from the repository root.

```bash
npx supabase login
npx supabase link --project-ref <your-project-ref>
```

Preview pending migrations:

```bash
npx supabase db push --dry-run --remote
```

Apply migrations:

```bash
npx supabase db push --remote
```

Create a migration:

```bash
npx supabase migration new descriptive_migration_name
```

Migration files are stored in `supabase/migrations/`. Review every migration before applying it to a shared or production database.

> A remote database reset is destructive. Use it only when intentionally rebuilding a development database.

## Accounting model

LiteBooks uses posted journal entries as the source for accounting reports.

- Debits and credits must balance before posting
- Posted entries cannot be casually changed or deleted
- Account balances are calculated from posted journal lines
- Trial Balance reconciles debit and credit balances
- Profit & Loss reports revenue and expenses for a date range
- Balance Sheet reports assets, liabilities, and equity as of a date
- Transaction posting creates accounting entries for supported business events
- Closed accounting periods protect posted activity from backdated posting

## Main modules

- **Dashboard:** company-level operational and inventory summaries
- **Inventory:** categories, units, products, and stock movements
- **Contacts:** customer and supplier records
- **Purchases:** supplier purchase drafts and posting
- **Accounting:** account balances and posted accounting activity
- **Reports:** Trial Balance, Profit & Loss, and Balance Sheet
- **Companies:** create, view, switch, and configure company workspaces
- **Account:** authenticated user profile

## Security

- Do not commit `.env` files or Supabase credentials
- Never expose a Supabase service-role key in frontend code
- Keep Row Level Security enabled for company-owned tables
- Verify company ownership in backend endpoints
- Apply database changes through version-controlled migrations
- Treat remote database resets as destructive operations

## Documentation

See [Documentation.md](Documentation.md) for:

- Feature descriptions
- Everyday business workflows
- Purchase and inventory processes
- Double-entry accounting concepts
- Reporting behavior
- Development stages and future scope

## Development status

LiteBooks has completed a strong core accounting and inventory foundation. Authentication, company management, inventory, contacts, purchases, account balances, Trial Balance, Profit & Loss, and Balance Sheet are implemented.

Sales, expenses, payments, full Chart of Accounts management, journal review, and the General Ledger remain the main next workflows for completing the MVP.
