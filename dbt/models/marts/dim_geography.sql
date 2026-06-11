{{ config(materialized='table') }}

-- Conformed geography dim, used by both customer and seller dims.
-- Adds the 5-region rollup (Norte/Nordeste/Centro-Oeste/Sudeste/Sul)
-- so dashboards roll up without join chains.

with geo as (
    select * from {{ ref('stg_geolocation') }}
),

with_region as (
    select
        zip_prefix,
        state_code,
        city,
        lat,
        lng,
        case state_code
            when 'AC' then 'Norte' when 'AP' then 'Norte' when 'AM' then 'Norte'
            when 'PA' then 'Norte' when 'RO' then 'Norte' when 'RR' then 'Norte'
            when 'TO' then 'Norte'
            when 'AL' then 'Nordeste' when 'BA' then 'Nordeste' when 'CE' then 'Nordeste'
            when 'MA' then 'Nordeste' when 'PB' then 'Nordeste' when 'PE' then 'Nordeste'
            when 'PI' then 'Nordeste' when 'RN' then 'Nordeste' when 'SE' then 'Nordeste'
            when 'DF' then 'Centro-Oeste' when 'GO' then 'Centro-Oeste'
            when 'MT' then 'Centro-Oeste' when 'MS' then 'Centro-Oeste'
            when 'ES' then 'Sudeste' when 'MG' then 'Sudeste'
            when 'RJ' then 'Sudeste' when 'SP' then 'Sudeste'
            when 'PR' then 'Sul' when 'RS' then 'Sul' when 'SC' then 'Sul'
        end as region
    from geo
)

select
    {{ dbt_utils.generate_surrogate_key(['zip_prefix']) }} as geo_sk,
    zip_prefix,
    state_code,
    region,
    city,
    lat,
    lng
from with_region
