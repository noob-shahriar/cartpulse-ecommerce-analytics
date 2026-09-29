-- Reusable analytical views. Run automatically by scripts/setup_database.py.
SET search_path TO cartpulse;

-- One row per order item, restricted to VALID SALES (is_valid_sale = TRUE), with the dimensions analysts need most.
CREATE OR REPLACE VIEW vw_item_sales AS
SELECT i.order_id, i.order_item_id, o.purchase_ts, o.purchase_date,
       DATE_TRUNC('month', o.purchase_ts)::date AS month_start,
       o.in_full_month_window, o.order_status,
       c.customer_unique_id, c.state AS customer_state, c.region AS customer_region,
       i.product_id, p.category_en, i.seller_id, s.state AS seller_state,
       i.price, i.freight_value, i.price + i.freight_value AS item_total,
       o.delivery_metrics_ok, o.delivery_days, o.is_late, o.days_late,
       r.review_score
FROM fact_order_items i
JOIN fact_orders o     ON o.order_id = i.order_id AND o.is_valid_sale
JOIN dim_customer c    ON c.customer_id = o.customer_id
JOIN dim_product p     ON p.product_id = i.product_id
JOIN dim_seller s      ON s.seller_id = i.seller_id
LEFT JOIN fact_reviews r ON r.order_id = i.order_id;

-- One row per REAL customer (customer_unique_id) with Recency / Frequency / Monetary.
-- Snapshot date = day after the last valid order in the data (not today's date).
CREATE OR REPLACE VIEW vw_customer_rfm AS
WITH snap AS (SELECT (MAX(purchase_ts)::date + 1) AS snapshot_date FROM fact_orders WHERE is_valid_sale),
cust AS (
    SELECT c.customer_unique_id,
           COUNT(*)              AS frequency,
           SUM(o.items_value)    AS monetary,
           SUM(o.order_value)    AS monetary_with_freight,
           MIN(o.purchase_ts)    AS first_purchase_ts,
           MAX(o.purchase_ts)    AS last_purchase_ts
    FROM fact_orders o JOIN dim_customer c USING (customer_id)
    WHERE o.is_valid_sale
    GROUP BY c.customer_unique_id)
SELECT cust.*, (snap.snapshot_date - cust.last_purchase_ts::date) AS recency_days,
       CASE
         WHEN frequency >= 2 AND (snap.snapshot_date - last_purchase_ts::date) <= 180 THEN 'Champions'
         WHEN frequency >= 2 AND (snap.snapshot_date - last_purchase_ts::date) <= 365 THEN 'Loyal Customers'
         WHEN frequency >= 2 THEN 'At-Risk Customers'
         WHEN (snap.snapshot_date - last_purchase_ts::date) <= 180 THEN 'Potential Loyalists'
         WHEN monetary >= 155 THEN 'At-Risk Customers'
         ELSE 'Low-Engagement Customers'
       END AS segment
FROM cust CROSS JOIN snap;
