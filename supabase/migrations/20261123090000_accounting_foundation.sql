-- Monday accounting foundation: chart of accounts and manual journals
-- Issue #2: Chart of accounts management; manual journal entries

ALTER TABLE public.accounts
    ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.journal_entries
    ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.journal_lines
    ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.accounts
    DROP CONSTRAINT IF EXISTS accounts_normal_balance_matches_type,
    ADD CONSTRAINT accounts_normal_balance_matches_type
    CHECK (
        (account_type IN ('asset', 'expense') AND normal_balance = 'debit')
        OR
        (account_type IN ('liability', 'equity', 'revenue') AND normal_balance = 'credit')
    );

CREATE OR REPLACE FUNCTION public.validate_account_parent()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    parent_company_id UUID;
    parent_type VARCHAR(20);
    parent_is_active BOOLEAN;
BEGIN
    IF NEW.parent_account_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.parent_account_id = NEW.id THEN
        RAISE EXCEPTION 'An account cannot be its own parent.';
    END IF;

    SELECT company_id, account_type, is_active
    INTO parent_company_id, parent_type, parent_is_active
    FROM public.accounts
    WHERE company_id = NEW.company_id
      AND id = NEW.parent_account_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Parent account not found in this company.';
    END IF;

    IF NOT parent_is_active THEN
        RAISE EXCEPTION 'The parent account must be active.';
    END IF;

    IF parent_type <> NEW.account_type THEN
        RAISE EXCEPTION 'The parent account must have the same account type.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_account_parent ON public.accounts;
CREATE TRIGGER trg_validate_account_parent
BEFORE INSERT OR UPDATE OF parent_account_id, account_type, company_id
ON public.accounts
FOR EACH ROW
EXECUTE FUNCTION public.validate_account_parent();

CREATE OR REPLACE FUNCTION public.validate_manual_journal_lines()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    entry_status VARCHAR(20);
    entry_source VARCHAR(30);
BEGIN
    SELECT status, source_type
    INTO entry_status, entry_source
    FROM public.journal_entries
    WHERE company_id = NEW.company_id
      AND id = NEW.journal_entry_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Journal entry not found.';
    END IF;

    IF entry_source <> 'manual' THEN
        RAISE EXCEPTION 'Only manual journal entries can be created through this workflow.';
    END IF;

    IF entry_status <> 'draft' THEN
        RAISE EXCEPTION 'Journal lines can only be maintained while the entry is draft.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.accounts
        WHERE company_id = NEW.company_id
          AND id = NEW.account_id
          AND is_active = FALSE
    ) THEN
        RAISE EXCEPTION 'Journal lines cannot use inactive accounts.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_manual_journal_lines ON public.journal_lines;
CREATE TRIGGER trg_validate_manual_journal_lines
BEFORE INSERT OR UPDATE ON public.journal_lines
FOR EACH ROW
EXECUTE FUNCTION public.validate_manual_journal_lines();

-- Audit trail for chart of accounts and journal mutations
CREATE TABLE IF NOT EXISTS public.accounting_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    entity_type VARCHAR(30) NOT NULL CHECK (entity_type IN ('account', 'journal_entry', 'journal_line')),
    entity_id UUID NOT NULL,
    action VARCHAR(20) NOT NULL,
    actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    previous_data JSONB,
    new_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_accounting_audit_company
ON public.accounting_audit_log(company_id, created_at DESC);

ALTER TABLE public.accounting_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS accounting_audit_owner_select ON public.accounting_audit_log;
CREATE POLICY accounting_audit_owner_select
ON public.accounting_audit_log
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.companies c
        WHERE c.id = accounting_audit_log.company_id
          AND c.owner_id = auth.uid()
    )
);

CREATE OR REPLACE FUNCTION public.log_account_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO public.accounting_audit_log
            (company_id, entity_type, entity_id, action, previous_data)
        VALUES
            (OLD.company_id, 'account', OLD.id, 'delete', to_jsonb(OLD));
        RETURN OLD;
    END IF;

    INSERT INTO public.accounting_audit_log
        (company_id, entity_type, entity_id, action, previous_data, new_data)
    VALUES
        (NEW.company_id, 'account', NEW.id,
         CASE WHEN TG_OP = 'INSERT' THEN 'create' ELSE 'update' END,
         CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
         to_jsonb(NEW));
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_account_audit ON public.accounts;
CREATE TRIGGER trg_account_audit
AFTER INSERT OR UPDATE OR DELETE ON public.accounts
FOR EACH ROW
EXECUTE FUNCTION public.log_account_change();

CREATE OR REPLACE FUNCTION public.log_journal_entry_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO public.accounting_audit_log
            (company_id, entity_type, entity_id, action, actor_id, previous_data)
        VALUES
            (OLD.company_id, 'journal_entry', OLD.id, 'delete', OLD.updated_by, to_jsonb(OLD));
        RETURN OLD;
    END IF;

    INSERT INTO public.accounting_audit_log
        (company_id, entity_type, entity_id, action, actor_id, previous_data, new_data)
    VALUES
        (NEW.company_id, 'journal_entry', NEW.id,
         CASE WHEN TG_OP = 'INSERT' THEN 'create' ELSE 'update' END,
         COALESCE(NEW.updated_by, NEW.created_by),
         CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
         to_jsonb(NEW));
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_journal_entry_audit ON public.journal_entries;
CREATE TRIGGER trg_journal_entry_audit
AFTER INSERT OR UPDATE OR DELETE ON public.journal_entries
FOR EACH ROW
EXECUTE FUNCTION public.log_journal_entry_change();
