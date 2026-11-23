-- Wednesday accounting: derive balances from posted journal lines and
-- create journal entries when supported business transactions are posted.

CREATE OR REPLACE VIEW public.account_balances
WITH (security_invoker = true)
AS
SELECT
    a.company_id,
    a.id AS account_id,
    a.account_code,
    a.account_name,
    a.account_type,
    a.account_subtype,
    a.normal_balance,
    a.is_active,
    COALESCE(SUM(jl.debit), 0)::NUMERIC(15, 2) AS debit_total,
    COALESCE(SUM(jl.credit), 0)::NUMERIC(15, 2) AS credit_total,
    CASE
        WHEN a.normal_balance = 'debit'
            THEN COALESCE(SUM(jl.debit - jl.credit), 0)
        ELSE COALESCE(SUM(jl.credit - jl.debit), 0)
    END::NUMERIC(15, 2) AS balance
FROM public.accounts a
LEFT JOIN public.journal_lines jl
  ON jl.company_id = a.company_id
 AND jl.account_id = a.id
LEFT JOIN public.journal_entries je
  ON je.company_id = jl.company_id
 AND je.id = jl.journal_entry_id
 AND je.status = 'posted'
WHERE jl.id IS NULL OR je.id IS NOT NULL
GROUP BY
    a.company_id, a.id, a.account_code, a.account_name,
    a.account_type, a.account_subtype, a.normal_balance, a.is_active;

GRANT SELECT ON public.account_balances TO authenticated;

CREATE OR REPLACE FUNCTION public.create_transaction_journal_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inventory UUID;
    v_payable UUID;
    v_receivable UUID;
    v_sales UUID;
    v_expense UUID;
    v_cash UUID;
    v_cogs UUID;
    v_journal_id UUID;
    v_amount NUMERIC(15, 2);
    v_cogs_amount NUMERIC(15, 2) := 0;
    v_line INTEGER := 0;
