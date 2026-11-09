CREATE TABLE public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    company_id UUID NOT NULL,

    transaction_id UUID NOT NULL,

    account_id UUID NOT NULL,

    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,

    payment_method VARCHAR(30) NOT NULL,

    amount NUMERIC(15, 2) NOT NULL,

    reference_number VARCHAR(100),

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT payments_company_id_id_unique
        UNIQUE (company_id, id),

    CONSTRAINT payments_transaction_fk
        FOREIGN KEY (company_id, transaction_id)
        REFERENCES public.transactions(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT payments_account_fk
        FOREIGN KEY (company_id, account_id)
        REFERENCES public.accounts(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT payments_method_check
        CHECK (
            payment_method IN (
                'cash',
                'bank_transfer',
                'card',
                'cheque',
                'e_wallet',
                'other'
            )
        ),

    CONSTRAINT payments_amount_positive
        CHECK (amount > 0)
);

CREATE INDEX idx_payments_company_id
ON public.payments(company_id);

CREATE INDEX idx_payments_transaction
ON public.payments(company_id, transaction_id);

CREATE INDEX idx_payments_account
ON public.payments(company_id, account_id);

CREATE INDEX idx_payments_date
ON public.payments(company_id, payment_date);