CREATE OR REPLACE FUNCTION public.record_inventory_movement(
    p_company_id UUID,
    p_product_id UUID,
    p_movement_type TEXT,
    p_movement_date DATE,
    p_quantity NUMERIC,
    p_unit_cost NUMERIC,
    p_notes TEXT DEFAULT NULL,
    p_created_by UUID DEFAULT NULL
)
RETURNS public.inventory_movements
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    v_current_quantity NUMERIC(15, 4);
    v_movement public.inventory_movements;
BEGIN
    IF p_movement_type NOT IN ('opening_stock', 'adjustment_in', 'adjustment_out') THEN
        RAISE EXCEPTION 'Unsupported standalone inventory movement type.';
    END IF;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero.';
    END IF;

    IF p_unit_cost IS NULL OR p_unit_cost < 0 THEN
        RAISE EXCEPTION 'Unit cost cannot be negative.';
    END IF;

    PERFORM 1
    FROM public.products
    WHERE company_id = p_company_id
      AND id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found for this company.';
    END IF;

    SELECT COALESCE(SUM(
        CASE
            WHEN movement_type IN ('opening_stock', 'purchase', 'adjustment_in')
                THEN quantity
            WHEN movement_type IN ('sale', 'adjustment_out')
                THEN -quantity
            ELSE 0
        END
    ), 0)
    INTO v_current_quantity
    FROM public.inventory_movements
    WHERE company_id = p_company_id
      AND product_id = p_product_id;

    IF p_movement_type = 'opening_stock' AND v_current_quantity <> 0 THEN
        RAISE EXCEPTION 'Opening stock can only be recorded when current stock is zero.';
    END IF;

    IF p_movement_type = 'adjustment_out' AND p_quantity > v_current_quantity THEN
        RAISE EXCEPTION 'Adjustment would reduce stock below zero.';
    END IF;

    INSERT INTO public.inventory_movements (
        company_id,
        product_id,
        movement_type,
        movement_date,
        quantity,
        unit_cost,
        notes,
        created_by
    )
    VALUES (
        p_company_id,
        p_product_id,
        p_movement_type,
        COALESCE(p_movement_date, CURRENT_DATE),
        p_quantity,
        p_unit_cost,
        NULLIF(BTRIM(p_notes), ''),
        p_created_by
    )
    RETURNING * INTO v_movement;

    RETURN v_movement;
END;
$$;


