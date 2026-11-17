USE OlistDB;
-- C1 | Customer grain, spend / orders / per-customer AOV; quartiles equal-sized by count.
WITH segmented AS (SELECT *,NTILE(4) OVER(ORDER BY total_spend,customer_unique_id) quartile FROM dbo.vw_customer_spend)
SELECT quartile,COUNT(*) customers_n,SUM(distinct_orders) orders_n,
SUM(total_spend) sales,CAST(AVG(total_spend) AS decimal(19,2)) avg_spend_per_customer,
CAST(SUM(total_spend)/NULLIF(SUM(distinct_orders),0) AS decimal(19,2)) segment_aov,
CAST(100.0*SUM(total_spend)/NULLIF(SUM(SUM(total_spend)) OVER(),0) AS decimal(9,2)) sales_share_pct,
MIN(total_spend) min_spend,MAX(total_spend) max_spend
FROM segmented GROUP BY quartile ORDER BY quartile;
-- Detail export for customer totals / per-customer AOV.
SELECT customer_unique_id,distinct_orders,total_spend,customer_aov FROM dbo.vw_customer_spend ORDER BY total_spend DESC,customer_unique_id;
