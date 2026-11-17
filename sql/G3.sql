USE OlistDB;
GO
-- G3 | Delivered-order review/payment coverage by purchase month.
-- Scope: orders purchased 2017-01-01 through 2018-08-31; delivered only.
-- Grain: one row per order in #G3Orders / #G3Flags; one row per month in final summary.
-- Review coverage means existence of at least one valid score (1..5).
-- #G3ValidReviews is one row per reviewed order, equivalent to the
-- existence/coverage status of the one-valid-review-per-order analysis view.
-- Payment coverage means at least one payment record (not payment success).

DROP TABLE IF EXISTS #G3Orders;
DROP TABLE IF EXISTS #G3ValidReviews;
DROP TABLE IF EXISTS #G3Payments;
DROP TABLE IF EXISTS #G3Flags;

-- 1. Materialize the eligible population once.
SELECT
    o.order_id,
    o.order_purchase_timestamp,
    DATEFROMPARTS(YEAR(o.order_purchase_timestamp),
                  MONTH(o.order_purchase_timestamp),1) AS purchase_month
INTO #G3Orders
FROM dbo.orders AS o
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170101'
  AND o.order_purchase_timestamp < '20180901';

CREATE UNIQUE CLUSTERED INDEX IX_G3Orders ON #G3Orders(order_id);

-- 2. One row per order with a VALID review.
SELECT r.order_id
INTO #G3ValidReviews
FROM dbo.order_reviews AS r
INNER JOIN #G3Orders AS o ON o.order_id = r.order_id
WHERE r.review_score BETWEEN 1 AND 5
GROUP BY r.order_id;

CREATE UNIQUE CLUSTERED INDEX IX_G3Reviews ON #G3ValidReviews(order_id);

-- 3. Aggregate payment records to the order grain BEFORE joining.
SELECT p.order_id, COUNT_BIG(*) AS payment_records
INTO #G3Payments
FROM dbo.order_payments AS p
INNER JOIN #G3Orders AS o ON o.order_id = p.order_id
GROUP BY p.order_id;

CREATE UNIQUE CLUSTERED INDEX IX_G3Payments ON #G3Payments(order_id);

-- 4. EXISTS and NOT EXISTS on small, indexed order-level tables.
-- LEFT JOIN uses a derived table with one row per order.
SELECT
    o.order_id,
    o.order_purchase_timestamp,
    o.purchase_month,
    CASE WHEN EXISTS (
        SELECT 1 FROM #G3ValidReviews AS r WHERE r.order_id = o.order_id
    ) THEN 1 ELSE 0 END AS has_valid_review,
    CASE WHEN NOT EXISTS (
        SELECT 1 FROM #G3Payments AS p WHERE p.order_id = o.order_id
    ) THEN 0 ELSE 1 END AS has_payment,
    COALESCE(pay.payment_records,CONVERT(BIGINT,0)) AS payment_records
INTO #G3Flags
FROM #G3Orders AS o
LEFT JOIN (
    SELECT order_id, payment_records
    FROM #G3Payments
) AS pay ON pay.order_id = o.order_id;

-- RESULT 1: Monthly coverage, with supporting numerators/denominators.
SELECT
    purchase_month,
    COUNT(*) AS delivered_orders,
    SUM(has_valid_review) AS reviewed_orders,
    SUM(CASE WHEN has_valid_review = 0 THEN 1 ELSE 0 END) AS missing_review_orders,
    CAST(100.0 * SUM(has_valid_review) / NULLIF(COUNT(*),0) AS DECIMAL(10,2)) AS review_coverage_pct,
    CAST(100.0 * SUM(CASE WHEN has_valid_review = 0 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(10,2)) AS missing_review_pct,
    SUM(has_payment) AS orders_with_payment,
    SUM(CASE WHEN has_payment = 0 THEN 1 ELSE 0 END) AS missing_payment_orders,
    CAST(100.0 * SUM(has_payment) / NULLIF(COUNT(*),0) AS DECIMAL(10,2)) AS payment_coverage_pct,
    CAST(100.0 * SUM(CASE WHEN has_payment = 0 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(10,2)) AS missing_payment_pct
FROM #G3Flags
GROUP BY purchase_month
ORDER BY purchase_month;

-- RESULT 2: Small sample of missing-review / missing-payment orders.
SELECT TOP (20)
    order_id, order_purchase_timestamp,
    has_valid_review, has_payment, payment_records
FROM #G3Flags
WHERE has_valid_review = 0 OR has_payment = 0
ORDER BY order_purchase_timestamp, order_id;

-- RESULT 3: Reconciliation against G1 delivered-order denominator.
SELECT
    COUNT(*) AS delivered_orders,
    SUM(has_valid_review) AS orders_with_valid_review,
    SUM(CASE WHEN has_valid_review = 0 THEN 1 ELSE 0 END) AS orders_without_valid_review,
    SUM(has_payment) AS orders_with_payment,
    SUM(CASE WHEN has_payment = 0 THEN 1 ELSE 0 END) AS orders_without_payment
FROM #G3Flags;
GO
