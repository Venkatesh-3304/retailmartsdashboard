-- ============================================================================
-- FILE: 03_kpi_queries/05_operations_analytics.sql
-- PROJECT: RetailMart Enterprise Analytics Platform
-- PURPOSE: Operations Analytics - Delivery, Returns, Payments tracking
-- AUTHOR: SQL Bootcamp
-- CREATED: 2025
--
-- DESCRIPTION:
--   Operations is where the rubber meets the road. At Amazon, they obsess over:
--   - On-time delivery rate (SLA compliance)
--   - Return rates and reasons
--   - Payment success rates
--   
--   This module tracks operational health and identifies bottlenecks.
--
-- CREATES:
--   • 5 Regular Views
--   • 1 Materialized View
--   • 5 JSON Export Functions
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '             OPERATIONS ANALYTICS MODULE - STARTING                         '
\echo '============================================================================'
\echo ''

-- ============================================================================
-- VIEW 1: DELIVERY PERFORMANCE
-- ============================================================================

\echo '[1/6] Creating view: vw_delivery_performance...'

CREATE OR REPLACE VIEW analytics.vw_delivery_performance AS
WITH delivery_metrics AS (
    SELECT 
        DATE_TRUNC('month', s.shipped_date)::DATE as ship_month,
        COUNT(*) as total_shipments,
        COUNT(*) FILTER (WHERE s.status = 'Delivered') as delivered_count,
        COUNT(*) FILTER (WHERE s.status = 'Shipped') as in_transit_count,
        COUNT(*) FILTER (WHERE s.status = 'Pending') as pending_count,
        AVG(s.delivered_date - s.shipped_date) as avg_delivery_days,
        COUNT(*) FILTER (WHERE (s.delivered_date - s.shipped_date) <= 3) as on_time_deliveries,
        COUNT(*) FILTER (WHERE (s.delivered_date - s.shipped_date) > 7) as delayed_deliveries
    FROM sales.shipments s
    WHERE s.shipped_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', s.shipped_date)
)
SELECT 
    ship_month,
    TO_CHAR(ship_month, 'Mon YYYY') as month_name,
    total_shipments,
    delivered_count,
    in_transit_count,
    pending_count,
    ROUND(avg_delivery_days::NUMERIC, 1) as avg_delivery_days,
    on_time_deliveries,
    delayed_deliveries,
    ROUND((on_time_deliveries::NUMERIC / NULLIF(delivered_count, 0) * 100), 2) as on_time_pct,
    ROUND((delayed_deliveries::NUMERIC / NULLIF(delivered_count, 0) * 100), 2) as delayed_pct,
    CASE 
        WHEN (on_time_deliveries::NUMERIC / NULLIF(delivered_count, 0) * 100) >= 95 THEN 'Excellent'
        WHEN (on_time_deliveries::NUMERIC / NULLIF(delivered_count, 0) * 100) >= 85 THEN 'Good'
        WHEN (on_time_deliveries::NUMERIC / NULLIF(delivered_count, 0) * 100) >= 70 THEN 'Needs Improvement'
        ELSE 'Critical'
    END as sla_status
FROM delivery_metrics
ORDER BY ship_month DESC;

\echo '      ✓ View created: vw_delivery_performance'


-- ============================================================================
-- VIEW 2: COURIER COMPARISON
-- ============================================================================

\echo '[2/6] Creating view: vw_courier_comparison...'

CREATE OR REPLACE VIEW analytics.vw_courier_comparison AS
SELECT 
    courier_name,
    COUNT(*) as total_shipments,
    COUNT(*) FILTER (WHERE status = 'Delivered') as delivered,
    COUNT(*) FILTER (WHERE status = 'Shipped') as in_transit,
    ROUND(AVG(delivered_date - shipped_date)::NUMERIC, 1) as avg_delivery_days,
    COUNT(*) FILTER (WHERE (delivered_date - shipped_date) <= 3) as on_time,
    ROUND((COUNT(*) FILTER (WHERE (delivered_date - shipped_date) <= 3)::NUMERIC / 
           NULLIF(COUNT(*) FILTER (WHERE status = 'Delivered'), 0) * 100), 2) as on_time_pct,
    RANK() OVER (ORDER BY AVG(delivered_date - shipped_date) NULLS LAST) as speed_rank,
    RANK() OVER (ORDER BY COUNT(*) FILTER (WHERE (delivered_date - shipped_date) <= 3)::NUMERIC / 
           NULLIF(COUNT(*) FILTER (WHERE status = 'Delivered'), 0) DESC NULLS LAST) as reliability_rank
FROM sales.shipments
WHERE shipped_date IS NOT NULL
GROUP BY courier_name
ORDER BY on_time_pct DESC NULLS LAST;

\echo '      ✓ View created: vw_courier_comparison'


-- ============================================================================
-- VIEW 3: RETURN ANALYSIS
-- ============================================================================

\echo '[3/6] Creating view: vw_return_analysis...'

