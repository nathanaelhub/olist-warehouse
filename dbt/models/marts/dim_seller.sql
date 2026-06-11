{{ config(materialized='table') }}

-- SCD1 (overwrite) — see docs/star_schema.md for rationale.

select
    {{ dbt_utils.generate_surrogate_key(['seller_id']) }} as seller_sk,
    seller_id,
    zip_prefix,
    city,
    state_code
from {{ ref('stg_sellers') }}
