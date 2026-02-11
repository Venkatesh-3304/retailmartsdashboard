-- ============================================================================
-- FILE: 01_setup/03_create_indexes.sql
-- PROJECT: RetailMart Enterprise Analytics Platform
-- PURPOSE: Create performance indexes on source tables for analytics queries
-- AUTHOR: SQL Bootcamp
-- CREATED: 2025
--
-- DESCRIPTION:
--   Analytics queries scan large amounts of data. Without proper indexes,
--   a simple dashboard refresh could take minutes instead of seconds.
--
--   Real-world example: Zomato's analytics queries scan millions of orders.
--   Proper indexes reduce query time from 30 seconds to under 1 second.
--
-- INDEX STRATEGY:
--   1. Date columns - Most analytics filter by date range
--   2. Foreign keys - JOINs use these extensively  
--   3. Status columns - Filter by order_status, payment_status
--   4. Composite indexes - For common WHERE + ORDER BY combinations
--
-- EXECUTION ORDER: Run AFTER 02_create_metadata_tables.sql
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '         RETAILMART ENTERPRISE ANALYTICS - PERFORMANCE INDEXES              '
\echo '============================================================================'
\echo ''

-- ============================================================================
-- SALES SCHEMA INDEXES
-- ============================================================================

\echo '[1/6] Creating indexes on sales schema...'

-- Orders table - Most queried table in analytics
CREATE INDEX IF NOT EXISTS idx_orders_date 
    ON sales.orders(order_date DESC);
    
CREATE INDEX IF NOT EXISTS idx_orders_status 
    ON sales.orders(order_status);
    
CREATE INDEX IF NOT EXISTS idx_orders_cust 
    ON sales.orders(cust_id);
    
CREATE INDEX IF NOT EXISTS idx_orders_store 
    ON sales.orders(store_id);

-- Composite index for common analytics query pattern
CREATE INDEX IF NOT EXISTS idx_orders_date_status 
    ON sales.orders(order_date DESC, order_status);

CREATE INDEX IF NOT EXISTS idx_orders_store_date 
    ON sales.orders(store_id, order_date DESC);

-- Order items - Second most queried
CREATE INDEX IF NOT EXISTS idx_order_items_order 
    ON sales.order_items(order_id);
    
CREATE INDEX IF NOT EXISTS idx_order_items_product 
    ON sales.order_items(prod_id);

-- Payments
CREATE INDEX IF NOT EXISTS idx_payments_order 
    ON sales.payments(order_id);
    
CREATE INDEX IF NOT EXISTS idx_payments_date 
    ON sales.payments(payment_date DESC);
    
CREATE INDEX IF NOT EXISTS idx_payments_mode 
    ON sales.payments(payment_mode);

-- Shipments
CREATE INDEX IF NOT EXISTS idx_shipments_order 
    ON sales.shipments(order_id);
    
CREATE INDEX IF NOT EXISTS idx_shipments_status 
    ON sales.shipments(status);
    
CREATE INDEX IF NOT EXISTS idx_shipments_shipped 
    ON sales.shipments(shipped_date DESC);
    
CREATE INDEX IF NOT EXISTS idx_shipments_delivered 
    ON sales.shipments(delivered_date DESC);

-- Returns
CREATE INDEX IF NOT EXISTS idx_returns_order 
    ON sales.returns(order_id);
    
CREATE INDEX IF NOT EXISTS idx_returns_product 
    ON sales.returns(prod_id);
    
CREATE INDEX IF NOT EXISTS idx_returns_date 
    ON sales.returns(return_date DESC);

\echo '      ✓ Sales indexes created (17 indexes)'


-- ============================================================================
-- CUSTOMERS SCHEMA INDEXES
-- ============================================================================

\echo '[2/6] Creating indexes on customers schema...'

-- Customers table
CREATE INDEX IF NOT EXISTS idx_customers_join_date 
    ON customers.customers(join_date DESC);
    
CREATE INDEX IF NOT EXISTS idx_customers_city 
    ON customers.customers(city);
    
CREATE INDEX IF NOT EXISTS idx_customers_state 
    ON customers.customers(state);
    
CREATE INDEX IF NOT EXISTS idx_customers_region 
    ON customers.customers(region_name);

-- Reviews
CREATE INDEX IF NOT EXISTS idx_reviews_cust 
    ON customers.reviews(cust_id);
    
CREATE INDEX IF NOT EXISTS idx_reviews_product 
    ON customers.reviews(prod_id);
    
CREATE INDEX IF NOT EXISTS idx_reviews_date 
    ON customers.reviews(review_date DESC);
    
CREATE INDEX IF NOT EXISTS idx_reviews_rating 
    ON customers.reviews(rating);

-- Loyalty points
CREATE INDEX IF NOT EXISTS idx_loyalty_updated 
    ON customers.loyalty_points(last_updated DESC);

\echo '      ✓ Customers indexes created (9 indexes)'


-- ============================================================================
-- PRODUCTS SCHEMA INDEXES
-- ============================================================================

\echo '[3/6] Creating indexes on products schema...'

-- Products
CREATE INDEX IF NOT EXISTS idx_products_category 
    ON products.products(category);
    
CREATE INDEX IF NOT EXISTS idx_products_brand 
    ON products.products(brand);
    
CREATE INDEX IF NOT EXISTS idx_products_supplier 
    ON products.products(supplier_id);
    
CREATE INDEX IF NOT EXISTS idx_products_price 
    ON products.products(price);

