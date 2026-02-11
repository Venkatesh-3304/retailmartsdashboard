/**
 * ============================================================================
 * RetailMart Enterprise Analytics Platform - Project Guide Generator
 * ============================================================================
 * Creates a comprehensive Word document for Day 22 project guide
 * ============================================================================
 */

const fs = require('fs');
const { 
    Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
    Header, Footer, AlignmentType, LevelFormat, HeadingLevel, 
    BorderStyle, WidthType, ShadingType, PageNumber, PageBreak
} = require('docx');

// ============================================================================
// STYLES CONFIGURATION
// ============================================================================

const styles = {
    default: {
        document: {
            run: { font: "Arial", size: 22 } // 11pt default
        }
    },
    paragraphStyles: [
        {
            id: "Title",
            name: "Title",
            basedOn: "Normal",
            run: { size: 56, bold: true, color: "1a365d", font: "Arial" },
            paragraph: { spacing: { before: 240, after: 120 }, alignment: AlignmentType.CENTER }
        },
        {
            id: "Heading1",
            name: "Heading 1",
            basedOn: "Normal",
            next: "Normal",
            quickFormat: true,
            run: { size: 36, bold: true, color: "1e40af", font: "Arial" },
            paragraph: { spacing: { before: 400, after: 200 }, outlineLevel: 0 }
        },
        {
            id: "Heading2",
            name: "Heading 2",
            basedOn: "Normal",
            next: "Normal",
            quickFormat: true,
            run: { size: 28, bold: true, color: "1e3a8a", font: "Arial" },
            paragraph: { spacing: { before: 300, after: 150 }, outlineLevel: 1 }
        },
        {
            id: "Heading3",
            name: "Heading 3",
            basedOn: "Normal",
            next: "Normal",
            quickFormat: true,
            run: { size: 24, bold: true, color: "1e3a8a", font: "Arial" },
            paragraph: { spacing: { before: 200, after: 100 }, outlineLevel: 2 }
        },
        {
            id: "CodeBlock",
            name: "Code Block",
            basedOn: "Normal",
            run: { font: "Consolas", size: 18, color: "1f2937" },
            paragraph: { 
                spacing: { before: 100, after: 100 },
                indent: { left: 360 }
            }
        }
    ]
};

// ============================================================================
// NUMBERING CONFIGURATION
// ============================================================================

const numbering = {
    config: [
        {
            reference: "bullet-list",
            levels: [{
                level: 0,
                format: LevelFormat.BULLET,
                text: "•",
                alignment: AlignmentType.LEFT,
                style: { paragraph: { indent: { left: 720, hanging: 360 } } }
            }]
        },
        {
            reference: "numbered-list-1",
            levels: [{
                level: 0,
                format: LevelFormat.DECIMAL,
                text: "%1.",
                alignment: AlignmentType.LEFT,
                style: { paragraph: { indent: { left: 720, hanging: 360 } } }
            }]
        },
        {
            reference: "numbered-list-2",
            levels: [{
                level: 0,
                format: LevelFormat.DECIMAL,
                text: "%1.",
                alignment: AlignmentType.LEFT,
                style: { paragraph: { indent: { left: 720, hanging: 360 } } }
            }]
        },
        {
            reference: "numbered-list-3",
            levels: [{
                level: 0,
                format: LevelFormat.DECIMAL,
                text: "%1.",
                alignment: AlignmentType.LEFT,
                style: { paragraph: { indent: { left: 720, hanging: 360 } } }
            }]
        },
        {
            reference: "numbered-list-4",
            levels: [{
                level: 0,
                format: LevelFormat.DECIMAL,
                text: "%1.",
                alignment: AlignmentType.LEFT,
                style: { paragraph: { indent: { left: 720, hanging: 360 } } }
            }]
        }
    ]
};

// ============================================================================
// TABLE STYLING
// ============================================================================

