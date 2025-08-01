-- ========================================
-- Microsoft Fabric Mirroring Demo
-- File: fabric-views.sql (CORRECTED FOR FABRIC - FINAL VERSION)
-- Author: stuba83 (https://github.com/stuba83)
-- Purpose: Advanced analytics views for Microsoft Fabric SQL Analytics Endpoint
-- ========================================

-- CLEANUP: Drop existing views if they exist
DROP VIEW IF EXISTS dbo.CustomerAnalytics;
DROP VIEW IF EXISTS dbo.CustomerLifetimeValue;
DROP VIEW IF EXISTS dbo.ProductPerformance;
DROP VIEW IF EXISTS dbo.CategoryPerformance;
DROP VIEW IF EXISTS dbo.SalesTrendAnalysis;
DROP VIEW IF EXISTS dbo.OrderAnalysis;
DROP VIEW IF EXISTS dbo.DataQualityDashboard;
DROP VIEW IF EXISTS dbo.BusinessKPIDashboard;
DROP VIEW IF EXISTS dbo.ViewCatalog;
GO

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
        WHEN ISNULL(c.IsDeleted, 0) = 1 THEN 'CLOSED'
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
        WHEN ISNULL(c.IsDeleted, 0) = 1 THEN 'CHURNED'
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
    
FROM SalesLT.Customer c
LEFT JOIN SalesLT.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID AND ISNULL(soh.IsDeleted, 0) = 0
WHERE c.CustomerID IS NOT NULL
GROUP BY 
    c.CustomerID, c.FirstName, c.MiddleName, c.LastName, c.EmailAddress, 
    c.Phone, c.CompanyName, c.IsDeleted, c.DeletedDate, c.DeletedBy, c.ModifiedDate;
GO

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
GO

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
        WHEN ISNULL(p.IsDeleted, 0) = 1 THEN 'DISCONTINUED'
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
    ISNULL(SUM(sod.OrderQty * sod.UnitPrice * (1 - sod.UnitPriceDiscount)), 0) as TotalRevenue,  -- Calculate LineTotal manually
    ISNULL(AVG(sod.UnitPrice), p.ListPrice) as AverageSellingPrice,
    ISNULL(MAX(soh.OrderDate), p.SellStartDate) as LastSaleDate,
    
    -- Performance Classification
    CASE 
        WHEN ISNULL(SUM(sod.OrderQty * sod.UnitPrice * (1 - sod.UnitPriceDiscount)), 0) >= 10000 THEN 'TOP_PERFORMER'
        WHEN ISNULL(SUM(sod.OrderQty * sod.UnitPrice * (1 - sod.UnitPriceDiscount)), 0) >= 5000 THEN 'HIGH_PERFORMER'
        WHEN ISNULL(SUM(sod.OrderQty * sod.UnitPrice * (1 - sod.UnitPriceDiscount)), 0) >= 1000 THEN 'MEDIUM_PERFORMER'
        WHEN ISNULL(SUM(sod.OrderQty * sod.UnitPrice * (1 - sod.UnitPriceDiscount)), 0) > 0 THEN 'LOW_PERFORMER'
        ELSE 'NO_SALES'
    END as PerformanceCategory,
    
    -- Product Lifecycle
    p.SellStartDate,
    p.SellEndDate,
    p.DiscontinuedDate,
    p.DeletedDate,
    CASE 
        WHEN ISNULL(p.IsDeleted, 0) = 1 THEN DATEDIFF(DAY, p.SellStartDate, p.DeletedDate)
        WHEN p.SellEndDate IS NOT NULL THEN DATEDIFF(DAY, p.SellStartDate, p.SellEndDate)
        ELSE DATEDIFF(DAY, p.SellStartDate, GETDATE())
    END as ProductLifespanDays

FROM SalesLT.Product p
LEFT JOIN SalesLT.ProductCategory pc ON p.ProductCategoryID = pc.ProductCategoryID
LEFT JOIN SalesLT.ProductModel pm ON p.ProductModelID = pm.ProductModelID
LEFT JOIN SalesLT.SalesOrderDetail sod ON p.ProductID = sod.ProductID
LEFT JOIN SalesLT.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID AND ISNULL(soh.IsDeleted, 0) = 0
GROUP BY 
    p.ProductID, p.Name, p.ProductNumber, p.Color, p.Size, p.Weight,
    pc.Name, pm.Name, p.StandardCost, p.ListPrice, p.SellStartDate, 
    p.SellEndDate, p.DiscontinuedDate, p.IsDeleted, p.DeletedDate;
GO

-- Product Category Performance View
CREATE VIEW CategoryPerformance AS
SELECT 
    pc.ProductCategoryID,
    pc.Name as CategoryName,
    
    -- Product Count Metrics
    COUNT(p.ProductID) as TotalProducts,
    SUM(CASE WHEN ISNULL(p.IsDeleted, 0) = 0 THEN 1 ELSE 0 END) as ActiveProducts,
    SUM(CASE WHEN ISNULL(p.IsDeleted, 0) = 1 THEN 1 ELSE 0 END) as DiscontinuedProducts,
    
    -- Financial Performance
    AVG(p.ListPrice) as AverageProductPrice,
    MIN(p.ListPrice) as MinPrice,
    MAX(p.ListPrice) as MaxPrice,
    AVG(CASE WHEN p.StandardCost > 0 THEN ((p.ListPrice - p.StandardCost) / p.StandardCost) * 100 ELSE 0 END) as AverageMarginPercent,
    
    -- Sales Performance
    ISNULL(SUM(sod.OrderQty), 0) as TotalUnitsSold,
    ISNULL(SUM(sod.OrderQty * sod.UnitPrice * (1 - sod.UnitPriceDiscount)), 0) as TotalRevenue,  -- Calculate LineTotal manually
    COUNT(DISTINCT sod.SalesOrderID) as OrdersWithCategory,
    COUNT(DISTINCT soh.CustomerID) as UniqueCustomers

FROM SalesLT.ProductCategory pc
LEFT JOIN SalesLT.Product p ON pc.ProductCategoryID = p.ProductCategoryID
LEFT JOIN SalesLT.SalesOrderDetail sod ON p.ProductID = sod.ProductID
LEFT JOIN SalesLT.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID AND ISNULL(soh.IsDeleted, 0) = 0
GROUP BY pc.ProductCategoryID, pc.Name;
GO

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
    
    -- Financial Metrics (using calculated TotalDue)
    SUM(soh.SubTotal) as TotalRevenue,
    AVG(soh.SubTotal) as AverageOrderValue,
    SUM(soh.TaxAmt) as TotalTax,
    SUM(soh.Freight) as TotalShipping,
    SUM(soh.SubTotal + soh.TaxAmt + soh.Freight) as GrandTotal,  -- Calculate manually
    
    -- Volume Metrics
    SUM(sod.OrderQty) as TotalQuantitySold,
    AVG(sod.OrderQty) as AverageQuantityPerOrder

FROM SalesLT.SalesOrderHeader soh
JOIN SalesLT.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
WHERE ISNULL(soh.IsDeleted, 0) = 0
  AND soh.OrderDate IS NOT NULL
GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate)
HAVING COUNT(soh.SalesOrderID) > 0;
GO

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
        WHEN ISNULL(soh.IsDeleted, 0) = 1 THEN 'CANCELLED'
        WHEN soh.Status = 1 THEN 'IN_PROCESS'
        WHEN soh.Status = 2 THEN 'APPROVED'
        WHEN soh.Status = 3 THEN 'BACKORDERED'
        WHEN soh.Status = 4 THEN 'REJECTED'
        WHEN soh.Status = 5 THEN 'SHIPPED'
        WHEN soh.Status = 6 THEN 'CANCELLED'
        ELSE 'UNKNOWN'
    END as OrderStatus,
    
    -- Financial Metrics (calculated since TotalDue computed column not available)
    soh.SubTotal,
    soh.TaxAmt,
    soh.Freight,
    (soh.SubTotal + soh.TaxAmt + soh.Freight) as TotalDue,  -- Calculate manually
    
    -- Order Characteristics
    COUNT(sod.ProductID) as LineItemCount,
    SUM(sod.OrderQty) as TotalQuantity,
    AVG(sod.UnitPrice) as AverageItemPrice,
    AVG(sod.UnitPriceDiscount) as AverageDiscount,
    
    -- Customer Classification for this order
    CASE 
        WHEN c.CompanyName IS NOT NULL THEN 'B2B'
        ELSE 'B2C'
    END as OrderType,
    
    -- Order Size Classification (using calculated TotalDue)
    CASE 
        WHEN (soh.SubTotal + soh.TaxAmt + soh.Freight) >= 2000 THEN 'LARGE'
        WHEN (soh.SubTotal + soh.TaxAmt + soh.Freight) >= 500 THEN 'MEDIUM'
        ELSE 'SMALL'
    END as OrderSize

