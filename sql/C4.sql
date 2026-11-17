
USE OlistDB;
GO

-- ============================================
-- C4: Who Purchases from Popular Categories?
-- Track C: Customer Behavior
-- Period: 2017-01-01 to 2018-08-31
-- Delivered Orders Only
-- ============================================

-- STEP 1: Unique customer-category pairs
-- Grain: One row per customer and category

DROP TABLE IF EXISTS #CategoryPairs;

SELECT DISTINCT
    customer_unique_id,
    category_name
INTO #CategoryPairs
FROM dbo.vw_category_items;

-- STEP 2: Top 3 categories by distinct buyers

DROP TABLE IF EXISTS #Top3;

SELECT TOP (3)
    category_name,
    COUNT(*) AS distinct_customers
INTO #Top3
FROM #CategoryPairs
GROUP BY category_name
ORDER BY COUNT(*) DESC, category_name;

-- Result 1: Top 3 Categories
SELECT *
FROM #Top3
ORDER BY distinct_customers DESC;

-- STEP 3: Identify buyers of top 3 categories
-- Required SQL topic: Multi-row Subquery (IN)

DROP TABLE IF EXISTS #Top3Buyers;

SELECT DISTINCT
    customer_unique_id
INTO #Top3Buyers
FROM #CategoryPairs
WHERE category_name IN
(
    SELECT category_name
    FROM #Top3
);

-- STEP 4: Compare customer segments
-- Grain: One row per customer segment

DROP TABLE IF EXISTS #C4Results;

SELECT
    CASE
        WHEN b.customer_unique_id IS NOT NULL
        THEN 'Top 3 Category Buyer'
        ELSE 'Other Buyer'
    END AS customer_segment,

    COUNT(*) AS total_customers,

    SUM(c.distinct_orders) AS total_orders,

    CAST(
        SUM(c.total_spend)
        AS DECIMAL(19,2)
    ) AS total_sales,

    CAST(
        AVG(c.total_spend)
        AS DECIMAL(19,2)
    ) AS avg_spend_per_customer,

    SUM(
        CASE WHEN c.distinct_orders >= 2
        THEN 1 ELSE 0 END
    ) AS repeat_customers,

    CAST(
        100.0 * SUM(
            CASE WHEN c.distinct_orders >= 2
            THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0)
        AS DECIMAL(9,2)
    ) AS repeat_purchase_pct

INTO #C4Results
FROM dbo.vw_customer_spend c

LEFT JOIN #Top3Buyers b
    ON c.customer_unique_id = b.customer_unique_id

GROUP BY
    CASE
        WHEN b.customer_unique_id IS NOT NULL
        THEN 'Top 3 Category Buyer'
        ELSE 'Other Buyer'
    END;

-- Result 2: Final Customer Comparison
SELECT *
FROM #C4Results
ORDER BY customer_segment;

-- STEP 5: Validate totals
SELECT
    SUM(total_customers) AS total_customers,
    SUM(total_orders) AS total_orders,
    SUM(total_sales) AS total_revenue,
    SUM(repeat_customers) AS repeat_customers
FROM #C4Results;
GO