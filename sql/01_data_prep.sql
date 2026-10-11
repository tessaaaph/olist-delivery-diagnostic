-- ============================================================
-- Olist Brazilian E-Commerce — Data Preparation & Diagnostics
-- ============================================================
-- Purpose : Confirm the loaded dataset is complete and correctly
--           typed before analysis begins.
-- Checks  : Table row counts, orders schema, delivery status
--           distribution, and presence of NULL timestamps.
-- Source  : Olist Brazilian E-Commerce Public Dataset (Kaggle)
-- ============================================================


-- ------------------------------------------------------------
-- Check 1 — Row counts across all tables
-- ------------------------------------------------------------
-- Confirms every table loaded correctly and matches expected
-- dataset sizes.

SELECT 'customers' AS table_name, COUNT(*) AS rows FROM customers
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation;


-- ------------------------------------------------------------
-- Check 2 — Schema of the orders table
-- ------------------------------------------------------------
-- The orders table is the analytical core. This confirms column
-- names and types before writing the diagnostic queries.

PRAGMA table_info(orders);


-- ------------------------------------------------------------
-- Check 3 — Delivery timestamp completeness
-- ------------------------------------------------------------
-- Not every order has a delivered_customer_date. This identifies
-- how many orders cannot be evaluated for lateness.

SELECT
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS not_delivered,
    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS missing_estimate,
    SUM(CASE WHEN order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL THEN 1 ELSE 0 END) AS evaluable_orders
FROM orders;