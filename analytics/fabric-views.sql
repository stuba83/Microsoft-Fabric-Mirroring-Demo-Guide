-- ========================================
-- Microsoft Fabric Mirroring Demo
-- File: fabric-views.sql
-- Author: stuba83 (https://github.com/stuba83)
-- Purpose: Advanced analytics views for Microsoft Fabric SQL Analytics Endpoint
-- ========================================

-- IMPORTANT: Execute these views in Microsoft Fabric SQL Analytics Endpoint
-- These views are designed to work with the mirrored data in Fabric OneLake
-- and provide advanced analytics capabilities for business intelligence.

-- ========================================
-- CUSTOMER ANALYTICS VIEWS
-- ========================================

-- Customer 360 View: Complete customer profile with transaction summary
CREATE VIEW CustomerAnalytics AS
SELECT 
    c.CustomerID,
    c.FirstName,
    c.MiddleName,
    c.LastName,
    CONCAT(c.FirstName, ' ', ISNULL(c.MiddleName + ' ', ''), c.LastName) as FullName,
    c.EmailAddress,
    c.Phone,
    c.CompanyName,
    
    -- Account Status
    CASE 
        WHEN c.IsDeleted = 1 THEN 'CLOSED'
        ELSE 'ACTIVE'
    END as AccountStatus,
    c.DeletedDate as AccountClosedDate,
    c.DeletedBy as ClosedBy,
    
    -- Transaction Metrics
    COUNT(soh.SalesOrderID) as TotalOrders,
    ISNULL(SUM(soh.SubTotal), 0) as TotalRevenue,
    ISNULL(AVG(soh.SubTotal), 0) as AverageOrderValue,
    ISNULL(MAX(soh.OrderDate), c.ModifiedDate) as LastOrderDate,
    ISNULL(MIN(soh.OrderDate), c.ModifiedDate) as FirstOrderDate,
    
    -- Customer Segmentation
    CASE 
        WHEN ISNULL(SUM(soh.SubTotal), 0) >= 5000 THEN 'VIP'
        WHEN ISNULL(SUM(soh.SubTotal), 0) >= 2000 THEN 'Premium'
        WHEN ISNULL(SUM(soh.SubTotal), 0) >= 500 THEN 'Standard'
        WHEN ISNULL(SUM(soh.SubTotal), 0) > 0 THEN 'Basic'
        ELSE 'Prospect'
    END as CustomerSegment,
    
    -- Customer Type
    CASE 
        WHEN c.CompanyName IS NOT NULL THEN 'B2B'
        ELSE 'B2C'
    END as CustomerType,
    
    -- Engagement Metrics
    CASE 
        WHEN c.IsDeleted = 1 THEN 'CHURNED'
        WHEN ISNULL(MAX(soh.OrderDate), c.ModifiedDate) >= DATEADD(DAY, -30, GETDATE()) THEN 'ACTIVE'
        WHEN ISNULL(MAX(soh.OrderDate), c.ModifiedDate) >= DATEADD(DAY, -90, GETDATE()) THEN 'AT_RISK'
        WHEN ISNULL(MAX(soh.OrderDate), c.ModifiedDate) >= DATEADD(DAY, -180, GETDATE()) THEN 'DORMANT'
        ELSE 'INACTIVE'
    END as EngagementStatus,
    
    -- Temporal Analysis
    DATEDIFF(DAY, c.ModifiedDate, GETDATE()) as DaysSinceRegistration,
    CASE 
        WHEN MAX(soh.OrderDate) IS NOT NULL THEN 
            DATEDIFF(DAY, MAX(soh.OrderDate), GETDATE())
        ELSE DATEDIFF(DAY, c.ModifiedDate, GETDATE())
    END as DaysSinceLastActivity
    
FROM Customer c
LEFT JOIN SalesOrderHeader soh ON c.CustomerID = soh.CustomerID AND soh.IsDeleted = 0
WHERE c.CustomerID IS NOT NULL
GROUP BY 
    c.CustomerID, c.FirstName, c.MiddleName, c.LastName, c.EmailAddress, 
    c.Phone, c.CompanyName, c.IsDeleted, c.DeletedDate, c.DeletedBy, c.ModifiedDate;

-- Customer Lifetime Value View
CREATE VIEW CustomerLifetimeValue AS
SELECT 
    ca.CustomerID,
    ca.FullName,
    ca.CompanyName,
    ca.CustomerSegment,
    ca.CustomerType,
    ca.AccountStatus,
    
    -- Financial Metrics
    ca.TotalRevenue as HistoricalCLV,
    ca.TotalOrders,
    ca.AverageOrderValue,
    
    -- Predictive CLV (simple model based on historical data)
    CASE 
        WHEN ca.AccountStatus = 'ACTIVE' THEN
            CASE 
                WHEN ca.TotalOrders >= 5 THEN ca.TotalRevenue * 1.5  -- Loyal customers
                WHEN ca.TotalOrders >= 2 THEN ca.TotalRevenue * 1.2  -- Repeat customers
                ELSE ca.TotalRevenue * 0.8  -- Single purchase
            END
        ELSE ca.TotalRevenue  -- Closed accounts
    END as PredictedCLV,
    
    -- Risk Assessment
    CASE 
        WHEN ca.EngagementStatus = 'CHURNED' THEN 'HIGH_RISK'
        WHEN ca.EngagementStatus = 'DORMANT' THEN 'HIGH_RISK'
        WHEN ca.EngagementStatus = 'AT_RISK' THEN 'MEDIUM_RISK'
        WHEN ca.EngagementStatus = 'ACTIVE' AND ca.TotalOrders = 1 THEN 'MEDIUM_RISK'
        ELSE 'LOW_RISK'
    END as ChurnRisk,
    
    -- Customer Journey Metrics
    DATEDIFF(DAY, ca.FirstOrderDate, ca.LastOrderDate) as CustomerLifespanDays,
    CASE 
        WHEN ca.TotalOrders > 1 AND ca.FirstOrderDate != ca.LastOrderDate THEN
            CAST(DATEDIFF(DAY, ca.FirstOrderDate, ca.LastOrderDate) AS FLOAT) / NULLIF(ca.TotalOrders - 1, 0)
        ELSE NULL
    END as AvgDaysBetweenOrders,
    
    ca.DaysSinceLastActivity,
    ca.EngagementStatus

FROM CustomerAnalytics ca;

-- ========================================
-- PRODUCT ANALYTICS VIEWS
-- ========================================

-- Product Performance View
CREATE VIEW ProductPerformance AS
SELECT 
    p.ProductID,
    p.Name as ProductName,
    p.ProductNumber,
    p.Color,
    p.Size,
    p.Weight,
    pc.Name as CategoryName,
    pm.Name as ModelName,
    
    -- Status Classification
    CASE 
        WHEN p.IsDeleted = 1 THEN 'DISCONTINUED'
        WHEN p.SellEndDate IS NOT NULL THEN 'END_OF_LIFE'
        WHEN p.DiscontinuedDate IS NOT NULL THEN 'DISCONTINUED'
        ELSE 'ACTIVE'
    END as ProductStatus,
    
    -- Pricing Information
    p.StandardCost,
    p.ListPrice,
    CASE 
        WHEN p.StandardCost > 0 THEN 
            ROUND(((p.ListPrice - p.StandardCost) / p.StandardCost) * 100, 2)
        ELSE 0
    END as ProfitMarginPercent,
    
    -- Sales Performance
    COUNT(sod.ProductID) as TimesSold,
    ISNULL(SUM(sod.OrderQty), 0) as TotalUnitsSold,
    ISNULL(SUM(sod.LineTotal), 0) as TotalRevenue,
    ISNULL(AVG(sod.UnitPrice), p.ListPrice) as AverageSellingPrice,
    ISNULL(MAX(soh.OrderDate), p.SellStartDate) as LastSaleDate,
    
    -- Performance Classification
    CASE 
        WHEN ISNULL(SUM(sod.LineTotal), 0) >= 10000 THEN 'TOP_PERFORMER'
        WHEN ISNULL(SUM(sod.LineTotal), 0) >= 5000 THEN 'HIGH_PERFORMER'
        WHEN ISNULL(SUM(sod.LineTotal), 0) >= 1000 THEN 'MEDIUM_PERFORMER'
        WHEN ISNULL(SUM(sod.LineTotal), 0) > 0 THEN 'LOW_PERFORMER'
        ELSE 'NO_SALES'
    END as PerformanceCategory,
    
    -- Product Lifecycle
    p.SellStartDate,
    p.SellEndDate,
    p.DiscontinuedDate,
    p.DeletedDate,
    CASE 
        WHEN p.IsDeleted = 1 THEN DATEDIFF(DAY, p.SellStartDate, p.DeletedDate)
        WHEN p.SellEndDate IS NOT NULL THEN DATEDIFF(DAY, p.SellStartDate, p.SellEndDate)
        ELSE DATEDIFF(DAY, p.SellStartDate, GETDATE())
    END as ProductLifespanDays,
    
    -- Inventory Insights
    CASE 
        WHEN COUNT(sod.ProductID) = 0 THEN 'SLOW_MOVING'
        WHEN COUNT(sod.ProductID) >= 20 THEN 'FAST_MOVING'
        ELSE 'NORMAL_MOVING'
    END as InventoryClassification

FROM Product p
LEFT JOIN ProductCategory pc ON p.ProductCategoryID = pc.ProductCategoryID
LEFT JOIN ProductModel pm ON p.ProductModelID = pm.ProductModelID
LEFT JOIN SalesOrderDetail sod ON p.ProductID = sod.ProductID
LEFT JOIN SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID AND soh.IsDeleted = 0
GROUP BY 
    p.ProductID, p.Name, p.ProductNumber, p.Color, p.Size, p.Weight,
    pc.Name, pm.Name, p.StandardCost, p.ListPrice, p.SellStartDate, 
    p.SellEndDate, p.DiscontinuedDate, p.IsDeleted, p.DeletedDate;

-- Product Category Performance View
CREATE VIEW CategoryPerformance AS
SELECT 
    pc.ProductCategoryID,
    pc.Name as CategoryName,
    
    -- Product Count Metrics
    COUNT(p.ProductID) as TotalProducts,
    SUM(CASE WHEN p.IsDeleted = 0 THEN 1 ELSE 0 END) as ActiveProducts,
    SUM(CASE WHEN p.IsDeleted = 1 THEN 1 ELSE 0 END) as DiscontinuedProducts,
    
    -- Financial Performance
    AVG(p.ListPrice) as AverageProductPrice,
    MIN(p.ListPrice) as MinPrice,
    MAX(p.ListPrice) as MaxPrice,
    AVG(CASE WHEN p.StandardCost > 0 THEN ((p.ListPrice - p.StandardCost) / p.StandardCost) * 100 ELSE 0 END) as AverageMarginPercent,
    
    -- Sales Performance
    ISNULL(SUM(sod.OrderQty), 0) as TotalUnitsSold,
    ISNULL(SUM(sod.LineTotal), 0) as TotalRevenue,
    COUNT(DISTINCT sod.SalesOrderID) as OrdersWithCategory,
    COUNT(DISTINCT soh.CustomerID) as UniqueCustomers,
    
    -- Category Health Score (0-100)
    CASE 
        WHEN COUNT(p.ProductID) = 0 THEN 0
        ELSE
            ROUND(
                (CAST(SUM(CASE WHEN p.IsDeleted = 0 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(p.ProductID) * 40) + -- Active products weight
                (CASE WHEN ISNULL(SUM(sod.LineTotal), 0) > 0 THEN 30 ELSE 0 END) + -- Revenue weight
                (CASE WHEN COUNT(DISTINCT soh.CustomerID) >= 5 THEN 20 ELSE COUNT(DISTINCT soh.CustomerID) * 4 END) + -- Customer diversity weight
                (CASE WHEN AVG(p.ListPrice) > 50 THEN 10 ELSE AVG(p.ListPrice) / 5 END) -- Price point weight
            , 0)
    END as CategoryHealthScore

FROM ProductCategory pc
LEFT JOIN Product p ON pc.ProductCategoryID = p.ProductCategoryID
LEFT JOIN SalesOrderDetail sod ON p.ProductID = sod.ProductID
LEFT JOIN SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID AND soh.IsDeleted = 0
GROUP BY pc.ProductCategoryID, pc.Name;

-- ========================================
-- SALES ANALYTICS VIEWS
-- ========================================

-- Sales Trend Analysis View
CREATE VIEW SalesTrendAnalysis AS
SELECT 
    YEAR(soh.OrderDate) as OrderYear,
    MONTH(soh.OrderDate) as OrderMonth,
    DATEFROMPARTS(YEAR(soh.OrderDate), MONTH(soh.OrderDate), 1) as MonthYear,
    
    -- Order Metrics
    COUNT(DISTINCT soh.SalesOrderID) as TotalOrders,
    COUNT(DISTINCT soh.CustomerID) as UniqueCustomers,
    COUNT(DISTINCT sod.ProductID) as UniqueProductsSold,
    
    -- Financial Metrics
    SUM(soh.SubTotal) as TotalRevenue,
    AVG(soh.SubTotal) as AverageOrderValue,
    SUM(soh.TaxAmt) as TotalTax,
    SUM(soh.Freight) as TotalShipping,
    SUM(soh.TotalDue) as GrandTotal,
    
    -- Volume Metrics
    SUM(sod.OrderQty) as TotalQuantitySold,
    AVG(sod.OrderQty) as AverageQuantityPerOrder,
    
    -- Customer Behavior
    CAST(COUNT(DISTINCT soh.CustomerID) AS FLOAT) / COUNT(DISTINCT soh.SalesOrderID) as CustomersPerOrder,
    AVG(CAST(sod.UnitPriceDiscount AS FLOAT)) as AverageDiscountRate,
    
    -- Growth Metrics (compared to same month previous year)
    LAG(SUM(soh.SubTotal), 12) OVER (ORDER BY YEAR(soh.OrderDate), MONTH(soh.OrderDate)) as SameMonthPrevYearRevenue,
    LAG(COUNT(DISTINCT soh.SalesOrderID), 12) OVER (ORDER BY YEAR(soh.OrderDate), MONTH(soh.OrderDate)) as SameMonthPrevYearOrders

FROM SalesOrderHeader soh
JOIN SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
WHERE soh.IsDeleted = 0
  AND soh.OrderDate IS NOT NULL
GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate)
HAVING COUNT(soh.SalesOrderID) > 0;

-- Order Analysis View
CREATE VIEW OrderAnalysis AS
SELECT 
    soh.SalesOrderID,
    soh.CustomerID,
    c.FirstName + ' ' + c.LastName as CustomerName,
    c.CompanyName,
    soh.OrderDate,
    soh.DueDate,
    soh.ShipDate,
    
    -- Order Status
    CASE 
        WHEN soh.IsDeleted = 1 THEN 'CANCELLED'
        WHEN soh.Status = 1 THEN 'IN_PROCESS'
        WHEN soh.Status = 2 THEN 'APPROVED'
        WHEN soh.Status = 3 THEN 'BACKORDERED'
        WHEN soh.Status = 4 THEN 'REJECTED'
        WHEN soh.Status = 5 THEN 'SHIPPED'
        WHEN soh.Status = 6 THEN 'CANCELLED'
        ELSE 'UNKNOWN'
    END as OrderStatus,
    
    -- Financial Metrics
    soh.SubTotal,
    soh.TaxAmt,
    soh.Freight,
    soh.TotalDue,
    
    -- Order Characteristics
    COUNT(sod.ProductID) as LineItemCount,
    SUM(sod.OrderQty) as TotalQuantity,
    AVG(sod.UnitPrice) as AverageItemPrice,
    AVG(sod.UnitPriceDiscount) as AverageDiscount,
    
    -- Fulfillment Metrics
    CASE 
        WHEN soh.ShipDate IS NOT NULL THEN DATEDIFF(DAY, soh.OrderDate, soh.ShipDate)
        ELSE DATEDIFF(DAY, soh.OrderDate, GETDATE())
    END as DaysToShip,
    
    CASE 
        WHEN soh.DueDate IS NOT NULL AND soh.ShipDate IS NOT NULL THEN
            CASE WHEN soh.ShipDate <= soh.DueDate THEN 'ON_TIME' ELSE 'LATE' END
        WHEN soh.DueDate IS NOT NULL AND soh.ShipDate IS NULL THEN
            CASE WHEN GETDATE() <= soh.DueDate THEN 'PENDING' ELSE 'OVERDUE' END
        ELSE 'NO_DUE_DATE'
    END as DeliveryPerformance,
    
    -- Customer Classification for this order
    CASE 
        WHEN c.CompanyName IS NOT NULL THEN 'B2B'
        ELSE 'B2C'
    END as OrderType,
    
    -- Order Size Classification
    CASE 
        WHEN soh.TotalDue >= 2000 THEN 'LARGE'
        WHEN soh.TotalDue >= 500 THEN 'MEDIUM'
        ELSE 'SMALL'
    END as OrderSize

FROM SalesOrderHeader soh
JOIN Customer c ON soh.CustomerID = c.CustomerID
JOIN SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
GROUP BY 
    soh.SalesOrderID, soh.CustomerID, c.FirstName, c.LastName, c.CompanyName,
    soh.OrderDate, soh.DueDate, soh.ShipDate, soh.Status, soh.IsDeleted,
    soh.SubTotal, soh.TaxAmt, soh.Freight, soh.TotalDue;

-- ========================================
-- ADVANCED ANALYTICS VIEWS
-- ========================================

-- Customer Cohort Analysis View
CREATE VIEW CustomerCohortAnalysis AS
WITH CustomerCohorts AS (
    SELECT 
        c.CustomerID,
        DATEFROMPARTS(YEAR(MIN(soh.OrderDate)), MONTH(MIN(soh.OrderDate)), 1) as CohortMonth,
        MIN(soh.OrderDate) as FirstOrderDate,
        COUNT(soh.SalesOrderID) as TotalOrders,
        SUM(soh.TotalDue) as TotalRevenue
    FROM Customer c
    JOIN SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
    WHERE soh.IsDeleted = 0
    GROUP BY c.CustomerID
),
CohortSizes AS (
    SELECT 
        CohortMonth,
        COUNT(CustomerID) as CohortSize,
        SUM(TotalRevenue) as CohortRevenue
    FROM CustomerCohorts
    GROUP BY CohortMonth
)
SELECT 
    cs.CohortMonth,
    cs.CohortSize,
    cs.CohortRevenue,
    AVG(cc.TotalRevenue) as AvgRevenuePerCustomer,
    AVG(cc.TotalOrders) as AvgOrdersPerCustomer,
    
    -- Retention metrics would require more complex analysis
    -- This is a simplified version for demonstration
    COUNT(CASE WHEN cc.TotalOrders >= 2 THEN 1 END) as RetainedCustomers,
    ROUND(
        CAST(COUNT(CASE WHEN cc.TotalOrders >= 2 THEN 1 END) AS FLOAT) / cs.CohortSize * 100, 
        2
    ) as RetentionRate

FROM CohortSizes cs
JOIN CustomerCohorts cc ON cs.CohortMonth = cc.CohortMonth
GROUP BY cs.CohortMonth, cs.CohortSize, cs.CohortRevenue;

-- RFM Analysis View (Recency, Frequency, Monetary)
CREATE VIEW RFMAnalysis AS
WITH CustomerRFM AS (
    SELECT 
        c.CustomerID,
        c.FirstName + ' ' + c.LastName as CustomerName,
        c.CompanyName,
        
        -- Recency: Days since last order
        DATEDIFF(DAY, MAX(soh.OrderDate), GETDATE()) as Recency,
        
        -- Frequency: Number of orders
        COUNT(soh.SalesOrderID) as Frequency,
        
        -- Monetary: Total revenue
        SUM(soh.TotalDue) as Monetary
        
    FROM Customer c
    JOIN SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
    WHERE c.IsDeleted = 0 AND soh.IsDeleted = 0
    GROUP BY c.CustomerID, c.FirstName, c.LastName, c.CompanyName
),
RFMScores AS (
    SELECT 
        *,
        -- RFM Scoring (1-5 scale, 5 being the best)
        CASE 
            WHEN Recency <= 30 THEN 5
            WHEN Recency <= 60 THEN 4
            WHEN Recency <= 90 THEN 3
            WHEN Recency <= 180 THEN 2
            ELSE 1
        END as R_Score,
        
        CASE 
            WHEN Frequency >= 10 THEN 5
            WHEN Frequency >= 5 THEN 4
            WHEN Frequency >= 3 THEN 3
            WHEN Frequency >= 2 THEN 2
            ELSE 1
        END as F_Score,
        
        CASE 
            WHEN Monetary >= 5000 THEN 5
            WHEN Monetary >= 2000 THEN 4
            WHEN Monetary >= 1000 THEN 3
            WHEN Monetary >= 500 THEN 2
            ELSE 1
        END as M_Score
        
    FROM CustomerRFM
)
SELECT 
    *,
    CAST(R_Score AS VARCHAR) + CAST(F_Score AS VARCHAR) + CAST(M_Score AS VARCHAR) as RFM_Score,
    
    -- Customer Segmentation based on RFM
    CASE 
        WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
        WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3 THEN 'Loyal Customers'
        WHEN R_Score >= 4 AND F_Score <= 2 AND M_Score >= 3 THEN 'New Customers'
        WHEN R_Score >= 3 AND F_Score <= 2 AND M_Score <= 2 THEN 'Potential Loyalists'
        WHEN R_Score <= 2 AND F_Score >= 3 AND M_Score >= 3 THEN 'At Risk'
        WHEN R_Score <= 2 AND F_Score <= 2 AND M_Score >= 4 THEN 'Cannot Lose Them'
        WHEN R_Score >= 3 AND F_Score <= 2 AND M_Score <= 2 THEN 'Need Attention'
        WHEN R_Score <= 2 AND F_Score <= 2 AND M_Score <= 2 THEN 'Lost Customers'
        ELSE 'Others'
    END as CustomerSegment

FROM RFMScores;

-- ========================================
-- OPERATIONAL VIEWS
-- ========================================

-- Data Quality Dashboard View
CREATE VIEW DataQualityDashboard AS
SELECT 
    'Customer' as TableName,
    COUNT(*) as TotalRecords,
    SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END) as SoftDeletedRecords,
    SUM(CASE WHEN EmailAddress IS NULL OR EmailAddress = '' THEN 1 ELSE 0 END) as MissingEmailRecords,
    SUM(CASE WHEN Phone IS NULL OR Phone = '' THEN 1 ELSE 0 END) as MissingPhoneRecords,
    AVG(DATEDIFF(DAY, ModifiedDate, GETDATE())) as AvgDaysOld

FROM Customer

UNION ALL

SELECT 
    'Product',
    COUNT(*),
    SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN Name IS NULL OR Name = '' THEN 1 ELSE 0 END) as MissingNameRecords,
    SUM(CASE WHEN StandardCost IS NULL OR StandardCost <= 0 THEN 1 ELSE 0 END) as InvalidCostRecords,
    AVG(DATEDIFF(DAY, ModifiedDate, GETDATE()))

