-- ============================================
-- Default Chart of Accounts for every company
-- ============================================

CREATE OR REPLACE FUNCTION public.seed_default_chart_of_accounts(p_company_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.accounts
        (company_id, account_code, account_name, account_type,
         account_subtype, normal_balance, is_system_account)
    VALUES
        -- Assets
        (p_company_id, '1010', 'Cash on Hand',              'asset',     'cash',                'debit',  TRUE),
        (p_company_id, '1020', 'Cash in Bank',              'asset',     'bank',                'debit',  TRUE),
        (p_company_id, '1100', 'Accounts Receivable',       'asset',     'receivable',          'debit',  TRUE),
        (p_company_id, '1200', 'Inventory',                 'asset',     'inventory',           'debit',  TRUE),

        -- Liabilities
        (p_company_id, '2010', 'Accounts Payable',          'liability', 'payable',             'credit', TRUE),
        (p_company_id, '2100', 'Loans Payable',             'liability', 'loan',                'credit', FALSE),

        -- Equity
        (p_company_id, '3010', 'Owner''s Capital',          'equity',    'capital',             'credit', TRUE),
        (p_company_id, '3020', 'Owner''s Drawings',         'equity',    'drawings',            'debit',  FALSE),
        (p_company_id, '3030', 'Retained Earnings',         'equity',    'retained_earnings',   'credit', TRUE),

        -- Revenue
        (p_company_id, '4010', 'Sales Revenue',             'revenue',   'sales',               'credit', TRUE),
        (p_company_id, '4020', 'Service Revenue',           'revenue',   'service',             'credit', FALSE),

        -- Cost of goods sold
        (p_company_id, '5010', 'Cost of Goods Sold',        'expense',   'cost_of_goods_sold',  'debit',  TRUE),

        -- Operating expenses
        (p_company_id, '6010', 'Rent Expense',              'expense',   'operating',           'debit',  FALSE),
        (p_company_id, '6020', 'Utilities Expense',         'expense',   'operating',           'debit',  FALSE),
        (p_company_id, '6030', 'Salaries and Wages',        'expense',   'operating',           'debit',  FALSE),
        (p_company_id, '6040', 'Internet and Communication','expense',   'operating',           'debit',  FALSE),
        (p_company_id, '6050', 'Office Supplies Expense',   'expense',   'operating',           'debit',  FALSE),
        (p_company_id, '6060', 'Inventory Adjustment Loss', 'expense',   'inventory_adjustment','debit',  TRUE),
        (p_company_id, '6090', 'Miscellaneous Expense',     'expense',   'operating',           'debit',  FALSE)
    ON CONFLICT (company_id, account_code) DO NOTHING;
END;
$$;

-- Trigger function: runs automatically when a company is created.
CREATE OR REPLACE FUNCTION public.trg_seed_company_defaults()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM public.seed_default_chart_of_accounts(NEW.id);
    RETURN NEW;
END;
$$;

-- These run with elevated rights, so users must not call them directly.
REVOKE ALL ON FUNCTION public.seed_default_chart_of_accounts(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trg_seed_company_defaults() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_companies_seed_defaults ON public.companies;

CREATE TRIGGER trg_companies_seed_defaults
AFTER INSERT ON public.companies
FOR EACH ROW
EXECUTE FUNCTION public.trg_seed_company_defaults();

-- Backfill companies that already exist (safe to re-run).
SELECT public.seed_default_chart_of_accounts(id) FROM public.companies;