CREATE OR REPLACE VIEW analytics.vw_return_analysis AS
WITH return_stats AS (
    SELECT 
        p.category,
        COUNT(*) as return_count,
        SUM(r.refund_amount) as total_refunds,
        r.reason
    FROM sales.returns r
    JOIN products.products p ON r.prod_id = p.prod_id
    GROUP BY p.category, r.reason
),
category_orders AS (
    SELECT 
        p.category,
        COUNT(DISTINCT oi.order_id) as total_orders,
        SUM(oi.quantity * oi.unit_price) as total_revenue
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.prod_id
    JOIN sales.orders o ON oi.order_id = o.order_id AND o.order_status = 'Delivered'
    GROUP BY p.category
)
SELECT 
    rs.category,
    rs.reason,
    rs.return_count,
    ROUND(rs.total_refunds::NUMERIC, 2) as total_refunds,
    co.total_orders,
    ROUND((rs.return_count::NUMERIC / NULLIF(co.total_orders, 0) * 100), 2) as return_rate_pct,
    ROUND((rs.total_refunds / NULLIF(co.total_revenue, 0) * 100), 2) as refund_rate_pct
FROM return_stats rs
JOIN category_orders co ON rs.category = co.category
ORDER BY return_count DESC;

\echo '      ✓ View created: vw_return_analysis'


-- ============================================================================
-- VIEW 4: PAYMENT SUCCESS RATE
-- ============================================================================

\echo '[4/6] Creating view: vw_payment_success_rate...'

CREATE OR REPLACE VIEW analytics.vw_payment_success_rate AS
WITH payment_stats AS (
    SELECT 
        payment_mode,
        DATE_TRUNC('month', payment_date)::DATE as payment_month,
        COUNT(*) as total_transactions,
        SUM(amount) as total_amount,
        AVG(amount) as avg_amount
    FROM sales.payments
    GROUP BY payment_mode, DATE_TRUNC('month', payment_date)
)
SELECT 
    payment_month,
    TO_CHAR(payment_month, 'Mon YYYY') as month_name,
    payment_mode,
    total_transactions,
    ROUND(total_amount::NUMERIC, 2) as total_amount,
    ROUND(avg_amount::NUMERIC, 2) as avg_amount,
    ROUND((total_amount / SUM(total_amount) OVER (PARTITION BY payment_month) * 100)::NUMERIC, 2) as pct_of_monthly_revenue,
    LAG(total_amount) OVER (PARTITION BY payment_mode ORDER BY payment_month) as prev_month_amount,
    ROUND(((total_amount - LAG(total_amount) OVER (PARTITION BY payment_mode ORDER BY payment_month)) /
           NULLIF(LAG(total_amount) OVER (PARTITION BY payment_mode ORDER BY payment_month), 0) * 100)::NUMERIC, 2) as mom_growth_pct
FROM payment_stats
ORDER BY payment_month DESC, total_amount DESC;

\echo '      ✓ View created: vw_payment_success_rate'


-- ============================================================================
-- VIEW 5: PENDING SHIPMENTS (Actionable)
-- ============================================================================

\echo '[5/6] Creating view: vw_pending_shipments...'

CREATE OR REPLACE VIEW analytics.vw_pending_shipments AS
SELECT 
    o.order_id,
    o.order_date,
    (SELECT MAX(order_date) FROM sales.orders) - o.order_date as days_since_order,
    c.full_name as customer_name,
    c.city as customer_city,
    s.store_name,
    o.total_amount,
    sh.status as shipment_status,
    sh.courier_name,
    sh.shipped_date,
    CASE 
        WHEN (SELECT MAX(order_date) FROM sales.orders) - o.order_date > 7 THEN 'Critical'
        WHEN (SELECT MAX(order_date) FROM sales.orders) - o.order_date > 3 THEN 'Urgent'
        ELSE 'Normal'
    END as priority
FROM sales.orders o
LEFT JOIN sales.shipments sh ON o.order_id = sh.order_id
JOIN customers.customers c ON o.cust_id = c.cust_id
JOIN stores.stores s ON o.store_id = s.store_id
WHERE o.order_status != 'Delivered'
AND (sh.status IS NULL OR sh.status != 'Delivered')
ORDER BY days_since_order DESC;

\echo '      ✓ View created: vw_pending_shipments'


-- ============================================================================
-- MATERIALIZED VIEW: OPERATIONS SUMMARY
-- ============================================================================

\echo '[6/6] Creating materialized view: mv_operations_summary...'

DROP MATERIALIZED VIEW IF EXISTS analytics.mv_operations_summary CASCADE;

