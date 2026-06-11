/*
  Seller retention by month-of-first-order cohort.

  Reads: marts.fact_orders, marts.dim_seller
  Output: one row per (cohort_month, months_since_cohort) with the
          % of the cohort's sellers still selling that month.

  Why it's in the highlights:
   - Uses a self-join via window function (first_seen_at per seller).
   - Cross-applies cohort × period to materialise the retention matrix
     in a single GROUP BY (no triangular subquery).
   - The output is the data behind the "seller retention" chart on the
     portfolio page.
*/

with seller_first_order as (
    select
        seller_sk,
        date_trunc('month', min(purchased_at))::date as cohort_month
    from marts.fact_orders
    group by seller_sk
),

seller_active_months as (
    select distinct
        seller_sk,
        date_trunc('month', purchased_at)::date as active_month
    from marts.fact_orders
),

cohort_size as (
    select cohort_month, count(*) as cohort_n
    from seller_first_order
    group by cohort_month
),

retention as (
    select
        f.cohort_month,
        datediff('month', f.cohort_month, a.active_month) as months_since_cohort,
        count(distinct a.seller_sk)                       as active_sellers
    from seller_first_order f
    join seller_active_months a using (seller_sk)
    where a.active_month >= f.cohort_month
    group by 1, 2
)

select
    r.cohort_month,
    r.months_since_cohort,
    r.active_sellers,
    c.cohort_n,
    round(100.0 * r.active_sellers / c.cohort_n, 1) as retention_pct
from retention r
join cohort_size c using (cohort_month)
where r.cohort_month between '2017-01-01' and '2018-06-01'
order by r.cohort_month, r.months_since_cohort;
