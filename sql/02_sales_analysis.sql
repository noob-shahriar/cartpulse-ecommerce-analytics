-- 02_sales_analysis.sql : Sales performance.
-- DEFINITIONS: valid sale = order not canceled/unavailable and with items.
--   Revenue (product GMV) = SUM(price) | Freight = SUM(freight_value) | Order value = price + freight.
--   Olist's own commission/margin is NOT in the data, so "revenue" here means customer-paid product value.

-- @kpi_summary : Headline sales KPIs for management (valid sales only, whole data period)
SELECT COUNT(*)                                        AS total_orders,
       COUNT(DISTINCT c.customer_unique_id)            AS total_customers,
       ROUND(SUM(o.items_value), 2)                    AS total_revenue_brl,
       ROUND(SUM(o.freight_value), 2)                  AS total_freight_brl,
       ROUND(SUM(o.order_value), 2)                    AS total_order_value_brl,
       ROUND(SUM(o.items_value) / COUNT(*), 2)         AS avg_order_value_brl,
       ROUND(SUM(o.order_value) / COUNT(*), 2)         AS avg_order_value_incl_freight_brl,
       ROUND(AVG(o.item_count), 3)                     AS avg_items_per_order,
       ROUND(SUM(o.items_value) / COUNT(DISTINCT c.customer_unique_id), 2) AS revenue_per_customer_brl
FROM fact_orders o JOIN dim_customer c USING (customer_id)
WHERE o.is_valid_sale;

-- @orders_by_status : How are all orders distributed by status, and how much value sits in each?
SELECT order_status,
       COUNT(*)                                            AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)  AS pct_of_orders,
       ROUND(SUM(items_value), 2)                          AS product_value_brl
FROM fact_orders
GROUP BY order_status
ORDER BY orders DESC;

-- @monthly_sales : Monthly orders, revenue, AOV, with month-over-month growth (full-month window only)
WITH monthly AS (
    SELECT DATE_TRUNC('month', purchase_ts)::date AS month_start,
           COUNT(*)                     AS orders,
           SUM(items_value)             AS revenue,
           SUM(freight_value)           AS freight,
           SUM(items_value) / COUNT(*)  AS aov
    FROM fact_orders
    WHERE is_valid_sale AND in_full_month_window
    GROUP BY 1)
SELECT month_start,
       orders,
       ROUND(revenue, 2)   AS revenue_brl,
       ROUND(freight, 2)   AS freight_brl,
       ROUND(aov, 2)       AS avg_order_value_brl,
       ROUND(100.0 * (orders  - LAG(orders)  OVER w) / NULLIF(LAG(orders)  OVER w, 0), 2) AS orders_mom_pct,
       ROUND(100.0 * (revenue - LAG(revenue) OVER w) / NULLIF(LAG(revenue) OVER w, 0), 2) AS revenue_mom_pct,
       ROUND(AVG(revenue) OVER (ORDER BY month_start ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS revenue_3m_moving_avg_brl
FROM monthly
WINDOW w AS (ORDER BY month_start)
ORDER BY month_start;

-- @yoy_jan_aug : Fair year-over-year comparison using the SAME months (Jan-Aug) in 2017 and 2018
SELECT EXTRACT(YEAR FROM purchase_ts)::int AS year,
       COUNT(*)                             AS orders,
       ROUND(SUM(items_value), 2)           AS revenue_brl,
       ROUND(SUM(items_value)/COUNT(*), 2)  AS avg_order_value_brl
FROM fact_orders
WHERE is_valid_sale AND EXTRACT(MONTH FROM purchase_ts) BETWEEN 1 AND 8 AND EXTRACT(YEAR FROM purchase_ts) IN (2017, 2018)
GROUP BY 1
ORDER BY 1;

-- @revenue_by_region : Which macro-regions of Brazil generate the most revenue?
SELECT c.region,
       COUNT(*)                                            AS orders,
       ROUND(SUM(o.items_value), 2)                        AS revenue_brl,
       ROUND(100.0 * SUM(o.items_value) / SUM(SUM(o.items_value)) OVER (), 2) AS revenue_share_pct,
       ROUND(SUM(o.items_value) / COUNT(*), 2)             AS avg_order_value_brl,
       ROUND(100.0 * SUM(o.freight_value) / SUM(o.items_value), 2) AS freight_pct_of_product_value
FROM fact_orders o JOIN dim_customer c USING (customer_id)
WHERE o.is_valid_sale
GROUP BY c.region
ORDER BY revenue_brl DESC;

-- @revenue_by_state : Which states generate the most revenue, and how concentrated is it?
SELECT c.state,
       COUNT(*)                                            AS orders,
       ROUND(SUM(o.items_value), 2)                        AS revenue_brl,
       ROUND(100.0 * SUM(o.items_value) / SUM(SUM(o.items_value)) OVER (), 2)  AS revenue_share_pct,
       ROUND(100.0 * SUM(SUM(o.items_value)) OVER (ORDER BY SUM(o.items_value) DESC) / SUM(SUM(o.items_value)) OVER (), 2) AS cumulative_share_pct,
       ROUND(SUM(o.items_value) / COUNT(*), 2)             AS avg_order_value_brl
FROM fact_orders o JOIN dim_customer c USING (customer_id)
WHERE o.is_valid_sale
GROUP BY c.state
ORDER BY revenue_brl DESC;

-- @payment_type_mix : How do customers pay, and do instalments matter?
SELECT payment_type,
       COUNT(DISTINCT order_id)                            AS orders,
       ROUND(SUM(payment_value), 2)                        AS payment_value_brl,
       ROUND(100.0 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 2) AS value_share_pct,
       ROUND(AVG(installments), 2)                         AS avg_installments
FROM fact_payments
WHERE order_id IN (SELECT order_id FROM fact_orders WHERE is_valid_sale)
GROUP BY payment_type
ORDER BY payment_value_brl DESC;

-- @weekday_pattern : Which weekdays are strongest for orders? (staffing / campaign timing)
SELECT d.day_of_week,
       TO_CHAR(o.purchase_date, 'Dy')                      AS weekday,
       COUNT(*)                                            AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)  AS pct_of_orders
FROM fact_orders o JOIN dim_date d ON d.date_key = o.purchase_date
WHERE o.is_valid_sale
GROUP BY d.day_of_week, TO_CHAR(o.purchase_date, 'Dy')
ORDER BY d.day_of_week;
