/*
============================================
    03_quality.sql
    Data quality checks
============================================
*/

-- Date range of the dataset
SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order
FROM orders
;
-- From Sep 2016 to Oct 2018

-- Monthly order volume
SELECT date_trunc('month', order_purchase_timestamp)::date AS month,
       COUNT(*) AS orders
FROM orders
GROUP BY 1
ORDER BY 1
;
-- Volume is negligible in 2016 (329 orders in total, nothing in Nov 2016) and in
-- Sep-Oct 2018 (20 orders). Reliable period: Jan 2017 - Aug 2018.

-- Delivered orders outside the reliable period
SELECT
    COUNT(*) FILTER (WHERE order_purchase_timestamp < '2017-01-01')  AS delivered_2016,
    COUNT(*) FILTER (WHERE order_purchase_timestamp >= '2018-09-01') AS delivered_sep_oct_2018,
    COUNT(*) AS delivered_total
FROM orders
WHERE order_status = 'delivered'
;
-- 267 delivered orders fall in 2016 and none in Sep-Oct 2018 (those 20 orders
-- are not delivered). Excluding the period therefore removes 267 of 96,478
-- delivered orders (0.28%).

-- Missing dates by order status
SELECT
    order_status,
    COUNT(*) AS orders,
    COUNT(*) - COUNT(order_approved_at) AS null_approved,
    COUNT(*) - COUNT(order_delivered_carrier_date) AS null_carrier,
    COUNT(*) - COUNT(order_delivered_customer_date) AS null_delivered
FROM orders
GROUP BY order_status
ORDER BY orders DESC
;
-- Delivered orders: 8 without a delivery date, 2 without a carrier date and
-- 14 without an approval date.

-- Share of orders by status
SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC
;
-- 97.02% of orders were delivered (96,478 of 99,441)


-- Duplicated review_id
WITH duplicated AS (
    SELECT review_id
    FROM order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)

SELECT
    COUNT(*) AS duplicated_ids
FROM duplicated
;
-- 789 review_id values appear more than once

-- Is the pair (review_id, order_id) unique? (needed to set a primary key)
SELECT
    COUNT(*) AS review_rows,
    COUNT(DISTINCT (review_id, order_id)) AS distinct_pairs
FROM order_reviews
;
-- Both are 99,224: the pair is unique, so it is used as the primary key in
-- 04_constraints.sql. The same review_id repeated across different orders
-- is therefore not a duplicated row.

-- Orders with more than one review
SELECT
    COUNT(*) AS orders_multiple_reviews
FROM (
    SELECT
        order_id
    FROM order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) AS multiple_reviews
;
-- 547 orders with more than 1 review (0.55% of all orders)

-- Delivered orders without any review
SELECT COUNT(*) AS delivered_without_review
FROM orders o
WHERE o.order_status = 'delivered'
  AND NOT EXISTS (
      SELECT 1
      FROM order_reviews r
      WHERE r.order_id = o.order_id
  )
;
-- 646 delivered orders have no review, they are left out of the review analysis.

-- customer_id vs customer_unique_id
SELECT
    COUNT(*) AS customer_ids,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers
;
-- 99,441 customer_id values and 96,096 customer_unique_id values: customer_id
-- identifies a customer in an order, customer_unique_id identifies the person.

-- Orphan check: child tables -> parent tables
SELECT
    'orders without customer' AS check_name,
    COUNT(*) AS n
FROM orders o
LEFT JOIN customers c
    ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL

UNION ALL
SELECT
    'order_items without order',
    COUNT(*)
FROM order_items i
LEFT JOIN orders o
    ON o.order_id = i.order_id
WHERE o.order_id IS NULL

UNION ALL
SELECT
    'order_payments without order',
    COUNT(*)
FROM order_payments p
LEFT JOIN orders o
    ON o.order_id = p.order_id
WHERE o.order_id IS NULL

UNION ALL
SELECT
    'order_reviews without order',
    COUNT(*)
FROM order_reviews r
LEFT JOIN orders o
    ON o.order_id = r.order_id
WHERE o.order_id IS NULL