const tableBorder = { style: BorderStyle.SINGLE, size: 1, color: "d1d5db" };
const cellBorders = { top: tableBorder, bottom: tableBorder, left: tableBorder, right: tableBorder };
const headerShading = { fill: "e0f2fe", type: ShadingType.CLEAR };

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function createParagraph(text, options = {}) {
    return new Paragraph({
        spacing: { after: 120 },
        ...options,
        children: [new TextRun({ text, ...options.textOptions })]
    });
}

function createHeading1(text) {
    return new Paragraph({
        heading: HeadingLevel.HEADING_1,
        children: [new TextRun(text)]
    });
}

function createHeading2(text) {
    return new Paragraph({
        heading: HeadingLevel.HEADING_2,
        children: [new TextRun(text)]
    });
}

function createHeading3(text) {
    return new Paragraph({
        heading: HeadingLevel.HEADING_3,
        children: [new TextRun(text)]
    });
}

function createBullet(text, reference = "bullet-list") {
    return new Paragraph({
        numbering: { reference, level: 0 },
        children: [new TextRun(text)]
    });
}

function createNumbered(text, reference = "numbered-list-1") {
    return new Paragraph({
        numbering: { reference, level: 0 },
        children: [new TextRun(text)]
    });
}

function createCodeBlock(lines) {
    return lines.map(line => new Paragraph({
        style: "CodeBlock",
        shading: { fill: "f3f4f6", type: ShadingType.CLEAR },
        children: [new TextRun({ text: line, font: "Consolas", size: 18 })]
    }));
}

function createTable(headers, rows, colWidths) {
    const headerRow = new TableRow({
        tableHeader: true,
        children: headers.map((h, i) => new TableCell({
            borders: cellBorders,
            width: { size: colWidths[i], type: WidthType.DXA },
            shading: headerShading,
            children: [new Paragraph({
                alignment: AlignmentType.CENTER,
                children: [new TextRun({ text: h, bold: true, size: 20 })]
            })]
        }))
    });

    const dataRows = rows.map(row => new TableRow({
        children: row.map((cell, i) => new TableCell({
            borders: cellBorders,
            width: { size: colWidths[i], type: WidthType.DXA },
            children: [new Paragraph({
                children: [new TextRun({ text: cell, size: 20 })]
            })]
        }))
    }));

    return new Table({
        columnWidths: colWidths,
        margins: { top: 50, bottom: 50, left: 100, right: 100 },
        rows: [headerRow, ...dataRows]
    });
}

function pageBreak() {
    return new Paragraph({ children: [new PageBreak()] });
}

// ============================================================================
// DOCUMENT CONTENT
// ============================================================================

