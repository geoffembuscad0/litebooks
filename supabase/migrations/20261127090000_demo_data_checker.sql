ALTER TABLE public.accounts
DROP CONSTRAINT IF EXISTS accounts_normal_balance_matches_type;

ALTER TABLE public.accounts
ADD CONSTRAINT accounts_normal_balance_matches_type
CHECK (
    (account_type IN ('asset', 'expense')
        AND normal_balance = 'debit')

    OR

    (account_type IN ('liability', 'revenue')
        AND normal_balance = 'credit')

    OR

    (
        account_type = 'equity'
        AND (
            (account_subtype = 'drawings'
                AND normal_balance = 'debit')
            OR
            (account_subtype IS DISTINCT FROM 'drawings'
                AND normal_balance = 'credit')
        )
    )
);