-- Issue #5: Trial Balance and Profit & Loss from posted journal entries.

CREATE OR REPLACE FUNCTION public.get_trial_balance(
    p_company_id UUID,
    p_as_of DATE
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
    WITH account_totals AS (
        SELECT
            a.id AS account_id,
            a.account_code,
            a.account_name,
            a.account_type,
            a.normal_balance,
            COALESCE(SUM(jl.debit), 0)::NUMERIC(15, 2) AS debit_total,
            COALESCE(SUM(jl.credit), 0)::NUMERIC(15, 2) AS credit_total
        FROM public.accounts a
        LEFT JOIN public.journal_lines jl
          ON jl.company_id = a.company_id
         AND jl.account_id = a.id
        LEFT JOIN public.journal_entries je
          ON je.company_id = jl.company_id
         AND je.id = jl.journal_entry_id
         AND je.status = 'posted'
         AND je.entry_date <= p_as_of
        WHERE a.company_id = p_company_id
        GROUP BY a.id, a.account_code, a.account_name, a.account_type, a.normal_balance
    ), balances AS (
        SELECT *,
            GREATEST(debit_total - credit_total, 0)::NUMERIC(15,2) AS debit_balance,
            GREATEST(credit_total - debit_total, 0)::NUMERIC(15,2) AS credit_balance
        FROM account_totals
    )
    SELECT jsonb_build_object(
        'as_of', p_as_of,
        'rows', COALESCE((
            SELECT jsonb_agg(to_jsonb(b) ORDER BY b.account_code)
            FROM balances b
        ), '[]'::jsonb),
        'totals', jsonb_build_object(
            'debit_total', COALESCE((SELECT SUM(debit_total) FROM balances), 0),
            'credit_total', COALESCE((SELECT SUM(credit_total) FROM balances), 0),
            'debit_balance', COALESCE((SELECT SUM(debit_balance) FROM balances), 0),
            'credit_balance', COALESCE((SELECT SUM(credit_balance) FROM balances), 0)
        )
    );
$$;

CREATE OR REPLACE FUNCTION public.get_profit_and_loss(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
    WITH account_totals AS (
        SELECT
            a.id AS account_id,
            a.account_code,
            a.account_name,
            a.account_type,
            COALESCE(SUM(jl.debit), 0)::NUMERIC(15, 2) AS debit_total,
            COALESCE(SUM(jl.credit), 0)::NUMERIC(15, 2) AS credit_total,
            CASE
                WHEN a.account_type = 'revenue'
                    THEN COALESCE(SUM(jl.credit - jl.debit), 0)
                ELSE COALESCE(SUM(jl.debit - jl.credit), 0)
            END::NUMERIC(15, 2) AS amount
        FROM public.accounts a
        LEFT JOIN public.journal_lines jl
          ON jl.company_id = a.company_id
         AND jl.account_id = a.id
        LEFT JOIN public.journal_entries je
          ON je.company_id = jl.company_id
         AND je.id = jl.journal_entry_id
         AND je.status = 'posted'
         AND je.entry_date BETWEEN p_start_date AND p_end_date
        WHERE a.company_id = p_company_id
          AND a.account_type IN ('revenue', 'expense')
        GROUP BY a.id, a.account_code, a.account_name, a.account_type
    ), revenues AS (
        SELECT * FROM account_totals WHERE account_type = 'revenue'
    ), expenses AS (
        SELECT * FROM account_totals WHERE account_type = 'expense'
    )
    SELECT jsonb_build_object(
        'start_date', p_start_date,
        'end_date', p_end_date,
        'revenue', COALESCE((SELECT SUM(amount) FROM revenues), 0),
        'expenses', COALESCE((SELECT SUM(amount) FROM expenses), 0),
        'net_income', COALESCE((SELECT SUM(amount) FROM revenues), 0)
                    - COALESCE((SELECT SUM(amount) FROM expenses), 0),
        'revenues', COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.account_code) FROM revenues r), '[]'::jsonb),
        'expense_accounts', COALESCE((SELECT jsonb_agg(to_jsonb(e) ORDER BY e.account_code) FROM expenses e), '[]'::jsonb)
    );
$$;

REVOKE ALL ON FUNCTION public.get_trial_balance(UUID, DATE) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_profit_and_loss(UUID, DATE, DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_trial_balance(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_profit_and_loss(UUID, DATE, DATE) TO authenticated;
