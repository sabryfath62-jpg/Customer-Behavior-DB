# SQL topic coverage map (Page 17 of assignment)

| Required topic | Question ID | Script | Evidence / meaning |
|---|---|---|---|
| Join at least 3 tables | C4 | `sql/01_views.sql`, `sql/C4.sql` | Orders -> customers -> item -> product -> translated category |
| LEFT JOIN preserving unmatched | G3 | `sql/G3.sql` | Delivered orders left joined to per-order payment summary |
| Advanced join: self-join | C6 | `sql/C6.sql` | First order self-joined to second order for same unique buyer |
| Scalar subquery | G1 | `sql/G1.sql` | Denominator: all in-scope orders by status |
| Multi-row subquery | C4 | `sql/C4.sql` | `IN (SELECT...)` top-three categories by distinct buyers |
| Derived table | G3 | `sql/G3.sql` | `(SELECT ... GROUP BY order_id) AS pay` to avoid multiplying payments |
| Correlated subquery | C3 | `sql/C3.sql` | Average spend of other buyers in assigned state |
| EXISTS and NOT EXISTS | C5 / G3 | `sql/C5.sql`, `sql/G3.sql` | X purchased but Y not observed; review/payment coverage |
| Two or more CTEs | G2 / C6 | `sql/G2.sql`, `sql/C6.sql` | Calendar -> monthly -> lagged sales; order pair sequence |
| Ranking/window function | C1/C6 | `sql/C1.sql`, `sql/C6.sql` | NTILE(4), ROW_NUMBER() |
| LAG/LEAD | G2, C2 | `sql/G2.sql`, `sql/C2.sql` | Prior month / previous purchase date |
| SUM OVER aggregate | G2 | `sql/G2.sql` | Running merchandise sales in purchase-month order |

Each analysis script identifies the question and source views; the README describes run order and metric rules.
