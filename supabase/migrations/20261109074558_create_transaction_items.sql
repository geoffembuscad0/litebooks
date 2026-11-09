CREATE TABLE public.transaction_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    company_id UUID NOT NULL,

    transaction_id UUID NOT NULL,

    line_number INTEGER NOT NULL,

    item_type VARCHAR(20) NOT NULL DEFAULT 'product',

    product_id UUID,
    expense_account_id UUID,
    unit_of_measure_id UUID,

    description VARCHAR(255) NOT NULL,

    -- Historical snapshots
    sku VARCHAR(100),
    unit_name VARCHAR(50),
    unit_abbreviation VARCHAR(15),

    quantity NUMERIC(15, 4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(15, 4) NOT NULL DEFAULT 0,

    line_subtotal NUMERIC(15, 2)
        GENERATED ALWAYS AS (
            ROUND(quantity * unit_price, 2)
        ) STORED,

    discount_amount NUMERIC(15, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(15, 2) NOT NULL DEFAULT 0,

    line_total NUMERIC(15, 2)
        GENERATED ALWAYS AS (
            ROUND(quantity * unit_price, 2)
            - discount_amount
            + tax_amount
        ) STORED,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT transaction_items_company_id_id_unique
        UNIQUE (company_id, id),

    CONSTRAINT transaction_items_line_unique
        UNIQUE (company_id, transaction_id, line_number),

    CONSTRAINT transaction_items_transaction_fk
        FOREIGN KEY (company_id, transaction_id)
        REFERENCES public.transactions(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT transaction_items_product_fk
        FOREIGN KEY (company_id, product_id)
        REFERENCES public.products(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT transaction_items_expense_account_fk
        FOREIGN KEY (company_id, expense_account_id)
        REFERENCES public.accounts(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT transaction_items_unit_fk
        FOREIGN KEY (company_id, unit_of_measure_id)
        REFERENCES public.unit_of_measures(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT transaction_items_type_check
        CHECK (
            (
                item_type = 'product'
                AND product_id IS NOT NULL
                AND unit_of_measure_id IS NOT NULL
                AND expense_account_id IS NULL
            )
            OR
            (
                item_type = 'expense'
                AND product_id IS NULL
                AND unit_of_measure_id IS NULL
                AND expense_account_id IS NOT NULL
            )
        ),

    CONSTRAINT transaction_items_quantity_positive
        CHECK (quantity > 0),

    CONSTRAINT transaction_items_price_nonnegative
        CHECK (unit_price >= 0),

    CONSTRAINT transaction_items_discount_check
        CHECK (
            discount_amount >= 0
            AND discount_amount <= ROUND(quantity * unit_price, 2)
        ),

    CONSTRAINT transaction_items_tax_nonnegative
        CHECK (tax_amount >= 0),

    CONSTRAINT transaction_items_total_nonnegative
        CHECK (
            ROUND(quantity * unit_price, 2)
            - discount_amount
            + tax_amount >= 0
        ),

    CONSTRAINT transaction_items_line_number_positive
        CHECK (line_number > 0)
);

CREATE INDEX idx_transaction_items_transaction
ON public.transaction_items(company_id, transaction_id);

CREATE INDEX idx_transaction_items_product
ON public.transaction_items(company_id, product_id);

CREATE INDEX idx_transaction_items_expense_account
ON public.transaction_items(company_id, expense_account_id);