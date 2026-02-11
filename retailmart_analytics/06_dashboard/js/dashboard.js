/**
 * ============================================================================
 * FILE: js/dashboard.js
 * PROJECT: RetailMart Enterprise Analytics Platform
 * PURPOSE: Dashboard interactivity, data loading, and chart rendering
 * AUTHOR: SQL Bootcamp
 * ============================================================================
 */

// ============================================================================
// CONFIGURATION
// ============================================================================

const CONFIG = {
  dataPath: "./data",
  refreshInterval: 300000, // 5 minutes
  chartColors: {
    primary: "#2563eb",
    success: "#10b981",
    warning: "#f59e0b",
    danger: "#ef4444",
    info: "#06b6d4",
    purple: "#8b5cf6",
    pink: "#ec4899",
    indigo: "#6366f1",
    teal: "#14b8a6",
    orange: "#f97316",
  },
  chartPalette: [
    "#2563eb",
    "#10b981",
    "#f59e0b",
    "#ef4444",
    "#8b5cf6",
    "#ec4899",
    "#06b6d4",
    "#f97316",
    "#6366f1",
    "#14b8a6",
  ],
};

// ============================================================================
// STATE MANAGEMENT
// ============================================================================

const state = {
  data: {},
  charts: {},
  currentTab: "executive",
  isLoading: false,
};

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

const Utils = {
  // Format currency (INR)
  formatCurrency(value) {
    if (value === null || value === undefined) return "₹0";
    const num = parseFloat(value);
    if (num >= 10000000) return "₹" + (num / 10000000).toFixed(2) + " Cr";
    if (num >= 100000) return "₹" + (num / 100000).toFixed(2) + " L";
    if (num >= 1000) return "₹" + (num / 1000).toFixed(1) + "K";
    return "₹" + num.toFixed(0);
  },

  // Format number with commas
  formatNumber(value) {
    if (value === null || value === undefined) return "0";
    return parseFloat(value).toLocaleString("en-IN");
  },

  // Format percentage
  formatPercent(value, decimals = 1) {
    if (value === null || value === undefined) return "0%";
    return parseFloat(value).toFixed(decimals) + "%";
  },

  // Get change indicator
  getChangeIndicator(value) {
    if (value > 0)
      return {
        class: "positive",
        icon: "↑",
        text: "+" + this.formatPercent(value),
      };
    if (value < 0)
      return { class: "negative", icon: "↓", text: this.formatPercent(value) };
    return { class: "neutral", icon: "→", text: "0%" };
  },

  // Truncate text
  truncate(text, maxLength = 30) {
    if (!text) return "";
    return text.length > maxLength
      ? text.substring(0, maxLength) + "..."
      : text;
  },

  // Safe array access
  safeArray(data) {
    return Array.isArray(data) ? data : [];
  },

  // Create badge HTML
  createBadge(text, type = "info") {
    return `<span class="badge badge-${type}">${text}</span>`;
  },
};

// ============================================================================
// DATA LOADING
// ============================================================================

