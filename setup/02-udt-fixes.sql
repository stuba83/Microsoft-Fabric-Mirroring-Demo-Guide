-- ========================================
-- Microsoft Fabric Mirroring Demo
-- File: 02-udt-fixes.sql
-- Author: stuba83 (https://github.com/stuba83)
-- Purpose: Fix User Defined Type (UDT) issues for Fabric Mirroring compatibility
-- ========================================

-- IMPORTANT: Execute this script BEFORE configuring mirroring in Fabric
-- UDT columns will prevent tables from being mirrored successfully

PRINT '=== UDT FIXES FOR FABRIC MIRRORING COMPATIBILITY ===';
PRINT 'Execution Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT 'Database: ' + DB_NAME();
PRINT '';

-- ========================================
-- STEP 1: BACKUP RECOMMENDATIONS
-- ========================================

PRINT '--- Step 1: Backup Recommendations ---';
PRINT '⚠️  IMPORTANT: Before proceeding, ensure you have:';
PRINT '   1. A recent backup of your database';
PRINT '   2. Tested this script in a development environment';
PRINT '   3. Scheduled this during a maintenance window';
PRINT '';

-- ========================================
-- STEP 2: IDENTIFY ALL UDT ISSUES
-- ========================================

PRINT '--- Step 2: Current UDT Issues Analysis ---';

-- Create a temporary table to store UDT issues for reference
CREATE TABLE #UDTIssues (
    TableName NVARCHAR(128),
    ColumnName NVARCHAR(128),
    CurrentDataType NVARCHAR(128),
    UserDefinedTypeName NVARCHAR(128),
    ProposedStandardType NVARCHAR(128)
);

-- Populate UDT issues
INSERT INTO #UDTIssues (TableName, ColumnName, CurrentDataType, UserDefinedTypeName, ProposedStandardType)
SELECT DISTINCT
    c.TABLE_NAME,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    t.name as UserDefinedTypeName,
    CASE 
        WHEN t.name LIKE '%nvarchar%' THEN 'NVARCHAR(' + CAST(c.CHARACTER_MAXIMUM_LENGTH AS VARCHAR) + ')'
        WHEN t.name LIKE '%bit%' THEN 'BIT'
        WHEN t.name LIKE '%int%' THEN 'INT'
        WHEN t.name LIKE '%decimal%' THEN 'DECIMAL(' + CAST(c.NUMERIC_PRECISION AS VARCHAR) + ',' + CAST(c.NUMERIC_SCALE AS VARCHAR) + ')'
        ELSE 'NVARCHAR(50)' -- Default fallback
    END
FROM INFORMATION_SCHEMA.COLUMNS c
JOIN sys.columns sc ON sc.object_id = OBJECT_ID('SalesLT.' + c.TABLE_NAME) 
    AND sc.name = c.COLUMN_NAME
JOIN sys.types t ON sc.user_type_id = t.user_type_id
WHERE c.TABLE_SCHEMA = 'SalesLT'
  AND t.is_user_defined = 1;

-- Display current issues
PRINT 'Current UDT issues found:';
SELECT TableName, ColumnName, UserDefinedTypeName, ProposedStandardType 
FROM #UDTIssues 
ORDER BY TableName, ColumnName;

-- ========================================
-- STEP 3: CHECK FOR DEPENDENT CONSTRAINTS
-- ========================================

PRINT '';
PRINT '--- Step 3: Checking for Dependent Constraints ---';

-- Find DEFAULT constraints that might depend on the UDT columns
SELECT 
    'DROP CONSTRAINT ' + dc.name + ' -- On table ' + OBJECT_NAME(dc.parent_object_id) + '.' + c.name as ConstraintDropCommand,
    dc.name as ConstraintName,
    OBJECT_NAME(dc.parent_object_id) as TableName,
    c.name as ColumnName,
    dc.definition as DefaultDefinition
