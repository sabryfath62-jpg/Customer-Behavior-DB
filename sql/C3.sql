USE OlistDB;
GO
-- C3 | Customers above their assigned state average.
-- Input/output grain: one row per unique buyer in the first query;
--                     one row per state in the second query.
-- Eligible orders: delivered, purchased [2017-01-01, 2018-09-01).
-- vw_customer_latest_state already assigns each buyer to the state
-- of their latest delivered in-scope order.
-- Monetary amounts are BRL merchandise sales, excluding freight.

-- C3a: Detailed per-customer evidence, including correlated subquery.
WITH peers AS
(
    SELECT c.customer_unique_id, s.customer_state,
           c.distinct_orders, c.total_spend
    FROM dbo.vw_customer_spend AS c
    INNER JOIN dbo.vw_customer_latest_state AS s
        ON c.customer_unique_id = s.customer_unique_id
),
compared AS
(
    SELECT p.*,
           (SELECT AVG(CAST(p2.total_spend AS DECIMAL(19,4)))
            FROM peers AS p2
            WHERE p2.customer_state = p.customer_state) AS state_peer_avg
    FROM peers AS p
)
SELECT customer_unique_id,
       customer_state,
       distinct_orders,
       total_spend,
       CAST(state_peer_avg AS DECIMAL(19,2)) AS peer_avg_brl,
       CAST(total_spend - state_peer_avg AS DECIMAL(19,2)) AS difference_brl,
       CASE WHEN total_spend > state_peer_avg THEN 1 ELSE 0 END AS above_state_avg
FROM compared
ORDER BY customer_state, difference_brl DESC, customer_unique_id;
GO

-- C3b: State summary. Calculate peer average before SUM(CASE ...).
-- A scalar subquery cannot be nested inside a SUM expression in SQL Server.
WITH peers AS
(
    SELECT c.customer_unique_id, s.customer_state, c.total_spend
    FROM dbo.vw_customer_spend AS c
    INNER JOIN dbo.vw_customer_latest_state AS s
        ON c.customer_unique_id = s.customer_unique_id
),
scored AS
(
    SELECT customer_unique_id, customer_state, total_spend,
           AVG(CAST(total_spend AS DECIMAL(19,4)))
               OVER (PARTITION BY customer_state) AS state_peer_avg
    FROM peers
)
SELECT customer_state,
       COUNT(*) AS customers_n,
       SUM(CASE WHEN total_spend > state_peer_avg THEN 1 ELSE 0 END)
           AS above_mean_buyers,
       CAST(SUM(total_spend) AS DECIMAL(19,2)) AS sales_brl
FROM scored
GROUP BY customer_state
ORDER BY customers_n DESC, customer_state;
GO

-- C3c: Reconciliation against prior confirmed results.
WITH peers AS
(
    SELECT c.customer_unique_id, s.customer_state, c.total_spend
    FROM dbo.vw_customer_spend AS c
    INNER JOIN dbo.vw_customer_latest_state AS s
        ON c.customer_unique_id = s.customer_unique_id
),
scored AS
(
    SELECT total_spend,
           AVG(CAST(total_spend AS DECIMAL(19,4)))
               OVER (PARTITION BY customer_state) AS state_peer_avg
    FROM peers
)
SELECT COUNT(*) AS total_customers,
       SUM(CASE WHEN total_spend > state_peer_avg THEN 1 ELSE 0 END)
           AS above_average_customers,
       CAST(100.0 * SUM(CASE WHEN total_spend > state_peer_avg THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) AS DECIMAL(9,2)) AS above_average_pct,
       CAST(SUM(total_spend) AS DECIMAL(19,2)) AS total_revenue_brl
FROM scored;
GO
