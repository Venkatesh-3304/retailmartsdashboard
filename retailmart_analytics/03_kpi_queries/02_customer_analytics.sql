-- ============================================================================
-- FILE: 03_kpi_queries/02_customer_analytics.sql
-- PROJECT: RetailMart Enterprise Analytics Platform
-- PURPOSE: Customer Analytics Module - Complete customer behavior tracking
-- AUTHOR: SQL Bootcamp
-- CREATED: 2025
--
-- DESCRIPTION:
--   "Your most unhappy customers are your greatest source of learning" - Bill Gates
--   
--   This module helps answer:
--   - Who are our most valuable customers? (CLV Analysis)
--   - How should we segment customers? (RFM Analysis)
--   - Are we retaining customers? (Cohort Retention)
--   - Who is about to leave? (Churn Prediction)
--   - What do our customers look like? (Demographics)
--
--   Real-world example: Swiggy spends ₹600 to acquire a customer.
--   They NEED to know if CLV > ₹600, otherwise they're losing money!
--
-- CREATES:
--   • 4 Regular Views
--   • 3 Materialized Views
--   • 6 JSON Export Functions
--
-- EXECUTION ORDER: Run AFTER 01_sales_analytics.sql
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '             CUSTOMER ANALYTICS MODULE - STARTING                           '
\echo '============================================================================'
\echo ''

-- ============================================================================
-- MATERIALIZED VIEW 1: CUSTOMER LIFETIME VALUE (CLV)
-- ============================================================================
-- Purpose: Calculate comprehensive customer value and segment into tiers
-- Business Impact: Determines how much to spend on acquisition/retention
-- ============================================================================

\echo '[1/7] Creating materialized view: mv_customer_lifetime_value...'

DROP MATERIALIZED VIEW IF EXISTS analytics.mv_customer_lifetime_value CASCADE;

CREATE MATERIALIZED VIEW analytics.mv_customer_lifetime_value AS
WITH customer_orders AS (
    SELECT 
        c.cust_id,
        c.full_name,
        c.gender,
        c.age,
        c.city,
        c.state,
        c.region_name,
        c.join_date,
        
        -- Order Metrics
        COUNT(DISTINCT o.order_id) as total_orders,
        SUM(o.total_amount) as total_revenue,
        AVG(o.total_amount) as avg_order_value,
        
        -- Timeline
        MIN(o.order_date) as first_order_date,
        MAX(o.order_date) as last_order_date,
        (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) as days_since_last_order,
        MAX(o.order_date) - MIN(o.order_date) as customer_lifespan_days,
        
        -- Items
        SUM(oi.quantity) as total_items_purchased
        
    FROM customers.customers c
    LEFT JOIN sales.orders o ON c.cust_id = o.cust_id AND o.order_status = 'Delivered'
    LEFT JOIN sales.order_items oi ON o.order_id = oi.order_id
    GROUP BY c.cust_id, c.full_name, c.gender, c.age, c.city, c.state, c.region_name, c.join_date
),
customer_loyalty AS (
    SELECT cust_id, total_points FROM customers.loyalty_points
),
customer_reviews AS (
    SELECT cust_id, COUNT(*) as review_count, ROUND(AVG(rating), 2) as avg_rating_given
    FROM customers.reviews
    GROUP BY cust_id
)
SELECT 
    co.cust_id,
    co.full_name,
    co.gender,
    co.age,
    co.city,
    co.state,
    co.region_name,
    co.join_date,
    
    -- Order Metrics
    COALESCE(co.total_orders, 0) as total_orders,
    ROUND(COALESCE(co.total_revenue, 0)::NUMERIC, 2) as total_revenue,
    ROUND(COALESCE(co.avg_order_value, 0)::NUMERIC, 2) as avg_order_value,
    COALESCE(co.total_items_purchased, 0) as total_items_purchased,
    
    -- Timeline
    co.first_order_date,
    co.last_order_date,
    COALESCE(co.days_since_last_order, 9999) as days_since_last_order,
    COALESCE(co.customer_lifespan_days, 0) as customer_lifespan_days,
    
    -- Loyalty & Engagement
    COALESCE(cl.total_points, 0) as loyalty_points,
    COALESCE(cr.review_count, 0) as review_count,
    COALESCE(cr.avg_rating_given, 0) as avg_rating_given,
    
    -- Calculated Metrics
    ROUND(
        COALESCE(co.total_revenue, 0) / NULLIF(GREATEST(co.customer_lifespan_days, 1), 0) * 365,
        2
    )::NUMERIC as projected_annual_value,
    
    ROUND(
        COALESCE(co.total_orders, 0)::NUMERIC / NULLIF(GREATEST(co.customer_lifespan_days, 1), 0) * 30,
        2
    ) as avg_orders_per_month,
    
    -- CLV Tier (using config values)
    CASE 
        WHEN COALESCE(co.total_revenue, 0) >= (SELECT analytics.get_config_number('clv_tier_platinum')) THEN 'Platinum'
        WHEN COALESCE(co.total_revenue, 0) >= (SELECT analytics.get_config_number('clv_tier_gold')) THEN 'Gold'
        WHEN COALESCE(co.total_revenue, 0) >= (SELECT analytics.get_config_number('clv_tier_silver')) THEN 'Silver'
        WHEN COALESCE(co.total_revenue, 0) >= (SELECT analytics.get_config_number('clv_tier_bronze')) THEN 'Bronze'
        ELSE 'Basic'
    END as clv_tier,
    
    -- Customer Status
    CASE 
        WHEN co.total_orders IS NULL OR co.total_orders = 0 THEN 'Never Purchased'
        WHEN co.days_since_last_order <= (SELECT analytics.get_config_number('rfm_recency_active_days')) THEN 'Active'
        WHEN co.days_since_last_order <= (SELECT analytics.get_config_number('rfm_recency_at_risk_days')) THEN 'At Risk'
        WHEN co.days_since_last_order <= (SELECT analytics.get_config_number('rfm_recency_churning_days')) THEN 'Churning'
        ELSE 'Churned'
    END as customer_status,
    
    -- Age Group
    CASE 
        WHEN co.age < 25 THEN '18-24'
        WHEN co.age < 35 THEN '25-34'
        WHEN co.age < 45 THEN '35-44'
        WHEN co.age < 55 THEN '45-54'
        ELSE '55+'
    END as age_group

