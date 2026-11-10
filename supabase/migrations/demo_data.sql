-- ============================================================
-- LiteBooks DEMO DATA (not a migration - run manually)
-- ============================================================
-- How to use:
--   1. Apply the migrations first (RLS + default chart of accounts).
--   2. Change v_owner_email below to the email you registered with.
--   3. Paste this whole file into the Supabase SQL Editor and run it.
--
-- It creates a separate company "Demo Computer Trading" (code DEMO001)
-- under your account, so your real companies are never touched.
-- Dates are relative to the current month so the dashboard has data.
-- Safe to re-run: it does nothing if DEMO001 already exists.
-- To start over, delete the demo company's rows (see bottom of file).
-- ============================================================

-- Helper (session-only): create and post a balanced journal entry.
CREATE OR REPLACE FUNCTION pg_temp.post_je(
    p_company UUID, p_number TEXT, p_date DATE, p_desc TEXT,
    p_source TEXT, p_ref UUID, p_lines JSONB
) RETURNS VOID
LANGUAGE plpgsql AS $f$
DECLARE
    v_id UUID;
    v_n INTEGER := 0;
    l JSONB;
BEGIN
    INSERT INTO public.journal_entries
        (company_id, entry_number, entry_date, description, source_type,
         transaction_id, payment_id, inventory_movement_id)
    VALUES
        (p_company, p_number, p_date, p_desc, p_source,
         CASE WHEN p_source = 'transaction'        THEN p_ref END,
         CASE WHEN p_source = 'payment'            THEN p_ref END,
         CASE WHEN p_source = 'inventory_movement' THEN p_ref END)
    RETURNING id INTO v_id;

    FOR l IN SELECT * FROM jsonb_array_elements(p_lines) LOOP
        v_n := v_n + 1;
        INSERT INTO public.journal_lines
            (company_id, journal_entry_id, account_id, line_number, debit, credit)
        VALUES
            (p_company, v_id, (l->>'account')::UUID, v_n,
             COALESCE((l->>'debit')::NUMERIC, 0),
             COALESCE((l->>'credit')::NUMERIC, 0));
    END LOOP;

    -- Posting fires the "must balance" validation trigger.
    UPDATE public.journal_entries
    SET status = 'posted', posted_at = NOW()
    WHERE id = v_id;
END
$f$;


DO $$
DECLARE
    v_owner_email  CONSTANT TEXT := 'CHANGE_ME@example.com';   -- <<< EDIT THIS
    v_company_code CONSTANT TEXT := 'DEMO001';

    v_owner_id     UUID;
    v_company_id   UUID;
    v_month_start  DATE := date_trunc('month', current_date)::DATE;
    v_days_elapsed INTEGER := current_date - date_trunc('month', current_date)::DATE;

    a_cash UUID; a_bank UUID; a_ar UUID; a_inv UUID;
    a_ap UUID; a_capital UUID; a_sales UUID; a_cogs UUID;

    p        RECORD;
    tx       RECORD;
    it       RECORD;
    v_tx_id  UUID;
    v_item_id UUID;
    v_mov_id UUID;
    v_pay_id UUID;
    v_total  NUMERIC(15, 2);
    v_cogs   NUMERIC(15, 2);
    v_line   INTEGER;
    v_date   DATE;
    v_exp_account UUID;
    v_pay_account UUID;
