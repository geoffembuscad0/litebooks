CREATE TABLE public.journal_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    company_id UUID NOT NULL,
    journal_entry_id UUID NOT NULL,
    account_id UUID NOT NULL,

    line_number INTEGER NOT NULL,

    description TEXT,

    debit NUMERIC(15, 2) NOT NULL DEFAULT 0,
    credit NUMERIC(15, 2) NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT journal_lines_company_id_id_unique
        UNIQUE (company_id, id),

    CONSTRAINT journal_lines_number_unique
        UNIQUE (company_id, journal_entry_id, line_number),

    CONSTRAINT journal_lines_entry_fk
        FOREIGN KEY (company_id, journal_entry_id)
        REFERENCES public.journal_entries(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT journal_lines_account_fk
        FOREIGN KEY (company_id, account_id)
        REFERENCES public.accounts(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT journal_lines_debit_nonnegative
        CHECK (debit >= 0),

    CONSTRAINT journal_lines_credit_nonnegative
        CHECK (credit >= 0),

    CONSTRAINT journal_lines_debit_credit_check
        CHECK (
            (debit > 0 AND credit = 0)
            OR
            (credit > 0 AND debit = 0)
        ),

    CONSTRAINT journal_lines_number_positive
        CHECK (line_number > 0)
);


-- Indexes
CREATE INDEX idx_journal_lines_company_id
ON public.journal_lines(company_id);

CREATE INDEX idx_journal_lines_journal_entry
ON public.journal_lines(company_id, journal_entry_id);

CREATE INDEX idx_journal_lines_account
ON public.journal_lines(company_id, account_id);

-- Functions

CREATE OR REPLACE FUNCTION public.protect_posted_journal_lines()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    entry_status VARCHAR(20);
    target_company_id UUID;
    target_entry_id UUID;
BEGIN
    IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
        IF TG_OP = 'UPDATE'
           AND (
               OLD.company_id <> NEW.company_id
               OR OLD.journal_entry_id <> NEW.journal_entry_id
           )
        THEN
            RAISE EXCEPTION
                'Moving a journal line to another entry is not allowed.';
        END IF;

        target_company_id := OLD.company_id;
        target_entry_id := OLD.journal_entry_id;
    ELSE
        target_company_id := NEW.company_id;
        target_entry_id := NEW.journal_entry_id;
    END IF;

    SELECT status
    INTO entry_status
    FROM public.journal_entries
    WHERE company_id = target_company_id
      AND id = target_entry_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Journal entry not found.';
    END IF;

    IF entry_status <> 'draft' THEN
        RAISE EXCEPTION
            'Journal lines can only be modified while the journal entry is in draft status.';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_protect_posted_journal_lines
BEFORE INSERT OR UPDATE OR DELETE ON public.journal_lines
FOR EACH ROW
EXECUTE FUNCTION public.protect_posted_journal_lines();