{{ config(materialized='view') }}

with src as (
    select * from {{ source('raw', 'products') }}
),
trans as (
    select * from {{ source('raw', 'product_category_name_translation') }}
)

select
    s.product_id,
    s.product_category_name                              as category_pt,
    coalesce(t.product_category_name_english,
             s.product_category_name, 'unknown')         as category_en,
    s.product_weight_g                                   as weight_g,
    s.product_length_cm * s.product_height_cm * s.product_width_cm
                                                         as volume_cm3,
    s.product_photos_qty                                 as photos_qty
from src s
left join trans t on s.product_category_name = t.product_category_name
