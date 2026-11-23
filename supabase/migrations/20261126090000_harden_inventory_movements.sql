-- Prevent movement modification and deletion
CREATE OR REPLACE FUNCTION public.prevent_inventory_movement_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'Inventory movements are immutable. Record a correcting movement instead.';
END;
$$;

DROP TRIGGER IF EXISTS trg_inventory_movements_immutable
ON public.inventory_movements;

CREATE TRIGGER trg_inventory_movements_immutable
BEFORE UPDATE OR DELETE
ON public.inventory_movements
FOR EACH ROW
EXECUTE FUNCTION public.prevent_inventory_movement_mutation();

REVOKE UPDATE, DELETE
ON public.inventory_movements
FROM authenticated;


------------------------------------------------------------------------------------------------------------
-- Derive the creator from the authenticated session

CREATE OR REPLACE FUNCTION public.set_inventory_movement_creator()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    NEW.created_by := auth.uid();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_inventory_movement_creator
ON public.inventory_movements;

CREATE TRIGGER trg_set_inventory_movement_creator
BEFORE INSERT
ON public.inventory_movements
FOR EACH ROW
EXECUTE FUNCTION public.set_inventory_movement_creator();


------------------------------------------------------------------------------------------------------------
-- Replace the movement RPC signature

DROP FUNCTION IF EXISTS public.record_inventory_movement(
    UUID,
    UUID,
    TEXT,
    DATE,
    NUMERIC,
    NUMERIC,
    TEXT,
    UUID
);

CREATE OR REPLACE FUNCTION public.record_inventory_movement(
    p_company_id UUID,
    p_product_id UUID,
    p_movement_type TEXT,
    p_movement_date DATE,
    p_quantity NUMERIC,
    p_unit_cost NUMERIC,
    p_notes TEXT DEFAULT NULL
)
RETURNS public.inventory_movements
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    v_movement public.inventory_movements;
BEGIN
    IF p_movement_type NOT IN (
        'opening_stock',
        'adjustment_in',
        'adjustment_out'
    ) THEN
        RAISE EXCEPTION 'Unsupported standalone inventory movement type.';
    END IF;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero.';
    END IF;

    IF p_movement_type IN ('opening_stock', 'adjustment_in')
       AND (p_unit_cost IS NULL OR p_unit_cost < 0) THEN
        RAISE EXCEPTION 'Incoming inventory must have a valid unit cost.';
    END IF;

    PERFORM 1
    FROM public.products
    WHERE company_id = p_company_id
      AND id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found for this company.';
    END IF;

    IF p_movement_type = 'opening_stock'
       AND EXISTS (
           SELECT 1
           FROM public.inventory_movements
           WHERE company_id = p_company_id
             AND product_id = p_product_id
       ) THEN
        RAISE EXCEPTION
            'Opening stock can only be recorded before the first inventory movement.';
    END IF;

    INSERT INTO public.inventory_movements (
        company_id,
        product_id,
        movement_type,
        movement_date,
        quantity,
        unit_cost,
        notes
    )
    VALUES (
        p_company_id,
        p_product_id,
        p_movement_type,
        COALESCE(p_movement_date, CURRENT_DATE),
        p_quantity,
        COALESCE(p_unit_cost, 0),
        NULLIF(BTRIM(p_notes), '')
    )
    RETURNING * INTO v_movement;

    RETURN v_movement;
END;
$$;

REVOKE ALL ON FUNCTION public.record_inventory_movement(
    UUID, UUID, TEXT, DATE, NUMERIC, NUMERIC, TEXT
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.record_inventory_movement(
    UUID, UUID, TEXT, DATE, NUMERIC, NUMERIC, TEXT
) TO authenticated;