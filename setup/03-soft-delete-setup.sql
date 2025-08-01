-- ========================================
-- Microsoft Fabric Mirroring Demo - CLEAN VERSION
-- File: 03-soft-delete-setup-clean.sql
-- Purpose: Implement soft delete strategy for historical data preservation
-- ========================================

PRINT '=== SOFT DELETE SETUP FOR FABRIC MIRRORING (CLEAN VERSION) ===';
PRINT 'Execution Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT 'Database: ' + DB_NAME();
PRINT '';

-- ========================================
-- STEP 1: ADD AUDIT COLUMNS TO MAIN TABLES
-- ========================================

PRINT '--- Step 1: Adding Audit Columns ---';
PRINT '';

-- Customer table audit columns
PRINT 'Adding audit columns to SalesLT.Customer...';
BEGIN TRY
    -- Add IsDeleted column
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.Customer') AND name = 'IsDeleted')
    BEGIN
        ALTER TABLE SalesLT.Customer ADD IsDeleted BIT NOT NULL DEFAULT 0;
        PRINT '  ✅ IsDeleted column added';
    END
    ELSE
        PRINT '  ⚠️  IsDeleted column already exists';

    -- Add DeletedDate column
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.Customer') AND name = 'DeletedDate')
    BEGIN
        ALTER TABLE SalesLT.Customer ADD DeletedDate DATETIME2 NULL;
        PRINT '  ✅ DeletedDate column added';
    END
    ELSE
        PRINT '  ⚠️  DeletedDate column already exists';

    -- Add DeletedBy column
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.Customer') AND name = 'DeletedBy')
    BEGIN
        ALTER TABLE SalesLT.Customer ADD DeletedBy NVARCHAR(100) NULL;
        PRINT '  ✅ DeletedBy column added';
    END
    ELSE
        PRINT '  ⚠️  DeletedBy column already exists';

    PRINT '✅ Customer audit columns completed successfully';
END TRY
BEGIN CATCH
    PRINT '❌ Customer audit columns failed: ' + ERROR_MESSAGE();
    RETURN; -- Stop execution on error
END CATCH;

PRINT '';

-- Product table audit columns
PRINT 'Adding audit columns to SalesLT.Product...';
BEGIN TRY
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.Product') AND name = 'IsDeleted')
    BEGIN
        ALTER TABLE SalesLT.Product ADD IsDeleted BIT NOT NULL DEFAULT 0;
        PRINT '  ✅ IsDeleted column added';
    END
    ELSE
        PRINT '  ⚠️  IsDeleted column already exists';

    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.Product') AND name = 'DeletedDate')
    BEGIN
        ALTER TABLE SalesLT.Product ADD DeletedDate DATETIME2 NULL;
        PRINT '  ✅ DeletedDate column added';
    END
    ELSE
        PRINT '  ⚠️  DeletedDate column already exists';

    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.Product') AND name = 'DeletedBy')
    BEGIN
        ALTER TABLE SalesLT.Product ADD DeletedBy NVARCHAR(100) NULL;
        PRINT '  ✅ DeletedBy column added';
    END
    ELSE
        PRINT '  ⚠️  DeletedBy column already exists';

    PRINT '✅ Product audit columns completed successfully';
END TRY
BEGIN CATCH
    PRINT '❌ Product audit columns failed: ' + ERROR_MESSAGE();
    RETURN;
END CATCH;

PRINT '';

-- SalesOrderHeader table audit columns
PRINT 'Adding audit columns to SalesLT.SalesOrderHeader...';
BEGIN TRY
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.SalesOrderHeader') AND name = 'IsDeleted')
    BEGIN
        ALTER TABLE SalesLT.SalesOrderHeader ADD IsDeleted BIT NOT NULL DEFAULT 0;
        PRINT '  ✅ IsDeleted column added';
    END
    ELSE
        PRINT '  ⚠️  IsDeleted column already exists';

    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.SalesOrderHeader') AND name = 'DeletedDate')
    BEGIN
        ALTER TABLE SalesLT.SalesOrderHeader ADD DeletedDate DATETIME2 NULL;
        PRINT '  ✅ DeletedDate column added';
    END
    ELSE
        PRINT '  ⚠️  DeletedDate column already exists';

    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.SalesOrderHeader') AND name = 'DeletedBy')
    BEGIN
        ALTER TABLE SalesLT.SalesOrderHeader ADD DeletedBy NVARCHAR(100) NULL;
        PRINT '  ✅ DeletedBy column added';
    END
    ELSE
        PRINT '  ⚠️  DeletedBy column already exists';

    PRINT '✅ SalesOrderHeader audit columns completed successfully';
END TRY
BEGIN CATCH
    PRINT '❌ SalesOrderHeader audit columns failed: ' + ERROR_MESSAGE();
    RETURN;
END CATCH;

PRINT '';

-- ProductCategory table audit columns
PRINT 'Adding audit columns to SalesLT.ProductCategory...';
BEGIN TRY
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.ProductCategory') AND name = 'IsDeleted')
    BEGIN
        ALTER TABLE SalesLT.ProductCategory ADD IsDeleted BIT NOT NULL DEFAULT 0;
        PRINT '  ✅ IsDeleted column added';
    END
    ELSE
        PRINT '  ⚠️  IsDeleted column already exists';

    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.ProductCategory') AND name = 'DeletedDate')
    BEGIN
        ALTER TABLE SalesLT.ProductCategory ADD DeletedDate DATETIME2 NULL;
        PRINT '  ✅ DeletedDate column added';
    END
    ELSE
        PRINT '  ⚠️  DeletedDate column already exists';

    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SalesLT.ProductCategory') AND name = 'DeletedBy')
    BEGIN
        ALTER TABLE SalesLT.ProductCategory ADD DeletedBy NVARCHAR(100) NULL;
        PRINT '  ✅ DeletedBy column added';
    END
    ELSE
        PRINT '  ⚠️  DeletedBy column already exists';

    PRINT '✅ ProductCategory audit columns completed successfully';
