# Lineage

The dbt DAG from raw Olist tables through staging to the star schema. GitHub renders the mermaid graph below; `dbt docs generate && dbt docs serve` produces the interactive version locally.

```mermaid
flowchart LR
  %% sources
  s_orders[("RAW.orders")]:::src
  s_items[("RAW.order_items")]:::src
  s_cust[("RAW.customers")]:::src
  s_sell[("RAW.sellers")]:::src
  s_prod[("RAW.products")]:::src
  s_pay[("RAW.order_payments")]:::src
  s_rev[("RAW.order_reviews")]:::src
  s_geo[("RAW.geolocation")]:::src

  %% staging (views)
  st_orders["stg_orders"]:::stg
  st_items["stg_order_items"]:::stg
  st_cust["stg_customers"]:::stg
  st_sell["stg_sellers"]:::stg
  st_prod["stg_products"]:::stg
  st_pay["stg_payments"]:::stg
  st_rev["stg_reviews"]:::stg
  st_geo["stg_geolocation"]:::stg

  %% marts
  d_date["dim_date<br/>1,827"]:::dim
  d_cust["dim_customer<br/>96,352 · SCD2"]:::dim
  d_sell["dim_seller<br/>3,095"]:::dim
  d_prod["dim_product<br/>32,951"]:::dim
  d_geo["dim_geography<br/>19,015"]:::dim
  d_pay["dim_payment<br/>28"]:::dim
  f_ord["fact_orders<br/>112,650 · order × line"]:::fact

  s_orders --> st_orders
  s_items --> st_items
  s_cust --> st_cust
  s_sell --> st_sell
  s_prod --> st_prod
  s_pay --> st_pay
  s_rev --> st_rev
  s_geo --> st_geo

  st_cust --> d_cust
  st_sell --> d_sell
  st_prod --> d_prod
  st_geo --> d_geo
  st_pay --> d_pay

  st_items --> f_ord
  st_orders --> f_ord
  st_pay --> f_ord
  st_rev --> f_ord
  d_date --> f_ord
  d_cust --> f_ord
  d_sell --> f_ord
  d_prod --> f_ord
  d_geo --> f_ord
  d_pay --> f_ord

  classDef src  fill:#eef4fb,stroke:#2a6fc4,color:#1c1b18;
  classDef stg  fill:#fff,stroke:#2a6fc4,color:#1c1b18;
  classDef dim  fill:#f6f4ef,stroke:#605b50,color:#1c1b18;
  classDef fact fill:#2a6fc4,stroke:#2a6fc4,color:#fff;
```

**Reading it:** eight raw tables → eight staging views → six dimensions + one fact. `dim_date` is role-played three times on `fact_orders` (purchase / delivered / estimated); `dim_geography` is conformed across the customer and seller sides. See [`results/dbt_run.log`](../results/dbt_run.log) (15 models) and [`results/dbt_test.log`](../results/dbt_test.log) (31/31 tests passing).
