-- ============================================================================
-- FILE: 04_alerts/business_alerts.sql
-- PROJECT: RetailMart Enterprise Analytics Platform
-- PURPOSE: Business Alerts - Automated monitoring and anomaly detection
-- AUTHOR: SQL Bootcamp
-- CREATED: 2025
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '               BUSINESS ALERTS MODULE - STARTING                            '
\echo '============================================================================'
\echo ''

\echo '[1/7] Creating alert: vw_alert_critical_stock...'

CREATE OR REPLACE VIEW analytics.vw_alert_critical_stock AS
SELECT 
    'CRITICAL_STOCK' as alert_type, 'HIGH' as severity,
    p.prod_id, p.prod_name, p.category, s.store_name, i.stock_qty as current_stock,
    'Product ' || p.prod_name || ' has only ' || i.stock_qty || ' units at ' || s.store_name as alert_message,
    'Urgent: Reorder immediately' as recommended_action
FROM products.inventory i
JOIN products.products p ON i.prod_id = p.prod_id
JOIN stores.stores s ON i.store_id = s.store_id
WHERE i.stock_qty < (SELECT analytics.get_config_number('alert_stock_critical'))
ORDER BY i.stock_qty;

\echo '      ✓ Alert view created: vw_alert_critical_stock'

\echo '[2/7] Creating alert: vw_alert_high_value_churn...'

CREATE OR REPLACE VIEW analytics.vw_alert_high_value_churn AS
SELECT 
    'HIGH_VALUE_CHURN' as alert_type, 'HIGH' as severity,
    cust_id, full_name, city, clv_tier, total_revenue as lifetime_value, days_since_last_order,
    'Platinum/Gold customer ' || full_name || ' inactive for ' || days_since_last_order || ' days' as alert_message,
    'Priority: Personal outreach with exclusive offer' as recommended_action
FROM analytics.mv_customer_lifetime_value
WHERE clv_tier IN ('Platinum', 'Gold')
AND days_since_last_order >= (SELECT analytics.get_config_number('alert_churn_days_platinum'))
AND total_orders > 0
ORDER BY total_revenue DESC;

\echo '      ✓ Alert view created: vw_alert_high_value_churn'

\echo '[3/7] Creating alert: vw_alert_revenue_anomaly...'

CREATE OR REPLACE VIEW analytics.vw_alert_revenue_anomaly AS
WITH daily_revenue AS (
    SELECT order_date, SUM(total_amount) as revenue
    FROM sales.orders WHERE order_status = 'Delivered' GROUP BY order_date
),
with_avg AS (
    SELECT order_date, revenue,
        AVG(revenue) OVER (ORDER BY order_date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) as avg_7day
    FROM daily_revenue
)
SELECT 
    'REVENUE_ANOMALY' as alert_type, 'MEDIUM' as severity,
    order_date, ROUND(revenue::NUMERIC, 2) as daily_revenue, ROUND(avg_7day::NUMERIC, 2) as seven_day_avg,
    ROUND(((revenue - avg_7day) / NULLIF(avg_7day, 0) * 100)::NUMERIC, 2) as variance_pct,
    'Revenue dropped ' || ABS(ROUND(((revenue - avg_7day) / NULLIF(avg_7day, 0) * 100)::NUMERIC, 0)) || '% below average' as alert_message,
    'Review for system issues or market factors' as recommended_action
FROM with_avg
WHERE revenue < avg_7day * 0.75
AND order_date >= (SELECT MAX(order_date) - INTERVAL '7 days' FROM sales.orders);

\echo '      ✓ Alert view created: vw_alert_revenue_anomaly'

\echo '[4/7] Creating alert: vw_alert_delayed_shipments...'

CREATE OR REPLACE VIEW analytics.vw_alert_delayed_shipments AS
SELECT 
    'DELAYED_SHIPMENT' as alert_type, 'MEDIUM' as severity,
    o.order_id, o.order_date,
    (SELECT MAX(order_date) FROM sales.orders) - o.order_date as days_since_order,
    c.full_name as customer_name, o.total_amount,
    'Order #' || o.order_id || ' pending for ' || ((SELECT MAX(order_date) FROM sales.orders) - o.order_date) || ' days' as alert_message,
    'Contact courier and update customer' as recommended_action
