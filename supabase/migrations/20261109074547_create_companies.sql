-- ============================================
-- TABLE: companies
-- DESCRIPTION: Stores companies owned by users
-- ============================================

CREATE TABLE public.companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    owner_id UUID NOT NULL
        REFERENCES auth.users(id)
        ON DELETE RESTRICT,

    company_name VARCHAR(150) NOT NULL,

    company_code VARCHAR(50),

    address TEXT,

    contact_number VARCHAR(30),

    email VARCHAR(255),

    currency CHAR(3) NOT NULL DEFAULT 'PHP',

    fiscal_year_start INTEGER NOT NULL DEFAULT 1,

    timezone VARCHAR(100) NOT NULL DEFAULT 'Asia/Manila',

    status VARCHAR(20) NOT NULL DEFAULT 'active',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- A company code only needs to be unique
    -- within the same owner's companies.
    CONSTRAINT unique_owner_company_code
        UNIQUE (owner_id, company_code),

    -- Fiscal year starts from January (1) to December (12).
    CONSTRAINT valid_fiscal_year_start
        CHECK (fiscal_year_start BETWEEN 1 AND 12),

    -- ISO-style three-character currency code.
    CONSTRAINT valid_currency_length
        CHECK (currency ~ '^[A-Z]{3}$'),

    -- Only supported company statuses.
    CONSTRAINT valid_company_status
        CHECK (status IN ('active', 'archived'))
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_companies_owner_id
ON public.companies(owner_id);

CREATE INDEX idx_companies_status
ON public.companies(status);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

-- Owners can view their companies.
CREATE POLICY "Owners can view their companies"
ON public.companies
FOR SELECT
TO authenticated
USING (auth.uid() = owner_id);

-- Owners can create companies under their account.
CREATE POLICY "Owners can create their companies"
ON public.companies
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = owner_id);

-- Owners can update their companies.
CREATE POLICY "Owners can update their companies"
ON public.companies
FOR UPDATE
TO authenticated
USING (auth.uid() = owner_id)
WITH CHECK (auth.uid() = owner_id);