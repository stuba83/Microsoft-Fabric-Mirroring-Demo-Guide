-- ========================================
-- Microsoft Fabric Mirroring Demo
-- File: powerbi-queries.sql
-- Author: stuba83 (https://github.com/stuba83)
-- Purpose: Optimized queries for Power BI reports using Fabric SQL Analytics Endpoint
-- ========================================

-- IMPORTANT: These queries are designed for Power BI DirectQuery mode
-- Connect Power BI to your Fabric SQL Analytics Endpoint and use these queries
-- as data sources for your reports and dashboards.

-- ========================================
-- EXECUTIVE DASHBOARD QUERIES
-- ========================================

-- Executive KPI Summary
-- Use this for high-level executive dashboard cards
SELECT 
    -- Revenue Metrics
    SUM(CASE WHEN soh.OrderDate >= DATEADD(MONTH, -1, GETDATE()) AND soh.IsDeleted = 0 THEN soh.TotalDue ELSE 0 END) as Revenue_ThisMonth,
    SUM(CASE WHEN soh.OrderDate >= DATEADD(MONTH, -2, GETDATE()) AND soh.OrderDate < DATEADD(MONTH, -1, GETDATE()) AND soh.IsDeleted = 0 THEN soh.TotalDue ELSE 0 END) as Revenue_LastMonth,
    SUM(CASE WHEN soh.OrderDate >= DATEADD(YEAR, -1, GETDATE()) AND soh.IsDeleted = 0 THEN soh.TotalDue ELSE 0 END) as Revenue_YTD,
    
    -- Order Metrics
    COUNT(DISTINCT CASE WHEN soh.OrderDate >= DATEADD(MONTH, -1, GETDATE()) AND soh.IsDeleted = 0 THEN soh.SalesOrderID END) as Orders_ThisMonth,
    COUNT(DISTINCT CASE WHEN soh.OrderDate >= DATEADD(MONTH, -2, GETDATE()) AND soh.OrderDate < DATEADD(MONTH, -1, GETDATE()) AND soh.IsDeleted = 0 THEN soh.SalesOrderID END) as Orders_LastMonth,
    
    -- Customer Metrics
    COUNT(DISTINCT CASE WHEN c.ModifiedDate >= DATEADD(MONTH, -1, GETDATE()) AND c.IsDeleted = 0 THEN c.CustomerID END) as NewCustomers_ThisMonth,
    COUNT(DISTINCT CASE WHEN c.IsDeleted = 0 THEN c.CustomerID END) as TotalActiveCustomers,
    COUNT(DISTINCT CASE WHEN c.IsDeleted = 1 THEN c.CustomerID END) as ChurnedCustomers,
    
    -- Product Metrics
    COUNT(DISTINCT CASE WHEN p.IsDeleted = 0 THEN p.ProductID END) as ActiveProducts,
    COUNT(DISTINCT CASE WHEN p.IsDeleted = 1 THEN p.ProductID END) as DiscontinuedProducts,
    
    -- Calculated KPIs
    CASE 
        WHEN SUM(CASE WHEN soh.OrderDate >= DATEADD(MONTH, -2, GETDATE()) AND soh.OrderDate < DATEADD(MONTH, -1, GETDATE()) AND soh.IsDeleted = 0 THEN soh.TotalDue ELSE 0 END) > 0 THEN
            ROUND(((SUM(CASE WHEN soh.OrderDate >= DATEADD(MONTH, -1, GETDATE()) AND soh.IsDeleted = 0 THEN soh.TotalDue ELSE 0 END) - 
                    SUM(CASE WHEN soh.OrderDate >= DATEADD(MONTH, -2, GETDATE()) AND soh.OrderDate < DATEADD(MONTH, -1, GETDATE()) AND soh.IsDeleted = 0 THEN soh.TotalDue ELSE 0 END)) /
                   SUM(CASE WHEN soh.OrderDate >= DATEADD(MONTH, -2, GETDATE()) AND soh.OrderDate < DATEADD(MONTH, -1, GETDATE()) AND soh.IsDeleted = 0 THEN soh.TotalDue ELSE 0 END)) * 100, 2)
        ELSE 0
    END as Revenue_MoM_Growth_Percent,
    
    AVG(CASE WHEN soh.OrderDate >= DATEADD(MONTH, -1, GETDATE()) AND soh.IsDeleted = 0 THEN soh.TotalDue END) as AOV_ThisMonth

FROM Customer c
FULL OUTER JOIN SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
FULL OUTER JOIN Product p ON 1=1;

-- Monthly Revenue Trend
-- Use this for line charts showing revenue trends over time
SELECT 
    YEAR(soh.OrderDate) as OrderYear,
    MONTH(soh.OrderDate) as OrderMonth,
    DATEFROMPARTS(YEAR(soh.OrderDate), MONTH(soh.OrderDate), 1) as MonthYear,
    DATENAME(MONTH, soh.OrderDate) + ' ' + CAST(YEAR(soh.OrderDate) AS VARCHAR) as MonthName,
    
    -- Financial Metrics
    SUM(soh.SubTotal) as Revenue,
    SUM(soh.TaxAmt) as Tax,
    SUM(soh.Freight) as Shipping,
    SUM(soh.TotalDue) as GrandTotal,
    
    -- Volume Metrics
    COUNT(DISTINCT soh.SalesOrderID) as OrderCount,
    COUNT(DISTINCT soh.CustomerID) as UniqueCustomers,
    SUM(sod.OrderQty) as TotalUnits,
    
    -- Performance Metrics
    AVG(soh.TotalDue) as AverageOrderValue,
    SUM(soh.SubTotal) / NULLIF(SUM(sod.OrderQty), 0) as RevenuePerUnit,
    
    -- Growth Calculations
    LAG(SUM(soh.TotalDue)) OVER (ORDER BY YEAR(soh.OrderDate), MONTH(soh.OrderDate)) as PreviousMonthRevenue,
    LAG(SUM(soh.TotalDue), 12) OVER (ORDER BY YEAR(soh.OrderDate), MONTH(soh.OrderDate)) as SameMonthLastYearRevenue

FROM SalesOrderHeader soh
JOIN SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
WHERE soh.IsDeleted = 0
  AND soh.OrderDate >= DATEADD(YEAR, -2, GETDATE())  -- Last 2 years
GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate)
ORDER BY OrderYear DESC, OrderMonth DESC;

