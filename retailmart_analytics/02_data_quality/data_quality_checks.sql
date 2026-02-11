-- ============================================================================
-- FILE: 02_data_quality/data_quality_checks.sql
-- PROJECT: RetailMart Enterprise Analytics Platform
-- PURPOSE: Data quality validation checks before analytics processing
-- AUTHOR: SQL Bootcamp
-- CREATED: 2025
--
-- DESCRIPTION:
--   "Garbage in, garbage out" - No matter how good your KPIs are, if the
--   underlying data is bad, your insights are worthless.
--
--   Real-world example: At PhonePe, before any report goes to leadership,
--   automated data quality checks run to catch issues like:
--   - Duplicate transactions
--   - Missing customer IDs
--   - Negative payment amounts
--   - Future-dated records
--
-- DATA QUALITY DIMENSIONS:
--   1. COMPLETENESS - Are required fields populated?
--   2. ACCURACY - Are values within expected ranges?
--   3. CONSISTENCY - Do related records match across tables?
--   4. TIMELINESS - Is data fresh enough?
--   5. UNIQUENESS - Are there unexpected duplicates?
--
-- EXECUTION ORDER: Run AFTER 01_setup scripts
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '         RETAILMART ENTERPRISE ANALYTICS - DATA QUALITY CHECKS              '
\echo '============================================================================'
\echo ''

-- ============================================================================
-- VIEW 1: COMPLETENESS CHECKS
-- ============================================================================
-- Checks for NULL or missing values in required fields
-- ============================================================================

\echo '[1/7] Creating completeness checks view...'

CREATE OR REPLACE VIEW analytics.vw_dq_completeness AS

-- Check 1: Orders without customer
SELECT 
    'Orders Missing Customer' as check_name,
    'COMPLETENESS' as category,
    'HIGH' as severity,
    'sales.orders' as source_table,
    COUNT(*) as issue_count,
    'Orders where cust_id is NULL' as description
FROM sales.orders
WHERE cust_id IS NULL

UNION ALL

-- Check 2: Orders without store
SELECT 
    'Orders Missing Store',
    'COMPLETENESS',
    'HIGH',
    'sales.orders',
    COUNT(*),
    'Orders where store_id is NULL'
FROM sales.orders
WHERE store_id IS NULL

UNION ALL

-- Check 3: Order items without price
SELECT 
    'Order Items Missing Price',
    'COMPLETENESS',
    'CRITICAL',
    'sales.order_items',
    COUNT(*),
    'Order items where unit_price is NULL or zero'
FROM sales.order_items
WHERE unit_price IS NULL OR unit_price = 0

UNION ALL

-- Check 4: Customers without name
SELECT 
    'Customers Missing Name',
    'COMPLETENESS',
    'MEDIUM',
    'customers.customers',
    COUNT(*),
    'Customers where full_name is NULL or empty'
FROM customers.customers
WHERE full_name IS NULL OR TRIM(full_name) = ''

UNION ALL

-- Check 5: Products without category
SELECT 
    'Products Missing Category',
    'COMPLETENESS',
    'MEDIUM',
    'products.products',
    COUNT(*),
    'Products where category is NULL or empty'
FROM products.products
WHERE category IS NULL OR TRIM(category) = ''

UNION ALL

-- Check 6: Shipments without dates
SELECT 
    'Shipments Missing Dates',
    'COMPLETENESS',
    'HIGH',
    'sales.shipments',
    COUNT(*),
    'Delivered shipments without delivered_date'
FROM sales.shipments
WHERE status = 'Delivered' AND delivered_date IS NULL;

\echo '      ✓ View created: vw_dq_completeness'


-- ============================================================================
-- VIEW 2: ACCURACY CHECKS
-- ============================================================================
-- Checks for values outside expected ranges
-- ============================================================================

\echo '[2/7] Creating accuracy checks view...'

CREATE OR REPLACE VIEW analytics.vw_dq_accuracy AS

-- Check 1: Negative order amounts
SELECT 
    'Negative Order Amount' as check_name,
    'ACCURACY' as category,
    'CRITICAL' as severity,
    'sales.orders' as source_table,
    COUNT(*) as issue_count,
    'Orders where total_amount is negative' as description
FROM sales.orders
WHERE total_amount < 0

UNION ALL