UNION ALL
SELECT
    'orders without items',
    COUNT(*)
FROM orders o
LEFT JOIN order_items i
    ON i.order_id = o.order_id
WHERE i.order_id IS NULL

UNION ALL
SELECT
    'orders without payments',
    COUNT(*)
FROM orders o
LEFT JOIN order_payments p
    ON p.order_id = o.order_id
WHERE p.order_id IS NULL
;
-- 775 orders without items and 1 order without payment. No other orphans.

-- Orphan check: order_items -> products / sellers
SELECT 
    'items without product' AS check_name,
    COUNT(*) AS n
FROM order_items i
LEFT JOIN products p
    ON p.product_id = i.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT
    'items without seller',
    COUNT(*)
FROM order_items i
LEFT JOIN sellers s
    ON s.seller_id = i.seller_id
WHERE s.seller_id IS NULL
;
-- No orphans: foreign keys can be added safely.

-- Orders without items, by status
SELECT 
    o.order_status,
    COUNT(*) AS orders
FROM orders o
LEFT JOIN order_items i
    ON i.order_id = o.order_id
WHERE i.order_id IS NULL
GROUP BY o.order_status
ORDER BY orders DESC
;
-- No delivered order without items: they are unavailable (603), canceled (164),
-- created (5), invoiced (2) and shipped (1).

-- The order without payment
SELECT 
    o.order_id,
    o.order_status
FROM orders o
LEFT JOIN order_payments p
    ON p.order_id = o.order_id
WHERE p.order_id IS NULL
;
-- 1 delivered order has no payment record.


-- Validity of price and freight values
SELECT
    COUNT(*) FILTER (WHERE price <= 0) AS non_positive_price,
    COUNT(*) FILTER (WHERE freight_value < 0) AS negative_freight
FROM order_items
;
-- All zero

-- Validity of payment and payment installments values
SELECT
    COUNT(*) FILTER (WHERE payment_value <= 0) AS non_positive_payment,
    COUNT(*) FILTER (WHERE payment_installments < 1) AS invalid_installments
FROM order_payments
;
-- 9 payments with value 0 and 2 payments with 0 installments.

-- Payments with invalid installments, compared against the order total
SELECT p.order_id,
       p.payment_sequential,
       p.payment_type,
       p.payment_installments,
       p.payment_value,
       (SELECT SUM(i.price + i.freight_value)
        FROM order_items i
        WHERE i.order_id = p.order_id) AS items_total,
       (SELECT COUNT(*)
        FROM order_payments p2
        WHERE p2.order_id = p.order_id) AS payments_in_order
FROM order_payments p
WHERE p.payment_installments < 1
;
-- In both orders the single payment equals the items total (price + freight).

-- Non positive payments details
SELECT *
FROM order_payments
WHERE payment_value <= 0
;
-- 6 'voucher' payments and 3 'not_defined' payments, all with value 0.

-- Zero value 'not_defined' payments
SELECT p.order_id,
       o.order_status,
       p.payment_type,
       p.payment_value,
       (SELECT SUM(i.price + i.freight_value)
        FROM order_items i
        WHERE i.order_id = p.order_id) AS items_total
FROM order_payments p
JOIN orders o ON o.order_id = p.order_id
WHERE p.payment_value <= 0
  AND p.payment_type = 'not_defined'
;
-- The 3 'not_defined' payments belong to canceled orders with no items.

-- Review scale
SELECT 
    MIN(review_score) AS min_score,
    MAX(review_score) AS max_score
FROM order_reviews
;
-- Reviews go from 1 to 5.

-- Logical consistency (dates)
SELECT
    COUNT(*) FILTER (WHERE order_approved_at < order_purchase_timestamp)
        AS approved_before_purchase,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date < order_purchase_timestamp)
        AS carrier_before_purchase,
    COUNT(*) FILTER (WHERE order_delivered_customer_date < order_delivered_carrier_date)
        AS delivered_before_carrier,
    COUNT(*) FILTER (WHERE order_delivered_customer_date < order_purchase_timestamp)
        AS delivered_before_purchase
