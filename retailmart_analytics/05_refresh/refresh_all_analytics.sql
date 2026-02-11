-- ============================================================================
-- FILE: 05_refresh/refresh_all_analytics.sql
-- PROJECT: RetailMart Enterprise Analytics Platform
-- PURPOSE: Refresh all materialized views with logging
-- AUTHOR: SQL Bootcamp
-- CREATED: 2025
--
-- DESCRIPTION:
--   Enterprise systems need scheduled refreshes. At Flipkart, data pipelines
--   run at 2 AM every night to refresh all dashboards before morning stand-ups.
--
--   This script:
--   1. Refreshes all materialized views in correct order
--   2. Logs execution time for each view
--   3. Updates metadata tables
--   4. Returns status report
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '             REFRESH ALL ANALYTICS - STARTING                               '
\echo '============================================================================'
\echo ''

-- ============================================================================
-- MAIN REFRESH FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION analytics.fn_refresh_all_analytics(
    p_concurrent BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    view_name TEXT,
    status TEXT,
    rows_count BIGINT,
    duration_ms INTEGER
) AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTEGER;
    v_rows BIGINT;
    v_log_id INTEGER;
    v_batch_id UUID := gen_random_uuid();
    v_refresh_cmd TEXT;
    v_views TEXT[] := ARRAY[
        'mv_monthly_sales_dashboard',
        'mv_executive_summary',
        'mv_customer_lifetime_value',
        'mv_rfm_analysis',
        'mv_cohort_retention',
        'mv_top_products',
        'mv_abc_analysis',
        'mv_store_performance',
        'mv_operations_summary',
        'mv_marketing_roi'
    ];
    v_view TEXT;
BEGIN
    -- Log batch start
    v_log_id := analytics.log_operation_start('REFRESH_BATCH', 'All Analytics', 'fn_refresh_all_analytics');
    
    RAISE NOTICE '=== Analytics Refresh Started (Batch: %) ===', v_batch_id;
    RAISE NOTICE 'Concurrent Mode: %', p_concurrent;
    RAISE NOTICE '';
    
    FOREACH v_view IN ARRAY v_views
    LOOP
        v_start_time := clock_timestamp();
        
        BEGIN
            -- Build refresh command
            IF p_concurrent THEN
                v_refresh_cmd := format('REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.%I', v_view);
            ELSE
                v_refresh_cmd := format('REFRESH MATERIALIZED VIEW analytics.%I', v_view);
            END IF;
            
            -- Execute refresh
            EXECUTE v_refresh_cmd;
            
            v_end_time := clock_timestamp();
            v_duration := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
            
            -- Get row count
            EXECUTE format('SELECT COUNT(*) FROM analytics.%I', v_view) INTO v_rows;
            
            -- Log to refresh history
            INSERT INTO analytics.refresh_history (
                refresh_batch_id, view_name, refresh_type, started_at, 
                completed_at, duration_ms, rows_after, status
            ) VALUES (
                v_batch_id, v_view, 
                CASE WHEN p_concurrent THEN 'CONCURRENT' ELSE 'FULL' END,
                v_start_time, v_end_time, v_duration, v_rows, 'SUCCESS'
            );
            
            -- Update KPI metadata
            UPDATE analytics.kpi_metadata
            SET last_refreshed = v_end_time,
                last_row_count = v_rows,
                avg_refresh_time_ms = COALESCE((avg_refresh_time_ms + v_duration) / 2, v_duration),
                updated_at = v_end_time
            WHERE object_name = v_view;
            
            RAISE NOTICE '✓ % refreshed (% rows, % ms)', v_view, v_rows, v_duration;
            
            view_name := v_view;
            status := 'SUCCESS';
            rows_count := v_rows;
            duration_ms := v_duration;
            RETURN NEXT;
            
        EXCEPTION WHEN OTHERS THEN
            v_end_time := clock_timestamp();
            v_duration := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
            
            -- Log failure
            INSERT INTO analytics.refresh_history (
                refresh_batch_id, view_name, refresh_type, started_at,
                completed_at, duration_ms, status
            ) VALUES (
                v_batch_id, v_view,
                CASE WHEN p_concurrent THEN 'CONCURRENT' ELSE 'FULL' END,
                v_start_time, v_end_time, v_duration, 'FAILED'
            );
            
            RAISE WARNING '✗ % FAILED: %', v_view, SQLERRM;
            
            view_name := v_view;
            status := 'FAILED: ' || SQLERRM;
            rows_count := 0;
            duration_ms := v_duration;
            RETURN NEXT;
        END;
    END LOOP;
    
    -- Complete batch logging
    PERFORM analytics.log_operation_complete(v_log_id, 'SUCCESS', array_length(v_views, 1));
    
    RAISE NOTICE '';
    RAISE NOTICE '=== Analytics Refresh Completed ===';
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION analytics.fn_refresh_all_analytics IS 
    'Refresh all materialized views with logging. Pass TRUE for concurrent refresh.';


-- ============================================================================
-- QUICK REFRESH SHORTCUTS
-- ============================================================================

-- Refresh just sales (fastest)
CREATE OR REPLACE FUNCTION analytics.fn_refresh_sales()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW analytics.mv_monthly_sales_dashboard;
    REFRESH MATERIALIZED VIEW analytics.mv_executive_summary;
    RAISE NOTICE 'Sales MVs refreshed';
END;
$$ LANGUAGE plpgsql;

-- Refresh just customers
CREATE OR REPLACE FUNCTION analytics.fn_refresh_customers()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW analytics.mv_customer_lifetime_value;
    REFRESH MATERIALIZED VIEW analytics.mv_rfm_analysis;
    REFRESH MATERIALIZED VIEW analytics.mv_cohort_retention;
    RAISE NOTICE 'Customer MVs refreshed';
END;
$$ LANGUAGE plpgsql;

-- Refresh just products
CREATE OR REPLACE FUNCTION analytics.fn_refresh_products()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW analytics.mv_top_products;
    REFRESH MATERIALIZED VIEW analytics.mv_abc_analysis;
    RAISE NOTICE 'Product MVs refreshed';
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- VERIFICATION
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '              REFRESH FUNCTIONS - CREATED                                   '
\echo '============================================================================'
\echo ''
\echo '✅ Functions Created:'
\echo '   • fn_refresh_all_analytics(concurrent)  - Refresh all MVs'
\echo '   • fn_refresh_sales()                    - Refresh sales MVs only'
\echo '   • fn_refresh_customers()                - Refresh customer MVs only'
\echo '   • fn_refresh_products()                 - Refresh product MVs only'
\echo ''
\echo '📊 Usage:'
\echo '   -- Refresh all (standard):'
\echo '   SELECT * FROM analytics.fn_refresh_all_analytics();'
\echo ''
\echo '   -- Refresh all (concurrent, requires unique index):'
\echo '   SELECT * FROM analytics.fn_refresh_all_analytics(TRUE);'
\echo ''
\echo '   -- Refresh specific module:'
\echo '   SELECT analytics.fn_refresh_sales();'
\echo ''
\echo '   -- Check refresh history:'
\echo '   SELECT view_name, status, duration_ms, completed_at'
\echo '   FROM analytics.refresh_history ORDER BY completed_at DESC LIMIT 20;'
\echo ''
\echo '============================================================================'