-- ========================================
-- CUSTOMER ANALYTICS QUERIES
-- ========================================

-- Customer Segment Overview
-- Use this for pie charts and customer segment analysis
SELECT 
    ca.CustomerSegment,
    COUNT(*) as CustomerCount,
    SUM(ca.TotalRevenue) as SegmentRevenue,
    AVG(ca.TotalRevenue) as AvgRevenuePerCustomer,
    AVG(ca.TotalOrders) as AvgOrdersPerCustomer,
    AVG(ca.AverageOrderValue) as AvgOrderValue,
    
    -- Engagement Distribution
    SUM(CASE WHEN ca.EngagementStatus = 'ACTIVE' THEN 1 ELSE 0 END) as ActiveCustomers,
    SUM(CASE WHEN ca.EngagementStatus = 'AT_RISK' THEN 1 ELSE 0 END) as AtRiskCustomers,
    SUM(CASE WHEN ca.EngagementStatus = 'CHURNED' THEN 1 ELSE 0 END) as ChurnedCustomers,
    
    -- Customer Type Distribution
    SUM(CASE WHEN ca.CustomerType = 'B2B' THEN 1 ELSE 0 END) as B2B_Count,
    SUM(CASE WHEN ca.CustomerType = 'B2C' THEN 1 ELSE 0 END) as B2C_Count,
    
    -- Revenue Distribution
    ROUND(SUM(ca.TotalRevenue) * 100.0 / SUM(SUM(ca.TotalRevenue)) OVER(), 2) as SegmentRevenuePercent

FROM CustomerAnalytics ca
GROUP BY ca.CustomerSegment
HAVING COUNT(*) > 0
ORDER BY SegmentRevenue DESC;

-- Top Customers Analysis
-- Use this for tables and detailed customer views
SELECT 
    clv.CustomerID,
    clv.FullName,
    clv.CompanyName,
    clv.CustomerType,
    clv.CustomerSegment,
    clv.AccountStatus,
    clv.HistoricalCLV,
    clv.PredictedCLV,
    clv.TotalOrders,
    clv.AverageOrderValue,
    clv.ChurnRisk,
    clv.EngagementStatus,
    clv.DaysSinceLastActivity,
    
    -- Revenue Ranking
    RANK() OVER (ORDER BY clv.HistoricalCLV DESC) as RevenueRank,
    
    -- Additional Customer Details from Customer table
    c.EmailAddress,
    c.Phone,
    c.ModifiedDate as RegistrationDate

FROM CustomerLifetimeValue clv
JOIN Customer c ON clv.CustomerID = c.CustomerID
WHERE clv.HistoricalCLV > 0
ORDER BY clv.PredictedCLV DESC;

