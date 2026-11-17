USE OlistDB;
-- O1 | Additional question: How does repeat-buyer share vary by latest customer state?
-- Audience: regional CRM; customer grain; minimum 30 customers for action-grade comparisons.
SELECT s.customer_state,COUNT(*) customers_n,SUM(CASE WHEN c.distinct_orders>=2 THEN 1 ELSE 0 END) repeat_customers,
CAST(100.0*SUM(CASE WHEN c.distinct_orders>=2 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(9,2)) repeat_pct,
CASE WHEN COUNT(*)>=30 THEN 'Comparison eligible' ELSE 'Exploratory (<30)' END sample_flag
FROM dbo.vw_customer_spend c JOIN dbo.vw_customer_latest_state s ON s.customer_unique_id=c.customer_unique_id
GROUP BY s.customer_state ORDER BY customers_n DESC;
