{{ config(materialized='view') }}

select
    seller_id,
    seller_zip_code_prefix as zip_prefix,
    initcap(seller_city)   as city,
    upper(seller_state)    as state_code
from {{ source('raw', 'sellers') }}
