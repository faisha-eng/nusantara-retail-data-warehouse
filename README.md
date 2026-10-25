# Nusantara Retail Data Warehouse (SQL Server ETL)

A team project for the ETL and Data Warehouse course at Universitas Tarumanagara. It builds a data warehouse in SQL Server to analyze monthly sales growth across 40 branches of a retail company (a case study).

## Scripts
- `ekstraksi.sql`: creates the staging database and extracts branch and sales data from the source databases.
- `transform.sql`: checks the data, adds surrogate keys, handles dimension changes (SCD Type 1 and 2), removes VOID/CANCELED sales, and sums sales per branch per month.
- `loading.sql`: creates the warehouse database, loads the data, and runs the incremental load with MERGE.

## Design
The warehouse has 1 fact table (Sales) and 5 dimensions (Region, Province, City, Branch, SalesTime).

## Results
7,531 source transactions (7,231 completed) became 480 monthly sales records (40 branches x 12 months of 2025).

## Tech
SQL Server, T-SQL, SQL Server Management Studio

## How to run
1. Create the source databases `MASTER_DB` and `POS_DB` (the source data is not included).
2. Run `ekstraksi.sql`, then `transform.sql`, then `loading.sql`.

## My role
Wrote the T-SQL scripts together with two teammates and co-authored the project report. Team of 5, 2026.