const DataLoader = {
  async loadJSON(path) {
    try {
      const response = await fetch(`${CONFIG.dataPath}/${path}`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return await response.json();
    } catch (error) {
      console.warn(`Failed to load ${path}:`, error.message);
      return null;
    }
  },

  async loadAllData() {
    showLoading(true);

    try {
      // Load all data in parallel
      const [
        executiveSummary,
        monthlyTrend,
        recentTrend,
        dayOfWeek,
        paymentModes,
        quarterly,
        topProducts,
        categories,
        abcAnalysis,
        inventoryStatus,
        topCustomers,
        clvTiers,
        rfmSegments,
        churnRisk,
        demographics,
        topStores,
        regional,
        deliveryPerf,
        couriers,
        returns,
        campaigns,
        channels,
        alerts,
      ] = await Promise.all([
        this.loadJSON("sales/executive_summary.json"),
        this.loadJSON("sales/monthly_trend.json"),
        this.loadJSON("sales/recent_trend.json"),
        this.loadJSON("sales/dayofweek.json"),
        this.loadJSON("sales/payment_modes.json"),
        this.loadJSON("sales/quarterly_sales.json"),
        this.loadJSON("products/top_products.json"),
        this.loadJSON("products/categories.json"),
        this.loadJSON("products/abc_analysis.json"),
        this.loadJSON("products/inventory_status.json"),
        this.loadJSON("customers/top_customers.json"),
        this.loadJSON("customers/clv_tiers.json"),
        this.loadJSON("customers/rfm_segments.json"),
        this.loadJSON("customers/churn_risk.json"),
        this.loadJSON("customers/demographics.json"),
        this.loadJSON("stores/top_stores.json"),
        this.loadJSON("stores/regional.json"),
        this.loadJSON("operations/delivery.json"),
        this.loadJSON("operations/couriers.json"),
        this.loadJSON("operations/returns.json"),
        this.loadJSON("marketing/campaigns.json"),
        this.loadJSON("marketing/channels.json"),
        this.loadJSON("alerts.json"),
      ]);

      state.data = {
        executiveSummary,
        monthlyTrend: Utils.safeArray(monthlyTrend),
        recentTrend: Utils.safeArray(recentTrend),
        dayOfWeek: Utils.safeArray(dayOfWeek),
        paymentModes: Utils.safeArray(paymentModes),
        quarterly: Utils.safeArray(quarterly),
        topProducts: Utils.safeArray(topProducts),
        categories: Utils.safeArray(categories),
        abcAnalysis,
        inventoryStatus: Utils.safeArray(inventoryStatus),
        topCustomers: Utils.safeArray(topCustomers),
        clvTiers: Utils.safeArray(clvTiers),
        rfmSegments: Utils.safeArray(rfmSegments),
        churnRisk,
        demographics: Utils.safeArray(demographics),
        topStores: Utils.safeArray(topStores),
        regional: Utils.safeArray(regional),
        deliveryPerf: Utils.safeArray(deliveryPerf),
        couriers: Utils.safeArray(couriers),
        returns,
        campaigns: Utils.safeArray(campaigns),
        channels: Utils.safeArray(channels),
        alerts,
      };

      console.log("Data loaded successfully");
      return true;
    } catch (error) {
      console.error("Error loading data:", error);
      return false;
    } finally {
      showLoading(false);
    }
  },
};

// ============================================================================
// CHART MANAGEMENT
// ============================================================================

const ChartManager = {
  // Destroy existing chart
  destroy(chartId) {
    if (state.charts[chartId]) {
      state.charts[chartId].destroy();
      delete state.charts[chartId];
    }
  },

  // Create line chart
  createLineChart(canvasId, labels, datasets, options = {}) {
    this.destroy(canvasId);
    const ctx = document.getElementById(canvasId);
    if (!ctx) return null;

    state.charts[canvasId] = new Chart(ctx, {
      type: "line",
      data: { labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: "top" },
        },
        scales: {
          y: { beginAtZero: false },
        },
        ...options,
      },
    });
    return state.charts[canvasId];
  },

  // Create bar chart
  createBarChart(canvasId, labels, datasets, options = {}) {
    this.destroy(canvasId);
    const ctx = document.getElementById(canvasId);
    if (!ctx) return null;

    state.charts[canvasId] = new Chart(ctx, {
      type: "bar",
      data: { labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: datasets.length > 1 },
        },
        ...options,
      },
    });
    return state.charts[canvasId];
  },

  // Create doughnut/pie chart
  createDoughnutChart(canvasId, labels, data, options = {}) {
    this.destroy(canvasId);
    const ctx = document.getElementById(canvasId);
    if (!ctx) return null;

    state.charts[canvasId] = new Chart(ctx, {
      type: "doughnut",
      data: {
        labels,
        datasets: [
          {
            data,
            backgroundColor: CONFIG.chartPalette.slice(0, data.length),
            borderWidth: 0,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: "right" },
        },
        ...options,
      },
    });
    return state.charts[canvasId];
  },

  // Create horizontal bar chart
  createHorizontalBarChart(canvasId, labels, data, options = {}) {
    this.destroy(canvasId);
    const ctx = document.getElementById(canvasId);
    if (!ctx) return null;

    state.charts[canvasId] = new Chart(ctx, {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            data,
            backgroundColor: CONFIG.chartColors.primary,
            borderRadius: 4,
          },
        ],
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
        },
        ...options,
      },
    });
    return state.charts[canvasId];
  },
};

// ============================================================================
// RENDER FUNCTIONS
// ============================================================================

