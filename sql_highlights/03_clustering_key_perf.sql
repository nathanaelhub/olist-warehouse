/*
  Clustering-key performance demonstration.

  fact_orders is materialised with `CLUSTER BY (purchase_date_key)`.
  Run the query below WITH the cluster key in effect, and again after
  rebuilding fact_orders without it. Compare:

    SELECT * FROM TABLE(GET_QUERY_OPERATOR_STATS(<query_id>));

  The "Partitions scanned" / "Partitions total" ratio is the win.

  Why it's in the highlights:
   - Most BI dashboards filter by date first; clustering on the
     time-key is the single most effective optimisation for a
     fact table at this scale (and most scales).
   - The story on the portfolio page is "before: scanned 100% of
     partitions; after: scanned ~20%; query went from X to Y."
*/

-- 1. Pick a representative dashboard query: 6-month window, grouped
--    by region + month, the kind a 'revenue by region' panel makes.

select
    g.region,
    d.year,
    d.month,
    count(distinct f.order_id)                   as orders_n,
    sum(f.gross_item_value)                      as gross_revenue,
    avg(f.delivery_days)                         as avg_delivery_days,
    sum(case when f.is_late then 1 else 0 end)::float
        / count(*)                               as late_rate
from marts.fact_orders f
join marts.dim_date     d on f.purchase_date_key = d.date_key
join marts.dim_geography g on f.customer_geo_sk  = g.geo_sk
where d.date between '2018-01-01' and '2018-06-30'
group by 1, 2, 3
order by 1, 2, 3;

-- 2. Then run, for the same query_id you just generated:
/*

with last_q as (
    select last_query_id() as qid
)
select
    operator_type,
    operator_attributes,
    operator_statistics
from table(get_query_operator_stats((select qid from last_q)));

-- Look at the TableScan rows. partitions_scanned vs partitions_total
-- is the headline number.

*/

-- 3. To compare, rebuild fact_orders without a cluster key:
/*

create or replace table marts.fact_orders_no_cluster as
    select * from marts.fact_orders;

alter table marts.fact_orders_no_cluster drop clustering key;

-- Replace `marts.fact_orders` with `marts.fact_orders_no_cluster` in
-- query 1, run, then look at operator stats again.

*/
