-- 07_profitability_analysis.sql : Revenue & profitability PROXY analysis.
-- IMPORTANT: The Olist dataset has NO product cost or profit field. Everything below is REVENUE,
-- FREIGHT, or a clearly labelled ESTIMATED proxy - never true profit. See docs/methodology.md.
--
-- ESTIMATED proxy used here: contribution_proxy_brl = items_value - freight_value
-- Assumption: freight is treated as the seller's/platform's main variable cost per order (documented, not fact).
-- This is NOT profit: it ignores product cost, payment fees, returns, and overhead. Label: ESTIMATED.

-- @revenue_composition : What does R$ of order value break down into?
SELECT ROUND(SUM(items_value), 2)                                   AS product_revenue_brl,
       ROUND(SUM(freight_value), 2)                                 AS freight_revenue_brl,
       ROUND(SUM(order_value), 2)                                   AS total_order_value_brl,
       ROUND(100.0 * SUM(freight_value) / SUM(order_value), 2)      AS freight_pct_of_order_value,
       ROUND(SUM(payment_value), 2)                                 AS total_payment_value_brl,
       ROUND(SUM(payment_value) - SUM(order_value), 2)              AS payment_vs_order_value_diff_brl
FROM fact_orders WHERE is_valid_sale;

-- @category_contribution_proxy : ESTIMATED contribution (revenue - freight) by category, vs revenue rank
SELECT category_en,
       ROUND(SUM(price), 2)                                          AS revenue_brl,
       ROUND(SUM(freight_value), 2)                                  AS freight_brl,
       ROUND(SUM(price) - SUM(freight_value), 2)                     AS contribution_proxy_brl,   -- ESTIMATED
       ROUND(100.0 * (SUM(price) - SUM(freight_value)) / SUM(price), 2) AS contribution_margin_proxy_pct,
       RANK() OVER (ORDER BY SUM(price) DESC)                        AS revenue_rank,
       RANK() OVER (ORDER BY SUM(price) - SUM(freight_value) DESC)   AS contribution_rank
FROM vw_item_sales
GROUP BY category_en
ORDER BY contribution_proxy_brl DESC;

-- @revenue_vs_freight_burden_matrix : Categories with high revenue AND high freight burden (needs attention)
WITH cat AS (
    SELECT category_en, SUM(price) AS revenue, SUM(freight_value) AS freight,
           100.0 * SUM(freight_value) / SUM(price) AS freight_pct
    FROM vw_item_sales GROUP BY category_en),
thresholds AS (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue) AS rev_p75,
                      PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY freight_pct) AS freight_p75 FROM cat)
SELECT c.category_en, ROUND(c.revenue, 2) AS revenue_brl, ROUND(c.freight_pct, 2) AS freight_pct_of_price,
       CASE WHEN c.revenue >= t.rev_p75 AND c.freight_pct >= t.freight_p75 THEN 'High revenue / high freight burden'
            WHEN c.revenue >= t.rev_p75 THEN 'High revenue / normal freight'
            WHEN c.freight_pct >= t.freight_p75 THEN 'Normal revenue / high freight burden'
            ELSE 'Normal' END AS quadrant
FROM cat c CROSS JOIN thresholds t
ORDER BY c.revenue DESC;

-- @contribution_by_region : ESTIMATED contribution proxy by customer region
SELECT c.region,
       ROUND(SUM(o.items_value), 2)                                    AS revenue_brl,
       ROUND(SUM(o.freight_value), 2)                                  AS freight_brl,
       ROUND(SUM(o.items_value) - SUM(o.freight_value), 2)             AS contribution_proxy_brl,
       ROUND(100.0 * (SUM(o.items_value) - SUM(o.freight_value)) / SUM(o.items_value), 2) AS contribution_margin_proxy_pct
FROM fact_orders o JOIN dim_customer c USING (customer_id)
WHERE o.is_valid_sale
GROUP BY c.region
ORDER BY contribution_proxy_brl DESC;

-- @contribution_by_customer_segment : ESTIMATED contribution proxy by RFM segment (needs 03's segmentation)
SELECT r.segment,
       COUNT(DISTINCT r.customer_unique_id)                            AS customers,
       ROUND(SUM(o.items_value), 2)                                    AS revenue_brl,
       ROUND(SUM(o.items_value) - SUM(o.freight_value), 2)             AS contribution_proxy_brl,
       ROUND(100.0 * SUM(o.items_value) / SUM(SUM(o.items_value)) OVER (), 2) AS revenue_share_pct
FROM vw_customer_rfm r
JOIN dim_customer c ON c.customer_unique_id = r.customer_unique_id
JOIN fact_orders o ON o.customer_id = c.customer_id AND o.is_valid_sale
GROUP BY r.segment
ORDER BY contribution_proxy_brl DESC;

-- @installments_vs_order_value : Do bigger orders get paid in more instalments? (financing behaviour)
SELECT CASE WHEN installments = 1 THEN '1) single payment' WHEN installments <= 3 THEN '2) 2-3x' WHEN installments <= 6 THEN '3) 4-6x' ELSE '4) 7x+' END AS installment_band,
       COUNT(DISTINCT fp.order_id)                    AS orders,
       ROUND(AVG(fo.order_value), 2)                  AS avg_order_value_brl
FROM fact_payments fp JOIN fact_orders fo USING (order_id)
WHERE fo.is_valid_sale AND fp.payment_type = 'credit_card'
GROUP BY 1 ORDER BY 1;
