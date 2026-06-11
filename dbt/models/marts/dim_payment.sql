{{ config(materialized='table') }}

-- Composite dim: one row per (type, installments). Small (~30 rows).

with src as (
    select distinct
        type,
        installments
    from {{ ref('stg_payments') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['type', 'installments']) }} as payment_sk,
    type,
    installments,
    case
        when type = 'voucher'      then 'voucher'
        when installments <= 1     then 'single_payment'
        when installments between 2 and 5  then 'short_installment'
        when installments between 6 and 11 then 'medium_installment'
        else 'long_installment'
    end                                                              as installment_bucket
from src
