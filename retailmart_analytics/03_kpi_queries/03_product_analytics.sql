-- ============================================================================
-- FILE: 03_kpi_queries/03_product_analytics.sql
-- PROJECT: RetailMart Enterprise Analytics Platform
-- PURPOSE: Product Analytics Module - Complete product performance tracking
-- AUTHOR: SQL Bootcamp
-- CREATED: 2025
--
-- DESCRIPTION:
--   "80% of your revenue comes from 20% of your products" - Pareto Principle
--   
--   This module answers:
--   - What are our best sellers? (Top Products)
--   - Which products drive most revenue? (ABC Analysis)
--   - How are categories performing? (Category Analysis)
--   - Which brands dominate? (Brand Analysis)
--   - Is inventory moving fast enough? (Inventory Turnover)
--
-- CREATES:
--   • 3 Regular Views
--   • 2 Materialized Views
--   • 5 JSON Export Functions
--
-- EXECUTION ORDER: Run AFTER 02_customer_analytics.sql
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '              PRODUCT ANALYTICS MODULE - STARTING                           '
\echo '============================================================================'
\echo ''

-- ============================================================================
-- MATERIALIZED VIEW 1: TOP PRODUCTS
-- ============================================================================

\echo '[1/5] Creating materialized view: mv_top_products...'

DROP MATERIALIZED VIEW IF EXISTS analytics.mv_top_products CASCADE;

CREATE MATERIALIZED VIEW analytics.mv_top_products AS
WITH product_sales AS (
    SELECT 
        p.prod_id,
        p.prod_name,
        p.category,
        p.brand,
        p.price as list_price,
        COUNT(DISTINCT oi.order_id) as times_ordered,
        SUM(oi.quantity) as total_units_sold,
        SUM(oi.quantity * oi.unit_price) as gross_revenue,
        SUM(oi.quantity * oi.unit_price * oi.discount / 100) as total_discounts,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount / 100)) as net_revenue,
        AVG(oi.unit_price) as avg_selling_price,
        AVG(oi.discount) as avg_discount_pct
    FROM products.products p
    JOIN sales.order_items oi ON p.prod_id = oi.prod_id
    JOIN sales.orders o ON oi.order_id = o.order_id AND o.order_status = 'Delivered'
    GROUP BY p.prod_id, p.prod_name, p.category, p.brand, p.price
),
product_reviews AS (
    SELECT prod_id, COUNT(*) as review_count, ROUND(AVG(rating), 2) as avg_rating
    FROM customers.reviews
    GROUP BY prod_id
),
product_inventory AS (
    SELECT prod_id, SUM(stock_qty) as total_stock, COUNT(DISTINCT store_id) as stores_stocking
    FROM products.inventory
    GROUP BY prod_id
)
SELECT 
    ps.prod_id,
    ps.prod_name,
    ps.category,
    ps.brand,
    ROUND(ps.list_price::NUMERIC, 2) as list_price,
    ps.times_ordered,
    ps.total_units_sold,
    ROUND(ps.gross_revenue::NUMERIC, 2) as gross_revenue,
    ROUND(ps.total_discounts::NUMERIC, 2) as total_discounts,
    ROUND(ps.net_revenue::NUMERIC, 2) as net_revenue,
    ROUND(ps.avg_selling_price::NUMERIC, 2) as avg_selling_price,
    ROUND(ps.avg_discount_pct::NUMERIC, 2) as avg_discount_pct,
    COALESCE(pr.review_count, 0) as review_count,
    COALESCE(pr.avg_rating, 0) as avg_rating,
    COALESCE(pi.total_stock, 0) as current_stock,
    COALESCE(pi.stores_stocking, 0) as stores_stocking,
    RANK() OVER (ORDER BY ps.net_revenue DESC) as revenue_rank,
    RANK() OVER (ORDER BY ps.total_units_sold DESC) as units_rank,
    RANK() OVER (PARTITION BY ps.category ORDER BY ps.net_revenue DESC) as category_rank,
    ROUND((ps.net_revenue / SUM(ps.net_revenue) OVER () * 100)::NUMERIC, 4) as pct_of_total_revenue
FROM product_sales ps
LEFT JOIN product_reviews pr ON ps.prod_id = pr.prod_id
LEFT JOIN product_inventory pi ON ps.prod_id = pi.prod_id;

CREATE INDEX IF NOT EXISTS idx_top_products_category ON analytics.mv_top_products(category);
CREATE INDEX IF NOT EXISTS idx_top_products_rank ON analytics.mv_top_products(revenue_rank);

\echo '      ✓ Materialized view created: mv_top_products'


-- ============================================================================
-- MATERIALIZED VIEW 2: ABC ANALYSIS (Pareto)
-- ============================================================================

\echo '[2/5] Creating materialized view: mv_abc_analysis...'

DROP MATERIALIZED VIEW IF EXISTS analytics.mv_abc_analysis CASCADE;

