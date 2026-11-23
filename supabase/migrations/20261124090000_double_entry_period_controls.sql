-- Issue #3: Double-entry validation and accounting period controls

CREATE TABLE IF NOT EXISTS public.accounting_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
    closed_at TIMESTAMPTZ,
    closed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT accounting_periods_company_id_id_unique UNIQUE (company_id, id),
    CONSTRAINT accounting_periods_valid_range CHECK (period_end >= period_start),
    CONSTRAINT accounting_periods_unique_range UNIQUE (company_id, period_start, period_end)
);

CREATE INDEX IF NOT EXISTS idx_accounting_periods_company
ON public.accounting_periods(company_id, period_start, period_end);

ALTER TABLE public.accounting_periods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS accounting_periods_owner_all ON public.accounting_periods;
CREATE POLICY accounting_periods_owner_all
ON public.accounting_periods
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.companies c
        WHERE c.id = accounting_periods.company_id
          AND c.owner_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.companies c
        WHERE c.id = accounting_periods.company_id
          AND c.owner_id = auth.uid()
    )
);

CREATE OR REPLACE FUNCTION public.ensure_journal_entry_period()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.accounting_periods p
        WHERE p.company_id = NEW.company_id
          AND NEW.entry_date BETWEEN p.period_start AND p.period_end
          AND p.status = 'closed'
    ) THEN
        RAISE EXCEPTION 'The accounting period for this entry date is closed.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ensure_journal_entry_period ON public.journal_entries;
CREATE TRIGGER trg_ensure_journal_entry_period
BEFORE INSERT OR UPDATE OF entry_date, company_id, status
ON public.journal_entries
FOR EACH ROW
EXECUTE FUNCTION public.ensure_journal_entry_period();

CREATE OR REPLACE FUNCTION public.validate_journal_entry_before_post()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    line_count INTEGER;
    debit_total NUMERIC(15,2);
    credit_total NUMERIC(15,2);
    account_count INTEGER;
BEGIN
    IF NEW.status = 'posted' AND (TG_OP = 'INSERT' OR OLD.status <> 'posted') THEN
        IF NEW.entry_date IS NULL THEN
            RAISE EXCEPTION 'A journal entry requires an entry date.';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM public.accounting_periods p
            WHERE p.company_id = NEW.company_id
              AND NEW.entry_date BETWEEN p.period_start AND p.period_end
              AND p.status = 'closed'
        ) THEN
            RAISE EXCEPTION 'Cannot post a journal entry into a closed accounting period.';
        END IF;

        SELECT COUNT(*), COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
        INTO line_count, debit_total, credit_total
        FROM public.journal_lines
        WHERE company_id = NEW.company_id
          AND journal_entry_id = NEW.id;

        IF line_count < 2 THEN
            RAISE EXCEPTION 'A journal entry must contain at least two lines.';
        END IF;

        IF debit_total <= 0 OR credit_total <= 0 THEN
            RAISE EXCEPTION 'A journal entry must contain both debit and credit lines.';
        END IF;

        IF debit_total <> credit_total THEN
            RAISE EXCEPTION 'Journal entry is not balanced: debit %, credit %.', debit_total, credit_total;
        END IF;

        SELECT COUNT(*)
        INTO account_count
        FROM public.journal_lines jl
        JOIN public.accounts a
          ON a.company_id = jl.company_id
         AND a.id = jl.account_id
        WHERE jl.company_id = NEW.company_id
          AND jl.journal_entry_id = NEW.id
          AND a.is_active = TRUE;

        IF account_count <> line_count THEN
            RAISE EXCEPTION 'Every journal line must use an active account.';
        END IF;

        NEW.posted_at := COALESCE(NEW.posted_at, NOW());
        NEW.updated_at := NOW();
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_journal_entry_posting ON public.journal_entries;
CREATE TRIGGER trg_validate_journal_entry_posting
BEFORE INSERT OR UPDATE OF status, entry_date, company_id
ON public.journal_entries
FOR EACH ROW
EXECUTE FUNCTION public.validate_journal_entry_before_post();

CREATE OR REPLACE FUNCTION public.close_accounting_period(
    p_company_id UUID,
    p_period_start DATE,
    p_period_end DATE,
    p_closed_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    period_id UUID;
BEGIN
    IF p_period_end < p_period_start THEN
        RAISE EXCEPTION 'The period end date cannot precede the period start date.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.journal_entries
        WHERE company_id = p_company_id
          AND entry_date BETWEEN p_period_start AND p_period_end
          AND status = 'draft'
    ) THEN
        RAISE EXCEPTION 'Draft journal entries exist in the period. Post or remove them before closing.';
    END IF;

    INSERT INTO public.accounting_periods
        (company_id, period_start, period_end, status, closed_at, closed_by)
    VALUES
        (p_company_id, p_period_start, p_period_end, 'closed', NOW(), p_closed_by)
    ON CONFLICT (company_id, period_start, period_end)
    DO UPDATE SET
        status = 'closed',
        closed_at = NOW(),
        closed_by = EXCLUDED.closed_by,
        updated_at = NOW()
    RETURNING id INTO period_id;

    INSERT INTO public.accounting_audit_log
        (company_id, entity_type, entity_id, action, actor_id, new_data)
    VALUES
        (p_company_id, 'journal_entry', period_id, 'close_period', p_closed_by,
         jsonb_build_object(
             'period_start', p_period_start,
             'period_end', p_period_end,
             'status', 'closed'
         ));

    RETURN jsonb_build_object(
        'id', period_id,
        'company_id', p_company_id,
        'period_start', p_period_start,
        'period_end', p_period_end,
        'status', 'closed'
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.reopen_accounting_period(
    p_company_id UUID,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    period_id UUID;
BEGIN
    UPDATE public.accounting_periods
    SET status = 'open', closed_at = NULL, closed_by = NULL, updated_at = NOW()
    WHERE company_id = p_company_id
      AND period_start = p_period_start
      AND period_end = p_period_end
    RETURNING id INTO period_id;

    IF period_id IS NULL THEN
        RAISE EXCEPTION 'Accounting period not found.';
    END IF;

    INSERT INTO public.accounting_audit_log
        (company_id, entity_type, entity_id, action, new_data)
    VALUES
        (p_company_id, 'journal_entry', period_id, 'reopen_period',
         jsonb_build_object(
             'period_start', p_period_start,
             'period_end', p_period_end,
             'status', 'open'
         ));

    RETURN jsonb_build_object(
        'id', period_id,
        'company_id', p_company_id,
        'period_start', p_period_start,
        'period_end', p_period_end,
        'status', 'open'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.close_accounting_period(UUID, DATE, DATE, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reopen_accounting_period(UUID, DATE, DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.close_accounting_period(UUID, DATE, DATE, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reopen_accounting_period(UUID, DATE, DATE) TO authenticated;
