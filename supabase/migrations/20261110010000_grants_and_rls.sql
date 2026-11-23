GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.profiles  TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.companies TO authenticated;

ALTER TABLE public.accounts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owners can view their accounts" ON public.accounts;
CREATE POLICY "Owners can view their accounts"
ON public.accounts FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.companies c
               WHERE c.id = accounts.company_id AND c.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Owners can view their transactions" ON public.transactions;
CREATE POLICY "Owners can view their transactions"
ON public.transactions FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.companies c
               WHERE c.id = transactions.company_id AND c.owner_id = auth.uid()));

GRANT SELECT ON public.accounts, public.transactions TO authenticated;