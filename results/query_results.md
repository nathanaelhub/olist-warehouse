# Query results

Real output from the analyst queries, run against the loaded warehouse. Reproducible — re-run after `dbt run` and you'll get these numbers.

Warehouse at capture time: `fact_orders` 112,650 rows (98,666 distinct orders) · `dim_customer` 96,352 (SCD2) · `dim_geography` 19,015 · `dim_product` 32,951 · `dim_seller` 3,095.

---

## Q1 — Gross revenue by Brazilian region

| region | revenue (R$) | orders |
|---|---|---|
| Sudeste | 10,226,484 | 67,662 |
| Sul | 2,295,786 | 14,027 |
| Nordeste | 1,874,175 | 9,307 |
| Centro-Oeste | 993,279 | 5,564 |
| Norte | 409,309 | 1,832 |

Sudeste drives **65%** of the R$15.8M total across 67,662 orders; the Norte (geographically largest region) contributes 2.6%.

---

## Q2 — Seller retention by quarterly cohort (% still selling N months later)

`sql_highlights/01_seller_retention_cohort.sql`

| cohort | size | M1 | M2 | M3 | M4 | M6 | M8 |
|---|---|---|---|---|---|---|---|
| 2017-Jan | 151 | 71 | 70 | 60 | 64 | 50 | 50 |
| 2017-Apr | 116 | 54 | 47 | 50 | 49 | 38 | 38 |
| 2017-Jul | 115 | 68 | 62 | 61 | 68 | 57 | 52 |
| 2017-Oct | 147 | 66 | 55 | 56 | 48 | 48 | 37 |
| 2018-Jan | 141 | 57 | 50 | 57 | 45 | 40 | — |
| 2018-Apr | 202 | 60 | 52 | 53 | 48 | — | — |

Retention is moderate, not a churn cliff — roughly half of every cohort is still active at month 6.

---

## Q3 — Late-delivery rate by category × region (Sudeste vs rest)

| category_group | Sudeste late % | rest-of-Brazil late % |
|---|---|---|
| health_beauty | 7.4 | 11.1 |
| electronics | 7.6 | 9.8 |
| home_garden | 7.2 | 9.5 |
| fashion | 5.3 | 9.1 |
| industrial | 7.7 | 8.8 |
| sports_leisure | 7.1 | 8.1 |

Inside Sudeste the late rate sits near 7% regardless of category; outside it the rate climbs (~1.3–1.7×). The signal is geographic, not categorical.