FROM Product

UNION ALL

SELECT 
    'SalesOrderHeader',
    COUNT(*),
    SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) as MissingCustomerRecords,
    SUM(CASE WHEN TotalDue IS NULL OR TotalDue <= 0 THEN 1 ELSE 0 END) as InvalidTotalRecords,
    AVG(DATEDIFF(DAY, ModifiedDate, GETDATE()));

-- Business KPI Dashboard View
CREATE VIEW BusinessKPIDashboard AS
SELECT 
    -- Current Period Metrics (Last 30 days)
    COUNT(DISTINCT CASE WHEN soh.OrderDate >= DATEADD(DAY, -30, GETDATE()) AND soh.IsDeleted = 0 THEN soh.SalesOrderID END) as Orders_Last30Days,
    COUNT(DISTINCT CASE WHEN c.ModifiedDate >= DATEADD(DAY, -30, GETDATE()) AND c.IsDeleted = 0 THEN c.CustomerID END) as NewCustomers_Last30Days,
    SUM(CASE WHEN soh.OrderDate >= DATEADD(DAY, -30, GETDATE()) AND soh.IsDeleted = 0 THEN soh.TotalDue ELSE 0 END) as Revenue_Last30Days,
    
    -- Previous Period Metrics (31-60 days ago)
    COUNT(DISTINCT CASE WHEN soh.OrderDate >= DATEADD(DAY, -60, GETDATE()) AND soh.OrderDate < DATEADD(DAY, -30, GETDATE()) AND soh.IsDeleted = 0 THEN soh.SalesOrderID END) as Orders_Previous30Days,
    SUM(CASE WHEN soh.OrderDate >= DATEADD(DAY, -60, GETDATE()) AND soh.OrderDate < DATEADD(DAY, -30, GETDATE()) AND soh.IsDeleted = 0 THEN soh.TotalDue ELSE 0 END) as Revenue_Previous30Days,
    
    -- Overall Metrics
    COUNT(DISTINCT c.CustomerID) as TotalCustomers,
    COUNT(DISTINCT CASE WHEN c.IsDeleted = 0 THEN c.CustomerID END) as ActiveCustomers,
    COUNT(DISTINCT p.ProductID) as TotalProducts,
    COUNT(DISTINCT CASE WHEN p.IsDeleted = 0 THEN p.ProductID END) as ActiveProducts,
    COUNT(DISTINCT soh.SalesOrderID) as TotalOrders,
    SUM(soh.TotalDue) as TotalRevenue,
    
    -- Average Metrics
    AVG(soh.TotalDue) as AverageOrderValue,
    AVG(DATEDIFF(DAY, soh.OrderDate, ISNULL(soh.ShipDate, GETDATE()))) as AvgDaysToShip

