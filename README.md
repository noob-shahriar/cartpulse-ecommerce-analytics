# CartPulse
**E-Commerce Growth & Profitability Intelligence**

An end-to-end Data Analyst portfolio project analysing the [Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) dataset (99,441 real, anonymised orders, Sep 2016 - Oct 2018) to answer sales, customer, product, seller and operational questions for a fictional e-commerce company, "CartPulse".

## 1. Project overview
CartPulse simulates a real analytics engagement: raw CSVs are profiled, cleaned with every decision documented, loaded into a PostgreSQL star schema, analysed with SQL and Python, and turned into a customer segmentation, a cohort-retention study, and a set of business recommendations backed by real numbers - no fabricated metrics anywhere.

## 2. Business problem
Management wants to understand how the business is performing and where to focus to improve revenue, customer retention, product/seller performance and operational efficiency. See `reports/executive_summary.md` for the answer.

## 3. Objectives
Sales performance - Customer behaviour - Product & seller performance - Operational performance - Estimated profitability (the dataset has no cost/profit field, see below).

## 4. Dataset
Olist Brazilian E-Commerce Public Dataset (Kaggle), 9 tables, ~100k orders. Not included in this repo (Kaggle licence, ~125 MB) - see `data/README.md` to download it, and `docs/data_dictionary.md` for every table and column, generated directly from the raw files.

## 5. Data architecture
```
Raw CSVs (data/raw, gitignored)
   -> scripts/data_pipeline.py  (cleaning, flags, documented decisions -> data/processed/cleaning_log.json)
   -> scripts/setup_database.py (loads a PostgreSQL star schema: 5 dims + 4 facts + 2 analytical views)
   -> sql/*.sql   (business analysis, run via scripts/run_sql.py -> reports/sql_results/)
   -> notebooks/*.ipynb (Python EDA, segmentation, cohort analysis, cross-checked against SQL)
   -> reports/, dashboard/ (executive summary, recommendations, Power BI spec)
```

## 6. Tech stack
Python (pandas, NumPy, Matplotlib, Seaborn), PostgreSQL, SQL, Jupyter, Power BI, Git/GitHub.

## 7. Data pipeline
`python scripts/data_pipeline.py` reads the 9 raw CSVs (never modified), applies documented cleaning rules (Problem -> Decision -> Reason -> Impact, in `data/processed/cleaning_log.json`), and writes cleaned tables to `data/processed/`. Nothing is silently dropped - questionable rows are flagged (e.g. `is_valid_sale`, `delivery_metrics_ok`) so each analysis decides how to treat them.

## 8. KPI framework
Revenue = product value (GMV) only. Order value = revenue + freight. Payment value = cash actually collected. **No true profit exists in this dataset** - see Limitations. Full definitions: `docs/methodology.md`.

## 9. SQL analysis
Eight files in `sql/`, one per business domain, using CTEs, window functions, ranking, running totals and Pareto analysis:
`01_data_quality` · `02_sales_analysis` · `03_customer_analysis` · `04_product_analysis` · `05_seller_analysis` · `06_operations_analysis` · `07_profitability_analysis` · `08_advanced_analysis`.
Run all of them: `python scripts/run_sql.py` (results land in `reports/sql_results/`).

## 10. Python analysis
Six notebooks in `notebooks/`, each following Question -> Analysis -> Visualization -> Finding -> Business implication, and cross-checking the SQL results in pandas:
`01_data_understanding` · `02_data_cleaning` · `03_exploratory_analysis` · `04_customer_analysis` · `05_product_analysis` · `06_advanced_analysis` (cohort retention + Pareto).

## 11. Customer segmentation
RFM-based segments (Champions, Loyal, At-Risk, Potential Loyalists, Low-Engagement) built with business-readable thresholds rather than classic quintiles, because ~97% of customers have only ever placed one order. Full methodology: `docs/methodology.md`; notebook: `notebooks/04_customer_analysis.ipynb`.

## 12. Cohort analysis
Monthly acquisition cohorts tracked for 6 months of retention (`notebooks/06_advanced_analysis.ipynb`). Month-1 retention averages under 1% across every cohort - consistent with the low overall repeat rate, not a modelling artefact - and this limitation is stated explicitly rather than over-interpreted.

## 13. Dashboard
Power BI Desktop isn't available in this build environment. `dashboard/README.md` ships the full data model, DAX measures, and a 5-page layout spec (Executive Overview, Sales & Product, Customer Intelligence, Seller & Operations, Profitability) so the `.pbix` can be assembled directly from `data/processed/powerbi/` or a live PostgreSQL connection.

## 14. Key findings
- Southeast region = 65.4% of revenue; freight burden rises from 15.2% (Southeast) to 22.7% (North) of item price.
- Only 3.04% of customers repeat-purchase; repeat customers are just 5.56% of revenue.
- 18 of 74 categories generate 80% of revenue; the top 10% of sellers generate 67.5% of revenue.
- Late-delivered orders average 2.57 stars vs 4.29 for on-time - a 1.72-star gap.
- No true profit is measurable; an estimated contribution proxy flags `furniture_decor`, `housewares` and `office_furniture` as high-revenue/high-freight-burden.

Full detail: `reports/executive_summary.md`.

## 15. Business recommendations
Five recommendations in Observation -> Evidence -> Implication -> Recommendation form: `reports/business_recommendations.md`.

## 16. Project structure
```
CartPulse/
├── data/                 raw (gitignored) + processed + README + data dictionary source
├── database/             schema.sql, analytical views, load validation
├── sql/                  01-08, one file per business domain
├── notebooks/             01-06, Python EDA / segmentation / cohort analysis
├── dashboard/             Power BI spec, DAX measures, screenshots (pending)
├── reports/               executive summary, recommendations, profitability, SQL result CSVs, figures
├── docs/                  data dictionary, methodology, interview prep, project story (see below)
├── scripts/               pipeline, database load, SQL runner, Power BI export
├── requirements.txt / .gitignore / README.md
```

## 17. How to run
```bash
pip install -r requirements.txt
python scripts/data_pipeline.py          # clean data
python scripts/setup_database.py         # load PostgreSQL (set PG* env vars, see .env.example)
python scripts/run_sql.py                # run all SQL, save results
jupyter nbconvert --to notebook --execute notebooks/*.ipynb --inplace   # or open in Jupyter
python scripts/export_powerbi.py         # export tables for Power BI
```

## 18. Limitations
- No product cost, commission or profit field - profitability figures are explicitly labelled ESTIMATED proxies.
- Data ends October 2018; cohort/seasonality conclusions are bounded to that window.
- ~97% one-time buyers limits how far retention analysis can go on this dataset - stated directly rather than glossed over.
- A small share of orders span multiple sellers; seller-level delivery/review metrics attribute the order outcome to each seller involved.
- Power BI dashboard ships as a build spec + data export, not a finished `.pbix`, since Power BI Desktop is Windows-only and unavailable in this environment.

## 19. Future improvements
- Connect a real cost/margin dataset (even indicative) to replace the estimated contribution proxy with real profitability.
- Add a marketing-spend or acquisition-channel source to calculate true CAC and CAC:LTV.
- Automate the pipeline with Airflow/dbt and a CI check that reruns `sql/01_data_quality.sql` on every load.
- Extend the RFM segmentation with a lightweight propensity model once more history/repeat purchases are available.
