-- ========================================
-- Microsoft Fabric Mirroring Demo
-- File: 01-insert-demo.sql
-- Author: stuba83 (https://github.com/stuba83)
-- Purpose: Demonstrate INSERT operations and real-time replication to Fabric
-- ========================================

-- DEMO SCENARIO:
-- This script creates new products and customers to demonstrate how INSERT operations
-- are replicated in real-time from Azure SQL Database to Microsoft Fabric OneLake.
-- Perfect for showing live mirroring capabilities to stakeholders.

PRINT '=== FABRIC MIRRORING DEMO - INSERT OPERATIONS ===';
PRINT 'Execution Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT 'Database: ' + DB_NAME();
PRINT '';

-- ========================================
-- PREPARATION: GET REFERENCE DATA
-- ========================================

PRINT '--- Preparation: Getting Reference Data ---';

-- Get available categories and models for realistic product creation
PRINT 'Available Product Categories:';
SELECT ProductCategoryID, Name FROM SalesLT.ProductCategory ORDER BY Name;

PRINT '';
PRINT 'Available Product Models (showing top 10):';
SELECT TOP 10 ProductModelID, Name FROM SalesLT.ProductModel ORDER BY Name;

-- Get current max IDs for reference
DECLARE @MaxCustomerID INT, @MaxProductID INT;
SELECT @MaxCustomerID = MAX(CustomerID) FROM SalesLT.Customer;
SELECT @MaxProductID = MAX(ProductID) FROM SalesLT.Product;

PRINT '';
PRINT 'Current max CustomerID: ' + CAST(@MaxCustomerID AS VARCHAR);
PRINT 'Current max ProductID: ' + CAST(@MaxProductID AS VARCHAR);
PRINT '';

-- ========================================
-- DEMO STEP 1: INSERT NEW CUSTOMERS
-- ========================================

PRINT '--- DEMO Step 1: Inserting New Customers ---';
PRINT 'Creating realistic customer data for the demo...';
PRINT '';

-- Customer 1: Tech-savvy cyclist
INSERT INTO SalesLT.Customer (
    NameStyle, FirstName, MiddleName, LastName, 
    CompanyName, EmailAddress, Phone,
    PasswordHash, PasswordSalt, ModifiedDate
)
VALUES (
    0, 'Alex', 'M', 'Rodriguez', 
    'TechCycle Solutions', 'alex.rodriguez@techcycle.com', '555-TECH-001',
    'YPdtRdvqeAhj6wyxEsFdQnRsxlJwzHWWwA==', 'K3X8iQ==', GETDATE()
);

DECLARE @Customer1ID INT = SCOPE_IDENTITY();
PRINT '✅ Customer 1 created - Alex Rodriguez (ID: ' + CAST(@Customer1ID AS VARCHAR) + ')';

-- Customer 2: Fitness enthusiast
INSERT INTO SalesLT.Customer (
    NameStyle, FirstName, LastName, 
    CompanyName, EmailAddress, Phone,
    PasswordHash, PasswordSalt, ModifiedDate
)
VALUES (
    0, 'Sarah', 'Johnson', 
    'FitLife Gear', 'sarah.johnson@fitlife.com', '555-FIT-002',
    'XQdtRdvqeAhj6wyxEsFdQnRsxlJwzHWWwB==', 'L4Y9jR==', GETDATE()
);

DECLARE @Customer2ID INT = SCOPE_IDENTITY();
PRINT '✅ Customer 2 created - Sarah Johnson (ID: ' + CAST(@Customer2ID AS VARCHAR) + ')';

-- Customer 3: Corporate buyer
INSERT INTO SalesLT.Customer (
    NameStyle, FirstName, MiddleName, LastName, 
    CompanyName, EmailAddress, Phone,
    PasswordHash, PasswordSalt, ModifiedDate
)
VALUES (
    0, 'Michael', 'T', 'Chen', 
    'Corporate Wellness Inc', 'michael.chen@corpwellness.com', '555-CORP-003',
    'ZRdtRdvqeAhj6wyxEsFdQnRsxlJwzHWWwC==', 'M5Z0kS==', GETDATE()
);

DECLARE @Customer3ID INT = SCOPE_IDENTITY();
PRINT '✅ Customer 3 created - Michael Chen (ID: ' + CAST(@Customer3ID AS VARCHAR) + ')';

-- Wait for replication demonstration
PRINT '';
PRINT '⏱️  Pausing 10 seconds for Fabric mirroring demonstration...';
PRINT '   👀 Check your Fabric SQL Analytics Endpoint now!';
WAITFOR DELAY '00:00:10';

-- ========================================
-- DEMO STEP 2: INSERT NEW PRODUCTS
-- ========================================

PRINT '';
PRINT '--- DEMO Step 2: Inserting New Products ---';
PRINT 'Creating innovative products for 2025 catalog...';
PRINT '';

-- Product 1: High-tech cycling computer
INSERT INTO SalesLT.Product (
    Name, ProductNumber, Color, StandardCost, ListPrice, 
    Size, Weight, ProductCategoryID, ProductModelID, 
    SellStartDate, ModifiedDate
)
VALUES (
    'Smart Cycling Computer Pro 2025', 
    'SCP-2025-BK', 
    'Black', 
    89.50, 
    199.99, 
    NULL, 
    0.3, 
    4,      -- Accessories category
    115,    -- Cable Lock model (reusing existing model)
    GETDATE(), 
    GETDATE()
);

DECLARE @Product1ID INT = SCOPE_IDENTITY();
PRINT '✅ Product 1 created - Smart Cycling Computer Pro 2025 (ID: ' + CAST(@Product1ID AS VARCHAR) + ')';

-- Product 2: Premium demo bike
INSERT INTO SalesLT.Product (
    Name, ProductNumber, Color, StandardCost, ListPrice, 
    Size, Weight, ProductCategoryID, ProductModelID, 
    SellStartDate, ModifiedDate
)
VALUES (
    'Fabric Demo Bike Elite Edition', 
    'FDB-ELITE-RD', 
    'Red', 
    450.75, 
    899.99, 
    'L', 
    12.5, 
    1,      -- Bikes category
    1,      -- Classic Vest model (reusing existing model)
    GETDATE(), 
    GETDATE()
);

DECLARE @Product2ID INT = SCOPE_IDENTITY();
PRINT '✅ Product 2 created - Fabric Demo Bike Elite Edition (ID: ' + CAST(@Product2ID AS VARCHAR) + ')';

-- Product 3: Smart water bottle
INSERT INTO SalesLT.Product (
    Name, ProductNumber, Color, StandardCost, ListPrice, 
    Size, Weight, ProductCategoryID, ProductModelID, 
    SellStartDate, ModifiedDate
)
VALUES (
    'Hydro-Smart Water Bottle 750ml', 
    'HSB-750-BL', 
    'Blue', 
    12.30, 
    34.99, 
    '750ml', 
    0.5, 
    32,     -- Bottles and Cages category
    119,    -- Bike Wash model (reusing existing model)
    GETDATE(), 
    GETDATE()
);

DECLARE @Product3ID INT = SCOPE_IDENTITY();
PRINT '✅ Product 3 created - Hydro-Smart Water Bottle 750ml (ID: ' + CAST(@Product3ID AS VARCHAR) + ')';

-- Product 4: Professional bike stand
INSERT INTO SalesLT.Product (
    Name, ProductNumber, Color, StandardCost, ListPrice, 
    Size, Weight, ProductCategoryID, ProductModelID, 
    SellStartDate, ModifiedDate
)
VALUES (
    'Pro Maintenance Bike Stand 2025', 
    'PMBS-2025-SL', 
    'Silver', 
    75.25, 
    149.99, 
    'Universal', 
    8.2, 
    31,     -- Bike Stands category
    122,    -- All-Purpose Bike Stand model
    GETDATE(), 
    GETDATE()
);

DECLARE @Product4ID INT = SCOPE_IDENTITY();
PRINT '✅ Product 4 created - Pro Maintenance Bike Stand 2025 (ID: ' + CAST(@Product4ID AS VARCHAR) + ')';

-- Product 5: LED safety light set
INSERT INTO SalesLT.Product (
    Name, ProductNumber, Color, StandardCost, ListPrice, 
    Size, Weight, ProductCategoryID, ProductModelID, 
    SellStartDate, ModifiedDate
)
VALUES (
    'UltraBright LED Safety Light Set', 
    'UBLS-SET-WH', 
    'White', 
    18.75, 
    49.99, 
    'Set of 4', 
    0.8, 
    4,      -- Accessories category
    115,    -- Cable Lock model (reusing existing model)
    GETDATE(), 
    GETDATE()
);

DECLARE @Product5ID INT = SCOPE_IDENTITY();
PRINT '✅ Product 5 created - UltraBright LED Safety Light Set (ID: ' + CAST(@Product5ID AS VARCHAR) + ')';

-- Wait for replication demonstration
PRINT '';
PRINT '⏱️  Pausing 15 seconds for Fabric mirroring demonstration...';
PRINT '   👀 Check your Fabric SQL Analytics Endpoint for the new products!';
WAITFOR DELAY '00:00:15';

-- ========================================
-- DEMO STEP 3: INSERT SALES ORDERS
-- ========================================

PRINT '';
PRINT '--- DEMO Step 3: Creating Sample Sales Orders ---';
PRINT 'Generating realistic sales transactions...';
PRINT '';

-- Sales Order 1: Alex Rodriguez buys cycling computer and lights
INSERT INTO SalesLT.SalesOrderHeader (
    RevisionNumber, OrderDate, DueDate, Status, OnlineOrderFlag,
    PurchaseOrderNumber, AccountNumber, CustomerID, 
    ShipMethod, SubTotal, TaxAmt, Freight, ModifiedDate
)
VALUES (
    1, GETDATE(), DATEADD(DAY, 7, GETDATE()), 1, 1,
    'PO-TECH-001', 'ACC-' + CAST(@Customer1ID AS VARCHAR), @Customer1ID,
    'STANDARD GROUND', 249.98, 18.75, 12.50, GETDATE()
);

DECLARE @SalesOrder1ID INT = SCOPE_IDENTITY();
PRINT '✅ Sales Order 1 created for Alex Rodriguez (Order ID: ' + CAST(@SalesOrder1ID AS VARCHAR) + ')';

-- Add order details for Sales Order 1
INSERT INTO SalesLT.SalesOrderDetail (
    SalesOrderID, ProductID, OrderQty, UnitPrice, UnitPriceDiscount, ModifiedDate
)
VALUES 
    (@SalesOrder1ID, @Product1ID, 1, 199.99, 0.00, GETDATE()),  -- Smart Cycling Computer
    (@SalesOrder1ID, @Product5ID, 1, 49.99, 0.00, GETDATE());   -- LED Light Set

PRINT '  - Added cycling computer and LED lights to order';

-- Sales Order 2: Sarah Johnson buys demo bike
INSERT INTO SalesLT.SalesOrderHeader (
    RevisionNumber, OrderDate, DueDate, Status, OnlineOrderFlag,
    PurchaseOrderNumber, AccountNumber, CustomerID, 
    ShipMethod, SubTotal, TaxAmt, Freight, ModifiedDate
)
VALUES (
    1, GETDATE(), DATEADD(DAY, 10, GETDATE()), 1, 1,
    'PO-FIT-002', 'ACC-' + CAST(@Customer2ID AS VARCHAR), @Customer2ID,
    'EXPEDITED', 899.99, 67.50, 25.00, GETDATE()
);

DECLARE @SalesOrder2ID INT = SCOPE_IDENTITY();
PRINT '✅ Sales Order 2 created for Sarah Johnson (Order ID: ' + CAST(@SalesOrder2ID AS VARCHAR) + ')';

-- Add order details for Sales Order 2
INSERT INTO SalesLT.SalesOrderDetail (
    SalesOrderID, ProductID, OrderQty, UnitPrice, UnitPriceDiscount, ModifiedDate
)
VALUES 
    (@SalesOrder2ID, @Product2ID, 1, 899.99, 0.00, GETDATE());  -- Demo Bike

PRINT '  - Added Fabric Demo Bike Elite Edition to order';

-- Sales Order 3: Michael Chen - Corporate bulk order
INSERT INTO SalesLT.SalesOrderHeader (
    RevisionNumber, OrderDate, DueDate, Status, OnlineOrderFlag,
    PurchaseOrderNumber, AccountNumber, CustomerID, 
    ShipMethod, SubTotal, TaxAmt, Freight, ModifiedDate
)
VALUES (
    1, GETDATE(), DATEADD(DAY, 14, GETDATE()), 1, 0,
    'PO-CORP-003', 'ACC-' + CAST(@Customer3ID AS VARCHAR), @Customer3ID,
    'TRUCK GROUND', 584.95, 43.87, 45.00, GETDATE()
);

DECLARE @SalesOrder3ID INT = SCOPE_IDENTITY();
PRINT '✅ Sales Order 3 created for Michael Chen - Corporate (Order ID: ' + CAST(@SalesOrder3ID AS VARCHAR) + ')';

-- Add order details for Sales Order 3 (bulk corporate order)
INSERT INTO SalesLT.SalesOrderDetail (
    SalesOrderID, ProductID, OrderQty, UnitPrice, UnitPriceDiscount, ModifiedDate
)
VALUES 
    (@SalesOrder3ID, @Product3ID, 10, 34.99, 0.10, GETDATE()),  -- 10 Water Bottles with 10% discount
    (@SalesOrder3ID, @Product4ID, 2, 149.99, 0.05, GETDATE()),  -- 2 Bike Stands with 5% discount
    (@SalesOrder3ID, @Product5ID, 5, 49.99, 0.15, GETDATE());   -- 5 LED Light Sets with 15% bulk discount

PRINT '  - Added bulk items: 10 water bottles, 2 bike stands, 5 LED light sets';
PRINT '  - Applied corporate discounts: 10%, 5%, and 15% respectively';

-- Wait for replication demonstration
PRINT '';
PRINT '⏱️  Pausing 10 seconds for sales orders to replicate...';
PRINT '   👀 Check Fabric for the complete sales transaction data!';
WAITFOR DELAY '00:00:10';

-- ========================================
-- DEMO STEP 4: VERIFICATION QUERIES
-- ========================================

PRINT '';
PRINT '--- DEMO Step 4: Verification of Inserted Data ---';
PRINT 'Displaying all newly created records for verification...';
PRINT '';

-- Show new customers
PRINT 'New Customers Created:';
SELECT 
    CustomerID, 
    CONCAT(FirstName, ' ', ISNULL(MiddleName + ' ', ''), LastName) as FullName,
    CompanyName,
    EmailAddress,
    Phone,
    ModifiedDate
FROM SalesLT.Customer 
WHERE CustomerID IN (@Customer1ID, @Customer2ID, @Customer3ID)
ORDER BY CustomerID;

PRINT '';
PRINT 'New Products Created:';
SELECT 
    ProductID,
    Name,
    ProductNumber,
    Color,
    CAST(StandardCost AS DECIMAL(10,2)) as StandardCost,
    CAST(ListPrice AS DECIMAL(10,2)) as ListPrice,
    Size,
    CAST(Weight AS DECIMAL(10,2)) as Weight,
    ModifiedDate
FROM SalesLT.Product 
WHERE ProductID IN (@Product1ID, @Product2ID, @Product3ID, @Product4ID, @Product5ID)
ORDER BY ProductID;

PRINT '';
PRINT 'New Sales Orders Created:';
SELECT 
    soh.SalesOrderID,
    soh.CustomerID,
    CONCAT(c.FirstName, ' ', c.LastName) as CustomerName,
    c.CompanyName,
    soh.OrderDate,
    soh.DueDate,
    CAST(soh.SubTotal AS DECIMAL(10,2)) as SubTotal,
    CAST(soh.TaxAmt AS DECIMAL(10,2)) as TaxAmt,
    CAST(soh.Freight AS DECIMAL(10,2)) as Freight,
    CAST(soh.TotalDue AS DECIMAL(10,2)) as TotalDue,
    soh.ShipMethod
FROM SalesLT.SalesOrderHeader soh
JOIN SalesLT.Customer c ON soh.CustomerID = c.CustomerID
WHERE soh.SalesOrderID IN (@SalesOrder1ID, @SalesOrder2ID, @SalesOrder3ID)
ORDER BY soh.SalesOrderID;

PRINT '';
PRINT 'Sales Order Details:';
SELECT 
    sod.SalesOrderID,
    sod.ProductID,
    p.Name as ProductName,
    p.ProductNumber,
    sod.OrderQty,
    CAST(sod.UnitPrice AS DECIMAL(10,2)) as UnitPrice,
    CAST(sod.UnitPriceDiscount AS DECIMAL(4,2)) as DiscountPercent,
    CAST(sod.LineTotal AS DECIMAL(10,2)) as LineTotal
FROM SalesLT.SalesOrderDetail sod
JOIN SalesLT.Product p ON sod.ProductID = p.ProductID
WHERE sod.SalesOrderID IN (@SalesOrder1ID, @SalesOrder2ID, @SalesOrder3ID)
ORDER BY sod.SalesOrderID, sod.ProductID;

-- ========================================
-- DEMO STEP 5: FABRIC VERIFICATION QUERIES
-- ========================================

PRINT '';
PRINT '--- DEMO Step 5: Fabric Verification Queries ---';
PRINT 'Run these queries in your Fabric SQL Analytics Endpoint to verify replication:';
PRINT '';

PRINT '-- Query 1: Verify new customers in Fabric';
PRINT 'SELECT CustomerID, FirstName, LastName, CompanyName, EmailAddress, ModifiedDate';
PRINT 'FROM Customer';
PRINT 'WHERE CustomerID IN (' + CAST(@Customer1ID AS VARCHAR) + ', ' + CAST(@Customer2ID AS VARCHAR) + ', ' + CAST(@Customer3ID AS VARCHAR) + ')';
PRINT 'ORDER BY CustomerID;';
PRINT '';

PRINT '-- Query 2: Verify new products in Fabric';
PRINT 'SELECT ProductID, Name, ProductNumber, Color, ListPrice, ModifiedDate';
PRINT 'FROM Product';
PRINT 'WHERE ProductNumber LIKE ''SCP-%'' OR ProductNumber LIKE ''FDB-%'' OR ProductNumber LIKE ''HSB-%'' OR ProductNumber LIKE ''PMBS-%'' OR ProductNumber LIKE ''UBLS-%''';
PRINT 'ORDER BY ProductID;';
PRINT '';

PRINT '-- Query 3: Verify sales orders in Fabric';
PRINT 'SELECT SalesOrderID, CustomerID, OrderDate, SubTotal, TotalDue';
PRINT 'FROM SalesOrderHeader';
PRINT 'WHERE SalesOrderID IN (' + CAST(@SalesOrder1ID AS VARCHAR) + ', ' + CAST(@SalesOrder2ID AS VARCHAR) + ', ' + CAST(@SalesOrder3ID AS VARCHAR) + ')';
PRINT 'ORDER BY SalesOrderID;';
PRINT '';

PRINT '-- Query 4: Complete order analysis in Fabric';
PRINT 'SELECT ';
PRINT '    soh.SalesOrderID,';
PRINT '    c.FirstName + '' '' + c.LastName as CustomerName,';
PRINT '    c.CompanyName,';
PRINT '    COUNT(sod.ProductID) as ItemsOrdered,';
PRINT '    SUM(sod.OrderQty) as TotalQuantity,';
PRINT '    AVG(sod.UnitPriceDiscount) as AvgDiscount,';
PRINT '    soh.TotalDue';
PRINT 'FROM SalesOrderHeader soh';
PRINT 'JOIN Customer c ON soh.CustomerID = c.CustomerID';
PRINT 'JOIN SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID';
PRINT 'WHERE soh.SalesOrderID IN (' + CAST(@SalesOrder1ID AS VARCHAR) + ', ' + CAST(@SalesOrder2ID AS VARCHAR) + ', ' + CAST(@SalesOrder3ID AS VARCHAR) + ')';
PRINT 'GROUP BY soh.SalesOrderID, c.FirstName, c.LastName, c.CompanyName, soh.TotalDue';
PRINT 'ORDER BY soh.SalesOrderID;';

-- ========================================
-- DEMO STEP 6: BUSINESS INSIGHTS
-- ========================================

PRINT '';
PRINT '--- DEMO Step 6: Business Insights from New Data ---';

-- Calculate some interesting metrics
DECLARE @TotalNewRevenue DECIMAL(10,2);
DECLARE @TotalNewCustomers INT;
DECLARE @TotalNewProducts INT;
DECLARE @AvgOrderValue DECIMAL(10,2);

SELECT @TotalNewRevenue = SUM(TotalDue) 
FROM SalesLT.SalesOrderHeader 
WHERE SalesOrderID IN (@SalesOrder1ID, @SalesOrder2ID, @SalesOrder3ID);

SET @TotalNewCustomers = 3;
SET @TotalNewProducts = 5;

SELECT @AvgOrderValue = AVG(TotalDue)
FROM SalesLT.SalesOrderHeader 
WHERE SalesOrderID IN (@SalesOrder1ID, @SalesOrder2ID, @SalesOrder3ID);

PRINT '';
PRINT '📊 DEMO SESSION BUSINESS METRICS:';
PRINT '  💰 Total Revenue Generated:  + CAST(@TotalNewRevenue AS VARCHAR);
PRINT '  👥 New Customers Added: ' + CAST(@TotalNewCustomers AS VARCHAR);
PRINT '  📦 New Products Launched: ' + CAST(@TotalNewProducts AS VARCHAR);
PRINT '  💵 Average Order Value:  + CAST(@AvgOrderValue AS VARCHAR);

-- Product category breakdown
PRINT '';
PRINT '📈 PRODUCT CATEGORY BREAKDOWN:';
SELECT 
    pc.Name as CategoryName,
    COUNT(p.ProductID) as NewProducts,
    AVG(p.ListPrice) as AvgPrice,
    SUM(ISNULL(sod.OrderQty, 0)) as TotalUnitsSold
FROM SalesLT.Product p
JOIN SalesLT.ProductCategory pc ON p.ProductCategoryID = pc.ProductCategoryID
LEFT JOIN SalesLT.SalesOrderDetail sod ON p.ProductID = sod.ProductID
WHERE p.ProductID IN (@Product1ID, @Product2ID, @Product3ID, @Product4ID, @Product5ID)
GROUP BY pc.Name, pc.ProductCategoryID
ORDER BY NewProducts DESC;

-- Customer analysis
PRINT '';
PRINT '👤 CUSTOMER ANALYSIS:';
SELECT 
    c.CustomerID,
    CONCAT(c.FirstName, ' ', c.LastName) as CustomerName,
    c.CompanyName,
    ISNULL(SUM(soh.TotalDue), 0) as TotalSpent,
    COUNT(soh.SalesOrderID) as OrdersPlaced,
    CASE 
        WHEN c.CompanyName IS NOT NULL THEN 'B2B'
        ELSE 'B2C'
    END as CustomerType
FROM SalesLT.Customer c
LEFT JOIN SalesLT.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
WHERE c.CustomerID IN (@Customer1ID, @Customer2ID, @Customer3ID)
GROUP BY c.CustomerID, c.FirstName, c.LastName, c.CompanyName
ORDER BY TotalSpent DESC;

-- ========================================
-- DEMO STEP 7: NEXT STEPS PREPARATION
-- ========================================

PRINT '';
PRINT '--- DEMO Step 7: Preparation for Next Demo Steps ---';

-- Store IDs for use in update and delete demos
PRINT '';
PRINT '🔗 REFERENCE IDs FOR NEXT DEMO SCRIPTS:';
PRINT 'Copy these IDs for use in update and delete demonstrations:';
PRINT '';
PRINT '-- Customer IDs:';
PRINT 'DECLARE @DemoCustomer1 INT = ' + CAST(@Customer1ID AS VARCHAR) + '; -- Alex Rodriguez';
PRINT 'DECLARE @DemoCustomer2 INT = ' + CAST(@Customer2ID AS VARCHAR) + '; -- Sarah Johnson';
PRINT 'DECLARE @DemoCustomer3 INT = ' + CAST(@Customer3ID AS VARCHAR) + '; -- Michael Chen';
PRINT '';
PRINT '-- Product IDs:';
PRINT 'DECLARE @DemoProduct1 INT = ' + CAST(@Product1ID AS VARCHAR) + '; -- Smart Cycling Computer';
PRINT 'DECLARE @DemoProduct2 INT = ' + CAST(@Product2ID AS VARCHAR) + '; -- Demo Bike';
PRINT 'DECLARE @DemoProduct3 INT = ' + CAST(@Product3ID AS VARCHAR) + '; -- Water Bottle';
PRINT 'DECLARE @DemoProduct4 INT = ' + CAST(@Product4ID AS VARCHAR) + '; -- Bike Stand';
PRINT 'DECLARE @DemoProduct5 INT = ' + CAST(@Product5ID AS VARCHAR) + '; -- LED Lights';
PRINT '';
PRINT '-- Sales Order IDs:';
PRINT 'DECLARE @DemoOrder1 INT = ' + CAST(@SalesOrder1ID AS VARCHAR) + '; -- Alex''s Order';
PRINT 'DECLARE @DemoOrder2 INT = ' + CAST(@SalesOrder2ID AS VARCHAR) + '; -- Sarah''s Order';
PRINT 'DECLARE @DemoOrder3 INT = ' + CAST(@SalesOrder3ID AS VARCHAR) + '; -- Michael''s Corporate Order';

-- ========================================
-- DEMO COMPLETION SUMMARY
-- ========================================

PRINT '';
PRINT '=== INSERT DEMO COMPLETED SUCCESSFULLY ===';
PRINT '';
PRINT '✅ What was demonstrated:';
PRINT '   📝 INSERT operations for Customers, Products, and Sales Orders';
PRINT '   ⚡ Real-time replication to Microsoft Fabric OneLake';
PRINT '   📊 Immediate availability for analytics in Fabric SQL Analytics Endpoint';
PRINT '   💼 Realistic business scenarios with different customer types';
PRINT '   🛍️  Complex sales transactions with discounts and multiple items';
PRINT '';
PRINT '📈 Data created:';
PRINT '   👥 3 new customers (B2B and B2C)';
PRINT '   📦 5 new products across different categories';
PRINT '   🛒 3 sales orders with 8 line items total';
PRINT '   💰  + CAST(@TotalNewRevenue AS VARCHAR) + ' in new revenue';
PRINT '';
PRINT '🎯 Demo highlights for stakeholders:';
PRINT '   ⚡ Zero-latency data replication';
PRINT '   🔍 Immediate analytical capabilities';
PRINT '   📊 Real-time business intelligence';
PRINT '   🔄 Seamless operational to analytical data flow';
PRINT '';
PRINT '➡️  Next steps:';
PRINT '   1. Run 02-update-demo.sql to show UPDATE replication';
PRINT '   2. Run 03-delete-demo.sql to demonstrate soft delete preservation';
PRINT '   3. Explore advanced analytics in Fabric using the fabric-views.sql';
PRINT '   4. Build Power BI reports using the replicated data';
PRINT '';
PRINT '📁 Repository: https://github.com/stuba83/fabric-mirroring-demo';
PRINT '⭐ Star the repo if this demo was helpful!';
PRINT '🐛 Issues or questions? https://github.com/stuba83/fabric-mirroring-demo/issues';