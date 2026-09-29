-- 03_customer_analysis.sql : Customer behaviour.
-- A "customer" is a REAL person = customer_unique_id (customer_id changes with every order). Valid sales only.

-- @customer_kpis : How many customers, how many come back, and what do they spend?
WITH per_customer AS (
    SELECT customer_unique_id, frequency AS orders, monetary AS spend FROM vw_customer_rfm)
SELECT COUNT(*)                                                     AS unique_customers,
       COUNT(*) FILTER (WHERE orders >= 2)                          AS repeat_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE orders >= 2) / COUNT(*), 2) AS repeat_purchase_rate_pct,
       ROUND(AVG(orders), 4)                                        AS avg_orders_per_customer,
       ROUND(AVG(spend), 2)                                         AS avg_spend_brl,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY spend)::numeric, 2) AS median_spend_brl,
       ROUND(AVG(spend) FILTER (WHERE orders = 1), 2)               AS avg_spend_one_time_brl,
       ROUND(AVG(spend) FILTER (WHERE orders >= 2), 2)              AS avg_spend_repeat_brl,
       ROUND(100.0 * SUM(spend) FILTER (WHERE orders >= 2) / SUM(spend), 2) AS revenue_share_from_repeat_pct
FROM per_customer;

-- @orders_per_customer : How many orders does each customer place? (distribution)
SELECT frequency AS orders_placed,
       COUNT(*)  AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 3) AS pct_of_customers
FROM vw_customer_rfm
GROUP BY frequency
ORDER BY frequency;

-- @spend_deciles : How concentrated is revenue across customers? (decile 1 = top spenders)
WITH ranked AS (
    SELECT monetary, NTILE(10) OVER (ORDER BY monetary DESC) AS decile FROM vw_customer_rfm)
SELECT decile,
       COUNT(*)                                  AS customers,
       ROUND(MIN(monetary), 2)                   AS min_spend_brl,
       ROUND(SUM(monetary), 2)                   AS revenue_brl,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2) AS revenue_share_pct,
       ROUND(100.0 * SUM(SUM(monetary)) OVER (ORDER BY decile) / SUM(SUM(monetary)) OVER (), 2) AS cumulative_share_pct
FROM ranked
GROUP BY decile
ORDER BY decile;

-- @customer_value_by_state : Which customer states are most valuable (revenue, spend per customer, repeat rate)?
WITH cust_state AS (
    SELECT DISTINCT ON (r.customer_unique_id) r.customer_unique_id, c.state, r.frequency, r.monetary
    FROM vw_customer_rfm r
    JOIN dim_customer c ON c.customer_unique_id = r.customer_unique_id
    ORDER BY r.customer_unique_id, c.customer_id)
SELECT state,
       COUNT(*)                                  AS customers,
       ROUND(SUM(monetary), 2)                   AS revenue_brl,
       ROUND(AVG(monetary), 2)                   AS avg_spend_per_customer_brl,
       ROUND(100.0 * COUNT(*) FILTER (WHERE frequency >= 2) / COUNT(*), 2) AS repeat_rate_pct,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2)        AS revenue_share_pct
FROM cust_state
GROUP BY state
ORDER BY revenue_brl DESC;

-- @rfm_thresholds : Distribution of Recency / Monetary used to justify segment thresholds
SELECT ROUND(AVG(recency_days), 1) AS avg_recency_days,
       PERCENTILE_CONT(ARRAY[0.25, 0.5, 0.75]) WITHIN GROUP (ORDER BY recency_days)::numeric(10,1)[] AS recency_q1_median_q3,
       PERCENTILE_CONT(ARRAY[0.25, 0.5, 0.75, 0.9]) WITHIN GROUP (ORDER BY monetary)::numeric(10,1)[] AS monetary_q1_median_q3_p90,
       MAX(frequency) AS max_frequency
FROM vw_customer_rfm;

-- @days_to_second_purchase : For customers who return, how long until the 2nd order?
WITH ordered AS (
    SELECT c.customer_unique_id, o.purchase_ts,
           ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id ORDER BY o.purchase_ts) AS rn
    FROM fact_orders o JOIN dim_customer c USING (customer_id)
    WHERE o.is_valid_sale),
gaps AS (
    SELECT a.customer_unique_id, EXTRACT(EPOCH FROM (b.purchase_ts - a.purchase_ts)) / 86400 AS days_gap
    FROM ordered a JOIN ordered b ON a.customer_unique_id = b.customer_unique_id AND a.rn = 1 AND b.rn = 2)
SELECT COUNT(*)                                                     AS customers_with_second_order,
       ROUND(AVG(days_gap)::numeric, 1)                             AS avg_days,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_gap)::numeric, 1) AS median_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE days_gap < 1) / COUNT(*), 2)        AS pct_within_24h,
       ROUND(100.0 * COUNT(*) FILTER (WHERE days_gap <= 30) / COUNT(*), 2)      AS pct_within_30d,
       ROUND(100.0 * COUNT(*) FILTER (WHERE days_gap <= 90) / COUNT(*), 2)      AS pct_within_90d
FROM gaps;

-- @first_order_category_repeat : Which first-purchase categories are followed by a repeat purchase most often? (min 500 customers)
WITH first_order AS (
    SELECT DISTINCT ON (c.customer_unique_id) c.customer_unique_id, o.order_id
    FROM fact_orders o JOIN dim_customer c USING (customer_id)
    WHERE o.is_valid_sale
    ORDER BY c.customer_unique_id, o.purchase_ts),
first_cat AS (
    SELECT f.customer_unique_id, p.category_en, SUM(i.price) AS v,
           ROW_NUMBER() OVER (PARTITION BY f.customer_unique_id ORDER BY SUM(i.price) DESC) AS rn
    FROM first_order f
    JOIN fact_order_items i USING (order_id) JOIN dim_product p USING (product_id)
    GROUP BY f.customer_unique_id, p.category_en)
SELECT fc.category_en,
       COUNT(*) AS first_time_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.frequency >= 2) / COUNT(*), 2) AS repeat_rate_pct
FROM first_cat fc JOIN vw_customer_rfm r USING (customer_unique_id)
WHERE fc.rn = 1
GROUP BY fc.category_en
HAVING COUNT(*) >= 500
ORDER BY repeat_rate_pct DESC;
