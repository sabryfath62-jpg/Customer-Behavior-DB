USE OlistDB;
GO
-- C6 | PURPOSE: first vs second delivered purchases; grain = one row per repeat customer.
-- Input: dbo.vw_delivered_scope; 2017-01-01 <= purchase timestamp < 2018-09-01.
-- ROW_NUMBER partitions by customer_unique_id, ordered by timestamp then order_id to break ties.
-- #FirstSecond retains the pair set across two SELECT statements (a CTE would expire).
IF OBJECT_ID('tempdb..#FirstSecond') IS NOT NULL DROP TABLE #FirstSecond;
WITH RankedOrders AS (
 SELECT customer_unique_id, order_id, order_purchase_timestamp, merchandise_sales,
 ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp,order_id) AS rn
 FROM dbo.vw_delivered_scope
)
SELECT first_order.customer_unique_id,
 first_order.order_id AS first_order_id, second_order.order_id AS second_order_id,
 first_order.merchandise_sales AS first_order_value,
 second_order.merchandise_sales AS second_order_value,
 DATEDIFF(DAY,first_order.order_purchase_timestamp,second_order.order_purchase_timestamp) AS gap_calendar_days,
 CASE WHEN second_order.merchandise_sales > first_order.merchandise_sales THEN 1 ELSE 0 END AS larger_second_order
INTO #FirstSecond
FROM RankedOrders AS first_order
INNER JOIN RankedOrders AS second_order
 ON first_order.customer_unique_id = second_order.customer_unique_id
 AND first_order.rn = 1 AND second_order.rn = 2;

-- Summary: sum and count retained so Excel can recompute averages.
SELECT COUNT(*) AS repeat_customers,
 COUNT(first_order_value) AS first_value_known,
 COUNT(second_order_value) AS second_value_known,
 SUM(first_order_value) AS first_value_sum_brl,
 SUM(second_order_value) AS second_value_sum_brl,
 CAST(SUM(first_order_value)/NULLIF(COUNT(first_order_value),0) AS decimal(19,2)) AS avg_first_value_brl,
 CAST(SUM(second_order_value)/NULLIF(COUNT(second_order_value),0) AS decimal(19,2)) AS avg_second_value_brl,
 SUM(CAST(gap_calendar_days AS bigint)) AS gap_days_sum,
 CAST(AVG(CAST(gap_calendar_days AS float)) AS decimal(10,2)) AS avg_gap_calendar_days,
 SUM(CASE WHEN first_order_value IS NOT NULL AND second_order_value IS NOT NULL THEN 1 ELSE 0 END) AS comparable_pairs,
 SUM(CASE WHEN first_order_value IS NOT NULL AND second_order_value IS NOT NULL AND larger_second_order=1 THEN 1 ELSE 0 END) AS larger_second_count,
 CAST(100.0*SUM(CASE WHEN first_order_value IS NOT NULL AND second_order_value IS NOT NULL AND larger_second_order=1 THEN 1 ELSE 0 END)
 /NULLIF(SUM(CASE WHEN first_order_value IS NOT NULL AND second_order_value IS NOT NULL THEN 1 ELSE 0 END),0) AS decimal(10,2)) AS larger_second_pct
FROM #FirstSecond;
-- Evidence sample (this SELECT is valid because #FirstSecond persists in the session).
SELECT TOP (50) * FROM #FirstSecond ORDER BY customer_unique_id;
DROP TABLE #FirstSecond;
GO
