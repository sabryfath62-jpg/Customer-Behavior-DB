USE OlistDB;
GO
-- DASHBOARD INPUT 1: one row per purchase month x observed lifetime-in-window customer group.
-- NOTE: repeat group is classified from all delivered orders in fixed analysis period, NOT monthly repeats.
SELECT CONVERT(char(7), d.order_purchase_timestamp,120) AS purchase_month,
 CASE WHEN c.distinct_orders >= 2 THEN 'Repeat' ELSE 'Single' END AS customer_group,
 COUNT(*) AS delivered_orders,
 CAST(SUM(d.merchandise_sales) AS decimal(19,2)) AS merchandise_sales_brl,
 SUM(d.has_valid_review) AS reviewed_orders
FROM dbo.vw_delivered_scope d JOIN dbo.vw_customer_spend c ON c.customer_unique_id=d.customer_unique_id
GROUP BY CONVERT(char(7), d.order_purchase_timestamp,120),
 CASE WHEN c.distinct_orders >= 2 THEN 'Repeat' ELSE 'Single' END
ORDER BY purchase_month,customer_group;

-- DASHBOARD INPUT 2: purchasing customers / value quartile (fixed full-window baseline).
WITH q AS (SELECT customer_unique_id,total_spend,distinct_orders,
 NTILE(4) OVER(ORDER BY total_spend,customer_unique_id) AS quartile FROM dbo.vw_customer_spend)
SELECT quartile,COUNT(*) AS customers_n,SUM(distinct_orders) AS delivered_orders,
 SUM(total_spend) AS revenue_brl,CAST(100.0*SUM(total_spend)/NULLIF(SUM(SUM(total_spend)) OVER(),0) AS decimal(10,2)) AS revenue_share_pct
FROM q GROUP BY quartile ORDER BY quartile;

-- DASHBOARD INPUT 3: frequency distribution (fixed full-window baseline).
SELECT distinct_orders AS orders_per_customer,COUNT(*) AS customers_n
FROM dbo.vw_customer_spend GROUP BY distinct_orders ORDER BY distinct_orders;
GO
