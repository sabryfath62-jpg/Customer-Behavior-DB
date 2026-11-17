
USE OlistDB;
GO

-- ============================================
-- C5: Category X But Not Category Y
-- Track C: Customer Behavior
-- Delivered Orders Only
-- ============================================

-- X = bed_bath_table
-- Y = health_beauty

-- STEP 1: Prepare customer-category pairs

DROP TABLE IF EXISTS #C5Pairs;

SELECT DISTINCT
    customer_unique_id,
    category_name
INTO #C5Pairs
FROM dbo.vw_category_items
WHERE category_name IN
(
    'bed_bath_table',
    'health_beauty'
);

-- Improve lookup performance
CREATE UNIQUE CLUSTERED INDEX IX_C5Pairs
ON #C5Pairs(customer_unique_id, category_name);


-- STEP 2: Identify customer segments

DROP TABLE IF EXISTS #C5Segments;

SELECT
    c.customer_unique_id,
    c.total_spend,
    c.distinct_orders,

    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM #C5Pairs p
            WHERE p.customer_unique_id =
                  c.customer_unique_id
              AND p.category_name = 'health_beauty'
        )
        THEN 'X and Y'

        WHEN NOT EXISTS
        (
            SELECT 1
            FROM #C5Pairs p
            WHERE p.customer_unique_id =
                  c.customer_unique_id
              AND p.category_name = 'health_beauty'
        )
        THEN 'X but not Y'
    END AS segment

INTO #C5Segments

FROM dbo.vw_customer_spend c

WHERE EXISTS
(
    SELECT 1
    FROM #C5Pairs p
    WHERE p.customer_unique_id =
          c.customer_unique_id
      AND p.category_name = 'bed_bath_table'
);


-- STEP 3: Final comparison

SELECT
    segment,

    COUNT(*) AS total_customers,

    SUM(distinct_orders) AS total_orders,

    CAST(
        SUM(total_spend) AS DECIMAL(19,2)
    ) AS total_sales,

    CAST(
        AVG(total_spend) AS DECIMAL(19,2)
    ) AS avg_customer_spend,

    SUM(
        CASE
            WHEN distinct_orders >= 2 THEN 1
            ELSE 0
        END
    ) AS repeat_customers,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN distinct_orders >= 2 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0)
        AS DECIMAL(9,2)
    ) AS repeat_pct

FROM #C5Segments
GROUP BY segment
ORDER BY segment;
GO
