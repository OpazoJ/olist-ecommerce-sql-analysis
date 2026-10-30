/*
============================================
    01_schema.sql
    Table definitions for the Olist dataset
============================================

Safe to re-run: existing tables are dropped first so a second run does not leave duplicated rows
(order_reviews and geolocation have no primary key until 04_constraints.sql, so a repeated load 
would not fail, it would silently double the data).
Foreign keys are added later, in 04_constraints.sql, after the data has been loaded and validated.
*/

DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders,
                     products, category_translation, sellers, customers,
                     geolocation CASCADE;
 
-- Zip code prefixes are VARCHAR(5), not INTEGER, to keep leading zeros
-- (e.g. '01037').
 
CREATE TABLE customers (
    customer_id                 VARCHAR(32) PRIMARY KEY,
    customer_unique_id          VARCHAR(32),
    customer_zip_code_prefix    VARCHAR(5),
    customer_city               TEXT,
    customer_state              CHAR(2)
);
 
CREATE TABLE sellers (
    seller_id                   VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix      VARCHAR(5),
    seller_city                 TEXT,
    seller_state                CHAR(2)
);
 
-- The source CSV spells two headers "product_name_lenght" and
-- "product_description_lenght". Here they are corrected to "length".
-- \copy matches columns by position, not by name, so the load still works.
CREATE TABLE products (
    product_id                  VARCHAR(32) PRIMARY KEY,
    product_category_name       TEXT,
    product_name_length         INTEGER,
    product_description_length  INTEGER,
    product_photos_qty          INTEGER,
    product_weight_g            INTEGER,
    product_length_cm           INTEGER,
    product_height_cm           INTEGER,
    product_width_cm            INTEGER
);
 
CREATE TABLE category_translation (
    product_category_name           TEXT PRIMARY KEY,
    product_category_name_english   TEXT
);
 
CREATE TABLE orders (
    order_id                        VARCHAR(32) PRIMARY KEY,
    customer_id                     VARCHAR(32),
    order_status                    TEXT,
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP
);
 
CREATE TABLE order_items (
    order_id            VARCHAR(32),
    order_item_id       INTEGER,
    product_id          VARCHAR(32),
    seller_id           VARCHAR(32),
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(10,2),
    freight_value       NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);
 
CREATE TABLE order_payments (
    order_id                VARCHAR(32),
    payment_sequential      INTEGER,
    payment_type            TEXT,
    payment_installments    INTEGER,
    payment_value           NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);
 
-- No primary key yet: review_id is not unique on its own (789 repeated values,
-- see 03_quality.sql). The pair (review_id, order_id) is unique and is set as
-- the primary key in 04_constraints.sql.
CREATE TABLE order_reviews (
    review_id               VARCHAR(32),
    order_id                VARCHAR(32),
    review_score            INTEGER,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);
 
-- No key: each zip code prefix appears many times (one row per coordinate).
CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(5),
    geolocation_lat             DOUBLE PRECISION,
    geolocation_lng             DOUBLE PRECISION,
    geolocation_city            TEXT,
    geolocation_state           CHAR(2)
);