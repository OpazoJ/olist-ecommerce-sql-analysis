/*
=========================================
    02_verification.sql
    Verify that every table loaded the same number of rows as its CSV file
=========================================

Expected counts are the number of records in each CSV (header excluded).
Note: the reviews CSV has more physical lines (104,719) than records
(99,224) because some comments contain line breaks.
*/

WITH loaded AS (
    SELECT 'customers' AS table_name, COUNT(*) AS loaded_rows FROM customers
    UNION ALL SELECT 'sellers',              COUNT(*) FROM sellers
    UNION ALL SELECT 'products',             COUNT(*) FROM products
    UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation
    UNION ALL SELECT 'orders',               COUNT(*) FROM orders
    UNION ALL SELECT 'order_items',          COUNT(*) FROM order_items
    UNION ALL SELECT 'order_payments',       COUNT(*) FROM order_payments
    UNION ALL SELECT 'order_reviews',        COUNT(*) FROM order_reviews
    UNION ALL SELECT 'geolocation',          COUNT(*) FROM geolocation
),
expected (table_name, expected_rows) AS (
    VALUES ('customers',            99441),
           ('sellers',               3095),
           ('products',             32951),
           ('category_translation',    71),
           ('orders',               99441),
           ('order_items',         112650),
           ('order_payments',      103886),
           ('order_reviews',        99224),
           ('geolocation',       1000163)
)
 
SELECT
    l.table_name,
    l.loaded_rows,
    e.expected_rows,
    l.loaded_rows = e.expected_rows AS matches
FROM loaded l
INNER JOIN expected e
    ON e.table_name = l.table_name
ORDER BY l.table_name
;
-- All 9 tables match (matches = true).