FROM Customer c
FULL OUTER JOIN SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
FULL OUTER JOIN Product p ON 1=1;  -- Cross join for totals

-- ========================================
-- SUMMARY
-- ========================================

-- View Catalog
CREATE VIEW ViewCatalog AS
SELECT 
    'CustomerAnalytics' as ViewName,
    'Complete customer profile with transaction summary and segmentation' as Description,
    'Customer 360, Segmentation, CLV Analysis' as UseCases
    
UNION ALL SELECT 'CustomerLifetimeValue', 'Customer lifetime value analysis with churn risk assessment', 'CLV Prediction, Churn Analysis, Customer Retention'
UNION ALL SELECT 'ProductPerformance', 'Product sales performance and lifecycle analysis', 'Product Analytics, Inventory Management, Pricing Strategy'
UNION ALL SELECT 'CategoryPerformance', 'Product category performance with health scoring', 'Category Management, Portfolio Analysis, Strategic Planning'
UNION ALL SELECT 'SalesTrendAnalysis', 'Monthly sales trends with growth metrics', 'Sales Forecasting, Trend Analysis, Performance Tracking'
UNION ALL SELECT 'OrderAnalysis', 'Detailed order analysis with fulfillment metrics', 'Order Management, Fulfillment Analysis, Customer Service'
UNION ALL SELECT 'CustomerCohortAnalysis', 'Cohort-based customer retention analysis', 'Retention Analysis, Customer Acquisition, Lifecycle Marketing'
UNION ALL SELECT 'RFMAnalysis', 'RFM segmentation for targeted marketing', 'Customer Segmentation, Marketing Campaigns, Personalization'
UNION ALL SELECT 'DataQualityDashboard', 'Data quality monitoring across all tables', 'Data Governance, Quality Assurance, Data Management'
UNION ALL SELECT 'BusinessKPIDashboard', 'Key business performance indicators', 'Executive Dashboards, Performance Monitoring, Strategic Planning';

