/*
  RAW layer — one table per Olist CSV, types match the source as
  closely as Snowflake will allow. No transformations here; staging
  models (in dbt) do the rename + cast.

      snow sql -f snowflake/ddl/02_raw_tables.sql
*/

USE ROLE WAREHOUSE_DEV;
USE WAREHOUSE LOAD_WH;
USE DATABASE OLIST;
USE SCHEMA RAW;

-- 1. Customers
CREATE OR REPLACE TABLE customers (
    customer_id              STRING NOT NULL,
    customer_unique_id       STRING NOT NULL,
    customer_zip_code_prefix STRING,
    customer_city            STRING,
    customer_state           STRING
);

-- 2. Orders (the head record; one row per order)
CREATE OR REPLACE TABLE orders (
    order_id                      STRING NOT NULL,
    customer_id                   STRING NOT NULL,
    order_status                  STRING,
    order_purchase_timestamp      TIMESTAMP_NTZ,
    order_approved_at             TIMESTAMP_NTZ,
    order_delivered_carrier_date  TIMESTAMP_NTZ,
    order_delivered_customer_date TIMESTAMP_NTZ,
    order_estimated_delivery_date TIMESTAMP_NTZ
);

-- 3. Order items (one row per order × product; this is the *grain* of fact_orders)
CREATE OR REPLACE TABLE order_items (
    order_id            STRING NOT NULL,
    order_item_id       NUMBER,
    product_id          STRING NOT NULL,
    seller_id           STRING NOT NULL,
    shipping_limit_date TIMESTAMP_NTZ,
    price               NUMBER(12, 2),
    freight_value       NUMBER(12, 2)
);

-- 4. Order payments (one row per payment method per order — may be multiple per order)
CREATE OR REPLACE TABLE order_payments (
    order_id             STRING NOT NULL,
    payment_sequential   NUMBER,
    payment_type         STRING,
    payment_installments NUMBER,
    payment_value        NUMBER(12, 2)
);

-- 5. Order reviews (zero or one per order)
CREATE OR REPLACE TABLE order_reviews (
    review_id               STRING,
    order_id                STRING NOT NULL,
    review_score            NUMBER,
    review_comment_title    STRING,
    review_comment_message  STRING,
    review_creation_date    TIMESTAMP_NTZ,
    review_answer_timestamp TIMESTAMP_NTZ
);

-- 6. Products
CREATE OR REPLACE TABLE products (
    product_id                  STRING NOT NULL,
    product_category_name       STRING,
    product_name_lenght         NUMBER,
    product_description_lenght  NUMBER,
    product_photos_qty          NUMBER,
    product_weight_g            NUMBER,
    product_length_cm           NUMBER,
    product_height_cm           NUMBER,
    product_width_cm            NUMBER
);

-- 7. Sellers
CREATE OR REPLACE TABLE sellers (
    seller_id              STRING NOT NULL,
    seller_zip_code_prefix STRING,
    seller_city            STRING,
    seller_state           STRING
);

-- 8. Geolocation (zip → lat/lng, multiple rows per zip)
CREATE OR REPLACE TABLE geolocation (
    geolocation_zip_code_prefix STRING NOT NULL,
    geolocation_lat             FLOAT,
    geolocation_lng             FLOAT,
    geolocation_city            STRING,
    geolocation_state           STRING
);

-- Reference table: Portuguese category names → English (Olist ships a translation CSV)
CREATE OR REPLACE TABLE product_category_name_translation (
    product_category_name         STRING NOT NULL,
    product_category_name_english STRING
);

SELECT
    (SELECT COUNT(*) FROM customers)                          AS n_customer_tables,
    (SELECT COUNT(*) FROM orders)                             AS n_orders_tables,
    (SELECT COUNT(*) FROM order_items)                        AS n_items_tables,
    (SELECT COUNT(*) FROM order_payments)                     AS n_payments_tables,
    (SELECT COUNT(*) FROM order_reviews)                      AS n_reviews_tables,
    (SELECT COUNT(*) FROM products)                           AS n_products_tables,
    (SELECT COUNT(*) FROM sellers)                            AS n_sellers_tables,
    (SELECT COUNT(*) FROM geolocation)                        AS n_geolocation_tables,
    (SELECT COUNT(*) FROM product_category_name_translation)  AS n_translation_tables;