BEGIN
    SELECT id INTO v_owner_id
    FROM auth.users
    WHERE lower(email) = lower(v_owner_email);

    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION
            'No user with email %. Edit v_owner_email at the top of this script.',
            v_owner_email;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.companies
        WHERE owner_id = v_owner_id
          AND lower(btrim(company_code)) = lower(v_company_code)
    ) THEN
        RAISE NOTICE 'Demo company % already exists - nothing to do.', v_company_code;
        RETURN;
    END IF;

    -- --------------------------------------------------------
    -- Company (the trigger seeds the chart of accounts)
    -- --------------------------------------------------------
    INSERT INTO public.companies
        (owner_id, company_name, company_code, address, contact_number,
         email, currency, fiscal_year_start, timezone)
    VALUES
        (v_owner_id, 'Demo Computer Trading', v_company_code,
         '123 Sample Street, Metro Manila', '+63 900 000 0000',
         'demo@example.com', 'PHP', 1, 'Asia/Manila')
    RETURNING id INTO v_company_id;

    SELECT id INTO a_cash    FROM public.accounts WHERE company_id = v_company_id AND account_code = '1010';
    SELECT id INTO a_bank    FROM public.accounts WHERE company_id = v_company_id AND account_code = '1020';
    SELECT id INTO a_ar      FROM public.accounts WHERE company_id = v_company_id AND account_code = '1100';
    SELECT id INTO a_inv     FROM public.accounts WHERE company_id = v_company_id AND account_code = '1200';
    SELECT id INTO a_ap      FROM public.accounts WHERE company_id = v_company_id AND account_code = '2010';
    SELECT id INTO a_capital FROM public.accounts WHERE company_id = v_company_id AND account_code = '3010';
    SELECT id INTO a_sales   FROM public.accounts WHERE company_id = v_company_id AND account_code = '4010';
    SELECT id INTO a_cogs    FROM public.accounts WHERE company_id = v_company_id AND account_code = '5010';

    IF a_cash IS NULL THEN
        RAISE EXCEPTION 'Chart of accounts was not seeded. Apply the chart-of-accounts migration first.';
    END IF;

    -- --------------------------------------------------------
    -- Categories and units
    -- --------------------------------------------------------
    INSERT INTO public.categories (company_id, name) VALUES
        (v_company_id, 'Laptops and Monitors'),
        (v_company_id, 'Peripherals'),
        (v_company_id, 'Storage');

    INSERT INTO public.unit_of_measures (company_id, name, abbreviation) VALUES
        (v_company_id, 'Piece', 'pc'),
        (v_company_id, 'Box',   'box');

    -- --------------------------------------------------------
    -- Products (with opening stock quantities)
    -- --------------------------------------------------------
    CREATE TEMP TABLE demo_products (
        sku TEXT, name TEXT, category TEXT, unit TEXT,
        cost NUMERIC, price NUMERIC, reorder NUMERIC, opening NUMERIC
    ) ON COMMIT DROP;

    INSERT INTO demo_products VALUES
        ('LAP-001', 'Laptop 14-inch',          'Laptops and Monitors', 'Piece', 28000, 35000, 2,  5),
        ('MON-001', 'Monitor 24-inch',         'Laptops and Monitors', 'Piece',  5500,  7500, 3,  8),
        ('KBD-001', 'Mechanical Keyboard',     'Peripherals',          'Piece',  1200,  1800, 5, 20),
        ('MSE-001', 'Wireless Mouse',          'Peripherals',          'Piece',   350,   590, 10, 30),
        ('USB-001', 'USB Flash Drive 32GB',    'Storage',              'Piece',   180,   290, 15, 50),
        ('HDD-001', 'External HDD 1TB',        'Storage',              'Piece',  2800,  3600, 3, 10);

    INSERT INTO public.products
        (company_id, category_id, unit_of_measure_id, sku, name,
         default_cost, selling_price, reorder_level)
    SELECT v_company_id, c.id, u.id, dp.sku, dp.name, dp.cost, dp.price, dp.reorder
    FROM demo_products dp
    JOIN public.categories c
      ON c.company_id = v_company_id AND c.name = dp.category
    JOIN public.unit_of_measures u
      ON u.company_id = v_company_id AND u.name = dp.unit;

    -- --------------------------------------------------------
    -- Contacts
    -- --------------------------------------------------------
    INSERT INTO public.contacts
        (company_id, name, contact_person, contact_type, is_customer, is_supplier, email, phone)
    VALUES
        (v_company_id, 'Metro Office Solutions', 'Ana Reyes',   'business',   TRUE,  FALSE, 'ana@metro-office.example',  '+63 900 111 1111'),
        (v_company_id, 'Juan Dela Cruz',         NULL,          'individual', TRUE,  FALSE, 'juan@example.com',          '+63 900 222 2222'),
        (v_company_id, 'TechSource Distribution','Mark Santos', 'business',   FALSE, TRUE,  'sales@techsource.example',  '+63 900 333 3333'),
        (v_company_id, 'PC Express Wholesale',   'Liza Cruz',   'business',   FALSE, TRUE,  'orders@pcexpress.example',  '+63 900 444 4444');

    -- --------------------------------------------------------
    -- Opening stock: movement + journal (Dr Inventory / Cr Owner's Capital)
    -- --------------------------------------------------------
    FOR p IN
        SELECT pr.id, pr.sku, pr.default_cost, dp.opening
        FROM public.products pr
        JOIN demo_products dp ON dp.sku = pr.sku
        WHERE pr.company_id = v_company_id
    LOOP
        INSERT INTO public.inventory_movements
            (company_id, product_id, movement_type, movement_date,
             quantity, unit_cost, notes)
        VALUES
            (v_company_id, p.id, 'opening_stock', v_month_start,
             p.opening, p.default_cost, 'Opening stock')
        RETURNING id, total_cost INTO v_mov_id, v_total;

        PERFORM pg_temp.post_je(
            v_company_id, 'JE-OPEN-' || p.sku, v_month_start,
            'Opening stock - ' || p.sku, 'inventory_movement', v_mov_id,
            jsonb_build_array(
                jsonb_build_object('account', a_inv,     'debit',  v_total),
                jsonb_build_object('account', a_capital, 'credit', v_total)
            )
        );
    END LOOP;

    -- --------------------------------------------------------
    -- Sample transactions (data-driven)
    -- --------------------------------------------------------
    CREATE TEMP TABLE demo_tx (
        seq INT, number TEXT, ttype TEXT, day_offset INT,
        contact TEXT, pay_amount NUMERIC, pay_method TEXT
    ) ON COMMIT DROP;

    CREATE TEMP TABLE demo_items (
        seq INT, line INT, sku TEXT, account_code TEXT,
        description TEXT, qty NUMERIC, price NUMERIC
    ) ON COMMIT DROP;

    INSERT INTO demo_tx VALUES
        (1, 'PUR-0001', 'purchase', 1, 'TechSource Distribution', 145000, 'bank_transfer'),
        (2, 'PUR-0002', 'purchase', 3, 'PC Express Wholesale',         0, NULL),
        (3, 'SAL-0001', 'sale',     2, 'Metro Office Solutions',   60000, 'bank_transfer'),
        (4, 'SAL-0002', 'sale',     4, 'Juan Dela Cruz',            4780, 'cash'),
        (5, 'SAL-0003', 'sale',     5, 'Metro Office Solutions',       0, NULL),
        (6, 'SAL-0004', 'sale',     7, 'Juan Dela Cruz',           35000, 'e_wallet'),
        (7, 'EXP-0001', 'expense',  1, NULL,                       15000, 'cash'),
        (8, 'EXP-0002', 'expense',  5, NULL,                        2000, 'bank_transfer'),
        (9, 'EXP-0003', 'expense',  8, NULL,                           0, NULL);

    INSERT INTO demo_items VALUES
        (1, 1, 'LAP-001', NULL, NULL,  4, 28000),
        (1, 2, 'MON-001', NULL, NULL,  6,  5500),
        (2, 1, 'KBD-001', NULL, NULL, 20,  1200),
        (2, 2, 'MSE-001', NULL, NULL, 30,   350),
        (3, 1, 'LAP-001', NULL, NULL,  3, 35000),
        (3, 2, 'MON-001', NULL, NULL,  2,  7500),
        (4, 1, 'KBD-001', NULL, NULL,  2,  1800),
        (4, 2, 'MSE-001', NULL, NULL,  2,   590),
        (5, 1, 'USB-001', NULL, NULL, 10,   290),
        (5, 2, 'HDD-001', NULL, NULL,  2,  3600),
        (6, 1, 'LAP-001', NULL, NULL,  1, 35000),
        (7, 1, NULL, '6010', 'Monthly office rent',   1, 15000),
        (8, 1, NULL, '6040', 'Internet subscription', 1,  2000),
        (9, 1, NULL, '6020', 'Electricity bill',      1,  3200);

    FOR tx IN SELECT * FROM demo_tx ORDER BY seq LOOP
        v_date := v_month_start + LEAST(tx.day_offset, v_days_elapsed);
        v_cogs := 0;
        v_line := 0;
        v_exp_account := NULL;

        -- Created as draft first, posted at the end (mirrors the real workflow).
        INSERT INTO public.transactions
            (company_id, contact_id, transaction_number, transaction_type,
             transaction_date, status)
        VALUES
            (v_company_id,
             (SELECT id FROM public.contacts
              WHERE company_id = v_company_id AND name = tx.contact),
             tx.number, tx.ttype, v_date, 'draft')
        RETURNING id INTO v_tx_id;

        FOR it IN
            SELECT di.line AS di_line, di.sku AS di_sku, di.description AS di_desc,
                   di.qty AS di_qty, di.price AS di_price,
                   pr.id AS product_id, pr.name AS product_name,
                   pr.default_cost AS product_cost, pr.unit_of_measure_id AS uom_id,
                   u.name AS unit_name, u.abbreviation AS unit_abbr,
                   ac.id AS account_id
            FROM demo_items di
            LEFT JOIN public.products pr
              ON pr.company_id = v_company_id AND pr.sku = di.sku
            LEFT JOIN public.unit_of_measures u
              ON u.id = pr.unit_of_measure_id
            LEFT JOIN public.accounts ac
              ON ac.company_id = v_company_id AND ac.account_code = di.account_code
            WHERE di.seq = tx.seq
            ORDER BY di.line
        LOOP
            v_line := v_line + 1;

            IF it.di_sku IS NOT NULL THEN
                INSERT INTO public.transaction_items
                    (company_id, transaction_id, line_number, item_type,
                     product_id, unit_of_measure_id, description, sku,
                     unit_name, unit_abbreviation, quantity, unit_price)
                VALUES
                    (v_company_id, v_tx_id, v_line, 'product',
                     it.product_id, it.uom_id, it.product_name, it.di_sku,
                     it.unit_name, it.unit_abbr, it.di_qty, it.di_price)
                RETURNING id INTO v_item_id;

                -- Stock movement. Sales leave at the product's cost; purchases
                -- come in at the purchase price. (Simplified: the real weighted
                -- average cost logic comes later.)
                INSERT INTO public.inventory_movements
                    (company_id, product_id, transaction_id, transaction_item_id,
                     movement_type, movement_date, quantity, unit_cost)
                VALUES
                    (v_company_id, it.product_id, v_tx_id, v_item_id,
                     tx.ttype, v_date, it.di_qty,
                     CASE WHEN tx.ttype = 'sale' THEN it.product_cost ELSE it.di_price END);

                IF tx.ttype = 'sale' THEN
                    v_cogs := v_cogs + ROUND(it.di_qty * it.product_cost, 2);
                END IF;
            ELSE
                INSERT INTO public.transaction_items
                    (company_id, transaction_id, line_number, item_type,
                     expense_account_id, description, quantity, unit_price)
                VALUES
                    (v_company_id, v_tx_id, v_line, 'expense',
                     it.account_id, it.di_desc, it.di_qty, it.di_price);
                v_exp_account := it.account_id;
            END IF;
        END LOOP;

        SELECT COALESCE(SUM(line_subtotal), 0) INTO v_total
        FROM public.transaction_items
        WHERE company_id = v_company_id AND transaction_id = v_tx_id;

        UPDATE public.transactions
        SET subtotal = v_total
        WHERE id = v_tx_id;

        UPDATE public.transactions
        SET status = 'posted', posted_at = NOW()
        WHERE id = v_tx_id;

        -- Accounting entry for the transaction (accrual basis:
        -- unpaid amounts sit in Receivable / Payable until a payment arrives).
        IF tx.ttype = 'sale' THEN
            PERFORM pg_temp.post_je(
                v_company_id, 'JE-' || tx.number, v_date,
                'Sale ' || tx.number, 'transaction', v_tx_id,
                jsonb_build_array(
                    jsonb_build_object('account', a_ar,    'debit',  v_total),
                    jsonb_build_object('account', a_sales, 'credit', v_total),
                    jsonb_build_object('account', a_cogs,  'debit',  v_cogs),
                    jsonb_build_object('account', a_inv,   'credit', v_cogs)
                )
            );
        ELSIF tx.ttype = 'purchase' THEN
            PERFORM pg_temp.post_je(
                v_company_id, 'JE-' || tx.number, v_date,
                'Purchase ' || tx.number, 'transaction', v_tx_id,
                jsonb_build_array(
                    jsonb_build_object('account', a_inv, 'debit',  v_total),
                    jsonb_build_object('account', a_ap,  'credit', v_total)
                )
            );
        ELSE
            PERFORM pg_temp.post_je(
                v_company_id, 'JE-' || tx.number, v_date,
                'Expense ' || tx.number, 'transaction', v_tx_id,
                jsonb_build_array(
                    jsonb_build_object('account', v_exp_account, 'debit',  v_total),
                    jsonb_build_object('account', a_ap,          'credit', v_total)
                )
            );
        END IF;

        -- Payment (if any) and its journal entry.
        IF tx.pay_amount > 0 THEN
            v_pay_account := CASE WHEN tx.pay_method = 'cash' THEN a_cash ELSE a_bank END;

            INSERT INTO public.payments
                (company_id, transaction_id, account_id, payment_date,
                 payment_method, amount, notes)
            VALUES
                (v_company_id, v_tx_id, v_pay_account, v_date,
                 tx.pay_method, tx.pay_amount, 'Demo payment')
            RETURNING id INTO v_pay_id;

            IF tx.ttype = 'sale' THEN
                PERFORM pg_temp.post_je(
                    v_company_id, 'JE-PAY-' || tx.number, v_date,
                    'Payment received for ' || tx.number, 'payment', v_pay_id,
                    jsonb_build_array(
                        jsonb_build_object('account', v_pay_account, 'debit',  tx.pay_amount),
                        jsonb_build_object('account', a_ar,          'credit', tx.pay_amount)
                    )
                );
            ELSE
                PERFORM pg_temp.post_je(
                    v_company_id, 'JE-PAY-' || tx.number, v_date,
                    'Payment made for ' || tx.number, 'payment', v_pay_id,
                    jsonb_build_array(
                        jsonb_build_object('account', a_ap,          'debit',  tx.pay_amount),
                        jsonb_build_object('account', v_pay_account, 'credit', tx.pay_amount)
                    )
                );
            END IF;
        END IF;
    END LOOP;

    RAISE NOTICE 'Demo company % created. Refresh LiteBooks and pick "Demo Computer Trading".', v_company_code;
END
$$;

DROP FUNCTION IF EXISTS pg_temp.post_je(UUID, TEXT, DATE, TEXT, TEXT, UUID, JSONB);


-- ============================================================
-- OPTIONAL: sanity check after running (should show equal totals)
-- ============================================================
-- SELECT SUM(jl.debit) AS total_debit, SUM(jl.credit) AS total_credit
-- FROM public.journal_lines jl
-- JOIN public.companies c ON c.id = jl.company_id
-- WHERE c.company_code = 'DEMO001';
--
-- RESETTING THE DEMO: posted journal entries are protected by triggers,
-- so the easiest reset is to drop and recreate your hosted dev database
-- state, or temporarily disable the protection triggers while cleaning up.