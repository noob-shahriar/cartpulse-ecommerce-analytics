# CartPulse - Interview Preparation

## SQL (20 questions)

**1. What is the difference between a fact table and a dimension table?**
A fact table holds measurable events (an order, an order item) at a defined grain, with foreign keys to dimensions. A dimension table holds descriptive attributes (a customer, a product) that facts are analysed by. In CartPulse: `fact_orders`, `fact_order_items` vs `dim_customer`, `dim_product`.

**2. What is "grain" and why does it matter?**
Grain is what one row of a table represents. `fact_orders` is one row per order; `fact_order_items` is one row per item. Aggregating at the wrong grain double-counts - e.g. joining `fact_orders` to `fact_order_items` and summing `items_value` from `fact_orders` would multiply revenue by the item count per order.

**3. Why use a CTE instead of a subquery?**
Readability and reuse - a CTE names an intermediate result once and can be referenced multiple times in the outer query; deeply nested subqueries get harder to read and debug. CartPulse uses CTEs throughout `sql/03_customer_analysis.sql` for RFM-style calculations.

**4. Explain a window function you used and why.**
`LAG(revenue) OVER (ORDER BY month_start)` in `sql/02_sales_analysis.sql` gets the previous month's revenue in the same row, without a self-join, to calculate month-over-month growth.

**5. What's the difference between `RANK()`, `DENSE_RANK()` and `ROW_NUMBER()`?**
`ROW_NUMBER()` gives unique sequential numbers even for ties; `RANK()` gives the same rank to ties and skips the next rank(s); `DENSE_RANK()` gives the same rank to ties without skipping. Used `RANK()` in `sql/04_product_analysis.sql` so tied revenue values share a rank.

**6. How do you calculate a running total in SQL?**
`SUM(revenue) OVER (ORDER BY month_start)` - a window function with an implicit frame of "all rows up to the current one" when ordered. Used in `sql/08_advanced_analysis.sql`, `running_revenue`.

**7. What is a Pareto analysis and how did you implement it in SQL?**
Identifying what share of items produce what share of value (the "80/20 rule"). Implemented with `SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER ()` for cumulative percentage, then finding the row where that crosses 80%.

**8. How would you find duplicate rows in a table?**
`GROUP BY` all columns `HAVING COUNT(*) > 1`, or `SELECT *, COUNT(*) OVER (PARTITION BY key_columns) AS dup_count` and filter `dup_count > 1`. Used to confirm `order_items` had zero exact duplicates.

**9. What does `NTILE(10)` do, and where did you use it?**
Splits ordered rows into 10 roughly equal buckets. Used in `sql/03_customer_analysis.sql`, `spend_deciles`, to see how much revenue the top 10% of spenders contribute.

**10. Explain the difference between `INNER JOIN` and `LEFT JOIN` with an example from this project.**
`INNER JOIN` keeps only matching rows in both tables; `LEFT JOIN` keeps every row from the left table even with no match. `fact_orders LEFT JOIN fact_reviews` keeps orders with no review (NULL review columns), which an inner join would silently drop.

**11. How do you handle NULLs in aggregate calculations?**
Aggregate functions (`AVG`, `SUM`) ignore NULLs by default, which can be desired (e.g. average review score across only reviewed orders) or misleading if you actually meant "0". `COUNT(*)` vs `COUNT(column)` differ for this reason - used deliberately in `review_coverage`.

**12. What's a self-join, and would this project ever need one?**
A table joined to itself, e.g. to compare each customer's first and second order. Used conceptually in `sql/03_customer_analysis.sql`, `days_to_second_purchase`, via `ROW_NUMBER()` + a join on `rn = 1` and `rn = 2`.

**13. How do you calculate month-over-month growth in SQL?**
`(current - LAG(current) OVER (ORDER BY month)) / LAG(current) OVER (ORDER BY month)`. Guard division by zero with `NULLIF`.

**14. What is referential integrity and how did you check it in this project?**
Every foreign key should resolve to an existing row in the referenced table. Checked with `LEFT JOIN ... WHERE parent.key IS NULL` patterns in `sql/01_data_quality.sql` - all came back zero orphans.