-- RFM Customer Segmentation
-- Use this for advanced customer segmentation analysis
SELECT 
    rfm.CustomerSegment,
    COUNT(*) as CustomerCount,
    AVG(rfm.Recency) as AvgRecency,
    AVG(rfm.Frequency) as AvgFrequency,
    AVG(rfm.Monetary) as AvgMonetary,
    AVG(rfm.R_Score) as AvgRecencyScore,
    AVG(rfm.F_Score) as AvgFrequencyScore,
    AVG(rfm.M_Score) as AvgMonetaryScore,
    
    -- Segment Characteristics
    MIN(rfm.Monetary) as MinSpent,
    MAX(rfm.Monetary) as MaxSpent,
    MIN(rfm.Frequency) as MinOrders,
    MAX(rfm.Frequency) as MaxOrders,
    
    -- Revenue Impact
    SUM(rfm.Monetary) as TotalSegmentRevenue,
    ROUND(SUM(rfm.Monetary) * 100.0 / SUM(SUM(rfm.Monetary)) OVER(), 2) as RevenuePercent

FROM RFMAnalysis rfm
GROUP BY rfm.CustomerSegment
ORDER BY TotalSegmentRevenue DESC;

-- ========================================
-- PRODUCT ANALYTICS QUERIES
-- ========================================

-- Product Performance Overview
-- Use this for product performance dashboards
SELECT 
    pp.ProductID,
    pp.ProductName,
    pp.ProductNumber,
    pp.Color,
    pp.Size,
    pp.CategoryName,
    pp.ProductStatus,
    pp.ListPrice,
    pp.StandardCost,
    pp.ProfitMarginPercent,
    pp.TimesSold,
    pp.TotalUnitsSold,
    pp.TotalRevenue,
    pp.AverageSellingPrice,
    pp.LastSaleDate,
    pp.PerformanceCategory,
    pp.ProductLifespanDays,
    pp.InventoryClassification,
    
    -- Rankings
    RANK() OVER (ORDER BY pp.TotalRevenue DESC) as RevenueRank,
    RANK() OVER (ORDER BY pp.TotalUnitsSold DESC) as VolumeRank,
    RANK() OVER (ORDER BY pp.ProfitMarginPercent DESC) as MarginRank,
    
    -- Revenue Contribution
    ROUND(pp.TotalRevenue * 100.0 / SUM(pp.TotalRevenue) OVER(), 2) as RevenueContributionPercent

FROM ProductPerformance pp
WHERE pp.TotalRevenue > 0 OR pp.ProductStatus = 'ACTIVE'
ORDER BY pp.TotalRevenue DESC;

-- Category Performance Analysis
-- Use this for category-level insights
SELECT 
    cp.CategoryName,
    cp.TotalProducts,
    cp.ActiveProducts,
    cp.DiscontinuedProducts,
    cp.TotalRevenue,
    cp.TotalUnitsSold,
    cp.AverageProductPrice,
    cp.MinPrice,
    cp.MaxPrice,
    cp.AverageMarginPercent,
    cp.UniqueCustomers,
    cp.CategoryHealthScore,
    
    -- Category Performance Metrics
    ROUND(cp.TotalRevenue / NULLIF(cp.TotalProducts, 0), 2) as RevenuePerProduct,
    ROUND(cp.TotalUnitsSold / NULLIF(cp.TotalProducts, 0), 2) as UnitsPerProduct,
    ROUND(cp.TotalRevenue / NULLIF(cp.UniqueCustomers, 0), 2) as RevenuePerCustomer,
    
    -- Category Rankings
    RANK() OVER (ORDER BY cp.TotalRevenue DESC) as RevenueRank,
    RANK() OVER (ORDER BY cp.CategoryHealthScore DESC) as HealthRank,
    
    -- Portfolio Analysis
    ROUND(cp.TotalRevenue * 100.0 / SUM(cp.TotalRevenue) OVER(), 2) as PortfolioContribution

FROM CategoryPerformance cp
ORDER BY cp.TotalRevenue DESC;

-- Top Products by Category
-- Use this for category drill-down analysis
SELECT 
    pp.CategoryName,
    pp.ProductID,
    pp.ProductName,
    pp.ProductNumber,
    pp.Color,
    pp.ListPrice,
    pp.TotalRevenue,
    pp.TotalUnitsSold,
    pp.ProfitMarginPercent,
    pp.PerformanceCategory,
    pp.ProductStatus,
    
    -- Within-Category Rankings
    RANK() OVER (PARTITION BY pp.CategoryName ORDER BY pp.TotalRevenue DESC) as CategoryRank,
    
    -- Category Contribution
    ROUND(pp.TotalRevenue * 100.0 / SUM(pp.TotalRevenue) OVER (PARTITION BY pp.CategoryName), 2) as CategoryContribution

FROM ProductPerformance pp
WHERE pp.TotalRevenue > 0
ORDER BY pp.CategoryName, CategoryRank;

-- ========================================
-- SALES ANALYTICS QUERIES
-- ========================================

