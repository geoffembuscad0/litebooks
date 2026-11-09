

CREATE TABLE public.contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    company_id UUID NOT NULL
        REFERENCES public.companies(id)
        ON DELETE CASCADE,

    name VARCHAR(150) NOT NULL,

    contact_person VARCHAR(150),

    contact_type VARCHAR(20) NOT NULL DEFAULT 'business',

    is_customer BOOLEAN NOT NULL DEFAULT FALSE,
    is_supplier BOOLEAN NOT NULL DEFAULT FALSE,

    email VARCHAR(255),
    phone VARCHAR(30),
    tax_number VARCHAR(50),

    billing_address TEXT,
    shipping_address TEXT,

    notes TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT contacts_type_check
        CHECK (contact_type IN ('individual', 'business')),

    CONSTRAINT contacts_has_role_check
        CHECK (is_customer = TRUE OR is_supplier = TRUE),

    CONSTRAINT contacts_company_id_id_unique
        UNIQUE (company_id, id)
);

CREATE INDEX idx_contacts_company_id
ON public.contacts(company_id);

CREATE INDEX idx_contacts_company_name
ON public.contacts(company_id, name);

CREATE INDEX idx_contacts_company_customer
ON public.contacts(company_id, is_customer);

CREATE INDEX idx_contacts_company_supplier
ON public.contacts(company_id, is_supplier);