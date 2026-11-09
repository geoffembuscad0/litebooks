CREATE TABLE public.journal_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    company_id UUID NOT NULL
        REFERENCES public.companies(id)
        ON DELETE CASCADE,

    entry_number VARCHAR(50) NOT NULL,

    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,

    description TEXT NOT NULL,

    reference_number VARCHAR(100),

    source_type VARCHAR(30) NOT NULL DEFAULT 'manual',

    transaction_id UUID,
    payment_id UUID,
    inventory_movement_id UUID,

    status VARCHAR(20) NOT NULL DEFAULT 'draft',

    posted_at TIMESTAMPTZ,
    voided_at TIMESTAMPTZ,

    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    posted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT journal_entries_company_id_id_unique
        UNIQUE (company_id, id),

    CONSTRAINT journal_entries_number_unique
        UNIQUE (company_id, entry_number),

    CONSTRAINT journal_entries_transaction_fk
        FOREIGN KEY (company_id, transaction_id)
        REFERENCES public.transactions(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT journal_entries_payment_fk
        FOREIGN KEY (company_id, payment_id)
        REFERENCES public.payments(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT journal_entries_inventory_movement_fk
        FOREIGN KEY (company_id, inventory_movement_id)
        REFERENCES public.inventory_movements(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT journal_entries_source_type_check
        CHECK (
            source_type IN (
                'manual',
                'transaction',
                'payment',
                'inventory_movement'
            )
        ),

    CONSTRAINT journal_entries_source_check
        CHECK (
            (
                source_type = 'manual'
                AND transaction_id IS NULL
                AND payment_id IS NULL
                AND inventory_movement_id IS NULL
            )
            OR
            (
                source_type = 'transaction'
                AND transaction_id IS NOT NULL
                AND payment_id IS NULL
                AND inventory_movement_id IS NULL
            )
            OR
            (
                source_type = 'payment'
                AND transaction_id IS NULL
                AND payment_id IS NOT NULL
                AND inventory_movement_id IS NULL
            )
            OR
            (
                source_type = 'inventory_movement'
                AND transaction_id IS NULL
                AND payment_id IS NULL
                AND inventory_movement_id IS NOT NULL
            )
        ),

    CONSTRAINT journal_entries_status_check
        CHECK (status IN ('draft', 'posted', 'void'))
);


-- Indexes
CREATE INDEX idx_journal_entries_company_id
ON public.journal_entries(company_id);

CREATE INDEX idx_journal_entries_company_date
ON public.journal_entries(company_id, entry_date);

CREATE INDEX idx_journal_entries_company_status
ON public.journal_entries(company_id, status);

CREATE INDEX idx_journal_entries_transaction
ON public.journal_entries(company_id, transaction_id);

CREATE INDEX idx_journal_entries_payment
ON public.journal_entries(company_id, payment_id);

CREATE INDEX idx_journal_entries_inventory_movement
ON public.journal_entries(company_id, inventory_movement_id);


-- Prevent duplicate journal entries for the same source.
CREATE UNIQUE INDEX journal_entries_transaction_unique
ON public.journal_entries(company_id, transaction_id)
WHERE transaction_id IS NOT NULL;

CREATE UNIQUE INDEX journal_entries_payment_unique
ON public.journal_entries(company_id, payment_id)
WHERE payment_id IS NOT NULL;

CREATE UNIQUE INDEX journal_entries_inventory_movement_unique
ON public.journal_entries(company_id, inventory_movement_id)
WHERE inventory_movement_id IS NOT NULL;

--- FUUNCTIONS BELOW:
CREATE OR REPLACE FUNCTION public.validate_journal_entry_posting()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    total_debit NUMERIC(15, 2);
    total_credit NUMERIC(15, 2);
    line_count INTEGER;
BEGIN
    IF NEW.status = 'posted'
       AND (
           TG_OP = 'INSERT'
           OR OLD.status <> 'posted'
       )
    THEN
        SELECT
            COUNT(*),
            COALESCE(SUM(debit), 0),
            COALESCE(SUM(credit), 0)
        INTO
            line_count,
            total_debit,
            total_credit
        FROM public.journal_lines
        WHERE company_id = NEW.company_id
          AND journal_entry_id = NEW.id;

        IF line_count < 2 THEN
            RAISE EXCEPTION
                'A journal entry must contain at least two lines.';
        END IF;

        IF total_debit <> total_credit THEN
            RAISE EXCEPTION
                'Journal entry is not balanced. Debits: %, Credits: %',
                total_debit,
                total_credit;
        END IF;

        NEW.posted_at := COALESCE(NEW.posted_at, NOW());
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_validate_journal_entry_posting
BEFORE INSERT OR UPDATE ON public.journal_entries
FOR EACH ROW
EXECUTE FUNCTION public.validate_journal_entry_posting();

-- Headers forr Journal Entry Headers
CREATE OR REPLACE FUNCTION public.protect_posted_journal_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status <> 'draft' THEN
        RAISE EXCEPTION
            'Posted or void journal entries cannot be modified or deleted.';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_protect_posted_journal_entry
BEFORE UPDATE OR DELETE ON public.journal_entries
FOR EACH ROW
EXECUTE FUNCTION public.protect_posted_journal_entry();