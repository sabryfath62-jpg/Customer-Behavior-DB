USE OlistDB;
-- C2 | Customer grain: observed repeat share; delivered orders only.
SELECT COUNT(*) customers_n,SUM(CASE WHEN distinct_orders=1 THEN 1 ELSE 0 END) single_buyers,
SUM(CASE WHEN distinct_orders>=2 THEN 1 ELSE 0 END) repeat_buyers,
CAST(100.0*SUM(CASE WHEN distinct_orders>=2 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(9,2)) repeat_pct
FROM dbo.vw_customer_spend;
-- Grain: consecutive purchase pair, ties ordered by order_id.
WITH ordered AS (SELECT customer_unique_id,order_id,order_purchase_timestamp,
LAG(order_purchase_timestamp) OVER(PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp,order_id) prior_date
FROM dbo.vw_delivered_scope), gaps AS (SELECT customer_unique_id,DATEDIFF(DAY,prior_date,order_purchase_timestamp) gap_days
FROM ordered WHERE prior_date IS NOT NULL)
SELECT COUNT(*) pairs_n,COUNT(DISTINCT customer_unique_id) repeat_buyers,
SUM(CAST(gap_days AS bigint)) gap_days_sum,CAST(AVG(CAST(gap_days AS float)) AS decimal(10,2)) avg_gap_days,
MIN(gap_days) min_gap,MAX(gap_days) max_gap FROM gaps;
