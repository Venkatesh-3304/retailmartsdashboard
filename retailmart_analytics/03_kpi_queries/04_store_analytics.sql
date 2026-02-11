-- ============================================================================
-- FILE: 03_kpi_queries/04_store_analytics.sql
-- PROJECT: RetailMart Enterprise Analytics Platform
-- PURPOSE: Store Analytics Module - Store performance and profitability tracking
-- AUTHOR: SQL Bootcamp
-- CREATED: 2025
--
-- DESCRIPTION:
--   At DMart, every month leadership asks: "Which stores are stars? Which need help?"
--   This module provides store-level P&L, regional comparisons, and efficiency metrics.
--
-- CREATES:
--   • 3 Regular Views
--   • 1 Materialized View
--   • 4 JSON Export Functions
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '               STORE ANALYTICS MODULE - STARTING                            '
\echo '============================================================================'
\echo ''

-- ============================================================================
-- MATERIALIZED VIEW: STORE PERFORMANCE
-- ============================================================================

\echo '[1/4] Creating materialized view: mv_store_performance...'

DROP MATERIALIZED VIEW IF EXISTS analytics.mv_store_performance CASCADE;

CREATE MATERIALIZED VIEW analytics.mv_store_performance AS
WITH store_sales AS (
    SELECT 
        s.store_id, s.store_name, s.city, s.state, s.region,
        COUNT(DISTINCT o.order_id) as total_orders,
        SUM(o.total_amount) as total_revenue,
        AVG(o.total_amount) as avg_order_value,
        COUNT(DISTINCT o.cust_id) as unique_customers
    FROM stores.stores s
    LEFT JOIN sales.orders o ON s.store_id = o.store_id AND o.order_status = 'Delivered'
    GROUP BY s.store_id, s.store_name, s.city, s.state, s.region
),
store_expenses AS (
    SELECT store_id, SUM(amount) as total_expenses
    FROM stores.expenses
    GROUP BY store_id
),
store_employees AS (
    SELECT store_id, COUNT(*) as employee_count, SUM(salary) as total_payroll
    FROM stores.employees
    GROUP BY store_id
)
SELECT 
    ss.store_id, ss.store_name, ss.city, ss.state, ss.region,
    ss.total_orders, 
    ROUND(COALESCE(ss.total_revenue, 0)::NUMERIC, 2) as total_revenue,
    ROUND(COALESCE(ss.avg_order_value, 0)::NUMERIC, 2) as avg_order_value,
    ss.unique_customers,
    ROUND(COALESCE(se.total_expenses, 0)::NUMERIC, 2) as total_expenses,
    ROUND((COALESCE(ss.total_revenue, 0) - COALESCE(se.total_expenses, 0))::NUMERIC, 2) as net_profit,
    ROUND(((COALESCE(ss.total_revenue, 0) - COALESCE(se.total_expenses, 0)) / 
           NULLIF(ss.total_revenue, 0) * 100)::NUMERIC, 2) as profit_margin_pct,
    COALESCE(emp.employee_count, 0) as employee_count,
    ROUND(COALESCE(emp.total_payroll, 0)::NUMERIC, 2) as total_payroll,
    ROUND((COALESCE(ss.total_revenue, 0) / NULLIF(emp.employee_count, 0))::NUMERIC, 2) as revenue_per_employee,
    RANK() OVER (ORDER BY ss.total_revenue DESC NULLS LAST) as revenue_rank,
    RANK() OVER (ORDER BY (COALESCE(ss.total_revenue, 0) - COALESCE(se.total_expenses, 0)) DESC) as profit_rank,
    CASE 
        WHEN PERCENT_RANK() OVER (ORDER BY ss.total_revenue NULLS FIRST) >= 0.8 THEN 'Star'
        WHEN PERCENT_RANK() OVER (ORDER BY ss.total_revenue NULLS FIRST) >= 0.5 THEN 'Average'
        WHEN PERCENT_RANK() OVER (ORDER BY ss.total_revenue NULLS FIRST) >= 0.2 THEN 'Improving'
        ELSE 'Needs Attention'
    END as performance_tier
FROM store_sales ss
LEFT JOIN store_expenses se ON ss.store_id = se.store_id
LEFT JOIN store_employees emp ON ss.store_id = emp.store_id;

CREATE INDEX IF NOT EXISTS idx_store_perf_region ON analytics.mv_store_performance(region);

\echo '      ✓ Materialized view created: mv_store_performance'


-- ============================================================================
-- VIEW 1: REGIONAL PERFORMANCE
-- ============================================================================

\echo '[2/4] Creating view: vw_regional_performance...'

