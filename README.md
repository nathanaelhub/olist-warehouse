# Olist Warehouse

An end-to-end analytics engineering case study on the public Olist Brazilian E-Commerce dataset. Raw CSVs land in Snowflake, get modeled into a Kimball-style star schema via dbt, and the resulting facts and dimensions back a narrative dashboard on [nathanaeljohnson.net/work/olist-warehouse](https://nathanaeljohnson.net/work/olist-warehouse).

The dataset is real: ~100,000 orders across 8 normalized OLTP tables published by Olist (the largest department-store marketplace in Brazil) in 2018, covering ~2 years of transactions. It's the kind of data shape a real e-commerce analytics team starts from — multi-table, partially denormalized, with timestamps that need standardising and free-text columns that need parsing.

## What this proves

- **SQL warehouse work** — query patterns that matter at scale (window functions, `QUALIFY` for top-N-per-group, clustering keys, materialized views, query result cache reasoning).
- **Dimensional modeling** — fact-table grain selection, slowly changing dimensions, conformed dimensions across multiple facts, role-playing date dimensions.
- **Snowflake** — staging, copy patterns, warehouse sizing, clustering, time travel, EXPLAIN plan reading.
- **dbt** — staging/intermediate/marts layering, tests, sources, documentation, source freshness.
- **Analytics storytelling** — turning a fact-table query into a chart that answers a business question, on a portfolio page anyone can read.

## Repo layout

```
olist-warehouse/
├── snowflake/
│   ├── setup/           # one-time account setup: database, warehouse, roles
│   └── ddl/             # raw schema CREATE TABLE statements (staging)
├── scripts/
│   ├── fetch_olist.py   # downloads CSVs from Kaggle
│   └── load_to_snowflake.py  # PUT + COPY INTO into raw tables
├── dbt/
│   ├── models/
│   │   ├── staging/     # stg_*.sql — rename + cast, one model per source
│   │   ├── intermediate/  # int_*.sql — joined + cleaned, business-rule-neutral
│   │   └── marts/       # fact_orders + dim_* — the analyst-facing layer
│   ├── tests/           # custom data tests
│   └── seeds/           # small reference data (e.g. brazilian state codes)
├── sql_highlights/      # the 3 queries called out on the portfolio page
└── docs/
    ├── architecture.md  # data flow + tool choices
    ├── star_schema.md   # grain decisions, SCD types, justification
    └── findings.md      # 3 business questions the marts can answer
```

## The pipeline

```
Kaggle CSVs
    │
    │  scripts/fetch_olist.py
    ▼
local data/raw/*.csv
    │
    │  scripts/load_to_snowflake.py
    │  (PUT to Snowflake stage → COPY INTO raw tables)
    ▼
RAW.OLIST.* (8 tables, untouched OLTP shape)
    │
    │  dbt run --select staging
    ▼
STG.OLIST.STG_* (rename, cast, drop dead columns)
    │
    │  dbt run --select intermediate
    ▼
STG.OLIST.INT_* (joined + cleaned, business-rule-neutral)
    │
    │  dbt run --select marts
    ▼
MARTS.OLIST.FACT_ORDERS + DIM_* (star schema)
    │
    ▼
Analysts query MARTS directly. Charts on the portfolio page query
exported aggregates committed to the portfolio repo (so the live site
isn't dependent on the warehouse being up).
```

## Quick start

### 1. Snowflake account

Sign up at [signup.snowflake.com](https://signup.snowflake.com) — Standard edition, any region. Free trial gives $400 credit, which is ~6 months of portfolio-scale work.

### 2. Install the Snowflake CLI

```bash
curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh | sh
snow --version
snow connection add   # interactive — fill in account/user/auth
snow connection test
```

### 3. Run the account setup

```bash
snow sql -f snowflake/setup/01_account_objects.sql
```

This creates the database (`OLIST`), warehouses (`LOAD_WH` for ingest, `XFORM_WH` for dbt, `ANALYST_WH` for queries), schemas (`RAW`, `STG`, `MARTS`), and a `WAREHOUSE_DEV` role.

### 4. Fetch + load the data

```bash
# Kaggle account required for the CSVs. Set KAGGLE_USERNAME + KAGGLE_KEY.
python scripts/fetch_olist.py        # → data/raw/*.csv
python scripts/load_to_snowflake.py  # → RAW.OLIST.*
```

### 5. Build the marts

```bash
cd dbt
dbt deps
dbt seed
dbt run
dbt test
```

### 6. Snapshot the aggregates for the portfolio

```bash
python scripts/snapshot_aggregates.py   # writes JSON exports the portfolio MDX imports
```

## Stack

| Layer | Tool | Why |
|---|---|---|
| Source | Kaggle Olist CSVs | Real, public, multi-table, non-toy |
| Warehouse | Snowflake (Standard, free trial) | Standard target for analytics-engineering roles; ergonomic SQL |
| Orchestration | Python + Snowflake CLI | Light — no Airflow needed at this scale |
| Modeling | dbt Core (CLI) | The current default for SQL transformations |
| Tests | dbt schema tests + a few custom | Catches schema regressions before charts break |
| Presentation | Hand-coded SVG charts on the portfolio | Editorial design control, no third-party iframe |

## License

MIT — the code is mine. The Olist dataset is published under [CC BY-NC-SA 4.0](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).
