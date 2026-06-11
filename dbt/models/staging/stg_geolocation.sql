{{ config(materialized='view') }}

-- Raw geolocation has multiple lat/lng readings per zip prefix.
-- Collapse to one row per zip — averaging coordinates is good enough
-- for choropleth-grade visualisation.

with src as (
    select
        geolocation_zip_code_prefix as zip_prefix,
        upper(geolocation_state)    as state_code,
        initcap(geolocation_city)   as city,
        geolocation_lat              as lat,
        geolocation_lng              as lng
    from {{ source('raw', 'geolocation') }}
)

select
    zip_prefix,
    -- mode-ish: take the most common (city, state) combo per zip
    mode(state_code)            as state_code,
    mode(city)                  as city,
    avg(lat)                    as lat,
    avg(lng)                    as lng
from src
group by zip_prefix