FROM customer_orders co
LEFT JOIN customer_loyalty cl ON co.cust_id = cl.cust_id
LEFT JOIN customer_reviews cr ON co.cust_id = cr.cust_id;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_clv_tier ON analytics.mv_customer_lifetime_value(clv_tier);
CREATE INDEX IF NOT EXISTS idx_clv_status ON analytics.mv_customer_lifetime_value(customer_status);
CREATE INDEX IF NOT EXISTS idx_clv_region ON analytics.mv_customer_lifetime_value(region_name);

COMMENT ON MATERIALIZED VIEW analytics.mv_customer_lifetime_value IS 
    'Customer Lifetime Value with tier classification - Refresh daily';

\echo '      ✓ Materialized view created: mv_customer_lifetime_value'


-- ============================================================================
-- MATERIALIZED VIEW 2: RFM ANALYSIS
-- ============================================================================
-- Purpose: Segment customers by Recency, Frequency, Monetary value
-- Use Case: Targeted marketing, personalized campaigns
-- 
-- RFM Scoring: Each dimension scored 1-5 (5 = best)
-- - Recency: How recently did they purchase? (Lower days = Higher score)
-- - Frequency: How often do they purchase? (More orders = Higher score)
-- - Monetary: How much do they spend? (Higher spend = Higher score)
-- ============================================================================

\echo '[2/7] Creating materialized view: mv_rfm_analysis...'

DROP MATERIALIZED VIEW IF EXISTS analytics.mv_rfm_analysis CASCADE;

