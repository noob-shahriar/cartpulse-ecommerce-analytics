# CartPulse Power BI Dashboard

Power BI Desktop is Windows-only and can't run in this environment, so this folder ships everything needed to build the `.pbix` yourself in about 1-2 hours: the data, the model relationships, the DAX measures, and a page-by-page layout spec. Real numbers referenced below all come from `reports/sql_results/` and `notebooks/`.

## 1. Get the data
Run once: `python scripts/setup_database.py` then `python scripts/export_customer_segments.py`, then re-export the star schema:
```
mkdir -p data/processed/powerbi
# (see scripts/export_powerbi.py, or just re-run the export block in scripts/setup_database.py's tables list)
```
Or simpler: **Get Data > PostgreSQL database**, server `localhost`, database `cartpulse`, schema `cartpulse` - import the 9 tables directly (`dim_*`, `fact_*`) plus `data/processed/customer_segments.csv`.

## 2. Data model (Power BI "Model" view)
Star schema, one-to-many, single direction, from each `dim_*` to the matching `fact_*`:
```
dim_date        (1) -> (*) fact_orders.purchase_date
dim_customer    (1) -> (*) fact_orders.customer_id
dim_product     (1) -> (*) fact_order_items.product_id
dim_seller      (1) -> (*) fact_order_items.seller_id
fact_orders     (1) -> (*) fact_order_items.order_id
fact_orders     (1) -> (*) fact_payments.order_id
fact_orders     (1) -> (1) fact_reviews.order_id
dim_customer.customer_unique_id -> customer_segments.customer_unique_id  (1) -> (*)
```
Mark `dim_date` as a Power BI **Date table**.

## 3. Core DAX measures
```DAX
Total Revenue          = SUM ( fact_orders[items_value] )
Total Freight           = SUM ( fact_orders[freight_value] )
Total Orders            = CALCULATE ( DISTINCTCOUNT ( fact_orders[order_id] ), fact_orders[is_valid_sale] = TRUE )
Total Customers         = DISTINCTCOUNT ( dim_customer[customer_unique_id] )
Avg Order Value         = DIVIDE ( [Total Revenue], [Total Orders] )
Repeat Customer Rate    = DIVIDE ( CALCULATE ( DISTINCTCOUNT ( dim_customer[customer_unique_id] ), customer_segments[frequency] >= 2 ), [Total Customers] )
Avg Review Score        = AVERAGE ( fact_reviews[review_score] )
Late Delivery Rate      = DIVIDE ( CALCULATE ( COUNTROWS ( fact_orders ), fact_orders[is_late] = TRUE ), CALCULATE ( COUNTROWS ( fact_orders ), fact_orders[delivery_metrics_ok] = TRUE ) )
Avg Delivery Days       = CALCULATE ( AVERAGE ( fact_orders[delivery_days] ), fact_orders[delivery_metrics_ok] = TRUE )
Revenue MoM %           = VAR CurM = [Total Revenue] VAR PrevM = CALCULATE ( [Total Revenue], DATEADD ( dim_date[date_key], -1, MONTH ) ) RETURN DIVIDE ( CurM - PrevM, PrevM )
Contribution Proxy (Est)= [Total Revenue] - [Total Freight]                      -- ESTIMATED, not profit; label clearly on every visual
Freight % of Revenue    = DIVIDE ( [Total Freight], [Total Revenue] )
```
Filter every valid-sale-based measure to `fact_orders[is_valid_sale] = TRUE` (either in the measure, as above, or with a report-level filter).

## 4. Pages
Applies consistent slicers on every page: Date range (dim_date[month_start]), Region, Category. Use card visuals for KPIs, tooltips showing the underlying count.

**Page 1 - Executive Overview**
KPI cards: Total Revenue, Total Orders, Total Customers, Avg Order Value, Repeat Customer Rate, Avg Review Score, Late Delivery Rate.
Visuals: revenue trend (line, by month), orders trend (line, by month), revenue by category (bar), revenue by region (map or bar), orders by status (donut).

**Page 2 - Sales & Product Intelligence**
Visuals: category revenue (bar, top 15), category order volume (bar), top products table (product_id, category, revenue, avg review), revenue contribution % (Pareto combo chart, matches `reports/figures/category_pareto.png`), monthly sales (line).

**Page 3 - Customer Intelligence**
Visuals: customer segments (donut, from customer_segments.segment), repeat vs one-time (donut), spend distribution (histogram/decile bar, matches notebook 04 chart), customer revenue by state (map), cohort retention (matrix/heatmap - import `reports/sql_results/08_advanced_analysis__cohort_retention.csv` as a table and build a matrix visual: rows=cohort_month, columns=month_number, values=retention_pct).

**Page 4 - Seller & Operations**
Visuals: seller revenue (bar, top 15), seller order volume, seller review scores (scatter: avg_review_score vs revenue), late delivery rate by state (map/bar), delivery time trend (line by month), state-level operational performance table.

**Page 5 - Profitability & Business Opportunities**
Banner: "Estimated proxy - see docs/methodology.md. Not actual profit (no cost data in source)."
Visuals: contribution proxy by category (bar, matches `reports/figures/contribution_proxy_by_category.png`), revenue-vs-freight-burden quadrant (scatter, matches `reports/figures/revenue_freight_quadrant.png`), high-revenue/high-freight category callout table, customer segment contribution (bar), operational problem-area table (worst late-delivery states/sellers).

## 5. After building
Export each page as an image (File > Export > Export to PDF, or screenshot) into `dashboard/screenshots/page1_overview.png` ... `page5_profitability.png`, then update this README's table below and reference the screenshots from the main `README.md`.

| Page | Screenshot | Status |
|---|---|---|
| 1. Executive Overview | `screenshots/page1_overview.png` | pending - build in Power BI Desktop |
| 2. Sales & Product Intelligence | `screenshots/page2_sales_product.png` | pending |
| 3. Customer Intelligence | `screenshots/page3_customer.png` | pending |
| 4. Seller & Operations | `screenshots/page4_seller_ops.png` | pending |
| 5. Profitability & Opportunities | `screenshots/page5_profitability.png` | pending |

Save the finished file as `dashboard/CartPulse.pbix`.
