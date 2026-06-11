/*
  Top-5 sellers per category by revenue, last 90 days of data.

  Why it's in the highlights:
   - Demonstrates Snowflake's QUALIFY clause — solves "top-N per group"
     without the GROUP BY + self-join contortion you'd need on Postgres
     or MySQL.
   - Single pass over fact_orders, partitioned by category_group.
   - The output drives the "category leaders" panel on the portfolio
     page.

  The trick — QUALIFY filters on the result of a window function the same
  way HAVING filters on the result of a GROUP BY. Without it, you'd need:
      SELECT * FROM (... ROW_NUMBER() ...) WHERE rn <= 5
  which costs you a CTE / subquery layer for every top-N you write.
*/

select
    p.category_group,
    s.seller_id,
    g.city                                            as seller_city,
    g.state_code                                      as seller_state,
    count(distinct f.order_id)                        as orders_n,
    sum(f.gross_item_value)                           as gross_revenue,
    avg(f.review_score)                               as avg_review,
    rank() over (
        partition by p.category_group
        order by sum(f.gross_item_value) desc
    )                                                 as rank_in_category
from marts.fact_orders f
join marts.dim_product  p on f.product_sk     = p.product_sk
join marts.dim_seller   s on f.seller_sk      = s.seller_sk
join marts.dim_date     d on f.purchase_date_key = d.date_key
join marts.dim_geography g on f.seller_geo_sk = g.geo_sk
where d.date >= (select max(date) from marts.dim_date
                 where date <= (select max(purchased_at)::date from marts.fact_orders)) - 90
group by 1, 2, 3, 4
qualify rank_in_category <= 5
order by p.category_group, rank_in_category;
