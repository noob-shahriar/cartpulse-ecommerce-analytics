-- Post-load validation for the CartPulse schema. Every check should return the expected value in the last column.
SET search_path TO cartpulse;
SELECT 'row_count fact_orders' AS check_name, COUNT(*) AS actual, 99441 AS expected FROM fact_orders
UNION ALL SELECT 'row_count fact_order_items', COUNT(*), 112650 FROM fact_order_items
UNION ALL SELECT 'row_count fact_payments', COUNT(*), 103886 FROM fact_payments
UNION ALL SELECT 'row_count fact_reviews', COUNT(*), 98673 FROM fact_reviews
UNION ALL SELECT 'row_count dim_customer', COUNT(*), 99441 FROM dim_customer
UNION ALL SELECT 'row_count dim_product', COUNT(*), 32951 FROM dim_product
UNION ALL SELECT 'row_count dim_seller', COUNT(*), 3095 FROM dim_seller
UNION ALL SELECT 'distinct real customers', COUNT(DISTINCT customer_unique_id), 96096 FROM dim_customer
UNION ALL SELECT 'orphan orders->customer', COUNT(*), 0 FROM fact_orders o LEFT JOIN dim_customer c USING (customer_id) WHERE c.customer_id IS NULL
UNION ALL SELECT 'orphan items->orders', COUNT(*), 0 FROM fact_order_items i LEFT JOIN fact_orders o USING (order_id) WHERE o.order_id IS NULL
UNION ALL SELECT 'orphan items->products', COUNT(*), 0 FROM fact_order_items i LEFT JOIN dim_product p USING (product_id) WHERE p.product_id IS NULL
UNION ALL SELECT 'orphan items->sellers', COUNT(*), 0 FROM fact_order_items i LEFT JOIN dim_seller s USING (seller_id) WHERE s.seller_id IS NULL
UNION ALL SELECT 'orphan payments->orders', COUNT(*), 0 FROM fact_payments p LEFT JOIN fact_orders o USING (order_id) WHERE o.order_id IS NULL
UNION ALL SELECT 'orphan reviews->orders', COUNT(*), 0 FROM fact_reviews r LEFT JOIN fact_orders o USING (order_id) WHERE o.order_id IS NULL
UNION ALL SELECT 'orders whose items_value != sum(items)', COUNT(*), 0 FROM fact_orders o
   JOIN (SELECT order_id, SUM(price) v FROM fact_order_items GROUP BY 1) i USING (order_id) WHERE ABS(o.items_value - i.v) > 0.01
UNION ALL SELECT 'orders flagged valid but no items', COUNT(*), 0 FROM fact_orders WHERE is_valid_sale AND item_count = 0
UNION ALL SELECT 'delivered ok but NULL delivery_days', COUNT(*), 0 FROM fact_orders WHERE delivery_metrics_ok AND delivery_days IS NULL
UNION ALL SELECT 'NULL is_late among delivery_metrics_ok', COUNT(*), 0 FROM fact_orders WHERE delivery_metrics_ok AND is_late IS NULL
UNION ALL SELECT 'negative delivery_days', COUNT(*), 0 FROM fact_orders WHERE delivery_days < 0;
