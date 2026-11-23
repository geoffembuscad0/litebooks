-- Helper: does the signed-in user own this company?
CREATE OR REPLACE FUNCTION public.is_company_owner(target_company_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.companies c
        WHERE c.id = target_company_id
          AND c.owner_id = (SELECT auth.uid())
    );
$$;

REVOKE ALL ON FUNCTION public.is_company_owner(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_company_owner(UUID) TO authenticated;

-- Make sure the tables that already have RLS are also granted
GRANT SELECT, INSERT, UPDATE ON public.companies TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;

-- RLS + grants for every company-owned table
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
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
    ]
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('DROP POLICY IF EXISTS "Owners manage company rows" ON public.%I', t);
        EXECUTE format(
            'CREATE POLICY "Owners manage company rows" ON public.%I
             FOR ALL TO authenticated
             USING (public.is_company_owner(company_id))
             WITH CHECK (public.is_company_owner(company_id))',
            t
        );
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated', t);
    END LOOP;
END $$;