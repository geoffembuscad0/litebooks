-- ============================================
-- ROW LEVEL SECURITY for all company-owned tables
-- ============================================
-- Rule: a signed-in user may only touch rows whose company_id belongs
-- to a company they own. profiles and companies already have their own
-- policies (see earlier migrations).

-- Helper: does the current user own this company?
-- SECURITY DEFINER so the lookup on companies does not recurse through RLS.
CREATE OR REPLACE FUNCTION public.user_owns_company(p_company_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.companies c
        WHERE c.id = p_company_id
          AND c.owner_id = auth.uid()
    );
$$;

REVOKE ALL ON FUNCTION public.user_owns_company(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.user_owns_company(UUID) TO authenticated;

-- Enable RLS and create one policy per table.
DO $$
DECLARE
    t TEXT;
    company_tables TEXT[] := ARRAY[
        'categories',
        'unit_of_measures',
        'products',
        'contacts',
        'accounts',
        'transactions',
        'transaction_items',
        'payments',
        'inventory_movements',
        'journal_entries',
        'journal_lines'
    ];
BEGIN
    FOREACH t IN ARRAY company_tables LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);

        -- Signed-out (anon) visitors get no access at all.
        EXECUTE format('REVOKE ALL ON public.%I FROM anon', t);

        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I',
                       'Owners manage ' || t, t);

        EXECUTE format(
            'CREATE POLICY %I ON public.%I
             FOR ALL
             TO authenticated
             USING (public.user_owns_company(company_id))
             WITH CHECK (public.user_owns_company(company_id))',
            'Owners manage ' || t, t
        );
    END LOOP;
END;
$$;

-- Note: the immutability rules for posted journal entries/lines are
-- enforced by triggers, so FOR ALL is safe here. RLS decides WHO may
-- touch a row; the triggers decide WHEN.