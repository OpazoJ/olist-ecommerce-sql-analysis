/*
============================================
    05_analysis.sql
    Analysis of the data
============================================
Business questions:
    Q1. Monthly revenue and growth
    Q2. % of orders delivered late
    Q3. Review scores of late vs on-time orders
    Q4. Top 10 categories by revenue
Analysis scope (decided in 03_quality.sql), applied to every question through the view below: orders
with status 'delivered' purchased between Jan 2017 and Aug 2018. 2016 has few orders (329)
and Sep-Oct 2018 has fewer (20), so both periods could be incomplete. The view has 96,211 orders
(267 delivered 2016 orders are left out).
*/

CREATE OR REPLACE VIEW orders_in_scope AS
SELECT *
FROM orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01'
;

-- Q1. Monthly revenue and growth --
-- Revenue = SUM(price), freight excluded.
-- The first month has no growth rate because there is no previous month.
-- Results: revenue grows from ~112K (Jan 2017) to ~988K (Nov 2017) and then
-- stays between 826K and 978K in 2018.
-- The highest growth rates are Feb 2017 (109.51%) and Mar 2017 (53.36%), both
-- from a small base. From Apr 2017 onward, the highest growth is Nov 2017
-- (52.37%), followed by a drop of 26.50% in Dec 2017.

WITH sales_by_month AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS sales_month,
        SUM(i.price) AS curr_month_sales
    FROM orders_in_scope o
    INNER JOIN order_items i
        ON o.order_id = i.order_id
    GROUP BY sales_month
),
sales_lag AS (
    SELECT
        sales_month,
        curr_month_sales,
        LAG(curr_month_sales) OVER (
            ORDER BY sales_month
        ) AS prev_month_sales
    FROM sales_by_month
)

SELECT
    sales_month,
    curr_month_sales,
    prev_month_sales,
    ROUND(100 * (curr_month_sales - prev_month_sales)
          / NULLIF(prev_month_sales, 0), 2) AS mom_growth_rate
FROM sales_lag
ORDER BY sales_month
;


-- Q2. % of orders delivered late --
-- Universe: orders in scope that have a delivery date (96,203 orders).
-- An order is late if the actual delivery date is after the estimated one,
-- comparing dates (::DATE), not timestamps. Comparing timestamps gives 8.13%
-- because the estimated date always carries a 00:00 time, so any order
-- delivered on the estimated day (after midnight) would count as late.
-- Result: 6.79% of delivered orders arrived late.
-- The two queries below are equivalent ways to write the same calculation.

-- With AVG
SELECT
    ROUND(
        AVG(
            CASE
                WHEN order_estimated_delivery_date::DATE < order_delivered_customer_date::DATE
                    THEN 1
                ELSE 0
            END) * 100, 2) AS delivered_late_pct
FROM orders_in_scope
WHERE order_delivered_customer_date IS NOT NULL
;

-- With SUM
SELECT
    ROUND(
        SUM(
            CASE
                WHEN order_estimated_delivery_date::DATE < order_delivered_customer_date::DATE
                    THEN 1
                ELSE 0
            END) * 100.00 / COUNT(*), 2) AS delivered_late_pct
FROM orders_in_scope
WHERE order_delivered_customer_date IS NOT NULL
;


-- Q3. Average of review scores --
-- Some orders have more than one review (547 in the whole table, 523 in the
-- analysis universe), so two approaches are shown: average by review and
-- average by order.
-- Orders without any review are excluded by the INNER JOIN.
-- Result: late orders average 2.27, on-time orders 4.29. Both approaches
-- give the same averages (rounded to 2 decimals).
-- This is an association, not proof of cause: late orders may also differ in
-- other ways (distance, seller, product type).

-- Number of orders with multiple reviews (analysis universe)
SELECT
    COUNT(*) AS orders_multiple_reviews
FROM (
    SELECT
        r.order_id
    FROM order_reviews r
    INNER JOIN orders_in_scope o
        ON o.order_id = r.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
    GROUP BY r.order_id
    HAVING COUNT(*) > 1
) AS multiple_reviews
;

-- Avg by review
SELECT
    CASE
        WHEN o.order_estimated_delivery_date::DATE < o.order_delivered_customer_date::DATE
            THEN 'yes'
        ELSE 'no'
    END AS delivered_late,
    ROUND(AVG(r.review_score), 2) AS review_score_avg,
    COUNT(*) AS reviews_count
FROM orders_in_scope o
INNER JOIN order_reviews r
    ON r.order_id = o.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY delivered_late
ORDER BY reviews_count DESC
;

-- Avg by order
WITH score_by_order AS (
    SELECT
        order_id,
        AVG(review_score) AS order_score_avg
    FROM order_reviews
    GROUP BY order_id
)

SELECT
    CASE
        WHEN o.order_estimated_delivery_date::DATE < o.order_delivered_customer_date::DATE
            THEN 'yes'
        ELSE 'no'
    END AS delivered_late,
    ROUND(AVG(s.order_score_avg), 2) AS order_score_avg,
    COUNT(*) AS orders_count
FROM score_by_order s
INNER JOIN orders_in_scope o
    ON s.order_id = o.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY delivered_late
ORDER BY orders_count DESC
;


-- Q4. Top 10 categories by revenue --
-- Category name: English translation, else original (Portuguese) name,
-- else 'unknown' (products without category).
-- Ranked by SUM(price). No cost data, so profitability can't be measured.
-- Results: health_beauty leads with a revenue of 1,229,557.50;
-- bed_bath_table sells the most items (10,945) among the top 10;
-- watches_gifts has the highest revenue per item (198.71) among the top 10.

WITH category_sales_base AS (
    SELECT
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown')
            AS category,
        i.price
    FROM orders_in_scope o
    INNER JOIN order_items i
        ON o.order_id = i.order_id
    INNER JOIN products p
        ON i.product_id = p.product_id
    LEFT JOIN category_translation t
        ON p.product_category_name = t.product_category_name
),
category_sales AS (
    SELECT
        category,
        SUM(price) AS total_revenue,
        COUNT(*) AS items_sold,
        RANK() OVER (ORDER BY SUM(price) DESC) AS sales_rank
    FROM category_sales_base
    GROUP BY category
)

SELECT
    sales_rank,
    category,
    total_revenue,
    items_sold,
    ROUND(total_revenue / items_sold, 2) AS rev_by_item
FROM category_sales
WHERE sales_rank <= 10
ORDER BY sales_rank
;