**15. Why use `FILTER (WHERE ...)` instead of a `CASE WHEN` inside `SUM`?**
PostgreSQL's `FILTER` clause is more readable for conditional aggregates: `COUNT(*) FILTER (WHERE is_late)` vs `SUM(CASE WHEN is_late THEN 1 ELSE 0 END)` - both work, `FILTER` is PostgreSQL-specific syntax sugar.

**16. How would you optimize a slow query joining several large fact tables?**
Check `EXPLAIN ANALYZE` for sequential scans on large tables, add indexes on join/filter columns (done: `ix_fo_customer`, `ix_foi_product`, `ix_foi_seller`), aggregate before joining where possible, and avoid re-scanning the same table with repeated correlated subqueries.

**17. What's the difference between a view and a materialized view?**
A view is a saved query, re-run every time it's referenced (used for `vw_item_sales`, `vw_customer_rfm` here - fine for this dataset's scale). A materialized view stores the result physically and needs manual/scheduled refresh - would be preferable if these views were queried very frequently on much larger data.

**18. How do you handle a metric where two data sources disagree (e.g. `payment_value` vs `order_value`)?**
Don't force one to match the other - document why they can differ (interest on instalments, vouchers, rounding), quantify the gap, and expose both explicitly so downstream users choose the right one for their question. Done in `sql/01_data_quality.sql`, `payment_reconciliation`.

**19. How would you extend the schema to support daily incremental loads instead of a full reload?**
Add a `loaded_at` / `updated_at` column, load only rows newer than the last successful watermark, and use `UPSERT` (`INSERT ... ON CONFLICT DO UPDATE`) on primary keys instead of a full truncate-and-reload.

**20. Why star schema here, and when would you NOT use one?**
Star schema keeps facts and dimensions cleanly separated for fast, understandable aggregation - good fit for a BI/reporting use case like this. It's a poor fit for highly normalized transactional (OLTP) systems where write consistency and storage efficiency matter more than read speed.

## Python / Pandas (10 questions)

**1. Why use pandas for validation when the numbers already came from SQL?**
Cross-checking two independent implementations catches bugs neither alone would - e.g. `notebooks/02_data_cleaning.ipynb` asserts pandas and SQL revenue totals match exactly.

**2. How do you handle a right-skewed distribution like item price?**
Report the median alongside (or instead of) the mean, and/or use a log scale for histograms - done throughout the EDA notebooks - since a long tail of expensive items pulls the mean well above the "typical" value.

**3. What's the difference between `.merge()` and `.join()` in pandas?**
`.merge()` is SQL-style, joins on columns (or index) with explicit `how=`; `.join()` is a convenience method joining on the index by default. This project uses `.merge()` throughout for clarity about join keys.

**4. How do you avoid double-counting when merging a one-to-many relationship?**
Aggregate the "many" side first (e.g. `items.groupby('order_id').agg(...)`) before merging into the "one" side (`orders`), rather than merging item-level rows directly into order-level KPIs.

**5. How did you detect and handle duplicate reviews?**
`sort_values` by answer timestamp then `drop_duplicates('order_id', keep='last')` - kept the most recent review per order rather than deleting "randomly" or averaging conflicting scores.

**6. What's the IQR method for outlier detection, and why flag rather than remove?**
Outliers = values beyond `Q3 + 1.5*(Q3-Q1)`. Flagged (not removed) because high prices/freight in this data are real expensive items, not data-entry errors - removing them would understate revenue.

**7. How do you safely convert a column to datetime with mixed/invalid formats?**
`pd.to_datetime(col, errors='coerce')` turns unparseable values into `NaT` instead of raising, so they can be counted and handled explicitly rather than crashing the pipeline.

**8. How would you profile every column of a new, unfamiliar dataset quickly?**
Loop over columns and report dtype, null count, distinct count, and (for numeric) `describe()` - exactly what `scripts/profile_raw.py` automates for the data dictionary.

**9. What's the risk of using `.fillna(0)` everywhere?**
It can silently turn "unknown"/"not applicable" into a real zero, distorting averages and sums. This project only fills 0 where zero is the correct business meaning (e.g. an order with no items has `item_count = 0`), and uses `NaN`/flags elsewhere.

