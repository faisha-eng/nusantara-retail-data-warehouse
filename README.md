# Nusantara Retail Data Warehouse (SQL Server ETL)

A team project for the ETL and Data Warehouse course at Universitas Tarumanagara.
It builds a snowflake-schema data warehouse in SQL Server for monthly sales growth
analysis across 40 branches of a retail company (PT. Nusantara Retail Indonesia, a case study).

## What the scripts do
- `ekstraksi.sql`: creates the staging database (`StagingArea`) and extracts branch
  master data and sales transactions from the source databases
- `transform.sql`: profiles the data (null and duplicate checks), adds surrogate keys,
  applies SCD Type 1 (Region, Province, City, SalesTime) and SCD Type 2 (Branch),
  filters out VOID/CANCELED sales, standardizes dates, and aggregates sales into
  monthly totals per branch
- `loading.sql`: creates the warehouse database (`DW_UAS`), runs the initial load,
  then the incremental load using `MERGE`

## Warehouse design
- 1 fact table: `Sales` (total sales per branch per month)
- 5 dimensions: Region, Province, City, Branch, SalesTime

## Results (from the project report)
- 7,531 source transactions (7,231 COMPLETED) aggregated into 480 monthly fact records
  (40 branches x 12 months of 2025)

## Tech
SQL Server, T-SQL, SQL Server Management Studio

## How to run
1. Create the source databases `MASTER_DB` and `POS_DB` (the source data is not included)
2. Run `ekstraksi.sql`
3. Run `transform.sql`
4. Run `loading.sql`

## My role
Wrote the T-SQL scripts together with two teammates and co-authored the project report.

## Team
Team of 5, Universitas Tarumanagara, 2026.
