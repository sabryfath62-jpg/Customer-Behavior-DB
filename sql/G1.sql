USE OlistDB;
-- G1 | Grain: order status; denominator: all distinct in-scope orders.
WITH scoped AS (SELECT order_id,order_status FROM dbo.orders WHERE order_purchase_timestamp >= '20170101' AND order_purchase_timestamp<'20180901')
SELECT order_status,COUNT(DISTINCT order_id) orders_n,
CAST(100.0*COUNT(DISTINCT order_id)/(SELECT COUNT(DISTINCT order_id) FROM scoped) AS decimal(9,2)) pct_all_orders
FROM scoped GROUP BY order_status ORDER BY orders_n DESC;
-- Grain: one delivered population summary; sales excludes freight.
SELECT COUNT(DISTINCT order_id) delivered_orders,COUNT(DISTINCT customer_unique_id) distinct_customers,
SUM(merchandise_sales) merchandise_sales,
CAST(SUM(merchandise_sales)/NULLIF(COUNT(DISTINCT order_id),0) AS decimal(19,2)) aov_brl,
SUM(CASE WHEN merchandise_sales IS NULL THEN 1 ELSE 0 END) orders_without_items
FROM dbo.vw_delivered_scope;