CREATE OR REPLACE FUNCTION public.create_purchase_draft(
    p_company_id UUID,
    p_supplier_id UUID,
    p_transaction_number TEXT,
    p_transaction_date DATE,
    p_due_date DATE,
    p_reference_number TEXT,
    p_notes TEXT,
    p_items JSONB,
    p_created_by UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    v_transaction public.transactions;
    v_item JSONB;
    v_product public.products;
    v_unit public.unit_of_measures;
    v_line_number INTEGER := 0;
    v_quantity NUMERIC(15, 4);
    v_unit_price NUMERIC(15, 4);
    v_subtotal NUMERIC(15, 2) := 0;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.contacts
        WHERE company_id = p_company_id
          AND id = p_supplier_id
          AND is_supplier = TRUE
          AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'Select an active supplier belonging to this company.';
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
       OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'A purchase must contain at least one item.';
    END IF;

    INSERT INTO public.transactions (
        company_id,
        contact_id,
        transaction_number,
        transaction_type,
        transaction_date,
        due_date,
        reference_number,
        notes,
        status
    )
    VALUES (
        p_company_id,
        p_supplier_id,
        BTRIM(p_transaction_number),
        'purchase',
        p_transaction_date,
        p_due_date,
        NULLIF(BTRIM(p_reference_number), ''),
        NULLIF(BTRIM(p_notes), ''),
        'draft'
    )
    RETURNING * INTO v_transaction;

    FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
    LOOP
        v_line_number := v_line_number + 1;
        v_quantity := (v_item->>'quantity')::NUMERIC;
        v_unit_price := (v_item->>'unit_price')::NUMERIC;

        IF v_quantity <= 0 OR v_unit_price < 0 THEN
            RAISE EXCEPTION 'Item quantities must be positive and prices cannot be negative.';
        END IF;

        SELECT * INTO v_product
        FROM public.products
        WHERE company_id = p_company_id
          AND id = (v_item->>'product_id')::UUID
          AND is_active = TRUE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Each purchase item must reference an active product in this company.';
        END IF;

        SELECT * INTO v_unit
        FROM public.unit_of_measures
        WHERE company_id = p_company_id
          AND id = v_product.unit_of_measure_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'The product unit of measure could not be found.';
        END IF;

        INSERT INTO public.transaction_items (
            company_id,
            transaction_id,
            line_number,
            item_type,
            product_id,
            unit_of_measure_id,
            description,
            sku,
            unit_name,
            unit_abbreviation,
            quantity,
            unit_price
        )
        VALUES (
            p_company_id,
            v_transaction.id,
            v_line_number,
            'product',
            v_product.id,
            v_unit.id,
            v_product.name,
            v_product.sku,
            v_unit.name,
            v_unit.abbreviation,
            v_quantity,
            v_unit_price
        );

        v_subtotal := v_subtotal + ROUND(v_quantity * v_unit_price, 2);
    END LOOP;

    UPDATE public.transactions
    SET subtotal = v_subtotal
    WHERE company_id = p_company_id
      AND id = v_transaction.id
    RETURNING * INTO v_transaction;

    RETURN jsonb_build_object(
        'id', v_transaction.id,
        'company_id', v_transaction.company_id,
        'contact_id', v_transaction.contact_id,
        'transaction_number', v_transaction.transaction_number,
        'transaction_type', v_transaction.transaction_type,
        'transaction_date', v_transaction.transaction_date,
        'due_date', v_transaction.due_date,
        'status', v_transaction.status,
        'reference_number', v_transaction.reference_number,
        'notes', v_transaction.notes,
        'subtotal', v_transaction.subtotal,
        'total_amount', v_transaction.total_amount,
        'created_at', v_transaction.created_at
    );
END;
$$;


CREATE OR REPLACE FUNCTION public.post_purchase(
    p_company_id UUID,
    p_transaction_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    v_transaction public.transactions;
    v_item RECORD;
BEGIN
    SELECT * INTO v_transaction
    FROM public.transactions
    WHERE company_id = p_company_id
      AND id = p_transaction_id
      AND transaction_type = 'purchase'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Purchase not found.';
    END IF;

    IF v_transaction.status <> 'draft' THEN
        RAISE EXCEPTION 'Only draft purchases can be posted.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.transaction_items
        WHERE company_id = p_company_id
          AND transaction_id = p_transaction_id
    ) THEN
        RAISE EXCEPTION 'A purchase must contain at least one item before posting.';
    END IF;

    FOR v_item IN
        SELECT id, product_id, quantity, unit_price
        FROM public.transaction_items
        WHERE company_id = p_company_id
          AND transaction_id = p_transaction_id
          AND item_type = 'product'
        ORDER BY line_number
    LOOP
        INSERT INTO public.inventory_movements (
            company_id,
            product_id,
            transaction_id,
            transaction_item_id,
            movement_type,
            movement_date,
            quantity,
            unit_cost
        )
        VALUES (
            p_company_id,
            v_item.product_id,
            p_transaction_id,
            v_item.id,
            'purchase',
            v_transaction.transaction_date,
            v_item.quantity,
            v_item.unit_price
        );
    END LOOP;

    UPDATE public.transactions
    SET status = 'posted',
        posted_at = NOW()
    WHERE company_id = p_company_id
      AND id = p_transaction_id
    RETURNING * INTO v_transaction;

    RETURN jsonb_build_object(
        'id', v_transaction.id,
        'company_id', v_transaction.company_id,
        'contact_id', v_transaction.contact_id,
        'transaction_number', v_transaction.transaction_number,
        'transaction_type', v_transaction.transaction_type,
        'transaction_date', v_transaction.transaction_date,
        'due_date', v_transaction.due_date,
        'status', v_transaction.status,
        'subtotal', v_transaction.subtotal,
        'total_amount', v_transaction.total_amount,
        'posted_at', v_transaction.posted_at
    );
END;
$$;


REVOKE ALL ON FUNCTION public.record_inventory_movement(
    UUID, UUID, TEXT, DATE, NUMERIC, NUMERIC, TEXT, UUID
) FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION public.create_purchase_draft(
    UUID, UUID, TEXT, DATE, DATE, TEXT, TEXT, JSONB, UUID
) FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION public.post_purchase(UUID, UUID) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.record_inventory_movement(
    UUID, UUID, TEXT, DATE, NUMERIC, NUMERIC, TEXT, UUID
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.create_purchase_draft(
    UUID, UUID, TEXT, DATE, DATE, TEXT, TEXT, JSONB, UUID
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.post_purchase(UUID, UUID) TO authenticated;