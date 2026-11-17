# Data dictionary, units and analytical grains

## Source tables and join keys

| Source table | Grain | Key candidate | Fields used | Notes |
|---|---|---|---|---|
| customers | Customer record linked to one order | `customer_id` | `customer_unique_id`, `customer_state`, city, zip prefix | People are counted by distinct `customer_unique_id` (not `customer_id`); ZIP prefixes should be text |
| orders | One order | `order_id` | customer_id, status, purchase, approval, delivery and estimated delivery timestamps | Filter **purchase** timestamps 2017-01-01 inclusive to 2018-09-01 exclusive |
| order_items | One item row within order | `(order_id,order_item_id)` | product_id, seller_id, price, freight_value | Item prices are merchandise BRL, freight separate; `order_item_id` is sequence, not quantity |
| products | One product | `product_id` | category, dimensions | Product length fields misspelled `lenght` in CSV; numeric attributes may have imported as text |
| sellers | One seller | `seller_id` | seller_state, seller_city | Not central to Track C |
| order_payments | One payment record | `(order_id,payment_sequential)` | value, type, installments | Multiple payments/order; payment installments are not repeated payment rows |
| order_reviews | One source review row | review_id *not globally unique* | order_id, review_score, creation & answer timestamps, comments | Preserve all; choose one valid score (1-5) per order |
| category_translation | Category mapping | product_category_name | English translation | LEFT JOIN to preserve untranslated/missing category |

## Derived views and fields

| View/field | Grain | Definition / denominator | Unit |
|---|---|---|---|
| vw_order_sales.merchandise_sales | Order | SUM(CAST(item.price AS DECIMAL(19,2))) | BRL |
| vw_order_sales.freight_total | Order | SUM(CAST(item.freight_value AS DECIMAL(19,2))) | BRL |
| vw_delivered_scope | Delivered order | joined order+customer+per-order sales+selected review | order grain |
| vw_customer_spend.total_spend | Unique person | SUM(merchandise_sales) for delivered orders | BRL |
| vw_customer_spend.customer_aov | Unique person | total spend / distinct delivered orders | BRL/order |
| vw_customer_latest_state | Unique person | State of latest delivered in-scope order (ties by order_id) | state code |
| selected review | Order | Latest nonnull answer timestamp, then creation date, review_id; source-row index if tie exists | valid score 1-5 |
| repeat rate | Unique person | Buyers with >=2 delivered orders / buyers with >=1 delivered order in window | percentage |
| month growth | Month | (sales this - sales last)/sales last, NULL if last absent or zero | percentage |
| delivery days | Eligible order | (actual delivery - purchase timestamp)/24h fractional | days |
| late rate | Valid delivery pair | Date(actual) > date(estimated) / eligible delivered orders | percentage |
| low rating rate | Reviewed order | Score 1-2 / valid reviewed delivered orders | percentage |
| review coverage | Delivered order | Valid-reviewed delivered orders / all delivered orders | percentage |

**Privacy/source:** anonymized Olist CSV snapshot; quote the original dataset and its license in README. Granularity matters: item rows and payment/review rows cannot be directly joined without aggregation by order. Review and delivery reflect order-level outcomes.