-- Sales Performance Overview
-- Use this for sales dashboard and trend analysis
SELECT 
    sta.OrderYear,
    sta.OrderMonth,
    sta.MonthYear,
    sta.TotalOrders,
    sta.UniqueCustomers,
    sta.UniqueProductsSold,
    sta.TotalRevenue,
    sta.AverageOrderValue,
    sta.TotalQuantitySold,
    sta.GrandTotal,
    
    -- Growth Calculations
    CASE 
        WHEN sta.PreviousMonthRevenue IS NOT NULL AND sta.PreviousMonthRevenue > 0 THEN
            ROUND(((sta.TotalRevenue - sta.PreviousMonthRevenue) / sta.PreviousMonthRevenue) * 100, 2)
        ELSE NULL
    END as MoM_Growth_Percent,
    
    CASE 
        WHEN sta.SameMonthLastYearRevenue IS NOT NULL AND sta.SameMonthLastYearRevenue > 0 THEN
            ROUND(((sta.TotalRevenue - sta.SameMonthLastYearRevenue) / sta.SameMonthLastYearRevenue) * 100, 2)
        ELSE NULL
    END as YoY_Growth_Percent,
    
    -- Performance Indicators
    CASE 
        WHEN sta.TotalRevenue >= LAG(sta.TotalRevenue) OVER (ORDER BY sta.OrderYear, sta.OrderMonth) THEN 'Positive'
        ELSE 'Negative'
    END as MoM_Trend,
    
    -- Running Totals
    SUM(sta.TotalRevenue) OVER (
        PARTITION BY sta.OrderYear 
        ORDER BY sta.OrderMonth 
        ROWS UNBOUNDED PRECEDING
    ) as YTD_Revenue

FROM SalesTrendAnalysis sta
ORDER BY sta.OrderYear DESC, sta.OrderMonth DESC;

-- Order Status Analysis
-- Use this for operational dashboards and fulfillment tracking
SELECT 
    oa.OrderStatus,
    COUNT(*) as OrderCount,
    SUM(oa.TotalDue) as TotalRevenue,
    AVG(oa.TotalDue) as AvgOrderValue,
    AVG(oa.LineItemCount) as AvgItemsPerOrder,
    AVG(oa.TotalQuantity) as AvgQuantityPerOrder,
    AVG(oa.DaysToShip) as AvgDaysToShip,
    
    -- Fulfillment Performance
    SUM(CASE WHEN oa.DeliveryPerformance = 'ON_TIME' THEN 1 ELSE 0 END) as OnTimeOrders,
    SUM(CASE WHEN oa.DeliveryPerformance = 'LATE' THEN 1 ELSE 0 END) as LateOrders,
    SUM(CASE WHEN oa.DeliveryPerformance = 'OVERDUE' THEN 1 ELSE 0 END) as OverdueOrders,
    
    -- Order Size Distribution
    SUM(CASE WHEN oa.OrderSize = 'LARGE' THEN 1 ELSE 0 END) as LargeOrders,
    SUM(CASE WHEN oa.OrderSize = 'MEDIUM' THEN 1 ELSE 0 END) as MediumOrders,
    SUM(CASE WHEN oa.OrderSize = 'SMALL' THEN 1 ELSE 0 END) as SmallOrders,
    
    -- Customer Type Distribution
    SUM(CASE WHEN oa.OrderType = 'B2B' THEN 1 ELSE 0 END) as B2B_Orders,
    SUM(CASE WHEN oa.OrderType = 'B2C' THEN 1 ELSE 0 END) as B2C_Orders,
    
    -- Performance Metrics
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as OrderStatusPercent,
    ROUND(
        CAST(SUM(CASE WHEN oa.DeliveryPerformance = 'ON_TIME' THEN 1 ELSE 0 END) AS FLOAT) /
        NULLIF(SUM(CASE WHEN oa.DeliveryPerformance IN ('ON_TIME', 'LATE') THEN 1 ELSE 0 END), 0) * 100, 
        2
    ) as OnTimeDeliveryPercent

FROM OrderAnalysis oa
GROUP BY oa.OrderStatus
ORDER BY OrderCount DESC;

-- Daily Sales Performance
-- Use this for daily operational reports
SELECT 
    CAST(soh.OrderDate AS DATE) as OrderDate,
    DATENAME(WEEKDAY, soh.OrderDate) as DayOfWeek,
    COUNT(DISTINCT soh.SalesOrderID) as OrderCount,
    COUNT(DISTINCT soh.CustomerID) as UniqueCustomers,
    SUM(soh.TotalDue) as DailyRevenue,
    AVG(soh.TotalDue) as AvgOrderValue,
    SUM(sod.OrderQty) as TotalUnits,
    
    -- Day-over-Day Growth
    LAG(SUM(soh.TotalDue)) OVER (ORDER BY CAST(soh.OrderDate AS DATE)) as PreviousDayRevenue,
    
    -- Weekly Comparison
    LAG(SUM(soh.TotalDue), 7) OVER (ORDER BY CAST(soh.OrderDate AS DATE)) as SameDayLastWeekRevenue,
    
    -- Performance Classification
    CASE 
        WHEN SUM(soh.TotalDue) >= AVG(SUM(soh.TotalDue)) OVER() * 1.5 THEN 'High'
        WHEN SUM(soh.TotalDue) >= AVG(SUM(soh.TotalDue)) OVER() * 0.8 THEN 'Normal'
        ELSE 'Low'
    END as DayPerformance

