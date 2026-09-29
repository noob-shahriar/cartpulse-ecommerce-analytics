# Methodology

## Sales / revenue definitions
- **Valid sale**: an order whose status is not `canceled` or `unavailable`, and which has at least one item (`fact_orders.is_valid_sale`). 1,242 of 99,441 orders (1.25%) are excluded from revenue by this rule.
- **Revenue / product value (GMV)**: `SUM(price)` across order items. This is what the customer paid for the product itself, before freight.
- **Freight**: `SUM(freight_value)`, the shipping charge collected from the customer.
- **Order value**: `items_value + freight_value`.
- **Payment value**: the cash actually collected (`fact_payments`), which can differ slightly from order value (installment interest, vouchers, rounding); the difference is under 0.02% of total order value across the dataset (see `sql/01_data_quality.sql`, `payment_reconciliation`).
- **Full-month trend window**: Jan 2017 - Aug 2018. Sep-Dec 2016 (5 orders) and Sep-Oct 2018 (20 orders) are excluded from month-over-month and trend charts to avoid fake spikes from partial months.

## Delivery / operations definitions
- **delivery_metrics_ok**: order status = `delivered` AND has a non-null delivery date. Used for every delivery-time and late-rate metric (8 delivered orders are missing a date and are excluded rather than guessed).
- **delivery_days**: calendar days from purchase to customer delivery.
- **is_late**: delivered after `order_estimated_delivery_date`.

## Customer segmentation (RFM)
See `database/transformations/01_views.sql` (`vw_customer_rfm`) and `notebooks/04_customer_analysis.ipynb`.
- Customer = `customer_unique_id` (the real person), not `customer_id` (a per-order key).
- Recency = days since last valid order, relative to a snapshot date of one day after the last order in the dataset (2018-09-04) - not today's date, since the data ends in the past.
- Frequency = count of valid orders. Monetary = sum of product value (`items_value`).
- **Why not classic RFM quintiles**: ~97% of customers have Frequency = 1 (see notebook 04, Q1), so a 5x5x5 quintile split on frequency would collapse to 1-2 buckets and produce uninformative segments. Business rules combining frequency, recency and a spend threshold (75th percentile monetary, R$155) were used instead; thresholds are documented in the view and were chosen from the actual recency/monetary distribution, not picked arbitrarily (see `sql/03_customer_analysis.sql`, `rfm_thresholds`).
- Segments: Champions, Loyal Customers, At-Risk Customers, Potential Loyalists, Low-Engagement Customers - defined in `vw_customer_rfm`.
- Limitation: with a 3% repeat-purchase rate, "Champions"/"Loyal" will always be a small slice of the customer base; this reflects the underlying marketplace, not a flaw in the method.

## Profitability - ESTIMATED, not actual profit
**The Olist dataset contains no product cost, COGS, commission, or profit field of any kind.** Every profitability figure in this project is one of:
1. **Revenue** (`items_value`) - actual, from the data.
2. **Freight** (`freight_value`) - actual, from the data.
3. An **ESTIMATED contribution proxy** = `items_value - freight_value`, clearly labelled `_proxy` in every column/table/view. This treats freight as a stand-in for the seller's main variable cost per order. It deliberately **ignores** product cost, marketplace commission, payment processing fees, returns, and overhead - all of which are real costs this proxy does not capture.
This proxy should never be read as "profit" and is not used to make investment claims beyond directional prioritisation (e.g. "category A carries more freight burden per real relative to category B").

## Cohort / retention analysis
Cohorts are grouped by month of first valid purchase (`sql/08_advanced_analysis.sql`, `cohort_retention`). Because the dataset spans Sep 2016 - Oct 2018, later cohorts (e.g. mid-2018) have fewer subsequent months observed than early cohorts - retention is only reported for months 0-6 for this reason, and comparisons across cohorts should account for the shrinking repeat rate already documented above (97% one-time buyers), which makes month 1+ retention very low for every cohort.

## Known data-quality decisions (full detail in `data/processed/cleaning_log.json`)
- Reviews: 551 older duplicate reviews (of orders with more than one review) were dropped, keeping the most recent review per order.
- Product category: 610 products with no category were labelled `unknown`; 2 categories missing from the official translation file were translated manually (`pc_gamer`, `portateis_cozinha_e_preparadores_de_alimentos`).
- Geolocation: collapsed from ~1M raw rows (many points per zip prefix, some outside Brazil's bounding box) to one row per zip prefix using the mean coordinate and most common city/state.
- Timestamp anomalies (carrier date before purchase, etc.) are flagged, not corrected or dropped, since the purchase -> delivery calculation does not depend on the carrier timestamp.