function renderExecutiveTab() {
  const data = state.data;

  // KPI Cards
  if (data.executiveSummary) {
    const es = data.executiveSummary;

    updateKPI(
      "kpiTotalRevenue",
      Utils.formatCurrency(es.total_revenue),
      es.revenue_growth_pct,
      "vs last 30 days"
    );
    updateKPI(
      "kpiTotalOrders",
      Utils.formatNumber(es.total_orders),
      es.orders_growth_pct,
      "vs last 30 days"
    );
    updateKPI("kpiTotalCustomers", Utils.formatNumber(es.total_customers));
    updateKPI("kpiAvgOrderValue", Utils.formatCurrency(es.overall_aov));

    // Update data freshness
    if (es.reference_date) {
      document.querySelector(
        ".freshness-text"
      ).textContent = `Data as of ${new Date(
        es.reference_date
      ).toLocaleDateString("en-IN")}`;
    }
  }

  // Revenue Trend Chart
  if (data.monthlyTrend && data.monthlyTrend.length > 0) {
    const sorted = [...data.monthlyTrend].sort((a, b) =>
      a.monthKey.localeCompare(b.monthKey)
    );

    ChartManager.createLineChart(
      "chartRevenueTrend",
      sorted.map((m) => m.monthName),
      [
        {
          label: "Revenue",
          data: sorted.map((m) => m.revenue),
          borderColor: CONFIG.chartColors.primary,
          backgroundColor: "rgba(37, 99, 235, 0.1)",
          fill: true,
          tension: 0.3,
        },
      ]
    );
  }

  // Category Revenue Chart
  if (data.categories && data.categories.length > 0) {
    const top6 = data.categories.slice(0, 6);
    ChartManager.createDoughnutChart(
      "chartCategoryRevenue",
      top6.map((c) => c.category),
      top6.map((c) => c.revenue)
    );
  }

  // Top Products Table
  if (data.topProducts && data.topProducts.length > 0) {
    const tbody = document.querySelector("#tableTopProducts tbody");
    if (tbody) {
      tbody.innerHTML = data.topProducts
        .slice(0, 10)
        .map(
          (p, i) => `
                <tr>
                    <td>${i + 1}</td>
                    <td class="truncate" title="${
                      p.productName
                    }">${Utils.truncate(p.productName, 25)}</td>
                    <td>${p.category}</td>
                    <td class="text-right">${Utils.formatCurrency(
                      p.revenue
                    )}</td>
                </tr>
            `
        )
        .join("");
    }
  }

  // Top Customers Table
  if (data.topCustomers && data.topCustomers.length > 0) {
    const tbody = document.querySelector("#tableTopCustomers tbody");
    if (tbody) {
      tbody.innerHTML = data.topCustomers
        .slice(0, 10)
        .map(
          (c, i) => `
                <tr>
                    <td>${i + 1}</td>
                    <td>${c.fullName}</td>
                    <td>${c.city}</td>
                    <td class="text-right">${Utils.formatCurrency(
                      c.totalRevenue
                    )}</td>
                </tr>
            `
        )
        .join("");
    }
  }
}

function renderSalesTab() {
  const data = state.data;

  // Daily Sales Trend
  if (data.recentTrend && data.recentTrend.length > 0) {
    const sorted = [...data.recentTrend].sort(
      (a, b) => new Date(a.date) - new Date(b.date)
    );

    ChartManager.createLineChart(
      "chartDailySales",
      sorted.map((d) =>
        new Date(d.date).toLocaleDateString("en-IN", {
          day: "2-digit",
          month: "short",
        })
      ),
      [
        {
          label: "Revenue",
          data: sorted.map((d) => d.revenue),
          borderColor: CONFIG.chartColors.primary,
          tension: 0.1,
        },
        {
          label: "7-Day Avg",
          data: sorted.map((d) => d.movingAvg7D),
          borderColor: CONFIG.chartColors.warning,
          borderDash: [5, 5],
          tension: 0.1,
        },
      ]
    );
  }

  // Day of Week
  if (data.dayOfWeek && data.dayOfWeek.length > 0) {
    const sorted = [...data.dayOfWeek].sort((a, b) => a.dayOrder - b.dayOrder);
    ChartManager.createBarChart(
      "chartDayOfWeek",
      sorted.map((d) => d.dayName),
      [
        {
          label: "Revenue",
          data: sorted.map((d) => d.revenue),
          backgroundColor: sorted.map((d) =>
            d.isWeekend
              ? CONFIG.chartColors.success
              : CONFIG.chartColors.primary
          ),
        },
      ]
    );
  }

  // Quarterly Sales
  if (data.quarterly && data.quarterly.length > 0) {
    const recent = data.quarterly.slice(0, 8).reverse();
    ChartManager.createBarChart(
      "chartQuarterly",
      recent.map((q) => q.quarterLabel),
      [
        {
          label: "Revenue",
          data: recent.map((q) => q.revenue),
          backgroundColor: CONFIG.chartColors.primary,
        },
      ]
    );
  }

  // Payment Modes
  if (data.paymentModes && data.paymentModes.length > 0) {
    ChartManager.createDoughnutChart(
      "chartPaymentModes",
      data.paymentModes.map((p) => p.paymentMode),
      data.paymentModes.map((p) => p.amount)
    );
  }
}

