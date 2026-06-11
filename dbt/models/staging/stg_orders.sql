{{ config(materialized='view') }}

-- Staging for orders. Renames are deliberate: shed the redundant
-- "order_" prefix on every column, since the table name carries that
-- context.

with src as (
    select * from {{ source('raw', 'orders') }}
)

select
    order_id,
    customer_id,
    order_status                                       as status,
    order_purchase_timestamp                           as purchased_at,
    order_approved_at                                  as approved_at,
    order_delivered_carrier_date                       as carrier_at,
    order_delivered_customer_date                      as delivered_at,
    order_estimated_delivery_date                      as estimated_delivery_at,

    -- Derived columns. Kept here (not in marts) so all downstream
    -- models see consistent definitions.
    datediff('day', order_purchase_timestamp,
             order_delivered_customer_date)            as delivery_days,
    datediff('day', order_estimated_delivery_date,
             order_delivered_customer_date)            as days_late_vs_estimate,
    case
        when order_delivered_customer_date is null then null
        when order_delivered_customer_date > order_estimated_delivery_date then true
        else false
    end                                                as is_late
from src
