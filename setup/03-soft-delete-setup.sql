-- ========================================
-- Microsoft Fabric Mirroring Demo
-- File: 03-soft-delete-setup.sql
-- Author: stuba83 (https://github.com/stuba83)
-- Purpose: Implement soft delete strategy for historical data preservation
-- ========================================

-- WHY SOFT DELETE FOR FABRIC MIRRORING?
-- Regular DELETE operations will be replicated to Fabric, removing data permanently.
-- For analytics, we want to preserve historical data while marking records as "deleted".
-- This approach maintains complete data lineage for analytical purposes.

PRINT '=== SOFT DELETE SETUP FOR FABRIC MIRRORING ===';
PRINT 'Execution Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT 'Database: ' + DB_NAME();
PRINT '';

-- ========================================
-- STEP 1: ADD AUDIT COLUMNS TO MAIN TABLES
-- ========================================

PRINT '--- Step 1: Adding Audit Columns ---';
PRINT 'Adding soft delete and audit columns to key tables...';
PRINT '';

-- Customer table audit columns
PRINT 'Adding audit columns to SalesLT.Customer...';
BEGIN TRY
    ALTER TABLE SalesLT.Customer 
    ADD IsDeleted BIT NOT NULL DEFAULT 0,
        DeletedDate DATETIME2 NULL,
        DeletedBy NVARCHAR(100) NULL;
    PRINT '✅ Customer audit columns added successfully';
END TRY
BEGIN CATCH
    PRINT '⚠️  Customer audit columns may already exist: ' + ERROR_MESSAGE();
END CATCH;

-- Product table audit columns
PRINT 'Adding audit columns to SalesLT.Product...';
BEGIN TRY
    ALTER TABLE SalesLT.Product 
    ADD IsDeleted BIT NOT NULL DEFAULT 0,
        DeletedDate DATETIME2 NULL,
        DeletedBy NVARCHAR(100) NULL;
    PRINT '✅ Product audit columns added successfully';
END TRY
BEGIN CATCH
    PRINT '⚠️  Product audit columns may already exist: ' + ERROR_MESSAGE();
END CATCH;

-- SalesOrderHeader table audit columns
PRINT 'Adding audit columns to SalesLT.SalesOrderHeader...';
BEGIN TRY
    ALTER TABLE SalesLT.SalesOrderHeader 
    ADD IsDeleted BIT NOT NULL DEFAULT 0,
        DeletedDate DATETIME2 NULL,
        DeletedBy NVARCHAR(100) NULL;
    PRINT '✅ SalesOrderHeader audit columns added successfully';
END TRY
BEGIN CATCH
    PRINT '⚠️  SalesOrderHeader audit columns may already exist: ' + ERROR_MESSAGE();
END CATCH;

-- ProductCategory table audit columns
PRINT 'Adding audit columns to SalesLT.ProductCategory...';
BEGIN TRY
    ALTER TABLE SalesLT.ProductCategory 
    ADD IsDeleted BIT NOT NULL DEFAULT 0,
        DeletedDate DATETIME2 NULL,
        DeletedBy NVARCHAR(100) NULL;
    PRINT '✅ ProductCategory audit columns added successfully';
END TRY
BEGIN CATCH
    PRINT '⚠️  ProductCategory audit columns may already exist: ' + ERROR_MESSAGE();
END CATCH;

-- ========================================
-- STEP 2: CREATE SOFT DELETE TRIGGERS
-- ========================================

PRINT '';
PRINT '--- Step 2: Creating Soft Delete Triggers ---';
PRINT 'These triggers will intercept DELETE operations and convert them to UPDATEs...';
PRINT '';

-- Customer soft delete trigger
PRINT 'Creating trigger for SalesLT.Customer...';
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_Customer_SoftDelete')
    DROP TRIGGER SalesLT.tr_Customer_SoftDelete;

EXEC('
CREATE TRIGGER SalesLT.tr_Customer_SoftDelete
ON SalesLT.Customer
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Prevent deletion if no records to delete
    IF NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;
    
    -- Update records to mark as deleted instead of physically deleting
    UPDATE SalesLT.Customer 
    SET IsDeleted = 1,
        DeletedDate = GETDATE(),
        DeletedBy = SYSTEM_USER,
        ModifiedDate = GETDATE()
    WHERE CustomerID IN (SELECT CustomerID FROM deleted);
    
    PRINT ''Soft delete applied to '' + CAST(@@ROWCOUNT AS VARCHAR) + '' customer record(s)'';
    
    -- Log the soft delete operation
    PRINT ''Customer records marked as deleted: '' + 
          STUFF((SELECT '', '' + CAST(CustomerID AS VARCHAR) 
                 FROM deleted 
                 FOR XML PATH('''')), 1, 2, '''');
END;
');
PRINT '✅ Customer soft delete trigger created';

-- Product soft delete trigger
PRINT 'Creating trigger for SalesLT.Product...';
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_Product_SoftDelete')
    DROP TRIGGER SalesLT.tr_Product_SoftDelete;

EXEC('
CREATE TRIGGER SalesLT.tr_Product_SoftDelete
ON SalesLT.Product
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;
    
    UPDATE SalesLT.Product 
    SET IsDeleted = 1,
        DeletedDate = GETDATE(),
        DeletedBy = SYSTEM_USER,
        ModifiedDate = GETDATE()
    WHERE ProductID IN (SELECT ProductID FROM deleted);
    
    PRINT ''Soft delete applied to '' + CAST(@@ROWCOUNT AS VARCHAR) + '' product record(s)'';
    
    -- Log the soft delete operation with product names
    PRINT ''Products marked as deleted: '' + 
          STUFF((SELECT '', '' + Name + '' (ID: '' + CAST(ProductID AS VARCHAR) + '')''
                 FROM deleted 
                 FOR XML PATH('''')), 1, 2, '''');
END;
');
PRINT '✅ Product soft delete trigger created';

-- SalesOrderHeader soft delete trigger
PRINT 'Creating trigger for SalesLT.SalesOrderHeader...';
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_SalesOrderHeader_SoftDelete')
    DROP TRIGGER SalesLT.tr_SalesOrderHeader_SoftDelete;

EXEC('
CREATE TRIGGER SalesLT.tr_SalesOrderHeader_SoftDelete
ON SalesLT.SalesOrderHeader
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;
    
    UPDATE SalesLT.SalesOrderHeader 
    SET IsDeleted = 1,
        DeletedDate = GETDATE(),
        DeletedBy = SYSTEM_USER,
        ModifiedDate = GETDATE()
    WHERE SalesOrderID IN (SELECT SalesOrderID FROM deleted);
    
    PRINT ''Soft delete applied to '' + CAST(@@ROWCOUNT AS VARCHAR) + '' sales order record(s)'';
    
    PRINT ''Sales orders marked as deleted: '' + 
          STUFF((SELECT '', '' + CAST(SalesOrderID AS VARCHAR)
                 FROM deleted 
                 FOR XML PATH('''')), 1, 2, '''');
END;
');
PRINT '✅ SalesOrderHeader soft delete trigger created';

-- ProductCategory soft delete trigger
PRINT 'Creating trigger for SalesLT.ProductCategory...';
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_ProductCategory_SoftDelete')
    DROP TRIGGER SalesLT.tr_ProductCategory_SoftDelete;

EXEC('
CREATE TRIGGER SalesLT.tr_ProductCategory_SoftDelete
ON SalesLT.ProductCategory
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;
    
    UPDATE SalesLT.ProductCategory 
    SET IsDeleted = 1,
        DeletedDate = GETDATE(),
        DeletedBy = SYSTEM_USER,
        ModifiedDate = GETDATE()
    WHERE ProductCategoryID IN (SELECT ProductCategoryID FROM deleted);
    
    PRINT ''Soft delete applied to '' + CAST(@@ROWCOUNT AS VARCHAR) + '' product category record(s)'';
END;
');
PRINT '✅ ProductCategory soft delete trigger created';

-- ========================================
-- STEP 3: CREATE ACTIVE DATA VIEWS
-- ========================================

PRINT '';
PRINT '--- Step 3: Creating Active Data Views ---';
PRINT 'These views show only non-deleted records for operational use...';
PRINT '';

-- Active Customer view
PRINT 'Creating SalesLT.vw_Customer_Active...';
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_Customer_Active')
    DROP VIEW SalesLT.vw_Customer_Active;

EXEC('
CREATE VIEW SalesLT.vw_Customer_Active AS
SELECT 
    CustomerID, NameStyle, Title, FirstName, MiddleName, LastName, Suffix,
    CompanyName, SalesPerson, EmailAddress, Phone, PasswordHash, PasswordSalt,
    rowguid, ModifiedDate
FROM SalesLT.Customer 
WHERE IsDeleted = 0;
');
PRINT '✅ Active Customer view created';

-- Active Product view
PRINT 'Creating SalesLT.vw_Product_Active...';
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_Product_Active')
    DROP VIEW SalesLT.vw_Product_Active;

EXEC('
CREATE VIEW SalesLT.vw_Product_Active AS
SELECT 
    ProductID, Name, ProductNumber, Color, StandardCost, ListPrice, Size, Weight,
    ProductCategoryID, ProductModelID, SellStartDate, SellEndDate, DiscontinuedDate,
    ThumbNailPhoto, ThumbnailPhotoFileName, rowguid, ModifiedDate
FROM SalesLT.Product 
WHERE IsDeleted = 0;
');
PRINT '✅ Active Product view created';

-- Active SalesOrderHeader view
PRINT 'Creating SalesLT.vw_SalesOrderHeader_Active...';
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_SalesOrderHeader_Active')
    DROP VIEW SalesLT.vw_SalesOrderHeader_Active;

EXEC('
CREATE VIEW SalesLT.vw_SalesOrderHeader_Active AS
SELECT 
    SalesOrderID, RevisionNumber, OrderDate, DueDate, ShipDate, Status,
    OnlineOrderFlag, SalesOrderNumber, PurchaseOrderNumber, AccountNumber,
    CustomerID, ShipToAddressID, BillToAddressID, ShipMethod, CreditCardApprovalCode,
    SubTotal, TaxAmt, Freight, TotalDue, Comment, rowguid, ModifiedDate
FROM SalesLT.SalesOrderHeader 
WHERE IsDeleted = 0;
');
PRINT '✅ Active SalesOrderHeader view created';

-- ========================================
-- STEP 4: CREATE HISTORICAL ANALYSIS VIEWS
-- ========================================

PRINT '';
PRINT '--- Step 4: Creating Historical Analysis Views ---';
PRINT 'These views provide rich analytics on historical data including deleted records...';
PRINT '';

-- Customer historical analysis view
PRINT 'Creating SalesLT.vw_Customer_Historical...';
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_Customer_Historical')
    DROP VIEW SalesLT.vw_Customer_Historical;

EXEC('
CREATE VIEW SalesLT.vw_Customer_Historical AS
SELECT 
    CustomerID,
    NameStyle,
    Title,
    FirstName,
    MiddleName,
    LastName,
    CONCAT(FirstName, '' '', ISNULL(MiddleName + '' '', ''''), LastName) as FullName,
    Suffix,
    CompanyName,
    SalesPerson,
    EmailAddress,
    Phone,
    rowguid,
    ModifiedDate,
    IsDeleted,
    DeletedDate,
    DeletedBy,
    CASE 
        WHEN IsDeleted = 1 THEN ''DELETED''
        ELSE ''ACTIVE''
    END AS RecordStatus,
    CASE 
        WHEN IsDeleted = 1 THEN DATEDIFF(DAY, ModifiedDate, DeletedDate)
        ELSE NULL
    END AS DaysActiveBeforeDeletion,
    CASE
        WHEN IsDeleted = 1 THEN DATEDIFF(DAY, DeletedDate, GETDATE())
        ELSE NULL
    END AS DaysSinceDeletion
FROM SalesLT.Customer;
');
PRINT '✅ Customer historical analysis view created';

-- Product historical analysis view
PRINT 'Creating SalesLT.vw_Product_Historical...';
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_Product_Historical')
    DROP VIEW SalesLT.vw_Product_Historical;

EXEC('
CREATE VIEW SalesLT.vw_Product_Historical AS
SELECT 
    ProductID,
    Name,
    ProductNumber,
    Color,
    StandardCost,
    ListPrice,
    Size,
    Weight,
    ProductCategoryID,
    ProductModelID,
    SellStartDate,
    SellEndDate,
    DiscontinuedDate,
    rowguid,
    ModifiedDate,
    IsDeleted,
    DeletedDate,
    DeletedBy,
    CASE 
        WHEN IsDeleted = 1 THEN ''DELETED''
        WHEN SellEndDate IS NOT NULL THEN ''DISCONTINUED''
        WHEN DiscontinuedDate IS NOT NULL THEN ''DISCONTINUED''
        ELSE ''ACTIVE''
    END AS RecordStatus,
    CASE 
        WHEN IsDeleted = 1 AND SellEndDate IS NOT NULL THEN 
            DATEDIFF(DAY, SellStartDate, SellEndDate)
        WHEN IsDeleted = 1 AND SellEndDate IS NULL THEN 
            DATEDIFF(DAY, SellStartDate, DeletedDate)
        WHEN SellEndDate IS NOT NULL THEN
            DATEDIFF(DAY, SellStartDate, SellEndDate)
        ELSE 
            DATEDIFF(DAY, SellStartDate, GETDATE())
    END AS ProductLifespanDays,
    CASE
        WHEN StandardCost > 0 THEN ROUND(((ListPrice - StandardCost) / StandardCost) * 100, 2)
        ELSE 0
    END AS ProfitMarginPercent
FROM SalesLT.Product;
');
PRINT '✅ Product historical analysis view created';

-- Sales Order historical analysis view
PRINT 'Creating SalesLT.vw_SalesOrderHeader_Historical...';
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_SalesOrderHeader_Historical')
    DROP VIEW SalesLT.vw_SalesOrderHeader_Historical;

EXEC('
CREATE VIEW SalesLT.vw_SalesOrderHeader_Historical AS
SELECT 
    SalesOrderID,
    RevisionNumber,
    OrderDate,
    DueDate,
    ShipDate,
    Status,
    OnlineOrderFlag,
    SalesOrderNumber,
    PurchaseOrderNumber,
    AccountNumber,
    CustomerID,
    ShipToAddressID,
    BillToAddressID,
    ShipMethod,
    CreditCardApprovalCode,
    SubTotal,
    TaxAmt,
    Freight,
    TotalDue,
    Comment,
    rowguid,
    ModifiedDate,
    IsDeleted,
    DeletedDate,
    DeletedBy,
    CASE 
        WHEN IsDeleted = 1 THEN ''DELETED''
        WHEN Status = 1 THEN ''IN_PROCESS''
        WHEN Status = 2 THEN ''APPROVED''
        WHEN Status = 3 THEN ''BACKORDERED''
        WHEN Status = 4 THEN ''REJECTED''
        WHEN Status = 5 THEN ''SHIPPED''
        WHEN Status = 6 THEN ''CANCELLED''
        ELSE ''UNKNOWN''
    END AS RecordStatus,
    CASE
        WHEN ShipDate IS NOT NULL THEN DATEDIFF(DAY, OrderDate, ShipDate)
        ELSE DATEDIFF(DAY, OrderDate, GETDATE())
    END AS DaysToShip
FROM SalesLT.SalesOrderHeader;
');
PRINT '✅ SalesOrderHeader historical analysis view created';

-- ========================================
-- STEP 5: CREATE DATA QUALITY MONITORING VIEWS
-- ========================================

PRINT '';
PRINT '--- Step 5: Creating Data Quality Monitoring Views ---';

-- Soft delete summary view
PRINT 'Creating SalesLT.vw_SoftDelete_Summary...';
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_SoftDelete_Summary')
    DROP VIEW SalesLT.vw_SoftDelete_Summary;

EXEC('
CREATE VIEW SalesLT.vw_SoftDelete_Summary AS
SELECT 
    ''Customer'' as TableName,
    COUNT(*) as TotalRecords,
    SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END) as DeletedRecords,
    SUM(CASE WHEN IsDeleted = 0 THEN 1 ELSE 0 END) as ActiveRecords,
    CASE WHEN COUNT(*) > 0 THEN 
        ROUND((SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) 
        ELSE 0 
    END as DeletionPercentage
FROM SalesLT.Customer

UNION ALL

SELECT 
    ''Product'',
    COUNT(*),
    SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN IsDeleted = 0 THEN 1 ELSE 0 END),
    CASE WHEN COUNT(*) > 0 THEN 
        ROUND((SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) 
        ELSE 0 
    END
FROM SalesLT.Product

UNION ALL

SELECT 
    ''SalesOrderHeader'',
    COUNT(*),
    SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN IsDeleted = 0 THEN 1 ELSE 0 END),
    CASE WHEN COUNT(*) > 0 THEN 
        ROUND((SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) 
        ELSE 0 
    END
FROM SalesLT.SalesOrderHeader

UNION ALL

SELECT 
    ''ProductCategory'',
    COUNT(*),
    SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN IsDeleted = 0 THEN 1 ELSE 0 END),
    CASE WHEN COUNT(*) > 0 THEN 
        ROUND((SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) 
        ELSE 0 
    END
FROM SalesLT.ProductCategory;
');
PRINT '✅ Soft delete summary view created';

-- ========================================
-- STEP 6: TEST SOFT DELETE FUNCTIONALITY
-- ========================================

PRINT '';
PRINT '--- Step 6: Testing Soft Delete Functionality ---';

-- Insert a test customer for deletion demo
PRINT 'Creating test customer for soft delete demonstration...';
INSERT INTO SalesLT.Customer (
    NameStyle, FirstName, LastName, EmailAddress, 
    PasswordHash, PasswordSalt, ModifiedDate
)
VALUES (
    0, 'SoftDelete', 'TestUser', 'softdelete.test@fabricdemo.com',
    'YPdtRdvqeAhj6wyxEsFdQnRsxlJwzHWWwA==', -- Sample hash
    'K3X8iQ==', -- Sample salt
    GETDATE()
);

DECLARE @TestCustomerID INT = SCOPE_IDENTITY();
PRINT 'Test customer created with ID: ' + CAST(@TestCustomerID AS VARCHAR);

-- Show customer before deletion
PRINT 'Customer before soft delete:';
SELECT CustomerID, FirstName, LastName, IsDeleted, DeletedDate 
FROM SalesLT.Customer 
WHERE CustomerID = @TestCustomerID;

-- Perform soft delete
PRINT 'Executing DELETE command (will be intercepted by trigger)...';
DELETE FROM SalesLT.Customer WHERE CustomerID = @TestCustomerID;

-- Show customer after soft delete
PRINT 'Customer after soft delete:';
SELECT CustomerID, FirstName, LastName, IsDeleted, DeletedDate, DeletedBy 
FROM SalesLT.Customer 
WHERE CustomerID = @TestCustomerID;

-- Verify the record still exists but is marked as deleted
IF EXISTS (SELECT 1 FROM SalesLT.Customer WHERE CustomerID = @TestCustomerID AND IsDeleted = 1)
    PRINT '✅ Soft delete test successful - record marked as deleted but preserved';
ELSE
    PRINT '❌ Soft delete test failed - review trigger implementation';

-- ========================================
-- STEP 7: VERIFICATION AND SUMMARY
-- ========================================

PRINT '';
PRINT '--- Step 7: Final Verification ---';

-- List all triggers created
PRINT 'Soft delete triggers created:';
SELECT 
    t.name as TriggerName,
    OBJECT_NAME(t.parent_id) as TableName,
    t.create_date,
    t.modify_date
FROM sys.triggers t
WHERE t.name LIKE 'tr_%_SoftDelete'
ORDER BY OBJECT_NAME(t.parent_id);

-- List all views created
PRINT '';
PRINT 'Analysis views created:';
SELECT 
    v.name as ViewName,
    v.create_date,
    v.modify_date
FROM sys.views v
WHERE v.name LIKE 'vw_%'
ORDER BY v.name;

-- Show soft delete summary
PRINT '';
PRINT 'Current soft delete status:';
SELECT * FROM SalesLT.vw_SoftDelete_Summary;

PRINT '';
PRINT '=== SOFT DELETE SETUP COMPLETED SUCCESSFULLY ===';
PRINT '';
PRINT 'What was implemented:';
PRINT '✅ Audit columns added to main tables (IsDeleted, DeletedDate, DeletedBy)';
PRINT '✅ INSTEAD OF DELETE triggers created for soft delete functionality';
PRINT '✅ Active data views created (exclude deleted records)';
PRINT '✅ Historical analysis views created (include deleted records with analytics)';
PRINT '✅ Data quality monitoring views created';
PRINT '✅ Soft delete functionality tested and verified';
PRINT '';
PRINT 'Benefits for Fabric Analytics:';
PRINT '📊 Complete historical data preservation';
PRINT '📈 Advanced analytics on deletion patterns';
PRINT '🔄 Data lineage and audit trail maintenance';
PRINT '📋 Data quality monitoring and reporting';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Configure mirroring in Microsoft Fabric';
PRINT '2. All DELETE operations will now be preserved as UPDATEs in Fabric';
PRINT '3. Use historical views in Fabric for advanced analytics';
PRINT '4. Run demo CRUD operations to test end-to-end functionality';
PRINT '';
PRINT '📁 Repository: https://github.com/stuba83/fabric-mirroring-demo';
PRINT '📧 Questions? Create an issue: https://github.com/stuba83/fabric-mirroring-demo/issues';