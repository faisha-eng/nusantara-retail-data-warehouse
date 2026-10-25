-- =============================================
-- BUAT DATABASE FINAL
-- =============================================
CREATE DATABASE DW_UAS;
GO

USE DW_UAS;
GO

-- =============================================
-- LOAD: Buat tabel di DW_FINAL
-- =============================================

-- Region
SELECT * INTO DW_UAS.dbo.Region FROM StagingArea.dbo.Region;
GO

-- Province
SELECT * INTO DW_UAS.dbo.Province FROM StagingArea.dbo.Province;
GO

-- City
SELECT * INTO DW_UAS.dbo.City FROM StagingArea.dbo.City;
GO

-- Branch (hanya yang is_current = 1)
SELECT * INTO DW_UAS.dbo.Branch 
FROM StagingArea.dbo.Branch 
WHERE is_current = 1;
GO

-- SalesTime
SELECT * INTO DW_UAS.dbo.SalesTime FROM StagingArea.dbo.SalesTime;
GO

-- Sales (Fact)
SELECT * INTO DW_UAS.dbo.Sales FROM StagingArea.dbo.Sales;
GO

-- =============================================
-- VERIFIKASI HASIL LOAD
-- =============================================
SELECT 'Region'    AS tabel, COUNT(*) AS jumlah_baris FROM DW_UAS.dbo.Region
UNION ALL
SELECT 'Province'  AS tabel, COUNT(*) AS jumlah_baris FROM DW_UAS.dbo.Province
UNION ALL
SELECT 'City'      AS tabel, COUNT(*) AS jumlah_baris FROM DW_UAS.dbo.City
UNION ALL
SELECT 'Branch'    AS tabel, COUNT(*) AS jumlah_baris FROM DW_UAS.dbo.Branch
UNION ALL
SELECT 'SalesTime' AS tabel, COUNT(*) AS jumlah_baris FROM DW_UAS.dbo.SalesTime
UNION ALL
SELECT 'Sales'     AS tabel, COUNT(*) AS jumlah_baris FROM DW_UAS.dbo.Sales;
GO

-- =============================================
-- INCREMENTAL LOAD: StagingArea → DW_UAS
-- Dijalankan berkala setelah transform selesai
-- =============================================
 
-- 1. Region (SCD Type 1)
MERGE DW_UAS.dbo.Region AS target
USING StagingArea.dbo.Region AS source
ON target.region_id = source.region_id
WHEN MATCHED AND target.region_name <> source.region_name THEN
    UPDATE SET target.region_name = source.region_name
WHEN NOT MATCHED THEN
    INSERT (region_id, region_name)
    VALUES (source.region_id, source.region_name);
GO
 
-- 2. Province (SCD Type 1)
MERGE DW_UAS.dbo.Province AS target
USING StagingArea.dbo.Province AS source
ON target.province_id = source.province_id
WHEN MATCHED AND target.province_name <> source.province_name THEN
    UPDATE SET target.province_name = source.province_name
WHEN NOT MATCHED THEN
    INSERT (province_id, region_id, province_name)
    VALUES (source.province_id, source.region_id, source.province_name);
GO
 
-- 3. City (SCD Type 1)
MERGE DW_UAS.dbo.City AS target
USING StagingArea.dbo.City AS source
ON target.city_id = source.city_id
WHEN MATCHED AND target.city_name <> source.city_name THEN
    UPDATE SET target.city_name = source.city_name
WHEN NOT MATCHED THEN
    INSERT (city_id, province_id, city_name)
    VALUES (source.city_id, source.province_id, source.city_name);
GO
 
-- 4. Branch (SCD Type 2)
-- Step 4a: Tutup record lama yang berubah
UPDATE DW_UAS.dbo.Branch
SET expiry_date = CAST(GETDATE() AS DATE),
    is_current = 0
WHERE is_current = 1
AND branch_id IN (
    SELECT s.branch_id
    FROM StagingArea.dbo.Branch s
    JOIN DW_UAS.dbo.Branch d ON s.branch_id = d.branch_id
    WHERE d.is_current = 1
    AND (
        s.branch_name <> d.branch_name OR
        s.branch_type <> d.branch_type OR
        s.city_id <> d.city_id
    )
);
GO
 
-- Step 4b: Insert record baru
INSERT INTO DW_UAS.dbo.Branch
(branch_id, city_id, branch_code, branch_name, branch_type, 
open_date, effective_date, expiry_date, is_current)
SELECT 
    s.branch_id, s.city_id, s.branch_code, s.branch_name,
    s.branch_type, s.open_date, CAST(GETDATE() AS DATE), NULL, 1
FROM StagingArea.dbo.Branch s
WHERE NOT EXISTS (
    SELECT 1 FROM DW_UAS.dbo.Branch d
    WHERE d.branch_id = s.branch_id AND d.is_current = 1
);
GO
 
-- 5. SalesTime (SCD Type 1)
MERGE DW_UAS.dbo.SalesTime AS target
USING StagingArea.dbo.SalesTime AS source
ON target.sk_time = source.sk_time
WHEN MATCHED AND target.month_name <> source.month_name THEN
    UPDATE SET target.month_name = source.month_name
WHEN NOT MATCHED THEN
    INSERT (sk_time, year, month, month_name)
    VALUES (source.sk_time, source.year, source.month, source.month_name);
GO
 
-- 6. Sales/Fact (hanya data baru)
MERGE DW_UAS.dbo.Sales AS target
USING StagingArea.dbo.Sales AS source
ON target.sk_branch = source.sk_branch
AND target.sk_time = source.sk_time
WHEN MATCHED AND target.total_sales <> source.total_sales THEN
    UPDATE SET target.total_sales = source.total_sales
WHEN NOT MATCHED THEN
    INSERT (sk_branch, sk_time, total_sales)
    VALUES (source.sk_branch, source.sk_time, source.total_sales);
GO
 
-- Verifikasi setelah incremental load
SELECT 'Region'    AS tabel, COUNT(*) AS jumlah_baris FROM DW_UAS.dbo.Region
UNION ALL
SELECT 'Province'  AS tabel, COUNT(*) AS jumlah_baris FROM DW_UAS.dbo.Province
UNION ALL
SELECT 'City'      AS tabel, COUNT(*) AS jumlah_baris FROM DW_UAS.dbo.City
UNION ALL
SELECT 'Branch'    AS tabel, COUNT(*) AS jumlah_baris FROM DW_UAS.dbo.Branch WHERE is_current = 1
UNION ALL
SELECT 'SalesTime' AS tabel, COUNT(*) AS jumlah_baris FROM DW_UAS.dbo.SalesTime
UNION ALL
SELECT 'Sales'     AS tabel, COUNT(*) AS jumlah_baris FROM DW_UAS.dbo.Sales;
GO