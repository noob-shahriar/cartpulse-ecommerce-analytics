# CartPulse - How to Tell This Story in an Interview

Use the **Problem -> Data -> Method -> Analysis -> Findings -> Recommendations -> Impact** structure.

**Problem.** A fictional e-commerce marketplace ("CartPulse", built on Olist's real anonymised order data) needed to understand what's driving revenue, whether customers come back, which sellers and categories matter most, and where operations are hurting satisfaction - to decide where to focus limited resources.

**Data.** The Olist Brazilian E-Commerce dataset: 9 relational CSVs, ~100k orders across Sep 2016-Oct 2018, covering customers, orders, items, payments, reviews, products and sellers - real transactional data, not a toy dataset, with the genuine messiness that implies (duplicate reviews, partial months, missing categories, timestamp anomalies).

**Method.** Profiled every raw file before assuming anything about it. Built a documented cleaning pipeline (every decision logged as Problem/Decision/Reason/Impact, nothing silently dropped) and loaded the result into a PostgreSQL star schema (5 dimensions, 4 facts, 2 analytical views). Wrote 8 SQL files covering data quality, sales, customers, products, sellers, operations, profitability and advanced (window-function) analysis, then cross-checked the same numbers independently in 6 Jupyter notebooks.

**Analysis.** Sales trends and regional concentration; an RFM-based customer segmentation built on the actual recency/monetary distribution (not arbitrary buckets); a cohort-retention study with its limitations stated explicitly; seller and category concentration (Pareto); the relationship between late delivery and review score; and an estimated profitability proxy, clearly labelled as an estimate because the source data has no cost or profit field.

**Findings.** Revenue is concentrated in the Southeast (65%) and in a small number of categories (18 of 74 = 80% of revenue) and sellers (top 10% = 67.5% of revenue). Repeat purchasing is structurally rare (3%) and doesn't improve by cohort. Late delivery is associated with a 1.7-star review-score gap - the single strongest satisfaction driver found in the data.

**Recommendations.** Five recommendations, each tied to specific evidence: regional freight investment, shifting focus from retention to acquisition/AOV, protecting the top-decile sellers and categories, fixing delivery reliability at the worst-performing sellers/states first, and piloting freight-cost reduction on the categories that combine high revenue with high freight burden.

**Impact (how to frame it honestly).** As a portfolio project, "impact" is the quality and defensibility of the analysis rather than a deployed business outcome. What this project demonstrates: the ability to go from raw, imperfect data to a validated relational model, translate SQL/Python findings into concrete business language, and be explicit about what the data can and can't support (e.g. refusing to call the profitability proxy "real profit"). This kind of rigor and communication is what a junior analyst is expected to bring on day one.

## If asked "what's the one thing you'd want a hiring manager to notice?"
That every number in the project - the executive summary, the recommendations, the dashboard spec - traces back to an actual SQL query or notebook cell that can be re-run and re-verified, and that the write-up is honest about the dataset's limits (no profit data, short history, low repeat rate) rather than overselling the findings.
