CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    company_id UUID NOT NULL
        REFERENCES public.companies(id)
        ON DELETE CASCADE,

    category_id UUID,

    unit_of_measure_id UUID NOT NULL,

    sku VARCHAR(100),
    barcode VARCHAR(100),

    name VARCHAR(150) NOT NULL,
    description TEXT,

    default_cost NUMERIC(15, 4) NOT NULL DEFAULT 0,
    selling_price NUMERIC(15, 2) NOT NULL DEFAULT 0,

    reorder_level NUMERIC(15, 4) NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT products_category_company_fk
        FOREIGN KEY (company_id, category_id)
        REFERENCES public.categories(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT products_unit_company_fk
        FOREIGN KEY (company_id, unit_of_measure_id)
        REFERENCES public.unit_of_measures(company_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT products_default_cost_nonnegative
        CHECK (default_cost >= 0),

    CONSTRAINT products_selling_price_nonnegative
        CHECK (selling_price >= 0),

    CONSTRAINT products_reorder_level_nonnegative
        CHECK (reorder_level >= 0)
);

-- SKU must be unique within the same company.
CREATE UNIQUE INDEX products_company_sku_unique
ON public.products (company_id, LOWER(sku))
WHERE sku IS NOT NULL;

-- Barcode must be unique within the same company.
CREATE UNIQUE INDEX products_company_barcode_unique
ON public.products (company_id, barcode)
WHERE barcode IS NOT NULL;

CREATE INDEX idx_products_company_id
ON public.products(company_id);

CREATE INDEX idx_products_category_id
ON public.products(company_id, category_id);

CREATE INDEX idx_products_unit_of_measure_id
ON public.products(company_id, unit_of_measure_id);

CREATE INDEX idx_products_name
ON public.products(company_id, name);