USE OlistDB;
GO
-- One row per order; merchandise excludes freight.
CREATE OR ALTER VIEW dbo.vw_order_sales AS
SELECT order_id, COUNT_BIG(*) AS item_count,
 CAST(SUM(CAST(price AS decimal(19,2))) AS decimal(19,2)) AS merchandise_sales,
 CAST(SUM(CAST(freight_value AS decimal(19,2))) AS decimal(19,2)) AS freight_total
FROM dbo.order_items GROUP BY order_id;
GO
-- Latest valid review per order. Source-row index is not available in this import.
-- Previously observed zero complete ties on ordering fields; recheck after reimport.
CREATE OR ALTER VIEW dbo.vw_one_review_per_order AS
WITH ranked AS (
 SELECT order_id,review_id,review_score,review_creation_date,review_answer_timestamp,
 ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY
 CASE WHEN review_answer_timestamp IS NULL THEN 1 ELSE 0 END,
 review_answer_timestamp DESC, review_creation_date DESC, review_id DESC) rn
 FROM dbo.order_reviews WHERE review_score BETWEEN 1 AND 5
)
SELECT order_id,review_id,review_score,review_creation_date,review_answer_timestamp
FROM ranked WHERE rn=1;
GO
-- Delivered in-scope order grain, including orders with missing item matches.
CREATE OR ALTER VIEW dbo.vw_delivered_scope AS
SELECT o.order_id,o.customer_id,o.order_purchase_timestamp,o.order_delivered_customer_date,
 o.order_estimated_delivery_date,c.customer_unique_id,c.customer_state,
 s.merchandise_sales,s.freight_total,s.item_count,
 r.review_score,CASE WHEN r.order_id IS NULL THEN 0 ELSE 1 END has_valid_review
FROM dbo.orders o JOIN dbo.customers c ON c.customer_id=o.customer_id
LEFT JOIN dbo.vw_order_sales s ON s.order_id=o.order_id
LEFT JOIN dbo.vw_one_review_per_order r ON r.order_id=o.order_id
WHERE o.order_status='delivered' AND o.order_purchase_timestamp >= '20170101'
AND o.order_purchase_timestamp < '20180901';
GO
CREATE OR ALTER VIEW dbo.vw_customer_latest_state AS
WITH ranked AS (
 SELECT customer_unique_id,customer_state,
 ROW_NUMBER() OVER(PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp DESC,order_id DESC) rn
 FROM dbo.vw_delivered_scope
)
SELECT customer_unique_id,customer_state FROM ranked WHERE rn=1;
GO
CREATE OR ALTER VIEW dbo.vw_customer_spend AS
SELECT customer_unique_id,COUNT(DISTINCT order_id) AS distinct_orders,
 CAST(SUM(merchandise_sales) AS decimal(19,2)) AS total_spend,
 CAST(SUM(merchandise_sales)/NULLIF(COUNT(DISTINCT order_id),0) AS decimal(19,2)) AS customer_aov
FROM dbo.vw_delivered_scope GROUP BY customer_unique_id;
GO
CREATE OR ALTER VIEW dbo.vw_category_items AS
SELECT d.order_id,d.customer_unique_id,oi.product_id,CAST(oi.price AS decimal(19,2)) price,
 COALESCE(t.product_category_name_english,p.product_category_name,'unknown') category_name
FROM dbo.vw_delivered_scope d JOIN dbo.order_items oi ON oi.order_id=d.order_id
JOIN dbo.products p ON p.product_id=oi.product_id
LEFT JOIN dbo.category_translation t ON t.product_category_name=p.product_category_name;
GO
