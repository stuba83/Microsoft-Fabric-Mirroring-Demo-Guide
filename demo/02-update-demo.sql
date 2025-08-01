-- ========================================
-- Microsoft Fabric Mirroring Demo
-- File: 02-update-demo.sql
-- Author: stuba83 (https://github.com/stuba83)
-- Purpose: Demonstrate UPDATE operations and real-time replication to Fabric
-- ========================================

-- DEMO SCENARIO:
-- This script demonstrates various UPDATE scenarios to show how data changes
-- are replicated in real-time from Azure SQL Database to Microsoft Fabric OneLake.
-- Perfect for showing live mirroring of business process changes.

PRINT '=== FABRIC MIRRORING DEMO - UPDATE OPERATIONS ===';
PRINT 'Execution Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT 'Database: ' + DB_NAME();
PRINT '';

-- NOTE: This script assumes you've run 01-insert-demo.sql first
-- If you haven't, update the variables below with existing record IDs

-- ========================================
-- DEMO SETUP: REFERENCE IDs FROM INSERT DEMO
-- ========================================

PRINT '--- Demo Setup: Getting Reference IDs ---';

-- Get the demo records created in the insert demo
-- If 01-insert-demo.sql was run, these should find the records
DECLARE @DemoCustomer1 INT, @DemoCustomer2 INT, @DemoCustomer3 INT;
DECLARE @DemoProduct1 INT, @DemoProduct2 INT, @DemoProduct3 INT, @DemoProduct4 INT, @DemoProduct5 INT;
DECLARE @DemoOrder1 INT, @DemoOrder2 INT, @DemoOrder3 INT;

-- Try to find demo records by their unique identifiers
SELECT @DemoProduct1 = ProductID FROM SalesLT.Product WHERE ProductNumber = 'SCP-2025-BK'; -- Smart Cycling Computer
SELECT @DemoProduct2 = ProductID FROM SalesLT.Product WHERE ProductNumber = 'FDB-ELITE-RD'; -- Demo Bike
SELECT @DemoProduct3 = ProductID FROM SalesLT.Product WHERE ProductNumber = 'HSB-750-BL'; -- Water Bottle
SELECT @DemoProduct4 = ProductID FROM SalesLT.Product WHERE ProductNumber = 'PMBS-2025-SL'; -- Bike Stand
SELECT @DemoProduct5 = ProductID FROM SalesLT.Product WHERE ProductNumber = 'UBLS-SET-WH'; -- LED Lights

-- Find demo customers by email patterns
SELECT @DemoCustomer1 = CustomerID FROM SalesLT.Customer WHERE EmailAddress = 'alex.rodriguez@techcycle.com';
SELECT @DemoCustomer2 = CustomerID FROM SalesLT.Customer WHERE EmailAddress = 'sarah.johnson@fitlife.com';
SELECT @DemoCustomer3 = CustomerID FROM SalesLT.Customer WHERE EmailAddress = 'michael.chen@corpwellness.com';

-- Find demo orders by customer IDs
SELECT @DemoOrder1 = SalesOrderID FROM SalesLT.SalesOrderHeader WHERE CustomerID = @DemoCustomer1 AND PurchaseOrderNumber = 'PO-TECH-001';
SELECT @DemoOrder2 = SalesOrderID FROM SalesLT.SalesOrderHeader WHERE CustomerID = @DemoCustomer2 AND PurchaseOrderNumber = 'PO-FIT-002';
SELECT @DemoOrder3 = SalesOrderID FROM SalesLT.SalesOrderHeader WHERE CustomerID = @DemoCustomer3 AND PurchaseOrderNumber = 'PO-CORP-003';

-- Verify we found the demo records
IF @DemoProduct1 IS NULL OR @DemoCustomer1 IS NULL
BEGIN
    PRINT '⚠️  WARNING: Demo records from 01-insert-demo.sql not found!';
    PRINT '   Please run 01-insert-demo.sql first, or update the variables below with existing IDs.';
    PRINT '';
    
    -- Fallback: use any existing records for demonstration
    SELECT TOP 1 @DemoProduct1 = ProductID FROM SalesLT.Product ORDER BY ModifiedDate DESC;
    SELECT TOP 1 @DemoCustomer1 = CustomerID FROM SalesLT.Customer ORDER BY ModifiedDate DESC;
    
    PRINT '   Using fallback records for demonstration:';
    PRINT '   Product ID: ' + CAST(@DemoProduct1 AS VARCHAR);
    PRINT '   Customer ID: ' + CAST(@DemoCustomer1 AS VARCHAR);
END
ELSE
BEGIN
    PRINT '✅ Demo records found successfully!';
    PRINT '   Products: ' + CAST(@DemoProduct1 AS VARCHAR) + ', ' + CAST(@DemoProduct2 AS VARCHAR) + ', ' + CAST(@DemoProduct3 AS VARCHAR) + ', ' + CAST(@DemoProduct4 AS VARCHAR) + ', ' + CAST(@DemoProduct5 AS VARCHAR);
    PRINT '   Customers: ' + CAST(@DemoCustomer1 AS VARCHAR) + ', ' + CAST(@DemoCustomer2 AS VARCHAR) + ', ' + CAST(@DemoCustomer3 AS VARCHAR);
    PRINT '   Orders: ' + CAST(@DemoOrder1 AS VARCHAR) + ', ' + CAST(@DemoOrder2 AS VARCHAR) + ', ' + CAST(@DemoOrder3 AS VARCHAR);
END

PRINT '';

-- ========================================
-- DEMO STEP 1: PRODUCT PRICE UPDATES
-- ========================================

PRINT '--- DEMO Step 1: Product Price Updates (Promotions & Market Changes) ---';
PRINT 'Simulating real business scenarios: promotions, cost changes, market adjustments...';
PRINT '';

-- Show current prices before updates
PRINT 'Current product prices:';
SELECT 
    ProductID, Name, ProductNumber, Color,
    CAST(StandardCost AS DECIMAL(10,2)) as StandardCost,
    CAST(ListPrice AS DECIMAL(10,2)) as ListPrice,
    ModifiedDate
FROM SalesLT.Product 
WHERE ProductID IN (@DemoProduct1, @DemoProduct2, @DemoProduct3, @DemoProduct4, @DemoProduct5)
ORDER BY ProductID;

PRINT '';

-- Update 1: Flash sale on Smart Cycling Computer (25% discount)
IF @DemoProduct1 IS NOT NULL
BEGIN
    PRINT '💥 FLASH SALE: 25% off Smart Cycling Computer Pro 2025!';
    UPDATE SalesLT.Product 
    SET ListPrice = ListPrice * 0.75,  -- 25% discount
        ModifiedDate = GETDATE()
    WHERE ProductID = @DemoProduct1;
    PRINT '✅ Smart Cycling Computer price updated to flash sale price';
    
    -- Show the change
    SELECT ProductID, Name, CAST(ListPrice AS DECIMAL(10,2)) as NewPrice, ModifiedDate
    FROM SalesLT.Product WHERE ProductID = @DemoProduct1;
END

PRINT '';
PRINT '⏱️  Pausing 8 seconds - Check Fabric for the price change replication...';
WAITFOR DELAY '00:00:08';

-- Update 2: Demo Bike - New variant with different color and size
IF @DemoProduct2 IS NOT NULL
BEGIN
    PRINT '🎨 PRODUCT VARIANT: Creating Blue XL version of Demo Bike';
    UPDATE SalesLT.Product 
    SET Color = 'Blue',
        Size = 'XL',
        Name = 'Fabric Demo Bike Elite Edition - Blue XL',
        ProductNumber = 'FDB-ELITE-BL-XL',
        ListPrice = ListPrice + 50.00,  -- Premium upcharge for XL
        ModifiedDate = GETDATE()
    WHERE ProductID = @DemoProduct2;
    PRINT '✅ Demo Bike updated to Blue XL variant with premium pricing';
    
    SELECT ProductID, Name, ProductNumber, Color, Size, CAST(ListPrice AS DECIMAL(10,2)) as NewPrice
    FROM SalesLT.Product WHERE ProductID = @DemoProduct2;
END

PRINT '';
PRINT '⏱️  Pausing 8 seconds - Check Fabric for the product variant update...';
WAITFOR DELAY '00:00:08';

-- Update 3: Water Bottle - Upgrade to insulated version
IF @DemoProduct3 IS NOT NULL
BEGIN
    PRINT '🌡️  PRODUCT UPGRADE: Water Bottle upgraded to insulated version';
    UPDATE SalesLT.Product 
    SET Name = 'Hydro-Smart Water Bottle 750ml - Insulated',
        StandardCost = StandardCost + 3.20,  -- Higher manufacturing cost
        ListPrice = ListPrice + 5.00,        -- Pass cost to customer
        Weight = Weight + 0.1,               -- Slightly heavier with insulation
        ModifiedDate = GETDATE()
    WHERE ProductID = @DemoProduct3;
    PRINT '✅ Water Bottle upgraded with insulation and adjusted pricing';
    
    SELECT ProductID, Name, CAST(StandardCost AS DECIMAL(10,2)) as StandardCost, 
           CAST(ListPrice AS DECIMAL(10,2)) as ListPrice, CAST(Weight AS DECIMAL(4,1)) as Weight
    FROM SalesLT.Product WHERE ProductID = @DemoProduct3;
END

-- ========================================
-- DEMO STEP 2: CUSTOMER INFORMATION UPDATES
-- ========================================

PRINT '';
PRINT '--- DEMO Step 2: Customer Information Updates ---';
PRINT 'Simulating customer profile changes: contact info, company changes, etc...';
PRINT '';

-- Show current customer info
PRINT 'Current customer information:';
SELECT 
    CustomerID, FirstName, MiddleName, LastName, CompanyName, 
    EmailAddress, Phone, ModifiedDate
FROM SalesLT.Customer 
WHERE CustomerID IN (@DemoCustomer1, @DemoCustomer2, @DemoCustomer3)
ORDER BY CustomerID;

PRINT '';

-- Update 1: Alex Rodriguez - Phone number change
IF @DemoCustomer1 IS NOT NULL
BEGIN
    PRINT '📞 CUSTOMER UPDATE: Alex Rodriguez changed phone number';
    UPDATE SalesLT.Customer 
    SET Phone = '555-TECH-NEW',
        ModifiedDate = GETDATE()
    WHERE CustomerID = @DemoCustomer1;
    PRINT '✅ Alex Rodriguez phone number updated';
END

-- Update 2: Sarah Johnson - Company name change and email update
IF @DemoCustomer2 IS NOT NULL
BEGIN
    PRINT '🏢 CUSTOMER UPDATE: Sarah Johnson - Company rebrand and new email';
    UPDATE SalesLT.Customer 
    SET CompanyName = 'FitLife Pro Gear',  -- Company rebrand
        EmailAddress = 'sarah.johnson@fitlifepro.com',  -- New domain
        ModifiedDate = GETDATE()
    WHERE CustomerID = @DemoCustomer2;
    PRINT '✅ Sarah Johnson company and email updated';
END

-- Update 3: Michael Chen - Add middle initial
IF @DemoCustomer3 IS NOT NULL
BEGIN
    PRINT '👤 CUSTOMER UPDATE: Michael Chen - Added middle initial';
    UPDATE SalesLT.Customer 
    SET MiddleName = 'T',
        ModifiedDate = GETDATE()
    WHERE CustomerID = @DemoCustomer3;
    PRINT '✅ Michael Chen middle initial added';
END

PRINT '';
PRINT '⏱️  Pausing 10 seconds - Check Fabric for customer information updates...';
WAITFOR DELAY '00:00:10';

-- Show updated customer info
PRINT 'Updated customer information:';
SELECT 
    CustomerID, 
    CONCAT(FirstName, ' ', ISNULL(MiddleName + ' ', ''), LastName) as FullName,
    CompanyName, EmailAddress, Phone, ModifiedDate
FROM SalesLT.Customer 
WHERE CustomerID IN (@DemoCustomer1, @DemoCustomer2, @DemoCustomer3)
ORDER BY CustomerID;

-- ========================================
-- DEMO STEP 3: SALES ORDER STATUS UPDATES
-- ========================================

PRINT '';
PRINT '--- DEMO Step 3: Sales Order Status Updates ---';
PRINT 'Simulating order lifecycle: processing, shipping, delivery...';
PRINT '';

-- Show current order status
PRINT 'Current order status:';
SELECT 
    soh.SalesOrderID, soh.CustomerID, 
    CONCAT(c.FirstName, ' ', c.LastName) as CustomerName,
    soh.OrderDate, soh.Status, soh.ShipDate, 
    CAST(soh.TotalDue AS DECIMAL(10,2)) as TotalDue,
    soh.ModifiedDate
FROM SalesLT.SalesOrderHeader soh
JOIN SalesLT.Customer c ON soh.CustomerID = c.CustomerID
WHERE soh.SalesOrderID IN (@DemoOrder1, @DemoOrder2, @DemoOrder3)
ORDER BY soh.SalesOrderID;

PRINT '';

-- Update 1: Order 1 - Approved and ready for shipping
IF @DemoOrder1 IS NOT NULL
BEGIN
    PRINT '📦 ORDER UPDATE: Alex''s order approved and ready for shipping';
    UPDATE SalesLT.SalesOrderHeader 
    SET Status = 2,  -- Approved
        Comment = 'Order approved - ready for fulfillment',
        ModifiedDate = GETDATE()
    WHERE SalesOrderID = @DemoOrder1;
    PRINT '✅ Order ' + CAST(@DemoOrder1 AS VARCHAR) + ' status updated to Approved';
END

-- Update 2: Order 2 - Shipped with tracking
IF @DemoOrder2 IS NOT NULL
BEGIN
    PRINT '🚚 ORDER UPDATE: Sarah''s bike order shipped!';
    UPDATE SalesLT.SalesOrderHeader 
    SET Status = 5,  -- Shipped
        ShipDate = GETDATE(),
        Comment = 'Shipped via Expedited - Tracking: EXP123456789',
        ModifiedDate = GETDATE()
    WHERE SalesOrderID = @DemoOrder2;
    PRINT '✅ Order ' + CAST(@DemoOrder2 AS VARCHAR) + ' status updated to Shipped';
END

-- Update 3: Order 3 - Partial backorder due to high demand
IF @DemoOrder3 IS NOT NULL
BEGIN
    PRINT '⏳ ORDER UPDATE: Michael''s corporate order partially backordered';
    UPDATE SalesLT.SalesOrderHeader 
    SET Status = 3,  -- Backordered
        Comment = 'Partial shipment - LED lights backordered due to high demand',
        ModifiedDate = GETDATE()
    WHERE SalesOrderID = @DemoOrder3;
    PRINT '✅ Order ' + CAST(@DemoOrder3 AS VARCHAR) + ' status updated to Backordered';
END

PRINT '';
PRINT '⏱️  Pausing 10 seconds - Check Fabric for order status updates...';
WAITFOR DELAY '00:00:10';

-- ========================================
-- DEMO STEP 4: BATCH UPDATE OPERATIONS
-- ========================================

PRINT '';
PRINT '--- DEMO Step 4: Batch Update Operations ---';
PRINT 'Demonstrating bulk updates that might occur in real business scenarios...';
PRINT '';

-- Batch Update 1: End-of-season sale - discount all accessories
PRINT '🎉 SEASONAL SALE: 15% off all accessories!';
UPDATE SalesLT.Product 
SET ListPrice = ListPrice * 0.85,  -- 15% discount
    ModifiedDate = GETDATE()
WHERE ProductCategoryID = 4  -- Accessories category
  AND ProductID IN (@DemoProduct1, @DemoProduct5);  -- Only our demo products

PRINT '✅ Seasonal discount applied to accessories';

-- Show affected products
SELECT ProductID, Name, ProductNumber, CAST(ListPrice AS DECIMAL(10,2)) as SalePrice, ModifiedDate
FROM SalesLT.Product 
WHERE ProductCategoryID = 4 AND ProductID IN (@DemoProduct1, @DemoProduct5);

PRINT '';
PRINT '⏱️  Pausing 8 seconds - Check Fabric for batch price updates...';
WAITFOR DELAY '00:00:08';

-- Batch Update 2: Update all pending orders with estimated delivery dates
PRINT '📅 LOGISTICS UPDATE: Adding estimated delivery dates to pending orders';
UPDATE SalesLT.SalesOrderHeader 
SET DueDate = CASE 
    WHEN ShipMethod = 'EXPEDITED' THEN DATEADD(DAY, 3, GETDATE())
    WHEN ShipMethod = 'STANDARD GROUND' THEN DATEADD(DAY, 7, GETDATE())
    WHEN ShipMethod = 'TRUCK GROUND' THEN DATEADD(DAY, 10, GETDATE())
    ELSE DATEADD(DAY, 5, GETDATE())
END,
ModifiedDate = GETDATE()
WHERE SalesOrderID IN (@DemoOrder1, @DemoOrder2, @DemoOrder3)
  AND Status NOT IN (6, 5);  -- Not cancelled or already shipped

PRINT '✅ Estimated delivery dates updated for pending orders';

-- ========================================
-- DEMO STEP 5: COMPLEX UPDATE WITH CALCULATIONS
-- ========================================

PRINT '';
PRINT '--- DEMO Step 5: Complex Updates with Business Logic ---';
PRINT 'Demonstrating updates that involve calculations and business rules...';
PRINT '';

-- Update product margins based on category performance
PRINT '💼 BUSINESS LOGIC: Adjusting margins based on category performance';

-- Get demo products in different categories for margin adjustment
UPDATE p
SET StandardCost = CASE 
    WHEN pc.Name = 'Bikes' THEN p.StandardCost * 0.95  -- Reduce cost (better supplier deal)
    WHEN pc.Name = 'Accessories' THEN p.StandardCost * 1.02  -- Slight cost increase
    WHEN pc.Name = 'Bottles and Cages' THEN p.StandardCost * 0.98  -- Small cost reduction
    ELSE p.StandardCost
END,
ModifiedDate = GETDATE()
FROM SalesLT.Product p
JOIN SalesLT.ProductCategory pc ON p.ProductCategoryID = pc.ProductCategoryID
WHERE p.ProductID IN (@DemoProduct1, @DemoProduct2, @DemoProduct3, @DemoProduct4, @DemoProduct5);

PRINT '✅ Product costs adjusted based on category performance';

-- Show margin changes
SELECT 
    p.ProductID, p.Name, pc.Name as Category,
    CAST(p.StandardCost AS DECIMAL(10,2)) as StandardCost,
    CAST(p.ListPrice AS DECIMAL(10,2)) as ListPrice,
    CAST(((p.ListPrice - p.StandardCost) / p.StandardCost) * 100 AS DECIMAL(5,2)) as MarginPercent,
    p.ModifiedDate
FROM SalesLT.Product p
JOIN SalesLT.ProductCategory pc ON p.ProductCategoryID = pc.ProductCategoryID
WHERE p.ProductID IN (@DemoProduct1, @DemoProduct2, @DemoProduct3, @DemoProduct4, @DemoProduct5)
ORDER BY p.ProductID;

-- ========================================
-- DEMO STEP 6: FABRIC VERIFICATION QUERIES
-- ========================================

PRINT '';
PRINT '--- DEMO Step 6: Fabric Verification Queries ---';
PRINT 'Run these queries in your Fabric SQL Analytics Endpoint to verify all updates:';
PRINT '';

PRINT '-- Query 1: Verify product price changes in Fabric';
PRINT 'SELECT ProductID, Name, ProductNumber, ListPrice, StandardCost, ModifiedDate';
PRINT 'FROM Product';
PRINT 'WHERE ProductNumber IN (''SCP-2025-BK'', ''FDB-ELITE-BL-XL'', ''HSB-750-BL'', ''PMBS-2025-SL'', ''UBLS-SET-WH'')';
PRINT 'ORDER BY ModifiedDate DESC;';
PRINT '';

PRINT '-- Query 2: Verify customer information updates in Fabric'; 
PRINT 'SELECT CustomerID, FirstName, MiddleName, LastName, CompanyName, EmailAddress, Phone, ModifiedDate';
PRINT 'FROM Customer';
PRINT 'WHERE EmailAddress LIKE ''%techcycle%'' OR EmailAddress LIKE ''%fitlifepro%'' OR EmailAddress LIKE ''%corpwellness%''';
PRINT 'ORDER BY ModifiedDate DESC;';
PRINT '';

PRINT '-- Query 3: Verify sales order status updates in Fabric';
PRINT 'SELECT SalesOrderID, CustomerID, Status, ShipDate, DueDate, Comment, ModifiedDate';
PRINT 'FROM SalesOrderHeader';
PRINT 'WHERE PurchaseOrderNumber IN (''PO-TECH-001'', ''PO-FIT-002'', ''PO-CORP-003'')';
PRINT 'ORDER BY ModifiedDate DESC;';
PRINT '';

PRINT '-- Query 4: Advanced analytics - Price change impact analysis';
PRINT 'SELECT ';
PRINT '    p.ProductID,';
PRINT '    p.Name,';
PRINT '    p.ListPrice as CurrentPrice,';
PRINT '    pc.Name as Category,';
PRINT '    ROUND(((p.ListPrice - p.StandardCost) / p.StandardCost) * 100, 2) as MarginPercent,';
PRINT '    p.ModifiedDate as LastPriceChange';
PRINT 'FROM Product p';
PRINT 'JOIN ProductCategory pc ON p.ProductCategoryID = pc.ProductCategoryID';
PRINT 'WHERE p.ProductNumber LIKE ''SCP-%'' OR p.ProductNumber LIKE ''FDB-%'' OR p.ProductNumber LIKE ''HSB-%''';
PRINT '   OR p.ProductNumber LIKE ''PMBS-%'' OR p.ProductNumber LIKE ''UBLS-%''';
PRINT 'ORDER BY p.ModifiedDate DESC;';

-- ========================================
-- DEMO STEP 7: UPDATE IMPACT ANALYSIS
-- ========================================

PRINT '';
PRINT '--- DEMO Step 7: Update Impact Analysis ---';

-- Analyze the impact of all our updates
DECLARE @ProductUpdates INT, @CustomerUpdates INT, @OrderUpdates INT;
DECLARE @AvgPriceChange DECIMAL(10,2);

-- Count updates made in this session (last 30 minutes)
SELECT @ProductUpdates = COUNT(*)
FROM SalesLT.Product 
WHERE ModifiedDate >= DATEADD(MINUTE, -30, GETDATE())
  AND ProductID IN (@DemoProduct1, @DemoProduct2, @DemoProduct3, @DemoProduct4, @DemoProduct5);

SELECT @CustomerUpdates = COUNT(*)
FROM SalesLT.Customer 
WHERE ModifiedDate >= DATEADD(MINUTE, -30, GETDATE())
  AND CustomerID IN (@DemoCustomer1, @DemoCustomer2, @DemoCustomer3);

SELECT @OrderUpdates = COUNT(*)
FROM SalesLT.SalesOrderHeader 
WHERE ModifiedDate >= DATEADD(MINUTE, -30, GETDATE())
  AND SalesOrderID IN (@DemoOrder1, @DemoOrder2, @DemoOrder3);

-- Calculate average price change
SELECT @AvgPriceChange = AVG(ListPrice)
FROM SalesLT.Product 
WHERE ProductID IN (@DemoProduct1, @DemoProduct2, @DemoProduct3, @DemoProduct4, @DemoProduct5);

PRINT '';
PRINT '📊 UPDATE DEMO SESSION SUMMARY:';
PRINT '  📦 Products Updated: ' + CAST(@ProductUpdates AS VARCHAR);
PRINT '  👥 Customers Updated: ' + CAST(@CustomerUpdates AS VARCHAR);
PRINT '  🛒 Orders Updated: ' + CAST(@OrderUpdates AS VARCHAR);
PRINT '  💰 Average Product Price: $' + CAST(@AvgPriceChange AS VARCHAR);
PRINT '';

-- Business scenarios demonstrated
PRINT '🎯 BUSINESS SCENARIOS DEMONSTRATED:';
PRINT '  💥 Flash sales and promotional pricing';
PRINT '  🎨 Product variants and feature upgrades';
PRINT '  📞 Customer information maintenance';
PRINT '  📦 Order status lifecycle management';
PRINT '  🎉 Batch seasonal pricing updates';
PRINT '  💼 Complex margin adjustments with business logic';

-- ========================================
-- DEMO COMPLETION SUMMARY
-- ========================================

PRINT '';
PRINT '=== UPDATE DEMO COMPLETED SUCCESSFULLY ===';
PRINT '';
PRINT '✅ What was demonstrated:';
PRINT '   ✏️  Various UPDATE operation types and patterns';
PRINT '   ⚡ Real-time replication of changes to Microsoft Fabric OneLake';
PRINT '   📊 Immediate availability of updated data for analytics';
PRINT '   💼 Real business scenarios: pricing, customer updates, order processing';
PRINT '   🔄 Complex updates with calculations and business logic';
PRINT '   📈 Batch operations affecting multiple records';
PRINT '';
PRINT '🔄 Update types covered:';
PRINT '   💰 Price changes (individual and batch)';
PRINT '   🎨 Product variants and specifications';
PRINT '   👤 Customer profile updates';
PRINT '   📦 Order status progression';
PRINT '   🧮 Calculated field updates';
PRINT '   📅 Date/time field updates';
PRINT '';
PRINT '📈 Key benefits shown:';
PRINT '   ⚡ Zero-latency change replication';
PRINT '   🔍 Real-time operational reporting';
PRINT '   📊 Live business intelligence updates';
PRINT '   🔄 Seamless data consistency across systems';
PRINT '';
PRINT '➡️  Next steps:';
PRINT '   1. Run 03-delete-demo.sql to demonstrate soft delete preservation';
PRINT '   2. Explore advanced analytics with updated data in Fabric';
PRINT '   3. Build dynamic Power BI reports that reflect real-time changes';
PRINT '   4. Set up alerts on key business metrics';
PRINT '';
PRINT '📁 Repository: https://github.com/stuba83/fabric-mirroring-demo';
PRINT '⭐ Star the repo if this demo was helpful!';
PRINT '🐛 Issues or questions? https://github.com/stuba83/fabric-mirroring-demo/issues';