-- Check 2: Future order dates
SELECT 
    'Future Order Dates',
    'ACCURACY',
    'CRITICAL',
    'sales.orders',
    COUNT(*),
    'Orders with order_date in the future'
FROM sales.orders
WHERE order_date > CURRENT_DATE

UNION ALL

-- Check 3: Negative quantities
SELECT 
    'Negative Quantities',
    'ACCURACY',
    'HIGH',
    'sales.order_items',
    COUNT(*),
    'Order items with negative quantity'
FROM sales.order_items
WHERE quantity < 0

UNION ALL

-- Check 4: Discount over 100%
SELECT 
    'Invalid Discount Percentage',
    'ACCURACY',
    'HIGH',
    'sales.order_items',
    COUNT(*),
    'Order items with discount > 100%'
FROM sales.order_items
WHERE discount > 100

UNION ALL

-- Check 5: Negative inventory
SELECT 
    'Negative Inventory',
    'ACCURACY',
    'MEDIUM',
    'products.inventory',
    COUNT(*),
    'Inventory records with negative stock_qty'
FROM products.inventory
WHERE stock_qty < 0

UNION ALL

-- Check 6: Invalid ratings
SELECT 
    'Invalid Ratings',
    'ACCURACY',
    'LOW',
    'customers.reviews',
    COUNT(*),
    'Reviews with rating outside 1-5 range'
FROM customers.reviews
WHERE rating < 1 OR rating > 5

UNION ALL

-- Check 7: Invalid age
SELECT 
    'Invalid Customer Age',
    'ACCURACY',
    'MEDIUM',
    'customers.customers',
    COUNT(*),
    'Customers with age < 10 or > 120'
FROM customers.customers
WHERE age < 10 OR age > 120

UNION ALL

-- Check 8: Delivered before shipped
SELECT 
    'Delivery Before Shipment',
    'ACCURACY',
    'HIGH',
    'sales.shipments',
    COUNT(*),
    'Shipments where delivered_date < shipped_date'
FROM sales.shipments
WHERE delivered_date < shipped_date;

\echo '      ✓ View created: vw_dq_accuracy'


-- ============================================================================
-- VIEW 3: CONSISTENCY CHECKS (Referential Integrity)
-- ============================================================================
-- Checks for orphan records - records that reference non-existent parents
-- ============================================================================

\echo '[3/7] Creating consistency checks view...'

CREATE OR REPLACE VIEW analytics.vw_dq_consistency AS

-- Check 1: Orders with invalid customer
SELECT 
    'Orphan Orders (Invalid Customer)' as check_name,
    'CONSISTENCY' as category,
    'CRITICAL' as severity,
    'sales.orders' as source_table,
    COUNT(*) as issue_count,
    'Orders referencing non-existent customer' as description
FROM sales.orders o
WHERE NOT EXISTS (SELECT 1 FROM customers.customers c WHERE c.cust_id = o.cust_id)
AND o.cust_id IS NOT NULL

UNION ALL

-- Check 2: Orders with invalid store
SELECT 
    'Orphan Orders (Invalid Store)',
    'CONSISTENCY',
    'HIGH',
    'sales.orders',
    COUNT(*),
    'Orders referencing non-existent store'
FROM sales.orders o
WHERE NOT EXISTS (SELECT 1 FROM stores.stores s WHERE s.store_id = o.store_id)
AND o.store_id IS NOT NULL

UNION ALL

-- Check 3: Order items with invalid order
SELECT 
    'Orphan Order Items',
    'CONSISTENCY',
    'CRITICAL',
    'sales.order_items',
    COUNT(*),
    'Order items referencing non-existent order'
FROM sales.order_items oi
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.order_id = oi.order_id)

UNION ALL

-- Check 4: Order items with invalid product
SELECT 
    'Invalid Product Reference',
    'CONSISTENCY',
    'HIGH',
    'sales.order_items',
    COUNT(*),
    'Order items referencing non-existent product'
FROM sales.order_items oi
WHERE NOT EXISTS (SELECT 1 FROM products.products p WHERE p.prod_id = oi.prod_id)

UNION ALL

-- Check 5: Payments with invalid order
SELECT 
    'Orphan Payments',
    'CONSISTENCY',
    'CRITICAL',
    'sales.payments',
    COUNT(*),
    'Payments referencing non-existent order'
FROM sales.payments p
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.order_id = p.order_id)