FROM SalesOrderHeader soh
JOIN SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
WHERE soh.IsDeleted = 0
  AND soh.OrderDate >= DATEADD(DAY, -90, GETDATE())  -- Last 90 days
GROUP BY CAST(soh.OrderDate AS DATE), DATENAME(WEEKDAY, soh.OrderDate)
ORDER BY OrderDate DESC;

-- ========================================
-- OPERATIONAL ANALYTICS QUERIES
-- ========================================

-- Data Quality Metrics
-- Use this for data governance dashboards
SELECT 
    dqd.TableName,
    dqd.TotalRecords,
    dqd.SoftDeletedRecords,
    ROUND(dqd.SoftDeletedRecords * 100.0 / NULLIF(dqd.TotalRecords, 0), 2) as SoftDeletePercent,
    dqd.MissingEmailRecords,
    dqd.MissingPhoneRecords,
    dqd.AvgDaysOld,
    
    -- Data Quality Score (0-100)
    CASE 
        WHEN dqd.TableName = 'Customer' THEN
            ROUND(
                100 - 
                (dqd.MissingEmailRecords * 30.0 / NULLIF(dqd.TotalRecords, 0)) -
                (dqd.MissingPhoneRecords * 20.0 / NULLIF(dqd.TotalRecords, 0)) -
                (dqd.SoftDeletedRecords * 10.0 / NULLIF(dqd.TotalRecords, 0))
            , 2)
        WHEN dqd.TableName = 'Product' THEN
            ROUND(
                100 - 
                (dqd.MissingEmailRecords * 40.0 / NULLIF(dqd.TotalRecords, 0)) -  -- Missing names
                (dqd.MissingPhoneRecords * 30.0 / NULLIF(dqd.TotalRecords, 0)) -  -- Invalid costs
                (dqd.SoftDeletedRecords * 5.0 / NULLIF(dqd.TotalRecords, 0))      -- Discontinued
            , 2)
        ELSE
            ROUND(
                100 - 
                (dqd.MissingEmailRecords * 35.0 / NULLIF(dqd.TotalRecords, 0)) -
                (dqd.MissingPhoneRecords * 25.0 / NULLIF(dqd.TotalRecords, 0)) -
                (dqd.SoftDeletedRecords * 10.0 / NULLIF(dqd.TotalRecords, 0))
            , 2)
    END as DataQualityScore,
    
    -- Freshness Indicator
    CASE 
        WHEN dqd.AvgDaysOld <= 30 THEN 'Fresh'
        WHEN dqd.AvgDaysOld <= 90 THEN 'Moderate'
        ELSE 'Stale'
    END as DataFreshness

FROM DataQualityDashboard dqd
ORDER BY DataQualityScore DESC;

-- Business Performance Summary
-- Use this for executive summary cards
SELECT 
    'Revenue' as MetricType,
    ' + FORMAT(bkd.Revenue_Last30Days, 'N0') as CurrentValue,
    ' + FORMAT(bkd.Revenue_Previous30Days, 'N0') as PreviousValue,
    CASE 
        WHEN bkd.Revenue_Previous30Days > 0 THEN
            ROUND(((bkd.Revenue_Last30Days - bkd.Revenue_Previous30Days) / bkd.Revenue_Previous30Days) * 100, 1)
        ELSE 0
    END as GrowthPercent,
    CASE 
        WHEN bkd.Revenue_Last30Days >= bkd.Revenue_Previous30Days THEN 'Positive'
        ELSE 'Negative'
    END as Trend

FROM BusinessKPIDashboard bkd

UNION ALL

SELECT 
    'Orders',
    FORMAT(bkd.Orders_Last30Days, 'N0'),
    FORMAT(bkd.Orders_Previous30Days, 'N0'),
    CASE 
        WHEN bkd.Orders_Previous30Days > 0 THEN
            ROUND(((CAST(bkd.Orders_Last30Days AS FLOAT) - bkd.Orders_Previous30Days) / bkd.Orders_Previous30Days) * 100, 1)
        ELSE 0
    END,
    CASE 
        WHEN bkd.Orders_Last30Days >= bkd.Orders_Previous30Days THEN 'Positive'
        ELSE 'Negative'
    END