CREATE MATERIALIZED VIEW analytics.mv_rfm_analysis AS
WITH customer_rfm AS (
    SELECT 
        c.cust_id,
        c.full_name,
        c.city,
        c.state,
        (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) as recency_days,
        COUNT(DISTINCT o.order_id) as frequency,
        SUM(o.total_amount) as monetary
    FROM customers.customers c
    JOIN sales.orders o ON c.cust_id = o.cust_id AND o.order_status = 'Delivered'
    GROUP BY c.cust_id, c.full_name, c.city, c.state
),
rfm_scores AS (
    SELECT 
        *,
        -- Score 1-5 using NTILE (quintiles)
        NTILE(5) OVER (ORDER BY recency_days DESC) as r_score,  -- Lower days = Higher score
        NTILE(5) OVER (ORDER BY frequency ASC) as f_score,      -- More orders = Higher score
        NTILE(5) OVER (ORDER BY monetary ASC) as m_score        -- Higher spend = Higher score
    FROM customer_rfm
    WHERE frequency > 0  -- Only customers with purchases
)
SELECT 
    cust_id,
    full_name,
    city,
    state,
    
    -- Raw Metrics
    recency_days,
    frequency as order_count,
    ROUND(monetary::NUMERIC, 2) as total_spent,
    
    -- RFM Scores (1-5)
    r_score as recency_score,
    f_score as frequency_score,
    m_score as monetary_score,
    
    -- Combined RFM Score
    CONCAT(r_score, f_score, m_score) as rfm_score,
    r_score + f_score + m_score as rfm_total,
    
    -- Customer Segment (based on RFM combination)
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 AND m_score <= 2 THEN 'Recent Customers'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 4 THEN 'Big Spenders'
        WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk - High Value'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Hibernating'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
        ELSE 'Potential Loyalists'
    END as rfm_segment,
    
    -- Recommended Action
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Reward - Exclusive offers & early access'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Nurture - Onboarding, product education'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'Win Back - Special discount, reach out'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Reactivate - Strong offer to return'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Last Chance - Deep discount or let go'
        ELSE 'Engage - Regular communication'
    END as recommended_action

FROM rfm_scores;

-- Create index on segment for quick filtering
CREATE INDEX IF NOT EXISTS idx_rfm_segment ON analytics.mv_rfm_analysis(rfm_segment);

COMMENT ON MATERIALIZED VIEW analytics.mv_rfm_analysis IS 
    'RFM segmentation for targeted marketing - Refresh weekly';

\echo '      ✓ Materialized view created: mv_rfm_analysis'


-- ============================================================================
-- MATERIALIZED VIEW 3: COHORT RETENTION
-- ============================================================================
-- Purpose: Track how well we retain customers over time
-- Use Case: Measure product-market fit, identify retention issues
-- 
-- A cohort is a group of customers who made their first purchase in the same month.
-- We track what % of each cohort returns in subsequent months.
-- ============================================================================

\echo '[3/7] Creating materialized view: mv_cohort_retention...'

DROP MATERIALIZED VIEW IF EXISTS analytics.mv_cohort_retention CASCADE;

CREATE MATERIALIZED VIEW analytics.mv_cohort_retention AS
WITH customer_first_order AS (
    -- Get each customer's first order month (their cohort)
    SELECT 
        cust_id,
        DATE_TRUNC('month', MIN(order_date))::DATE as cohort_month
    FROM sales.orders
    WHERE order_status = 'Delivered'
    GROUP BY cust_id
),
customer_activity AS (
    -- Get all months each customer was active
    SELECT DISTINCT
        o.cust_id,
        DATE_TRUNC('month', o.order_date)::DATE as activity_month
    FROM sales.orders o
    WHERE o.order_status = 'Delivered'
),
cohort_data AS (
    -- Combine cohort with activity
    SELECT 
        cfo.cohort_month,
        ca.activity_month,
        -- Calculate months since cohort (0 = first month)
        EXTRACT(YEAR FROM AGE(ca.activity_month, cfo.cohort_month)) * 12 +
        EXTRACT(MONTH FROM AGE(ca.activity_month, cfo.cohort_month)) as months_since_cohort,
        COUNT(DISTINCT cfo.cust_id) as customer_count
    FROM customer_first_order cfo
    JOIN customer_activity ca ON cfo.cust_id = ca.cust_id
    GROUP BY cfo.cohort_month, ca.activity_month
),
cohort_sizes AS (
    -- Get initial cohort sizes
    SELECT 
        cohort_month,
        COUNT(DISTINCT cust_id) as cohort_size
    FROM customer_first_order
    GROUP BY cohort_month
)
SELECT 
    cd.cohort_month,
    TO_CHAR(cd.cohort_month, 'Mon YYYY') as cohort_name,
    cs.cohort_size,
    cd.months_since_cohort as month_number,
    cd.customer_count as retained_customers,
    ROUND((cd.customer_count::NUMERIC / cs.cohort_size * 100), 2) as retention_rate