FROM SalesLT.SalesOrderHeader soh
JOIN SalesLT.Customer c ON soh.CustomerID = c.CustomerID
JOIN SalesLT.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
GROUP BY 
    soh.SalesOrderID, soh.CustomerID, c.FirstName, c.LastName, c.CompanyName,
    soh.OrderDate, soh.DueDate, soh.ShipDate, soh.Status, soh.IsDeleted,
    soh.SubTotal, soh.TaxAmt, soh.Freight;
GO

-- ========================================
-- OPERATIONAL VIEWS
-- ========================================

-- Data Quality Dashboard View
CREATE VIEW DataQualityDashboard AS
SELECT 
    'Customer' as TableName,
    COUNT(*) as TotalRecords,
    SUM(CASE WHEN ISNULL(IsDeleted, 0) = 1 THEN 1 ELSE 0 END) as SoftDeletedRecords,
    SUM(CASE WHEN EmailAddress IS NULL OR EmailAddress = '' THEN 1 ELSE 0 END) as MissingEmailRecords,
    SUM(CASE WHEN Phone IS NULL OR Phone = '' THEN 1 ELSE 0 END) as MissingPhoneRecords,
    AVG(DATEDIFF(DAY, ModifiedDate, GETDATE())) as AvgDaysOld

FROM SalesLT.Customer

