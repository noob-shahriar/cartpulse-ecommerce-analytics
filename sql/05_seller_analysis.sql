-- 05_seller_analysis.sql : Seller performance.
-- Grain: (seller, order). If an order has several sellers, each seller is credited with its own items' revenue,
-- and shares the order-level delivery outcome and review score (multi-seller orders are a small minority).

-- @seller_scorecard : One row per seller: volume, revenue, AOV, review score, delivery performance (feeds the dashboard)
WITH seller_orders AS (
    SELECT seller_id, order_id, MAX(seller_state) AS seller_state, SUM(price) AS seller_revenue,
           MAX(review_score) AS review_score, BOOL_OR(delivery_metrics_ok) AS delivery_ok,
           MAX(delivery_days) AS delivery_days, MAX(is_late::int) AS is_late
    FROM vw_item_sales
    GROUP BY seller_id, order_id)
SELECT seller_id, MAX(seller_state) AS seller_state,
       COUNT(*)                                        AS orders,
       ROUND(SUM(seller_revenue), 2)                   AS revenue_brl,
       ROUND(SUM(seller_revenue) / COUNT(*), 2)        AS avg_order_value_brl,
       ROUND(AVG(review_score), 3)                     AS avg_review_score,
       COUNT(review_score)                             AS reviewed_orders,
       COUNT(*) FILTER (WHERE delivery_ok)             AS delivered_orders,
       ROUND(AVG(delivery_days)::numeric, 2)           AS avg_delivery_days,
       ROUND(100.0 * SUM(is_late) / NULLIF(COUNT(*) FILTER (WHERE delivery_ok), 0), 2) AS late_delivery_rate_pct
FROM seller_orders
GROUP BY seller_id
ORDER BY revenue_brl DESC;

-- @top_sellers_by_revenue : Who are the 15 biggest sellers and how much of the business do they hold?
SELECT seller_id, seller_state,
       COUNT(DISTINCT order_id)                          AS orders,
       ROUND(SUM(price), 2)                              AS revenue_brl,
       ROUND(100.0 * SUM(price) / SUM(SUM(price)) OVER (), 2) AS revenue_share_pct,
       ROUND(AVG(review_score), 2)                       AS avg_review_score
FROM vw_item_sales
GROUP BY seller_id, seller_state
ORDER BY revenue_brl DESC
LIMIT 15;

-- @seller_concentration : How dependent is revenue on the top sellers? (percentile buckets of sellers)
WITH seller_rev AS (SELECT seller_id, SUM(price) AS revenue FROM vw_item_sales GROUP BY seller_id),
ranked AS (SELECT revenue, PERCENT_RANK() OVER (ORDER BY revenue DESC) AS pr FROM seller_rev)
SELECT COUNT(*)                                                        AS active_sellers,
       ROUND(100.0 * SUM(revenue) FILTER (WHERE pr < 0.01) / SUM(revenue), 2) AS top_1pct_share,
       ROUND(100.0 * SUM(revenue) FILTER (WHERE pr < 0.05) / SUM(revenue), 2) AS top_5pct_share,
       ROUND(100.0 * SUM(revenue) FILTER (WHERE pr < 0.10) / SUM(revenue), 2) AS top_10pct_share,
       ROUND(100.0 * SUM(revenue) FILTER (WHERE pr < 0.20) / SUM(revenue), 2) AS top_20pct_share
FROM ranked;

-- @sellers_poor_delivery : Sellers with the worst late-delivery rates (>= 50 delivered orders so rates are meaningful)
WITH seller_orders AS (
    SELECT seller_id, order_id, MAX(is_late::int) AS is_late, MAX(review_score) AS review_score, SUM(price) AS rev
    FROM vw_item_sales WHERE delivery_metrics_ok
    GROUP BY seller_id, order_id)
SELECT seller_id,
       COUNT(*)                                   AS delivered_orders,
       ROUND(100.0 * SUM(is_late) / COUNT(*), 2)  AS late_delivery_rate_pct,
       ROUND(AVG(review_score), 2)                AS avg_review_score,
       ROUND(SUM(rev), 2)                         AS revenue_brl
FROM seller_orders
GROUP BY seller_id
HAVING COUNT(*) >= 50
ORDER BY late_delivery_rate_pct DESC
LIMIT 15;

-- @sellers_low_reviews : Sellers with low satisfaction (>= 50 reviewed orders, lowest average score first)
SELECT seller_id, COUNT(*) AS reviewed_orders, ROUND(AVG(review_score), 2) AS avg_review_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2) / COUNT(*), 1) AS pct_1_2_stars,
       ROUND(SUM(rev), 2) AS revenue_brl
FROM (SELECT seller_id, order_id, MAX(review_score) AS review_score, SUM(price) AS rev
      FROM vw_item_sales WHERE review_score IS NOT NULL GROUP BY seller_id, order_id) d
GROUP BY seller_id
HAVING COUNT(*) >= 50
ORDER BY avg_review_score ASC
LIMIT 15;

-- @seller_volume_tiers : Does seller size relate to quality? (tiers by number of orders)
WITH seller_orders AS (
    SELECT seller_id, order_id, SUM(price) AS rev, MAX(review_score) AS review_score,
           BOOL_OR(delivery_metrics_ok) AS delivery_ok, MAX(is_late::int) AS is_late
    FROM vw_item_sales GROUP BY seller_id, order_id),
seller_tier AS (
    SELECT seller_id, COUNT(*) AS n, SUM(rev) AS rev,
           CASE WHEN COUNT(*) < 10 THEN '1) 1-9 orders' WHEN COUNT(*) < 50 THEN '2) 10-49' WHEN COUNT(*) < 200 THEN '3) 50-199' ELSE '4) 200+' END AS tier
    FROM seller_orders GROUP BY seller_id)
SELECT t.tier,
       COUNT(DISTINCT t.seller_id)                          AS sellers,
       ROUND(100.0 * SUM(t.rev) / SUM(SUM(t.rev)) OVER (), 2) AS revenue_share_pct,
       ROUND(AVG(so.review_score), 3)                       AS avg_review_score,
       ROUND(100.0 * SUM(so.is_late) / NULLIF(COUNT(*) FILTER (WHERE so.delivery_ok), 0), 2) AS late_delivery_rate_pct
FROM seller_tier t JOIN seller_orders so USING (seller_id)
GROUP BY t.tier
ORDER BY t.tier;

-- @seller_state_summary : Where are sellers located and how do they perform? (sellers are concentrated geographically)
SELECT seller_state,
       COUNT(DISTINCT seller_id)                            AS sellers,
       COUNT(DISTINCT order_id)                             AS orders,
       ROUND(SUM(price), 2)                                 AS revenue_brl,
       ROUND(100.0 * SUM(price) / SUM(SUM(price)) OVER (), 2) AS revenue_share_pct,
       ROUND(AVG(review_score), 3)                          AS avg_review_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / NULLIF(COUNT(*) FILTER (WHERE delivery_metrics_ok), 0), 2) AS late_item_rate_pct
FROM vw_item_sales
GROUP BY seller_state
ORDER BY revenue_brl DESC;
