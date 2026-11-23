-- Issue #6: Balance Sheet from posted accounting data.
-- Current fiscal-year earnings are presented within equity; prior-period
-- earnings are expected to be reflected in the retained earnings account.

CREATE OR REPLACE FUNCTION public.get_balance_sheet(
    p_company_id UUID,
    p_as_of DATE
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
    WITH company_period AS (
        SELECT
            c.fiscal_year_start,
            make_date(
                EXTRACT(YEAR FROM p_as_of)::INTEGER
                    - CASE
                        WHEN EXTRACT(MONTH FROM p_as_of)::INTEGER < c.fiscal_year_start THEN 1
                        ELSE 0
                      END,
                c.fiscal_year_start,
                1
            ) AS fiscal_year_start_date
        FROM public.companies c
        WHERE c.id = p_company_id
    ), account_totals AS (
        SELECT
            a.id AS account_id,
            a.account_code,
            a.account_name,
            a.account_type,
            a.normal_balance,
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
         AND je.entry_date <= p_as_of
        WHERE a.company_id = p_company_id
          AND a.account_type IN ('asset', 'liability', 'equity')
        GROUP BY a.id, a.account_code, a.account_name, a.account_type, a.normal_balance
    ), income_activity AS (
        SELECT
            COALESCE(SUM(
                CASE
                    WHEN a.account_type = 'revenue' THEN jl.credit - jl.debit
                    WHEN a.account_type = 'expense' THEN -(jl.debit - jl.credit)
                    ELSE 0
                END
            ), 0)::NUMERIC(15, 2) AS net_income
        FROM public.journal_entries je
        JOIN public.journal_lines jl
          ON jl.company_id = je.company_id
         AND jl.journal_entry_id = je.id
        JOIN public.accounts a
          ON a.company_id = jl.company_id
         AND a.id = jl.account_id
        CROSS JOIN company_period cp
        WHERE je.company_id = p_company_id
          AND je.status = 'posted'
          AND je.entry_date BETWEEN cp.fiscal_year_start_date AND p_as_of
          AND a.account_type IN ('revenue', 'expense')
    ), equity_rows AS (
        SELECT account_id, account_code, account_name, balance
        FROM account_totals
        WHERE account_type = 'equity'
        UNION ALL
        SELECT
            NULL::UUID AS account_id,
            'CURRENT'::VARCHAR AS account_code,
            'Current fiscal-year earnings'::VARCHAR AS account_name,
            net_income AS balance
        FROM income_activity
    ), section_totals AS (
        SELECT
            COALESCE((SELECT SUM(balance) FROM account_totals WHERE account_type = 'asset'), 0)::NUMERIC(15, 2) AS total_assets,
            COALESCE((SELECT SUM(balance) FROM account_totals WHERE account_type = 'liability'), 0)::NUMERIC(15, 2) AS total_liabilities,
            COALESCE((SELECT SUM(balance) FROM equity_rows), 0)::NUMERIC(15, 2) AS total_equity,
            (SELECT net_income FROM income_activity) AS current_net_income
    )
    SELECT jsonb_build_object(
        'as_of', p_as_of,
        'fiscal_year_start', (SELECT fiscal_year_start_date FROM company_period),
        'assets', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'account_id', account_id,
                'account_code', account_code,
                'account_name', account_name,
                'balance', balance
            ) ORDER BY account_code)
            FROM account_totals WHERE account_type = 'asset'
        ), '[]'::jsonb),
        'liabilities', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'account_id', account_id,
                'account_code', account_code,
                'account_name', account_name,
                'balance', balance
            ) ORDER BY account_code)
            FROM account_totals WHERE account_type = 'liability'
        ), '[]'::jsonb),
        'equity', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'account_id', account_id,
                'account_code', account_code,
                'account_name', account_name,
                'balance', balance
            ) ORDER BY account_code)
            FROM equity_rows
        ), '[]'::jsonb),
        'current_net_income', section_totals.current_net_income,
        'total_assets', section_totals.total_assets,
        'total_liabilities', section_totals.total_liabilities,
        'total_equity', section_totals.total_equity,
        'total_liabilities_and_equity', section_totals.total_liabilities + section_totals.total_equity,
        'balance_difference', section_totals.total_assets - section_totals.total_liabilities - section_totals.total_equity
    )
    FROM section_totals;
$$;

REVOKE ALL ON FUNCTION public.get_balance_sheet(UUID, DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_balance_sheet(UUID, DATE) TO authenticated;