-- Inventory
CREATE INDEX IF NOT EXISTS idx_inventory_store 
    ON products.inventory(store_id);
    
CREATE INDEX IF NOT EXISTS idx_inventory_product 
    ON products.inventory(prod_id);
    
CREATE INDEX IF NOT EXISTS idx_inventory_stock 
    ON products.inventory(stock_qty);
    
CREATE INDEX IF NOT EXISTS idx_inventory_updated 
    ON products.inventory(last_updated DESC);

-- Promotions
CREATE INDEX IF NOT EXISTS idx_promotions_dates 
    ON products.promotions(start_date, end_date);

\echo '      ✓ Products indexes created (9 indexes)'


-- ============================================================================
-- STORES SCHEMA INDEXES
-- ============================================================================

\echo '[4/6] Creating indexes on stores schema...'

-- Stores
CREATE INDEX IF NOT EXISTS idx_stores_city 
    ON stores.stores(city);
    
CREATE INDEX IF NOT EXISTS idx_stores_state 
    ON stores.stores(state);
    
CREATE INDEX IF NOT EXISTS idx_stores_region 
    ON stores.stores(region);

-- Employees
CREATE INDEX IF NOT EXISTS idx_employees_store 
    ON stores.employees(store_id);
    
CREATE INDEX IF NOT EXISTS idx_employees_dept 
    ON stores.employees(dept_id);
    
CREATE INDEX IF NOT EXISTS idx_employees_role 
    ON stores.employees(role);

-- Store Expenses
CREATE INDEX IF NOT EXISTS idx_store_expenses_store 
    ON stores.expenses(store_id);
    
CREATE INDEX IF NOT EXISTS idx_store_expenses_date 
    ON stores.expenses(expense_date DESC);
    
CREATE INDEX IF NOT EXISTS idx_store_expenses_type 
    ON stores.expenses(expense_type);

\echo '      ✓ Stores indexes created (9 indexes)'


-- ============================================================================
-- MARKETING SCHEMA INDEXES
-- ============================================================================

\echo '[5/6] Creating indexes on marketing schema...'

-- Campaigns
CREATE INDEX IF NOT EXISTS idx_campaigns_dates 
    ON marketing.campaigns(start_date, end_date);

-- Ad Spend
CREATE INDEX IF NOT EXISTS idx_ads_campaign 
    ON marketing.ads_spend(campaign_id);
    
CREATE INDEX IF NOT EXISTS idx_ads_channel 
    ON marketing.ads_spend(channel);

-- Email Clicks
CREATE INDEX IF NOT EXISTS idx_email_cust 
    ON marketing.email_clicks(cust_id);
    
CREATE INDEX IF NOT EXISTS idx_email_campaign 
    ON marketing.email_clicks(campaign_id);
    
CREATE INDEX IF NOT EXISTS idx_email_date 
    ON marketing.email_clicks(sent_date DESC);

\echo '      ✓ Marketing indexes created (6 indexes)'


-- ============================================================================
-- CORE/DIMENSION SCHEMA INDEXES
-- ============================================================================

\echo '[6/6] Creating indexes on core dimensions...'

-- Date dimension
CREATE INDEX IF NOT EXISTS idx_dimdate_year 
    ON core.dim_date(year);
    
CREATE INDEX IF NOT EXISTS idx_dimdate_month 
    ON core.dim_date(year, month);
    
CREATE INDEX IF NOT EXISTS idx_dimdate_quarter 
    ON core.dim_date(year, quarter);

\echo '      ✓ Core indexes created (3 indexes)'


-- ============================================================================
-- ANALYZE TABLES
-- ============================================================================
-- After creating indexes, run ANALYZE to update statistics
-- This helps the query planner make better decisions

\echo ''
\echo 'Updating table statistics...'

ANALYZE sales.orders;
ANALYZE sales.order_items;
ANALYZE sales.payments;
ANALYZE sales.shipments;
ANALYZE sales.returns;
ANALYZE customers.customers;
ANALYZE customers.reviews;
ANALYZE products.products;
ANALYZE products.inventory;
ANALYZE stores.stores;
ANALYZE stores.employees;
ANALYZE marketing.campaigns;
ANALYZE marketing.ads_spend;

\echo '✓ Table statistics updated'


-- ============================================================================
-- VERIFICATION
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '                 PERFORMANCE INDEXES SETUP COMPLETE                         '
\echo '============================================================================'
\echo ''
\echo '✅ Indexes Created:'
\echo '   • Sales schema:     17 indexes'
\echo '   • Customers schema:  9 indexes'
\echo '   • Products schema:   9 indexes'
\echo '   • Stores schema:     9 indexes'
\echo '   • Marketing schema:  6 indexes'
\echo '   • Core schema:       3 indexes'
\echo '   ─────────────────────────────'
\echo '   • TOTAL:            53 indexes'
\echo ''
\echo '📊 Index Usage Query:'
\echo '   SELECT schemaname, tablename, indexname, idx_scan'
\echo '   FROM pg_stat_user_indexes'
\echo '   ORDER BY idx_scan DESC;'
\echo ''
\echo '➡️  Next: Run 02_data_quality/data_quality_checks.sql'
\echo '============================================================================'
\echo ''

-- Show index count by schema
SELECT 
    schemaname as schema,
    COUNT(*) as index_count
FROM pg_indexes
WHERE schemaname IN ('sales', 'customers', 'products', 'stores', 'marketing', 'core', 'analytics')
GROUP BY schemaname
ORDER BY index_count DESC;