function renderProductsTab() {
  const data = state.data;

  // Top Products Bar
  if (data.topProducts && data.topProducts.length > 0) {
    const top10 = data.topProducts.slice(0, 10);
    ChartManager.createHorizontalBarChart(
      "chartTopProductsBar",
      top10.map((p) => Utils.truncate(p.productName, 20)),
      top10.map((p) => p.revenue)
    );
  }

  // ABC Analysis Pie
  if (data.abcAnalysis && data.abcAnalysis.summary) {
    ChartManager.createDoughnutChart(
      "chartABCPie",
      data.abcAnalysis.summary.map(
        (s) => `Class ${s.class} (${s.productCount} products)`
      ),
      data.abcAnalysis.summary.map((s) => s.totalRevenue)
    );
  }

  // Category Performance
  if (data.categories && data.categories.length > 0) {
    ChartManager.createBarChart(
      "chartCategoryPerformance",
      data.categories.map((c) => c.category),
      [
        {
          label: "Revenue",
          data: data.categories.map((c) => c.revenue),
          backgroundColor: CONFIG.chartColors.primary,
        },
      ]
    );
  }

  // Inventory Status
  if (data.inventoryStatus && data.inventoryStatus.length > 0) {
    ChartManager.createDoughnutChart(
      "chartInventoryStatus",
      data.inventoryStatus.map((s) => s.status),
      data.inventoryStatus.map((s) => s.productCount)
    );
  }

  // Product Details Table
  if (data.topProducts && data.topProducts.length > 0) {
    const tbody = document.querySelector("#tableProductDetails tbody");
    if (tbody) {
      tbody.innerHTML = data.topProducts
        .slice(0, 15)
        .map(
          (p) => `
                <tr>
                    <td>${p.revenueRank}</td>
                    <td class="truncate" title="${
                      p.productName
                    }">${Utils.truncate(p.productName, 30)}</td>
                    <td>${p.category}</td>
                    <td>${p.brand}</td>
                    <td class="text-right">${Utils.formatCurrency(
                      p.revenue
                    )}</td>
                    <td class="text-right">${Utils.formatNumber(
                      p.unitsSold
                    )}</td>
                    <td>${
                      p.avgRating ? p.avgRating.toFixed(1) + " ⭐" : "-"
                    }</td>
                    <td class="text-right">${Utils.formatNumber(
                      p.currentStock
                    )}</td>
                </tr>
            `
        )
        .join("");
    }
  }
}

