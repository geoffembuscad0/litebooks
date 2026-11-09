CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    company_id UUID NOT NULL
        REFERENCES public.companies(id)
        ON DELETE CASCADE,

    name VARCHAR(100) NOT NULL,
    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT categories_company_id_id_unique
        UNIQUE (company_id, id)
);

-- Prevent duplicate category names within the same company.
CREATE UNIQUE INDEX categories_company_name_unique
ON public.categories (company_id, LOWER(name));

-- Improve company-specific queries.
CREATE INDEX idx_categories_company_id
ON public.categories(company_id);