FROM cohort_data cd
JOIN cohort_sizes cs ON cd.cohort_month = cs.cohort_month
WHERE cd.months_since_cohort <= 12  -- Track up to 12 months
ORDER BY cd.cohort_month DESC, cd.months_since_cohort;

-- Create index for quick cohort lookups
CREATE INDEX IF NOT EXISTS idx_cohort_month ON analytics.mv_cohort_retention(cohort_month);

COMMENT ON MATERIALIZED VIEW analytics.mv_cohort_retention IS 
    'Monthly cohort retention analysis - Refresh weekly';

\echo '      ✓ Materialized view created: mv_cohort_retention'


-- ============================================================================
-- VIEW 1: CHURN RISK CUSTOMERS
-- ============================================================================
-- Purpose: Identify high-value customers at risk of churning
-- Use Case: Proactive retention campaigns
-- ============================================================================

\echo '[4/7] Creating view: vw_churn_risk_customers...'

CREATE OR REPLACE VIEW analytics.vw_churn_risk_customers AS
SELECT 
    cust_id,
    full_name,
    city,
    state,
    clv_tier,
    total_orders,
    total_revenue as total_spent,
    days_since_last_order as days_inactive,
    
    -- Churn Risk Level
    CASE 
        WHEN days_since_last_order > 180 THEN 'Churned'
        WHEN days_since_last_order > 90 THEN 'High Risk'
        WHEN days_since_last_order > 60 THEN 'Medium Risk'
        WHEN days_since_last_order > 30 THEN 'Low Risk'
        ELSE 'Active'
    END as churn_risk_level,
    
    -- Priority Score (Higher = More urgent to retain)
    -- High value + Long inactive = Highest priority
    CASE 
        WHEN clv_tier = 'Platinum' THEN 5
        WHEN clv_tier = 'Gold' THEN 4
        WHEN clv_tier = 'Silver' THEN 3
        WHEN clv_tier = 'Bronze' THEN 2
        ELSE 1
    END +
    CASE 
        WHEN days_since_last_order > 90 THEN 5
        WHEN days_since_last_order > 60 THEN 3
        WHEN days_since_last_order > 30 THEN 1
        ELSE 0
    END as priority_score,
    
    -- Recommended Action
    CASE 
        WHEN clv_tier IN ('Platinum', 'Gold') AND days_since_last_order > 60 
            THEN 'URGENT: Personal outreach from account manager'
        WHEN clv_tier IN ('Platinum', 'Gold') AND days_since_last_order > 30 
            THEN 'HIGH: Send exclusive offer + loyalty bonus'
        WHEN days_since_last_order > 90 
            THEN 'Win-back campaign with significant discount'
        WHEN days_since_last_order > 60 
            THEN 'Re-engagement email with personalized recommendations'
        WHEN days_since_last_order > 30 
            THEN 'Reminder email with what''s new'
        ELSE 'No action needed'
    END as recommended_action

FROM analytics.mv_customer_lifetime_value
WHERE total_orders > 0
AND days_since_last_order > 30  -- Focus on at-risk customers
ORDER BY priority_score DESC, total_revenue DESC;

COMMENT ON VIEW analytics.vw_churn_risk_customers IS 'High-value customers at risk of churning';

\echo '      ✓ View created: vw_churn_risk_customers'


-- ============================================================================
-- VIEW 2: CUSTOMER DEMOGRAPHICS
-- ============================================================================
-- Purpose: Understand customer base composition
-- Use Case: Marketing targeting, product development
-- ============================================================================

\echo '[5/7] Creating view: vw_customer_demographics...'

CREATE OR REPLACE VIEW analytics.vw_customer_demographics AS
SELECT 
    age_group,
    gender,
    COUNT(*) as customer_count,
    SUM(total_revenue) as total_revenue,
    ROUND(AVG(total_revenue)::NUMERIC, 2) as avg_revenue_per_customer,
    ROUND(AVG(total_orders)::NUMERIC, 1) as avg_orders_per_customer,
    
    -- Percentage calculations
    ROUND(
        (COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100), 
        2
    ) as pct_of_customers,
    ROUND(
        (SUM(total_revenue) / SUM(SUM(total_revenue)) OVER () * 100)::NUMERIC, 
        2
    ) as pct_of_revenue

