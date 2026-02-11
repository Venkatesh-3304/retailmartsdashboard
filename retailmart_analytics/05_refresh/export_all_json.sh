#!/bin/bash
# ============================================================================
# FILE: 05_refresh/export_all_json.sh
# PROJECT: RetailMart Enterprise Analytics Platform
# PURPOSE: Export all analytics data to JSON files for dashboard
# ============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

DB_NAME="${DB_NAME:-retailmart_analytics}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/06_dashboard/data"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$SCRIPT_DIR/logs/export_log_$TIMESTAMP.txt"

export_json() {
    local fn=$1 out=$2 desc=$3
    echo "  Exporting $desc..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT $fn();" > "$out" 2>> "$LOG_FILE"
    [ $? -eq 0 ] && [ -s "$out" ] && echo -e "    ${GREEN}✓${NC} $out" || echo -e "    ${RED}✗${NC} Failed: $desc"
}

echo -e "\n${BLUE}=== RETAILMART JSON EXPORT ===${NC}\n"
mkdir -p "$DATA_DIR"/{sales,customers,products,stores,operations,marketing}

# Refresh if requested
[ "$1" = "--refresh" ] && psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM analytics.fn_refresh_all_analytics();" >> "$LOG_FILE" 2>&1

echo -e "${YELLOW}[1/6] Sales Data${NC}"
export_json "analytics.get_executive_summary_json" "$DATA_DIR/sales/executive_summary.json" "Executive Summary"
export_json "analytics.get_monthly_trend_json" "$DATA_DIR/sales/monthly_trend.json" "Monthly Trend"
export_json "analytics.get_recent_trend_json" "$DATA_DIR/sales/recent_trend.json" "Recent Trend"
export_json "analytics.get_dayofweek_json" "$DATA_DIR/sales/dayofweek.json" "Day of Week"
export_json "analytics.get_payment_mode_json" "$DATA_DIR/sales/payment_modes.json" "Payment Modes"
export_json "analytics.get_quarterly_sales_json" "$DATA_DIR/sales/quarterly_sales.json" "Quarterly"
export_json "analytics.get_weekend_weekday_json" "$DATA_DIR/sales/weekend_weekday.json" "Weekend vs Weekday"
export_json "analytics.get_hourly_pattern_json" "$DATA_DIR/sales/hourly_pattern.json" "Hourly Pattern"

echo -e "${YELLOW}[2/6] Customer Data${NC}"
export_json "analytics.get_top_customers_json" "$DATA_DIR/customers/top_customers.json" "Top Customers"
export_json "analytics.get_clv_tier_distribution_json" "$DATA_DIR/customers/clv_tiers.json" "CLV Tiers"
export_json "analytics.get_rfm_segments_json" "$DATA_DIR/customers/rfm_segments.json" "RFM Segments"
export_json "analytics.get_churn_risk_json" "$DATA_DIR/customers/churn_risk.json" "Churn Risk"
export_json "analytics.get_demographics_json" "$DATA_DIR/customers/demographics.json" "Demographics"
export_json "analytics.get_geography_json" "$DATA_DIR/customers/geography.json" "Geography"

echo -e "${YELLOW}[3/6] Product Data${NC}"
export_json "analytics.get_top_products_json" "$DATA_DIR/products/top_products.json" "Top Products"
export_json "analytics.get_category_performance_json" "$DATA_DIR/products/categories.json" "Categories"
export_json "analytics.get_brand_performance_json" "$DATA_DIR/products/brands.json" "Brands"
export_json "analytics.get_abc_analysis_json" "$DATA_DIR/products/abc_analysis.json" "ABC Analysis"
export_json "analytics.get_inventory_status_json" "$DATA_DIR/products/inventory_status.json" "Inventory"

echo -e "${YELLOW}[4/6] Store Data${NC}"
export_json "analytics.get_top_stores_json" "$DATA_DIR/stores/top_stores.json" "Top Stores"
export_json "analytics.get_regional_performance_json" "$DATA_DIR/stores/regional.json" "Regional"
export_json "analytics.get_store_inventory_json" "$DATA_DIR/stores/inventory.json" "Store Inventory"
export_json "analytics.get_employee_distribution_json" "$DATA_DIR/stores/employees.json" "Employee Distribution"

echo -e "${YELLOW}[5/6] Operations Data${NC}"
export_json "analytics.get_operations_summary_json" "$DATA_DIR/operations/summary.json" "Summary"
export_json "analytics.get_delivery_performance_json" "$DATA_DIR/operations/delivery.json" "Delivery"
export_json "analytics.get_courier_comparison_json" "$DATA_DIR/operations/couriers.json" "Couriers"
export_json "analytics.get_return_analysis_json" "$DATA_DIR/operations/returns.json" "Returns"
export_json "analytics.get_pending_shipments_json" "$DATA_DIR/operations/pending.json" "Pending"

echo -e "${YELLOW}[6/6] Marketing Data${NC}"
export_json "analytics.get_marketing_summary_json" "$DATA_DIR/marketing/summary.json" "Summary"
export_json "analytics.get_campaign_performance_json" "$DATA_DIR/marketing/campaigns.json" "Campaigns"
export_json "analytics.get_channel_performance_json" "$DATA_DIR/marketing/channels.json" "Channels"
export_json "analytics.get_email_engagement_json" "$DATA_DIR/marketing/email.json" "Email"

echo -e "${YELLOW}Alerts${NC}"
export_json "analytics.get_all_alerts_json" "$DATA_DIR/alerts.json" "All Alerts"

echo -e "\n${GREEN}=== EXPORT COMPLETE ===${NC}"
echo "Files: $(find "$DATA_DIR" -name "*.json" | wc -l) JSON files"
echo "Location: $DATA_DIR"
