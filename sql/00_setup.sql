-- Track C / Olist SQL Server setup (no credentials, no machine-specific paths).
-- Fresh installation: run 01_schema.sql, import the original 8 source CSVs into tables,
-- run 01_views.sql, validate with 02_validation.sql, then run questions.
-- Existing OlistDB import: do NOT rerun the rename scripts or re-import; run 01_views.sql safely.
-- SSMS Import Data: UTF-8, CSV-aware double quote text qualifier, comma delimiter,
-- header first row, CRLF/LF handling, datetime2 for timestamps, varchar/text for ZIP prefixes,
-- decimal(18,2) prices/freight/payments. Keep quoted multiline review text intact.
-- Import actual CSVs into schema table names in 01_schema.sql. Compare against docs/source_validation.md.
-- Run order for existing OlistDB: 01_views.sql, 02_validation.sql,
-- 03_analysis.sql, 04_dashboard_exports.sql. Ignore optional geolocation table.
IF DB_ID(N'OlistDB') IS NULL CREATE DATABASE OlistDB;
GO