**10. How do you make a matplotlib chart's y-axis show currency instead of raw numbers?**
A custom formatter function passed to `ax.yaxis.set_major_formatter(FuncFormatter(...))`, e.g. the `brl()` helper used throughout the notebooks to render `R$1,234k` instead of `1234000`.

## Power BI (10 questions)

**1. What's the difference between a calculated column and a measure?**
A calculated column is computed row-by-row and stored in the table (uses memory, filter-context-independent at creation); a measure is computed on the fly in the context of the current filters/slicers (e.g. `Total Revenue` in `dashboard/README.md` recalculates per visual).

**2. Why mark a table as a "Date table" in Power BI?**
Enables built-in time-intelligence functions (`DATEADD`, `SAMEPERIODLASTYEAR`, etc.) and ensures a continuous calendar, even for dates with no transactions, which matters for accurate month-over-month calculations.

**3. What does `DIVIDE()` do and why use it instead of `/`?**
`DIVIDE(numerator, denominator, [alternateresult])` safely returns a specified value (default blank) instead of an error when the denominator is 0 - important for ratios like `Late Delivery Rate` where a filtered context could have zero delivered orders.

**4. How would you build the cohort-retention heatmap in Power BI?**
Import the pre-aggregated `cohort_retention` CSV (cohort_month x month_number x retention_pct) as its own table (not part of the star schema) and use a Matrix visual with cohort_month on rows, month_number on columns, retention_pct as values, conditional formatting for the heatmap effect.

**5. What's the difference between a one-to-many and many-to-many relationship, and does this model have any?**
One-to-many: one dimension row relates to many fact rows (e.g. one customer, many orders) - this is the norm here. A true many-to-many would need a bridge table; CartPulse avoids this by keeping `fact_order_items` as the item-level bridge between orders, products and sellers.

**6. How do slicers interact with measures using `CALCULATE`?**
Slicers modify filter context; `CALCULATE` can override or add to that context (e.g. forcing `is_valid_sale = TRUE` regardless of what other filters are applied), which is why several measures wrap their base expression in `CALCULATE(..., fact_orders[is_valid_sale] = TRUE)`.

**7. Why avoid putting too many visuals on one dashboard page?**
Cognitive overload and slower rendering (each visual runs its own DAX queries). CartPulse's spec caps each of the 5 pages to a focused set of KPIs plus 3-5 supporting visuals, one page per business area rather than one crowded page.

**8. How do you show both an ESTIMATED metric and make clear it's not actual profit?**
Explicit labelling in every visual title/tooltip ("Contribution Proxy (Est.)") plus a banner text box on the profitability page - never presenting it unlabeled as if it were audited profit.

