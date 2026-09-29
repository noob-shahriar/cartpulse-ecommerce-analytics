-- 08_advanced_analysis.sql : Advanced window-function analysis (running totals, Pareto, cohorts).

-- @running_revenue : Cumulative revenue and cumulative share of orders over the full-month window
WITH monthly AS (SELECT DATE_TRUNC('month', purchase_ts)::date AS month_start, SUM(items_value) AS revenue, COUNT(*) AS orders
                  FROM fact_orders WHERE is_valid_sale AND in_full_month_window GROUP BY 1)
SELECT month_start, orders, ROUND(revenue, 2) AS revenue_brl,
       ROUND(SUM(revenue) OVER (ORDER BY month_start), 2)                                   AS running_revenue_brl,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY month_start) / SUM(revenue) OVER (), 2)     AS running_revenue_pct
FROM monthly ORDER BY month_start;

-- @category_pareto : Pareto analysis - how many categories make up 80% of revenue?
WITH cat AS (SELECT category_en, SUM(price) AS revenue FROM vw_item_sales GROUP BY category_en),
ranked AS (SELECT category_en, revenue, ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rnk,
                  SUM(revenue) OVER (ORDER BY revenue DESC) AS running_rev, SUM(revenue) OVER () AS total_rev
           FROM cat)
SELECT rnk, category_en, ROUND(revenue, 2) AS revenue_brl,
       ROUND(100.0 * running_rev / total_rev, 2) AS cumulative_pct
FROM ranked ORDER BY rnk;

-- @pareto_summary : Single-number answer: how many categories = 80% of revenue, out of how many total?
WITH cat AS (SELECT category_en, SUM(price) AS revenue FROM vw_item_sales GROUP BY category_en),
ranked AS (SELECT category_en, SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER () AS cum_pct,
                  ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rnk FROM cat)
SELECT MIN(rnk) FILTER (WHERE cum_pct >= 0.8) AS categories_for_80pct_revenue,
       (SELECT COUNT(*) FROM cat)             AS total_categories
FROM ranked;

-- @top_n_products_per_category : Top 3 products by revenue WITHIN each of the top 8 categories (ranking window fn)
WITH cat_rank AS (SELECT category_en, SUM(price) AS revenue FROM vw_item_sales GROUP BY category_en ORDER BY revenue DESC LIMIT 8),
prod AS (SELECT s.category_en, s.product_id, SUM(s.price) AS revenue,
                RANK() OVER (PARTITION BY s.category_en ORDER BY SUM(s.price) DESC) AS rnk
         FROM vw_item_sales s JOIN cat_rank c USING (category_en) GROUP BY s.category_en, s.product_id)
SELECT category_en, rnk, product_id, ROUND(revenue, 2) AS revenue_brl FROM prod WHERE rnk <= 3 ORDER BY category_en, rnk;

-- @cohort_retention : Monthly acquisition cohorts and retention by months-since-first-purchase (Jan17-Aug18 cohorts)
WITH first_purchase AS (
    SELECT c.customer_unique_id, MIN(DATE_TRUNC('month', o.purchase_ts))::date AS cohort_month
    FROM fact_orders o JOIN dim_customer c USING (customer_id) WHERE o.is_valid_sale GROUP BY 1),
activity AS (
    SELECT c.customer_unique_id, DATE_TRUNC('month', o.purchase_ts)::date AS active_month
    FROM fact_orders o JOIN dim_customer c USING (customer_id) WHERE o.is_valid_sale),
joined AS (
    SELECT f.cohort_month, a.active_month,
           (EXTRACT(YEAR FROM a.active_month) - EXTRACT(YEAR FROM f.cohort_month)) * 12
           + (EXTRACT(MONTH FROM a.active_month) - EXTRACT(MONTH FROM f.cohort_month)) AS month_number,
           f.customer_unique_id
    FROM first_purchase f JOIN activity a USING (customer_unique_id)
    WHERE f.cohort_month BETWEEN '2017-01-01' AND '2018-08-01'),
cohort_size AS (SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS n FROM joined WHERE month_number = 0 GROUP BY 1)
SELECT j.cohort_month, j.month_number,
       COUNT(DISTINCT j.customer_unique_id)                              AS active_customers,
       cs.n                                                              AS cohort_size,
       ROUND(100.0 * COUNT(DISTINCT j.customer_unique_id) / cs.n, 2)     AS retention_pct
FROM joined j JOIN cohort_size cs USING (cohort_month)
WHERE j.month_number BETWEEN 0 AND 6
GROUP BY j.cohort_month, j.month_number, cs.n
ORDER BY j.cohort_month, j.month_number;

-- @rfm_segment_summary : Segment sizes, revenue share, and average RFM values (feeds notebook 06 / Power BI)
SELECT segment, COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)      AS pct_of_customers,
       ROUND(AVG(recency_days), 1)                             AS avg_recency_days,
       ROUND(AVG(frequency), 2)                                AS avg_frequency,
       ROUND(AVG(monetary), 2)                                 AS avg_monetary_brl,
       ROUND(SUM(monetary), 2)                                 AS total_revenue_brl,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2) AS revenue_share_pct
FROM vw_customer_rfm
GROUP BY segment
ORDER BY total_revenue_brl DESC;