const children = [
    // ========================================================================
    // TITLE PAGE
    // ========================================================================
    new Paragraph({ spacing: { after: 2000 } }),
    new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: "📊", size: 120 })]
    }),
    new Paragraph({ spacing: { after: 400 } }),
    new Paragraph({
        heading: HeadingLevel.TITLE,
        children: [new TextRun("RetailMart Enterprise Analytics Platform")]
    }),
    new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { after: 200 },
        children: [new TextRun({ text: "Day 22-24 Capstone Project Guide", size: 32, color: "4b5563" })]
    }),
    new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { after: 400 },
        children: [new TextRun({ text: "SQL Bootcamp", size: 24, color: "6b7280" })]
    }),
    new Paragraph({ spacing: { after: 1200 } }),
    new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: "From Learner to Data Analyst", size: 28, italics: true, color: "059669" })]
    }),
    new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { after: 800 },
        children: [new TextRun({ text: "A Complete Enterprise Analytics Implementation", size: 22, color: "6b7280" })]
    }),

    pageBreak(),

    // ========================================================================
    // TABLE OF CONTENTS PLACEHOLDER
    // ========================================================================
    createHeading1("Table of Contents"),
    createParagraph("1. Project Overview"),
    createParagraph("2. Architecture & Folder Structure"),
    createParagraph("3. Module Guide: Sales Analytics"),
    createParagraph("4. Module Guide: Customer Analytics"),
    createParagraph("5. Module Guide: Product Analytics"),
    createParagraph("6. Module Guide: Store Analytics"),
    createParagraph("7. Module Guide: Operations Analytics"),
    createParagraph("8. Module Guide: Marketing Analytics"),
    createParagraph("9. Business Alerts System"),
    createParagraph("10. Dashboard Integration"),
    createParagraph("11. GitHub Deployment"),
    createParagraph("12. Career Guide & Interview Prep"),

    pageBreak(),

    // ========================================================================
    // SECTION 1: PROJECT OVERVIEW
    // ========================================================================
    createHeading1("1. Project Overview"),
    
    createHeading2("1.1 Welcome to Enterprise Analytics"),
    createParagraph("Congratulations! You've spent 21 days learning SQL from the ground up. Now it's time to put everything together into a production-ready analytics platform that would impress any hiring manager."),
    createParagraph(""),
    createParagraph("Imagine you've just joined Flipkart as a Data Analyst. On day one, your manager says:", { textOptions: { italics: true } }),
    createParagraph('"We need a complete analytics solution for RetailMart. Sales dashboards, customer segmentation, inventory tracking, the works. Can you build it?"', { textOptions: { italics: true, color: "1e40af" } }),
    createParagraph(""),
    createParagraph("This project is your answer. By the end, you'll have built exactly what major Indian tech companies use daily."),

    createHeading2("1.2 What Makes This Enterprise-Grade?"),
    createBullet("Materialized Views for fast dashboard queries (used by Amazon, Flipkart)"),
    createBullet("RFM Customer Segmentation (how Swiggy targets promotions)"),
    createBullet("Cohort Retention Analysis (how Netflix measures product-market fit)"),
    createBullet("ABC/Pareto Analysis (how DMart manages inventory)"),
    createBullet("Automated Business Alerts (how PhonePe catches issues early)"),
    createBullet("JSON API Functions (how modern dashboards fetch data)"),
    createBullet("Audit Logging (required for compliance at banks like HDFC)"),

    createHeading2("1.3 Project Statistics"),
    createTable(
        ["Component", "Count", "Purpose"],
        [
            ["SQL Files", "12", "Complete analytics implementation"],
            ["Regular Views", "25", "Real-time analytics queries"],
            ["Materialized Views", "12", "Pre-computed metrics for speed"],
            ["JSON Functions", "32", "Dashboard data API"],
            ["Alert Views", "6", "Automated business monitoring"],
            ["Dashboard Tabs", "7", "Complete web visualization"],
            ["Performance Indexes", "53+", "Query optimization"]
        ],
        [2500, 1500, 5000]
    ),

    createHeading2("1.4 SQL Techniques Used"),
    createParagraph("This project demonstrates mastery of every concept from Days 1-21:"),
    createBullet("CTEs (WITH clauses) - Complex query organization"),
    createBullet("Window Functions - ROW_NUMBER, RANK, DENSE_RANK, LAG, LEAD, NTILE"),
    createBullet("Moving Averages - ROWS BETWEEN n PRECEDING"),
    createBullet("Date Intelligence - DATE_TRUNC, EXTRACT, AGE, INTERVAL"),
    createBullet("Conditional Aggregation - CASE WHEN inside SUM/COUNT"),
    createBullet("Multi-table JOINs - Combining 5+ tables efficiently"),
    createBullet("JSON Functions - json_build_object, json_agg"),
    createBullet("Stored Procedures - Refresh orchestration"),
    createBullet("Materialized Views - Pre-computed analytics"),

    pageBreak(),

    // ========================================================================
    // SECTION 2: ARCHITECTURE
    // ========================================================================
    createHeading1("2. Architecture & Folder Structure"),

    createHeading2("2.1 Project Organization"),
    createParagraph("Enterprise projects follow strict organization. Here's our structure:"),
    ...createCodeBlock([
        "retailmart_analytics_project/",
        "├── 01_setup/                    # Foundation",
        "│   ├── 01_create_analytics_schema.sql",
        "│   ├── 02_create_metadata_tables.sql",
        "│   └── 03_create_indexes.sql",
        "├── 02_data_quality/            # Validation",
        "│   └── data_quality_checks.sql",
        "├── 03_kpi_queries/             # Core Analytics",
        "│   ├── 01_sales_analytics.sql",
        "│   ├── 02_customer_analytics.sql",
        "│   ├── 03_product_analytics.sql",
        "│   ├── 04_store_analytics.sql",
        "│   ├── 05_operations_analytics.sql",
        "│   └── 06_marketing_analytics.sql",
        "├── 04_alerts/                  # Monitoring",
        "│   └── business_alerts.sql",
        "├── 05_refresh/                 # Automation",
        "│   ├── refresh_all_analytics.sql",
        "│   └── export_all_json.sh",
        "├── 06_dashboard/               # Visualization",
        "│   ├── index.html",
        "│   ├── css/styles.css",
        "│   ├── js/dashboard.js",
        "│   └── data/                   # 32 JSON files",
        "└── 07_documentation/           # Documentation",
        "    └── README.md"
    ]),

    createHeading2("2.2 Why This Structure Matters"),
    createParagraph("At Zomato, PhonePe, or any major tech company, you'll see similar organization:"),
    createBullet("Numbered folders ensure correct execution order"),
    createBullet("Each module is independent but follows consistent patterns"),
    createBullet("Separation of concerns (setup vs queries vs alerts)"),
    createBullet("Easy to maintain, test, and deploy"),

    createHeading2("2.3 Data Flow Architecture"),
    createParagraph("Understanding how data flows through the system:"),
    ...createCodeBlock([
        "Source Tables (sales, customers, products, stores)",
        "        ↓",
        "Regular Views (real-time calculations)",
        "        ↓",
        "Materialized Views (pre-computed, refreshed daily)",
        "        ↓",
        "JSON Export Functions (API layer)",
        "        ↓",
        "Dashboard (HTML/JS visualization)"
    ]),

    pageBreak(),

    // ========================================================================
    // SECTION 3: SALES ANALYTICS
    // ========================================================================
    createHeading1("3. Module Guide: Sales Analytics"),

    createHeading2("3.1 The Business Story"),
    createParagraph("Every Monday morning at Amazon India, leadership asks: \"How did we do last week?\" This module answers that question with precision."),
    createParagraph(""),
    createParagraph("Real-world application: When Flipkart's Big Billion Day starts, executives refresh their dashboards every hour to monitor:"),
    createBullet("Real-time revenue vs targets"),
    createBullet("Hour-over-hour growth trends"),
    createBullet("Payment gateway performance"),
    createBullet("Regional performance variations"),

    createHeading2("3.2 Key Components"),
    createTable(
        ["Object Name", "Type", "Purpose"],
        [
            ["mv_monthly_sales_dashboard", "MV", "Monthly trends with MoM/YoY growth"],
            ["mv_executive_summary", "MV", "Top-level KPIs for C-suite"],
            ["vw_daily_sales_summary", "View", "Daily metrics with 7-day moving avg"],
            ["vw_sales_by_dayofweek", "View", "Best performing days"],
            ["vw_sales_by_payment_mode", "View", "Payment method analysis"],
            ["vw_quarterly_sales", "View", "QoQ and YoY comparisons"]
        ],
        [3500, 1000, 4500]
    ),

    createHeading2("3.3 Key SQL Patterns"),
    createHeading3("Pattern 1: Month-over-Month Growth"),
    ...createCodeBlock([
        "-- Using LAG to calculate growth",
        "LAG(gross_revenue, 1) OVER (ORDER BY year, month) as prev_month_revenue,",
        "ROUND(",
        "    ((gross_revenue - LAG(gross_revenue, 1) OVER (ORDER BY year, month))",
        "    / NULLIF(LAG(gross_revenue, 1) OVER (ORDER BY year, month), 0) * 100),",
        "    2",
        ") as mom_growth_pct"
    ]),

    createHeading3("Pattern 2: Rolling/Moving Average"),
    ...createCodeBlock([
        "-- 7-day moving average for trend smoothing",
        "AVG(gross_revenue) OVER (",
        "    ORDER BY date_key",
        "    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW",
        ") as moving_avg_7day"
    ]),

    createHeading3("Pattern 3: Year-to-Date Calculation"),
    ...createCodeBlock([
        "-- Cumulative sum within each year",
        "SUM(gross_revenue) OVER (",
        "    PARTITION BY year",
        "    ORDER BY month",
        "    ROWS UNBOUNDED PRECEDING",
        ") as ytd_revenue"
    ]),

    pageBreak(),

    // ========================================================================
    // SECTION 4: CUSTOMER ANALYTICS
    // ========================================================================
    createHeading1("4. Module Guide: Customer Analytics"),

    createHeading2("4.1 The Business Story"),
    createParagraph("At Swiggy, they discovered something shocking: they were spending ₹600 to acquire each new customer. The critical question became: \"Is our Customer Lifetime Value greater than ₹600?\""),
    createParagraph(""),
    createParagraph("This module answers the questions that keep marketing leaders up at night:"),
    createBullet("Who are our most valuable customers? (CLV Tiers)"),
    createBullet("How should we segment customers for targeting? (RFM Analysis)"),
    createBullet("Are we retaining customers over time? (Cohort Retention)"),
    createBullet("Who is about to leave? (Churn Prediction)"),

    createHeading2("4.2 RFM Analysis Explained"),
    createParagraph("RFM is the gold standard for customer segmentation, used by Amazon, Netflix, and every major retailer:"),
    createBullet("Recency: How recently did they purchase? (Lower days = Higher score)"),
    createBullet("Frequency: How often do they purchase? (More orders = Higher score)"),
    createBullet("Monetary: How much do they spend? (Higher spend = Higher score)"),
    createParagraph(""),
    createParagraph("Each dimension is scored 1-5 using NTILE (quintiles). A customer scoring 5-5-5 is a \"Champion\" - your most valuable customer. A 1-1-1 is \"Lost\" - probably not worth pursuing."),

    createHeading3("RFM Segments and Actions"),
    createTable(
        ["Segment", "RFM Pattern", "Recommended Action"],
        [
            ["Champions", "R≥4, F≥4, M≥4", "Exclusive offers, early access"],
            ["Loyal Customers", "R≥4, F≥3, M≥3", "Loyalty rewards, upsell"],
            ["At Risk - High Value", "R≤2, F≥4, M≥4", "URGENT: Win-back campaign"],
            ["Recent Customers", "R≥4, F≤2, M≤2", "Onboarding, nurture sequence"],
            ["Lost", "R≤2, F≤2, M≤2", "Deep discount or let go"]
        ],
        [2500, 2000, 4500]
    ),

    createHeading2("4.3 Key SQL Pattern: NTILE for Scoring"),
    ...createCodeBlock([
        "-- RFM Scoring using NTILE (quintiles)",
        "NTILE(5) OVER (ORDER BY recency_days DESC) as r_score,",
        "NTILE(5) OVER (ORDER BY frequency ASC) as f_score,",
        "NTILE(5) OVER (ORDER BY monetary ASC) as m_score"
    ]),
    createParagraph("NTILE divides your data into equal buckets. NTILE(5) creates 5 groups of roughly equal size."),

    pageBreak(),

    // ========================================================================
    // SECTION 5: PRODUCT ANALYTICS
    // ========================================================================
    createHeading1("5. Module Guide: Product Analytics"),

    createHeading2("5.1 The Pareto Principle"),
    createParagraph("\"80% of your revenue comes from 20% of your products\" - This is the Pareto Principle, and it's remarkably accurate in retail."),
    createParagraph(""),
    createParagraph("At DMart, inventory managers obsess over ABC Analysis:"),
    createBullet("Class A: Top products generating 80% of revenue (require tight inventory control)"),
    createBullet("Class B: Next set generating 15% of revenue (moderate attention)"),
    createBullet("Class C: Remaining products generating 5% (bulk ordering okay)"),

    createHeading2("5.2 Key SQL Pattern: Cumulative Distribution"),
    ...createCodeBlock([
        "-- ABC Classification using cumulative percentage",
        "WITH with_cumulative AS (",
        "    SELECT *,",
        "        SUM(net_revenue) OVER (ORDER BY net_revenue DESC) as cumulative,",
        "        SUM(net_revenue) OVER () as total",
        "    FROM product_revenue",
        ")",
        "SELECT *,",
        "    CASE",
        "        WHEN cumulative / total <= 0.80 THEN 'A'",
        "        WHEN cumulative / total <= 0.95 THEN 'B'",
        "        ELSE 'C'",
        "    END as abc_classification",
        "FROM with_cumulative"
    ]),

    pageBreak(),

    // ========================================================================
    // SECTION 6-8: OTHER MODULES (Condensed)
    // ========================================================================
    createHeading1("6. Module Guide: Store Analytics"),
    createParagraph("Store analytics helps answer: \"Which stores are stars? Which need help?\""),
    createBullet("Store profitability with revenue minus expenses"),
    createBullet("Regional performance comparison"),
    createBullet("Employee productivity metrics"),
    createBullet("Inventory health by location"),

    createHeading1("7. Module Guide: Operations Analytics"),
    createParagraph("Operations is where promises meet reality. This module tracks:"),
    createBullet("Delivery SLA performance (On-time delivery %)"),
    createBullet("Courier partner comparison"),
    createBullet("Return analysis by category and reason"),
    createBullet("Payment gateway success rates"),

    createHeading1("8. Module Guide: Marketing Analytics"),
    createParagraph("Marketing needs to prove ROI. This module provides:"),
    createBullet("Campaign ROI calculation"),
    createBullet("Channel performance comparison"),
    createBullet("Promotion effectiveness measurement"),
    createBullet("Email engagement metrics"),

    pageBreak(),

    // ========================================================================
    // SECTION 9: ALERTS
    // ========================================================================
    createHeading1("9. Business Alerts System"),

    createHeading2("9.1 Why Automated Alerts?"),
    createParagraph("The best time to fix a problem is before it becomes a crisis. At Amazon, alerts fire automatically when:"),
    createBullet("Inventory falls below safety stock (prevents stockouts)"),
    createBullet("High-value customers go inactive (enables retention)"),
    createBullet("Revenue drops unexpectedly (catches issues early)"),
    createBullet("Shipments are delayed (maintains customer trust)"),

    createHeading2("9.2 Alert Severity Levels"),
    createTable(
        ["Severity", "Response Time", "Channel", "Example"],
        [
            ["HIGH", "Immediate", "Pager/Slack", "Platinum customer churning"],
            ["MEDIUM", "Same day", "Email/Slack", "Revenue 25%+ below average"],
            ["LOW", "This week", "Dashboard", "Category return rate high"]
        ],
        [1500, 1800, 2000, 3700]
    ),

    createHeading2("9.3 Implemented Alerts"),
    createBullet("CRITICAL_STOCK: Top 100 products with stock < 10 units"),
    createBullet("HIGH_VALUE_CHURN: Platinum/Gold customers inactive 60+ days"),
    createBullet("REVENUE_ANOMALY: Daily revenue 25%+ below 7-day average"),
    createBullet("DELAYED_SHIPMENT: Orders not shipped within 3 days"),
    createBullet("HIGH_RETURN_RATE: Categories with > 15% return rate"),
    createBullet("PAYMENT_SHIFT: Significant payment method usage changes"),

    pageBreak(),

    // ========================================================================
    // SECTION 10: DASHBOARD
    // ========================================================================
    createHeading1("10. Dashboard Integration"),

    createHeading2("10.1 SQL to Dashboard Flow"),
    createParagraph("Understanding how SQL becomes a visual dashboard:"),
    ...createCodeBlock([
        "Step 1: SQL View/MV calculates metrics",
        "        SELECT SUM(total_amount) as revenue FROM sales.orders",
        "",
        "Step 2: JSON Function wraps for API",
        "        SELECT json_build_object('revenue', revenue) FROM ...",
        "",
        "Step 3: Export Script creates JSON files",
        "        psql -c \"SELECT get_executive_summary_json()\" > data.json",
        "",
        "Step 4: JavaScript fetches and renders",
        "        fetch('data/sales/executive_summary.json')",
        "        .then(data => createChart(data))"
    ]),

    createHeading2("10.2 Dashboard Tabs"),
    createTable(
        ["Tab", "Charts", "Key Metrics"],
        [
            ["Executive", "Revenue Trend, Category Pie", "Total Revenue, Orders, AOV"],
            ["Sales", "Daily Trend, Day of Week, Quarterly", "Growth %, Payment Mix"],
            ["Products", "Top Products, ABC Pie, Categories", "Best Sellers, Stock Status"],
            ["Customers", "RFM Segments, CLV Tiers, Churn", "Segments, At-Risk Count"],
            ["Stores", "Regional Comparison, Rankings", "Store P&L, Margin %"],
            ["Operations", "Delivery SLA, Courier Comparison", "On-Time %, Return Rate"],
            ["Marketing", "Campaign ROI, Channel Performance", "ROAS, Conversion Rate"]
        ],
        [2000, 3500, 3500]
    ),

    pageBreak(),

    // ========================================================================
    // SECTION 11: GITHUB DEPLOYMENT
    // ========================================================================
    createHeading1("11. GitHub Deployment"),

    createHeading2("11.1 Step-by-Step Guide"),
    createNumbered("Create GitHub Repository", "numbered-list-2"),
    ...createCodeBlock([
        "# On github.com, create new repository: 'retailmart-analytics'"
    ]),
    createNumbered("Initialize Local Repository", "numbered-list-2"),
    ...createCodeBlock([
        "cd retailmart_analytics_project",
        "git init",
        "git add .",
        "git commit -m \"Initial commit: RetailMart Analytics Platform\""
    ]),
    createNumbered("Push to GitHub", "numbered-list-2"),
    ...createCodeBlock([
        "git remote add origin https://github.com/YOUR_USERNAME/retailmart-analytics.git",
        "git branch -M main",
        "git push -u origin main"
    ]),
    createNumbered("Enable GitHub Pages (for dashboard)", "numbered-list-2"),
    createBullet("Go to Repository Settings → Pages"),
    createBullet("Source: Deploy from a branch"),
    createBullet("Branch: main, folder: /06_dashboard"),
    createBullet("Save and wait for deployment"),

    createHeading2("11.2 What to Include in README"),
    createBullet("Project overview and screenshots"),
    createBullet("Technologies used (PostgreSQL, Chart.js)"),
    createBullet("Setup instructions"),
    createBullet("SQL techniques demonstrated"),
    createBullet("Live dashboard link"),

    pageBreak(),

    // ========================================================================
    // SECTION 12: CAREER GUIDE
    // ========================================================================
    createHeading1("12. Career Guide & Interview Prep"),

    createHeading2("12.1 Target Companies"),
    createParagraph("This project demonstrates skills valued by:"),
    createTable(
        ["Company", "Role", "Salary Range"],
        [
            ["Flipkart", "Business Analyst", "₹12-20 LPA"],
            ["Amazon India", "Data Analyst", "₹15-25 LPA"],
            ["Swiggy/Zomato", "Analytics Manager", "₹18-30 LPA"],
            ["PhonePe/Paytm", "Senior Analyst", "₹14-22 LPA"],
            ["Meesho/Cred", "Growth Analyst", "₹12-18 LPA"],
            ["HDFC/ICICI", "MIS Analyst", "₹8-15 LPA"]
        ],
        [3000, 3000, 3000]
    ),

    createHeading2("12.2 Interview Talking Points"),
    createParagraph("When discussing this project in interviews, highlight:"),
    createBullet("\"I built a complete analytics platform with 12 SQL modules and 25+ views\""),
    createBullet("\"I implemented RFM segmentation - the same approach used by Amazon and Swiggy\""),
    createBullet("\"I created automated alerts that would catch issues like high-value customer churn\""),
    createBullet("\"I used materialized views for performance - reducing dashboard load time by 10x\""),
    createBullet("\"I built a responsive dashboard with Chart.js that visualizes all KPIs\""),

    createHeading2("12.3 Technical Questions to Prepare"),
    createNumbered("\"How did you handle slowly changing dimensions?\"", "numbered-list-3"),
    createParagraph("→ Explain how CLV tiers are recalculated daily based on cumulative spend."),
    createNumbered("\"Why use materialized views vs regular views?\"", "numbered-list-3"),
    createParagraph("→ MVs pre-compute expensive calculations. Executive summary with YTD, MoM, YoY would be slow as a regular view scanning millions of rows."),
    createNumbered("\"How would you optimize a slow query?\"", "numbered-list-3"),
    createParagraph("→ Discuss indexes created on date columns, foreign keys, and frequently filtered columns."),
    createNumbered("\"Explain your RFM implementation.\"", "numbered-list-3"),
    createParagraph("→ Walk through NTILE for quintile scoring, segment logic, and recommended actions."),

    createHeading2("12.4 Portfolio Tips"),
    createBullet("Add live dashboard link to your resume"),
    createBullet("Include 2-3 screenshots in LinkedIn posts"),
    createBullet("Write a Medium article explaining the architecture"),
    createBullet("Record a 5-minute Loom walkthrough"),

    new Paragraph({ spacing: { after: 400 } }),
    new Paragraph({
        alignment: AlignmentType.CENTER,
        shading: { fill: "e0f2fe", type: ShadingType.CLEAR },
        spacing: { before: 200, after: 200 },
        children: [new TextRun({ 
            text: "🎉 Congratulations! You've completed the RetailMart Enterprise Analytics Platform!", 
            size: 24, 
            bold: true,
            color: "1e40af"
        })]
    }),
    new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [new TextRun({ 
            text: "You're now equipped with skills that will serve you throughout your data career.", 
            size: 22,
            italics: true,
            color: "4b5563"
        })]
    })
];

