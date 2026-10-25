USE StagingArea;
GO
--DATA PROFILING
--CEK KEBERADAAN NILAI NULL/MISSING VALUE
-- 1. tabel dim Branch
select * from Branch;
SELECT
    SUM(CASE WHEN branch_id IS NULL THEN 1 ELSE 0 END) AS null_branch_id,
    SUM(CASE WHEN branch_code IS NULL THEN 1 ELSE 0 END) AS null_branch_code,
    SUM(CASE WHEN branch_name IS NULL THEN 1 ELSE 0 END) AS null_branch_name,
    SUM(CASE WHEN branch_type IS NULL THEN 1 ELSE 0 END) AS null_branch_type,
    SUM(CASE WHEN open_date IS NULL THEN 1 ELSE 0 END) AS null_open_date,
    SUM(CASE WHEN city_id IS NULL THEN 1 ELSE 0 END) AS null_city_id
FROM Branch;
-- 2. tabel dim city
select * from City;
SELECT
    SUM(CASE WHEN city_id IS NULL THEN 1 ELSE 0 END) AS null_city_id,
    SUM(CASE WHEN province_id IS NULL THEN 1 ELSE 0 END) AS null_province_id,
    SUM(CASE WHEN city_name IS NULL THEN 1 ELSE 0 END) AS null_city_name
FROM City;
-- 3. tabel dim province
select * from Province;
SELECT
    SUM(CASE WHEN province_id IS NULL THEN 1 ELSE 0 END) AS null_province_id,
    SUM(CASE WHEN region_id IS NULL THEN 1 ELSE 0 END) AS null_region_id,
    SUM(CASE WHEN province_name IS NULL THEN 1 ELSE 0 END) AS null_province_name
FROM Province;
-- 4. tabel dim region
select * from Region;
SELECT
    SUM(CASE WHEN region_id IS NULL THEN 1 ELSE 0 END) AS null_region_id,
    SUM(CASE WHEN region_name IS NULL THEN 1 ELSE 0 END) AS null_region_name
FROM Region;
-- 5. tabel fact sales
select * from Sales;
SELECT
    SUM(CASE WHEN branch_id IS NULL THEN 1 ELSE 0 END) AS null_branch_id,
    SUM(CASE WHEN sales_datetime IS NULL THEN 1 ELSE 0 END) AS null_sales_datetime,
    SUM(CASE WHEN net_amount IS NULL THEN 1 ELSE 0 END) AS null_net_amount,
    SUM(CASE WHEN sales_status IS NULL THEN 1 ELSE 0 END) AS null_sales_status
FROM Sales;

--CEK DUPLIKASI DATA (memastikan key tidak ada yang duplikat)
-- 1. dim Branch
SELECT
    branch_id,
    COUNT(*) AS jumlah
FROM Branch
GROUP BY branch_id
HAVING COUNT(*) > 1;
-- 2. dim City
SELECT
    city_id,
    COUNT(*) AS jumlah
FROM City
GROUP BY city_id
HAVING COUNT(*) > 1;
-- 2. dim Province
SELECT
    province_id,
    COUNT(*) AS jumlah
FROM Province
GROUP BY province_id
HAVING COUNT(*) > 1;
-- 2. dim Region
SELECT
    region_id,
    COUNT(*) AS jumlah
FROM Region
GROUP BY region_id
HAVING COUNT(*) > 1;


-- =============================================
-- STEP 1: TAMBAH SURROGATE KEY KE SEMUA TABEL DIMENSI
-- =============================================

-- Region
ALTER TABLE Region
ADD sk_region INT IDENTITY(1,1) PRIMARY KEY;
GO

-- Province
ALTER TABLE Province
ADD sk_province INT IDENTITY(1,1) PRIMARY KEY;
GO

-- City
ALTER TABLE City
ADD sk_city INT IDENTITY(1,1) PRIMARY KEY;
GO

-- Branch (SCD Type 2 perlu kolom tambahan)
ALTER TABLE Branch
ADD sk_branch INT IDENTITY(1,1) PRIMARY KEY,
    effective_date DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    expiry_date DATE NULL,
    is_current BIT NOT NULL DEFAULT 1;
