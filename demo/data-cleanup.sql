-- ========================================
-- Microsoft Fabric Mirroring Demo
-- File: 00-cleanup-demo.sql
-- Author: stuba83 (https://github.com/stuba83)
-- Purpose: Clean up previous demo data to ensure fresh demo environment
-- ========================================

-- IMPORTANT: Run this script BEFORE starting a new demo session
-- This ensures a clean slate and prevents conflicts with existing demo data
-- Execute this in Azure SQL Database (source database)

PRINT '=== FABRIC MIRRORING DEMO - DATA CLEANUP ===';
PRINT 'Execution Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT 'Database: ' + DB_NAME();
PRINT 'Server: ' + @@SERVERNAME;
PRINT '';

-- ========================================
-- SAFETY CHECKS
-- ========================================

PRINT '--- Safety Checks ---';

-- Verify we're in the correct database
IF DB_NAME() NOT LIKE '%AdventureWorks%'
BEGIN
    PRINT '⚠️  WARNING: This script is designed for AdventureWorksLT database.';
    PRINT '   Current database: ' + DB_NAME();
    PRINT '   Please verify you are in the correct database before proceeding.';
    PRINT '';
END

-- Check if this is a production environment
IF @@SERVERNAME LIKE '%prod%' OR @@SERVERNAME LIKE '%production%'
BEGIN
    PRINT '🛑 CRITICAL WARNING: This appears to be a production server!';
    PRINT '   Server: ' + @@SERVERNAME;
    PRINT '   This cleanup script should only be run in development/demo environments.';
    PRINT '   Execution halted for safety.';
    RETURN;
END

PRINT '✅ Safety checks passed. Proceeding with cleanup...';
PRINT '';

-- ========================================
-- STEP 1: IDENTIFY DEMO DATA
-- ========================================

PRINT '--- Step 1: Identifying Demo Data ---';

-- Count existing demo data
DECLARE @DemoCustomers INT, @DemoProducts INT, @DemoOrders INT, @DemoOrderDetails INT;

SELECT @DemoCustomers = COUNT(*)
FROM SalesLT.Customer 
WHERE EmailAddress IN (
    'alex.rodriguez@techcycle.com', 
    'sarah.johnson@fitlife.com', 
    'sarah.johnson@fitlifepro.com',
    'michael.chen@corpwellness.com',
    'softdelete.test@fabricdemo.com'
) OR FirstName = 'SoftDelete';

SELECT @DemoProducts = COUNT(*)
FROM SalesLT.Product 
WHERE ProductNumber IN ('SCP-2025-BK', 'FDB-ELITE-RD', 'HSB-750-BL', 'PMBS-2025-SL', 'UBLS-SET-WH')
   OR ProductNumber LIKE 'SCP-%-BK-%'  -- Timestamped versions
   OR ProductNumber LIKE 'FDB-%-RD-%'
   OR ProductNumber LIKE 'HSB-%-BL-%'
   OR ProductNumber LIKE 'PMBS-%-SL-%'
   OR ProductNumber LIKE 'UBLS-%-WH-%'
   OR Name LIKE '%Demo%'
   OR Name LIKE '%Smart Cycling Computer%'
   OR Name LIKE '%Hydro-Smart%'
   OR Name LIKE '%Fabric Demo Bike%';

SELECT @DemoOrders = COUNT(*)
FROM SalesLT.SalesOrderHeader 
WHERE PurchaseOrderNumber IN ('PO-TECH-001', 'PO-FIT-002', 'PO-CORP-003')
   OR PurchaseOrderNumber LIKE 'PO-TECH-%'
   OR PurchaseOrderNumber LIKE 'PO-FIT-%'
   OR PurchaseOrderNumber LIKE 'PO-CORP-%'
   OR AccountNumber LIKE 'ACC-%';

SELECT @DemoOrderDetails = COUNT(*)
FROM SalesLT.SalesOrderDetail sod
JOIN SalesLT.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
WHERE soh.PurchaseOrderNumber IN ('PO-TECH-001', 'PO-FIT-002', 'PO-CORP-003')
   OR soh.PurchaseOrderNumber LIKE 'PO-TECH-%'
   OR soh.PurchaseOrderNumber LIKE 'PO-FIT-%'
   OR soh.PurchaseOrderNumber LIKE 'PO-CORP-%';

PRINT 'Demo data found:';
PRINT '  📧 Demo Customers: ' + CAST(@DemoCustomers AS VARCHAR);
PRINT '  📦 Demo Products: ' + CAST(@DemoProducts AS VARCHAR);
PRINT '  🛒 Demo Orders: ' + CAST(@DemoOrders AS VARCHAR);
PRINT '  📋 Demo Order Details: ' + CAST(@DemoOrderDetails AS VARCHAR);

IF @DemoCustomers = 0 AND @DemoProducts = 0 AND @DemoOrders = 0
BEGIN
    PRINT '✅ No demo data found. Database is already clean.';
    PRINT '   Ready to run demo scripts!';
    RETURN;
END

PRINT '';

-- ========================================
-- STEP 2: BACKUP RECOMMENDATION
-- ========================================

PRINT '--- Step 2: Backup Recommendation ---';
PRINT '⚠️  RECOMMENDATION: Before proceeding with cleanup:';
PRINT '   1. Ensure you have a recent backup of your database';
PRINT '   2. Verify this is a development/demo environment';
PRINT '   3. Coordinate with team members if this is a shared environment';
PRINT '';
PRINT 'Press Ctrl+C to cancel, or wait 10 seconds to continue...';
WAITFOR DELAY '00:00:10';
PRINT 'Continuing with cleanup...';
PRINT '';

-- ========================================
-- STEP 3: CLEAN SALES ORDER DETAILS
-- ========================================

PRINT '--- Step 3: Cleaning Sales Order Details ---';

-- Remove demo order details first (due to FK constraints)
DECLARE @DeletedOrderDetails INT = 0;

DELETE sod 
FROM SalesLT.SalesOrderDetail sod
JOIN SalesLT.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
WHERE soh.PurchaseOrderNumber IN ('PO-TECH-001', 'PO-FIT-002', 'PO-CORP-003')
   OR soh.PurchaseOrderNumber LIKE 'PO-TECH-%'
   OR soh.PurchaseOrderNumber LIKE 'PO-FIT-%'
   OR soh.PurchaseOrderNumber LIKE 'PO-CORP-%'
   OR soh.AccountNumber LIKE 'ACC-%';

SET @DeletedOrderDetails = @@ROWCOUNT;
PRINT '🗑️  Deleted ' + CAST(@DeletedOrderDetails AS VARCHAR) + ' demo order details';

-- Also clean order details for demo products
DELETE sod 
FROM SalesLT.SalesOrderDetail sod
JOIN SalesLT.Product p ON sod.ProductID = p.ProductID
WHERE p.ProductNumber IN ('SCP-2025-BK', 'FDB-ELITE-RD', 'HSB-750-BL', 'PMBS-2025-SL', 'UBLS-SET-WH')
   OR p.ProductNumber LIKE 'SCP-%-BK-%'
   OR p.ProductNumber LIKE 'FDB-%-RD-%'
   OR p.ProductNumber LIKE 'HSB-%-BL-%'
   OR p.ProductNumber LIKE 'PMBS-%-SL-%'
   OR p.ProductNumber LIKE 'UBLS-%-WH-%'
   OR p.Name LIKE '%Demo%'
   OR p.Name LIKE '%Smart Cycling Computer%'
   OR p.Name LIKE '%Hydro-Smart%'
   OR p.Name LIKE '%Fabric Demo Bike%';

SET @DeletedOrderDetails = @DeletedOrderDetails + @@ROWCOUNT;
PRINT '🗑️  Total deleted order details: ' + CAST(@DeletedOrderDetails AS VARCHAR);

-- ========================================
-- STEP 4: CLEAN SALES ORDERS
-- ========================================

PRINT '';
PRINT '--- Step 4: Cleaning Sales Orders ---';

DECLARE @DeletedOrders INT = 0;

-- Remove demo sales orders
DELETE FROM SalesLT.SalesOrderHeader 
WHERE PurchaseOrderNumber IN ('PO-TECH-001', 'PO-FIT-002', 'PO-CORP-003')
   OR PurchaseOrderNumber LIKE 'PO-TECH-%'
   OR PurchaseOrderNumber LIKE 'PO-FIT-%'
   OR PurchaseOrderNumber LIKE 'PO-CORP-%'
   OR AccountNumber LIKE 'ACC-%'
   OR Comment LIKE '%demo%'
   OR Comment LIKE '%Demo%';

SET @DeletedOrders = @@ROWCOUNT;
PRINT '🗑️  Deleted ' + CAST(@DeletedOrders AS VARCHAR) + ' demo sales orders';

-- Remove orphaned orders from demo customers
DELETE soh
FROM SalesLT.SalesOrderHeader soh
JOIN SalesLT.Customer c ON soh.CustomerID = c.CustomerID
WHERE c.EmailAddress IN (
    'alex.rodriguez@techcycle.com', 
    'sarah.johnson@fitlife.com', 
    'sarah.johnson@fitlifepro.com',
    'michael.chen@corpwellness.com',
    'softdelete.test@fabricdemo.com'
) OR c.FirstName = 'SoftDelete';

SET @DeletedOrders = @DeletedOrders + @@ROWCOUNT;
PRINT '🗑️  Total deleted orders: ' + CAST(@DeletedOrders AS VARCHAR);

-- ========================================
-- STEP 5: CLEAN CUSTOMER ADDRESSES
-- ========================================

PRINT '';
PRINT '--- Step 5: Cleaning Customer Addresses ---';

DECLARE @DeletedAddresses INT = 0;

-- Remove addresses for demo customers
DELETE ca
FROM SalesLT.CustomerAddress ca
JOIN SalesLT.Customer c ON ca.CustomerID = c.CustomerID
WHERE c.EmailAddress IN (
    'alex.rodriguez@techcycle.com', 
    'sarah.johnson@fitlife.com', 
    'sarah.johnson@fitlifepro.com',
    'michael.chen@corpwellness.com',
    'softdelete.test@fabricdemo.com'
) OR c.FirstName = 'SoftDelete';

SET @DeletedAddresses = @@ROWCOUNT;
PRINT '🗑️  Deleted ' + CAST(@DeletedAddresses AS VARCHAR) + ' demo customer addresses';

-- ========================================
-- STEP 6: CLEAN PRODUCTS
-- ========================================

PRINT '';
PRINT '--- Step 6: Cleaning Demo Products ---';

DECLARE @DeletedProducts INT = 0;

-- Remove demo products
DELETE FROM SalesLT.Product 
WHERE ProductNumber IN ('SCP-2025-BK', 'FDB-ELITE-RD', 'HSB-750-BL', 'PMBS-2025-SL', 'UBLS-SET-WH')
   OR ProductNumber LIKE 'SCP-%-BK-%'  -- Timestamped versions
   OR ProductNumber LIKE 'FDB-%-RD-%'
   OR ProductNumber LIKE 'HSB-%-BL-%'
   OR ProductNumber LIKE 'PMBS-%-SL-%'
   OR ProductNumber LIKE 'UBLS-%-WH-%'
   OR Name LIKE '%Demo%'
   OR Name LIKE '%Smart Cycling Computer%'
   OR Name LIKE '%Hydro-Smart%'
   OR Name LIKE '%Fabric Demo Bike%'
   OR Name LIKE '%Pro Maintenance Bike Stand%'
   OR Name LIKE '%UltraBright LED%'
   OR Name = 'Smart Cycling Computer Pro 2025'
   OR Name = 'Fabric Demo Bike Elite Edition'
   OR Name LIKE 'Fabric Demo Bike Elite Edition%'
   OR Name = 'Hydro-Smart Water Bottle 750ml'
   OR Name LIKE 'Hydro-Smart Water Bottle%'
   OR Name = 'Pro Maintenance Bike Stand 2025'
   OR Name = 'UltraBright LED Safety Light Set';

SET @DeletedProducts = @@ROWCOUNT;
PRINT '🗑️  Deleted ' + CAST(@DeletedProducts AS VARCHAR) + ' demo products';

-- ========================================
-- STEP 7: CLEAN CUSTOMERS
-- ========================================

PRINT '';
PRINT '--- Step 7: Cleaning Demo Customers ---';

DECLARE @DeletedCustomers INT = 0;

-- Remove demo customers
DELETE FROM SalesLT.Customer 
WHERE EmailAddress IN (
    'alex.rodriguez@techcycle.com', 
    'sarah.johnson@fitlife.com', 
    'sarah.johnson@fitlifepro.com',
    'michael.chen@corpwellness.com',
    'softdelete.test@fabricdemo.com'
) OR FirstName = 'SoftDelete'
  OR (FirstName = 'Alex' AND LastName = 'Rodriguez' AND CompanyName = 'TechCycle Solutions')
  OR (FirstName = 'Sarah' AND LastName = 'Johnson' AND CompanyName IN ('FitLife Gear', 'FitLife Pro Gear'))
  OR (FirstName = 'Michael' AND LastName = 'Chen' AND CompanyName = 'Corporate Wellness Inc')
  OR LastName = 'TestUser'
  OR CompanyName LIKE '%Demo%'
  OR Phone LIKE '555-TECH-%'
  OR Phone LIKE '555-FIT-%'
  OR Phone LIKE '555-CORP-%';

SET @DeletedCustomers = @@ROWCOUNT;
PRINT '🗑️  Deleted ' + CAST(@DeletedCustomers AS VARCHAR) + ' demo customers';

-- ========================================
-- STEP 8: CLEAN SOFT DELETE TEST DATA
-- ========================================

PRINT '';
PRINT '--- Step 8: Cleaning Soft Delete Test Data ---';

-- Reset any soft-deleted records that might be left from previous demos
DECLARE @ResetSoftDeletes INT = 0;

-- Check if soft delete columns exist
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.Customer') AND name = 'IsDeleted')
BEGIN
    -- Reset soft deleted demo records to hard delete them
    UPDATE SalesLT.Customer 
    SET IsDeleted = 0, DeletedDate = NULL, DeletedBy = NULL
    WHERE IsDeleted = 1 
      AND (EmailAddress LIKE '%demo%' 
           OR EmailAddress LIKE '%test%'
           OR FirstName = 'SoftDelete'
           OR LastName = 'TestUser');
    
    SET @ResetSoftDeletes = @@ROWCOUNT;
    PRINT '🔄 Reset ' + CAST(@ResetSoftDeletes AS VARCHAR) + ' soft-deleted records for cleanup';
    
    -- Now delete them permanently
    DELETE FROM SalesLT.Customer 
    WHERE EmailAddress LIKE '%demo%' 
       OR EmailAddress LIKE '%test%'
       OR FirstName = 'SoftDelete'
       OR LastName = 'TestUser';
    
    PRINT '🗑️  Permanently deleted test soft delete records';
END

-- Do the same for Products and Orders if soft delete columns exist
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.Product') AND name = 'IsDeleted')
BEGIN
    UPDATE SalesLT.Product 
    SET IsDeleted = 0, DeletedDate = NULL, DeletedBy = NULL
    WHERE IsDeleted = 1 
      AND (Name LIKE '%Demo%' OR Name LIKE '%Test%');
    
    PRINT '🔄 Reset soft-deleted demo products for cleanup';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.SalesOrderHeader') AND name = 'IsDeleted')
BEGIN
    UPDATE SalesLT.SalesOrderHeader 
    SET IsDeleted = 0, DeletedDate = NULL, DeletedBy = NULL
    WHERE IsDeleted = 1 
      AND (PurchaseOrderNumber LIKE 'PO-TECH-%' 
           OR PurchaseOrderNumber LIKE 'PO-FIT-%'
           OR PurchaseOrderNumber LIKE 'PO-CORP-%');
    
    PRINT '🔄 Reset soft-deleted demo orders for cleanup';
END

-- ========================================
-- STEP 9: VERIFICATION
-- ========================================

PRINT '';
PRINT '--- Step 9: Cleanup Verification ---';

-- Verify cleanup was successful
DECLARE @RemainingCustomers INT, @RemainingProducts INT, @RemainingOrders INT;

SELECT @RemainingCustomers = COUNT(*)
FROM SalesLT.Customer 
WHERE EmailAddress IN (
    'alex.rodriguez@techcycle.com', 
    'sarah.johnson@fitlife.com', 
    'sarah.johnson@fitlifepro.com',
    'michael.chen@corpwellness.com',
    'softdelete.test@fabricdemo.com'
) OR FirstName = 'SoftDelete';

SELECT @RemainingProducts = COUNT(*)
FROM SalesLT.Product 
WHERE ProductNumber IN ('SCP-2025-BK', 'FDB-ELITE-RD', 'HSB-750-BL', 'PMBS-2025-SL', 'UBLS-SET-WH')
   OR Name LIKE '%Demo%'
   OR Name LIKE '%Smart Cycling Computer%'
   OR Name LIKE '%Hydro-Smart%'
   OR Name LIKE '%Fabric Demo Bike%';

SELECT @RemainingOrders = COUNT(*)
FROM SalesLT.SalesOrderHeader 
WHERE PurchaseOrderNumber IN ('PO-TECH-001', 'PO-FIT-002', 'PO-CORP-003')
   OR PurchaseOrderNumber LIKE 'PO-TECH-%'
   OR PurchaseOrderNumber LIKE 'PO-FIT-%'
   OR PurchaseOrderNumber LIKE 'PO-CORP-%';

PRINT 'Cleanup verification:';
PRINT '  📧 Remaining demo customers: ' + CAST(@RemainingCustomers AS VARCHAR);
PRINT '  📦 Remaining demo products: ' + CAST(@RemainingProducts AS VARCHAR);
PRINT '  🛒 Remaining demo orders: ' + CAST(@RemainingOrders AS VARCHAR);

-- ========================================
-- STEP 10: SUMMARY AND RECOMMENDATIONS
-- ========================================

PRINT '';
PRINT '--- Step 10: Cleanup Summary ---';

IF @RemainingCustomers = 0 AND @RemainingProducts = 0 AND @RemainingOrders = 0
BEGIN
    PRINT '✅ CLEANUP SUCCESSFUL!';
    PRINT '';
    PRINT '📊 Cleanup Statistics:';
    PRINT '  🗑️  Deleted ' + CAST(@DeletedCustomers AS VARCHAR) + ' demo customers';
    PRINT '  🗑️  Deleted ' + CAST(@DeletedProducts AS VARCHAR) + ' demo products';
    PRINT '  🗑️  Deleted ' + CAST(@DeletedOrders AS VARCHAR) + ' demo orders';
    PRINT '  🗑️  Deleted ' + CAST(@DeletedOrderDetails AS VARCHAR) + ' demo order details';
    PRINT '  🗑️  Deleted ' + CAST(@DeletedAddresses AS VARCHAR) + ' demo addresses';
    PRINT '';
    PRINT '🎯 Database is now clean and ready for demo!';
    PRINT '';
    PRINT '➡️  Next steps:';
    PRINT '   1. ✅ Database cleaned successfully';
    PRINT '   2. Run 01-insert-demo.sql to create fresh demo data';
    PRINT '   3. Run 02-update-demo.sql to demonstrate updates';
    PRINT '   4. Run 03-delete-demo.sql to demonstrate soft deletes';
END
ELSE
BEGIN
    PRINT '⚠️  CLEANUP INCOMPLETE!';
    PRINT '';
    PRINT '   Some demo records may still exist. This could be due to:';
    PRINT '   • Foreign key constraints preventing deletion';
    PRINT '   • Custom data not covered by cleanup patterns';
    PRINT '   • Insufficient permissions';
    PRINT '';
    PRINT '🔍 Manual review recommended:';
    IF @RemainingCustomers > 0
        PRINT '   • Check remaining demo customers manually';
    IF @RemainingProducts > 0
        PRINT '   • Check remaining demo products manually';
    IF @RemainingOrders > 0
        PRINT '   • Check remaining demo orders manually';
    PRINT '';
    PRINT '💡 You may still proceed with demo scripts, but expect potential conflicts.';
END

-- Check for Fabric mirroring impact
PRINT '';
PRINT '🔄 Fabric Mirroring Impact:';
PRINT '   • All deletions will be replicated to Fabric OneLake';
PRINT '   • If soft delete triggers are active, deletions become UPDATEs';
PRINT '   • Check Fabric SQL Analytics Endpoint to verify cleanup replication';
PRINT '   • Allow 1-5 minutes for complete replication';

PRINT '';
PRINT '=== CLEANUP COMPLETED ===';
PRINT '';
PRINT '📁 Repository: https://github.com/stuba83/fabric-mirroring-demo';
PRINT '📧 Issues? Create an issue: https://github.com/stuba83/fabric-mirroring-demo/issues';
PRINT '';
PRINT '🎉 Ready to start your Fabric Mirroring demo!';

-- ========================================
-- FABRIC VERIFICATION QUERIES
-- ========================================

PRINT '';
PRINT '--- Fabric Verification Queries ---';
PRINT 'Run these queries in Fabric SQL Analytics Endpoint to verify cleanup replication:';
PRINT '';
PRINT '-- Verify demo customers are removed from Fabric:';
PRINT 'SELECT COUNT(*) as DemoCustomersRemaining FROM Customer';
PRINT 'WHERE EmailAddress LIKE ''%techcycle%'' OR EmailAddress LIKE ''%fitlife%'' OR EmailAddress LIKE ''%corpwellness%'';';
PRINT '';
PRINT '-- Verify demo products are removed from Fabric:';
PRINT 'SELECT COUNT(*) as DemoProductsRemaining FROM Product';
PRINT 'WHERE ProductNumber LIKE ''SCP-%'' OR ProductNumber LIKE ''FDB-%'' OR ProductNumber LIKE ''HSB-%'';';
PRINT '';
PRINT '-- Verify demo orders are removed from Fabric:';
PRINT 'SELECT COUNT(*) as DemoOrdersRemaining FROM SalesOrderHeader';
PRINT 'WHERE PurchaseOrderNumber LIKE ''PO-TECH-%'' OR PurchaseOrderNumber LIKE ''PO-FIT-%'' OR PurchaseOrderNumber LIKE ''PO-CORP-%'';';
PRINT '';
PRINT 'Expected result: All counts should be 0 after replication completes.';