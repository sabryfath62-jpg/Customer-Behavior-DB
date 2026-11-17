# Question-to-evidence register

All 12 required questions have T-SQL files `sql/G1.sql`, `G2.sql`, `G3.sql`, `C1.sql`-`C7.sql`, `O1.sql`, `O2.sql` and supporting CSV exports in `results/`. Query-level result tables, purpose, interpretations, limitations and actions are in `report/Track_C_Final_Findings.pdf`. Original source tables are not uploaded to GitHub.

| ID | Analytical output grain | Primary CSV evidence |
|---|---|---|
| G1 | Order status, delivered population | `G1_status.csv`, `G1_delivered.csv` |
| G2 | Purchase month | `G2_monthly.csv` |
| G3 | Purchase month / delivered order | `G3_monthly.csv` |
| C1 | Customer and equal-count quartile | `C1_customer_detail.csv`, `C1_segments.csv` |
| C2 | Buyer / consecutive pair | `C2_repeat.csv`, `purchase_frequency_supporting_observed.csv` |
| C3 | One buyer / assigned latest state | `C3_customer_state_comparison.csv`, `C3_state_summary.csv` |
| C4 | Buyer category group (top 3) | `C4_top_categories.csv`, `C4_popular_categories.csv` |
| C5 | X but not Y / both X and Y | `C5_category_X_Y.csv` |
| C6 | First two purchases | `C6_first_second.csv` |
| C7 | Single-order vs repeat | `C7_experience.csv` |
| O1 | State assigned from latest delivery | `O1_state_repeat.csv` |
| O2 | Orders-per-customer band | `O2_frequency_spend.csv` |

`dashboard_month_group.csv` is an explicit 40-row SQL dashboard export grain (month x observed customer group), and `sql/04_dashboard_exports.sql` reproduces that view.