function renderCustomersTab() {
  const data = state.data;

  // RFM Segments
  if (data.rfmSegments && data.rfmSegments.length > 0) {
    ChartManager.createHorizontalBarChart(
      "chartRFMSegments",
      data.rfmSegments.map((s) => s.segment),
      data.rfmSegments.map((s) => s.customerCount)
    );
  }

  // CLV Tiers
  if (data.clvTiers && data.clvTiers.length > 0) {
    ChartManager.createDoughnutChart(
      "chartCLVTiers",
      data.clvTiers.map((t) => `${t.tier} (${t.customerCount})`),
      data.clvTiers.map((t) => t.totalRevenue)
    );
  }

  // Demographics
  if (data.demographics && data.demographics.length > 0) {
    const ageGroups = [...new Set(data.demographics.map((d) => d.ageGroup))];
    const maleData = ageGroups.map(
      (ag) =>
        data.demographics.find((d) => d.ageGroup === ag && d.gender === "M")
          ?.customerCount || 0
    );
    const femaleData = ageGroups.map(
      (ag) =>
        data.demographics.find((d) => d.ageGroup === ag && d.gender === "F")
          ?.customerCount || 0
    );

    ChartManager.createBarChart("chartDemographics", ageGroups, [
      {
        label: "Male",
        data: maleData,
        backgroundColor: CONFIG.chartColors.primary,
      },
      {
        label: "Female",
        data: femaleData,
        backgroundColor: CONFIG.chartColors.pink,
      },
    ]);
  }

  // Churn Risk Distribution
  if (data.churnRisk && data.churnRisk.distribution) {
    ChartManager.createDoughnutChart(
      "chartChurnRisk",
      data.churnRisk.distribution.map((d) => d.riskLevel),
      data.churnRisk.distribution.map((d) => d.customerCount)
    );
  }

  // Churn Risk Table
  if (data.churnRisk && data.churnRisk.highPriorityCustomers) {
    const tbody = document.querySelector("#tableChurnRisk tbody");
    if (tbody) {
      tbody.innerHTML = data.churnRisk.highPriorityCustomers
        .slice(0, 10)
        .map(
          (c) => `
                <tr>
                    <td>${c.fullName}</td>
                    <td>${c.clvTier}</td>
                    <td>${Utils.formatCurrency(c.totalSpent)}</td>
                    <td>${c.daysInactive} days</td>
                    <td class="truncate" title="${
                      c.recommendedAction
                    }">${Utils.truncate(c.recommendedAction, 40)}</td>
                </tr>
            `
        )
        .join("");
    }
  }
}

function renderStoresTab() {
  const data = state.data;

  // Regional Performance
  if (data.regional && data.regional.length > 0) {
    ChartManager.createBarChart(
      "chartRegionalPerformance",
      data.regional.map((r) => r.region),
      [
        {
          label: "Revenue",
          data: data.regional.map((r) => r.revenue),
          backgroundColor: CONFIG.chartColors.primary,
        },
        {
          label: "Profit",
          data: data.regional.map((r) => r.profit),
          backgroundColor: CONFIG.chartColors.success,
        },
      ]
    );
  }

  // Store Rankings
  if (data.topStores && data.topStores.length > 0) {
    const top10 = data.topStores.slice(0, 10);
    ChartManager.createHorizontalBarChart(
      "chartStoreRankings",
      top10.map((s) => Utils.truncate(s.storeName, 20)),
      top10.map((s) => s.revenue)
    );
  }

  // Store Scorecard Table
  if (data.topStores && data.topStores.length > 0) {
    const tbody = document.querySelector("#tableStoreScorecard tbody");
    if (tbody) {
      tbody.innerHTML = data.topStores
        .slice(0, 15)
        .map((s) => {
          const tierBadge =
            s.performanceTier === "Star"
              ? "success"
              : s.performanceTier === "Average"
              ? "info"
              : s.performanceTier === "Improving"
              ? "warning"
              : "danger";
          return `
                    <tr>
                        <td>${s.revenueRank}</td>
                        <td>${Utils.truncate(s.storeName, 25)}</td>
                        <td>${s.city}</td>
                        <td>${s.region}</td>
                        <td class="text-right">${Utils.formatCurrency(
                          s.revenue
                        )}</td>
                        <td class="text-right">${Utils.formatCurrency(
                          s.profit
                        )}</td>
                        <td class="text-right">${s.profitMargin}%</td>
                        <td>${Utils.createBadge(
                          s.performanceTier,
                          tierBadge
                        )}</td>
                    </tr>
                `;
        })
        .join("");
    }
  }
}