FROM orders
;
-- 166 orders with a carrier date before the purchase date and 23 delivered
-- before the carrier date. No order is approved or delivered before purchase.
-- These dates are not used in the analysis (it only uses purchase, estimated
-- and customer delivery dates), so no rows are removed.

-- Products without category / without English translation
SELECT
    COUNT(*) FILTER (WHERE p.product_category_name IS NULL) AS null_category,
    COUNT(*) FILTER (WHERE p.product_category_name IS NOT NULL
                     AND t.product_category_name IS NULL)  AS without_translation
FROM products p
LEFT JOIN category_translation t
       ON t.product_category_name = p.product_category_name
;
-- 610 products with null category, and 13 products with a category that has
-- no English translation.

-- Categories without English translation
SELECT p.product_category_name,
       COUNT(*) AS products
FROM products p
LEFT JOIN category_translation t
       ON t.product_category_name = p.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL
GROUP BY p.product_category_name
;
-- 2 categories without English translation:
-- portateis_cozinha_e_preparadores_de_alimentos (10 products) and pc_gamer (3).

-- Profile of products without category
SELECT
    COUNT(*)                                   AS products_no_category,
    COUNT(*) FILTER (WHERE product_name_length IS NULL)        AS null_name_length,
    COUNT(*) FILTER (WHERE product_description_length IS NULL) AS null_description_length,
    COUNT(*) FILTER (WHERE product_photos_qty IS NULL)         AS null_photos,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL)           AS null_weight,
    COUNT(*) FILTER (WHERE product_length_cm IS NULL)          AS null_dimensions
FROM products
WHERE product_category_name IS NULL
;
-- All 610 have no category, name length, description length or photos
-- (weight and dimensions are missing in only 1 of them).

-- Weight of products without category in delivered sales
SELECT
    ROUND(100.0 * COUNT(*) FILTER (WHERE p.product_category_name IS NULL)
          / COUNT(*), 2) AS pct_items,
    ROUND(100.0 * SUM(i.price) FILTER (WHERE p.product_category_name IS NULL)
          / SUM(i.price), 2) AS pct_revenue
FROM order_items i
INNER JOIN orders o
    ON o.order_id = i.order_id
INNER JOIN products p
    ON p.product_id = i.product_id
WHERE o.order_status = 'delivered'
;
-- 1.39% of delivered items and 1.29% of delivered revenue (all periods).
-- Decision: kept as real sales, grouped as 'unknown' in the category analysis.


/*
Summary of findings and decisions

1.  Scope: order_status = 'delivered' (96,478 orders, 97.02%).
2.  Reliable period: Jan 2017 to Aug 2018. 2016 (329 orders) and Sep-Oct 2018
    (20 orders) could be incomplete. The analysis applies the same scope to
    every question: delivered orders purchased between Jan 2017 and Aug 2018
    (96,211 orders, 267 delivered 2016 orders are excluded).
3.  8 delivered orders have no delivery date: excluded from delivery-time and
    review analysis.
4.  547 orders have multiple reviews: results are shown both averaging all
    reviews and averaging per order. 646 delivered orders have no review.
5.  customer_id is per order: use customer_unique_id for repeat-purchase
    analysis.
6.  166 orders have a carrier date before purchase and 23 were delivered before
    the carrier date: those columns are not used in the analysis.
7.  775 orders without items are all non-delivered: no impact on the delivered
    scope.
8.  9 payments have value 0 (6 vouchers and 3 'not_defined' payments on canceled
    orders): no impact on revenue sums.
9.  2 credit card payments with 0 installments: single payment matching the
    order total, treated as 1 installment.
10. 1 delivered order has no payment record: kept, revenue is computed from
    order_items.price, not from order_payments.
11. 610 products without category (1.29% of revenue): grouped as 'unknown'.
    13 products from 2 categories have no English translation:
    use COALESCE(english, original, 'unknown') in category analysis.
12. No orphan rows in any relationship: foreign keys added in 04_constraints.sql.
    (review_id, order_id) is unique and is used as the primary key of
    order_reviews.
*/