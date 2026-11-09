CREATE TABLE public.unit_of_measures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    company_id UUID NOT NULL
        REFERENCES public.companies(id)
        ON DELETE CASCADE,

    name VARCHAR(50) NOT NULL,
    abbreviation VARCHAR(15) NOT NULL,
    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unit_of_measures_company_id_id_unique
        UNIQUE (company_id, id)
);

-- Prevent duplicate unit names within a company.
CREATE UNIQUE INDEX unit_of_measures_company_name_unique
ON public.unit_of_measures (company_id, LOWER(name));

-- Prevent duplicate abbreviations within a company.
CREATE UNIQUE INDEX unit_of_measures_company_abbreviation_unique
ON public.unit_of_measures (company_id, LOWER(abbreviation));

CREATE INDEX idx_unit_of_measures_company_id
ON public.unit_of_measures(company_id);