CREATE OR REPLACE VIEW analytics.vw_regional_performance AS
SELECT 
    region,
    COUNT(DISTINCT store_id) as store_count,
    SUM(total_orders) as total_orders,
    ROUND(SUM(total_revenue)::NUMERIC, 2) as total_revenue,
    ROUND(AVG(avg_order_value)::NUMERIC, 2) as avg_order_value,
    SUM(unique_customers) as total_customers,
    ROUND(SUM(total_expenses)::NUMERIC, 2) as total_expenses,
    ROUND(SUM(net_profit)::NUMERIC, 2) as total_profit,
    ROUND(AVG(profit_margin_pct)::NUMERIC, 2) as avg_profit_margin,
    SUM(employee_count) as total_employees,
    ROUND((SUM(total_revenue) / NULLIF(SUM(employee_count), 0))::NUMERIC, 2) as revenue_per_employee,
    ROUND((SUM(total_revenue) / COUNT(DISTINCT store_id))::NUMERIC, 2) as avg_revenue_per_store
FROM analytics.mv_store_performance
GROUP BY region
ORDER BY total_revenue DESC;

\echo '      ✓ View created: vw_regional_performance'


-- ============================================================================
-- VIEW 2: STORE INVENTORY STATUS
-- ============================================================================

\echo '[3/4] Creating view: vw_store_inventory_status...'

CREATE OR REPLACE VIEW analytics.vw_store_inventory_status AS
SELECT 
    s.store_id, s.store_name, s.city, s.region,
    COUNT(DISTINCT i.prod_id) as products_stocked,
    SUM(i.stock_qty) as total_units,
    SUM(i.stock_qty * p.price) as inventory_value,
    COUNT(*) FILTER (WHERE i.stock_qty = 0) as out_of_stock_count,
    COUNT(*) FILTER (WHERE i.stock_qty < 10 AND i.stock_qty > 0) as low_stock_count,
    CASE 
        WHEN COUNT(*) FILTER (WHERE i.stock_qty = 0) > 20 THEN 'Critical'
        WHEN COUNT(*) FILTER (WHERE i.stock_qty < 10) > 50 THEN 'Warning'
        ELSE 'Healthy'
    END as inventory_health
FROM stores.stores s
LEFT JOIN products.inventory i ON s.store_id = i.store_id
LEFT JOIN products.products p ON i.prod_id = p.prod_id
GROUP BY s.store_id, s.store_name, s.city, s.region
ORDER BY inventory_value DESC;

\echo '      ✓ View created: vw_store_inventory_status'


-- ============================================================================
-- VIEW 3: EMPLOYEE BY STORE
-- ============================================================================

\echo '[4/4] Creating view: vw_employee_by_store...'

CREATE OR REPLACE VIEW analytics.vw_employee_by_store AS
SELECT 
    s.store_id, s.store_name, s.city, s.region,
    COUNT(e.emp_id) as employee_count,
    ROUND(SUM(e.salary)::NUMERIC, 2) as total_payroll,
    ROUND(AVG(e.salary)::NUMERIC, 2) as avg_salary,
    COUNT(DISTINCT e.role) as unique_roles,
    STRING_AGG(DISTINCT e.role, ', ') as roles
FROM stores.stores s
LEFT JOIN stores.employees e ON s.store_id = e.store_id
GROUP BY s.store_id, s.store_name, s.city, s.region
ORDER BY total_payroll DESC;

\echo '      ✓ View created: vw_employee_by_store'


-- ============================================================================
-- JSON EXPORT FUNCTIONS
-- ============================================================================

\echo ''
\echo 'Creating JSON export functions...'

CREATE OR REPLACE FUNCTION analytics.get_top_stores_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(json_build_object(
            'storeId', store_id, 'storeName', store_name, 'city', city, 'region', region,
            'revenue', total_revenue, 'profit', net_profit, 'profitMargin', profit_margin_pct,
            'orders', total_orders, 'employees', employee_count, 'performanceTier', performance_tier,
            'revenueRank', revenue_rank
        ) ORDER BY revenue_rank)
        FROM analytics.mv_store_performance
        LIMIT 20
    );
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_regional_performance_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(json_build_object(
            'region', region, 'storeCount', store_count, 'revenue', total_revenue,
            'profit', total_profit, 'avgProfitMargin', avg_profit_margin,
            'employees', total_employees, 'revenuePerEmployee', revenue_per_employee
        ) ORDER BY total_revenue DESC)
        FROM analytics.vw_regional_performance
    );
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_store_inventory_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(json_build_object(
            'storeName', store_name, 'city', city, 'region', region,
            'productsStocked', products_stocked, 'inventoryValue', ROUND(inventory_value::NUMERIC, 2),
            'outOfStock', out_of_stock_count, 'lowStock', low_stock_count, 'health', inventory_health
        ) ORDER BY inventory_value DESC)
        FROM analytics.vw_store_inventory_status
        LIMIT 20
    );
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_employee_distribution_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(json_build_object(
            'storeName', store_name, 'city', city, 'region', region,
            'employees', employee_count, 'totalPayroll', total_payroll, 'avgSalary', avg_salary
        ) ORDER BY total_payroll DESC)
        FROM analytics.vw_employee_by_store
        LIMIT 20
    );
END;
$$ LANGUAGE plpgsql STABLE;

\echo '      ✓ JSON functions created (4 functions)'

REFRESH MATERIALIZED VIEW analytics.mv_store_performance;

\echo ''
\echo '============================================================================'
\echo '               STORE ANALYTICS MODULE - COMPLETE                            '
\echo '============================================================================'
\echo ''