GO

-- =============================================
-- STEP 2: BUAT TABEL Dim_SalesTime
-- =============================================
CREATE TABLE SalesTime (
    sk_time INT PRIMARY KEY,        -- format YYYYMM
    year INT NOT NULL,
    month INT NOT NULL,
    month_name VARCHAR(20) NOT NULL
);
GO

-- =============================================
-- STEP 3: SCD TYPE 1 - Region
-- =============================================
MERGE StagingArea.dbo.Region AS target
USING MASTER_DB.dbo.Region AS source
ON target.region_id = source.region_id
WHEN MATCHED AND target.region_name <> source.region_name THEN
    UPDATE SET target.region_name = source.region_name
WHEN NOT MATCHED THEN
    INSERT (region_id, region_name)
    VALUES (source.region_id, source.region_name);
GO

-- =============================================
-- STEP 4: SCD TYPE 1 - Province
-- =============================================
MERGE StagingArea.dbo.Province AS target
USING MASTER_DB.dbo.Province AS source
ON target.province_id = source.province_id
WHEN MATCHED AND target.province_name <> source.province_name THEN
    UPDATE SET target.province_name = source.province_name
WHEN NOT MATCHED THEN
    INSERT (province_id, region_id, province_name)
    VALUES (source.province_id, source.region_id, source.province_name);
GO

-- =============================================
-- STEP 5: SCD TYPE 1 - City
-- =============================================
MERGE StagingArea.dbo.City AS target
USING MASTER_DB.dbo.City AS source
ON target.city_id = source.city_id
WHEN MATCHED AND target.city_name <> source.city_name THEN
    UPDATE SET target.city_name = source.city_name
WHEN NOT MATCHED THEN
    INSERT (city_id, province_id, city_name)
    VALUES (source.city_id, source.province_id, source.city_name);
GO

-- =============================================
-- STEP 6: SCD TYPE 2 - Branch
-- =============================================

-- Step 6a: Expire baris lama yang berubah
UPDATE StagingArea.dbo.Branch
SET
    expiry_date = CAST(GETDATE() AS DATE),
    is_current  = 0
WHERE is_current = 1
AND branch_id IN (
    SELECT b.branch_id
    FROM MASTER_DB.dbo.Branch b
    JOIN StagingArea.dbo.Branch d ON b.branch_id = d.branch_id
    WHERE d.is_current = 1
    AND (
        d.branch_name <> b.branch_name OR
        d.city_id     <> b.city_id     OR
        d.branch_type <> b.branch_type
    )
);
GO

-- Step 6b: Insert baris baru (data berubah + data baru)
INSERT INTO StagingArea.dbo.Branch
    (branch_id, city_id, branch_code, branch_name, branch_type, open_date, effective_date, expiry_date, is_current)
SELECT
    b.branch_id,
    b.city_id,
    b.branch_code,
    b.branch_name,
    b.branch_type,
    b.open_date,
    CAST(GETDATE() AS DATE),
    NULL,
    1
FROM MASTER_DB.dbo.Branch b
WHERE NOT EXISTS (
    SELECT 1 FROM StagingArea.dbo.Branch d
    WHERE d.branch_id = b.branch_id AND d.is_current = 1
);
GO

-- =============================================
-- STEP 7: SCD TYPE 1 - SalesTime
-- Pecah sales_datetime dari tabel Sales
-- sk_time format YYYYMM
-- =============================================
MERGE StagingArea.dbo.SalesTime AS target
USING (
    SELECT DISTINCT
        CONVERT(INT, FORMAT(sales_datetime, 'yyyyMM')) AS sk_time,
        YEAR(sales_datetime)                           AS year,
        MONTH(sales_datetime)                          AS month,
        DATENAME(MONTH, sales_datetime)                AS month_name
    FROM StagingArea.dbo.Sales
) AS source
ON target.sk_time = source.sk_time
WHEN MATCHED AND target.month_name <> source.month_name THEN
    UPDATE SET target.month_name = source.month_name
WHEN NOT MATCHED THEN
    INSERT (sk_time, year, month, month_name)
    VALUES (source.sk_time, source.year, source.month, source.month_name);
GO

