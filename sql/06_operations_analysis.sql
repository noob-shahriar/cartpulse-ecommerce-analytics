-- 06_operations_analysis.sql : Delivery / operational performance.
-- Only orders with delivery_metrics_ok = TRUE (delivered AND has a delivery date) are used for timing metrics.

-- @operations_kpis : Headline operational KPIs
SELECT COUNT(*) FILTER (WHERE delivery_metrics_ok)                                   AS delivered_orders_measured,
       ROUND(AVG(delivery_days) FILTER (WHERE delivery_metrics_ok)::numeric, 2)      AS avg_delivery_days,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days) FILTER (WHERE delivery_metrics_ok)::numeric, 2) AS median_delivery_days,
       ROUND(AVG(EXTRACT(EPOCH FROM (estimated_delivery_date - purchase_ts)) / 86400)::numeric, 2) AS avg_estimated_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*) FILTER (WHERE delivery_metrics_ok), 2) AS late_delivery_rate_pct,
       ROUND(AVG(days_late) FILTER (WHERE is_late), 2)                               AS avg_days_late_when_late
FROM fact_orders;

-- @delivery_by_month : Has delivery performance improved or worsened over time?
SELECT DATE_TRUNC('month', purchase_ts)::date AS month_start,
       COUNT(*) FILTER (WHERE delivery_metrics_ok)                                    AS delivered,
       ROUND(AVG(delivery_days) FILTER (WHERE delivery_metrics_ok)::numeric, 2)       AS avg_delivery_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / NULLIF(COUNT(*) FILTER (WHERE delivery_metrics_ok), 0), 2) AS late_rate_pct
FROM fact_orders
WHERE in_full_month_window
GROUP BY 1
ORDER BY 1;

-- @delivery_by_customer_state : Where do delivery problems concentrate geographically?
SELECT c.state,
       COUNT(*) FILTER (WHERE o.delivery_metrics_ok)                                      AS delivered,
       ROUND(AVG(o.delivery_days) FILTER (WHERE o.delivery_metrics_ok)::numeric, 2)        AS avg_delivery_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.is_late) / NULLIF(COUNT(*) FILTER (WHERE o.delivery_metrics_ok), 0), 2) AS late_rate_pct
FROM fact_orders o JOIN dim_customer c USING (customer_id)
GROUP BY c.state
HAVING COUNT(*) FILTER (WHERE o.delivery_metrics_ok) >= 30
ORDER BY late_rate_pct DESC;

-- @delivery_by_region : Same, rolled up to macro-region for the executive dashboard
SELECT c.region,
       COUNT(*) FILTER (WHERE o.delivery_metrics_ok)                                       AS delivered,
       ROUND(AVG(o.delivery_days) FILTER (WHERE o.delivery_metrics_ok)::numeric, 2)         AS avg_delivery_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.is_late) / NULLIF(COUNT(*) FILTER (WHERE o.delivery_metrics_ok), 0), 2) AS late_rate_pct
FROM fact_orders o JOIN dim_customer c USING (customer_id)
GROUP BY c.region
ORDER BY late_rate_pct DESC;

-- @review_vs_delivery : Is late delivery associated with a worse review score? (core operations finding)
SELECT CASE WHEN o.is_late THEN 'Late' WHEN o.delivery_metrics_ok THEN 'On time' ELSE 'Unknown' END AS delivery_outcome,
       COUNT(r.review_score)                             AS reviewed_orders,
       ROUND(AVG(r.review_score), 3)                      AS avg_review_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 2) / COUNT(r.review_score), 2) AS pct_1_2_stars,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score = 5) / COUNT(r.review_score), 2)  AS pct_5_stars
FROM fact_orders o LEFT JOIN fact_reviews r USING (order_id)
WHERE o.delivery_metrics_ok
GROUP BY 1
ORDER BY avg_review_score;

-- @review_vs_days_late : Does the SIZE of the delay matter, or just being late at all?
SELECT CASE WHEN NOT is_late THEN '0) on time' WHEN days_late <= 3 THEN '1) 1-3 days late' WHEN days_late <= 7 THEN '2) 4-7 days late' ELSE '3) 8+ days late' END AS lateness_bucket,
       COUNT(r.review_score)               AS reviewed_orders,
       ROUND(AVG(r.review_score), 3)       AS avg_review_score
FROM fact_orders o LEFT JOIN fact_reviews r USING (order_id)
WHERE o.delivery_metrics_ok
GROUP BY 1
ORDER BY 1;

-- @delivery_vs_estimate_gap : Are estimated delivery dates realistic, or padded? (negative = delivered earlier than promised)
SELECT ROUND(AVG(EXTRACT(EPOCH FROM (estimated_delivery_date - delivered_ts)) / 86400)::numeric, 2) AS avg_days_estimate_beat_by,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (estimated_delivery_date - delivered_ts)) / 86400)::numeric, 2) AS median_days_estimate_beat_by,
       ROUND(100.0 * COUNT(*) FILTER (WHERE delivered_ts < estimated_delivery_date - INTERVAL '10 days') / COUNT(*), 2) AS pct_delivered_10plus_days_early
FROM fact_orders WHERE delivery_metrics_ok;

-- @processing_time_breakdown : Where does time go: approval, carrier handoff, or transit?
SELECT ROUND(AVG(EXTRACT(EPOCH FROM (approved_ts - purchase_ts)) / 3600)::numeric, 2)       AS avg_hours_to_approve,
       ROUND(AVG(EXTRACT(EPOCH FROM (carrier_ts - approved_ts)) / 86400) FILTER (WHERE carrier_ts >= approved_ts)::numeric, 2) AS avg_days_approve_to_carrier,
       ROUND(AVG(EXTRACT(EPOCH FROM (delivered_ts - carrier_ts)) / 86400) FILTER (WHERE delivered_ts >= carrier_ts)::numeric, 2) AS avg_days_carrier_to_customer
FROM fact_orders WHERE delivery_metrics_ok;
