# Microsoft Fabric Mirroring Demo Guide
## Azure SQL Database to Microsoft Fabric OneLake

**Author:** [stuba83](https://github.com/stuba83)  
**Repository:** [github.com/stuba83/Microsoft-Fabric-Mirroring-Demo-Guide](https://github.com/stuba83/Microsoft-Fabric-Mirroring-Demo-Guide)  
**Last Updated:** August 2025

### 📋 Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Phase 1: Azure SQL Database Setup](#phase-1-azure-sql-database-setup)
- [Phase 2: Microsoft Fabric Workspace Setup](#phase-2-microsoft-fabric-workspace-setup)
- [Phase 3: Configure Mirroring](#phase-3-configure-mirroring)
- [Phase 4: Understanding Mirroring Limitations](#phase-4-understanding-mirroring-limitations)
- [Phase 5: Resolving UDT Issues](#phase-5-resolving-udt-issues)
- [Phase 6: Implementing Soft Delete Strategy](#phase-6-implementing-soft-delete-strategy)
- [Phase 7: CRUD Operations Demo](#phase-7-crud-operations-demo)
- [Phase 8: Advanced Analytics Scenarios](#phase-8-advanced-analytics-scenarios)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Resources](#resources)

---

## Overview

This guide demonstrates the complete setup and configuration of **Microsoft Fabric Mirroring** from Azure SQL Database to Fabric OneLake. You'll learn how to:

- Set up Azure SQL Database with AdventureWorks sample data
- Configure real-time mirroring to Microsoft Fabric
- Handle data type limitations and compatibility issues
- Implement soft delete strategies for historical data preservation
- Demonstrate CRUD operations with real-time replication
- Leverage advanced analytics capabilities in Fabric

**🎯 Demo Duration:** ~2-3 hours  
**💰 Estimated Cost:** ~$20-50 for demo period  
**🔧 Skill Level:** Intermediate  

---

## Prerequisites

### Required Access & Subscriptions
- [ ] **Azure Subscription** with Contributor permissions
- [ ] **Microsoft Fabric** tenant with Admin/Member workspace role
- [ ] **Fabric Capacity** (F64 or higher recommended for demos)

### Required Tools
- [ ] **Azure Portal** access
- [ ] **SQL Server Management Studio (SSMS)** or **Azure Data Studio**
- [ ] **Web browser** for Fabric Portal access

### Knowledge Prerequisites
- Basic SQL Server/Azure SQL Database knowledge
- Understanding of data warehousing concepts
- Familiarity with Microsoft Fabric workspace navigation

---

## Phase 1: Azure SQL Database Setup

### Step 1.1: Create Azure SQL Database (Serverless)

```bash
# Azure CLI commands for automated setup
az group create --name rg-fabric-mirroring-demo --location eastus

az sql server create \
  --name sql-fabric-demo-$(date +%s) \
  --resource-group rg-fabric-mirroring-demo \
  --location eastus \
  --admin-user sqladmin \
  --admin-password 'P@ssw0rd123!'

az sql db create \
  --resource-group rg-fabric-mirroring-demo \
  --server sql-fabric-demo-$(date +%s) \
  --name AdventureWorksLT \
  --sample-name AdventureWorksLT \
  --compute-model Serverless \
  --edition GeneralPurpose \
  --family Gen5 \
  --capacity 1
```

### Step 1.2: Manual Setup via Azure Portal

1. **Navigate to Azure Portal** → Create a resource → SQL Database
2. **Basic Configuration:**
   - **Subscription:** Your subscription
   - **Resource Group:** Create new `rg-fabric-mirroring-demo`
   - **Database Name:** `AdventureWorksLT`
   - **Server:** Create new server
     - **Server name:** `sql-fabric-demo-[unique-suffix]`
     - **Location:** East US (or your preferred region)
     - **Authentication:** SQL Authentication
     - **Admin login:** `sqladmin`
     - **Password:** `P@ssw0rd123!`

3. **Compute + Storage:**
   - **Service tier:** General Purpose
   - **Compute tier:** Serverless
   - **Hardware configuration:** Standard-series (Gen5)
   - **Min vCores:** 0.5
   - **Max vCores:** 1
   - **Auto-pause delay:** 60 minutes

4. **Additional Settings:**
   - **Use existing data:** Sample
   - **Sample:** AdventureWorksLT

5. **Networking:**
   - **Allow Azure services:** Yes
   - **Add current client IP:** Yes

### Step 1.3: Enable System Assigned Managed Identity

```sql
-- Connect to your Azure SQL Database and run:
-- This is automatically handled during Fabric Mirroring setup
-- but verify it's enabled in Azure Portal > SQL Server > Identity
```

**Via Azure Portal:**
1. Go to your SQL Server → **Identity**
2. **System assigned** → Status: **On**
3. Click **Save**

### Step 1.4: Verify Sample Data

```sql
-- Connect via SSMS or Azure Data Studio and verify data
SELECT COUNT(*) as TableCount 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'SalesLT';

-- Should return 13 tables
SELECT TOP 5 * FROM SalesLT.Customer;
SELECT TOP 5 * FROM SalesLT.Product;
SELECT TOP 5 * FROM SalesLT.SalesOrderHeader;
```

---

## Phase 2: Microsoft Fabric Workspace Setup

### Step 2.1: Access Fabric Portal

1. Navigate to [Microsoft Fabric Portal](https://fabric.microsoft.com)
2. Sign in with your organizational account
3. Ensure you have **Fabric capacity** assigned

### Step 2.2: Create Fabric Workspace

1. **Create Workspace:**
   - **Name:** `Fabric-Mirroring-Demo`
   - **Description:** `Demo workspace for Azure SQL Database mirroring`
   - **Advanced:** Assign to your Fabric capacity

2. **Verify Workspace Settings:**
   - Navigate to **Workspace settings**
   - Ensure **Mirroring** is enabled
   - Verify **Data Engineering** and **Data Warehouse** workloads are available

### Step 2.3: Configure Tenant Settings (Admin Required)

Required tenant settings in Fabric Admin Portal:
- [ ] **Users can create Fabric items** → Enabled
- [ ] **Users can create and use Mirrored Databases** → Enabled
- [ ] **Users can create Fabric capacities** → Enabled (if managing your own capacity)

---

## Phase 3: Configure Mirroring

### Step 3.1: Create Mirrored Database

1. **In Fabric Workspace** → **+ New item** → **Mirrored Database**
2. **Select Azure SQL Database**
3. **Connection Details:**
   - **Server:** `sql-fabric-demo-[your-suffix].database.windows.net`
   - **Database:** `AdventureWorksLT`
   - **Authentication:** SQL Authentication
   - **Username:** `sqladmin`
   - **Password:** `P@ssw0rd123!`

### Step 3.2: Initial Mirroring Attempt (Expected Errors)

1. **Select tables** → **Mirror all data** (initially)
2. **Click Connect**
3. **Expected Result:** Multiple table errors due to UDT limitations

**Expected Error Messages:**
```
This table contains unsupported columns: 
- Customer: NameStyle(bit<UDT>), FirstName(nvarchar<UDT>), MiddleName(nvarchar<UDT>), LastName(nvarchar<UDT>), Phone(nvarchar<UDT>)
- Product: Name(nvarchar<UDT>)
- ProductCategory: Name(nvarchar<UDT>)
- ProductModel: CatalogDescription(xml), Name(nvarchar<UDT>)
- SalesOrderHeader: TotalDue(money<Computed>), SalesOrderNumber(nvarchar<Computed>), OnlineOrderFlag(bit<UDT>), PurchaseOrderNumber(nvarchar<UDT>), AccountNumber(nvarchar<UDT>)
```

### Step 3.3: Document the Limitations

This is perfect for demonstrating real-world mirroring challenges!

---

## Phase 4: Understanding Mirroring Limitations

### 4.1 Unsupported Data Types

| Data Type | Issue | Impact | Solution |
|-----------|--------|--------|----------|
| **User Defined Types (UDT)** | Custom data types not recognized | Columns won't replicate | Convert to standard types |
| **XML** | Complex XML data type | Columns won't replicate | Convert to NVARCHAR(MAX) or exclude |
| **Computed Columns** | Server-side calculations | Columns won't replicate | Convert to regular columns or exclude |
| **Geography/Geometry** | Spatial data types | Columns won't replicate | Convert to WKT string format |
| **Large Binary Objects >1MB** | Size limitations | Data truncated to 1MB | Implement file storage strategy |

### 4.2 Table-Level Limitations

**Unsupported Table Features:**
- Temporal tables
- Memory-optimized tables
- Graph tables
- External tables
- Tables without primary keys (prior to April 2025)

### 4.3 Database-Level Limitations

- **Maximum 500 tables** per mirrored database
- **No CDC enabled** databases
- **No Azure Synapse Link** enabled databases
- **Single mirroring instance** per database

---

## Phase 5: Resolving UDT Issues

### Step 5.1: Fix SalesLT.Customer Table

```sql
-- Connect to Azure SQL Database via SSMS
-- Fix UDT issues in Customer table

-- Step 1: Remove DEFAULT constraint (if exists)
ALTER TABLE SalesLT.Customer 
DROP CONSTRAINT DF_Customer_NameStyle;

-- Step 2: Convert UDT columns to standard types
ALTER TABLE SalesLT.Customer 
ALTER COLUMN NameStyle BIT NOT NULL;

ALTER TABLE SalesLT.Customer 
ALTER COLUMN FirstName NVARCHAR(50) NOT NULL;

ALTER TABLE SalesLT.Customer 
ALTER COLUMN MiddleName NVARCHAR(50);

ALTER TABLE SalesLT.Customer 
ALTER COLUMN LastName NVARCHAR(50) NOT NULL;

ALTER TABLE SalesLT.Customer 
ALTER COLUMN Phone NVARCHAR(25);

-- Step 3: Recreate DEFAULT constraint
ALTER TABLE SalesLT.Customer 
ADD CONSTRAINT DF_Customer_NameStyle DEFAULT (0) FOR NameStyle;
```

### Step 5.2: Fix SalesLT.Product Table

```sql
-- Fix Product table UDT issue
ALTER TABLE SalesLT.Product 
ALTER COLUMN Name NVARCHAR(50) NOT NULL;
```

### Step 5.3: Fix SalesLT.ProductCategory Table

```sql
-- Fix ProductCategory table UDT issue
ALTER TABLE SalesLT.ProductCategory 
ALTER COLUMN Name NVARCHAR(50) NOT NULL;
```

### Step 5.4: Fix SalesLT.ProductModel Table

```sql
-- Fix ProductModel table UDT issue (Name only)
ALTER TABLE SalesLT.ProductModel 
ALTER COLUMN Name NVARCHAR(50) NOT NULL;

-- Note: CatalogDescription(xml) will remain unsupported
-- This column simply won't replicate to Fabric
```

### Step 5.5: Fix SalesLT.CustomerAddress Table

```sql
-- Fix CustomerAddress table UDT issue
ALTER TABLE SalesLT.CustomerAddress 
ALTER COLUMN AddressType NVARCHAR(50) NOT NULL;
```

### Step 5.6: Fix SalesLT.SalesOrderHeader Table

```sql
-- Check for DEFAULT constraints first
SELECT 
    dc.name AS ConstraintName,
    c.name AS ColumnName
FROM sys.default_constraints dc
JOIN sys.columns c ON dc.parent_object_id = c.object_id 
WHERE c.object_id = OBJECT_ID('SalesLT.SalesOrderHeader')
AND c.name IN ('OnlineOrderFlag', 'PurchaseOrderNumber', 'AccountNumber');

-- Remove constraint if exists (adjust name as needed)
-- ALTER TABLE SalesLT.SalesOrderHeader DROP CONSTRAINT DF_SalesOrderHeader_OnlineOrderFlag;

-- Fix UDT columns (leave computed columns as-is for demo)
ALTER TABLE SalesLT.SalesOrderHeader 
ALTER COLUMN OnlineOrderFlag BIT NOT NULL;

ALTER TABLE SalesLT.SalesOrderHeader 
ALTER COLUMN PurchaseOrderNumber NVARCHAR(25);

ALTER TABLE SalesLT.SalesOrderHeader 
ALTER COLUMN AccountNumber NVARCHAR(15);

-- Recreate constraint if needed
-- ALTER TABLE SalesLT.SalesOrderHeader 
-- ADD CONSTRAINT DF_SalesOrderHeader_OnlineOrderFlag DEFAULT (1) FOR OnlineOrderFlag;
```

### Step 5.7: Complete UDT Fix Script

```sql
-- Complete script to fix all UDT issues at once
-- Execute section by section, checking for errors

PRINT 'Starting UDT fixes for Fabric Mirroring compatibility...';

-- Customer table fixes
BEGIN TRY
    ALTER TABLE SalesLT.Customer DROP CONSTRAINT DF_Customer_NameStyle;
END TRY
BEGIN CATCH
    PRINT 'DF_Customer_NameStyle constraint not found or already removed';
END CATCH;

ALTER TABLE SalesLT.Customer ALTER COLUMN NameStyle BIT NOT NULL;
ALTER TABLE SalesLT.Customer ALTER COLUMN FirstName NVARCHAR(50) NOT NULL;
ALTER TABLE SalesLT.Customer ALTER COLUMN MiddleName NVARCHAR(50);
ALTER TABLE SalesLT.Customer ALTER COLUMN LastName NVARCHAR(50) NOT NULL;
ALTER TABLE SalesLT.Customer ALTER COLUMN Phone NVARCHAR(25);
ALTER TABLE SalesLT.Customer ADD CONSTRAINT DF_Customer_NameStyle DEFAULT (0) FOR NameStyle;

-- Product table fixes
ALTER TABLE SalesLT.Product ALTER COLUMN Name NVARCHAR(50) NOT NULL;

-- ProductCategory table fixes
ALTER TABLE SalesLT.ProductCategory ALTER COLUMN Name NVARCHAR(50) NOT NULL;

-- ProductModel table fixes
ALTER TABLE SalesLT.ProductModel ALTER COLUMN Name NVARCHAR(50) NOT NULL;

-- CustomerAddress table fixes
ALTER TABLE SalesLT.CustomerAddress ALTER COLUMN AddressType NVARCHAR(50) NOT NULL;

-- SalesOrderHeader table fixes (UDT only, leave computed columns)
ALTER TABLE SalesLT.SalesOrderHeader ALTER COLUMN OnlineOrderFlag BIT NOT NULL;
ALTER TABLE SalesLT.SalesOrderHeader ALTER COLUMN PurchaseOrderNumber NVARCHAR(25);
ALTER TABLE SalesLT.SalesOrderHeader ALTER COLUMN AccountNumber NVARCHAR(15);

PRINT 'UDT fixes completed successfully!';
```

---

## Phase 6: Implementing Soft Delete Strategy

### 6.1 Why Soft Delete for Analytics?

In analytical scenarios, you often want to preserve historical data even when records are "deleted" from operational systems. Fabric Mirroring will replicate physical deletes, but for analytics, we want to maintain a complete historical record.

### 6.2 Add Audit Columns

```sql
-- Add soft delete columns to main tables
ALTER TABLE SalesLT.Customer 
ADD IsDeleted BIT NOT NULL DEFAULT 0,
    DeletedDate DATETIME2 NULL,
    DeletedBy NVARCHAR(100) NULL;

ALTER TABLE SalesLT.Product 
ADD IsDeleted BIT NOT NULL DEFAULT 0,
    DeletedDate DATETIME2 NULL,
    DeletedBy NVARCHAR(100) NULL;

ALTER TABLE SalesLT.SalesOrderHeader 
ADD IsDeleted BIT NOT NULL DEFAULT 0,
    DeletedDate DATETIME2 NULL,
    DeletedBy NVARCHAR(100) NULL;
```

### 6.3 Create Soft Delete Triggers

```sql
-- Trigger for Customer soft delete
CREATE TRIGGER tr_Customer_SoftDelete
ON SalesLT.Customer
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE SalesLT.Customer 
    SET IsDeleted = 1,
        DeletedDate = GETDATE(),
        DeletedBy = SYSTEM_USER,
        ModifiedDate = GETDATE()
    WHERE CustomerID IN (SELECT CustomerID FROM deleted);
    
    PRINT 'Soft delete applied to ' + CAST(@@ROWCOUNT AS VARCHAR) + ' customer records';
END;

-- Trigger for Product soft delete
CREATE TRIGGER tr_Product_SoftDelete
ON SalesLT.Product
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE SalesLT.Product 
    SET IsDeleted = 1,
        DeletedDate = GETDATE(),
        DeletedBy = SYSTEM_USER,
        ModifiedDate = GETDATE()
    WHERE ProductID IN (SELECT ProductID FROM deleted);
    
    PRINT 'Soft delete applied to ' + CAST(@@ROWCOUNT AS VARCHAR) + ' product records';
END;

-- Trigger for SalesOrderHeader soft delete
CREATE TRIGGER tr_SalesOrderHeader_SoftDelete
ON SalesLT.SalesOrderHeader
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE SalesLT.SalesOrderHeader 
    SET IsDeleted = 1,
        DeletedDate = GETDATE(),
        DeletedBy = SYSTEM_USER,
        ModifiedDate = GETDATE()
    WHERE SalesOrderID IN (SELECT SalesOrderID FROM deleted);
    
    PRINT 'Soft delete applied to ' + CAST(@@ROWCOUNT AS VARCHAR) + ' sales order records';
END;
```

### 6.4 Create Active Data Views

```sql
-- Create views for "active" data (excluding soft deleted records)
CREATE VIEW SalesLT.vw_Customer_Active AS
SELECT * FROM SalesLT.Customer 
WHERE IsDeleted = 0;

CREATE VIEW SalesLT.vw_Product_Active AS
SELECT * FROM SalesLT.Product 
WHERE IsDeleted = 0;

CREATE VIEW SalesLT.vw_SalesOrderHeader_Active AS
SELECT * FROM SalesLT.SalesOrderHeader 
WHERE IsDeleted = 0;
```

### 6.5 Create Historical Analysis Views

```sql
-- Create views for historical analysis in Fabric
CREATE VIEW SalesLT.vw_Customer_Historical AS
SELECT *,
    CASE 
        WHEN IsDeleted = 1 THEN 'DELETED'
        ELSE 'ACTIVE'
    END AS RecordStatus,
    CASE 
        WHEN IsDeleted = 1 THEN DATEDIFF(DAY, ModifiedDate, DeletedDate)
        ELSE NULL
    END AS DaysActive
FROM SalesLT.Customer;

CREATE VIEW SalesLT.vw_Product_Historical AS
SELECT *,
    CASE 
        WHEN IsDeleted = 1 THEN 'DELETED'
        ELSE 'ACTIVE'
    END AS RecordStatus,
    CASE 
        WHEN IsDeleted = 1 AND SellEndDate IS NOT NULL THEN 
            DATEDIFF(DAY, SellStartDate, SellEndDate)
        WHEN IsDeleted = 1 AND SellEndDate IS NULL THEN 
            DATEDIFF(DAY, SellStartDate, DeletedDate)
        ELSE NULL
    END AS ProductLifespanDays
FROM SalesLT.Product;
```

---

## Phase 7: CRUD Operations Demo

### 7.1 Insert Demo Products

```sql
-- ========================================
-- DEMO: INSERT OPERATIONS
-- ========================================

PRINT '=== INSERTING DEMO PRODUCTS FOR MIRRORING ===';

-- Product 1: Smart Cycling Computer
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
    4,      -- Accessories
    115,    -- Cable Lock model
    GETDATE(), 
    GETDATE()
);

-- Product 2: Demo Bike
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
    1,      -- Bikes
    1,      -- Classic Vest model
    GETDATE(), 
    GETDATE()
);

-- Product 3: Smart Water Bottle
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
    32,     -- Bottles and Cages
    119,    -- Bike Wash model
    GETDATE(), 
    GETDATE()
);

-- Verify insertions
SELECT ProductID, Name, ProductNumber, Color, ListPrice, ModifiedDate
FROM SalesLT.Product 
WHERE ProductNumber IN ('SCP-2025-BK', 'FDB-ELITE-RD', 'HSB-750-BL')
ORDER BY ProductID;

PRINT 'Demo products inserted! Check Fabric for replication...';
```

### 7.2 Update Demo Operations

```sql
-- ========================================
-- DEMO: UPDATE OPERATIONS  
-- ========================================

PRINT '=== DEMONSTRATING UPDATE REPLICATION ===';

-- Get Product IDs
DECLARE @SmartComputerID INT, @DemoBikeID INT, @SmartBottleID INT;

SELECT @SmartComputerID = ProductID FROM SalesLT.Product WHERE ProductNumber = 'SCP-2025-BK';
SELECT @DemoBikeID = ProductID FROM SalesLT.Product WHERE ProductNumber = 'FDB-ELITE-RD';
SELECT @SmartBottleID = ProductID FROM SalesLT.Product WHERE ProductNumber = 'HSB-750-BL';

-- Update 1: Price change (special offer)
PRINT 'Applying 25% discount to Smart Cycling Computer...';
UPDATE SalesLT.Product 
SET ListPrice = 149.99,  -- Was $199.99
    ModifiedDate = GETDATE()
WHERE ProductID = @SmartComputerID;

WAITFOR DELAY '00:00:05'; -- Wait 5 seconds for replication demo

-- Update 2: Product variant (color and size change)
PRINT 'Creating Blue XL variant of Demo Bike...';
UPDATE SalesLT.Product 
SET Color = 'Blue',
    Size = 'XL',
    Name = 'Fabric Demo Bike Elite Edition - Blue XL',
    ProductNumber = 'FDB-ELITE-BL-XL',
    ModifiedDate = GETDATE()
WHERE ProductID = @DemoBikeID;

WAITFOR DELAY '00:00:05';

-- Update 3: Specification improvements
PRINT 'Upgrading Smart Bottle to insulated version...';
UPDATE SalesLT.Product 
SET StandardCost = 15.50,
    ListPrice = 39.99,     
    Weight = 0.6,          
    Name = 'Hydro-Smart Water Bottle 750ml - Insulated',
    ModifiedDate = GETDATE()
WHERE ProductID = @SmartBottleID;

-- Show final state
SELECT 
    ProductID,
    Name,
    ProductNumber,
    Color,
    Size,
    CAST(ListPrice AS DECIMAL(10,2)) AS ListPrice,
    ModifiedDate
FROM SalesLT.Product 
WHERE ProductID IN (@SmartComputerID, @DemoBikeID, @SmartBottleID)
ORDER BY ProductID;

PRINT 'Updates complete! Verify changes replicated to Fabric...';
```

### 7.3 Soft Delete Demo

```sql
-- ========================================
-- DEMO: SOFT DELETE OPERATIONS
-- ========================================

PRINT '=== DEMONSTRATING SOFT DELETE REPLICATION ===';

-- Get a demo product ID
DECLARE @DeleteDemoID INT;
SELECT @DeleteDemoID = ProductID FROM SalesLT.Product WHERE ProductNumber = 'SCP-2025-BK';

-- Show product before deletion
PRINT 'Product before soft delete:';
SELECT ProductID, Name, IsDeleted, DeletedDate FROM SalesLT.Product 
WHERE ProductID = @DeleteDemoID;

-- Execute soft delete (will be converted to UPDATE by trigger)
PRINT 'Executing DELETE command (will become soft delete)...';
DELETE FROM SalesLT.Product WHERE ProductID = @DeleteDemoID;

-- Show product after soft delete
PRINT 'Product after soft delete:';
SELECT ProductID, Name, IsDeleted, DeletedDate, DeletedBy FROM SalesLT.Product 
WHERE ProductID = @DeleteDemoID;

-- Demonstrate that record still exists but is flagged
PRINT 'Verify: Record still exists in table but marked as deleted';
SELECT COUNT(*) as TotalRecords, 
       SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END) as DeletedRecords
FROM SalesLT.Product 
WHERE ProductNumber LIKE 'SCP-%' OR ProductNumber LIKE 'FDB-%' OR ProductNumber LIKE 'HSB-%';

PRINT 'Soft delete demo complete! Check Fabric for the UPDATE replication...';
```

### 7.4 Fabric Verification Queries

Execute these in **Fabric SQL Analytics Endpoint**:

```sql
-- Query 1: Verify all demo products replicated
SELECT ProductID, Name, ProductNumber, Color, ListPrice, ModifiedDate
FROM Product 
WHERE ProductNumber LIKE 'SCP-%' 
   OR ProductNumber LIKE 'FDB-%' 
   OR ProductNumber LIKE 'HSB-%'
ORDER BY ModifiedDate DESC;

-- Query 2: Check soft deleted records
SELECT ProductID, Name, IsDeleted, DeletedDate, DeletedBy
FROM Product 
WHERE IsDeleted = 1 
  AND (ProductNumber LIKE 'SCP-%' 
       OR ProductNumber LIKE 'FDB-%' 
       OR ProductNumber LIKE 'HSB-%');

-- Query 3: Historical analysis
SELECT 
    COUNT(*) as TotalProducts,
    SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END) as DeletedProducts,
    SUM(CASE WHEN IsDeleted = 0 THEN 1 ELSE 0 END) as ActiveProducts
FROM Product;

-- Query 4: Price change analysis
SELECT 
    ProductID,
    Name,
    ListPrice,
    ModifiedDate,
    LAG(ListPrice) OVER (PARTITION BY ProductID ORDER BY ModifiedDate) as PreviousPrice
FROM Product 
WHERE ProductNumber LIKE 'SCP-%'
ORDER BY ModifiedDate;
```

---

## Phase 8: Advanced Analytics Scenarios

### 8.1 Create Analytics Views in Fabric

Execute these in **Fabric SQL Analytics Endpoint**:

```sql
-- Customer Analysis View
CREATE VIEW CustomerAnalytics AS
SELECT 
    c.CustomerID,
    CONCAT(c.FirstName, ' ', c.LastName) as FullName,
    c.EmailAddress,
    COUNT(soh.SalesOrderID) as TotalOrders,
    SUM(soh.SubTotal) as TotalRevenue,
    AVG(soh.SubTotal) as AverageOrderValue,
    MAX(soh.OrderDate) as LastOrderDate,
    DATEDIFF(DAY, MAX(soh.OrderDate), GETDATE()) as DaysSinceLastOrder,
    c.IsDeleted,
    c.DeletedDate
FROM Customer c
LEFT JOIN SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName, c.EmailAddress, 
         c.IsDeleted, c.DeletedDate;

-- Product Performance View
CREATE VIEW ProductPerformance AS
SELECT 
    p.ProductID,
    p.Name,
    p.ProductNumber,
    p.Color,
    p.ListPrice,
    pc.Name as CategoryName,
    COUNT(sod.ProductID) as TimesSold,
    SUM(sod.OrderQty) as TotalQuantitySold,
    SUM(sod.LineTotal) as TotalRevenue,
    AVG(sod.UnitPrice) as AverageSellingPrice,
    p.IsDeleted,
    CASE 
        WHEN p.IsDeleted = 1 THEN 'Discontinued'
        WHEN COUNT(sod.ProductID) = 0 THEN 'No Sales'
        WHEN COUNT(sod.ProductID) < 5 THEN 'Low Performer'
        WHEN COUNT(sod.ProductID) >= 20 THEN 'Top Performer'
        ELSE 'Medium Performer'
    END as PerformanceCategory
FROM Product p
LEFT JOIN ProductCategory pc ON p.ProductCategoryID = pc.ProductCategoryID
LEFT JOIN SalesOrderDetail sod ON p.ProductID = sod.ProductID
GROUP BY p.ProductID, p.Name, p.ProductNumber, p.Color, p.ListPrice, 
         pc.Name, p.IsDeleted;

-- Sales Trend Analysis
CREATE VIEW SalesTrendAnalysis AS
SELECT 
    YEAR(soh.OrderDate) as OrderYear,
    MONTH(soh.OrderDate) as OrderMonth,
    COUNT(DISTINCT soh.SalesOrderID) as TotalOrders,
    COUNT(DISTINCT soh.CustomerID) as UniqueCustomers,
    SUM(soh.SubTotal) as TotalRevenue,
    AVG(soh.SubTotal) as AverageOrderValue,
    SUM(sod.OrderQty) as TotalQuantitySold
FROM SalesOrderHeader soh
JOIN SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
WHERE soh.IsDeleted = 0  -- Only active orders
GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate);
```

### 8.2 Power BI Integration Points

**Datasets to create in Power BI:**
1. **Customer 360 Dashboard**
   - Source: `CustomerAnalytics` view
   - Metrics: Customer lifetime value, churn analysis, segmentation

2. **Product Performance Dashboard**
   - Source: `ProductPerformance` view  
   - Metrics: Top/bottom performers, category analysis, pricing optimization

3. **Sales Operations Dashboard**
   - Source: `SalesTrendAnalysis` view
   - Metrics: Monthly trends, seasonal patterns, growth analysis

4. **Data Quality & Governance Dashboard**
   - Source: Historical views with soft delete data
   - Metrics: Data retention, deletion patterns, audit trails

---

## Troubleshooting

### Common Issues & Solutions

#### Issue 1: Mirroring Connection Fails
**Symptoms:** Cannot connect to Azure SQL Database from Fabric
**Solutions:**
```sql
-- Check firewall rules
-- Verify in Azure Portal > SQL Server > Networking
-- Ensure "Allow Azure services and resources" is enabled
-- Add your IP address if connecting from specific location

-- Verify System Assigned Managed Identity
-- Azure Portal > SQL Server > Identity > System assigned: On
```

#### Issue 2: Tables Not Appearing in Mirroring
**Symptoms:** Some tables don't show up in table selection
**Possible Causes & Solutions:**
- **No Primary Key:** Add primary key to tables
- **Unsupported Features:** Check for temporal, memory-optimized, or graph tables
- **Permissions:** Ensure proper database permissions

```sql
-- Find tables without primary keys
SELECT SCHEMA_NAME(t.schema_id) AS SchemaName, t.name AS TableName
FROM sys.tables t
LEFT JOIN sys.key_constraints kc ON t.object_id = kc.parent_object_id 
    AND kc.type = 'PK'
WHERE kc.object_id IS NULL
  AND SCHEMA_NAME(t.schema_id) = 'SalesLT';
```

#### Issue 3: Slow Initial Sync
**Symptoms:** Initial data loading takes very long
**Solutions:**
- Monitor source database DTU/CPU usage
- Consider smaller batch sizes
- Temporary scale up during initial sync

#### Issue 4: Replication Lag
**Symptoms:** Changes not appearing in Fabric quickly
**Solutions:**
- Check transaction log size and activity
- Monitor long-running transactions
- Verify network connectivity

```sql
-- Check transaction log usage
SELECT 
    name,
    log_reuse_wait_desc,
    log_space_used_percent,
    log_space_available_percent
FROM sys.databases 
WHERE name = 'AdventureWorksLT';
```

### Monitoring Queries

```sql
-- Monitor mirroring status in Azure SQL Database
SELECT * FROM sys.dm_change_feed_log_scan_sessions;

-- Check active transactions
SELECT 
    session_id,
    transaction_id,
    transaction_begin_time,
    DATEDIFF(SECOND, transaction_begin_time, GETDATE()) as duration_seconds
FROM sys.dm_tran_active_transactions t
JOIN sys.dm_tran_session_transactions st ON t.transaction_id = st.transaction_id;
```

---

## Best Practices

### 1. Data Modeling for Analytics
- **Implement soft deletes** for historical preservation
- **Add audit columns** (CreatedDate, ModifiedDate, CreatedBy, ModifiedBy)
- **Use meaningful business keys** alongside technical primary keys
- **Design with time-based partitioning** in mind for large tables

### 2. Performance Optimization
- **Monitor transaction log size** during high-volume operations
- **Implement proper indexing** strategy on source tables
- **Consider read replicas** for reporting workloads during migration
- **Schedule maintenance operations** during low-traffic periods

### 3. Security & Governance
- **Use Azure Key Vault** for connection strings in production
- **Implement row-level security** where needed (note: doesn't replicate to Fabric)
- **Document data lineage** and transformation logic
- **Establish data retention policies** for historical data

### 4. Cost Management
- **Use serverless databases** for dev/test environments
- **Monitor Fabric capacity usage** during demos and production
- **Implement auto-pause** for development databases
- **Right-size your Fabric capacity** based on actual usage

### 5. Change Management
- **Test schema changes** in development first
- **Coordinate releases** between source and analytics teams
- **Document breaking changes** and mitigation strategies
- **Maintain rollback procedures** for critical changes

---

## Resources

### Official Documentation
- [Microsoft Fabric Mirroring Overview](https://learn.microsoft.com/en-us/fabric/database/mirrored-database/overview)
- [Azure SQL Database Mirroring Tutorial](https://learn.microsoft.com/en-us/fabric/database/mirrored-database/azure-sql-database-tutorial)
- [Mirroring Limitations](https://learn.microsoft.com/en-us/fabric/database/mirrored-database/azure-sql-database-limitations)
- [Fabric Pricing](https://azure.microsoft.com/en-us/pricing/details/microsoft-fabric/)

### Sample Scripts Repository
All scripts from this demo are available in our GitHub repository:
```
📁 fabric-mirroring-demo/
├── 📁 setup/
│   ├── 01-azure-sql-setup.sql
│   ├── 02-udt-fixes.sql
│   └── 03-soft-delete-setup.sql
├── 📁 demo/
│   ├── 01-insert-demo.sql
│   ├── 02-update-demo.sql
│   └── 03-delete-demo.sql
├── 📁 analytics/
│   ├── fabric-views.sql
│   └── powerbi-queries.sql
└── 📁 troubleshooting/
    └── monitoring-queries.sql
```

### Community Resources
- [Microsoft Fabric Community](https://community.fabric.microsoft.com/)
- [Azure SQL Database Community](https://techcommunity.microsoft.com/t5/azure-sql-database/ct-p/Azure-SQL-Database)
- [Power BI Community](https://community.powerbi.com/)

### Learning Paths
- [Microsoft Fabric Learning Path](https://learn.microsoft.com/en-us/training/paths/get-started-fabric/)
- [Azure SQL Database Fundamentals](https://learn.microsoft.com/en-us/training/paths/azure-sql-fundamentals/)
- [Modern Data Warehouse with Microsoft Fabric](https://learn.microsoft.com/en-us/training/paths/implement-lakehouse-microsoft-fabric/)

---

## Demo Checklist

### Pre-Demo Setup (30 minutes)
- [ ] Azure SQL Database created with AdventureWorksLT
- [ ] System Assigned Managed Identity enabled
- [ ] Fabric workspace created and configured
- [ ] UDT issues resolved in source database
- [ ] Soft delete triggers implemented
- [ ] Demo products inserted and ready

### During Demo (60-90 minutes)
- [ ] Show initial mirroring errors (UDT limitations)
- [ ] Demonstrate UDT resolution process
- [ ] Configure successful mirroring
- [ ] Execute CRUD operations with real-time monitoring
- [ ] Demonstrate soft delete functionality
- [ ] Show analytics views in Fabric SQL Analytics Endpoint
- [ ] Highlight Power BI integration opportunities

### Post-Demo Cleanup
- [ ] Delete Azure SQL Database (if not needed)
- [ ] Remove Fabric workspace items
- [ ] Document lessons learned and client feedback

---

**🎯 Success Metrics:**
- Real-time data replication demonstrated
- UDT limitations explained and resolved
- Soft delete strategy implemented
- Advanced analytics scenarios showcased
- Client understanding of Fabric capabilities confirmed

**📞 Support:** For technical issues during the demo, refer to the troubleshooting section or contact your Microsoft representative.

---

## About the Author

**GitHub:** [@stuba83](https://github.com/stuba83)

This comprehensive demo guide was created to showcase the complete implementation of Microsoft Fabric Mirroring from Azure SQL Database to Fabric OneLake. The guide includes real-world scenarios, limitations handling, and advanced analytics patterns.

For questions, issues, or contributions to this demo guide, please:
- 🐛 **Report issues:** [Create an issue](https://github.com/stuba83/fabric-mirroring-demo/issues)
- 🤝 **Contribute:** [Submit a pull request](https://github.com/stuba83/fabric-mirroring-demo/pulls)
- 💬 **Discuss:** [Start a discussion](https://github.com/stuba83/fabric-mirroring-demo/discussions)

### Repository Structure
```
📁 fabric-mirroring-demo/
├── README.md                     # This comprehensive guide
├── 📁 scripts/
│   ├── 📁 setup/
│   │   ├── 01-azure-sql-setup.sql
│   │   ├── 02-udt-fixes.sql
│   │   └── 03-soft-delete-setup.sql
│   ├── 📁 demo/
│   │   ├── 01-insert-demo.sql
│   │   ├── 02-update-demo.sql
│   │   └── 03-delete-demo.sql
│   ├── 📁 analytics/
│   │   ├── fabric-views.sql
│   │   └── powerbi-queries.sql
│   └── 📁 troubleshooting/
│       └── monitoring-queries.sql
├── 📁 assets/
│   └── 📁 images/
│       ├── architecture-diagram.png
│       └── demo-screenshots/
└── LICENSE
```

**⭐ If this guide helped you, please star the repository!**

---

*This guide was created for demonstration purposes. Adapt configurations and security settings for your production requirements.*

**Contact:** [@stuba83](https://github.com/stuba83) | **Repository:** [fabric-mirroring-demo](https://github.com/stuba83/fabric-mirroring-demo)