BEGIN
    IF NEW.status <> 'posted' OR (TG_OP = 'UPDATE' AND OLD.status = 'posted') THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.journal_entries
        WHERE company_id = NEW.company_id AND transaction_id = NEW.id
    ) THEN
        RAISE EXCEPTION 'This transaction already has a journal entry.';
    END IF;

    v_amount := NEW.total_amount;
    IF v_amount IS NULL OR v_amount <= 0 THEN
        RAISE EXCEPTION 'A posted transaction must have a positive total.';
    END IF;

    SELECT id INTO v_inventory FROM public.accounts
    WHERE company_id = NEW.company_id AND is_active
      AND account_subtype = 'inventory' LIMIT 1;
    SELECT id INTO v_payable FROM public.accounts
    WHERE company_id = NEW.company_id AND is_active
      AND account_subtype = 'payable' LIMIT 1;
    SELECT id INTO v_receivable FROM public.accounts
    WHERE company_id = NEW.company_id AND is_active
      AND account_subtype = 'receivable' LIMIT 1;
    SELECT id INTO v_sales FROM public.accounts
    WHERE company_id = NEW.company_id AND is_active
      AND account_subtype = 'sales' LIMIT 1;
    SELECT id INTO v_expense FROM public.accounts
    WHERE company_id = NEW.company_id AND is_active
      AND account_subtype = 'operating' LIMIT 1;
    SELECT id INTO v_cash FROM public.accounts
    WHERE company_id = NEW.company_id AND is_active
      AND account_subtype = 'cash' LIMIT 1;
    SELECT id INTO v_cogs FROM public.accounts
    WHERE company_id = NEW.company_id AND is_active
      AND account_subtype = 'cost_of_goods_sold' LIMIT 1;

    INSERT INTO public.journal_entries (
        company_id, entry_number, entry_date, description, reference_number,
        source_type, transaction_id, status, created_by, posted_by, posted_at
    ) VALUES (
        NEW.company_id, 'TX-' || NEW.transaction_number, NEW.transaction_date,
        INITCAP(NEW.transaction_type) || ' ' || NEW.transaction_number,
        NEW.reference_number, 'transaction', NEW.id, 'draft',
        auth.uid(), auth.uid(), NOW()
    ) RETURNING id INTO v_journal_id;

    IF NEW.transaction_type = 'purchase' THEN
        IF v_inventory IS NULL OR v_payable IS NULL THEN
            RAISE EXCEPTION 'Active Inventory and Accounts Payable accounts are required.';
        END IF;
        v_line := v_line + 1;
        INSERT INTO public.journal_lines (company_id, journal_entry_id, account_id, line_number, description, debit, credit)
        VALUES (NEW.company_id, v_journal_id, v_inventory, v_line, 'Inventory acquired', v_amount, 0);
        v_line := v_line + 1;
        INSERT INTO public.journal_lines (company_id, journal_entry_id, account_id, line_number, description, debit, credit)
        VALUES (NEW.company_id, v_journal_id, v_payable, v_line, 'Supplier payable', 0, v_amount);

    ELSIF NEW.transaction_type = 'sale' THEN
        IF v_receivable IS NULL OR v_sales IS NULL THEN
            RAISE EXCEPTION 'Active Accounts Receivable and Sales Revenue accounts are required.';
        END IF;
        v_line := v_line + 1;
        INSERT INTO public.journal_lines (company_id, journal_entry_id, account_id, line_number, description, debit, credit)
        VALUES (NEW.company_id, v_journal_id, v_receivable, v_line, 'Customer receivable', v_amount, 0);
        v_line := v_line + 1;
        INSERT INTO public.journal_lines (company_id, journal_entry_id, account_id, line_number, description, debit, credit)
        VALUES (NEW.company_id, v_journal_id, v_sales, v_line, 'Sales revenue', 0, v_amount);

        SELECT COALESCE(ROUND(SUM(quantity * unit_cost), 2), 0)
        INTO v_cogs_amount
        FROM public.inventory_movements
        WHERE company_id = NEW.company_id
          AND transaction_id = NEW.id
          AND movement_type = 'sale';

        IF v_cogs_amount > 0 THEN
            IF v_inventory IS NULL OR v_cogs IS NULL THEN
                RAISE EXCEPTION 'Active Inventory and Cost of Goods Sold accounts are required.';
            END IF;
            v_line := v_line + 1;
            INSERT INTO public.journal_lines (company_id, journal_entry_id, account_id, line_number, description, debit, credit)
            VALUES (NEW.company_id, v_journal_id, v_cogs, v_line, 'Cost of goods sold', v_cogs_amount, 0);
            v_line := v_line + 1;
            INSERT INTO public.journal_lines (company_id, journal_entry_id, account_id, line_number, description, debit, credit)
            VALUES (NEW.company_id, v_journal_id, v_inventory, v_line, 'Inventory relieved', 0, v_cogs_amount);
        END IF;

    ELSIF NEW.transaction_type = 'expense' THEN
        IF v_expense IS NULL OR v_cash IS NULL THEN
            RAISE EXCEPTION 'Active expense and cash accounts are required.';
        END IF;
        v_line := v_line + 1;
        INSERT INTO public.journal_lines (company_id, journal_entry_id, account_id, line_number, description, debit, credit)
        VALUES (NEW.company_id, v_journal_id, v_expense, v_line, COALESCE(NULLIF(BTRIM(NEW.notes), ''), 'Business expense'), v_amount, 0);
        v_line := v_line + 1;
        INSERT INTO public.journal_lines (company_id, journal_entry_id, account_id, line_number, description, debit, credit)
        VALUES (NEW.company_id, v_journal_id, v_cash, v_line, 'Expense paid', 0, v_amount);
    ELSE
        RAISE EXCEPTION 'Unsupported transaction type for accounting integration.';
    END IF;

    UPDATE public.journal_entries
    SET status = 'posted', posted_by = auth.uid(), posted_at = NOW(), updated_at = NOW()
    WHERE company_id = NEW.company_id AND id = v_journal_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_transaction_journal_entry ON public.transactions;
CREATE TRIGGER trg_create_transaction_journal_entry
AFTER INSERT OR UPDATE OF status ON public.transactions
FOR EACH ROW
WHEN (NEW.status = 'posted')
EXECUTE FUNCTION public.create_transaction_journal_entry();

REVOKE ALL ON FUNCTION public.create_transaction_journal_entry() FROM PUBLIC, anon, authenticated;
