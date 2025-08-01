-- ========================================
-- Microsoft Fabric Mirroring Demo Setup
-- File: 01-azure-sql-setup.sql
-- Author: stuba83 (https://github.com/stuba83)
-- Purpose: Initial Azure SQL Database setup and verification
-- ========================================

-- Pre-requisites:
-- 1. Azure SQL Database created with AdventureWorksLT sample data
-- 2. System Assigned Managed Identity enabled on SQL Server
-- 3. Firewall rules configured to allow Azure services

PRINT '=== AZURE SQL DATABASE SETUP VERIFICATION ===';
PRINT 'Database: ' + DB_NAME();
PRINT 'Server: ' + @@SERVERNAME;
PRINT 'Execution Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '';

-- ========================================
-- STEP 1: VERIFY SAMPLE DATA INSTALLATION
-- ========================================

PRINT '--- Step 1: Verifying AdventureWorksLT Sample Data ---';

-- Check if we have the expected SalesLT schema
IF EXISTS (SELECT * FROM sys.schemas WHERE name = 'SalesLT')
    PRINT '✓ SalesLT schema found'
ELSE
    PRINT '✗ ERROR: SalesLT schema not found. Please ensure AdventureWorksLT sample data is installed.';

-- Count tables in SalesLT schema
DECLARE @TableCount INT;
SELECT @TableCount = COUNT(*) 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'SalesLT';

PRINT 'Tables found in SalesLT schema: ' + CAST(@TableCount AS VARCHAR);

-- Display all tables with row counts
PRINT '';
PRINT 'Table inventory:';
SELECT 
    t.TABLE_NAME,
    p.rows as RowCount
FROM INFORMATION_SCHEMA.TABLES t
LEFT JOIN sys.partitions p ON p.object_id = OBJECT_ID(t.TABLE_SCHEMA + '.' + t.TABLE_NAME)
LEFT JOIN sys.objects o ON p.object_id = o.object_id
WHERE t.TABLE_SCHEMA = 'SalesLT' 
  AND t.TABLE_TYPE = 'BASE TABLE'
  AND p.index_id IN (0, 1) -- Heap or clustered index
ORDER BY t.TABLE_NAME;

-- ========================================
-- STEP 2: VERIFY DATABASE CONFIGURATION
-- ========================================

PRINT '';
PRINT '--- Step 2: Database Configuration Check ---';

-- Check database collation
PRINT 'Database collation: ' + CAST(DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS VARCHAR);

-- Check database edition and service objective
PRINT 'Database edition: ' + CAST(DATABASEPROPERTYEX(DB_NAME(), 'Edition') AS VARCHAR);
PRINT 'Service objective: ' + CAST(DATABASEPROPERTYEX(DB_NAME(), 'ServiceObjective') AS VARCHAR);

-- Check if Change Data Capture is enabled (should be disabled for mirroring)
IF EXISTS (SELECT * FROM sys.change_tracking_databases WHERE database_id = DB_ID())
    PRINT '⚠️  WARNING: Change Tracking is enabled - this may conflict with mirroring'
ELSE
    PRINT '✓ Change Tracking is not enabled (good for mirroring)';

-- ========================================
-- STEP 3: IDENTIFY POTENTIAL MIRRORING ISSUES
-- ========================================

PRINT '';
PRINT '--- Step 3: Pre-Mirroring Compatibility Check ---';

-- Check for User Defined Types (UDTs) - these will cause mirroring issues
PRINT '';
PRINT 'Checking for User Defined Types (UDTs):';
SELECT DISTINCT
    c.TABLE_SCHEMA,
    c.TABLE_NAME,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    t.name as SystemTypeName,
    CASE WHEN t.is_user_defined = 1 THEN 'UDT (Will cause issues)' ELSE 'Standard Type' END as TypeCategory
FROM INFORMATION_SCHEMA.COLUMNS c
JOIN sys.columns sc ON sc.object_id = OBJECT_ID(c.TABLE_SCHEMA + '.' + c.TABLE_NAME) 
    AND sc.name = c.COLUMN_NAME
JOIN sys.types t ON sc.user_type_id = t.user_type_id
WHERE c.TABLE_SCHEMA = 'SalesLT'
  AND t.is_user_defined = 1
ORDER BY c.TABLE_NAME, c.COLUMN_NAME;

-- Check for computed columns
PRINT '';
PRINT 'Checking for computed columns:';
SELECT 
    OBJECT_SCHEMA_NAME(c.object_id) as SchemaName,
    OBJECT_NAME(c.object_id) as TableName,
    c.name as ColumnName,
    cc.definition as ComputedDefinition
FROM sys.computed_columns cc
JOIN sys.columns c ON cc.object_id = c.object_id AND cc.column_id = c.column_id
WHERE OBJECT_SCHEMA_NAME(c.object_id) = 'SalesLT'
ORDER BY TableName, ColumnName;

-- Check for XML columns
PRINT '';
PRINT 'Checking for XML columns:';
SELECT 
    c.TABLE_SCHEMA,
    c.TABLE_NAME,
    c.COLUMN_NAME,
    c.DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_SCHEMA = 'SalesLT'
  AND c.DATA_TYPE = 'xml'
ORDER BY c.TABLE_NAME, c.COLUMN_NAME;

-- Check for tables without primary keys
PRINT '';
PRINT 'Checking for tables without primary keys:';
SELECT 
    SCHEMA_NAME(t.schema_id) AS SchemaName, 
    t.name AS TableName,
    'Missing Primary Key' as Issue
FROM sys.tables t
LEFT JOIN sys.key_constraints kc ON t.object_id = kc.parent_object_id 
    AND kc.type = 'PK'
WHERE kc.object_id IS NULL
  AND SCHEMA_NAME(t.schema_id) = 'SalesLT'
ORDER BY t.name;

-- ========================================
-- STEP 4: VERIFY CONNECTIVITY REQUIREMENTS
-- ========================================

PRINT '';
PRINT '--- Step 4: Connectivity and Security Check ---';

-- Check current user and permissions
PRINT 'Current user: ' + USER_NAME();
PRINT 'Is member of db_owner: ' + CASE WHEN IS_MEMBER('db_owner') = 1 THEN 'Yes' ELSE 'No' END;

-- Check server-level permissions needed for mirroring
-- Note: ALTER ANY EXTERNAL MIRROR permission is required
SELECT 
    dp.state_desc,
    dp.permission_name,
    dp.grantee_principal_id,
    pr.name as principal_name
FROM sys.server_permissions dp
LEFT JOIN sys.server_principals pr ON dp.grantee_principal_id = pr.principal_id
WHERE dp.permission_name = 'ALTER ANY EXTERNAL MIRROR'
   OR dp.permission_name = 'CONTROL SERVER';

-- ========================================
-- STEP 5: SAMPLE DATA VERIFICATION
-- ========================================

PRINT '';
PRINT '--- Step 5: Sample Data Verification ---';

-- Get sample of key tables
PRINT 'Sample Customer data:';
SELECT TOP 3 
    CustomerID, 
    FirstName, 
    LastName, 
    EmailAddress,
    ModifiedDate
FROM SalesLT.Customer
ORDER BY CustomerID;

PRINT '';
PRINT 'Sample Product data:';
SELECT TOP 3 
    ProductID, 
    Name, 
    ProductNumber, 
    Color, 
    ListPrice,
    ModifiedDate
FROM SalesLT.Product
ORDER BY ProductID;

PRINT '';
PRINT 'Sample Sales Order data:';
SELECT TOP 3 
    SalesOrderID, 
    CustomerID, 
    OrderDate, 
    SubTotal,
    ModifiedDate
FROM SalesLT.SalesOrderHeader
ORDER BY SalesOrderID;

-- ========================================
-- STEP 6: SUMMARY AND NEXT STEPS
-- ========================================

PRINT '';
PRINT '=== SETUP VERIFICATION SUMMARY ===';

-- Count issues that need to be resolved
DECLARE @UDTIssues INT, @ComputedIssues INT, @XMLIssues INT, @PKIssues INT;

SELECT @UDTIssues = COUNT(DISTINCT c.TABLE_NAME)
FROM INFORMATION_SCHEMA.COLUMNS c
JOIN sys.columns sc ON sc.object_id = OBJECT_ID(c.TABLE_SCHEMA + '.' + c.TABLE_NAME) 
    AND sc.name = c.COLUMN_NAME
JOIN sys.types t ON sc.user_type_id = t.user_type_id
WHERE c.TABLE_SCHEMA = 'SalesLT' AND t.is_user_defined = 1;

SELECT @ComputedIssues = COUNT(DISTINCT OBJECT_NAME(c.object_id))
FROM sys.computed_columns cc
JOIN sys.columns c ON cc.object_id = c.object_id AND cc.column_id = c.column_id
WHERE OBJECT_SCHEMA_NAME(c.object_id) = 'SalesLT';

SELECT @XMLIssues = COUNT(DISTINCT c.TABLE_NAME)
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_SCHEMA = 'SalesLT' AND c.DATA_TYPE = 'xml';

SELECT @PKIssues = COUNT(*)
FROM sys.tables t
LEFT JOIN sys.key_constraints kc ON t.object_id = kc.parent_object_id AND kc.type = 'PK'
WHERE kc.object_id IS NULL AND SCHEMA_NAME(t.schema_id) = 'SalesLT';

PRINT 'Issues found that need resolution before mirroring:';
PRINT '  - Tables with UDT columns: ' + CAST(@UDTIssues AS VARCHAR);
PRINT '  - Tables with computed columns: ' + CAST(@ComputedIssues AS VARCHAR);
PRINT '  - Tables with XML columns: ' + CAST(@XMLIssues AS VARCHAR);
PRINT '  - Tables without primary keys: ' + CAST(@PKIssues AS VARCHAR);

PRINT '';
PRINT 'Next steps:';
PRINT '1. Run 02-udt-fixes.sql to resolve UDT compatibility issues';
PRINT '2. Run 03-soft-delete-setup.sql to implement soft delete strategy';
PRINT '3. Configure mirroring in Microsoft Fabric';
PRINT '4. Run demo scripts to test CRUD operations';

PRINT '';
PRINT '✓ Azure SQL Database setup verification completed';
PRINT '📁 Repository: https://github.com/stuba83/fabric-mirroring-demo';