CREATE MATERIALIZED VIEW analytics.mv_operations_summary AS
WITH delivery_stats AS (
    SELECT 
        COUNT(*) as total_shipments,
        COUNT(*) FILTER (WHERE status = 'Delivered') as delivered,
        ROUND(AVG(delivered_date - shipped_date)::NUMERIC, 1) as avg_delivery_days,
        ROUND((COUNT(*) FILTER (WHERE (delivered_date - shipped_date) <= 3)::NUMERIC / 
               NULLIF(COUNT(*) FILTER (WHERE status = 'Delivered'), 0) * 100), 2) as on_time_pct
    FROM sales.shipments WHERE shipped_date IS NOT NULL
),
return_stats AS (
    SELECT 
        COUNT(*) as total_returns,
        ROUND(SUM(refund_amount)::NUMERIC, 2) as total_refunds,
        ROUND(AVG(refund_amount)::NUMERIC, 2) as avg_refund
    FROM sales.returns
),
payment_stats AS (
    SELECT 
        COUNT(*) as total_payments,
        ROUND(SUM(amount)::NUMERIC, 2) as total_payment_amount,
        COUNT(DISTINCT payment_mode) as payment_modes_used
    FROM sales.payments
),
order_stats AS (
    SELECT 
        COUNT(*) as total_orders,
        COUNT(*) FILTER (WHERE order_status = 'Delivered') as delivered_orders,
        COUNT(*) FILTER (WHERE order_status = 'Pending') as pending_orders,
        COUNT(*) FILTER (WHERE order_status = 'Processing') as processing_orders
    FROM sales.orders
)
SELECT 
    (SELECT MAX(order_date) FROM sales.orders) as reference_date,
    d.total_shipments, d.delivered as shipments_delivered, d.avg_delivery_days, d.on_time_pct as delivery_sla_pct,
    r.total_returns, r.total_refunds, r.avg_refund,
    ROUND((r.total_returns::NUMERIC / NULLIF(o.delivered_orders, 0) * 100), 2) as return_rate_pct,
    p.total_payments, p.total_payment_amount, p.payment_modes_used,
    o.total_orders, o.delivered_orders, o.pending_orders, o.processing_orders
FROM delivery_stats d
CROSS JOIN return_stats r
CROSS JOIN payment_stats p
CROSS JOIN order_stats o;

\echo '      ✓ Materialized view created: mv_operations_summary'


-- ============================================================================
-- JSON EXPORT FUNCTIONS
-- ============================================================================

\echo ''
\echo 'Creating JSON export functions...'

CREATE OR REPLACE FUNCTION analytics.get_operations_summary_json()
RETURNS JSON AS $$
BEGIN
    RETURN (SELECT row_to_json(t) FROM analytics.mv_operations_summary t);
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_delivery_performance_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(json_build_object(
            'month', month_name, 
            'shipments', total_shipments, 
            'delivered', delivered_count,
            'avgDeliveryDays', avg_delivery_days,
            'onTimePct', on_time_pct, 
            'slaStatus', sla_status
        ) ORDER BY ship_month DESC)
        FROM analytics.vw_delivery_performance
        LIMIT 12
    );
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_courier_comparison_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(json_build_object(
            'courier', courier_name, 
            'shipments', total_shipments, 
            'avgDays', avg_delivery_days,
            'onTimePct', on_time_pct, 
            'speedRank', speed_rank, 
            'reliabilityRank', reliability_rank,
            'performanceScore', ROUND((COALESCE(on_time_pct, 0) * 0.7 + (100 - LEAST(avg_delivery_days * 10, 100)) * 0.3)::NUMERIC, 1)
        ) ORDER BY on_time_pct DESC NULLS LAST)
        FROM analytics.vw_courier_comparison
    );
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_return_analysis_json()
RETURNS JSON AS $$
BEGIN
    RETURN json_build_object(
        'byCategory', (
            SELECT json_agg(json_build_object(
                'category', category,
                'returnCount', return_count,
                'totalRefunds', total_refunds,
                'returnRate', return_rate_pct
            ) ORDER BY return_count DESC)
            FROM (
                SELECT 
                    category,
                    SUM(return_count) as return_count,
                    SUM(total_refunds) as total_refunds,
                    ROUND(AVG(return_rate_pct)::NUMERIC, 2) as return_rate_pct
                FROM analytics.vw_return_analysis
                GROUP BY category
            ) cat_summary
        ),
        'byReason', (
            SELECT json_agg(json_build_object(
                'reason', reason,
                'count', return_count
            ) ORDER BY return_count DESC)
            FROM (
                SELECT 
                    reason,
                    SUM(return_count) as return_count
                FROM analytics.vw_return_analysis
                GROUP BY reason
            ) reason_summary
        )
    );
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_pending_shipments_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(json_build_object(
            'orderId', order_id, 'orderDate', order_date, 'daysSince', days_since_order,
            'customer', customer_name, 'city', customer_city, 'amount', total_amount,
            'status', shipment_status, 'priority', priority
        ) ORDER BY days_since_order DESC)
        FROM analytics.vw_pending_shipments
        LIMIT 50
    );
END;
$$ LANGUAGE plpgsql STABLE;

\echo '      ✓ JSON functions created (5 functions)'

REFRESH MATERIALIZED VIEW analytics.mv_operations_summary;

\echo ''
\echo '============================================================================'
\echo '             OPERATIONS ANALYTICS MODULE - COMPLETE                         '
\echo '============================================================================'
\echo ''