-- ============================================================================
-- FILE: 01_setup/02_create_metadata_tables.sql
-- PROJECT: RetailMart Enterprise Analytics Platform
-- PURPOSE: Create metadata tables for tracking KPIs and audit logging
-- AUTHOR: SQL Bootcamp
-- CREATED: 2025
--
-- DESCRIPTION:
--   Enterprise analytics requires tracking:
--   1. What KPIs exist and when they were last refreshed
--   2. Audit trail of all operations (who ran what, when, how long)
--   3. Execution history for performance monitoring
--
--   Real-world example: At Flipkart, every dashboard refresh is logged.
--   If a report shows wrong numbers, they can trace back exactly when
--   data was refreshed and by whom.
--
-- EXECUTION ORDER: Run AFTER 01_create_analytics_schema.sql
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '         RETAILMART ENTERPRISE ANALYTICS - METADATA TABLES                  '
\echo '============================================================================'
\echo ''

-- ============================================================================
-- TABLE 1: KPI METADATA
-- ============================================================================
-- This table is like a "data catalog" - it documents all KPIs in the system.
-- 
-- Real-world example: Swiggy has a data catalog (like Apache Atlas or AWS Glue)
-- that tracks every metric, who owns it, how it's calculated, and when it refreshes.
-- ============================================================================

\echo '[1/5] Creating KPI metadata table...'

DROP TABLE IF EXISTS analytics.kpi_metadata CASCADE;

