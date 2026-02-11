-- ============================================================================
-- FILE: 03_kpi_queries/06_marketing_analytics.sql
-- PROJECT: RetailMart Enterprise Analytics Platform
-- PURPOSE: Marketing Analytics - Campaign ROI, Promotion effectiveness
-- AUTHOR: SQL Bootcamp
-- CREATED: 2025
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '             MARKETING ANALYTICS MODULE - STARTING                          '
\echo '============================================================================'
\echo ''

\echo '[1/5] Creating view: vw_campaign_performance...'

CREATE OR REPLACE VIEW analytics.vw_campaign_performance AS
WITH campaign_spend AS (
    SELECT 
        c.campaign_id, c.campaign_name, c.start_date, c.end_date, c.budget,
        COALESCE(SUM(a.amount), 0) as actual_spend,
        COALESCE(SUM(a.clicks), 0) as total_clicks,
        COALESCE(SUM(a.conversions), 0) as total_conversions
    FROM marketing.campaigns c
    LEFT JOIN marketing.ads_spend a ON c.campaign_id = a.campaign_id
    GROUP BY c.campaign_id, c.campaign_name, c.start_date, c.end_date, c.budget
),
campaign_revenue AS (
    SELECT c.campaign_id,
        COUNT(DISTINCT o.order_id) as orders_during_campaign,
        COALESCE(SUM(o.total_amount), 0) as revenue_during_campaign
    FROM marketing.campaigns c
    LEFT JOIN sales.orders o ON o.order_date BETWEEN c.start_date AND c.end_date AND o.order_status = 'Delivered'
    GROUP BY c.campaign_id
)
SELECT 
    cs.campaign_id, cs.campaign_name, cs.start_date, cs.end_date,
    cs.end_date - cs.start_date as duration_days,
    ROUND(cs.budget::NUMERIC, 2) as budget,
    ROUND(cs.actual_spend::NUMERIC, 2) as actual_spend,
    cs.total_clicks, cs.total_conversions,
    CASE WHEN cs.total_clicks > 0 THEN ROUND((cs.total_conversions::NUMERIC / cs.total_clicks * 100), 2) ELSE 0 END as conversion_rate_pct,
    CASE WHEN cs.total_clicks > 0 THEN ROUND((cs.actual_spend / cs.total_clicks)::NUMERIC, 2) ELSE 0 END as cost_per_click,
    cr.orders_during_campaign,
    ROUND(cr.revenue_during_campaign::NUMERIC, 2) as attributed_revenue,
    CASE WHEN cs.actual_spend > 0 THEN ROUND(((cr.revenue_during_campaign - cs.actual_spend) / cs.actual_spend * 100)::NUMERIC, 2) ELSE 0 END as roi_pct,
    CASE 
        WHEN cs.actual_spend = 0 THEN 'Not Started'
        WHEN ((cr.revenue_during_campaign - cs.actual_spend) / NULLIF(cs.actual_spend, 0) * 100) >= 200 THEN 'Excellent'
        WHEN ((cr.revenue_during_campaign - cs.actual_spend) / NULLIF(cs.actual_spend, 0) * 100) >= 100 THEN 'Good'
        WHEN ((cr.revenue_during_campaign - cs.actual_spend) / NULLIF(cs.actual_spend, 0) * 100) >= 0 THEN 'Break Even'
        ELSE 'Losing Money'
    END as campaign_status
FROM campaign_spend cs
LEFT JOIN campaign_revenue cr ON cs.campaign_id = cr.campaign_id
ORDER BY cs.start_date DESC;

\echo '      ✓ View created: vw_campaign_performance'

\echo '[2/5] Creating view: vw_channel_performance...'

CREATE OR REPLACE VIEW analytics.vw_channel_performance AS
SELECT 
    a.channel,
    COUNT(DISTINCT a.campaign_id) as campaigns_using,
    ROUND(SUM(a.amount)::NUMERIC, 2) as total_spend,
    SUM(a.clicks) as total_clicks,
    SUM(a.conversions) as total_conversions,
    ROUND((SUM(a.amount) / NULLIF(SUM(a.clicks), 0))::NUMERIC, 2) as avg_cost_per_click,
    ROUND((SUM(a.conversions)::NUMERIC / NULLIF(SUM(a.clicks), 0) * 100), 2) as conversion_rate_pct,
    ROUND((SUM(a.amount) / SUM(SUM(a.amount)) OVER () * 100)::NUMERIC, 2) as pct_of_total_spend,
    RANK() OVER (ORDER BY SUM(a.conversions)::NUMERIC / NULLIF(SUM(a.clicks), 0) DESC NULLS LAST) as efficiency_rank
FROM marketing.ads_spend a
GROUP BY a.channel
ORDER BY total_spend DESC;

\echo '      ✓ View created: vw_channel_performance'

\echo '[3/5] Creating view: vw_promotion_effectiveness...'

