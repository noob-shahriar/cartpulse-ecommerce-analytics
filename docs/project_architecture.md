# Project Architecture

```
Raw CSVs (Kaggle, data/raw/, gitignored, never modified)
        |
        v
scripts/data_pipeline.py   -- cleans, flags (is_valid_sale, delivery_metrics_ok, outlier flags, etc.)
        |                     writes data/processed/*.csv + cleaning_log.json (Problem/Decision/Reason/Impact)
        v
scripts/setup_database.py  -- creates schema (database/schema.sql) + loads cleaned tables
        |                     applies analytical views (database/transformations/01_views.sql)
        v
PostgreSQL "cartpulse" schema
   dims: dim_date, dim_location, dim_customer, dim_product, dim_seller
   facts: fact_orders, fact_order_items, fact_payments, fact_reviews
   views: vw_item_sales, vw_customer_rfm
        |
        +--> sql/01-08 (scripts/run_sql.py)  --> reports/sql_results/*.csv
        |
        +--> notebooks/01-06 (Python/pandas cross-check + visuals) --> reports/figures/*.png
        |
        +--> scripts/export_powerbi.py --> data/processed/powerbi/*.csv --> dashboard/ (Power BI spec)
        |
        v
reports/executive_summary.md, business_recommendations.md, profitability_analysis.md
docs/data_dictionary.md, methodology.md, interview_questions.md, project_story.md, cv_bullets.md
```

## Design choices worth explaining in an interview
- **Star schema, not raw normalized tables**: fast, intuitive aggregation for BI use cases; documented in `database/schema.sql`.
- **Flag, don't delete**: questionable rows (cancelled orders, timestamp anomalies, price outliers) are kept and flagged (`is_valid_sale`, `delivery_metrics_ok`, `flag_price_outlier`, ...) so each analysis can decide how to treat them, rather than one cleaning pass making that decision for every future use.
- **Views as a single source of truth**: `vw_item_sales` and `vw_customer_rfm` encode the "valid sale" filter and the "one review per order" rule once, so every downstream query and notebook uses the same definition instead of re-deriving it slightly differently each time.
- **SQL and Python cross-checked independently**: every notebook that reproduces a SQL result asserts they match, catching logic bugs in either.
