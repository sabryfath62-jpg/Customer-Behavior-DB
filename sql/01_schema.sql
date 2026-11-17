-- Olist / Track C | SOURCE TABLE DDL and documented import structure.
-- Reproducible fresh-database path: CREATE tables below and import 8 original CSVs using
-- SQL Server Import and Export Wizard configured for existing destination tables.
-- If tables already exist in OlistDB, NO CREATE TABLE statements replace them.
-- WARNING: verify CSV columns/locale/UTF-8/quoted embedded commas/newlines; preserve originals.
-- Avoid Import Flat File Wizard when you need to load pre-created tables: use Import Data wizard.
IF DB_ID(N'OlistDB') IS NULL CREATE DATABASE OlistDB;
GO
USE OlistDB;
GO
IF OBJECT_ID(N'dbo.customers',N'U') IS NULL
 CREATE TABLE dbo.customers(customer_id nvarchar(50) NOT NULL, customer_unique_id nvarchar(50) NOT NULL,
 customer_zip_code_prefix varchar(12) NULL, customer_city nvarchar(100) NULL, customer_state nvarchar(4) NULL);
IF OBJECT_ID(N'dbo.orders',N'U') IS NULL
 CREATE TABLE dbo.orders(order_id nvarchar(50) NOT NULL,customer_id nvarchar(50) NOT NULL,
 order_status nvarchar(32) NULL,order_purchase_timestamp datetime2 NULL,order_approved_at datetime2 NULL,
 order_delivered_carrier_date datetime2 NULL,order_delivered_customer_date datetime2 NULL,
 order_estimated_delivery_date datetime2 NULL);
IF OBJECT_ID(N'dbo.order_items',N'U') IS NULL
 CREATE TABLE dbo.order_items(order_id nvarchar(50) NOT NULL,order_item_id int NOT NULL,
 product_id nvarchar(50) NOT NULL,seller_id nvarchar(50) NOT NULL,
 shipping_limit_date datetime2 NULL,price decimal(18,2) NULL,freight_value decimal(18,2) NULL);
IF OBJECT_ID(N'dbo.order_payments',N'U') IS NULL
 CREATE TABLE dbo.order_payments(order_id nvarchar(50) NOT NULL,payment_sequential int NOT NULL,
 payment_type nvarchar(50) NULL,payment_installments int NULL,payment_value decimal(18,2) NULL);
IF OBJECT_ID(N'dbo.order_reviews',N'U') IS NULL
 CREATE TABLE dbo.order_reviews(review_id nvarchar(50) NOT NULL,order_id nvarchar(50) NOT NULL,
 review_score int NULL,review_comment_title nvarchar(1000) NULL,
 review_comment_message nvarchar(max) NULL,review_creation_date datetime2 NULL,
 review_answer_timestamp datetime2 NULL);
IF OBJECT_ID(N'dbo.products',N'U') IS NULL
 CREATE TABLE dbo.products(product_id nvarchar(50) NOT NULL,product_category_name nvarchar(100) NULL,
 product_name_lenght int NULL,product_description_lenght int NULL,product_photos_qty int NULL,
 product_weight_g decimal(18,2) NULL,product_length_cm decimal(18,2) NULL,
 product_height_cm decimal(18,2) NULL,product_width_cm decimal(18,2) NULL);
IF OBJECT_ID(N'dbo.sellers',N'U') IS NULL
 CREATE TABLE dbo.sellers(seller_id nvarchar(50) NOT NULL,seller_zip_code_prefix varchar(12) NULL,
 seller_city nvarchar(100) NULL,seller_state nvarchar(4) NULL);
IF OBJECT_ID(N'dbo.category_translation',N'U') IS NULL
 CREATE TABLE dbo.category_translation(product_category_name nvarchar(100) NOT NULL,
 product_category_name_english nvarchar(100) NULL);
GO
-- Source row-grain candidate keys: customers.customer_id; orders.order_id;
-- items.(order_id,order_item_id); payments.(order_id,payment_sequential);
-- products.product_id; sellers.seller_id; category_translation.product_category_name.
-- Test all candidate keys and missing joins with 02_validation.sql BEFORE applying constraints.
-- Imported SSMS copy may use slightly different but compatible types (e.g. float item.price);
-- 01_views.sql CASTs money without altering source tables. Zip prefixes should be text for fresh import.