-- ========================================
-- USAGE INSTRUCTIONS
-- ========================================

/*
FABRIC ANALYTICS VIEWS USAGE GUIDE
===================================

1. EXECUTE ALL VIEWS: Run this entire script in your Fabric SQL Analytics Endpoint

2. VERIFY INSTALLATION: 
   SELECT * FROM ViewCatalog;

3. START WITH OVERVIEW VIEWS:
   - BusinessKPIDashboard: Executive summary
   - DataQualityDashboard: Data health check

4. CUSTOMER ANALYSIS:
   - CustomerAnalytics: Customer 360 view
   - CustomerLifetimeValue: CLV and churn analysis
   - RFMAnalysis: Marketing segmentation

5. PRODUCT ANALYSIS:
   - ProductPerformance: Product sales performance
   - CategoryPerformance: Category health scoring

6. SALES ANALYSIS:
   - SalesTrendAnalysis: Time-based trends
   - OrderAnalysis: Order-level insights
   - CustomerCohortAnalysis: Retention analysis

7. POWER BI INTEGRATION:
   These views are optimized for Power BI DirectQuery mode.
   Connect to your Fabric SQL Analytics Endpoint and use these views
   as data sources for your reports and dashboards.

8. CUSTOM ANALYSIS:
   Use these views as building blocks for more specific analysis.
   Join multiple views together for comprehensive insights.

EXAMPLE QUERIES:
================

-- Top 10 customers by CLV
SELECT TOP 10 * FROM CustomerLifetimeValue ORDER BY PredictedCLV DESC;

-- Best performing products this month
SELECT * FROM ProductPerformance WHERE LastSaleDate >= DATEADD(MONTH, -1, GETDATE()) ORDER BY TotalRevenue DESC;

-- Monthly revenue trend
SELECT OrderYear, OrderMonth, TotalRevenue FROM SalesTrendAnalysis ORDER BY OrderYear DESC, OrderMonth DESC;

-- Customer segments for marketing
SELECT CustomerSegment, COUNT(*) as CustomerCount FROM RFMAnalysis GROUP BY CustomerSegment ORDER BY CustomerCount DESC;

REPOSITORY: https://github.com/stuba83/fabric-mirroring-demo
AUTHOR: stuba83
*/