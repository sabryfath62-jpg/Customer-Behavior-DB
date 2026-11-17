USE OlistDB;
-- G2 | Month grain: full 20-month calendar; running sales, MoM and AOV.
WITH months AS (SELECT CAST('20170101' AS date) m UNION ALL SELECT DATEADD(MONTH,1,m) FROM months WHERE m<'20180801'),
monthly AS (SELECT DATEFROMPARTS(YEAR(order_purchase_timestamp),MONTH(order_purchase_timestamp),1) m,
COUNT(DISTINCT order_id) orders_n,SUM(merchandise_sales) sales FROM dbo.vw_delivered_scope
GROUP BY DATEFROMPARTS(YEAR(order_purchase_timestamp),MONTH(order_purchase_timestamp),1)),
series AS (SELECT m.m,COALESCE(x.orders_n,0) orders_n,COALESCE(x.sales,0) sales FROM months m LEFT JOIN monthly x ON x.m=m.m),
lagged AS (SELECT *,LAG(sales) OVER(ORDER BY m) prev_sales,SUM(sales) OVER(ORDER BY m ROWS UNBOUNDED PRECEDING) running_sales FROM series)
SELECT m purchase_month,orders_n,sales,CAST(sales/NULLIF(orders_n,0) AS decimal(19,2)) aov_brl,
prev_sales,CAST(100.0*(sales-prev_sales)/NULLIF(prev_sales,0) AS decimal(10,2)) mom_growth_pct,running_sales
FROM lagged ORDER BY m OPTION(MAXRECURSION 30);
