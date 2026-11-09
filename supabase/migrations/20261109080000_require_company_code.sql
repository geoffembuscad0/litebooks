-- Create company codes as required onboarding data and enforce uniqueness
-- per owner without case-sensitive duplicates.
ALTER TABLE public.companies
    ALTER COLUMN company_code SET NOT NULL;

ALTER TABLE public.companies
    DROP CONSTRAINT IF EXISTS unique_owner_company_code;

ALTER TABLE public.companies
    ADD CONSTRAINT company_code_not_blank
    CHECK (length(btrim(company_code)) > 0);

CREATE UNIQUE INDEX companies_owner_company_code_unique
    ON public.companies (owner_id, lower(btrim(company_code)));
