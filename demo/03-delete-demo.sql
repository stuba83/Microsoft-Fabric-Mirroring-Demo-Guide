-- ========================================
-- Microsoft Fabric Mirroring Demo
-- File: 03-delete-demo.sql
-- Author: stuba83 (https://github.com/stuba83)
-- Purpose: Demonstrate soft DELETE operations for historical data preservation
-- ========================================

-- DEMO SCENARIO:
-- This script demonstrates how DELETE operations are converted to soft deletes
-- to preserve historical data for analytics in Microsoft Fabric OneLake.
-- Shows the power of maintaining complete data lineage for business intelligence.

PRINT '=== FABRIC MIRRORING DEMO - SOFT DELETE OPERATIONS ===';
PRINT 'Execution Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT 'Database: ' + DB_NAME();
PRINT '';

-- IMPORTANT: This script assumes you've run the setup scripts:
-- 1. 03-soft-delete-setup.sql (to create triggers and audit columns)
-- 2. 01-insert-demo.sql (to create demo data)

-- ========================================
-- DEMO SETUP: VERIFY SOFT DELETE INFRASTRUCTURE
-- ========================================

PRINT '--- Demo Setup: Verifying Soft Delete Infrastructure ---';

-- Check if soft delete triggers exist
DECLARE @TriggerCount INT;
SELECT @TriggerCount = COUNT(*)
FROM sys.triggers 
WHERE name LIKE 'tr_%_SoftDelete';

IF @TriggerCount < 4
BEGIN
    PRINT 'WARNING: Soft delete triggers not found!';
    PRINT '   Please run 03-soft-delete-setup.sql first to create the soft delete infrastructure.';
    PRINT '   This demo requires INSTEAD OF DELETE triggers to work properly.';
    RETURN;
END
ELSE
BEGIN
    PRINT 'Soft delete infrastructure verified (' + CAST(@TriggerCount AS VARCHAR) + ' triggers found)';
END

-- Check if audit columns exist
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.Customer') AND name = 'IsDeleted')
BEGIN
    PRINT 'WARNING: Audit columns not found!';
    PRINT '   Please run 03-soft-delete-setup.sql first to add IsDeleted, DeletedDate, DeletedBy columns.';
    RETURN;
END
ELSE
BEGIN
    PRINT 'Audit columns verified (IsDeleted, DeletedDate, DeletedBy)';
END

PRINT '';

-- ========================================
-- DEMO SETUP: GET REFERENCE DATA
-- ========================================

PRINT '--- Demo Setup: Getting Reference Data for Deletion Tests ---';

-- Get demo records (prefer records created in previous demos)
DECLARE @DemoCustomer1 INT, @DemoCustomer2 INT, @DemoCustomer3 INT;
DECLARE @DemoProduct1 INT, @DemoProduct2 INT, @DemoProduct3 INT, @DemoProduct4 INT, @DemoProduct5 INT;
DECLARE @DemoOrder1 INT, @DemoOrder2 INT;

-- Find demo records by their unique identifiers
SELECT TOP 1 @DemoProduct1 = ProductID FROM SalesLT.Product WHERE ProductNumber LIKE 'SCP-%' AND IsDeleted = 0 ORDER BY ProductID DESC;
SELECT TOP 1 @DemoProduct2 = ProductID FROM SalesLT.Product WHERE ProductNumber LIKE 'FDB-%' AND IsDeleted = 0 ORDER BY ProductID DESC;
SELECT TOP 1 @DemoProduct3 = ProductID FROM SalesLT.Product WHERE ProductNumber LIKE 'HSB-%' AND IsDeleted = 0 ORDER BY ProductID DESC;
SELECT TOP 1 @DemoProduct4 = ProductID FROM SalesLT.Product WHERE ProductNumber LIKE 'PMBS-%' AND IsDeleted = 0 ORDER BY ProductID DESC;
SELECT TOP 1 @DemoProduct5 = ProductID FROM SalesLT.Product WHERE ProductNumber LIKE 'UBLS-%' AND IsDeleted = 0 ORDER BY ProductID DESC;

-- Find demo customers
SELECT TOP 1 @DemoCustomer1 = CustomerID FROM SalesLT.Customer WHERE EmailAddress LIKE '%techcycle%' AND IsDeleted = 0;
SELECT TOP 1 @DemoCustomer2 = CustomerID FROM SalesLT.Customer WHERE EmailAddress LIKE '%fitlife%' AND IsDeleted = 0;
SELECT TOP 1 @DemoCustomer3 = CustomerID FROM SalesLT.Customer WHERE EmailAddress LIKE '%corpwellness%' AND IsDeleted = 0;

-- Find demo orders
SELECT TOP 1 @DemoOrder1 = SalesOrderID FROM SalesLT.SalesOrderHeader WHERE CustomerID = @DemoCustomer1 AND IsDeleted = 0;
SELECT TOP 1 @DemoOrder2 = SalesOrderID FROM SalesLT.SalesOrderHeader WHERE CustomerID = @DemoCustomer2 AND IsDeleted = 0;

-- If demo records not found, use any existing records for demonstration
IF @DemoProduct1 IS NULL
BEGIN
    PRINT 'Demo records from insert demo not found, using existing records...';
    
    -- Get any existing products for demonstration
    SELECT TOP 1 @DemoProduct1 = ProductID FROM SalesLT.Product WHERE IsDeleted = 0 ORDER BY ModifiedDate DESC;
    SELECT TOP 1 @DemoProduct2 = ProductID FROM SalesLT.Product WHERE ProductID != @DemoProduct1 AND IsDeleted = 0 ORDER BY ModifiedDate DESC;
    
    -- Get any existing customers
    SELECT TOP 1 @DemoCustomer1 = CustomerID FROM SalesLT.Customer WHERE IsDeleted = 0 ORDER BY ModifiedDate DESC;
    
    -- Get any existing orders
    SELECT TOP 1 @DemoOrder1 = SalesOrderID FROM SalesLT.SalesOrderHeader WHERE IsDeleted = 0 ORDER BY ModifiedDate DESC;
END

PRINT 'Using records for soft delete demonstration:';
PRINT '  Products: ' + ISNULL(CAST(@DemoProduct1 AS VARCHAR), 'None') + ', ' + ISNULL(CAST(@DemoProduct2 AS VARCHAR), 'None');
PRINT '  Customers: ' + ISNULL(CAST(@DemoCustomer1 AS VARCHAR), 'None') + ', ' + ISNULL(CAST(@DemoCustomer2 AS VARCHAR), 'None');
PRINT '  Orders: ' + ISNULL(CAST(@DemoOrder1 AS VARCHAR), 'None') + ', ' + ISNULL(CAST(@DemoOrder2 AS VARCHAR), 'None');
PRINT '';

-- ========================================
-- DEMO STEP 1: SHOW CURRENT DATA STATUS
-- ========================================

PRINT '--- DEMO Step 1: Current Data Status (Before Soft Deletes) ---';
PRINT 'Showing current record counts and status...';
PRINT '';

-- Show current soft delete summary
PRINT 'Current soft delete summary across all tables:';
SELECT * FROM SalesLT.vw_SoftDelete_Summary ORDER BY TableName;

PRINT '';
PRINT 'Demo records current status:';

-- Show demo products before deletion
IF @DemoProduct1 IS NOT NULL
BEGIN
    SELECT 
        ProductID, Name, ProductNumber, Color, 
        CAST(ListPrice AS DECIMAL(10,2)) as ListPrice,
        IsDeleted, DeletedDate, DeletedBy, ModifiedDate
    FROM SalesLT.Product 
    WHERE ProductID IN (@DemoProduct1, @DemoProduct2, @DemoProduct3, @DemoProduct4, @DemoProduct5)
    ORDER BY ProductID;
END

PRINT '';

-- Show demo customers before deletion
IF @DemoCustomer1 IS NOT NULL
BEGIN
    SELECT 
        CustomerID, 
        CONCAT(FirstName, ' ', ISNULL(MiddleName + ' ', ''), LastName) as FullName,
        EmailAddress, CompanyName,
        IsDeleted, DeletedDate, DeletedBy, ModifiedDate
    FROM SalesLT.Customer 
    WHERE CustomerID IN (@DemoCustomer1, @DemoCustomer2, @DemoCustomer3)
    ORDER BY CustomerID;
END

-- ========================================
-- DEMO STEP 2: PRODUCT DISCONTINUATION (SOFT DELETE)
-- ========================================

PRINT '';
PRINT '--- DEMO Step 2: Product Discontinuation (Soft Delete) ---';
PRINT 'Simulating product discontinuation while preserving historical sales data...';
PRINT '';

-- Scenario: Smart Cycling Computer being discontinued due to new model
IF @DemoProduct1 IS NOT NULL
BEGIN
    PRINT 'PRODUCT DISCONTINUATION: Smart Cycling Computer Pro 2025';
    PRINT 'Reason: New 2026 model launching - discontinuing 2025 version';
    PRINT '';
    
    -- Show product before deletion
    PRINT 'Product before discontinuation:';
    SELECT ProductID, Name, ProductNumber, IsDeleted, DeletedDate, ModifiedDate
    FROM SalesLT.Product WHERE ProductID = @DemoProduct1;
    
    PRINT '';
    PRINT 'Executing DELETE command (will be converted to soft delete by trigger)...';
    
    -- This DELETE will be intercepted by the trigger and converted to UPDATE
    DELETE FROM SalesLT.Product WHERE ProductID = @DemoProduct1;
    
    PRINT '';
    PRINT 'Product after "deletion" (actually soft deleted):';
    SELECT ProductID, Name, ProductNumber, IsDeleted, DeletedDate, DeletedBy, ModifiedDate
    FROM SalesLT.Product WHERE ProductID = @DemoProduct1;
    
    PRINT '';
    PRINT 'Product discontinued but preserved for historical analytics!';
END

PRINT '';
PRINT 'Pausing 10 seconds - Check Fabric to see the soft delete as an UPDATE...';
WAITFOR DELAY '00:00:10';

-- ========================================
-- DEMO STEP 3: CUSTOMER ACCOUNT CLOSURE (SOFT DELETE)
-- ========================================

PRINT '';
PRINT '--- DEMO Step 3: Customer Account Closure (Soft Delete) ---';
PRINT 'Simulating customer account closure while preserving purchase history...';
PRINT '';

-- Scenario: Customer requests account deletion but we need to keep sales history
IF @DemoCustomer2 IS NOT NULL
BEGIN
    PRINT 'CUSTOMER ACCOUNT CLOSURE: Customer requested account deletion';
    PRINT 'Business Requirement: Preserve purchase history for analytics and compliance';
    PRINT '';
    
    -- Show customer before deletion
    PRINT 'Customer before account closure:';
    SELECT 
        CustomerID, FirstName, LastName, EmailAddress, CompanyName,
        IsDeleted, DeletedDate, ModifiedDate
    FROM SalesLT.Customer WHERE CustomerID = @DemoCustomer2;
    
    -- Check if customer has purchase history
    DECLARE @CustomerOrderCount INT;
    SELECT @CustomerOrderCount = COUNT(*) 
    FROM SalesLT.SalesOrderHeader 
    WHERE CustomerID = @DemoCustomer2;
    
    PRINT '';
    PRINT 'Customer has ' + CAST(@CustomerOrderCount AS VARCHAR) + ' orders in history';
    PRINT '';
    PRINT 'Executing DELETE command (will be converted to soft delete by trigger)...';
    
    -- This DELETE will be intercepted by the trigger and converted to UPDATE
    DELETE FROM SalesLT.Customer WHERE CustomerID = @DemoCustomer2;
    
    PRINT '';
    PRINT 'Customer after "deletion" (actually soft deleted):';
    SELECT 
        CustomerID, FirstName, LastName, EmailAddress, CompanyName,
        IsDeleted, DeletedDate, DeletedBy, ModifiedDate
    FROM SalesLT.Customer WHERE CustomerID = @DemoCustomer2;
    
    PRINT '';
    PRINT 'Customer account closed but purchase history preserved!';
    
    -- Verify the customer's orders are still accessible for analytics
    PRINT '';
    PRINT 'Customer''s purchase history still available for analytics:';
    SELECT 
        soh.SalesOrderID, soh.OrderDate, 
        CAST((soh.SubTotal + soh.TaxAmt + soh.Freight) AS DECIMAL(10,2)) as TotalDue,
        'Historical Order (Customer Deleted)' as Note
    FROM SalesLT.SalesOrderHeader soh
    WHERE soh.CustomerID = @DemoCustomer2
    ORDER BY soh.OrderDate;
END

PRINT '';
PRINT 'Pausing 10 seconds - Check Fabric for the customer soft delete...';
WAITFOR DELAY '00:00:10';

-- ========================================
-- DEMO STEP 4: ORDER CANCELLATION (SOFT DELETE)
-- ========================================

PRINT '';
PRINT '--- DEMO Step 4: Order Cancellation (Soft Delete) ---';
PRINT 'Simulating order cancellation while preserving sales pipeline data...';
PRINT '';

-- Scenario: Customer cancels order but we want to track cancellation analytics
IF @DemoOrder1 IS NOT NULL
BEGIN
    PRINT 'ORDER CANCELLATION: Customer cancelled order due to delivery delay';
    PRINT 'Business Requirement: Track cancellation patterns for process improvement';
    PRINT '';
    
    -- Show order before deletion
    PRINT 'Order before cancellation:';
    SELECT 
        SalesOrderID, CustomerID, OrderDate, Status,
        CAST((SubTotal + TaxAmt + Freight) AS DECIMAL(10,2)) as TotalDue,
        IsDeleted, DeletedDate, ModifiedDate
    FROM SalesLT.SalesOrderHeader WHERE SalesOrderID = @DemoOrder1;
    
    -- Show order details
    PRINT '';
    PRINT 'Order details (will be preserved for analytics):';
    SELECT 
        sod.ProductID, p.Name as ProductName, sod.OrderQty,
        CAST(sod.UnitPrice AS DECIMAL(10,2)) as UnitPrice,
        CAST(sod.LineTotal AS DECIMAL(10,2)) as LineTotal
    FROM SalesLT.SalesOrderDetail sod
    JOIN SalesLT.Product p ON sod.ProductID = p.ProductID
    WHERE sod.SalesOrderID = @DemoOrder1;
    
    PRINT '';
    PRINT 'Executing DELETE command (will be converted to soft delete by trigger)...';
    
    -- This DELETE will be intercepted by the trigger and converted to UPDATE
    DELETE FROM SalesLT.SalesOrderHeader WHERE SalesOrderID = @DemoOrder1;
    
    PRINT '';
    PRINT 'Order after "deletion" (actually soft deleted):';
    SELECT 
        SalesOrderID, CustomerID, OrderDate, Status,
        CAST((SubTotal + TaxAmt + Freight) AS DECIMAL(10,2)) as TotalDue,
        IsDeleted, DeletedDate, DeletedBy, ModifiedDate
    FROM SalesLT.SalesOrderHeader WHERE SalesOrderID = @DemoOrder1;
    
    PRINT '';
    PRINT 'Order cancelled but preserved for cancellation analytics!';
END

-- ========================================
-- DEMO STEP 5: BULK SOFT DELETE OPERATION
-- ========================================

PRINT '';
PRINT '--- DEMO Step 5: Bulk Soft Delete Operation ---';
PRINT 'Simulating bulk discontinuation of seasonal products...';
PRINT '';

-- Scenario: End of season - discontinue multiple seasonal items
IF @DemoProduct3 IS NOT NULL AND @DemoProduct5 IS NOT NULL
BEGIN
    PRINT 'SEASONAL CLEANUP: Discontinuing seasonal products for new inventory';
    PRINT 'Products being discontinued: Water bottles and LED lights (seasonal items)';
    PRINT '';
    
    -- Show products before bulk deletion
    PRINT 'Products before seasonal discontinuation:';
    SELECT 
        ProductID, Name, ProductNumber, 
        CAST(ListPrice AS DECIMAL(10,2)) as ListPrice,
        IsDeleted, DeletedDate
    FROM SalesLT.Product 
    WHERE ProductID IN (@DemoProduct3, @DemoProduct5)
    ORDER BY ProductID;
    
    PRINT '';
    PRINT 'Executing bulk DELETE command (will be converted to soft deletes by trigger)...';
    
    -- Bulk soft delete - both will be intercepted by triggers
    DELETE FROM SalesLT.Product 
    WHERE ProductID IN (@DemoProduct3, @DemoProduct5);
    
    PRINT '';
    PRINT 'Products after bulk "deletion" (actually soft deleted):';
    SELECT 
        ProductID, Name, ProductNumber, 
        CAST(ListPrice AS DECIMAL(10,2)) as ListPrice,
        IsDeleted, DeletedDate, DeletedBy
    FROM SalesLT.Product 
    WHERE ProductID IN (@DemoProduct3, @DemoProduct5)
    ORDER BY ProductID;
    
    PRINT '';
    PRINT 'Bulk seasonal discontinuation completed - all data preserved!';
END

PRINT '';
PRINT 'Pausing 10 seconds - Check Fabric for the bulk soft deletes...';
WAITFOR DELAY '00:00:10';

-- ========================================
-- DEMO STEP 6: VERIFY SOFT DELETE EFFECTIVENESS
-- ========================================

PRINT '';
PRINT '--- DEMO Step 6: Verify Soft Delete Effectiveness ---';
PRINT 'Demonstrating that "deleted" records are preserved and queryable...';
PRINT '';

-- Show updated soft delete summary
PRINT 'Updated soft delete summary after demo operations:';
SELECT * FROM SalesLT.vw_SoftDelete_Summary ORDER BY TableName;

PRINT '';

-- Show that soft deleted records are still queryable
PRINT 'Recently soft deleted records (still available for analytics):';
SELECT 
    'Product' as RecordType,
    CAST(ProductID AS VARCHAR) as RecordID,
    Name as RecordName,
    DeletedDate,
    DeletedBy
FROM SalesLT.Product 
WHERE IsDeleted = 1 AND DeletedDate >= DATEADD(HOUR, -1, GETDATE())

UNION ALL

SELECT 
    'Customer' as RecordType,
    CAST(CustomerID AS VARCHAR) as RecordID,
    CONCAT(FirstName, ' ', LastName) as RecordName,
    DeletedDate,
    DeletedBy
FROM SalesLT.Customer 
WHERE IsDeleted = 1 AND DeletedDate >= DATEADD(HOUR, -1, GETDATE())

UNION ALL

SELECT 
    'SalesOrder' as RecordType,
    CAST(SalesOrderID AS VARCHAR) as RecordID,
    'Order #' + CAST(SalesOrderID AS VARCHAR) as RecordName,
    DeletedDate,
    DeletedBy
FROM SalesLT.SalesOrderHeader 
WHERE IsDeleted = 1 AND DeletedDate >= DATEADD(HOUR, -1, GETDATE())

ORDER BY DeletedDate DESC;

-- ========================================
-- DEMO STEP 7: ANALYTICS WITH HISTORICAL DATA
-- ========================================

PRINT '';
PRINT '--- DEMO Step 7: Analytics with Historical Data ---';
PRINT 'Demonstrating advanced analytics using both active and deleted records...';
PRINT '';

-- Product lifecycle analysis
PRINT 'Product Lifecycle Analysis (including discontinued products):';
SELECT 
    p.ProductID,
    p.Name,
    p.ProductNumber,
    CASE 
        WHEN p.IsDeleted = 1 THEN 'DISCONTINUED'
        WHEN p.SellEndDate IS NOT NULL THEN 'END_OF_LIFE'
        ELSE 'ACTIVE'
    END as ProductStatus,
    p.SellStartDate,
    COALESCE(p.DeletedDate, p.SellEndDate) as DiscontinuedDate,
    CASE 
        WHEN p.IsDeleted = 1 THEN DATEDIFF(DAY, p.SellStartDate, p.DeletedDate)
        WHEN p.SellEndDate IS NOT NULL THEN DATEDIFF(DAY, p.SellStartDate, p.SellEndDate)
        ELSE DATEDIFF(DAY, p.SellStartDate, GETDATE())
    END as ProductLifespanDays,
    CAST(p.ListPrice AS DECIMAL(10,2)) as LastKnownPrice
FROM SalesLT.Product p
WHERE p.ProductID IN (@DemoProduct1, @DemoProduct2, @DemoProduct3, @DemoProduct4, @DemoProduct5)
ORDER BY ProductLifespanDays DESC;

PRINT '';

-- Customer retention analysis
PRINT 'Customer Retention Analysis (including closed accounts):';
SELECT 
    c.CustomerID,
    CONCAT(c.FirstName, ' ', c.LastName) as CustomerName,
    c.CompanyName,
    CASE 
        WHEN c.IsDeleted = 1 THEN 'ACCOUNT_CLOSED'
        ELSE 'ACTIVE'
    END as AccountStatus,
    COUNT(soh.SalesOrderID) as TotalOrders,
    ISNULL(SUM(soh.SubTotal + soh.TaxAmt + soh.Freight), 0) as TotalRevenue,
    MAX(soh.OrderDate) as LastOrderDate,
    c.DeletedDate as AccountClosedDate,
    CASE 
        WHEN c.IsDeleted = 1 AND c.DeletedDate IS NOT NULL THEN 
            DATEDIFF(DAY, MAX(soh.OrderDate), c.DeletedDate)
        ELSE NULL
    END as DaysBetweenLastOrderAndClosure
FROM SalesLT.Customer c
LEFT JOIN SalesLT.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID AND soh.IsDeleted = 0
WHERE c.CustomerID IN (@DemoCustomer1, @DemoCustomer2, @DemoCustomer3)
GROUP BY c.CustomerID, c.FirstName, c.LastName, c.CompanyName, c.IsDeleted, c.DeletedDate
ORDER BY TotalRevenue DESC;

-- ========================================
-- DEMO STEP 8: FABRIC VERIFICATION QUERIES
-- ========================================

PRINT '';
PRINT '--- DEMO Step 8: Fabric Verification Queries ---';
PRINT 'Run these queries in your Fabric SQL Analytics Endpoint to verify soft deletes:';
PRINT '';

PRINT '-- Query 1: Verify soft deleted products in Fabric';
PRINT 'SELECT ProductID, Name, ProductNumber, IsDeleted, DeletedDate, DeletedBy, ModifiedDate';
PRINT 'FROM Product';  -- Or SalesLT.Product if schema is preserved
PRINT 'WHERE IsDeleted = 1 AND DeletedDate >= DATEADD(HOUR, -2, GETDATE())';
PRINT 'ORDER BY DeletedDate DESC;';
PRINT '';

PRINT '-- Query 2: Verify soft deleted customers in Fabric';
PRINT 'SELECT CustomerID, FirstName, LastName, EmailAddress, IsDeleted, DeletedDate, DeletedBy';
PRINT 'FROM Customer';  -- Or SalesLT.Customer if schema is preserved
PRINT 'WHERE IsDeleted = 1 AND DeletedDate >= DATEADD(HOUR, -2, GETDATE())';
PRINT 'ORDER BY DeletedDate DESC;';
PRINT '';

PRINT '-- Query 3: Historical sales analysis including deleted records';
PRINT 'SELECT ';
PRINT '    c.CustomerID,';
PRINT '    c.FirstName + '' '' + c.LastName as CustomerName,';
PRINT '    CASE WHEN c.IsDeleted = 1 THEN ''CLOSED'' ELSE ''ACTIVE'' END as AccountStatus,';
PRINT '    COUNT(soh.SalesOrderID) as TotalOrders,';
PRINT '    SUM(soh.SubTotal + soh.TaxAmt + soh.Freight) as TotalRevenue,';
PRINT '    MAX(soh.OrderDate) as LastOrderDate';
PRINT 'FROM Customer c';  -- Or SalesLT.Customer if schema is preserved
PRINT 'LEFT JOIN SalesOrderHeader soh ON c.CustomerID = soh.CustomerID';
PRINT 'WHERE c.EmailAddress LIKE ''%techcycle%'' OR c.EmailAddress LIKE ''%fitlife%'' OR c.EmailAddress LIKE ''%corpwellness%''';
PRINT 'GROUP BY c.CustomerID, c.FirstName, c.LastName, c.IsDeleted';
PRINT 'ORDER BY TotalRevenue DESC;';
PRINT '';

-- ========================================
-- DEMO STEP 9: BUSINESS VALUE DEMONSTRATION
-- ========================================

PRINT '';
PRINT '--- DEMO Step 9: Business Value Demonstration ---';
PRINT 'Showing the business value of soft delete vs hard delete...';
PRINT '';

-- Calculate metrics that would be lost with hard deletes
DECLARE @PreservedRevenue DECIMAL(12,2) = 0;
DECLARE @PreservedOrders INT = 0;
DECLARE @PreservedCustomers INT = 0;
DECLARE @PreservedProducts INT = 0;

-- Calculate preserved revenue from soft deleted customers' historical orders
SELECT @PreservedRevenue = ISNULL(SUM(soh.SubTotal + soh.TaxAmt + soh.Freight), 0),
       @PreservedOrders = COUNT(soh.SalesOrderID)
FROM SalesLT.SalesOrderHeader soh
JOIN SalesLT.Customer c ON soh.CustomerID = c.CustomerID
WHERE c.IsDeleted = 1 AND c.DeletedDate >= DATEADD(HOUR, -1, GETDATE());

-- Count preserved records
SELECT @PreservedCustomers = COUNT(*) 
FROM SalesLT.Customer 
WHERE IsDeleted = 1 AND DeletedDate >= DATEADD(HOUR, -1, GETDATE());

SELECT @PreservedProducts = COUNT(*) 
FROM SalesLT.Product 
WHERE IsDeleted = 1 AND DeletedDate >= DATEADD(HOUR, -1, GETDATE());

PRINT 'BUSINESS VALUE OF SOFT DELETE STRATEGY:';
PRINT '';
PRINT 'Data Preservation Metrics:';
PRINT '   * Historical Revenue Preserved: $' + CAST(@PreservedRevenue AS VARCHAR);
PRINT '   * Historical Orders Preserved: ' + CAST(@PreservedOrders AS VARCHAR);
PRINT '   * Customer Records Preserved: ' + CAST(@PreservedCustomers AS VARCHAR);
PRINT '   * Product Records Preserved: ' + CAST(@PreservedProducts AS VARCHAR);
PRINT '';

PRINT 'Business Benefits Achieved:';
PRINT '   * Complete customer lifetime value analysis possible';
PRINT '   * Product performance tracking including discontinued items';
PRINT '   * Churn analysis and customer retention insights';
PRINT '   * Regulatory compliance and audit trail maintenance';
PRINT '   * Data-driven business decisions based on complete history';
PRINT '   * Ability to "undelete" records if needed';
PRINT '';

PRINT 'What would be lost with hard deletes:';
PRINT '   * Customer purchase history and lifetime value';
PRINT '   * Product sales performance data';
PRINT '   * Revenue attribution and trend analysis';
PRINT '   * Compliance and audit capabilities';
PRINT '   * Customer win-back opportunities';

-- ========================================
-- DEMO STEP 10: RECOVERY DEMONSTRATION
-- ========================================

PRINT '';
PRINT '--- DEMO Step 10: Recovery Demonstration (Undelete) ---';
PRINT 'Showing how soft deleted records can be recovered if needed...';
PRINT '';

-- Scenario: Customer wants to reactivate their account
IF @DemoCustomer2 IS NOT NULL
BEGIN
    PRINT 'CUSTOMER REACTIVATION: Previously closed customer wants to return';
    PRINT 'Demonstrating the ability to "undelete" soft deleted records...';
    PRINT '';
    
    -- Show current soft deleted status
    PRINT 'Customer current status (soft deleted):';
    SELECT CustomerID, FirstName, LastName, EmailAddress, IsDeleted, DeletedDate, DeletedBy
    FROM SalesLT.Customer WHERE CustomerID = @DemoCustomer2;
    
    PRINT '';
    PRINT 'Reactivating customer account...';
    
    -- "Undelete" the customer by resetting soft delete flags
    UPDATE SalesLT.Customer 
    SET IsDeleted = 0,
        DeletedDate = NULL,
        DeletedBy = NULL,
        ModifiedDate = GETDATE()
    WHERE CustomerID = @DemoCustomer2;
    
    PRINT '';
    PRINT 'Customer after reactivation:';
    SELECT CustomerID, FirstName, LastName, EmailAddress, IsDeleted, DeletedDate, ModifiedDate
    FROM SalesLT.Customer WHERE CustomerID = @DemoCustomer2;
    
    PRINT '';
    PRINT 'Customer successfully reactivated with full history intact!';
    PRINT 'All previous orders and purchase history immediately available again.';
    
    -- Show that historical orders are still linked
    PRINT '';
    PRINT 'Customer''s historical orders (never lost):';
    SELECT 
        SalesOrderID, OrderDate, 
        CAST((SubTotal + TaxAmt + Freight) AS DECIMAL(10,2)) as TotalDue,
        'Historical order preserved during account closure' as Note
    FROM SalesLT.SalesOrderHeader 
    WHERE CustomerID = @DemoCustomer2
    ORDER BY OrderDate;
END

PRINT '';
PRINT 'Pausing 10 seconds - Check Fabric for the customer reactivation...';
WAITFOR DELAY '00:00:10';

-- ========================================
-- DEMO COMPLETION SUMMARY
-- ========================================

PRINT '';
PRINT '=== SOFT DELETE DEMO COMPLETED SUCCESSFULLY ===';
PRINT '';
PRINT 'What was demonstrated:';
PRINT '   * DELETE operations converted to soft deletes (UPDATEs)';
PRINT '   * Complete data preservation for historical analytics';
PRINT '   * Real-time replication of soft deletes to Fabric as UPDATEs';
PRINT '   * Real business scenarios: discontinuation, account closure, cancellation';
PRINT '   * Advanced analytics using both active and "deleted" records';
PRINT '   * Recovery capabilities (undelete functionality)';
PRINT '   * Audit trail and compliance benefits';
PRINT '';

PRINT 'Soft Delete Scenarios Covered:';
PRINT '   * Product discontinuation (preserve sales history)';
PRINT '   * Customer account closure (preserve purchase history)';
PRINT '   * Order cancellation (preserve pipeline analytics)';
PRINT '   * Bulk seasonal cleanup (preserve performance data)';
PRINT '   * Account reactivation (demonstrate reversibility)';
PRINT '';

PRINT 'Business Value Demonstrated:';
PRINT '   * Complete customer lifetime value analysis';
PRINT '   * Product performance including discontinued items';
PRINT '   * Churn analysis and retention insights';
PRINT '   * Regulatory compliance and audit capabilities';
PRINT '   * Data-driven decisions based on complete history';
PRINT '   * Flexibility to recover "deleted" data';
PRINT '';

PRINT 'Technical Benefits Shown:';
PRINT '   * Zero data loss in analytical systems';
PRINT '   * Seamless integration with Fabric Mirroring';
PRINT '   * Rich historical datasets for machine learning';
PRINT '   * Granular audit trails and data lineage';
PRINT '   * Protection against accidental data loss';
PRINT '';

PRINT 'Next steps:';
PRINT '   1. Explore advanced historical analytics in Fabric using fabric-views.sql';
PRINT '   2. Build Power BI reports leveraging both active and historical data';
PRINT '   3. Implement alerting on deletion patterns and trends';
PRINT '   4. Create customer win-back campaigns using soft delete data';
PRINT '   5. Develop compliance reports using complete audit trails';
PRINT '';

PRINT 'Advanced Analytics Opportunities:';
PRINT '   * Customer churn prediction models';
PRINT '   * Product lifecycle optimization';
PRINT '   * Revenue recovery analysis';
PRINT '   * Seasonal demand forecasting';
PRINT '   * Regulatory reporting and compliance';
PRINT '';

PRINT 'Repository: https://github.com/stuba83/fabric-mirroring-demo';
PRINT 'Star the repo if this demo was helpful!';
PRINT 'Issues or questions? https://github.com/stuba83/fabric-mirroring-demo/issues';
PRINT '';
PRINT 'CONGRATULATIONS! You''ve completed the full CRUD demonstration';
PRINT '   showing INSERT, UPDATE, and soft DELETE operations with real-time';
PRINT '   replication to Microsoft Fabric OneLake. Your data is now ready';
PRINT '   for advanced analytics, machine learning, and business intelligence!';