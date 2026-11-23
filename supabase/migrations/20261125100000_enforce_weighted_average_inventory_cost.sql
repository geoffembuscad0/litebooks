-- ============================================================
-- LiteBooks: Enforce Perpetual Weighted-Average Inventory Cost
-- ============================================================

-- ------------------------------------------------------------
-- 1. Recalculate historical outgoing movement costs
-- ------------------------------------------------------------
-- Process each product's movements chronologically.
-- Incoming movements retain their recorded unit cost.
-- Outgoing movements receive the weighted-average cost
-- immediately before the movement.
--
-- The migration intentionally fails if historical movements
-- reduce stock below zero. Correct those records before
-- applying this migration.
-- ------------------------------------------------------------

DO $$
DECLARE
    v_product RECORD;
    v_movement RECORD;

    v_stock_quantity NUMERIC(20, 6);
    v_inventory_value NUMERIC(20, 6);
    v_average_cost NUMERIC(15, 4);
BEGIN
    FOR v_product IN
        SELECT DISTINCT company_id, product_id
        FROM public.inventory_movements
        ORDER BY company_id, product_id
    LOOP
        v_stock_quantity := 0;
        v_inventory_value := 0;

        FOR v_movement IN
            SELECT
                id,
                movement_type,
                quantity,
                unit_cost
            FROM public.inventory_movements
            WHERE company_id = v_product.company_id
              AND product_id = v_product.product_id
            ORDER BY movement_date, created_at, id
            FOR UPDATE
        LOOP
            IF v_movement.movement_type IN (
                'opening_stock',
                'purchase',
                'adjustment_in'
            ) THEN

                v_stock_quantity :=
                    v_stock_quantity + v_movement.quantity;

                v_inventory_value :=
                    v_inventory_value
                    + (v_movement.quantity * v_movement.unit_cost);

            ELSIF v_movement.movement_type IN (
                'sale',
                'adjustment_out'
            ) THEN

                IF v_stock_quantity <= 0
                   OR v_movement.quantity > v_stock_quantity THEN

                    RAISE EXCEPTION
                        'Cannot recalculate product %. Historical movement % would cause negative stock.',
                        v_product.product_id,
                        v_movement.id;
                END IF;

                v_average_cost :=
                    ROUND(
                        v_inventory_value / v_stock_quantity,
                        4
                    );

                -- Replace the historical outgoing cost.
                UPDATE public.inventory_movements
                SET unit_cost = v_average_cost
                WHERE id = v_movement.id;

                v_inventory_value :=
                    v_inventory_value
                    - (v_movement.quantity * v_average_cost);

                v_stock_quantity :=
                    v_stock_quantity - v_movement.quantity;

                -- Avoid residual floating-point-like decimal
                -- differences when the stock quantity reaches zero.
                IF v_stock_quantity = 0 THEN
                    v_inventory_value := 0;
                END IF;

            END IF;
        END LOOP;
    END LOOP;
END;
$$;


-- ------------------------------------------------------------
-- 2. Create weighted-average costing trigger function
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.apply_weighted_average_inventory_cost()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_stock_quantity NUMERIC(20, 6);
    v_inventory_value NUMERIC(20, 6);
    v_average_cost NUMERIC(15, 4);
    v_latest_movement_date DATE;