FROM BusinessKPIDashboard bkd

UNION ALL

SELECT 
    'Average Order Value',
    ' + FORMAT(bkd.AOV_ThisMonth, 'N0'),
    ' + FORMAT(bkd.AverageOrderValue, 'N0'),
    CASE 
        WHEN bkd.AverageOrderValue > 0 THEN
            ROUND(((bkd.AOV_ThisMonth - bkd.AverageOrderValue) / bkd.AverageOrderValue) * 100, 1)
        ELSE 0
    END,
    CASE 
        WHEN bkd.AOV_ThisMonth >= bkd.AverageOrderValue THEN 'Positive'
        ELSE 'Negative'
    END

FROM BusinessKPIDashboard bkd

UNION ALL

SELECT 
    'Active Customers',
    FORMAT(bkd.ActiveCustomers, 'N0'),
    FORMAT(bkd.TotalCustomers, 'N0'),
    ROUND((CAST(bkd.ActiveCustomers AS FLOAT) / NULLIF(bkd.TotalCustomers, 0)) * 100, 1),
    CASE 
        WHEN CAST(bkd.ActiveCustomers AS FLOAT) / NULLIF(bkd.TotalCustomers, 0) >= 0.8 THEN 'Positive'
        WHEN CAST(bkd.ActiveCustomers AS FLOAT) / NULLIF(bkd.TotalCustomers, 0) >= 0.6 THEN 'Neutral'
        ELSE 'Negative'
    END

FROM BusinessKPIDashboard bkd;

-- ========================================
-- ADVANCED ANALYTICS QUERIES
-- ========================================

-- Customer Cohort Retention
-- Use this for cohort analysis and retention charts
SELECT 
    cca.CohortMonth,
    FORMAT(cca.CohortMonth, 'MMM yyyy') as CohortLabel,
    cca.CohortSize,
    cca.CohortRevenue,
    cca.AvgRevenuePerCustomer,
    cca.AvgOrdersPerCustomer,
    cca.RetainedCustomers,
    cca.RetentionRate,
    
    -- Cohort Classification
    CASE 
        WHEN cca.RetentionRate >= 60 THEN 'High Retention'
        WHEN cca.RetentionRate >= 40 THEN 'Medium Retention'
        ELSE 'Low Retention'
    END as RetentionClass,
    
    -- Revenue per Retained Customer
    ROUND(cca.CohortRevenue / NULLIF(cca.RetainedCustomers, 0), 2) as RevenuePerRetainedCustomer,
    
    -- Cohort Age (months)
    DATEDIFF(MONTH, cca.CohortMonth, GETDATE()) as CohortAgeMonths

FROM CustomerCohortAnalysis cca
WHERE cca.CohortSize >= 5  -- Only cohorts with meaningful size
ORDER BY cca.CohortMonth DESC;

-- Product Portfolio Analysis
-- Use this for strategic product management
SELECT 
    pp.CategoryName,
    pp.ProductStatus,
    COUNT(*) as ProductCount,
    SUM(pp.TotalRevenue) as CategoryStatusRevenue,
    AVG(pp.ListPrice) as AvgPrice,
    AVG(pp.ProfitMarginPercent) as AvgMargin,
    SUM(pp.TotalUnitsSold) as TotalUnits,
    
    -- Portfolio Metrics
    ROUND(SUM(pp.TotalRevenue) * 100.0 / SUM(SUM(pp.TotalRevenue)) OVER (PARTITION BY pp.CategoryName), 2) as CategoryContribution,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY pp.CategoryName), 2) as ProductCountPercent,
    
    -- Performance Classification
    CASE 
        WHEN AVG(pp.ProfitMarginPercent) >= 30 AND SUM(pp.TotalRevenue) >= 1000 THEN 'Star Products'
        WHEN AVG(pp.ProfitMarginPercent) >= 30 AND SUM(pp.TotalRevenue) < 1000 THEN 'Question Marks'
        WHEN AVG(pp.ProfitMarginPercent) < 30 AND SUM(pp.TotalRevenue) >= 1000 THEN 'Cash Cows'
        ELSE 'Dogs'
    END as BCGClassification

FROM ProductPerformance pp
GROUP BY pp.CategoryName, pp.ProductStatus
ORDER BY pp.CategoryName, CategoryStatusRevenue DESC;

