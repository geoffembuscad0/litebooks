# LiteBooks

LiteBooks is a lightweight, multi-company Inventory and Accounting
Management System. It is being developed to help small businesses
organize their products, monitor stock, record everyday business
transactions, and understand their financial position without the
complexity of a large enterprise accounting platform.

The project is being built as a full-stack web application with **React,
TypeScript, FastAPI, and Supabase**.

## Project goals

LiteBooks aims to provide a straightforward place to:

-   Maintain product, category, and unit-of-measure records.
-   Track inventory coming in and going out.
-   Record purchases, sales, expenses, and payments.
-   Maintain a company-specific Chart of Accounts.
-   Record accounting activity using double-entry bookkeeping.
-   View useful financial reports, including Profit and Loss and Balance
    Sheet.
-   Manage more than one company under a single user account.

The initial focus is on reliable inventory records and understandable
financial reporting. LiteBooks is not intended to reproduce every
feature of a full enterprise accounting suite.

## Planned modules

  -----------------------------------------------------------------------
  Module                              Purpose
  ----------------------------------- -----------------------------------
  Dashboard                           Show an overview of inventory,
                                      sales, expenses, and financial
                                      performance.

  Account Management                  Support sign-in, user profile, and
                                      account settings.

  Company Management                  Allow a user to create, edit, and
                                      switch between their companies.

  Inventory                           Manage products, categories, units
                                      of measure, stock movements, and
                                      stock valuation.

  Contacts                            Maintain customer and supplier
                                      records.

  Transactions                        Record purchases, sales, operating
                                      expenses, and payments.

  Accounting                          Manage the Chart of Accounts,
                                      journal entries, and the General
                                      Ledger.

  Financial Reports                   Present the Profit and Loss
                                      Statement, Balance Sheet, and other
                                      useful summaries.
  -----------------------------------------------------------------------

## Technology stack

### Frontend

-   React
-   TypeScript
-   Vite
-   React Router
-   TanStack Query
-   Supabase JavaScript client

### Backend

-   Python
-   FastAPI
-   Pydantic
-   Supabase Python client

### Database and services

-   Supabase
-   PostgreSQL
-   Supabase Auth
-   PostgreSQL Row Level Security (RLS)

## High-level architecture

``` text
User
 |
 v
React + TypeScript frontend
 |
 | HTTPS requests
 v
FastAPI backend
 |
 | Authenticated database operations
 v
Supabase / PostgreSQL
 |
 +-- User profiles
 +-- Companies
 +-- Inventory records
 +-- Contacts
 +-- Transactions and payments
 +-- Journal entries and lines
```

The frontend is responsible for the user interface and user experience.
FastAPI handles application workflows and business rules. Supabase
provides authentication and PostgreSQL database services.

The backend must verify that the signed-in user is authorized to access
the requested company. A company ID supplied by the browser must never
be treated as proof of permission. Row Level Security will provide an
additional database-level protection layer.

## Multi-company approach

A user may own multiple companies. Each company has its own products,
contacts, transactions, accounts, inventory movements, and accounting
records.

After signing in, the user selects the company they want to work with.
The selected company becomes the context for the application's business
screens. Switching companies changes the data being displayed.

Company-owned records contain a `company_id`. Database relationships are
designed to prevent records from one company from being linked
accidentally to another company's records.

The initial ownership model is owner-only. Team membership and
invitations may be considered in a later version.

## Inventory and accounting principles

-   Product stock is derived from inventory movement records rather than
    maintained as an independently editable quantity on the product
    record.
-   The planned inventory valuation method is perpetual weighted average
    cost.
-   Monetary values use PostgreSQL `NUMERIC` types rather than
    floating-point types.
-   Accounting activity is recorded using journal entries and journal
    lines.
-   Every posted journal entry must have equal total debits and credits.
-   Posted accounting records should be corrected through reversing or
    compensating entries rather than silently edited.
-   Financial reports should be derived from posted accounting records,
    not from manually maintained report totals.

## Development status

The project is in its foundational database-design stage.

The database schema has been designed in batches covering:

1.  User profiles and companies
2.  Categories, units of measure, and products
3.  Contacts and Chart of Accounts
4.  Transactions, transaction items, and payments
5.  Inventory movements
6.  Journal entries and journal lines

The Supabase CLI dry-run validation has been reported successful through
Batch 6. A successful dry run previews the migration; it does not by
itself confirm that the migration has been applied to the hosted
database.

Next planned work includes database helper functions and triggers,
default Chart of Accounts setup, Row Level Security policies, and the
application workflows that connect transactions to inventory and
accounting records.

## Local development setup

The following steps describe the current local development arrangement.
Exact package versions may change as the project evolves.

### Prerequisites

-   Git
-   Node.js LTS and npm
-   Python 3
-   A Supabase project
-   Supabase CLI

### 1. Clone the repository

``` bash
git clone <your-repository-url>
cd LiteBooks
```

### 2. Set up the frontend

``` bash
npm install
npm run dev
```

The Vite development server normally runs at:

``` text
http://localhost:5173
```

### 3. Set up the backend

``` bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install "fastapi[standard]" supabase pydantic-settings python-dotenv
```

Start the API:

``` bash
fastapi dev app/main.py
```

The API normally runs at:

``` text
http://127.0.0.1:8000
```

Interactive API documentation is available at:

``` text
http://127.0.0.1:8000/docs
```

### 4. Configure Supabase

Create the required environment files based on the project's current
configuration. Keep credentials and secret keys out of source control.

Typical configuration values include:

-   Supabase project URL
-   Supabase publishable/anonymous key for the frontend, as appropriate
-   Supabase URL and server-side credentials for the backend
-   Any application-specific environment settings

Never expose a Supabase service-role key in frontend code or commit it
to Git.

### 5. Run database migrations

The project uses Supabase CLI migrations in `supabase/migrations/`.

Create a migration:

``` bash
npx supabase migration new descriptive_migration_name
```

Preview pending remote migrations:

``` bash
npx supabase db push --dry-run --remote
```

Apply pending migrations to the linked hosted project only after
reviewing the preview:

``` bash
npx supabase db push --yes --remote
```

Make sure the CLI is logged in and the project is linked before running
remote migration commands. Review each migration carefully before
applying it to a shared or production database.

## Repository structure

The main project structure is expected to follow this arrangement:

``` text
LiteBooks/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── core/
│   │   ├── dependencies/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   └── main.py
│   └── .venv/
├── src/
│   └── ... frontend source
├── supabase/
│   ├── migrations/
│   └── config.toml
├── .gitignore
├── package.json
├── README.md
└── Documentation.md
```

The actual structure may expand as features are implemented.

## Documentation

See **[Documentation.md](Documentation.md)** for the planned features,
plain-language workflows, and explanations of how common business
activities move through the system.

## Security reminders

-   Do not commit `.env` files, passwords, access tokens, or private
    keys.
-   Do not place service-role credentials in browser code.
-   Validate user identity and company ownership in the backend.
-   Enable and test RLS policies before allowing direct client access to
    protected tables.
-   Apply database migrations deliberately and keep backups appropriate
    to the environment.

## Project direction

LiteBooks will be developed incrementally. The priority is to make
core workflows dependable and easy to understand before adding advanced
accounting, automation, or collaboration features.