CREATE MATERIALIZED VIEW analytics.mv_abc_analysis AS
WITH product_revenue AS (
    SELECT 
        p.prod_id,
        p.prod_name,
        p.category,
        p.brand,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount / 100)) as net_revenue
    FROM products.products p
    JOIN sales.order_items oi ON p.prod_id = oi.prod_id
    JOIN sales.orders o ON oi.order_id = o.order_id AND o.order_status = 'Delivered'
    GROUP BY p.prod_id, p.prod_name, p.category, p.brand
),
with_cumulative AS (
    SELECT 
        *,
        SUM(net_revenue) OVER (ORDER BY net_revenue DESC) as cumulative_revenue,
        SUM(net_revenue) OVER () as total_revenue
    FROM product_revenue
)
SELECT 
    prod_id,
    prod_name,
    category,
    brand,
    ROUND(net_revenue::NUMERIC, 2) as net_revenue,
    ROUND((net_revenue / total_revenue * 100)::NUMERIC, 4) as pct_of_revenue,
    ROUND((cumulative_revenue / total_revenue * 100)::NUMERIC, 2) as cumulative_pct,
    CASE 
        WHEN cumulative_revenue / total_revenue <= 0.80 THEN 'A'
        WHEN cumulative_revenue / total_revenue <= 0.95 THEN 'B'
        ELSE 'C'
    END as abc_classification,
    ROW_NUMBER() OVER (ORDER BY net_revenue DESC) as revenue_rank
FROM with_cumulative
ORDER BY net_revenue DESC;

\echo '      ✓ Materialized view created: mv_abc_analysis'


-- ============================================================================
-- VIEW 1: CATEGORY PERFORMANCE
-- ============================================================================

\echo '[3/5] Creating view: vw_category_performance...'

CREATE OR REPLACE VIEW analytics.vw_category_performance AS
WITH category_stats AS (
    SELECT 
        p.category,
        COUNT(DISTINCT p.prod_id) as product_count,
        COUNT(DISTINCT oi.order_id) as order_count,
        SUM(oi.quantity) as units_sold,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount / 100)) as net_revenue,
        AVG(oi.unit_price) as avg_price,
        AVG(oi.discount) as avg_discount_pct
    FROM products.products p
    JOIN sales.order_items oi ON p.prod_id = oi.prod_id
    JOIN sales.orders o ON oi.order_id = o.order_id AND o.order_status = 'Delivered'
    GROUP BY p.category
),
category_reviews AS (
    SELECT p.category, COUNT(*) as total_reviews, AVG(r.rating) as avg_rating
    FROM customers.reviews r
    JOIN products.products p ON r.prod_id = p.prod_id
    GROUP BY p.category
)
SELECT 
    cs.category,
    cs.product_count,
    cs.order_count,
    cs.units_sold,
    ROUND(cs.net_revenue::NUMERIC, 2) as net_revenue,
    ROUND(cs.avg_price::NUMERIC, 2) as avg_price,
    ROUND(cs.avg_discount_pct::NUMERIC, 2) as avg_discount_pct,
    COALESCE(cr.total_reviews, 0) as total_reviews,
    ROUND(COALESCE(cr.avg_rating, 0)::NUMERIC, 2) as avg_rating,
    ROUND((cs.net_revenue / SUM(cs.net_revenue) OVER () * 100)::NUMERIC, 2) as market_share_pct,
    RANK() OVER (ORDER BY cs.net_revenue DESC) as revenue_rank
FROM category_stats cs
LEFT JOIN category_reviews cr ON cs.category = cr.category
ORDER BY net_revenue DESC;

\echo '      ✓ View created: vw_category_performance'


-- ============================================================================
-- VIEW 2: BRAND PERFORMANCE
-- ============================================================================

\echo '[4/5] Creating view: vw_brand_performance...'

CREATE OR REPLACE VIEW analytics.vw_brand_performance AS
SELECT 
    brand,
    category,
    COUNT(DISTINCT prod_id) as product_count,
    SUM(total_units_sold) as total_units_sold,
    ROUND(SUM(net_revenue)::NUMERIC, 2) as net_revenue,
    ROUND(AVG(avg_rating)::NUMERIC, 2) as avg_rating,
    SUM(review_count) as review_count,
    ROUND((SUM(net_revenue) / SUM(SUM(net_revenue)) OVER (PARTITION BY category) * 100)::NUMERIC, 2) as category_market_share_pct,
    RANK() OVER (PARTITION BY category ORDER BY SUM(net_revenue) DESC) as category_rank
FROM analytics.mv_top_products
GROUP BY brand, category
ORDER BY net_revenue DESC;

\echo '      ✓ View created: vw_brand_performance'


-- ============================================================================
-- VIEW 3: INVENTORY TURNOVER
-- ============================================================================

\echo '[5/5] Creating view: vw_inventory_turnover...'