function renderOperationsTab() {
  const data = state.data;

  // KPI Cards
  if (data.deliveryPerf && data.deliveryPerf.length > 0) {
    const latest = data.deliveryPerf[0];
    updateKPI("kpiOnTimeDelivery", Utils.formatPercent(latest.onTimePct));
    updateKPI("kpiAvgDeliveryDays", latest.avgDeliveryDays + " days");
  }

  if (data.returns && data.returns.byCategory) {
    const totalReturns = data.returns.byCategory.reduce(
      (sum, c) => sum + (c.returnCount || 0),
      0
    );
    const totalRefunds = data.returns.byCategory.reduce(
      (sum, c) => sum + (c.totalRefunds || 0),
      0
    );
    updateKPI("kpiReturnRate", Utils.formatNumber(totalReturns) + " returns");
    updateKPI("kpiTotalRefunds", Utils.formatCurrency(totalRefunds));
  }

  // Delivery SLA Trend
  if (data.deliveryPerf && data.deliveryPerf.length > 0) {
    const sorted = [...data.deliveryPerf].reverse().slice(-12);
    ChartManager.createLineChart(
      "chartDeliverySLA",
      sorted.map((d) => d.month),
      [
        {
          label: "On-Time %",
          data: sorted.map((d) => d.onTimePct),
          borderColor: CONFIG.chartColors.success,
          tension: 0.3,
        },
      ]
    );
  }

  // Courier Performance
  if (data.couriers && data.couriers.length > 0) {
    ChartManager.createBarChart(
      "chartCourierPerformance",
      data.couriers.map((c) => c.courier),
      [
        {
          label: "Performance Score",
          data: data.couriers.map((c) => c.performanceScore),
          backgroundColor: CONFIG.chartColors.primary,
        },
      ]
    );
  }

  // Return Analysis
  if (data.returns) {
    if (data.returns.byReason && data.returns.byReason.length > 0) {
      ChartManager.createDoughnutChart(
        "chartReturnReasons",
        data.returns.byReason.map((r) => r.reason),
        data.returns.byReason.map((r) => r.count)
      );
    }

    if (data.returns.byCategory && data.returns.byCategory.length > 0) {
      const withReturns = data.returns.byCategory.filter(
        (c) => c.returnRate > 0
      );
      ChartManager.createBarChart(
        "chartReturnByCategory",
        withReturns.map((c) => c.category),
        [
          {
            label: "Return Rate %",
            data: withReturns.map((c) => c.returnRate),
            backgroundColor: withReturns.map((c) =>
              c.returnRate > 15
                ? CONFIG.chartColors.danger
                : c.returnRate > 10
                ? CONFIG.chartColors.warning
                : CONFIG.chartColors.success
            ),
          },
        ]
      );
    }
  }
}

function renderMarketingTab() {
  const data = state.data;

  // Campaign ROI
  if (data.campaigns && data.campaigns.length > 0) {
    const withROI = data.campaigns.filter((c) => c.roi !== null).slice(0, 10);
    ChartManager.createBarChart(
      "chartCampaignROI",
      withROI.map((c) => Utils.truncate(c.campaignName, 15)),
      [
        {
          label: "ROI %",
          data: withROI.map((c) => c.roi || 0),
          backgroundColor: withROI.map((c) =>
            (c.roi || 0) > 100
              ? CONFIG.chartColors.success
              : (c.roi || 0) > 0
              ? CONFIG.chartColors.warning
              : CONFIG.chartColors.danger
          ),
        },
      ]
    );
  }

  // Channel Performance
  if (data.channels && data.channels.length > 0) {
    ChartManager.createDoughnutChart(
      "chartChannelPerformance",
      data.channels.map((c) => c.channel),
      data.channels.map((c) => c.spend)
    );
  }

  // Campaign Details Table
  if (data.campaigns && data.campaigns.length > 0) {
    const tbody = document.querySelector("#tableCampaigns tbody");
    if (tbody) {
      tbody.innerHTML = data.campaigns
        .slice(0, 10)
        .map((c) => {
          const statusBadge =
            c.status === "Completed"
              ? "success"
              : c.status === "Active"
              ? "info"
              : "warning";
          return `
                    <tr>
                        <td class="truncate" title="${
                          c.campaignName
                        }">${Utils.truncate(c.campaignName, 25)}</td>
                        <td>${Utils.createBadge(c.status, statusBadge)}</td>
                        <td class="text-right">${Utils.formatCurrency(
                          c.budget
                        )}</td>
                        <td class="text-right">${Utils.formatCurrency(
                          c.actualSpend
                        )}</td>
                        <td class="text-right">${Utils.formatNumber(
                          c.clicks
                        )}</td>
                        <td class="text-right">${Utils.formatNumber(
                          c.conversions
                        )}</td>
                        <td class="text-right">${c.conversionRate || 0}%</td>
                        <td class="text-right ${
                          (c.roi || 0) > 0 ? "text-success" : "text-danger"
                        }">
                            ${c.roi || 0}%
                        </td>
                    </tr>
                `;
        })
        .join("");
    }
  }
}

