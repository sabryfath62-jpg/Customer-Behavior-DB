USE OlistDB;
-- O2 | Additional question: How does spend vary by purchase-frequency band?
-- Audience: customer insights; customer grain; band 1, 2, 3+ delivered orders.
WITH bands AS (SELECT *,CASE WHEN distinct_orders=1 THEN '1 order' WHEN distinct_orders=2 THEN '2 orders' ELSE '3+ orders' END band
FROM dbo.vw_customer_spend)
SELECT band,COUNT(*) customers_n,SUM(distinct_orders) delivered_orders,SUM(total_spend) sales,
CAST(AVG(total_spend) AS decimal(19,2)) avg_spend_per_customer,
CAST(100.0*SUM(total_spend)/NULLIF(SUM(SUM(total_spend)) OVER(),0) AS decimal(9,2)) sales_share_pct
FROM bands GROUP BY band ORDER BY MIN(distinct_orders);
