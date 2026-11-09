CREATE TABLE public.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    company_id UUID NOT NULL
        REFERENCES public.companies(id)
        ON DELETE CASCADE,

    parent_account_id UUID,

    account_code VARCHAR(20) NOT NULL,
    account_name VARCHAR(150) NOT NULL,

    account_type VARCHAR(20) NOT NULL,
    account_subtype VARCHAR(50),

    normal_balance VARCHAR(10) NOT NULL,

    description TEXT,

    is_system_account BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT accounts_company_id_id_unique
        UNIQUE (company_id, id),

    CONSTRAINT accounts_company_code_unique
        UNIQUE (company_id, account_code),

    CONSTRAINT accounts_type_check
        CHECK (
            account_type IN (
                'asset',
                'liability',
                'equity',
                'revenue',
                'expense'
            )
        ),

    CONSTRAINT accounts_normal_balance_check
        CHECK (
            normal_balance IN ('debit', 'credit')
        ),

    CONSTRAINT accounts_parent_company_fk
        FOREIGN KEY (company_id, parent_account_id)
        REFERENCES public.accounts(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT accounts_no_self_parent
        CHECK (
            parent_account_id IS NULL
            OR parent_account_id <> id
        )
);

CREATE INDEX idx_accounts_company_id
ON public.accounts(company_id);

CREATE INDEX idx_accounts_company_type
ON public.accounts(company_id, account_type);

CREATE INDEX idx_accounts_parent_account
ON public.accounts(company_id, parent_account_id);