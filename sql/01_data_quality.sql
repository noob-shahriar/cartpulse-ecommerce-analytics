-- 01_data_quality.sql : data-quality audit of the loaded database.
-- Each query starts with a "-- @name : purpose" marker used by scripts/run_sql.py.

-- @null_profile : How complete are the order lifecycle fields? (NULLs are expected for unfinished orders)
SELECT COUNT(*)                                       AS orders,
       COUNT(*) FILTER (WHERE approved_ts  IS NULL)   AS null_approved,
       COUNT(*) FILTER (WHERE carrier_ts   IS NULL)   AS null_carrier,
       COUNT(*) FILTER (WHERE delivered_ts IS NULL)   AS null_delivered,
       COUNT(*) FILTER (WHERE payment_value IS NULL)  AS null_payment
FROM fact_orders;

-- @status_vs_delivery_date : Do order statuses agree with the presence of a delivery date?
SELECT order_status,
       COUNT(*)                                        AS orders,
       COUNT(*) FILTER (WHERE delivered_ts IS NOT NULL) AS with_delivery_date,
       COUNT(*) FILTER (WHERE delivered_ts IS NULL)     AS without_delivery_date
FROM fact_orders
GROUP BY order_status
ORDER BY orders DESC;

-- @orphan_and_duplicate_checks : Are keys unique and do all foreign keys resolve? (all should be 0)
SELECT 'duplicate order_id' AS check_name, COUNT(*) - COUNT(DISTINCT order_id) AS problems FROM fact_orders
UNION ALL SELECT 'duplicate (order_id, item_id)', COUNT(*) - COUNT(DISTINCT (order_id, order_item_id)) FROM fact_order_items
UNION ALL SELECT 'orders without customer', COUNT(*) FROM fact_orders o WHERE NOT EXISTS (SELECT 1 FROM dim_customer c WHERE c.customer_id = o.customer_id)
UNION ALL SELECT 'items without product', COUNT(*) FROM fact_order_items i WHERE NOT EXISTS (SELECT 1 FROM dim_product p WHERE p.product_id = i.product_id)
UNION ALL SELECT 'items without seller', COUNT(*) FROM fact_order_items i WHERE NOT EXISTS (SELECT 1 FROM dim_seller s WHERE s.seller_id = i.seller_id)
UNION ALL SELECT 'payments without order', COUNT(*) FROM fact_payments p WHERE NOT EXISTS (SELECT 1 FROM fact_orders o WHERE o.order_id = p.order_id);

-- @orders_without_items : Which orders have no items, and are they legitimate?
SELECT order_status, COUNT(*) AS orders
FROM fact_orders
WHERE item_count = 0
GROUP BY order_status
ORDER BY orders DESC;

-- @date_sequence_issues : How many orders have impossible timestamp ordering? (flagged, not deleted)
SELECT COUNT(*) FILTER (WHERE carrier_ts   < purchase_ts) AS carrier_before_purchase,
       COUNT(*) FILTER (WHERE delivered_ts < carrier_ts)  AS delivered_before_carrier,
       COUNT(*) FILTER (WHERE delivered_ts < purchase_ts) AS delivered_before_purchase,
       COUNT(*) FILTER (WHERE approved_ts  < purchase_ts) AS approved_before_purchase
FROM fact_orders;

-- @payment_reconciliation : How closely do cash payments match items + freight? Which payment types deviate?
SELECT main_payment_type,
       COUNT(*)                                                     AS orders,
       COUNT(*) FILTER (WHERE ABS(payment_value - order_value) > 1) AS mismatched_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE ABS(payment_value - order_value) > 1) / COUNT(*), 2) AS mismatch_pct,
       ROUND(SUM(payment_value - order_value), 2)                   AS net_difference_brl
FROM fact_orders
WHERE item_count > 0 AND payment_value IS NOT NULL
GROUP BY main_payment_type
ORDER BY orders DESC;

-- @review_coverage : What share of delivered orders have a review score?
SELECT COUNT(*)                                                AS delivered_orders,
       COUNT(r.order_id)                                       AS with_review,
       ROUND(100.0 * COUNT(r.order_id) / COUNT(*), 2)          AS review_coverage_pct
FROM fact_orders o LEFT JOIN fact_reviews r USING (order_id)
WHERE o.order_status = 'delivered';

-- @price_outlier_percentiles : How skewed are item prices and freight? (why medians matter)
SELECT ROUND(AVG(price), 2)                                        AS mean_price,
       PERCENTILE_CONT(0.5)  WITHIN GROUP (ORDER BY price)::numeric(10,2) AS median_price,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY price)::numeric(10,2) AS p99_price,
       MAX(price)                                                  AS max_price,
       ROUND(AVG(freight_value), 2)                                AS mean_freight,
       PERCENTILE_CONT(0.5)  WITHIN GROUP (ORDER BY freight_value)::numeric(10,2) AS median_freight
FROM fact_order_items;
