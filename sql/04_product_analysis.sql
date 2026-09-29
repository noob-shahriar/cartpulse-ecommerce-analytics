-- 04_product_analysis.sql : Product & category performance (valid sales, item level via vw_item_sales).
-- Freight burden = freight_value / price (how much shipping the customer pays relative to the product).

-- @category_performance : Revenue, orders, prices, freight and reviews for every category
WITH cat_reviews AS (      -- one score per (category, order) so multi-item orders are not double counted
    SELECT category_en, AVG(review_score) AS avg_review, COUNT(review_score) AS reviewed_orders
    FROM (SELECT DISTINCT category_en, order_id, review_score FROM vw_item_sales WHERE review_score IS NOT NULL) d
    GROUP BY category_en)
SELECT s.category_en,
       COUNT(DISTINCT s.order_id)                        AS orders,
       COUNT(*)                                          AS items_sold,
       ROUND(SUM(s.price), 2)                            AS revenue_brl,
       ROUND(100.0 * SUM(s.price) / SUM(SUM(s.price)) OVER (), 2) AS revenue_share_pct,
       ROUND(AVG(s.price), 2)                            AS avg_item_price_brl,
       ROUND(AVG(s.freight_value), 2)                    AS avg_freight_brl,
       ROUND(100.0 * SUM(s.freight_value) / SUM(s.price), 2) AS freight_pct_of_price,
       ROUND(r.avg_review, 3)                            AS avg_review_score
FROM vw_item_sales s LEFT JOIN cat_reviews r USING (category_en)
GROUP BY s.category_en, r.avg_review
ORDER BY revenue_brl DESC;

-- @top_categories_by_orders : Which categories drive order VOLUME (vs revenue)?
SELECT category_en,
       COUNT(DISTINCT order_id) AS orders,
       RANK() OVER (ORDER BY COUNT(DISTINCT order_id) DESC) AS order_rank,
       RANK() OVER (ORDER BY SUM(price) DESC)               AS revenue_rank
FROM vw_item_sales
GROUP BY category_en
ORDER BY orders DESC
LIMIT 15;

-- @top_products : Which individual products earn the most? (top 20 by revenue)
SELECT s.product_id, s.category_en,
       COUNT(DISTINCT s.order_id)            AS orders,
       ROUND(SUM(s.price), 2)                AS revenue_brl,
       ROUND(AVG(s.price), 2)                AS avg_price_brl,
       ROUND(AVG(s.review_score), 2)         AS avg_review_score
FROM vw_item_sales s
GROUP BY s.product_id, s.category_en
ORDER BY revenue_brl DESC
LIMIT 20;

-- @high_sales_poor_reviews : Products with real sales volume (>= 30 orders) but weak reviews (avg < 3.5) -> quality/expectation risk
SELECT product_id, category_en,
       COUNT(DISTINCT order_id)              AS orders,
       ROUND(SUM(price), 2)                  AS revenue_brl,
       ROUND(AVG(review_score), 2)           AS avg_review_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2) / COUNT(review_score), 1) AS pct_reviews_1_2_stars
FROM vw_item_sales
GROUP BY product_id, category_en
HAVING COUNT(DISTINCT order_id) >= 30 AND AVG(review_score) < 3.5
ORDER BY revenue_brl DESC
LIMIT 20;

-- @high_freight_categories : Which categories carry the heaviest freight relative to price? (min 300 items sold)
SELECT category_en,
       COUNT(*)                                          AS items_sold,
       ROUND(AVG(price), 2)                              AS avg_price_brl,
       ROUND(AVG(freight_value), 2)                      AS avg_freight_brl,
       ROUND(100.0 * SUM(freight_value) / SUM(price), 2) AS freight_pct_of_price,
       ROUND(SUM(price), 2)                              AS revenue_brl
FROM vw_item_sales
GROUP BY category_en
HAVING COUNT(*) >= 300
ORDER BY freight_pct_of_price DESC
LIMIT 15;

-- @lowest_rated_categories : Categories with the weakest customer satisfaction (min 300 reviewed orders)
SELECT category_en, COUNT(*) AS reviewed_orders, ROUND(AVG(review_score), 3) AS avg_review_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2) / COUNT(*), 1) AS pct_1_2_stars
FROM (SELECT DISTINCT category_en, order_id, review_score FROM vw_item_sales WHERE review_score IS NOT NULL) d
GROUP BY category_en
HAVING COUNT(*) >= 300
ORDER BY avg_review_score ASC
LIMIT 10;

-- @price_band_performance : How do sales and satisfaction vary by item price band?
SELECT CASE WHEN price < 50 THEN '1) < R$50' WHEN price < 100 THEN '2) R$50-99' WHEN price < 200 THEN '3) R$100-199'
            WHEN price < 500 THEN '4) R$200-499' ELSE '5) R$500+' END AS price_band,
       COUNT(*)                                          AS items_sold,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_items,
       ROUND(SUM(price), 2)                              AS revenue_brl,
       ROUND(100.0 * SUM(price) / SUM(SUM(price)) OVER (), 2) AS pct_of_revenue,
       ROUND(AVG(review_score), 3)                       AS avg_review_score
FROM vw_item_sales
GROUP BY 1
ORDER BY 1;