// ============================================================================
// CREATE DOCUMENT
// ============================================================================

const doc = new Document({
    styles,
    numbering,
    sections: [{
        properties: {
            page: {
                margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 }
            }
        },
        headers: {
            default: new Header({
                children: [new Paragraph({
                    alignment: AlignmentType.RIGHT,
                    children: [new TextRun({ 
                        text: "RetailMart Analytics | SQL Bootcamp", 
                        size: 18, 
                        color: "9ca3af" 
                    })]
                })]
            })
        },
        footers: {
            default: new Footer({
                children: [new Paragraph({
                    alignment: AlignmentType.CENTER,
                    children: [
                        new TextRun({ text: "Page ", size: 18, color: "9ca3af" }),
                        new TextRun({ children: [PageNumber.CURRENT], size: 18, color: "9ca3af" }),
                        new TextRun({ text: " of ", size: 18, color: "9ca3af" }),
                        new TextRun({ children: [PageNumber.TOTAL_PAGES], size: 18, color: "9ca3af" })
                    ]
                })]
            })
        },
        children
    }]
});

// ============================================================================
// SAVE DOCUMENT
// ============================================================================

Packer.toBuffer(doc).then(buffer => {
    fs.writeFileSync('/home/claude/retailmart_analytics_project/07_documentation/RetailMart_Project_Guide.docx', buffer);
    console.log('✅ Document created: RetailMart_Project_Guide.docx');
}).catch(err => {
    console.error('Error creating document:', err);
});
