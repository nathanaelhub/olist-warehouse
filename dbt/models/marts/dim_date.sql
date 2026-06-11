{{ config(materialized='table') }}

-- Conformed date dimension. Generated, not loaded — one row per day
-- from 2016-01-01 to 2020-12-31 (covers Olist range + buffer).
-- Used 3 times by fact_orders (purchase / delivered / estimated),
-- aliased on each join.

with calendar as (
    select dateadd(day, seq4(), to_date('2016-01-01')) as date
    from table(generator(rowcount => 1827))   -- 5 years
)

select
    to_number(to_varchar(date, 'YYYYMMDD'))            as date_key,
    date,
    year(date)                                          as year,
    quarter(date)                                       as quarter,
    month(date)                                         as month,
    monthname(date)                                     as month_name,
    day(date)                                           as day,
    dayofweek(date)                                     as day_of_week,
    dayname(date)                                       as day_name,
    case when dayofweek(date) in (0, 6) then true else false end
                                                        as is_weekend,
    weekofyear(date)                                    as iso_week,
    case
        when month(date) in (3, 4, 5)  then 'Autumn'
        when month(date) in (6, 7, 8)  then 'Winter'
        when month(date) in (9, 10, 11) then 'Spring'
        else 'Summer'
    end                                                 as br_season
from calendar