CREATE OR REPLACE VIEW analytics.vw_inventory_turnover AS
WITH product_velocity AS (
    SELECT 
        p.prod_id,
        p.prod_name,
        p.category,
        i.stock_qty as current_stock,
        COALESCE(SUM(oi.quantity), 0) as units_sold_30d
    FROM products.products p
    LEFT JOIN products.inventory i ON p.prod_id = i.prod_id
    LEFT JOIN sales.order_items oi ON p.prod_id = oi.prod_id
    LEFT JOIN sales.orders o ON oi.order_id = o.order_id 
        AND o.order_status = 'Delivered'
        AND o.order_date >= (SELECT MAX(order_date) - INTERVAL '30 days' FROM sales.orders)
    GROUP BY p.prod_id, p.prod_name, p.category, i.stock_qty
)
SELECT 
    prod_id,
    prod_name,
    category,
    COALESCE(current_stock, 0) as current_stock,
    units_sold_30d,
    ROUND(units_sold_30d / 30.0, 2) as daily_velocity,
    CASE 
        WHEN units_sold_30d > 0 THEN ROUND(COALESCE(current_stock, 0) / (units_sold_30d / 30.0), 0)
        ELSE 9999
    END as days_of_inventory,
    CASE 
        WHEN COALESCE(current_stock, 0) = 0 THEN 'Out of Stock'
        WHEN units_sold_30d = 0 THEN 'Dead Stock'
        WHEN COALESCE(current_stock, 0) / NULLIF(units_sold_30d / 30.0, 0) < 7 THEN 'Low Stock'
        WHEN COALESCE(current_stock, 0) / NULLIF(units_sold_30d / 30.0, 0) > 90 THEN 'Overstocked'
        ELSE 'Normal'
    END as stock_status
FROM product_velocity
ORDER BY days_of_inventory;

\echo '      ✓ View created: vw_inventory_turnover'


-- ============================================================================
-- JSON EXPORT FUNCTIONS
-- ============================================================================

\echo ''
\echo 'Creating JSON export functions...'

CREATE OR REPLACE FUNCTION analytics.get_top_products_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(
            json_build_object(
                'prodId', prod_id, 'productName', prod_name, 'category', category, 'brand', brand,
                'revenue', net_revenue, 'unitsSold', total_units_sold, 'avgRating', avg_rating,
                'currentStock', current_stock, 'revenueRank', revenue_rank, 'categoryRank', category_rank
            ) ORDER BY revenue_rank
        )
        FROM analytics.mv_top_products
        LIMIT 20
    );
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_category_performance_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(
            json_build_object(
                'category', category, 'productCount', product_count, 'revenue', net_revenue,
                'unitsSold', units_sold, 'avgPrice', avg_price, 'avgRating', avg_rating,
                'marketShare', market_share_pct, 'rank', revenue_rank
            ) ORDER BY revenue_rank
        )
        FROM analytics.vw_category_performance
    );
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_brand_performance_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(
            json_build_object(
                'brand', brand, 'category', category, 'productCount', product_count,
                'revenue', net_revenue, 'unitsSold', total_units_sold, 'avgRating', avg_rating,
                'categoryMarketShare', category_market_share_pct, 'categoryRank', category_rank
            ) ORDER BY net_revenue DESC
        )
        FROM analytics.vw_brand_performance
        LIMIT 20
    );
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_abc_analysis_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_build_object(
            'summary', (
                SELECT json_agg(json_build_object(
                    'class', abc_classification, 'productCount', cnt, 'totalRevenue', revenue, 'pctOfRevenue', pct
                ))
                FROM (
                    SELECT abc_classification, COUNT(*) as cnt, 
                           ROUND(SUM(net_revenue)::NUMERIC, 2) as revenue,
                           ROUND((SUM(net_revenue) / SUM(SUM(net_revenue)) OVER () * 100)::NUMERIC, 2) as pct
                    FROM analytics.mv_abc_analysis
                    GROUP BY abc_classification
                ) s
            ),
            'topAProducts', (
                SELECT json_agg(json_build_object('productName', prod_name, 'revenue', net_revenue, 'pct', pct_of_revenue))
                FROM analytics.mv_abc_analysis WHERE abc_classification = 'A' LIMIT 20
            )
        )
    );
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_inventory_status_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(json_build_object(
            'status', stock_status, 'productCount', cnt, 'pctOfProducts', pct
        ))
        FROM (
            SELECT stock_status, COUNT(*) as cnt,
                   ROUND((COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100), 2) as pct
            FROM analytics.vw_inventory_turnover
            GROUP BY stock_status
        ) s
    );
END;
$$ LANGUAGE plpgsql STABLE;

\echo '      ✓ JSON functions created (5 functions)'


-- Refresh MVs
REFRESH MATERIALIZED VIEW analytics.mv_top_products;
REFRESH MATERIALIZED VIEW analytics.mv_abc_analysis;

\echo ''
\echo '============================================================================'
\echo '              PRODUCT ANALYTICS MODULE - COMPLETE                           '
\echo '============================================================================'
\echo ''