UNION ALL

-- Check 6: Shipments with invalid order
SELECT 
    'Orphan Shipments',
    'CONSISTENCY',
    'HIGH',
    'sales.shipments',
    COUNT(*),
    'Shipments referencing non-existent order'
FROM sales.shipments s
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.order_id = s.order_id)

UNION ALL

-- Check 7: Returns with invalid order
SELECT 
    'Orphan Returns',
    'CONSISTENCY',
    'HIGH',
    'sales.returns',
    COUNT(*),
    'Returns referencing non-existent order'
FROM sales.returns r
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.order_id = r.order_id)

UNION ALL

-- Check 8: Order total vs item sum mismatch
SELECT 
    'Order Total Mismatch',
    'CONSISTENCY',
    'MEDIUM',
    'sales.orders',
    COUNT(*),
    'Orders where total_amount differs significantly from sum of items'
FROM (
    SELECT o.order_id, o.total_amount,
           SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0)/100)) as calculated_total
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.total_amount
    HAVING ABS(o.total_amount - SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0)/100))) > 1
) mismatches;

\echo '      ✓ View created: vw_dq_consistency'


-- ============================================================================
-- VIEW 4: TIMELINESS CHECKS
-- ============================================================================
-- Checks for stale or delayed data
-- ============================================================================

\echo '[4/7] Creating timeliness checks view...'

CREATE OR REPLACE VIEW analytics.vw_dq_timeliness AS

-- Check 1: Old pending orders
SELECT 
    'Old Pending Orders' as check_name,
    'TIMELINESS' as category,
    'MEDIUM' as severity,
    'sales.orders' as source_table,
    COUNT(*) as issue_count,
    'Orders pending for more than 7 days' as description
FROM sales.orders
WHERE order_status = 'Pending'
AND order_date < (SELECT MAX(order_date) - INTERVAL '7 days' FROM sales.orders)

UNION ALL

-- Check 2: Shipments not delivered
SELECT 
    'Long-Pending Shipments',
    'TIMELINESS',
    'HIGH',
    'sales.shipments',
    COUNT(*),
    'Shipped orders not delivered within 10 days'
FROM sales.shipments
WHERE status = 'Shipped'
AND shipped_date < (SELECT MAX(order_date) - INTERVAL '10 days' FROM sales.orders)

UNION ALL

-- Check 3: Stale inventory data
SELECT 
    'Stale Inventory Data',
    'TIMELINESS',
    'MEDIUM',
    'products.inventory',
    COUNT(*),
    'Inventory not updated in last 30 days'
FROM products.inventory
WHERE last_updated < (SELECT MAX(order_date) - INTERVAL '30 days' FROM sales.orders);

\echo '      ✓ View created: vw_dq_timeliness'


-- ============================================================================
-- VIEW 5: UNIQUENESS CHECKS
-- ============================================================================
-- Checks for potential duplicates
-- ============================================================================

\echo '[5/7] Creating uniqueness checks view...'

CREATE OR REPLACE VIEW analytics.vw_dq_uniqueness AS

-- Check 1: Potential duplicate customers (same name, city)
SELECT 
    'Potential Duplicate Customers' as check_name,
    'UNIQUENESS' as category,
    'LOW' as severity,
    'customers.customers' as source_table,
    COUNT(*) as issue_count,
    'Customers with same name and city' as description
FROM (
    SELECT full_name, city, COUNT(*) as cnt
    FROM customers.customers
    WHERE full_name IS NOT NULL
    GROUP BY full_name, city
    HAVING COUNT(*) > 1
) dups

UNION ALL

-- Check 2: Multiple payments for same order
SELECT 
    'Multiple Payments Per Order',
    'UNIQUENESS',
    'LOW',
    'sales.payments',
    COUNT(*),
    'Orders with more than one payment record'
FROM (
    SELECT order_id, COUNT(*) as cnt
    FROM sales.payments
    GROUP BY order_id
    HAVING COUNT(*) > 1
) multi_payments;

\echo '      ✓ View created: vw_dq_uniqueness'


-- ============================================================================
-- VIEW 6: CONSOLIDATED DATA QUALITY REPORT
-- ============================================================================
-- Single view combining all checks for easy monitoring
-- ============================================================================

\echo '[6/7] Creating consolidated DQ report view...'