END TRY
BEGIN CATCH
    PRINT '❌ ProductCategory audit columns failed: ' + ERROR_MESSAGE();
    RETURN;
END CATCH;

-- ========================================
-- STEP 2: CREATE SOFT DELETE TRIGGERS
-- ========================================

PRINT '';
PRINT '--- Step 2: Creating Soft Delete Triggers ---';
PRINT '';

-- Customer soft delete trigger
PRINT 'Creating trigger for SalesLT.Customer...';
BEGIN TRY
    IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_Customer_SoftDelete')
        DROP TRIGGER SalesLT.tr_Customer_SoftDelete;

    EXEC('
    CREATE TRIGGER SalesLT.tr_Customer_SoftDelete
    ON SalesLT.Customer
    INSTEAD OF DELETE
    AS
    BEGIN
        SET NOCOUNT ON;
        
        IF NOT EXISTS (SELECT 1 FROM deleted)
            RETURN;
        
        UPDATE SalesLT.Customer 
        SET IsDeleted = 1,
            DeletedDate = GETDATE(),
            DeletedBy = SYSTEM_USER,
            ModifiedDate = GETDATE()
        WHERE CustomerID IN (SELECT CustomerID FROM deleted);
        
        PRINT ''Soft delete applied to '' + CAST(@@ROWCOUNT AS VARCHAR) + '' customer record(s)'';
    END;
    ');
    PRINT '✅ Customer soft delete trigger created';
END TRY
BEGIN CATCH
    PRINT '❌ Customer trigger failed: ' + ERROR_MESSAGE();
END CATCH;

PRINT '';

-- Product soft delete trigger
PRINT 'Creating trigger for SalesLT.Product...';
BEGIN TRY
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
    END;
    ');
    PRINT '✅ Product soft delete trigger created';
END TRY
BEGIN CATCH
    PRINT '❌ Product trigger failed: ' + ERROR_MESSAGE();
END CATCH;

PRINT '';

-- SalesOrderHeader soft delete trigger
PRINT 'Creating trigger for SalesLT.SalesOrderHeader...';
BEGIN TRY
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
    END;
    ');
    PRINT '✅ SalesOrderHeader soft delete trigger created';
END TRY
BEGIN CATCH
    PRINT '❌ SalesOrderHeader trigger failed: ' + ERROR_MESSAGE();
END CATCH;

PRINT '';

-- ProductCategory soft delete trigger
PRINT 'Creating trigger for SalesLT.ProductCategory...';
BEGIN TRY
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
END TRY
BEGIN CATCH
    PRINT '❌ ProductCategory trigger failed: ' + ERROR_MESSAGE();
END CATCH;

-- ========================================
-- STEP 3: CREATE ACTIVE DATA VIEWS
-- ========================================

PRINT '';
PRINT '--- Step 3: Creating Active Data Views ---';
PRINT '';

-- Active Customer view
PRINT 'Creating SalesLT.vw_Customer_Active...';
BEGIN TRY
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
END TRY
BEGIN CATCH
    PRINT '❌ Customer view failed: ' + ERROR_MESSAGE();
END CATCH;

-- Active Product view
PRINT 'Creating SalesLT.vw_Product_Active...';
BEGIN TRY
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
END TRY
BEGIN CATCH
    PRINT '❌ Product view failed: ' + ERROR_MESSAGE();
END CATCH;

-- Active SalesOrderHeader view
PRINT 'Creating SalesLT.vw_SalesOrderHeader_Active...';
BEGIN TRY
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
END TRY
BEGIN CATCH
    PRINT '❌ SalesOrderHeader view failed: ' + ERROR_MESSAGE();
END CATCH;

-- ========================================
-- STEP 4: QUICK TEST
-- ========================================

PRINT '';
PRINT '--- Step 4: Quick Functionality Test ---';
PRINT '';

BEGIN TRY
    -- Create a test customer
    PRINT 'Creating test customer...';
    INSERT INTO SalesLT.Customer (
        NameStyle, FirstName, LastName, EmailAddress, 
        PasswordHash, PasswordSalt, ModifiedDate
    )
    VALUES (
        0, 'Test', 'SoftDelete', 'test@example.com',
        'YPdtRdvqeAhj6wyxEsFdQnRsxlJwzHWWwA==',
        'K3X8iQ==',
        GETDATE()
    );

    DECLARE @TestID INT = SCOPE_IDENTITY();
    PRINT 'Test customer created with ID: ' + CAST(@TestID AS VARCHAR);

    -- Test soft delete
    PRINT 'Testing soft delete...';
    DELETE FROM SalesLT.Customer WHERE CustomerID = @TestID;

    -- Verify result
    DECLARE @IsDeleted BIT = 0;
    SELECT @IsDeleted = IsDeleted FROM SalesLT.Customer WHERE CustomerID = @TestID;
    
    IF @IsDeleted = 1
        PRINT '✅ Soft delete test PASSED - record marked as deleted';
    ELSE
        PRINT '❌ Soft delete test FAILED - check triggers';

END TRY
BEGIN CATCH
    PRINT '❌ Test failed: ' + ERROR_MESSAGE();
END CATCH;

PRINT '';
PRINT '=== SETUP COMPLETED ===';
PRINT 'Soft delete functionality has been implemented successfully!';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Configure Microsoft Fabric mirroring';
PRINT '2. All DELETE operations will now be preserved as UPDATEs';
PRINT '3. Use the active views for operational queries';
PRINT '4. Historical data is preserved for analytics';