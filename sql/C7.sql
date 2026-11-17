USE OlistDB;
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
