/*
============================================
    04_constraints.sql
    Keys and indexes (added after loading and validating the data)
============================================
-- Safe to run once on a fresh load. To start over, re-run 01_schema.sql.
*/

-- Primary key for order_reviews: review_id alone repeats, but the pair
-- (review_id, order_id) is unique (checked in 03_quality.sql).
ALTER TABLE order_reviews
    ADD CONSTRAINT pk_order_reviews
    PRIMARY KEY (review_id, order_id);

-- Foreign keys (03_quality.sql found no orphan rows)
ALTER TABLE orders
    ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id);

ALTER TABLE order_items
    ADD CONSTRAINT fk_items_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id);

ALTER TABLE order_items
    ADD CONSTRAINT fk_items_product
    FOREIGN KEY (product_id) REFERENCES products (product_id);

ALTER TABLE order_items
    ADD CONSTRAINT fk_items_seller
    FOREIGN KEY (seller_id) REFERENCES sellers (seller_id);

ALTER TABLE order_payments
    ADD CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id);

ALTER TABLE order_reviews
    ADD CONSTRAINT fk_reviews_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id);

-- Indexes on foreign key columns used in joins. PostgreSQL does not create
-- them automatically. order_items.order_id and order_payments.order_id are
-- already covered by their composite primary keys.
CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX idx_items_product   ON order_items (product_id);
CREATE INDEX idx_items_seller    ON order_items (seller_id);
CREATE INDEX idx_reviews_order   ON order_reviews (order_id);

-- Not added:
-- products -> category_translation: 13 products belong to 2 categories that
--   have no translation, so the foreign key would fail.
-- geolocation: zip code prefixes repeat, so there is no key to reference
--   (customers, sellers and geolocation relate only by zip code prefix).