-- Sales Channel Performance
-- Use this for channel analysis (if you have channel data)
SELECT 
    CASE 
        WHEN soh.OnlineOrderFlag = 1 THEN 'Online'
        ELSE 'Offline'
    END as SalesChannel,
    
    COUNT(DISTINCT soh.SalesOrderID) as OrderCount,
    COUNT(DISTINCT soh.CustomerID) as UniqueCustomers,
    SUM(soh.TotalDue) as TotalRevenue,
    AVG(soh.TotalDue) as AvgOrderValue,
    SUM(sod.OrderQty) as TotalUnits,
    
    -- Channel Performance Metrics
    ROUND(COUNT(DISTINCT soh.SalesOrderID) * 100.0 / SUM(COUNT(DISTINCT soh.SalesOrderID)) OVER(), 2) as OrderShare,
    ROUND(SUM(soh.TotalDue) * 100.0 / SUM(SUM(soh.TotalDue)) OVER(), 2) as RevenueShare,
    
    -- Customer Behavior by Channel
    AVG(sod.OrderQty) as AvgQuantityPerOrder,
    AVG(CAST(sod.UnitPriceDiscount AS FLOAT)) as AvgDiscountRate,
    
    -- Fulfillment Performance
    AVG(CASE WHEN soh.ShipDate IS NOT NULL THEN DATEDIFF(DAY, soh.OrderDate, soh.ShipDate) END) as AvgShippingDays

FROM SalesOrderHeader soh
JOIN SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
WHERE soh.IsDeleted = 0
  AND soh.OrderDate >= DATEADD(YEAR, -1, GETDATE())
GROUP BY soh.OnlineOrderFlag
ORDER BY TotalRevenue DESC;

-- ========================================
-- POWER BI SPECIFIC OPTIMIZATIONS
-- ========================================

-- Date Table for Time Intelligence
-- Use this as a separate query for date-based calculations
SELECT 
    CAST(d.Date AS DATE) as Date,
    YEAR(d.Date) as Year,
    MONTH(d.Date) as Month,
    DAY(d.Date) as Day,
    DATEPART(QUARTER, d.Date) as Quarter,
    DATEPART(WEEK, d.Date) as WeekOfYear,
    DATEPART(DAYOFYEAR, d.Date) as DayOfYear,
    DATENAME(MONTH, d.Date) as MonthName,
    DATENAME(WEEKDAY, d.Date) as WeekdayName,
    DATEPART(WEEKDAY, d.Date) as WeekdayNumber,
    
    -- Fiscal Year (assuming fiscal year starts in July)
    CASE 
        WHEN MONTH(d.Date) >= 7 THEN YEAR(d.Date) + 1
        ELSE YEAR(d.Date)
    END as FiscalYear,
    
    -- Period Flags
    CASE WHEN d.Date >= DATEADD(DAY, -30, GETDATE()) THEN 1 ELSE 0 END as IsLast30Days,
    CASE WHEN d.Date >= DATEADD(DAY, -90, GETDATE()) THEN 1 ELSE 0 END as IsLast90Days,
    CASE WHEN YEAR(d.Date) = YEAR(GETDATE()) THEN 1 ELSE 0 END as IsCurrentYear,
    CASE WHEN YEAR(d.Date) = YEAR(GETDATE()) - 1 THEN 1 ELSE 0 END as IsLastYear,
    CASE WHEN MONTH(d.Date) = MONTH(GETDATE()) AND YEAR(d.Date) = YEAR(GETDATE()) THEN 1 ELSE 0 END as IsCurrentMonth

FROM (
    SELECT DATEADD(DAY, number, '2020-01-01') as Date
    FROM master.dbo.spt_values
    WHERE type = 'P' AND number <= DATEDIFF(DAY, '2020-01-01', GETDATE()) + 365
) d
WHERE d.Date <= DATEADD(YEAR, 1, GETDATE())  -- Include future dates for planning
ORDER BY d.Date;

-- ========================================
-- POWER BI REPORT SUGGESTIONS
-- ========================================

/*
POWER BI REPORT STRUCTURE RECOMMENDATIONS:
==========================================

1. EXECUTIVE DASHBOARD
   - Use "Executive KPI Summary" for key metric cards
   - Use "Monthly Revenue Trend" for revenue line chart
   - Use "Business Performance Summary" for trend indicators

2. CUSTOMER ANALYTICS REPORT
   - Use "Customer Segment Overview" for segment distribution
   - Use "Top Customers Analysis" for customer detail tables
   - Use "RFM Customer Segmentation" for advanced segmentation

3. PRODUCT PERFORMANCE REPORT
   - Use "Product Performance Overview" for product tables
   - Use "Category Performance Analysis" for category insights
   - Use "Top Products by Category" for drill-down analysis

4. SALES OPERATIONS REPORT
   - Use "Sales Performance Overview" for trend analysis
   - Use "Order Status Analysis" for operational metrics
   - Use "Daily Sales Performance" for daily tracking

5. DATA GOVERNANCE REPORT
   - Use "Data Quality Metrics" for data health monitoring
   - Use "Date Table" for proper time intelligence

POWER BI BEST PRACTICES:
========================

1. DirectQuery Mode: All queries are optimized for DirectQuery
2. Relationships: Use CustomerID, ProductID, SalesOrderID as keys
3. Measures: Create DAX measures for dynamic calculations
4. Filters: Use date ranges and status filters for performance
5. Refresh: Set up automatic refresh for real-time insights

SAMPLE DAX MEASURES:
===================

Revenue Growth % = 
DIVIDE(
    [Revenue This Month] - [Revenue Last Month],
    [Revenue Last Month],
    0
) * 100

Customer Retention Rate = 
DIVIDE(
    COUNTROWS(FILTER(CustomerAnalytics, [TotalOrders] >= 2)),
    COUNTROWS(CustomerAnalytics),
    0
) * 100

Average Days to Ship = 
AVERAGE(OrderAnalysis[DaysToShip])

*/