CREATE TABLE analytics.kpi_metadata (
    kpi_id              SERIAL PRIMARY KEY,
    kpi_name            VARCHAR(100) UNIQUE NOT NULL,
    kpi_category        VARCHAR(50) NOT NULL,           -- Sales, Customer, Product, Store, Operations, Marketing
    kpi_type            VARCHAR(30) NOT NULL,           -- VIEW, MATERIALIZED_VIEW, FUNCTION, TABLE
    object_name         VARCHAR(100) NOT NULL,          -- Actual DB object name
    description         TEXT,
    business_question   TEXT,                           -- What question does this KPI answer?
    formula             TEXT,                           -- How is it calculated?
    source_tables       TEXT,                           -- Which tables feed this KPI?
    refresh_frequency   VARCHAR(30) DEFAULT 'DAILY',    -- HOURLY, DAILY, WEEKLY, REALTIME
    owner               VARCHAR(100) DEFAULT CURRENT_USER,
    last_refreshed      TIMESTAMP,
    last_row_count      BIGINT,
    avg_refresh_time_ms INTEGER,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for quick lookups
CREATE INDEX idx_kpi_category ON analytics.kpi_metadata(kpi_category);
CREATE INDEX idx_kpi_type ON analytics.kpi_metadata(kpi_type);
CREATE INDEX idx_kpi_active ON analytics.kpi_metadata(is_active);

COMMENT ON TABLE analytics.kpi_metadata IS 'Data catalog for all KPIs - tracks definitions, ownership, and refresh status';

\echo '      ✓ Table created: kpi_metadata'


-- ============================================================================
-- TABLE 2: EXECUTION LOG
-- ============================================================================
-- Tracks every analytics operation - refreshes, exports, queries.
-- Essential for troubleshooting and performance monitoring.
--
-- Real-world example: When Amazon's dashboard shows stale data, engineers
-- check the execution log to see if the refresh job failed.
-- ============================================================================

\echo '[2/5] Creating execution log table...'

DROP TABLE IF EXISTS analytics.execution_log CASCADE;

CREATE TABLE analytics.execution_log (
    log_id              SERIAL PRIMARY KEY,
    operation_type      VARCHAR(50) NOT NULL,           -- REFRESH, EXPORT, VALIDATE, ALERT_CHECK
    module_name         VARCHAR(50),                    -- Sales, Customer, Product, Store, etc.
    object_name         VARCHAR(100),                   -- Specific view/function name
    status              VARCHAR(20) NOT NULL,           -- SUCCESS, FAILED, PARTIAL, RUNNING
    rows_affected       BIGINT,
    execution_time_ms   INTEGER,
    started_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at        TIMESTAMP,
    executed_by         VARCHAR(50) DEFAULT CURRENT_USER,
    error_message       TEXT,
    error_detail        TEXT,
    server_info         JSONB                           -- Additional context (memory, CPU, etc.)
);

-- Create indexes for log analysis
CREATE INDEX idx_exec_log_operation ON analytics.execution_log(operation_type);
CREATE INDEX idx_exec_log_status ON analytics.execution_log(status);
CREATE INDEX idx_exec_log_started ON analytics.execution_log(started_at DESC);
CREATE INDEX idx_exec_log_module ON analytics.execution_log(module_name);

COMMENT ON TABLE analytics.execution_log IS 'Audit trail of all analytics operations for troubleshooting and monitoring';

\echo '      ✓ Table created: execution_log'


-- ============================================================================
-- TABLE 3: REFRESH HISTORY
-- ============================================================================
-- Summarized view of materialized view refreshes.
-- Used to track data freshness on dashboards.
-- ============================================================================

\echo '[3/5] Creating refresh history table...'

DROP TABLE IF EXISTS analytics.refresh_history CASCADE;

CREATE TABLE analytics.refresh_history (
    refresh_id          SERIAL PRIMARY KEY,
    refresh_batch_id    UUID DEFAULT gen_random_uuid(), -- Groups related refreshes
    view_name           VARCHAR(100) NOT NULL,
    refresh_type        VARCHAR(20) DEFAULT 'FULL',     -- FULL, INCREMENTAL, CONCURRENT
    started_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at        TIMESTAMP,
    duration_ms         INTEGER,
    rows_before         BIGINT,
    rows_after          BIGINT,
    status              VARCHAR(20) DEFAULT 'RUNNING',
    triggered_by        VARCHAR(50) DEFAULT CURRENT_USER,
    trigger_source      VARCHAR(50) DEFAULT 'MANUAL'    -- MANUAL, SCHEDULED, API
);

CREATE INDEX idx_refresh_view ON analytics.refresh_history(view_name);
CREATE INDEX idx_refresh_status ON analytics.refresh_history(status);
CREATE INDEX idx_refresh_started ON analytics.refresh_history(started_at DESC);

COMMENT ON TABLE analytics.refresh_history IS 'History of materialized view refreshes for data freshness tracking';

\echo '      ✓ Table created: refresh_history'


-- ============================================================================
-- TABLE 4: DATA QUALITY ISSUES
-- ============================================================================
-- Stores data quality issues found during validation checks.
-- Critical for enterprise data governance.
-- ============================================================================

\echo '[4/5] Creating data quality issues table...'

DROP TABLE IF EXISTS analytics.data_quality_issues CASCADE;

CREATE TABLE analytics.data_quality_issues (
    issue_id            SERIAL PRIMARY KEY,
    check_name          VARCHAR(100) NOT NULL,
    check_category      VARCHAR(50) NOT NULL,           -- COMPLETENESS, ACCURACY, CONSISTENCY, TIMELINESS
    severity            VARCHAR(20) NOT NULL,           -- CRITICAL, HIGH, MEDIUM, LOW
    source_table        VARCHAR(100),
    affected_records    BIGINT,
    sample_ids          TEXT,                           -- Sample of affected record IDs
    issue_description   TEXT,
    suggested_action    TEXT,
    detected_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at         TIMESTAMP,
    resolved_by         VARCHAR(50),
    status              VARCHAR(20) DEFAULT 'OPEN'      -- OPEN, IN_PROGRESS, RESOLVED, IGNORED
);

CREATE INDEX idx_dq_status ON analytics.data_quality_issues(status);
CREATE INDEX idx_dq_severity ON analytics.data_quality_issues(severity);
CREATE INDEX idx_dq_detected ON analytics.data_quality_issues(detected_at DESC);

COMMENT ON TABLE analytics.data_quality_issues IS 'Tracks data quality issues detected by validation checks';

\echo '      ✓ Table created: data_quality_issues'


-- ============================================================================
-- HELPER FUNCTIONS FOR LOGGING
-- ============================================================================

\echo '[5/5] Creating logging helper functions...'

-- Function to log operation start
CREATE OR REPLACE FUNCTION analytics.log_operation_start(
    p_operation_type VARCHAR,
    p_module_name VARCHAR,
    p_object_name VARCHAR DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_log_id INTEGER;
BEGIN
    INSERT INTO analytics.execution_log (
        operation_type, module_name, object_name, status, started_at
    ) VALUES (
        p_operation_type, p_module_name, p_object_name, 'RUNNING', CURRENT_TIMESTAMP
    ) RETURNING log_id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- Function to log operation completion
CREATE OR REPLACE FUNCTION analytics.log_operation_complete(
    p_log_id INTEGER,
    p_status VARCHAR,
    p_rows_affected BIGINT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_started_at TIMESTAMP;
    v_duration_ms INTEGER;
BEGIN
    -- Get start time
    SELECT started_at INTO v_started_at
    FROM analytics.execution_log
    WHERE log_id = p_log_id;
    
    -- Calculate duration
    v_duration_ms := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_started_at)) * 1000;
    
    -- Update log
    UPDATE analytics.execution_log
    SET 
        status = p_status,
        rows_affected = p_rows_affected,
        execution_time_ms = v_duration_ms,
        completed_at = CURRENT_TIMESTAMP,
        error_message = p_error_message
    WHERE log_id = p_log_id;
END;
$$ LANGUAGE plpgsql;

-- Function to log refresh start
CREATE OR REPLACE FUNCTION analytics.log_refresh_start(
    p_view_name VARCHAR,
    p_refresh_type VARCHAR DEFAULT 'FULL',
    p_trigger_source VARCHAR DEFAULT 'MANUAL'
)
RETURNS INTEGER AS $$
DECLARE
    v_refresh_id INTEGER;
    v_row_count BIGINT;
BEGIN
    -- Try to get current row count
    BEGIN
        EXECUTE format('SELECT COUNT(*) FROM analytics.%I', p_view_name) INTO v_row_count;
    EXCEPTION WHEN OTHERS THEN
        v_row_count := NULL;
    END;
    
    INSERT INTO analytics.refresh_history (
        view_name, refresh_type, trigger_source, rows_before, status
    ) VALUES (
        p_view_name, p_refresh_type, p_trigger_source, v_row_count, 'RUNNING'
    ) RETURNING refresh_id INTO v_refresh_id;
    
    RETURN v_refresh_id;
END;
$$ LANGUAGE plpgsql;

-- Function to log refresh completion
CREATE OR REPLACE FUNCTION analytics.log_refresh_complete(
    p_refresh_id INTEGER,
    p_status VARCHAR
)
RETURNS VOID AS $$
DECLARE
    v_view_name VARCHAR;
    v_started_at TIMESTAMP;
    v_duration_ms INTEGER;
    v_row_count BIGINT;
BEGIN
    -- Get details
    SELECT view_name, started_at INTO v_view_name, v_started_at
    FROM analytics.refresh_history
    WHERE refresh_id = p_refresh_id;
    
    -- Calculate duration
    v_duration_ms := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_started_at)) * 1000;
    
    -- Get new row count
    BEGIN
        EXECUTE format('SELECT COUNT(*) FROM analytics.%I', v_view_name) INTO v_row_count;
    EXCEPTION WHEN OTHERS THEN
        v_row_count := NULL;
    END;
    
    -- Update history
    UPDATE analytics.refresh_history
    SET 
        status = p_status,
        completed_at = CURRENT_TIMESTAMP,
        duration_ms = v_duration_ms,
        rows_after = v_row_count
    WHERE refresh_id = p_refresh_id;
    
    -- Update KPI metadata
    UPDATE analytics.kpi_metadata
    SET 
        last_refreshed = CURRENT_TIMESTAMP,
        last_row_count = v_row_count,
        updated_at = CURRENT_TIMESTAMP
    WHERE object_name = v_view_name;