CREATE OR REPLACE VIEW analytics.vw_promotion_effectiveness AS
WITH promo_sales AS (
    SELECT p.promo_id, p.promo_name, p.start_date, p.end_date, p.discount_percent,
        COUNT(DISTINCT o.order_id) as orders, SUM(o.total_amount) as revenue
    FROM products.promotions p
    LEFT JOIN sales.orders o ON o.order_date BETWEEN p.start_date AND p.end_date AND o.order_status = 'Delivered'
    GROUP BY p.promo_id, p.promo_name, p.start_date, p.end_date, p.discount_percent
)
SELECT promo_id, promo_name, start_date, end_date, 
    end_date - start_date as duration_days, discount_percent,
    COALESCE(orders, 0) as orders, ROUND(COALESCE(revenue, 0)::NUMERIC, 2) as revenue
FROM promo_sales ORDER BY start_date DESC;

\echo '      ✓ View created: vw_promotion_effectiveness'

\echo '[4/5] Creating view: vw_email_engagement...'

CREATE OR REPLACE VIEW analytics.vw_email_engagement AS
SELECT 
    c.campaign_id, c.campaign_name,
    DATE_TRUNC('month', e.sent_date)::DATE as send_month,
    COUNT(*) as emails_sent,
    COUNT(*) FILTER (WHERE e.opened) as emails_opened,
    COUNT(*) FILTER (WHERE e.clicked) as emails_clicked,
    ROUND((COUNT(*) FILTER (WHERE e.opened)::NUMERIC / NULLIF(COUNT(*), 0) * 100), 2) as open_rate_pct,
    ROUND((COUNT(*) FILTER (WHERE e.clicked)::NUMERIC / NULLIF(COUNT(*), 0) * 100), 2) as click_rate_pct
FROM marketing.email_clicks e
JOIN marketing.campaigns c ON e.campaign_id = c.campaign_id
GROUP BY c.campaign_id, c.campaign_name, DATE_TRUNC('month', e.sent_date)
ORDER BY send_month DESC;

\echo '      ✓ View created: vw_email_engagement'

\echo '[5/5] Creating materialized view: mv_marketing_roi...'

DROP MATERIALIZED VIEW IF EXISTS analytics.mv_marketing_roi CASCADE;

CREATE MATERIALIZED VIEW analytics.mv_marketing_roi AS
SELECT 
    (SELECT MAX(order_date) FROM sales.orders) as reference_date,
    COUNT(DISTINCT c.campaign_id) as total_campaigns,
    ROUND(SUM(c.budget)::NUMERIC, 2) as total_budget,
    ROUND(COALESCE(SUM(a.amount), 0)::NUMERIC, 2) as total_spend,
    COALESCE(SUM(a.clicks), 0) as total_clicks,
    COALESCE(SUM(a.conversions), 0) as total_conversions,
    ROUND((COALESCE(SUM(a.conversions), 0)::NUMERIC / NULLIF(SUM(a.clicks), 0) * 100), 2) as overall_conversion_rate,
    ROUND((COALESCE(SUM(a.amount), 0) / NULLIF(SUM(a.clicks), 0))::NUMERIC, 2) as overall_cpc
FROM marketing.campaigns c
LEFT JOIN marketing.ads_spend a ON c.campaign_id = a.campaign_id;

\echo '      ✓ Materialized view created: mv_marketing_roi'

-- JSON Functions
CREATE OR REPLACE FUNCTION analytics.get_marketing_summary_json() RETURNS JSON AS $$
BEGIN RETURN (SELECT row_to_json(t) FROM analytics.mv_marketing_roi t); END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_campaign_performance_json() RETURNS JSON AS $$
BEGIN RETURN (
    SELECT json_agg(json_build_object(
        'campaignName', campaign_name, 'budget', budget, 'spend', actual_spend,
        'clicks', total_clicks, 'conversions', total_conversions, 'roi', roi_pct, 'status', campaign_status
    ) ORDER BY start_date DESC)
    FROM analytics.vw_campaign_performance LIMIT 20
); END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_channel_performance_json() RETURNS JSON AS $$
BEGIN RETURN (
    SELECT json_agg(json_build_object(
        'channel', channel, 'spend', total_spend, 'clicks', total_clicks,
        'conversions', total_conversions, 'conversionRate', conversion_rate_pct, 'efficiencyRank', efficiency_rank
    ) ORDER BY total_spend DESC)
    FROM analytics.vw_channel_performance
); END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION analytics.get_email_engagement_json() RETURNS JSON AS $$
BEGIN RETURN (
    SELECT json_agg(json_build_object(
        'campaignName', campaign_name, 'sent', emails_sent, 'opened', emails_opened,
        'clicked', emails_clicked, 'openRate', open_rate_pct, 'clickRate', click_rate_pct
    ) ORDER BY send_month DESC)
    FROM analytics.vw_email_engagement LIMIT 20
); END;
$$ LANGUAGE plpgsql STABLE;

\echo '      ✓ JSON functions created (4 functions)'

REFRESH MATERIALIZED VIEW analytics.mv_marketing_roi;

\echo ''
\echo '============================================================================'
\echo '             MARKETING ANALYTICS MODULE - COMPLETE                          '
\echo '============================================================================'
