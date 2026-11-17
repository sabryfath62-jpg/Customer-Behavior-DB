USE OlistDB;
GO
-- Source counts and distinct candidate keys
SELECT 'orders' table_name,COUNT(*) rows_n,COUNT(DISTINCT order_id) distinct_ids FROM dbo.orders
UNION ALL SELECT 'customers',COUNT(*),COUNT(DISTINCT customer_id) FROM dbo.customers
UNION ALL SELECT 'products',COUNT(*),COUNT(DISTINCT product_id) FROM dbo.products
UNION ALL SELECT 'sellers',COUNT(*),COUNT(DISTINCT seller_id) FROM dbo.sellers;
-- Item grain; expect no duplicate order_id + order_item_id
SELECT order_id,order_item_id,COUNT(*) n FROM dbo.order_items
GROUP BY order_id,order_item_id HAVING COUNT(*)>1;
-- Missing foreign key matches
SELECT 'orders_customers' relationship,COUNT(*) missing_n FROM dbo.orders o LEFT JOIN dbo.customers c ON o.customer_id=c.customer_id WHERE c.customer_id IS NULL
UNION ALL SELECT 'items_orders',COUNT(*) FROM dbo.order_items i LEFT JOIN dbo.orders o ON i.order_id=o.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'items_products',COUNT(*) FROM dbo.order_items i LEFT JOIN dbo.products p ON i.product_id=p.product_id WHERE p.product_id IS NULL
UNION ALL SELECT 'items_sellers',COUNT(*) FROM dbo.order_items i LEFT JOIN dbo.sellers s ON i.seller_id=s.seller_id WHERE s.seller_id IS NULL
UNION ALL SELECT 'reviews_orders',COUNT(*) FROM dbo.order_reviews r LEFT JOIN dbo.orders o ON r.order_id=o.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'payments_orders',COUNT(*) FROM dbo.order_payments p LEFT JOIN dbo.orders o ON p.order_id=o.order_id WHERE o.order_id IS NULL;
-- Key missingness, out-of-scope and invalid measures
SELECT COUNT(*) orders_n,SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) missing_delivery,
SUM(CASE WHEN order_purchase_timestamp<'20170101' OR order_purchase_timestamp>='20180901' THEN 1 ELSE 0 END) out_of_scope
FROM dbo.orders;
SELECT SUM(CASE WHEN price<0 THEN 1 ELSE 0 END) negative_price,
SUM(CASE WHEN freight_value<0 THEN 1 ELSE 0 END) negative_freight,
SUM(CASE WHEN freight_value=0 THEN 1 ELSE 0 END) zero_freight FROM dbo.order_items;
SELECT SUM(CASE WHEN payment_value<0 THEN 1 ELSE 0 END) negative_payment,
SUM(CASE WHEN payment_value=0 THEN 1 ELSE 0 END) zero_payment,
SUM(CASE WHEN payment_installments=0 THEN 1 ELSE 0 END) zero_installments FROM dbo.order_payments;
SELECT SUM(CASE WHEN review_score NOT BETWEEN 1 AND 5 THEN 1 ELSE 0 END) invalid_scores,
COUNT(*)-COUNT(DISTINCT order_id) extra_review_rows FROM dbo.order_reviews;
-- Complete ranking ties must be zero or source index is needed for deterministic selection.
SELECT order_id,review_answer_timestamp,review_creation_date,review_id,COUNT(*) tied_rows
FROM dbo.order_reviews WHERE review_score BETWEEN 1 AND 5
GROUP BY order_id,review_answer_timestamp,review_creation_date,review_id HAVING COUNT(*)>1;
-- Date pair quality; exclude impossible pairs from delivery-duration denominator.
SELECT COUNT(*) delivered_n,
SUM(CASE WHEN order_delivered_customer_date IS NULL OR order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) missing_dates,
SUM(CASE WHEN order_delivered_customer_date < order_purchase_timestamp THEN 1 ELSE 0 END) impossible_pairs
FROM dbo.vw_delivered_scope;
-- Critical reconciliations
SELECT COUNT(*) delivered_orders,COUNT(DISTINCT customer_unique_id) customers,
SUM(merchandise_sales) merchandise_revenue,COUNT(*)-COUNT(merchandise_sales) missing_item_matches
FROM dbo.vw_delivered_scope;
SELECT COUNT(*) customer_rows,COUNT(DISTINCT customer_unique_id) unique_customers,
SUM(total_spend) total_spend FROM dbo.vw_customer_spend;

-- Explicit derived table: one row per order, count of item rows
SELECT COUNT(*) orders_with_items,SUM(x.item_rows) total_item_rows FROM
(SELECT order_id,COUNT(*) item_rows FROM dbo.order_items GROUP BY order_id) AS x;

-- Additional required quality checks: composite payment key (not concatenation), translation key,
-- blank category and zero installments, relevant order timestamps.
SELECT order_id,payment_sequential,COUNT(*) AS duplicate_rows
FROM dbo.order_payments GROUP BY order_id,payment_sequential HAVING COUNT(*)>1;
SELECT product_category_name,COUNT(*) AS duplicate_rows
FROM dbo.category_translation GROUP BY product_category_name HAVING COUNT(*)>1;
SELECT COUNT(*) AS category_translation_rows,
 COUNT(DISTINCT product_category_name) AS unique_source_categories FROM dbo.category_translation;
SELECT COUNT(*) AS total_products,
 SUM(CASE WHEN product_category_name IS NULL OR LTRIM(RTRIM(product_category_name))='' THEN 1 ELSE 0 END) AS blank_category
FROM dbo.products;
SELECT payment_type,COUNT(*) AS zero_value_rows FROM dbo.order_payments
WHERE payment_value=0 GROUP BY payment_type ORDER BY zero_value_rows DESC;
SELECT payment_type,COUNT(*) AS zero_installment_rows FROM dbo.order_payments
WHERE payment_installments=0 GROUP BY payment_type ORDER BY zero_installment_rows DESC;
SELECT order_status,COUNT(*) AS orders_n,
 SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS missing_delivered_date
FROM dbo.orders GROUP BY order_status ORDER BY orders_n DESC;
SELECT MIN(order_purchase_timestamp) AS first_order_timestamp,
 MAX(order_purchase_timestamp) AS last_order_timestamp,
 SUM(CASE WHEN order_purchase_timestamp>='20170101' AND order_purchase_timestamp<'20180901' THEN 1 ELSE 0 END) AS in_scope,
 SUM(CASE WHEN order_purchase_timestamp<'20170101' OR order_purchase_timestamp>='20180901' THEN 1 ELSE 0 END) AS outside_scope
FROM dbo.orders;
-- Source reviews, including multiple rows for one order; do not delete.
SELECT COUNT(*) AS total_review_rows,COUNT(DISTINCT order_id) AS reviewed_orders,
 COUNT(*)-COUNT(DISTINCT order_id) AS extra_review_rows,
 COUNT(*)-COUNT(DISTINCT review_id) AS repeated_review_id_rows
FROM dbo.order_reviews;
SELECT COUNT(*) AS orders_with_multiple_review_rows FROM
 (SELECT order_id FROM dbo.order_reviews GROUP BY order_id HAVING COUNT(*)>1) AS x;
-- Review text length / potential truncation: compare source CSV max length; TEXT column should be NVARCHAR(MAX).
SELECT MAX(LEN(review_comment_message)) AS max_comment_length,
 SUM(CASE WHEN LEN(review_comment_message)=250 THEN 1 ELSE 0 END) AS comment_rows_exactly_250
FROM dbo.order_reviews;
GO
