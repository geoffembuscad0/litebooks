CREATE TABLE public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    company_id UUID NOT NULL
        REFERENCES public.companies(id)
        ON DELETE CASCADE,

    contact_id UUID,

    transaction_number VARCHAR(50) NOT NULL,

    transaction_type VARCHAR(20) NOT NULL,

    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,

    status VARCHAR(20) NOT NULL DEFAULT 'draft',

    reference_number VARCHAR(100),
    notes TEXT,

    subtotal NUMERIC(15, 2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(15, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(15, 2) NOT NULL DEFAULT 0,

    total_amount NUMERIC(15, 2)
        GENERATED ALWAYS AS (
            subtotal - discount_amount + tax_amount
        ) STORED,

    posted_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT transactions_company_id_id_unique
        UNIQUE (company_id, id),

    CONSTRAINT transactions_company_number_unique
        UNIQUE (company_id, transaction_number),

    CONSTRAINT transactions_contact_company_fk
        FOREIGN KEY (company_id, contact_id)
        REFERENCES public.contacts(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT transactions_type_check
        CHECK (
            transaction_type IN (
                'purchase',
                'sale',
                'expense'
            )
        ),

    CONSTRAINT transactions_status_check
        CHECK (
            status IN (
                'draft',
                'posted',
                'void'
            )
        ),

    CONSTRAINT transactions_subtotal_nonnegative
        CHECK (subtotal >= 0),

    CONSTRAINT transactions_discount_nonnegative
        CHECK (
            discount_amount >= 0
            AND discount_amount <= subtotal
        ),

    CONSTRAINT transactions_tax_nonnegative
        CHECK (tax_amount >= 0),

    CONSTRAINT transactions_total_nonnegative
        CHECK (subtotal - discount_amount + tax_amount >= 0),

    CONSTRAINT transactions_due_date_check
        CHECK (
            due_date IS NULL
            OR due_date >= transaction_date
        )
);

CREATE INDEX idx_transactions_company_id
ON public.transactions(company_id);

CREATE INDEX idx_transactions_company_date
ON public.transactions(company_id, transaction_date);

CREATE INDEX idx_transactions_company_type
ON public.transactions(company_id, transaction_type);

CREATE INDEX idx_transactions_company_status
ON public.transactions(company_id, status);

CREATE INDEX idx_transactions_contact
ON public.transactions(company_id, contact_id);