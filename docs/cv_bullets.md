# CartPulse - CV Bullet Points

Based only on techniques actually used and results actually calculated in this project (no invented numbers).

## One-line version
Built CartPulse, an end-to-end data analyst portfolio project on 99k+ real e-commerce orders (Olist/Kaggle) - PostgreSQL star schema, 8 SQL analysis files, 6 Python/pandas notebooks, RFM customer segmentation, and a documented data-cleaning pipeline, surfacing findings such as an 8.1% late-delivery rate linked to a 1.7-star review-score gap.

## Two-bullet version
- Designed and built a PostgreSQL star-schema analytics database from 99,441 raw e-commerce orders (9 relational source tables), with a documented, decision-logged data-cleaning pipeline in Python/pandas that preserved every row while flagging data-quality issues rather than silently dropping them.
- Delivered SQL (window functions, CTEs, Pareto/cohort analysis) and Python-based business analysis - including an RFM customer segmentation and a late-delivery-vs-review-score study (2.57 vs 4.29 average stars) - translated into 5 evidence-backed business recommendations.

## Three-bullet professional version
- **Data engineering:** built a reproducible pipeline (Python/pandas -> PostgreSQL star schema: 5 dimensions, 4 fact tables, 2 analytical views) from 9 raw e-commerce CSVs (99,441 orders), documenting every cleaning decision and validating referential integrity and cross-tool (SQL vs pandas) consistency end-to-end.
- **Analysis:** wrote 8 SQL files (window functions, CTEs, Pareto and cohort-retention analysis) and 6 Jupyter notebooks covering sales, customer, product, seller and operational KPIs; built an RFM-based customer segmentation from the actual data distribution rather than arbitrary thresholds, and quantified a 1.7-star review-score gap between late and on-time deliveries.
- **Business communication:** translated findings into an executive summary and 5 Observation -> Evidence -> Implication -> Recommendation write-ups, explicitly distinguishing actual revenue/freight from an estimated profitability proxy given the dataset's lack of cost data - and produced a full Power BI dashboard specification (data model, DAX measures, 5-page layout) ready to build.