FROM analytics.mv_customer_lifetime_value
WHERE total_orders > 0
GROUP BY age_group, gender
ORDER BY total_revenue DESC;

COMMENT ON VIEW analytics.vw_customer_demographics IS 'Customer breakdown by age group and gender';

\echo '      ✓ View created: vw_customer_demographics'


-- ============================================================================
-- VIEW 3: CUSTOMER GEOGRAPHY
-- ============================================================================
-- Purpose: Geographic distribution of customers
-- Use Case: Store expansion, regional marketing
-- ============================================================================

\echo '[6/7] Creating view: vw_customer_geography...'

CREATE OR REPLACE VIEW analytics.vw_customer_geography AS
WITH geo_stats AS (
    SELECT 
        state,
        city,
        COUNT(*) as customer_count,
        SUM(total_orders) as total_orders,
        SUM(total_revenue) as total_revenue,
        AVG(total_revenue) as avg_revenue_per_customer,
        AVG(avg_order_value) as avg_order_value
    FROM analytics.mv_customer_lifetime_value
    WHERE total_orders > 0
    GROUP BY state, city
)
SELECT 
    state,
    city,
    customer_count,
    total_orders,
    ROUND(total_revenue::NUMERIC, 2) as total_revenue,
    ROUND(avg_order_value::NUMERIC, 2) as avg_order_value,
    ROUND(avg_revenue_per_customer::NUMERIC, 2) as revenue_per_customer,
    RANK() OVER (ORDER BY total_revenue DESC) as revenue_rank,
    RANK() OVER (PARTITION BY state ORDER BY total_revenue DESC) as state_rank
FROM geo_stats
ORDER BY total_revenue DESC;

COMMENT ON VIEW analytics.vw_customer_geography IS 'Customer distribution by location';

\echo '      ✓ View created: vw_customer_geography'


-- ============================================================================
-- VIEW 4: NEW VS RETURNING CUSTOMERS
-- ============================================================================
-- Purpose: Track customer acquisition vs retention
-- Use Case: Balance acquisition and retention spend
-- ============================================================================

\echo '[7/7] Creating view: vw_new_vs_returning...'