BEGIN

    -- Lock the product record to serialize stock movements.
    PERFORM 1
    FROM public.products
    WHERE company_id = NEW.company_id
      AND id = NEW.product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found for this company.';
    END IF;


    -- Find the latest recorded movement date.
    SELECT MAX(movement_date)
    INTO v_latest_movement_date
    FROM public.inventory_movements
    WHERE company_id = NEW.company_id
      AND product_id = NEW.product_id;


    -- Prevent backdated movements from silently changing
    -- the cost of subsequent movements.
    IF v_latest_movement_date IS NOT NULL
       AND NEW.movement_date < v_latest_movement_date THEN

        RAISE EXCEPTION
            'Backdated inventory movements are not allowed. Latest movement date is %.',
            v_latest_movement_date;
    END IF;


    -- Calculate existing stock quantity and inventory value.
    SELECT
        COALESCE(
            SUM(
                CASE
                    WHEN movement_type IN (
                        'opening_stock',
                        'purchase',
                        'adjustment_in'
                    )
                    THEN quantity

                    WHEN movement_type IN (
                        'sale',
                        'adjustment_out'
                    )
                    THEN -quantity

                    ELSE 0
                END
            ),
            0
        ),

        COALESCE(
            SUM(
                CASE
                    WHEN movement_type IN (
                        'opening_stock',
                        'purchase',
                        'adjustment_in'
                    )
                    THEN quantity * unit_cost

                    WHEN movement_type IN (
                        'sale',
                        'adjustment_out'
                    )
                    THEN -(quantity * unit_cost)

                    ELSE 0
                END
            ),
            0
        )

    INTO
        v_stock_quantity,
        v_inventory_value

    FROM public.inventory_movements
    WHERE company_id = NEW.company_id
      AND product_id = NEW.product_id;


    -- --------------------------------------------------------
    -- 3. Incoming stock
    -- --------------------------------------------------------

    IF NEW.movement_type IN (
        'opening_stock',
        'purchase',
        'adjustment_in'
    ) THEN

        IF NEW.unit_cost IS NULL OR NEW.unit_cost < 0 THEN
            RAISE EXCEPTION
                'Incoming inventory must have a valid unit cost.';
        END IF;


    -- --------------------------------------------------------
    -- 4. Outgoing stock
    -- --------------------------------------------------------

    ELSIF NEW.movement_type IN (
        'sale',
        'adjustment_out'
    ) THEN

        IF v_stock_quantity <= 0 THEN
            RAISE EXCEPTION
                'Insufficient stock. No available inventory remains.';
        END IF;

        IF NEW.quantity > v_stock_quantity THEN
            RAISE EXCEPTION
                'Insufficient stock. Available quantity: %, requested quantity: %.',
                v_stock_quantity,
                NEW.quantity;
        END IF;

        -- Calculate the current weighted-average unit cost.
        v_average_cost :=
            ROUND(
                v_inventory_value / v_stock_quantity,
                4
            );

        -- Always override the supplied outgoing cost.
        -- The caller cannot choose the cost of outgoing stock.
        NEW.unit_cost := v_average_cost;

    ELSE

        RAISE EXCEPTION
            'Unsupported inventory movement type: %.',
            NEW.movement_type;

    END IF;

    RETURN NEW;
END;
$$;


-- ------------------------------------------------------------
-- 5. Attach trigger to inventory movements
-- ------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_apply_weighted_average_inventory_cost
ON public.inventory_movements;

CREATE TRIGGER trg_apply_weighted_average_inventory_cost
BEFORE INSERT ON public.inventory_movements
FOR EACH ROW
EXECUTE FUNCTION public.apply_weighted_average_inventory_cost();


-- ------------------------------------------------------------
-- 6. Update standalone inventory movement RPC
-- ------------------------------------------------------------

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
    v_movement public.inventory_movements;
BEGIN

    IF p_movement_type NOT IN (
        'opening_stock',
        'adjustment_in',
        'adjustment_out'
    ) THEN
        RAISE EXCEPTION
            'Unsupported standalone inventory movement type.';
    END IF;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION
            'Quantity must be greater than zero.';
    END IF;

    -- Only incoming movements require a supplied unit cost.
    -- Outgoing movements are automatically costed by the trigger.
    IF p_movement_type IN (
        'opening_stock',
        'adjustment_in'
    ) AND (p_unit_cost IS NULL OR p_unit_cost < 0) THEN

        RAISE EXCEPTION
            'Incoming inventory must have a valid unit cost.';
    END IF;


    -- Lock the product before checking its movement history.
    PERFORM 1
    FROM public.products
    WHERE company_id = p_company_id
      AND id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Product not found for this company.';
    END IF;


    -- Opening stock is permitted only once in the product's
    -- entire inventory movement history.
    IF p_movement_type = 'opening_stock'
       AND EXISTS (
            SELECT 1
            FROM public.inventory_movements
            WHERE company_id = p_company_id
              AND product_id = p_product_id
       ) THEN

        RAISE EXCEPTION
            'Opening stock can only be recorded before the first inventory movement. Use a stock adjustment instead.';
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

        -- The trigger calculates the actual outgoing cost.
        COALESCE(p_unit_cost, 0),

        NULLIF(BTRIM(p_notes), ''),
        p_created_by
    )
    RETURNING * INTO v_movement;

    RETURN v_movement;
