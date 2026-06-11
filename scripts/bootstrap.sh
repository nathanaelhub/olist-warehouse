#!/usr/bin/env bash
#
# Bootstrap the whole pipeline after you've stood up Snowflake credentials
# and Kaggle credentials. Idempotent — safe to re-run if a step fails.
#
# Prereqs you do yourself (~2 min total):
#   1. snow connection add   # one interactive prompt
#   2. mv ~/Downloads/kaggle.json ~/.kaggle/ && chmod 600 ~/.kaggle/kaggle.json
#
# Then:
#   bash scripts/bootstrap.sh
#
# Each phase is gated and reports clearly on failure.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Pretty output -------------------------------------------------------------

readonly RESET=$'\033[0m'
readonly BOLD=$'\033[1m'
readonly DIM=$'\033[2m'
readonly GREEN=$'\033[32m'
readonly YELLOW=$'\033[33m'
readonly RED=$'\033[31m'
readonly BLUE=$'\033[34m'

phase()  { printf '\n%s━━━ %s %s\n' "$BOLD$BLUE" "$1" "$RESET"; }
step()   { printf '%s→%s %s\n' "$DIM" "$RESET" "$1"; }
ok()     { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
warn()   { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$1" >&2; }
fail()   { printf '%s✗%s %s\n' "$RED" "$RESET" "$1" >&2; exit 1; }
need()   { command -v "$1" >/dev/null 2>&1 || fail "missing prereq: $1"; }

# Phase 0 — sanity checks ---------------------------------------------------

phase "0 · sanity checks"

need snow         || fail "snow CLI not installed — run: curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh | sh"
need python3      || fail "python3 missing"
need pip          || fail "pip missing — install via 'python3 -m ensurepip --upgrade'"

[[ -f ~/.snowflake/config.toml ]] || fail "~/.snowflake/config.toml missing — run: snow connection add"

if [[ -d "${KAGGLE_CONFIG_DIR:-$HOME/.kaggle}" && -f "${KAGGLE_CONFIG_DIR:-$HOME/.kaggle}/kaggle.json" ]]; then
  ok "kaggle credentials present"
else
  fail "kaggle.json missing at ~/.kaggle/kaggle.json — see kaggle.com → Account → Create New API Token"
fi

step "testing Snowflake connection..."
if ! snow connection test >/dev/null 2>&1; then
  fail "snow connection test failed — check ~/.snowflake/config.toml"
fi
ok "Snowflake connection verified"

# Phase 1 — Python deps -----------------------------------------------------

phase "1 · python dependencies"

step "installing snowflake-connector-python, kaggle, dbt-snowflake..."
pip install --quiet \
  snowflake-connector-python \
  kaggle \
  dbt-snowflake \
  tomli || fail "pip install failed"
ok "deps installed"

# Phase 2 — Snowflake account objects --------------------------------------

phase "2 · account objects (database, warehouses, role)"

step "running snowflake/setup/01_account_objects.sql..."
snow sql -f snowflake/setup/01_account_objects.sql \
  > /tmp/olist_setup_step2.log 2>&1 \
  || { cat /tmp/olist_setup_step2.log; fail "setup script failed (see /tmp/olist_setup_step2.log)"; }
ok "OLIST database + warehouses + WAREHOUSE_DEV role created"

step "running snowflake/ddl/02_raw_tables.sql..."
snow sql -f snowflake/ddl/02_raw_tables.sql \
  > /tmp/olist_setup_step2b.log 2>&1 \
  || { cat /tmp/olist_setup_step2b.log; fail "DDL failed (see /tmp/olist_setup_step2b.log)"; }
ok "9 raw tables created in OLIST.RAW"

# Phase 3 — Fetch Kaggle CSVs ----------------------------------------------

phase "3 · fetch Olist CSVs from Kaggle"

if [[ -d data/raw ]] && [[ $(find data/raw -name "*.csv" | wc -l) -ge 9 ]]; then
  ok "data/raw already has the 9 CSVs — skipping fetch"
else
  step "downloading dataset (~140 MB)..."
  python3 scripts/fetch_olist.py || fail "kaggle fetch failed"
  ok "9 CSVs landed in data/raw/"
fi

# Phase 4 — Load to Snowflake ----------------------------------------------

phase "4 · PUT + COPY INTO raw tables"

step "running scripts/load_to_snowflake.py..."
python3 scripts/load_to_snowflake.py \
  > /tmp/olist_load.log 2>&1 \
  || { tail -40 /tmp/olist_load.log; fail "load failed (see /tmp/olist_load.log)"; }
ok "all 9 raw tables loaded"

# Phase 5 — dbt build + test ----------------------------------------------

phase "5 · dbt — build marts + run tests"

if [[ ! -f ~/.dbt/profiles.yml ]]; then
  warn "no ~/.dbt/profiles.yml found"
  printf "\n%sCopy %s, fill in account/user/password, then re-run this script from phase 5.%s\n\n" \
    "$YELLOW" "$DIM dbt/profiles.yml.example → ~/.dbt/profiles.yml $RESET" "$RESET"
  fail "dbt profile missing"
fi

cd dbt
step "dbt deps..."
dbt deps --quiet || fail "dbt deps failed"
step "dbt run..."
dbt run > /tmp/olist_dbt_run.log 2>&1 \
  || { tail -40 /tmp/olist_dbt_run.log; fail "dbt run failed (see /tmp/olist_dbt_run.log)"; }
ok "marts built"
step "dbt test..."
dbt test > /tmp/olist_dbt_test.log 2>&1 \
  || { tail -40 /tmp/olist_dbt_test.log; fail "dbt test failed (see /tmp/olist_dbt_test.log)"; }
ok "all tests passed"
cd "$REPO_ROOT"

# Phase 6 — run the three portfolio queries --------------------------------

phase "6 · run the three portfolio queries"

step "Q1 — revenue by region..."
snow sql -q "
  SELECT g.region,
         SUM(f.gross_item_value)::number(15,2) AS revenue,
         COUNT(DISTINCT f.order_id)            AS orders
  FROM marts.fact_orders f
  JOIN marts.dim_geography g ON f.customer_geo_sk = g.geo_sk
  GROUP BY 1
  ORDER BY 2 DESC;
" 2>/dev/null | tee /tmp/olist_q1_revenue_by_region.txt

step "Q2 — seller cohort retention..."
snow sql -f sql_highlights/01_seller_retention_cohort.sql 2>/dev/null \
  | tee /tmp/olist_q2_retention.txt

step "Q3 — late delivery by category × region..."
snow sql -q "
  SELECT p.category_group,
         AVG(CASE WHEN g.region  = 'Sudeste' THEN (CASE WHEN f.is_late THEN 1.0 ELSE 0 END) END)
           ::number(5,3) AS sudeste_late_rate,
         AVG(CASE WHEN g.region != 'Sudeste' THEN (CASE WHEN f.is_late THEN 1.0 ELSE 0 END) END)
           ::number(5,3) AS rest_late_rate
  FROM marts.fact_orders f
  JOIN marts.dim_product p   ON f.product_sk    = p.product_sk
  JOIN marts.dim_geography g ON f.customer_geo_sk = g.geo_sk
  WHERE f.is_late IS NOT NULL
  GROUP BY 1
  ORDER BY 1;
" 2>/dev/null | tee /tmp/olist_q3_late_by_category.txt

# Done ---------------------------------------------------------------------

phase "✓ done"

printf "
%sThree result files saved:%s
  %s/tmp/olist_q1_revenue_by_region.txt%s
  %s/tmp/olist_q2_retention.txt%s
  %s/tmp/olist_q3_late_by_category.txt%s

%sCopy/paste those three files back to me, and I'll commit the real numbers
to the portfolio's chart components in a follow-up PR.%s
" "$BOLD" "$RESET" "$DIM" "$RESET" "$DIM" "$RESET" "$DIM" "$RESET" "$GREEN" "$RESET"