CREATE OR REPLACE VIEW analytics.vw_data_quality_report AS
SELECT * FROM analytics.vw_dq_completeness WHERE issue_count > 0
UNION ALL
SELECT * FROM analytics.vw_dq_accuracy WHERE issue_count > 0
UNION ALL
SELECT * FROM analytics.vw_dq_consistency WHERE issue_count > 0
UNION ALL
SELECT * FROM analytics.vw_dq_timeliness WHERE issue_count > 0
UNION ALL
SELECT * FROM analytics.vw_dq_uniqueness WHERE issue_count > 0;
-- ORDER BY 
--     CASE severity 
--         WHEN 'CRITICAL' THEN 1 
--         WHEN 'HIGH' THEN 2 
--         WHEN 'MEDIUM' THEN 3 
--         WHEN 'LOW' THEN 4 
--     END,
--     issue_count DESC;

\echo '      ✓ View created: vw_data_quality_report'


-- ============================================================================
-- FUNCTION: RUN ALL DATA QUALITY CHECKS
-- ============================================================================
-- Function that runs all checks and logs issues to the tracking table
-- ============================================================================

\echo '[7/7] Creating data quality check function...'

CREATE OR REPLACE FUNCTION analytics.fn_run_data_quality_checks()
RETURNS TABLE (
    check_name VARCHAR,
    category VARCHAR,
    severity VARCHAR,
    source_table VARCHAR,
    issue_count BIGINT,
    description TEXT
) AS $$
DECLARE
    v_log_id INTEGER;
    v_total_issues BIGINT := 0;
    rec RECORD;
BEGIN
    -- Start logging
    v_log_id := analytics.log_operation_start('VALIDATE', 'Data Quality', 'fn_run_data_quality_checks');
    
    -- Clear old issues (older than 7 days)
    DELETE FROM analytics.data_quality_issues 
    WHERE detected_at < CURRENT_TIMESTAMP - INTERVAL '7 days';
    
    -- Run checks and log issues
    FOR rec IN SELECT * FROM analytics.vw_data_quality_report LOOP
        -- Log each issue found
        IF rec.issue_count > 0 THEN
            PERFORM analytics.log_dq_issue(
                rec.check_name,
                rec.category,
                rec.severity,
                rec.source_table,
                rec.issue_count,
                rec.description
            );
            v_total_issues := v_total_issues + rec.issue_count;
        END IF;
        
        -- Return row
        check_name := rec.check_name;
        category := rec.category;
        severity := rec.severity;
        source_table := rec.source_table;
        issue_count := rec.issue_count;
        description := rec.description;
        RETURN NEXT;
    END LOOP;
    
    -- Complete logging
    PERFORM analytics.log_operation_complete(v_log_id, 'SUCCESS', v_total_issues);
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

\echo '      ✓ Function created: fn_run_data_quality_checks()'


-- ============================================================================
-- VERIFICATION
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '              DATA QUALITY CHECKS SETUP COMPLETE                            '
\echo '============================================================================'
\echo ''
\echo '✅ Views Created:'
\echo '   • vw_dq_completeness    - Missing/NULL value checks'
\echo '   • vw_dq_accuracy        - Value range and logic checks'
\echo '   • vw_dq_consistency     - Referential integrity checks'
\echo '   • vw_dq_timeliness      - Data freshness checks'
\echo '   • vw_dq_uniqueness      - Duplicate detection'
\echo '   • vw_data_quality_report - Consolidated report'
\echo ''
\echo '✅ Functions Created:'
\echo '   • fn_run_data_quality_checks() - Run all checks and log issues'
\echo ''
\echo '📊 Quick Check:'
\echo '   SELECT * FROM analytics.vw_data_quality_report;'
\echo ''
\echo '   -- Or run full check with logging:'
\echo '   SELECT * FROM analytics.fn_run_data_quality_checks();'
\echo ''
\echo '➡️  Next: Run 03_kpi_queries/01_sales_analytics.sql'
\echo '============================================================================'
\echo ''

-- Show current data quality status
SELECT 
    severity,
    COUNT(*) as checks_with_issues,
    SUM(issue_count) as total_issues
FROM analytics.vw_data_quality_report
GROUP BY severity
ORDER BY 
    CASE severity 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'HIGH' THEN 2 
        WHEN 'MEDIUM' THEN 3 
        WHEN 'LOW' THEN 4 
    END;
