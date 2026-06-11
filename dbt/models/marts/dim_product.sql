{{ config(materialized='table') }}

-- SCD1 + denormalized category. We add a category_group rollup so
-- ~73 leaf categories collapse to ~12 readable groups for higher-level
-- analyses without a separate category hierarchy dim.

with src as (
    select * from {{ ref('stg_products') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_sk,
    product_id,
    category_en,
    category_pt,
    case
        when category_en in (
            'bed_bath_table', 'furniture_decor', 'furniture_living_room',
            'home_appliances', 'home_appliances_2', 'home_comfort',
            'home_construction', 'kitchen_dining_laundry_garden_furniture',
            'office_furniture', 'small_appliances', 'housewares',
            'garden_tools', 'air_conditioning'
        ) then 'home_garden'
        when category_en in (
            'health_beauty', 'perfumery', 'diapers_and_hygiene'
        ) then 'health_beauty'
        when category_en in (
            'sports_leisure', 'fashion_sport'
        ) then 'sports_leisure'
        when category_en in (
            'fashion_bags_accessories', 'fashion_shoes',
            'fashion_male_clothing', 'fashion_underwear_beach',
            'fashion_female_clothing', 'fashion_childrens_clothes'
        ) then 'fashion'
        when category_en in (
            'computers_accessories', 'computers', 'telephony',
            'tablets_printing_image', 'pc_gamer', 'electronics',
            'consoles_games', 'audio'
        ) then 'electronics'
        when category_en in (
            'food', 'drinks', 'food_drink', 'la_cuisine'
        ) then 'food_drink'
        when category_en in (
            'baby', 'toys', 'art', 'arts_and_craftmanship'
        ) then 'kids_creative'
        when category_en in (
            'auto', 'industry_commerce_and_business',
            'agro_industry_and_commerce', 'construction_tools_construction',
            'construction_tools_lights', 'construction_tools_safety',
            'construction_tools_tools', 'costruction_tools_garden'
        ) then 'industrial'
        when category_en in (
            'books_general_interest', 'books_imported',
            'books_technical', 'cds_dvds_musicals', 'music', 'dvds_blu_ray',
            'cine_photo'
        ) then 'media'
        when category_en in (
            'flowers', 'cool_stuff', 'christmas_supplies',
            'party_supplies', 'fashion_male_clothing', 'fashion_children_clothes'
        ) then 'lifestyle'
        when category_en in (
            'market_place', 'signaling_and_security', 'stationery',
            'luggage_accessories', 'watches_gifts', 'security_and_services',
            'fixed_telephony'
        ) then 'misc_retail'
        else 'other'
    end                                                       as category_group,
    weight_g,
    volume_cm3,
    photos_qty
from src
