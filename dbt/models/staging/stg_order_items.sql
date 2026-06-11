{{ config(materialized='view') }}

select
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date as shipping_limit_at,
    price,
    freight_value       as freight,
    price + freight_value as gross_item_value
from {{ source('raw', 'order_items') }}
