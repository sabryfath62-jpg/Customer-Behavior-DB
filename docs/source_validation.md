# Source checks, QA and cleaning decisions

The original uploaded Olist archive contains the following non-header record counts: customers 99,441; orders 99,441; order_items 112,650; order_payments 103,886; order_reviews 99,224; products 32,951; sellers 3,095; product_category_name_translation **71**; optional geolocation 1,000,163.

## Results established from the student's SSMS screenshots

- Candidate key duplicates: orders, customers, products, sellers = 0; item/payment composite key checks = 0 (previously checked with concatenation; `02_validation.sql` additionally tests direct `(id,sequence)` grouping).
- Unmatched orders->customers, items->orders/products/sellers, payments->orders, reviews->orders = 0 for inspected links.
- 2,965 orders have no delivery timestamp; of these, 8 are status `delivered`. They remain in order/revenue populations and are excluded from duration denominators.
- 610 product records have blank category; review titles are missing for 87,666 rows and messages for 58,274, which does not invalidate scores.
- Original review rows = 99,224; distinct reviewed orders = 98,673; 547 orders have multiple review rows (551 extra rows); repeated review_id rows = 814, and no full timestamp/ID ordering ties detected. Source reviews must not be discarded.
- In-scope orders (all statuses) = 99,092; outside = 349; delivered in-scope = 96,211; merchandise revenue = BRL 13,181,027.13; distinct buyers = 93,104; repeat buyers = 2,789.
- Orders with no items = 775, all non-delivered (unavailable 603; canceled 164; created 5; invoiced 2; shipped 1).
- No negative item price, freight, payment or review score outside 1..5 was found. 383 zero-freight item rows; 9 zero-value payments (6 voucher, 3 not_defined); 2 zero-installment credit-card payments. Preserve and document rather than invent replacements.
- 36 unique buyers have delivered orders assigned to more than one state; use last delivered purchase to assign a state for customer comparisons.

## Unresolved discrepancies and mitigations

1. The original `product_category_name_translation.csv` contains **71 data rows**, while one SSMS import summary previously reported 72. Recheck header/blank row handling on the student's SQL instance (`SELECT COUNT(*) FROM dbo.category_translation`). The SQL queries use the source mapping; a duplicate/header record must not be treated as a real category.
2. Some SQL imported column types were `FLOAT` for price/freight, numeric-looking product fields imported as text, and seller/customer ZIP prefixes imported as `INT`. View layer converts money to DECIMAL; recommended schema uses character ZIP codes to preserve leading zeros. Existing source tables are not altered.
3. SSMS screenshot showed `review_comment_message` as NVARCHAR(250). The original CSV permits longer/multiline review text. Check whether import truncated review comments and reimport that column with NVARCHAR(MAX) if necessary. Numeric review scores remain suitable for Track C even where comments are truncated.
4. The imported review table has no immutable source row index. Previous tests found zero ties among valid reviews on the full choice fields; if newer data introduces a tie, add source-row index to staging and update selection order. Do not claim perfect tie handling without it.
5. SQL Server statements are authored for the named `OlistDB` schema. Results were computed from source CSVs and reconciled to the student's screenshots, but the final scripts were **not executed against that live SQL Server instance here**. The submitting team must run the complete script on local SSMS and compare the outputs.

Rules: Never delete all NULL rows. Never SUM(DISTINCT price) to fix multiplied joins. Use distinct order/customer denominators and complete calendar months for month-over-month comparison. Decisions based on rate comparisons with fewer than 30 eligible observations are exploratory only. No causal claims or lifetime churn can be inferred.