-- =============================================
-- STEP 8: TRANSFORM FACT TABLE Sales
-- Tambah SK, filter COMPLETED, agregasi
-- =============================================

-- Step 8a: Tambah kolom sk_branch dan sk_time ke Fact
ALTER TABLE Sales
ADD sk_branch INT NULL,
    sk_time INT NULL;
GO

-- Step 8b: Isi sk_branch dan sk_time
UPDATE StagingArea.dbo.Sales
SET
    sk_branch = b.sk_branch,
    sk_time   = CONVERT(INT, FORMAT(sales_datetime, 'yyyyMM'))
FROM StagingArea.dbo.Sales s
JOIN StagingArea.dbo.Branch b ON s.branch_id = b.branch_id AND b.is_current = 1;
GO

-- Step 8c: Hapus transaksi yang bukan COMPLETED
DELETE FROM StagingArea.dbo.Sales
WHERE sales_status <> 'COMPLETED';
GO

-- Step 8d: Agregasi - buat tabel fact final
-- Drop kolom yang tidak diperlukan lagi
ALTER TABLE Sales DROP COLUMN branch_id;
ALTER TABLE Sales DROP COLUMN sales_datetime;
ALTER TABLE Sales DROP COLUMN sales_status;
GO

-- Step 8e: Rename net_amount ke total_sales
EXEC sp_rename 'Sales.net_amount', 'total_sales', 'COLUMN';
GO

-- Step 8f: Agregasi total_sales per sk_branch per sk_time
-- Buat tabel fact final yang sudah diagregasi
SELECT
    sk_branch,
    sk_time,
    SUM(total_sales) AS total_sales
INTO StagingArea.dbo.Fact_Sales
FROM StagingArea.dbo.Sales
GROUP BY sk_branch, sk_time;
GO

-- Step 8g: Hapus tabel Sales sementara
DROP TABLE StagingArea.dbo.Sales;
GO

-- Step 8h: Rename Fact_Sales jadi Sales
EXEC sp_rename 'Fact_Sales', 'Sales';
GO

-- Step 8i: Ubah kolom jadi NOT NULL dulu sebelum tambah PK
ALTER TABLE Sales ALTER COLUMN sk_branch INT NOT NULL;
ALTER TABLE Sales ALTER COLUMN sk_time INT NOT NULL;
ALTER TABLE Sales ALTER COLUMN total_sales DECIMAL(18,2) NOT NULL;
GO

-- Baru tambah constraint
ALTER TABLE Sales
ADD CONSTRAINT PK_Sales PRIMARY KEY (sk_branch, sk_time);

ALTER TABLE Sales
ADD CONSTRAINT FK_Sales_Branch FOREIGN KEY (sk_branch) REFERENCES Branch(sk_branch);

ALTER TABLE Sales
ADD CONSTRAINT FK_Sales_Time FOREIGN KEY (sk_time) REFERENCES SalesTime(sk_time);
GO

select * from Sales;

-- =============================================
-- STEP 9: TAMBAH FK ANTAR DIMENSI
-- =============================================
-- Tambah unique constraint supaya bisa direferensikan FK
ALTER TABLE Region
ADD CONSTRAINT UQ_Region_region_id UNIQUE (region_id);

ALTER TABLE Province
ADD CONSTRAINT UQ_Province_province_id UNIQUE (province_id);

ALTER TABLE City
ADD CONSTRAINT UQ_City_city_id UNIQUE (city_id);
GO

ALTER TABLE Province
ADD CONSTRAINT FK_Province_Region
    FOREIGN KEY (region_id) REFERENCES Region(region_id);
GO

ALTER TABLE City
ADD CONSTRAINT FK_City_Province
    FOREIGN KEY (province_id) REFERENCES Province(province_id);
GO

ALTER TABLE Branch
ADD CONSTRAINT FK_Branch_City
    FOREIGN KEY (city_id) REFERENCES City(city_id);
GO

-- =============================================
-- CEK HASIL AKHIR
-- =============================================
SELECT * FROM Region;
SELECT * FROM Province;
SELECT * FROM City;
SELECT * FROM Branch;
SELECT * FROM SalesTime;
SELECT * FROM Sales;
GO

