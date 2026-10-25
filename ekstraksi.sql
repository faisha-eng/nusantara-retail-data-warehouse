-- =============================================
-- CREATE DATABASE DATA WAREHOUSE
-- =============================================
CREATE DATABASE StagingArea;
GO

USE StagingArea;
GO

-- =============================================
-- CREATE TABEL DIMENSI & FAKTA
-- =============================================

CREATE TABLE Region (
    region_id INT NOT NULL,           -- natural key
    region_name VARCHAR(100) NOT NULL
);

CREATE TABLE Province (
    province_id INT NOT NULL,         -- natural key
    region_id INT NOT NULL,
    province_name VARCHAR(100) NOT NULL
);

CREATE TABLE City (
    city_id INT NOT NULL,             -- natural key
    province_id INT NOT NULL,
    city_name VARCHAR(100) NOT NULL
);

CREATE TABLE Branch (
    branch_id INT NOT NULL,           -- natural key
    city_id INT NOT NULL,
    branch_code VARCHAR(20) NOT NULL,
    branch_name VARCHAR(100) NOT NULL,
    branch_type VARCHAR(50),
    open_date DATE
);

-- Fact_Sales tanpa sales_id, PK-nya kombinasi sk_branch + sk_time
CREATE TABLE Sales (
    branch_id INT,
    sales_datetime DATETIME,
    net_amount DECIMAL(18,2),
    sales_status VARCHAR(20)
);

-- 1. Dim_Region
INSERT INTO StagingArea.dbo.Region (region_id, region_name)
SELECT region_id, region_name
FROM MASTER_DB.dbo.Region;
GO

-- 2. Dim_Province
INSERT INTO StagingArea.dbo.Province (province_id, region_id, province_name)
SELECT province_id, region_id, province_name
FROM MASTER_DB.dbo.Province;
GO

-- 3. Dim_City
INSERT INTO StagingArea.dbo.City (city_id, province_id, city_name)
SELECT city_id, province_id, city_name
FROM MASTER_DB.dbo.City;
GO

-- 4. Dim_Branch
INSERT INTO StagingArea.dbo.Branch (branch_id, city_id, branch_code, branch_name, branch_type, open_date)
SELECT branch_id, city_id, branch_code, branch_name, branch_type, open_date
FROM MASTER_DB.dbo.Branch;
GO

-- 6. Fact_Sales
INSERT INTO StagingArea.dbo.Sales (branch_id, sales_datetime, net_amount, sales_status)
SELECT branch_id, sales_datetime, net_amount, sales_status
FROM POS_DB.dbo.Sales_Header
GO

select * from Sales;