CREATE OR REPLACE VIEW analytics.vw_new_vs_returning AS
WITH customer_first_order AS (
    SELECT cust_id, MIN(order_date) as first_order_date
    FROM sales.orders
    WHERE order_status = 'Delivered'
    GROUP BY cust_id
),
monthly_breakdown AS (
    SELECT 
        DATE_TRUNC('month', o.order_date)::DATE as order_month,
        COUNT(DISTINCT o.order_id) as total_orders,
        SUM(o.total_amount) as total_revenue,
        COUNT(DISTINCT o.cust_id) as total_customers,
        COUNT(DISTINCT o.cust_id) FILTER (
            WHERE DATE_TRUNC('month', o.order_date) = DATE_TRUNC('month', cfo.first_order_date)
        ) as new_customers,
        COUNT(DISTINCT o.cust_id) FILTER (
            WHERE DATE_TRUNC('month', o.order_date) > DATE_TRUNC('month', cfo.first_order_date)
        ) as returning_customers
    FROM sales.orders o
    JOIN customer_first_order cfo ON o.cust_id = cfo.cust_id
    WHERE o.order_status = 'Delivered'
    GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT 
    order_month,
    TO_CHAR(order_month, 'Mon YYYY') as month_name,
    total_orders,
    ROUND(total_revenue::NUMERIC, 2) as total_revenue,
    total_customers,
    new_customers,
    returning_customers,
    ROUND((new_customers::NUMERIC / NULLIF(total_customers, 0) * 100), 2) as new_customer_pct,
    ROUND((returning_customers::NUMERIC / NULLIF(total_customers, 0) * 100), 2) as returning_customer_pct
FROM monthly_breakdown
ORDER BY order_month DESC;

COMMENT ON VIEW analytics.vw_new_vs_returning IS 'New vs returning customer breakdown by month';

\echo '      ✓ View created: vw_new_vs_returning'


-- ============================================================================
-- JSON EXPORT FUNCTIONS
-- ============================================================================

\echo ''
\echo 'Creating JSON export functions...'

-- JSON 1: Top Customers (Top 50 by CLV)
CREATE OR REPLACE FUNCTION analytics.get_top_customers_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(
            json_build_object(
                'custId', cust_id,
                'fullName', full_name,
                'city', city,
                'state', state,
                'clvTier', clv_tier,
                'totalOrders', total_orders,
                'totalRevenue', total_revenue,
                'avgOrderValue', avg_order_value,
                'daysSinceLastOrder', days_since_last_order,
                'customerStatus', customer_status,
                'loyaltyPoints', loyalty_points
            ) ORDER BY total_revenue DESC
        )
        FROM analytics.mv_customer_lifetime_value
        WHERE total_orders > 0
        LIMIT 50
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- JSON 2: CLV Tier Distribution
CREATE OR REPLACE FUNCTION analytics.get_clv_tier_distribution_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(
            json_build_object(
                'tier', clv_tier,
                'customerCount', customer_count,
                'totalRevenue', total_revenue,
                'avgRevenue', avg_revenue,
                'pctOfCustomers', pct_of_customers,
                'pctOfRevenue', pct_of_revenue
            ) ORDER BY 
                CASE clv_tier 
                    WHEN 'Platinum' THEN 1 
                    WHEN 'Gold' THEN 2 
                    WHEN 'Silver' THEN 3 
                    WHEN 'Bronze' THEN 4 
                    ELSE 5 
                END
        )
        FROM (
            SELECT 
                clv_tier,
                COUNT(*) as customer_count,
                ROUND(SUM(total_revenue)::NUMERIC, 2) as total_revenue,
                ROUND(AVG(total_revenue)::NUMERIC, 2) as avg_revenue,
                ROUND((COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100), 2) as pct_of_customers,
                ROUND((SUM(total_revenue) / SUM(SUM(total_revenue)) OVER () * 100)::NUMERIC, 2) as pct_of_revenue
            FROM analytics.mv_customer_lifetime_value
            WHERE total_orders > 0
            GROUP BY clv_tier
        ) tier_stats
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- JSON 3: RFM Segments
CREATE OR REPLACE FUNCTION analytics.get_rfm_segments_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(
            json_build_object(
                'segment', rfm_segment,
                'customerCount', customer_count,
                'totalRevenue', total_revenue,
                'avgRecencyDays', avg_recency,
                'avgFrequency', avg_frequency,
                'avgMonetary', avg_monetary,
                'recommendedAction', recommended_action
            ) ORDER BY total_revenue DESC
        )
        FROM (
            SELECT 
                rfm_segment,
                COUNT(*) as customer_count,
                ROUND(SUM(total_spent)::NUMERIC, 2) as total_revenue,
                ROUND(AVG(recency_days)::NUMERIC, 0) as avg_recency,
                ROUND(AVG(order_count)::NUMERIC, 1) as avg_frequency,
                ROUND(AVG(total_spent)::NUMERIC, 2) as avg_monetary,
                MAX(recommended_action) as recommended_action
            FROM analytics.mv_rfm_analysis
            GROUP BY rfm_segment
        ) segment_stats
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- JSON 4: Churn Risk
CREATE OR REPLACE FUNCTION analytics.get_churn_risk_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_build_object(
            'distribution', (
                SELECT json_agg(
                    json_build_object(
                        'riskLevel', churn_risk_level,
                        'customerCount', customer_count,
                        'totalValue', total_value,
                        'avgDaysInactive', avg_days_inactive,
                        'pctOfCustomers', pct_of_customers
                    ) ORDER BY 
                        CASE churn_risk_level 
                            WHEN 'Churned' THEN 1 
                            WHEN 'High Risk' THEN 2 
                            WHEN 'Medium Risk' THEN 3 
                            WHEN 'Low Risk' THEN 4 
                            ELSE 5 
                        END
                )
                FROM (
                    SELECT 
                        churn_risk_level,
                        COUNT(*) as customer_count,
                        ROUND(SUM(total_spent)::NUMERIC, 2) as total_value,
                        ROUND(AVG(days_inactive)::NUMERIC, 0) as avg_days_inactive,
                        ROUND((COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100), 2) as pct_of_customers
                    FROM analytics.vw_churn_risk_customers
                    GROUP BY churn_risk_level
                ) dist
            ),
            'highPriorityCustomers', (
                SELECT json_agg(
                    json_build_object(
                        'custId', cust_id,
                        'fullName', full_name,
                        'clvTier', clv_tier,
                        'totalSpent', total_spent,
                        'daysInactive', days_inactive,
                        'recommendedAction', recommended_action
                    ) ORDER BY priority_score DESC
                )
                FROM analytics.vw_churn_risk_customers
                WHERE priority_score >= 7
                LIMIT 20
            )
        )
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- JSON 5: Demographics
CREATE OR REPLACE FUNCTION analytics.get_demographics_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(
            json_build_object(
                'ageGroup', age_group,
                'gender', gender,
                'customerCount', customer_count,
                'totalRevenue', total_revenue,
                'avgRevenue', avg_revenue_per_customer,
                'pctOfCustomers', pct_of_customers,
                'pctOfRevenue', pct_of_revenue
            ) ORDER BY total_revenue DESC
        )
        FROM analytics.vw_customer_demographics
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- JSON 6: Geography (Top 50)
CREATE OR REPLACE FUNCTION analytics.get_geography_json()
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(
            json_build_object(
                'state', state,
                'city', city,
                'customerCount', customer_count,
                'totalOrders', total_orders,
                'totalRevenue', total_revenue,
                'avgOrderValue', avg_order_value,
                'revenuePerCustomer', revenue_per_customer,
                'rank', revenue_rank
            ) ORDER BY revenue_rank
        )
        FROM analytics.vw_customer_geography
        LIMIT 50
    );