**9. What's a drill-through page and where might CartPulse use one?**
A page a user navigates to with context carried over (e.g. right-click a seller on the Seller & Operations page to drill through to that seller's full order/review history) - a natural extension beyond the 5-page spec.

**10. How would you connect Power BI directly to the PostgreSQL database instead of importing CSVs?**
Get Data > PostgreSQL database, enter host/database/schema, choose Import or DirectQuery mode. DirectQuery avoids duplicating data and stays live, but pushes every visual's query to Postgres in real time, which needs indexes to stay fast at this data volume.

## Business Analytics (10 questions)

**1. Why measure revenue as `items_value` rather than `payment_value`?**
`items_value` isolates product revenue from freight and payment-method quirks (instalment interest, vouchers), giving a cleaner, comparable metric across orders paid different ways.

**2. What's the difference between GMV and net revenue, and which does this project use?**
GMV (Gross Merchandise Value) is the total value of goods transacted; net revenue would be GMV minus refunds/commissions/discounts. This project uses GMV-equivalent product value (`items_value`) because commission/fee data doesn't exist in the source.

**3. Why is repeat-purchase rate a weak growth lever here, and what would you measure instead?**
Only 3% of customers return, and that doesn't change by cohort. Acquisition volume and average order value have far more room to move the top line than retention does in this specific dataset.

**4. What is RFM segmentation and when does the classic version break down?**
Recency/Frequency/Monetary customer scoring. Classic quintile RFM breaks down when frequency has almost no variance (here, ~97% of customers = frequency 1), collapsing most customers into the same bucket - this project used business-rule segments instead.

**5. How would you turn "18 of 74 categories = 80% of revenue" into an action?**
Prioritise inventory depth, seller recruitment, and marketing spend for that group of 18 first, since the marginal return on effort there is highest; treat the remaining 56 as a longer-tail, lower-priority investment.

**6. What's the risk of over-indexing on average order value alone?**
AOV can rise even while total revenue falls, if order count drops faster than AOV rises - always pair AOV with order volume and total revenue, as this project's `kpi_summary` does.

**7. How do you decide what counts as a "late" delivery, and why does the definition matter?**
Defined as delivered after the platform's own estimated delivery date (a promise already made to the customer), not a fixed SLA - because that's the number the customer's expectation was actually set against, and it's what best explains the review-score gap found.

**8. If leadership asks for "profit by category", what do you say?**
Explain clearly that true profit can't be calculated from this data (no cost/commission fields), offer the estimated contribution proxy (revenue - freight) as the closest available substitute, and recommend what additional data (unit cost, commission rate) would be needed to answer the real question.

**9. How would you validate that a KPI on the dashboard is trustworthy before presenting it to executives?**
Cross-check it in at least two ways (SQL and Python, as done throughout this project), verify against a known edge case, and document the exact definition (what's included/excluded) so it can't be silently reinterpreted later.

**10. What's the single most actionable finding in this project, and why?**
The review-score gap between late and on-time deliveries (2.57 vs 4.29 stars) - because it is large, statistically clear from the data, directly actionable (fix the late-delivery rate, which is concentrated among identifiable states/sellers), and ties operations directly to customer satisfaction, which is harder to move through marketing alone.

## Project-Specific (10 questions)

**1. Walk me through your project end-to-end.**
See `docs/project_story.md`.

**2. Why PostgreSQL over just using pandas the whole way?**
To demonstrate a realistic analytics-engineering stack (schema design, relational integrity, SQL analysis) and because SQL window functions/CTEs are the industry-standard way to do this class of analysis at any real company.

**3. Why is your revenue number smaller than "total orders x price" would suggest?**
Because 1,242 orders (1.25%) are canceled/unavailable and excluded from revenue as `is_valid_sale = FALSE` - a deliberate, documented decision, not a bug.

**4. Why did you exclude Sep-Dec 2016 and Sep-Oct 2018 from trend charts?**
Those months have only a handful of orders each (partial data at the start/end of the collection window) - including them would create misleading spikes/drops in month-over-month growth that reflect data coverage, not the business.

**5. What would you do differently with more time or better data?**
Get real cost/commission data to replace the profitability proxy with actual margin; add a marketing/acquisition-channel table to calculate true CAC; extend the observation window to see if repeat rate improves with a longer time horizon.

**6. How did you decide RFM segment thresholds weren't arbitrary?**
Checked the actual recency/monetary distribution first (`sql/03_customer_analysis.sql`, `rfm_thresholds`) and used a real percentile (75th, R$155) rather than a round number picked without evidence.

**7. What's the hardest data-quality issue you found, and how did you resolve it?**
Reviews weren't unique per order (551 orders had more than one review) - resolved by keeping only the most recent review per order, documented as a specific cleaning decision rather than silently averaging or dropping at random.

**8. How do you know your cleaned data is still consistent with the raw data?**
Automated assertions in `notebooks/02_data_cleaning.ipynb` (row counts preserved, no order lost, raw vs cleaned item revenue matches exactly) run every time the notebook executes - not just a one-time manual check.

**9. Why build both SQL views (`vw_item_sales`, `vw_customer_rfm`) instead of putting all logic in one-off queries?**
Reusable single source of truth - both customer segmentation and category/seller analysis depend on the same underlying joins/filters (valid sales, one review per order), so a shared view avoids each query redefining that logic slightly differently and drifting apart.

**10. If this were a real company, what would you build next?**
An automated daily/weekly refresh pipeline with data-quality checks that alert before bad data reaches the dashboard, plus a live seller-health scorecard feeding directly into account management workflows.
