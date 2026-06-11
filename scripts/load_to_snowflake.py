"""
Load data/raw/*.csv into OLIST.RAW.* via PUT + COPY INTO.

Uses the snowflake-connector-python driver. Authentication comes from
the same ~/.snowflake/config.toml the `snow` CLI uses — set up first
with `snow connection add`.

Usage:
    pip install snowflake-connector-python tomli
    python scripts/load_to_snowflake.py
    python scripts/load_to_snowflake.py --connection my-trial-acct
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    import tomllib  # type: ignore[import-not-found]
except ModuleNotFoundError:  # py<3.11
    import tomli as tomllib  # type: ignore[no-redef]

import snowflake.connector  # type: ignore[import-not-found]


RAW_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"

# Order matters only for FK-style dependency in dbt downstream — at raw
# load it's just nine independent COPY INTOs.
LOADS: list[tuple[str, str]] = [
    ("olist_customers_dataset.csv",                  "customers"),
    ("olist_orders_dataset.csv",                     "orders"),
    ("olist_order_items_dataset.csv",                "order_items"),
    ("olist_order_payments_dataset.csv",             "order_payments"),
    ("olist_order_reviews_dataset.csv",              "order_reviews"),
    ("olist_products_dataset.csv",                   "products"),
    ("olist_sellers_dataset.csv",                    "sellers"),
    ("olist_geolocation_dataset.csv",                "geolocation"),
    ("product_category_name_translation.csv",        "product_category_name_translation"),
]


def load_connection(name: str | None) -> dict[str, str]:
    cfg_path = Path.home() / ".snowflake" / "config.toml"
    if not cfg_path.exists():
        raise SystemExit(
            "no ~/.snowflake/config.toml — run `snow connection add` first"
        )
    with cfg_path.open("rb") as f:
        cfg = tomllib.load(f)
    connections = cfg.get("connections", {})
    if not connections:
        raise SystemExit("no [connections.*] entries in ~/.snowflake/config.toml")
    if name is None:
        default = cfg.get("default_connection_name")
        if default and default in connections:
            return connections[default]
        # fall back to the first entry
        return next(iter(connections.values()))
    if name not in connections:
        raise SystemExit(f"connection '{name}' not found in config")
    return connections[name]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--connection", help="connection name in ~/.snowflake/config.toml")
    ap.add_argument("--truncate-first", action="store_true", default=True)
    args = ap.parse_args()

    if not RAW_DIR.exists():
        raise SystemExit(f"no raw data at {RAW_DIR} — run scripts/fetch_olist.py first")

    conn_args = load_connection(args.connection)
    # Pin role/warehouse/db/schema regardless of what the default is.
    conn_args = {
        **conn_args,
        "role": "WAREHOUSE_DEV",
        "warehouse": "LOAD_WH",
        "database": "OLIST",
        "schema": "RAW",
    }
    print(f"connecting to {conn_args.get('account')} as {conn_args.get('user')}...")

    with snowflake.connector.connect(**conn_args) as conn, conn.cursor() as cur:
        cur.execute("USE ROLE WAREHOUSE_DEV")
        cur.execute("USE WAREHOUSE LOAD_WH")
        cur.execute("USE DATABASE OLIST")
        cur.execute("USE SCHEMA RAW")

        for csv_name, table in LOADS:
            src = RAW_DIR / csv_name
            if not src.exists():
                print(f"  skip {csv_name} (not found locally)")
                continue

            if args.truncate_first:
                cur.execute(f"TRUNCATE TABLE {table}")

            print(f"  PUT {csv_name} -> @OLIST_STAGE/{table}/")
            cur.execute(
                f"PUT 'file://{src}' @OLIST_STAGE/{table}/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE"
            )

            print(f"  COPY INTO {table}")
            cur.execute(
                f"""
                COPY INTO {table}
                FROM @OLIST_STAGE/{table}/
                FILE_FORMAT = (
                    TYPE = 'CSV'
                    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
                    SKIP_HEADER = 1
                    NULL_IF = ('', 'NA')
                )
                ON_ERROR = 'CONTINUE'
                """
            )
            rows = cur.fetchall()
            for r in rows:
                print(f"    -> {r}")

            # Spot-check the row count made it through.
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            (n,) = cur.fetchone()
            print(f"    {table}: {n:,} rows landed\n")

        print("done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