UNION ALL

SELECT 
    'Product',
    COUNT(*),
    SUM(CASE WHEN ISNULL(IsDeleted, 0) = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN Name IS NULL OR Name = '' THEN 1 ELSE 0 END) as MissingNameRecords,
    SUM(CASE WHEN StandardCost IS NULL OR StandardCost <= 0 THEN 1 ELSE 0 END) as InvalidCostRecords,
    AVG(DATEDIFF(DAY, ModifiedDate, GETDATE()))

FROM SalesLT.Product

UNION ALL

SELECT 
    'SalesOrderHeader',
    COUNT(*),
    SUM(CASE WHEN ISNULL(IsDeleted, 0) = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) as MissingCustomerRecords,
    SUM(CASE WHEN SubTotal IS NULL OR SubTotal <= 0 THEN 1 ELSE 0 END) as InvalidTotalRecords,
    AVG(DATEDIFF(DAY, ModifiedDate, GETDATE()))

FROM SalesLT.SalesOrderHeader;
GO
GO
GO

-- Business KPI Dashboard View
CREATE VIEW BusinessKPIDashboard AS
SELECT 
    -- Current Period Metrics (Last 30 days) - using calculated TotalDue
    COUNT(DISTINCT CASE WHEN soh.OrderDate >= DATEADD(DAY, -30, GETDATE()) AND ISNULL(soh.IsDeleted, 0) = 0 THEN soh.SalesOrderID END) as Orders_Last30Days,
    COUNT(DISTINCT CASE WHEN c.ModifiedDate >= DATEADD(DAY, -30, GETDATE()) AND ISNULL(c.IsDeleted, 0) = 0 THEN c.CustomerID END) as NewCustomers_Last30Days,
    SUM(CASE WHEN soh.OrderDate >= DATEADD(DAY, -30, GETDATE()) AND ISNULL(soh.IsDeleted, 0) = 0 THEN (soh.SubTotal + soh.TaxAmt + soh.Freight) ELSE 0 END) as Revenue_Last30Days,
    
    -- Previous Period Metrics (31-60 days ago)
    COUNT(DISTINCT CASE WHEN soh.OrderDate >= DATEADD(DAY, -60, GETDATE()) AND soh.OrderDate < DATEADD(DAY, -30, GETDATE()) AND ISNULL(soh.IsDeleted, 0) = 0 THEN soh.SalesOrderID END) as Orders_Previous30Days,
    SUM(CASE WHEN soh.OrderDate >= DATEADD(DAY, -60, GETDATE()) AND soh.OrderDate < DATEADD(DAY, -30, GETDATE()) AND ISNULL(soh.IsDeleted, 0) = 0 THEN (soh.SubTotal + soh.TaxAmt + soh.Freight) ELSE 0 END) as Revenue_Previous30Days,
    
    -- Overall Metrics
    COUNT(DISTINCT c.CustomerID) as TotalCustomers,
    COUNT(DISTINCT CASE WHEN ISNULL(c.IsDeleted, 0) = 0 THEN c.CustomerID END) as ActiveCustomers,
    COUNT(DISTINCT p.ProductID) as TotalProducts,
    COUNT(DISTINCT CASE WHEN ISNULL(p.IsDeleted, 0) = 0 THEN p.ProductID END) as ActiveProducts,
    COUNT(DISTINCT soh.SalesOrderID) as TotalOrders,
    SUM(soh.SubTotal + soh.TaxAmt + soh.Freight) as TotalRevenue,  -- Calculate manually
    
    -- Average Metrics
    AVG(soh.SubTotal + soh.TaxAmt + soh.Freight) as AverageOrderValue  -- Calculate manually

FROM SalesLT.Customer c
FULL OUTER JOIN SalesLT.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
FULL OUTER JOIN SalesLT.Product p ON 1=1;  -- Cross join for totals
GO

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
UNION ALL SELECT 'DataQualityDashboard', 'Data quality monitoring across all tables', 'Data Governance, Quality Assurance, Data Management'
UNION ALL SELECT 'BusinessKPIDashboard', 'Key business performance indicators', 'Executive Dashboards, Performance Monitoring, Strategic Planning';
GO

-- ========================================
-- VERIFICATION
-- ========================================

-- Verify all views were created successfully
SELECT 'All Fabric Analytics Views Created Successfully!' as Status;
GO

SELECT * FROM ViewCatalog ORDER BY ViewName;
GO