-- Ensure transaction items can be referenced using
-- their company, transaction, and item IDs together.
ALTER TABLE public.transaction_items
ADD CONSTRAINT transaction_items_company_transaction_id_unique
UNIQUE (company_id, transaction_id, id);


-- Create inventory movements table.
CREATE TABLE public.inventory_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    company_id UUID NOT NULL,
    product_id UUID NOT NULL,

    transaction_id UUID,
    transaction_item_id UUID,

    movement_type VARCHAR(30) NOT NULL,

    movement_date DATE NOT NULL DEFAULT CURRENT_DATE,

    quantity NUMERIC(15, 4) NOT NULL,

    unit_cost NUMERIC(15, 4) NOT NULL DEFAULT 0,

    total_cost NUMERIC(15, 2)
        GENERATED ALWAYS AS (
            ROUND(quantity * unit_cost, 2)
        ) STORED,

    reference_number VARCHAR(100),
    notes TEXT,

    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Composite key for company-scoped relationships.
    CONSTRAINT inventory_movements_company_id_id_unique
        UNIQUE (company_id, id),

    -- Product must belong to the same company.
    CONSTRAINT inventory_movements_product_fk
        FOREIGN KEY (company_id, product_id)
        REFERENCES public.products(company_id, id)
        ON DELETE RESTRICT,

    -- Transaction item must belong to the same company
    -- and the same transaction.
    CONSTRAINT inventory_movements_transaction_item_fk
        FOREIGN KEY (company_id, transaction_id, transaction_item_id)
        REFERENCES public.transaction_items(
            company_id,
            transaction_id,
            id
        )
        ON DELETE RESTRICT,

    -- Allowed movement types.
    CONSTRAINT inventory_movements_type_check
        CHECK (
            movement_type IN (
                'opening_stock',
                'purchase',
                'sale',
                'adjustment_in',
                'adjustment_out'
            )
        ),

    -- Quantity must always be positive.
    CONSTRAINT inventory_movements_quantity_positive
        CHECK (quantity > 0),

    -- Unit cost cannot be negative.
    CONSTRAINT inventory_movements_unit_cost_nonnegative
        CHECK (unit_cost >= 0),

    -- Purchase and sale movements must reference
    -- a transaction and transaction item.
    -- Opening stock and adjustments are standalone movements.
    CONSTRAINT inventory_movements_source_check
        CHECK (
            (
                movement_type IN ('purchase', 'sale')
                AND transaction_id IS NOT NULL
                AND transaction_item_id IS NOT NULL
            )
            OR
            (
                movement_type IN (
                    'opening_stock',
                    'adjustment_in',
                    'adjustment_out'
                )
                AND transaction_id IS NULL
                AND transaction_item_id IS NULL
            )
        )
);


-- Prevent duplicate stock movements for the same transaction item.
CREATE UNIQUE INDEX inventory_movements_transaction_item_unique
ON public.inventory_movements(company_id, transaction_item_id)
WHERE transaction_item_id IS NOT NULL;


-- Indexes for inventory queries and reports.
CREATE INDEX idx_inventory_movements_company_id
ON public.inventory_movements(company_id);

CREATE INDEX idx_inventory_movements_product
ON public.inventory_movements(company_id, product_id);

CREATE INDEX idx_inventory_movements_date
ON public.inventory_movements(company_id, movement_date);

CREATE INDEX idx_inventory_movements_type
ON public.inventory_movements(company_id, movement_type);

CREATE INDEX idx_inventory_movements_transaction
ON public.inventory_movements(company_id, transaction_id);