FROM sys.default_constraints dc
JOIN sys.columns c ON dc.parent_object_id = c.object_id AND dc.parent_column_id = c.column_id
WHERE OBJECT_SCHEMA_NAME(dc.parent_object_id) = 'SalesLT'
  AND c.name IN (SELECT ColumnName FROM #UDTIssues)
ORDER BY OBJECT_NAME(dc.parent_object_id), c.name;

-- ========================================
-- STEP 4: FIX SALESLT.CUSTOMER TABLE
-- ========================================

PRINT '';
PRINT '--- Step 4: Fixing SalesLT.Customer Table ---';

-- Expected UDT issues in Customer table:
-- NameStyle(bit<UDT>), FirstName(nvarchar<UDT>), MiddleName(nvarchar<UDT>), 
-- LastName(nvarchar<UDT>), Phone(nvarchar<UDT>)

-- Step 4.1: Remove DEFAULT constraint for NameStyle (if exists)
PRINT 'Removing DEFAULT constraint for NameStyle...';
BEGIN TRY
    ALTER TABLE SalesLT.Customer DROP CONSTRAINT DF_Customer_NameStyle;
    PRINT '✓ DF_Customer_NameStyle constraint removed';
END TRY
BEGIN CATCH
    PRINT 'ℹ️  DF_Customer_NameStyle constraint not found or already removed';
END CATCH;

-- Step 4.2: Fix UDT columns in Customer table
PRINT 'Converting UDT columns to standard types...';

-- NameStyle: bit<UDT> → BIT
ALTER TABLE SalesLT.Customer 
ALTER COLUMN NameStyle BIT NOT NULL;
PRINT '✓ NameStyle converted to BIT';

-- FirstName: nvarchar<UDT> → NVARCHAR(50)
ALTER TABLE SalesLT.Customer 
ALTER COLUMN FirstName NVARCHAR(50) NOT NULL;
PRINT '✓ FirstName converted to NVARCHAR(50)';

-- MiddleName: nvarchar<UDT> → NVARCHAR(50)
ALTER TABLE SalesLT.Customer 
ALTER COLUMN MiddleName NVARCHAR(50);
PRINT '✓ MiddleName converted to NVARCHAR(50)';

-- LastName: nvarchar<UDT> → NVARCHAR(50)
ALTER TABLE SalesLT.Customer 
ALTER COLUMN LastName NVARCHAR(50) NOT NULL;
PRINT '✓ LastName converted to NVARCHAR(50)';

-- Phone: nvarchar<UDT> → NVARCHAR(25)
ALTER TABLE SalesLT.Customer 
ALTER COLUMN Phone NVARCHAR(25);
PRINT '✓ Phone converted to NVARCHAR(25)';

-- Step 4.3: Recreate DEFAULT constraint for NameStyle
ALTER TABLE SalesLT.Customer 
ADD CONSTRAINT DF_Customer_NameStyle DEFAULT (0) FOR NameStyle;
PRINT '✓ DF_Customer_NameStyle constraint recreated';

-- ========================================
-- STEP 5: FIX SALESLT.PRODUCT TABLE
-- ========================================

PRINT '';
PRINT '--- Step 5: Fixing SalesLT.Product Table ---';

-- Expected UDT issue: Name(nvarchar<UDT>)
ALTER TABLE SalesLT.Product 
ALTER COLUMN Name NVARCHAR(50) NOT NULL;
PRINT '✓ Product.Name converted to NVARCHAR(50)';

-- ========================================
-- STEP 6: FIX SALESLT.PRODUCTCATEGORY TABLE
-- ========================================

PRINT '';
PRINT '--- Step 6: Fixing SalesLT.ProductCategory Table ---';

-- Expected UDT issue: Name(nvarchar<UDT>)
ALTER TABLE SalesLT.ProductCategory 
ALTER COLUMN Name NVARCHAR(50) NOT NULL;
PRINT '✓ ProductCategory.Name converted to NVARCHAR(50)';

-- ========================================
-- STEP 7: FIX SALESLT.PRODUCTMODEL TABLE
-- ========================================

PRINT '';
PRINT '--- Step 7: Fixing SalesLT.ProductModel Table ---';

-- Expected UDT issue: Name(nvarchar<UDT>)
-- Note: CatalogDescription(xml) will remain unsupported - that's expected
ALTER TABLE SalesLT.ProductModel 
ALTER COLUMN Name NVARCHAR(50) NOT NULL;
PRINT '✓ ProductModel.Name converted to NVARCHAR(50)';
PRINT 'ℹ️  CatalogDescription(xml) remains unsupported - this is expected';

-- ========================================
-- STEP 8: FIX SALESLT.CUSTOMERADDRESS TABLE
-- ========================================

PRINT '';
PRINT '--- Step 8: Fixing SalesLT.CustomerAddress Table ---';

-- Expected UDT issue: AddressType(nvarchar<UDT>)
ALTER TABLE SalesLT.CustomerAddress 
ALTER COLUMN AddressType NVARCHAR(50) NOT NULL;
PRINT '✓ CustomerAddress.AddressType converted to NVARCHAR(50)';

-- ========================================
-- STEP 9: FIX SALESLT.SALESORDERHEADER TABLE
-- ========================================

PRINT '';
PRINT '--- Step 9: Fixing SalesLT.SalesOrderHeader Table ---';

-- Expected UDT issues: OnlineOrderFlag(bit<UDT>), PurchaseOrderNumber(nvarchar<UDT>), AccountNumber(nvarchar<UDT>)
-- Note: TotalDue(money<Computed>) and SalesOrderNumber(nvarchar<Computed>) are computed columns - leave as-is

-- Check for DEFAULT constraint on OnlineOrderFlag
BEGIN TRY
    -- Try common constraint names
    ALTER TABLE SalesLT.SalesOrderHeader DROP CONSTRAINT DF_SalesOrderHeader_OnlineOrderFlag;
    PRINT '✓ DF_SalesOrderHeader_OnlineOrderFlag constraint removed';
END TRY
BEGIN CATCH
    PRINT 'ℹ️  OnlineOrderFlag DEFAULT constraint not found or already removed';
END CATCH;

-- Fix UDT columns (leave computed columns unchanged)
ALTER TABLE SalesLT.SalesOrderHeader 
ALTER COLUMN OnlineOrderFlag BIT NOT NULL;
PRINT '✓ OnlineOrderFlag converted to BIT';

ALTER TABLE SalesLT.SalesOrderHeader 
ALTER COLUMN PurchaseOrderNumber NVARCHAR(25);
PRINT '✓ PurchaseOrderNumber converted to NVARCHAR(25)';

ALTER TABLE SalesLT.SalesOrderHeader 
ALTER COLUMN AccountNumber NVARCHAR(15);
PRINT '✓ AccountNumber converted to NVARCHAR(15)';

-- Recreate DEFAULT constraint for OnlineOrderFlag (commonly defaults to 1)
BEGIN TRY
    ALTER TABLE SalesLT.SalesOrderHeader 
    ADD CONSTRAINT DF_SalesOrderHeader_OnlineOrderFlag DEFAULT (1) FOR OnlineOrderFlag;
    PRINT '✓ DF_SalesOrderHeader_OnlineOrderFlag constraint recreated';
END TRY
BEGIN CATCH
    PRINT 'ℹ️  Could not recreate OnlineOrderFlag DEFAULT constraint - manual review needed';
END CATCH;

PRINT 'ℹ️  TotalDue and SalesOrderNumber remain as computed columns (expected limitation)';

-- ========================================
-- STEP 10: VERIFICATION
-- ========================================

PRINT '';
PRINT '--- Step 10: Post-Fix Verification ---';

-- Check if any UDT issues remain
PRINT 'Checking for remaining UDT issues...';
SELECT 
    c.TABLE_NAME,
    c.COLUMN_NAME,
    t.name as TypeName,
    CASE WHEN t.is_user_defined = 1 THEN '❌ Still UDT' ELSE '✅ Standard Type' END as Status
FROM INFORMATION_SCHEMA.COLUMNS c
JOIN sys.columns sc ON sc.object_id = OBJECT_ID('SalesLT.' + c.TABLE_NAME) 
    AND sc.name = c.COLUMN_NAME
JOIN sys.types t ON sc.user_type_id = t.user_type_id
WHERE c.TABLE_SCHEMA = 'SalesLT'
  AND c.TABLE_NAME IN (SELECT DISTINCT TableName FROM #UDTIssues)
  AND c.COLUMN_NAME IN (SELECT DISTINCT ColumnName FROM #UDTIssues)
ORDER BY c.TABLE_NAME, c.COLUMN_NAME;

-- Verify sample data integrity
PRINT '';
PRINT 'Verifying data integrity after conversions:';
SELECT 'Customer' as TableName, COUNT(*) as RecordCount FROM SalesLT.Customer
UNION ALL
SELECT 'Product', COUNT(*) FROM SalesLT.Product
UNION ALL
SELECT 'ProductCategory', COUNT(*) FROM SalesLT.ProductCategory
UNION ALL
SELECT 'ProductModel', COUNT(*) FROM SalesLT.ProductModel
UNION ALL
SELECT 'CustomerAddress', COUNT(*) FROM SalesLT.CustomerAddress
UNION ALL
SELECT 'SalesOrderHeader', COUNT(*) FROM SalesLT.SalesOrderHeader;

-- Clean up temporary table
DROP TABLE #UDTIssues;

-- ========================================
-- STEP 11: SUMMARY AND NEXT STEPS
-- ========================================

PRINT '';
PRINT '=== UDT FIXES COMPLETED SUCCESSFULLY ===';
PRINT '';
PRINT 'Tables fixed:';
PRINT '✅ SalesLT.Customer - 5 UDT columns converted';
PRINT '✅ SalesLT.Product - 1 UDT column converted';
PRINT '✅ SalesLT.ProductCategory - 1 UDT column converted';
PRINT '✅ SalesLT.ProductModel - 1 UDT column converted';
PRINT '✅ SalesLT.CustomerAddress - 1 UDT column converted';
PRINT '✅ SalesLT.SalesOrderHeader - 3 UDT columns converted';
PRINT '';
PRINT 'Expected remaining limitations (these are normal):';
PRINT 'ℹ️  ProductModel.CatalogDescription(xml) - XML type not supported';
PRINT 'ℹ️  SalesOrderHeader computed columns - Computed columns not supported';
PRINT '';
PRINT 'Next steps:';
PRINT '1. ✅ UDT issues resolved - ready for mirroring';
PRINT '2. Run 03-soft-delete-setup.sql for historical data preservation';
PRINT '3. Configure mirroring in Microsoft Fabric';
PRINT '4. Test with demo CRUD operations';
PRINT '';
PRINT '📁 Repository: https://github.com/stuba83/fabric-mirroring-demo';
PRINT '📧 Issues? Create an issue at: https://github.com/stuba83/fabric-mirroring-demo/issues';