-- ========================================
-- FABRIC MIRRORING VERIFICATION QUERIES
-- ========================================

-- Real-time Data Freshness Check
-- Use this to verify mirroring is working correctly
SELECT 
    'Customer' as TableName,
    COUNT(*) as RecordCount,
    MAX(ModifiedDate) as LastModified,
    DATEDIFF(MINUTE, MAX(ModifiedDate), GETDATE()) as MinutesSinceLastUpdate,
    
    -- Freshness Status
    CASE 
        WHEN DATEDIFF(MINUTE, MAX(ModifiedDate), GETDATE()) <= 5 THEN 'Real-time'
        WHEN DATEDIFF(MINUTE, MAX(ModifiedDate), GETDATE()) <= 30 THEN 'Near Real-time'
        WHEN DATEDIFF(MINUTE, MAX(ModifiedDate), GETDATE()) <= 60 THEN 'Delayed'
        ELSE 'Stale'
    END as DataFreshness

FROM Customer

UNION ALL

SELECT 
    'Product',
    COUNT(*),
    MAX(ModifiedDate),
    DATEDIFF(MINUTE, MAX(ModifiedDate), GETDATE()),
    CASE 
        WHEN DATEDIFF(MINUTE, MAX(ModifiedDate), GETDATE()) <= 5 THEN 'Real-time'
        WHEN DATEDIFF(MINUTE, MAX(ModifiedDate), GETDATE()) <= 30 THEN 'Near Real-time'
        WHEN DATEDIFF(MINUTE, MAX(ModifiedDate), GETDATE()) <= 60 THEN 'Delayed'
        ELSE 'Stale'
    END

FROM Product

UNION ALL

SELECT 
    'SalesOrderHeader',
    COUNT(*),
    MAX(ModifiedDate),
    DATEDIFF(MINUTE, MAX(ModifiedDate), GETDATE()),
    CASE 
        WHEN DATEDIFF(MINUTE, MAX(ModifiedDate), GETDATE()) <= 5 THEN 'Real-time'
        WHEN DATEDIFF(MINUTE, MAX(ModifiedDate), GETDATE()) <= 30 THEN 'Near Real-time'
        WHEN DATEDIFF(MINUTE, MAX(ModifiedDate), GETDATE()) <= 60 THEN 'Delayed'
        ELSE 'Stale'
    END

FROM SalesOrderHeader

ORDER BY TableName;

-- ========================================
-- USAGE INSTRUCTIONS
-- ========================================

/*
POWER BI INTEGRATION GUIDE:
============================

1. CONNECT TO FABRIC:
   - Open Power BI Desktop
   - Get Data → More → Azure → Azure SQL Database
   - Server: [your-fabric-sql-analytics-endpoint]
   - Database: [your-mirrored-database]
   - Use DirectQuery mode for real-time data

2. IMPORT QUERIES:
   - Copy each query from this file
   - Paste into Power Query Editor
   - Rename queries appropriately
   - Apply and close

3. CREATE RELATIONSHIPS:
   - CustomerID between Customer and SalesOrderHeader
   - ProductID between Product and SalesOrderDetail
   - SalesOrderID between SalesOrderHeader and SalesOrderDetail

4. BUILD REPORTS:
   - Use the suggested report structure above
   - Create interactive filters and slicers
   - Add drill-through functionality
   - Implement bookmarks for navigation

5. SCHEDULE REFRESH:
   - Publish to Power BI Service
   - Configure automatic refresh
   - Set up data alerts for key metrics

6. SHARE AND COLLABORATE:
   - Create workspace for team collaboration
   - Set up row-level security if needed
   - Configure mobile layouts

REPOSITORY: https://github.com/stuba83/fabric-mirroring-demo
AUTHOR: stuba83
SUPPORT: https://github.com/stuba83/fabric-mirroring-demo/issues
*/