END;
$$ LANGUAGE plpgsql STABLE;

\echo '      ✓ JSON functions created (6 functions)'


-- ============================================================================
-- REFRESH MATERIALIZED VIEWS
-- ============================================================================

\echo ''
\echo 'Refreshing materialized views...'

REFRESH MATERIALIZED VIEW analytics.mv_customer_lifetime_value;
REFRESH MATERIALIZED VIEW analytics.mv_rfm_analysis;
REFRESH MATERIALIZED VIEW analytics.mv_cohort_retention;

\echo '✓ Materialized views refreshed'


-- ============================================================================
-- VERIFICATION
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '             CUSTOMER ANALYTICS MODULE - COMPLETE                           '
\echo '============================================================================'
\echo ''
\echo '✅ Regular Views (4):'
\echo '   • vw_churn_risk_customers    - At-risk customers prioritized'
\echo '   • vw_customer_demographics   - Age/gender breakdown'
\echo '   • vw_customer_geography      - Location distribution'
\echo '   • vw_new_vs_returning        - Acquisition vs retention'
\echo ''
\echo '✅ Materialized Views (3):'
\echo '   • mv_customer_lifetime_value  - CLV with tiers'
\echo '   • mv_rfm_analysis            - RFM segmentation'
\echo '   • mv_cohort_retention        - Cohort retention rates'
\echo ''
\echo '✅ JSON Functions (6):'
\echo '   • get_top_customers_json()'
\echo '   • get_clv_tier_distribution_json()'
\echo '   • get_rfm_segments_json()'
\echo '   • get_churn_risk_json()'
\echo '   • get_demographics_json()'
\echo '   • get_geography_json()'
\echo ''
\echo '📊 Quick Test:'
\echo '   SELECT clv_tier, COUNT(*), ROUND(SUM(total_revenue)::NUMERIC, 2)'
\echo '   FROM analytics.mv_customer_lifetime_value'
\echo '   GROUP BY clv_tier ORDER BY 3 DESC;'
\echo ''
\echo '➡️  Next: Run 03_product_analytics.sql'
\echo '============================================================================'
\echo ''

-- Show CLV distribution
SELECT 
    clv_tier,
    COUNT(*) as customers,
    ROUND(SUM(total_revenue)::NUMERIC, 2) as total_revenue,
    ROUND(AVG(total_revenue)::NUMERIC, 2) as avg_revenue
FROM analytics.mv_customer_lifetime_value
WHERE total_orders > 0
GROUP BY clv_tier
ORDER BY avg_revenue DESC;