END;
$$ LANGUAGE plpgsql;

-- Function to log data quality issue
CREATE OR REPLACE FUNCTION analytics.log_dq_issue(
    p_check_name VARCHAR,
    p_check_category VARCHAR,
    p_severity VARCHAR,
    p_source_table VARCHAR,
    p_affected_records BIGINT,
    p_description TEXT,
    p_suggested_action TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_issue_id INTEGER;
BEGIN
    INSERT INTO analytics.data_quality_issues (
        check_name, check_category, severity, source_table,
        affected_records, issue_description, suggested_action
    ) VALUES (
        p_check_name, p_check_category, p_severity, p_source_table,
        p_affected_records, p_description, p_suggested_action
    ) RETURNING issue_id INTO v_issue_id;
    
    RETURN v_issue_id;
END;
$$ LANGUAGE plpgsql;

\echo '      ✓ Logging functions created'


-- ============================================================================
-- INSERT INITIAL KPI METADATA
-- ============================================================================
-- Pre-populate with all KPIs we'll create in subsequent scripts
-- This serves as documentation and enables tracking

\echo ''
\echo 'Populating KPI metadata catalog...'

INSERT INTO analytics.kpi_metadata (kpi_name, kpi_category, kpi_type, object_name, description, business_question, refresh_frequency) VALUES
-- Sales KPIs
('Daily Sales Summary', 'Sales', 'VIEW', 'vw_daily_sales_summary', 'Daily aggregated sales metrics', 'How much did we sell each day?', 'REALTIME'),
('Monthly Sales Dashboard', 'Sales', 'MATERIALIZED_VIEW', 'mv_monthly_sales_dashboard', 'Monthly trends with MoM/YoY growth', 'How are monthly sales trending?', 'DAILY'),
('Executive Summary', 'Sales', 'MATERIALIZED_VIEW', 'mv_executive_summary', 'Top-level KPIs for executive view', 'What are our key numbers right now?', 'HOURLY'),
('Sales by Day of Week', 'Sales', 'VIEW', 'vw_sales_by_dayofweek', 'Performance breakdown by weekday', 'Which days perform best?', 'REALTIME'),
('Payment Mode Analysis', 'Sales', 'VIEW', 'vw_sales_by_payment_mode', 'Revenue by payment method', 'How do customers prefer to pay?', 'REALTIME'),
('Quarterly Sales', 'Sales', 'VIEW', 'vw_quarterly_sales', 'Quarterly performance with QoQ growth', 'How did each quarter perform?', 'REALTIME'),

-- Customer KPIs
('Customer Lifetime Value', 'Customer', 'MATERIALIZED_VIEW', 'mv_customer_lifetime_value', 'CLV with tier classification', 'How valuable is each customer?', 'DAILY'),
('RFM Analysis', 'Customer', 'MATERIALIZED_VIEW', 'mv_rfm_analysis', 'RFM segmentation for targeting', 'How should we segment customers?', 'WEEKLY'),
('Cohort Retention', 'Customer', 'MATERIALIZED_VIEW', 'mv_cohort_retention', 'Monthly cohort retention rates', 'Are we retaining customers over time?', 'WEEKLY'),
('Churn Risk', 'Customer', 'VIEW', 'vw_churn_risk_customers', 'Customers at risk of churning', 'Which valuable customers might leave?', 'REALTIME'),
('Customer Demographics', 'Customer', 'VIEW', 'vw_customer_demographics', 'Age and gender breakdown', 'Who are our customers?', 'REALTIME'),

-- Product KPIs
('Top Products', 'Product', 'MATERIALIZED_VIEW', 'mv_top_products', 'Products ranked by revenue/units', 'What are our best sellers?', 'DAILY'),
('ABC Analysis', 'Product', 'MATERIALIZED_VIEW', 'mv_abc_analysis', 'Pareto classification of products', 'Which products drive 80% of revenue?', 'WEEKLY'),
('Category Performance', 'Product', 'VIEW', 'vw_category_performance', 'Category-level metrics', 'Which categories perform best?', 'REALTIME'),
('Inventory Turnover', 'Product', 'VIEW', 'vw_inventory_turnover', 'Stock velocity and days of inventory', 'How fast is inventory moving?', 'REALTIME'),

-- Store KPIs
('Store Performance', 'Store', 'MATERIALIZED_VIEW', 'mv_store_performance', 'Store-level revenue and profit', 'Which stores are most profitable?', 'DAILY'),
('Regional Performance', 'Store', 'VIEW', 'vw_regional_performance', 'Regional aggregation of metrics', 'How do regions compare?', 'REALTIME'),
('Store Inventory Status', 'Store', 'VIEW', 'vw_store_inventory_status', 'Inventory health by store', 'Which stores have stock issues?', 'REALTIME'),

-- Operations KPIs
('Delivery Performance', 'Operations', 'VIEW', 'vw_delivery_performance', 'Delivery SLA and timing metrics', 'Are we delivering on time?', 'REALTIME'),
('Courier Comparison', 'Operations', 'VIEW', 'vw_courier_comparison', 'Performance by courier partner', 'Which courier is most reliable?', 'REALTIME'),
('Return Analysis', 'Operations', 'VIEW', 'vw_return_analysis', 'Return rates and reasons', 'Why are customers returning products?', 'REALTIME'),
('Payment Success Rate', 'Operations', 'VIEW', 'vw_payment_success_rate', 'Payment gateway performance', 'Are payments succeeding?', 'REALTIME'),

-- Marketing KPIs
('Campaign Performance', 'Marketing', 'VIEW', 'vw_campaign_performance', 'Campaign ROI and effectiveness', 'Which campaigns work best?', 'REALTIME'),
('Promotion Effectiveness', 'Marketing', 'VIEW', 'vw_promotion_effectiveness', 'Impact of promotions on sales', 'Are promotions driving sales?', 'REALTIME'),
('Channel Performance', 'Marketing', 'VIEW', 'vw_channel_performance', 'Ad spend and conversion by channel', 'Where should we spend ad budget?', 'REALTIME');

\echo '      ✓ KPI metadata populated (25 KPIs cataloged)'


-- ============================================================================
-- VERIFICATION
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '                 METADATA TABLES SETUP COMPLETE                             '
\echo '============================================================================'
\echo ''
\echo '✅ Tables Created:'
\echo '   • analytics.kpi_metadata        - KPI catalog (25 KPIs documented)'
\echo '   • analytics.execution_log       - Operation audit trail'
\echo '   • analytics.refresh_history     - MV refresh tracking'
\echo '   • analytics.data_quality_issues - DQ issue tracking'
\echo ''
\echo '✅ Functions Created:'
\echo '   • log_operation_start()     - Start logging an operation'
\echo '   • log_operation_complete()  - Complete logging an operation'
\echo '   • log_refresh_start()       - Start logging a refresh'
\echo '   • log_refresh_complete()    - Complete logging a refresh'
\echo '   • log_dq_issue()           - Log a data quality issue'
\echo ''
\echo '📊 Quick Test:'
\echo '   SELECT kpi_name, kpi_category, refresh_frequency'
\echo '   FROM analytics.kpi_metadata'
\echo '   ORDER BY kpi_category, kpi_name;'
\echo ''
\echo '➡️  Next: Run 03_create_indexes.sql'
\echo '============================================================================'
\echo ''

-- Show summary
SELECT 
    kpi_category,
    COUNT(*) as kpi_count,
    COUNT(*) FILTER (WHERE kpi_type = 'VIEW') as views,
    COUNT(*) FILTER (WHERE kpi_type = 'MATERIALIZED_VIEW') as mvs
FROM analytics.kpi_metadata
GROUP BY kpi_category
ORDER BY kpi_category;