FROM sales.orders o
LEFT JOIN sales.shipments s ON o.order_id = s.order_id
JOIN customers.customers c ON o.cust_id = c.cust_id
WHERE o.order_status NOT IN ('Delivered', 'Cancelled')
AND (s.shipped_date IS NULL OR s.status = 'Pending')
AND (SELECT MAX(order_date) FROM sales.orders) - o.order_date >= 3
ORDER BY o.total_amount DESC;

\echo '      ✓ Alert view created: vw_alert_delayed_shipments'

\echo '[5/7] Creating alert: vw_alert_high_return_rate...'

CREATE OR REPLACE VIEW analytics.vw_alert_high_return_rate AS
WITH category_returns AS (
    SELECT p.category, COUNT(DISTINCT r.return_id) as returns, COUNT(DISTINCT oi.order_id) as orders
    FROM products.products p
    JOIN sales.order_items oi ON p.prod_id = oi.prod_id
    JOIN sales.orders o ON oi.order_id = o.order_id AND o.order_status = 'Delivered'
    LEFT JOIN sales.returns r ON oi.order_id = r.order_id AND oi.prod_id = r.prod_id
    GROUP BY p.category
)
SELECT 
    'HIGH_RETURN_RATE' as alert_type, 'LOW' as severity,
    category, returns as return_count, orders as order_count,
    ROUND((returns::NUMERIC / NULLIF(orders, 0) * 100), 2) as return_rate_pct,
    'Category ' || category || ' has ' || ROUND((returns::NUMERIC / NULLIF(orders, 0) * 100), 1) || '% return rate' as alert_message,
    'Investigate product quality and descriptions' as recommended_action
FROM category_returns
WHERE (returns::NUMERIC / NULLIF(orders, 0) * 100) >= 15;

\echo '      ✓ Alert view created: vw_alert_high_return_rate'

\echo '[6/7] Creating alert: vw_alert_low_stock...'

CREATE OR REPLACE VIEW analytics.vw_alert_low_stock AS
SELECT 
    'LOW_STOCK' as alert_type, 'LOW' as severity,
    p.prod_id, p.prod_name, p.category, SUM(i.stock_qty) as total_stock,
    'Product ' || p.prod_name || ' has only ' || SUM(i.stock_qty) || ' units' as alert_message,
    'Monitor and consider reordering' as recommended_action
FROM products.products p
JOIN products.inventory i ON p.prod_id = i.prod_id
GROUP BY p.prod_id, p.prod_name, p.category
HAVING SUM(i.stock_qty) BETWEEN 10 AND 50;

\echo '      ✓ Alert view created: vw_alert_low_stock'

\echo '[7/7] Creating consolidated alert view...'

CREATE OR REPLACE VIEW analytics.vw_all_active_alerts AS
SELECT alert_type, severity, alert_message, recommended_action, prod_name as entity_name, current_stock::TEXT as metric FROM analytics.vw_alert_critical_stock
UNION ALL SELECT alert_type, severity, alert_message, recommended_action, full_name, days_since_last_order::TEXT FROM analytics.vw_alert_high_value_churn
UNION ALL SELECT alert_type, severity, alert_message, recommended_action, order_date::TEXT, variance_pct::TEXT FROM analytics.vw_alert_revenue_anomaly
UNION ALL SELECT alert_type, severity, alert_message, recommended_action, 'Order #' || order_id, days_since_order::TEXT FROM analytics.vw_alert_delayed_shipments
UNION ALL SELECT alert_type, severity, alert_message, recommended_action, category, return_rate_pct::TEXT FROM analytics.vw_alert_high_return_rate
UNION ALL SELECT alert_type, severity, alert_message, recommended_action, prod_name, total_stock::TEXT FROM analytics.vw_alert_low_stock;

\echo '      ✓ Consolidated alert view created'

CREATE OR REPLACE FUNCTION analytics.get_all_alerts_json() RETURNS JSON AS $$
BEGIN RETURN (
    SELECT json_build_object(
        'summary', (SELECT json_agg(json_build_object('severity', severity, 'count', cnt)) FROM (SELECT severity, COUNT(*) as cnt FROM analytics.vw_all_active_alerts GROUP BY severity) s),
        'alerts', (SELECT json_agg(json_build_object('type', alert_type, 'severity', severity, 'message', alert_message, 'action', recommended_action, 'entity', entity_name)) FROM analytics.vw_all_active_alerts LIMIT 50)
    )
); END;
$$ LANGUAGE plpgsql STABLE;

\echo ''
\echo '============================================================================'
\echo '               BUSINESS ALERTS MODULE - COMPLETE                            '
\echo '============================================================================'
