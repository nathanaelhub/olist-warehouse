{{ config(materialized='table') }}

-- SCD Type 2: customer_unique_id is the person; the same person can
-- have multiple customer_id values (Olist mints a new one per order).
-- City/state can change over time as people move; we track the
-- transitions so historic orders join to the customer state that was
-- current when they ordered.

with src as (
    select
        c.customer_id,
        c.customer_unique_id,
        c.zip_prefix,
        c.city,
        c.state_code,
        -- attach the *earliest* order timestamp this customer_id appears in
        min(o.purchased_at) as first_seen_at
    from {{ ref('stg_customers') }} c
    left join {{ ref('stg_orders') }} o on o.customer_id = c.customer_id
    group by 1, 2, 3, 4, 5
),

-- Detect changes by looking at consecutive (zip, city, state) tuples
-- for the same customer_unique_id, ordered by first_seen_at.
changes as (
    select
        customer_unique_id,
        zip_prefix,
        city,
        state_code,
        first_seen_at,
        lag(zip_prefix) over (
            partition by customer_unique_id order by first_seen_at
        ) as prev_zip,
        lead(first_seen_at) over (
            partition by customer_unique_id order by first_seen_at
        ) as next_change_at
    from src
),

new_versions as (
    -- Keep only the rows where attributes changed (or it's the first row).
    select
        customer_unique_id,
        zip_prefix,
        city,
        state_code,
        first_seen_at as valid_from,
        coalesce(next_change_at, to_timestamp_ntz('2999-12-31')) as valid_to
    from changes
    where prev_zip is null or prev_zip != zip_prefix
)

select
    {{ dbt_utils.generate_surrogate_key([
        'customer_unique_id', 'valid_from'
    ]) }}                                                 as customer_sk,
    customer_unique_id,
    zip_prefix,
    city,
    state_code,
    valid_from,
    valid_to,
    case when valid_to = to_timestamp_ntz('2999-12-31') then true else false end
                                                          as is_current
from new_versions