// ============================================================================
// UI HELPERS
// ============================================================================

function updateKPI(elementId, value, change = null, changeLabel = "") {
  const element = document.getElementById(elementId);
  if (!element) return;

  const valueEl = element.querySelector(".kpi-value");
  const changeEl = element.querySelector(".kpi-change");

  if (valueEl) valueEl.textContent = value;

  if (changeEl && change !== null) {
    const indicator = Utils.getChangeIndicator(change);
    changeEl.className = `kpi-change ${indicator.class}`;
    changeEl.textContent = `${indicator.icon} ${indicator.text} ${changeLabel}`;
  }
}

function showLoading(show) {
  const overlay = document.getElementById("loadingOverlay");
  if (overlay) {
    overlay.classList.toggle("active", show);
  }
  state.isLoading = show;
}

function updateAlertBadge() {
  const badge = document.querySelector(".alert-count");
  if (badge && state.data.alerts) {
    const count = state.data.alerts.alerts
      ? state.data.alerts.alerts.length
      : 0;
    badge.textContent = count > 99 ? "99+" : count;
  }
}

function showAlertModal() {
  const modal = document.getElementById("alertModal");
  const body = document.getElementById("alertModalBody");

  if (!modal || !body) return;

  if (state.data.alerts && state.data.alerts.alerts) {
    body.innerHTML = state.data.alerts.alerts
      .map(
        (a) => `
            <div class="alert-item ${a.severity.toLowerCase()}">
                <div class="alert-severity">${a.severity}</div>
                <div class="alert-message">${a.message}</div>
            </div>
        `
      )
      .join("");
  } else {
    body.innerHTML = '<p class="text-muted">No active alerts</p>';
  }

  modal.classList.add("active");
}

function hideAlertModal() {
  const modal = document.getElementById("alertModal");
  if (modal) modal.classList.remove("active");
}

// ============================================================================
// TAB NAVIGATION
// ============================================================================

function switchTab(tabName) {
  // Update state
  state.currentTab = tabName;

  // Update tab buttons
  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.tab === tabName);
  });

  // Update tab content
  document.querySelectorAll(".tab-content").forEach((content) => {
    content.classList.toggle("active", content.id === `tab-${tabName}`);
  });

  // Render tab-specific content
  const renderFunctions = {
    executive: renderExecutiveTab,
    sales: renderSalesTab,
    products: renderProductsTab,
    customers: renderCustomersTab,
    stores: renderStoresTab,
    operations: renderOperationsTab,
    marketing: renderMarketingTab,
  };

  if (renderFunctions[tabName]) {
    renderFunctions[tabName]();
  }
}

// ============================================================================
// INITIALIZATION
// ============================================================================

async function initDashboard() {
  console.log("Initializing RetailMart Analytics Dashboard...");

  // Load all data
  const success = await DataLoader.loadAllData();

  if (success) {
    // Render initial tab
    switchTab("executive");

    // Update alert badge
    updateAlertBadge();

    // Update footer timestamp
    document.getElementById(
      "footerTimestamp"
    ).textContent = `Last updated: ${new Date().toLocaleString("en-IN")}`;
  } else {
    console.error("Failed to initialize dashboard");
  }
}

// ============================================================================
// EVENT LISTENERS
// ============================================================================

document.addEventListener("DOMContentLoaded", () => {
  // Initialize dashboard
  initDashboard();

  // Tab navigation
  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.addEventListener("click", () => switchTab(btn.dataset.tab));
  });

  // Refresh button
  document.getElementById("btnRefresh")?.addEventListener("click", async () => {
    await initDashboard();
  });

  // Alert badge click
  document
    .getElementById("alertBadge")
    ?.addEventListener("click", showAlertModal);

  // Modal close
  document
    .getElementById("closeModal")
    ?.addEventListener("click", hideAlertModal);
  document.getElementById("alertModal")?.addEventListener("click", (e) => {
    if (e.target.id === "alertModal") hideAlertModal();
  });

  // Keyboard shortcuts
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") hideAlertModal();
    if (e.key === "r" && e.ctrlKey) {
      e.preventDefault();
      initDashboard();
    }
  });
});

// Auto-refresh (optional)
// setInterval(initDashboard, CONFIG.refreshInterval);
