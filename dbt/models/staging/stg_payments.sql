{{ config(materialized='view') }}

select
    order_id,
    payment_sequential   as seq,
    payment_type         as type,
    payment_installments as installments,
    payment_value        as value
from {{ source('raw', 'order_payments') }}