END;
$$;


-- ------------------------------------------------------------
-- 7. Update purchase posting RPC
-- ------------------------------------------------------------

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
    v_product_id UUID;
BEGIN

    SELECT *
    INTO v_transaction
    FROM public.transactions
    WHERE company_id = p_company_id
      AND id = p_transaction_id
      AND transaction_type = 'purchase'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Purchase not found.';
    END IF;

    IF v_transaction.status <> 'draft' THEN
        RAISE EXCEPTION
            'Only draft purchases can be posted.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.transaction_items
        WHERE company_id = p_company_id
          AND transaction_id = p_transaction_id
          AND item_type = 'product'
    ) THEN
        RAISE EXCEPTION
            'A purchase must contain at least one product item before posting.';
    END IF;


    -- Lock all affected products in a consistent order.
    -- This helps prevent deadlocks when purchases contain
    -- multiple products.
    FOR v_product_id IN
        SELECT DISTINCT product_id
        FROM public.transaction_items
        WHERE company_id = p_company_id
          AND transaction_id = p_transaction_id
          AND item_type = 'product'
        ORDER BY product_id
    LOOP

        PERFORM 1
        FROM public.products
        WHERE company_id = p_company_id
          AND id = v_product_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'A purchase item references an invalid product.';
        END IF;

    END LOOP;


    -- Insert purchase movements.
    -- The inventory trigger retains purchase unit costs
    -- and updates the effective weighted-average cost.
    FOR v_item IN
        SELECT
            id,
            product_id,
            quantity,
            unit_price
        FROM public.transaction_items
        WHERE company_id = p_company_id
          AND transaction_id = p_transaction_id
          AND item_type = 'product'
        ORDER BY product_id, line_number
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


    -- Only mark the purchase as posted after every movement
    -- has been successfully recorded.
    UPDATE public.transactions
    SET
        status = 'posted',
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


-- ------------------------------------------------------------
-- 8. Inventory valuation RPC
-- ------------------------------------------------------------
-- Returns the current inventory carrying value using the
-- recorded weighted-average movement costs.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_inventory_valuation(
    p_company_id UUID
)
RETURNS NUMERIC(15, 2)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
    SELECT COALESCE(
        ROUND(
            SUM(
                CASE
                    WHEN movement_type IN (
                        'opening_stock',
                        'purchase',
                        'adjustment_in'
                    )
                    THEN quantity * unit_cost

                    WHEN movement_type IN (
                        'sale',
                        'adjustment_out'
                    )
                    THEN -(quantity * unit_cost)

                    ELSE 0
                END
            ),
            2
        ),
        0
    )::NUMERIC(15, 2)
    FROM public.inventory_movements
    WHERE company_id = p_company_id;
$$;


-- ------------------------------------------------------------
-- 9. Function permissions
-- ------------------------------------------------------------

REVOKE ALL ON FUNCTION public.apply_weighted_average_inventory_cost()
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.record_inventory_movement(
    UUID, UUID, TEXT, DATE, NUMERIC, NUMERIC, TEXT, UUID
) FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION public.post_purchase(UUID, UUID)
FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION public.get_inventory_valuation(UUID)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.record_inventory_movement(
    UUID, UUID, TEXT, DATE, NUMERIC, NUMERIC, TEXT, UUID
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.post_purchase(UUID, UUID)
TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_inventory_valuation(UUID)
TO authenticated;