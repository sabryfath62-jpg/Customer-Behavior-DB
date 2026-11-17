USE OlistDB;
GO
-- ALL 12 OFFICIAL ANALYSES, separate batches; run after 01_views.sql.


-- ========== G1 ==========
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
GO


-- ========== G2 ==========
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
GO


-- ========== G3 ==========
-- G3 | PURPOSE: missing valid review and payment records among delivered orders.
-- Grain: one purchase month; denominators = distinct delivered orders that month.
-- Review validity: score in 1..5 and one selected valid review/order.
-- LEFT JOIN uses a DERIVED TABLE that has ALREADY been aggregated to order grain.
WITH Flags AS (
 SELECT d.order_id,
 DATEFROMPARTS(YEAR(d.order_purchase_timestamp),MONTH(d.order_purchase_timestamp),1) AS purchase_month,
 CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_one_review_per_order r WHERE r.order_id=d.order_id) THEN 1 ELSE 0 END AS has_valid_review,
 CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.order_payments p WHERE p.order_id=d.order_id) THEN 0 ELSE 1 END AS has_payment,
 COALESCE(pay.payment_records,0) AS payment_records
 FROM dbo.vw_delivered_scope d
 LEFT JOIN (SELECT order_id,COUNT_BIG(*) AS payment_records FROM dbo.order_payments GROUP BY order_id) AS pay
   ON pay.order_id=d.order_id
)
SELECT purchase_month,COUNT(*) AS delivered_orders,
 SUM(has_valid_review) AS reviewed_orders,
 SUM(CASE WHEN has_valid_review=0 THEN 1 ELSE 0 END) AS missing_review_orders,
 CAST(100.0*SUM(has_valid_review)/NULLIF(COUNT(*),0) AS decimal(10,2)) AS review_coverage_pct,
 CAST(100.0*SUM(CASE WHEN has_valid_review=0 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(10,2)) AS missing_review_pct,
 SUM(has_payment) AS orders_with_payment,
 SUM(CASE WHEN has_payment=0 THEN 1 ELSE 0 END) AS missing_payment_orders,
 CAST(100.0*SUM(has_payment)/NULLIF(COUNT(*),0) AS decimal(10,2)) AS payment_coverage_pct,
 CAST(100.0*SUM(CASE WHEN has_payment=0 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(10,2)) AS missing_payment_pct
FROM Flags GROUP BY purchase_month ORDER BY purchase_month;
-- Sample of missing matches: EXISTS and NOT EXISTS cover both paths.
SELECT TOP (20) d.order_id,d.order_purchase_timestamp,
 CASE WHEN EXISTS(SELECT 1 FROM dbo.vw_one_review_per_order r WHERE r.order_id=d.order_id) THEN 1 ELSE 0 END AS has_valid_review,
 CASE WHEN EXISTS(SELECT 1 FROM dbo.order_payments p WHERE p.order_id=d.order_id) THEN 1 ELSE 0 END AS has_payment
FROM dbo.vw_delivered_scope d
WHERE NOT EXISTS(SELECT 1 FROM dbo.vw_one_review_per_order r WHERE r.order_id=d.order_id)
   OR NOT EXISTS(SELECT 1 FROM dbo.order_payments p WHERE p.order_id=d.order_id)
ORDER BY d.order_purchase_timestamp,d.order_id;
GO
GO


-- ========== C1 ==========
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
GO


-- ========== C2 ==========
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
GO


-- ========== C3 ==========
-- C3 | Customer grain; assigned state from latest delivered order. Correlated peer average.
WITH peers AS (SELECT c.customer_unique_id,s.customer_state,c.distinct_orders,c.total_spend
FROM dbo.vw_customer_spend c JOIN dbo.vw_customer_latest_state s ON s.customer_unique_id=c.customer_unique_id),
compared AS (SELECT p.*,(SELECT AVG(CAST(p2.total_spend AS decimal(19,4))) FROM peers p2 WHERE p2.customer_state=p.customer_state) state_peer_avg
FROM peers p)
SELECT customer_unique_id,customer_state,distinct_orders,total_spend,
CAST(state_peer_avg AS decimal(19,2)) peer_avg_brl,
CAST(total_spend-state_peer_avg AS decimal(19,2)) difference_brl,
CASE WHEN total_spend>state_peer_avg THEN 1 ELSE 0 END above_state_avg
FROM compared ORDER BY customer_state,difference_brl DESC,customer_unique_id;

-- Optional state summary: one row/state, from customer spend and latest assigned state.
SELECT s.customer_state,COUNT(*) AS customers_n,
 SUM(CASE WHEN c.total_spend > (SELECT AVG(x.total_spend) FROM dbo.vw_customer_spend x
     JOIN dbo.vw_customer_latest_state y ON x.customer_unique_id=y.customer_unique_id
     WHERE y.customer_state=s.customer_state) THEN 1 ELSE 0 END) AS above_mean_buyers,
 SUM(c.total_spend) AS sales_brl
FROM dbo.vw_customer_spend c JOIN dbo.vw_customer_latest_state s ON c.customer_unique_id=s.customer_unique_id
GROUP BY s.customer_state ORDER BY customers_n DESC;
GO


-- ========== C4 ==========
-- C4 | Top 3 categories by distinct customers, then compare buyer groups.
-- Multi-row subquery IN; customers purchasing any top-three category vs other buyers.
WITH top3 AS (SELECT TOP(3) category_name FROM dbo.vw_category_items
GROUP BY category_name ORDER BY COUNT(DISTINCT customer_unique_id) DESC,category_name),
seg AS (SELECT c.customer_unique_id,c.total_spend,c.distinct_orders,
CASE WHEN c.customer_unique_id IN (SELECT DISTINCT i.customer_unique_id FROM dbo.vw_category_items i
WHERE i.category_name IN (SELECT category_name FROM top3)) THEN 'Top 3 category buyer' ELSE 'Other buyer' END segment
FROM dbo.vw_customer_spend c)
SELECT segment,COUNT(*) customers_n,SUM(total_spend) merchandise_sales,
CAST(SUM(total_spend)/NULLIF(COUNT(*),0) AS decimal(19,2)) spend_per_customer,
SUM(CASE WHEN distinct_orders>=2 THEN 1 ELSE 0 END) repeat_customers,
CAST(100.0*SUM(CASE WHEN distinct_orders>=2 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(9,2)) repeat_pct
FROM seg GROUP BY segment ORDER BY segment;
-- Supporting top-three categories evidence
SELECT TOP(3) category_name,COUNT(DISTINCT customer_unique_id) distinct_customers,
COUNT(DISTINCT order_id) orders_n FROM dbo.vw_category_items GROUP BY category_name
ORDER BY distinct_customers DESC,category_name;
GO


-- ========== C5 ==========
-- C5 | Category X vs Y selected deterministically as top 2 categories by distinct orders.
-- Verify substantial order counts from second result set before interpreting.
WITH ranked AS (SELECT TOP(2) category_name,COUNT(DISTINCT order_id) orders_n FROM dbo.vw_category_items
GROUP BY category_name ORDER BY COUNT(DISTINCT order_id) DESC,category_name),
xy AS (SELECT category_name,ROW_NUMBER() OVER(ORDER BY orders_n DESC,category_name) rn FROM ranked),
seg AS (SELECT c.customer_unique_id,c.total_spend,c.distinct_orders,
CASE WHEN EXISTS(SELECT 1 FROM dbo.vw_category_items i WHERE i.customer_unique_id=c.customer_unique_id
AND i.category_name=(SELECT category_name FROM xy WHERE rn=1))
AND EXISTS(SELECT 1 FROM dbo.vw_category_items i WHERE i.customer_unique_id=c.customer_unique_id
AND i.category_name=(SELECT category_name FROM xy WHERE rn=2)) THEN 'Both X and Y'
WHEN EXISTS(SELECT 1 FROM dbo.vw_category_items i WHERE i.customer_unique_id=c.customer_unique_id
AND i.category_name=(SELECT category_name FROM xy WHERE rn=1))
AND NOT EXISTS(SELECT 1 FROM dbo.vw_category_items i WHERE i.customer_unique_id=c.customer_unique_id
AND i.category_name=(SELECT category_name FROM xy WHERE rn=2)) THEN 'X but not Y' ELSE 'Other' END segment
FROM dbo.vw_customer_spend c)
SELECT segment,COUNT(*) customers_n,SUM(total_spend) sales,
CAST(AVG(total_spend) AS decimal(19,2)) spend_per_customer,
SUM(CASE WHEN distinct_orders>=2 THEN 1 ELSE 0 END) repeat_customers
FROM seg WHERE segment IN ('Both X and Y','X but not Y') GROUP BY segment;
SELECT TOP(2) category_name,COUNT(DISTINCT order_id) orders_n
FROM dbo.vw_category_items GROUP BY category_name
ORDER BY orders_n DESC,category_name;
-- No observed Y purchase is NOT proof of lack of interest.
GO


-- ========== C6 ==========
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
GO


-- ========== C7 ==========
-- C7 | Distinct delivered-order denominator for delivery and coverage; reviewed order denominator for low-rating rate.
-- Delivery elapsed days uses fractional days, late uses calendar date comparison.
WITH classified AS (SELECT d.*,
CASE WHEN c.distinct_orders=1 THEN 'Single order' ELSE 'Repeat customer' END segment,
CASE WHEN d.order_delivered_customer_date IS NOT NULL AND d.order_estimated_delivery_date IS NOT NULL
AND d.order_delivered_customer_date>=d.order_purchase_timestamp THEN 1 ELSE 0 END valid_delivery,
CASE WHEN d.order_delivered_customer_date IS NOT NULL AND d.order_estimated_delivery_date IS NOT NULL
AND d.order_delivered_customer_date>=d.order_purchase_timestamp
AND CAST(d.order_delivered_customer_date AS date)>CAST(d.order_estimated_delivery_date AS date) THEN 1 ELSE 0 END late_flag
FROM dbo.vw_delivered_scope d JOIN dbo.vw_customer_spend c ON c.customer_unique_id=d.customer_unique_id)
SELECT segment,COUNT(*) delivered_orders,
SUM(valid_delivery) eligible_delivery_orders,COUNT(*)-SUM(valid_delivery) excluded_delivery_orders,
SUM(CASE WHEN valid_delivery=1 THEN late_flag ELSE 0 END) late_orders,
CAST(100.0*SUM(CASE WHEN valid_delivery=1 THEN late_flag ELSE 0 END)/NULLIF(SUM(valid_delivery),0) AS decimal(9,2)) late_pct,
CAST(AVG(CASE WHEN valid_delivery=1 THEN DATEDIFF(SECOND,order_purchase_timestamp,order_delivered_customer_date)/86400.0 END) AS decimal(10,2)) avg_delivery_days,
SUM(has_valid_review) reviewed_orders,
CAST(100.0*SUM(has_valid_review)/NULLIF(COUNT(*),0) AS decimal(9,2)) review_coverage_pct,
SUM(CASE WHEN review_score IN(1,2) THEN 1 ELSE 0 END) low_rated_orders,
CAST(100.0*SUM(CASE WHEN review_score IN(1,2) THEN 1 ELSE 0 END)/NULLIF(SUM(has_valid_review),0) AS decimal(9,2)) low_rating_pct,
CAST(AVG(CAST(review_score AS float)) AS decimal(9,2)) mean_rating
FROM classified GROUP BY segment;
-- Observation window limits lifetime repeat classification; no causal interpretation.
GO


-- ========== O1 ==========
-- O1 | Additional question: How does repeat-buyer share vary by latest customer state?
-- Audience: regional CRM; customer grain; minimum 30 customers for action-grade comparisons.
SELECT s.customer_state,COUNT(*) customers_n,SUM(CASE WHEN c.distinct_orders>=2 THEN 1 ELSE 0 END) repeat_customers,
CAST(100.0*SUM(CASE WHEN c.distinct_orders>=2 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(9,2)) repeat_pct,
CASE WHEN COUNT(*)>=30 THEN 'Comparison eligible' ELSE 'Exploratory (<30)' END sample_flag
FROM dbo.vw_customer_spend c JOIN dbo.vw_customer_latest_state s ON s.customer_unique_id=c.customer_unique_id
GROUP BY s.customer_state ORDER BY customers_n DESC;
GO


-- ========== O2 ==========
-- O2 | Additional question: How does spend vary by purchase-frequency band?
-- Audience: customer insights; customer grain; band 1, 2, 3+ delivered orders.
WITH bands AS (SELECT *,CASE WHEN distinct_orders=1 THEN '1 order' WHEN distinct_orders=2 THEN '2 orders' ELSE '3+ orders' END band
FROM dbo.vw_customer_spend)
SELECT band,COUNT(*) customers_n,SUM(distinct_orders) delivered_orders,SUM(total_spend) sales,
CAST(AVG(total_spend) AS decimal(19,2)) avg_spend_per_customer,
CAST(100.0*SUM(total_spend)/NULLIF(SUM(SUM(total_spend)) OVER(),0) AS decimal(9,2)) sales_share_pct
FROM bands GROUP BY band ORDER BY MIN(distinct_orders);
GO
