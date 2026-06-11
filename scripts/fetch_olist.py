"""
Download the Olist CSVs from Kaggle into data/raw/.

Prereqs:
    pip install kaggle
    Kaggle API token at ~/.kaggle/kaggle.json
        (Account → Create New API Token on kaggle.com)

Usage:
    python scripts/fetch_olist.py
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

DATASET = "olistbr/brazilian-ecommerce"
TARGET = Path(__file__).resolve().parent.parent / "data" / "raw"

EXPECTED_FILES = {
    "olist_customers_dataset.csv",
    "olist_orders_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "olist_geolocation_dataset.csv",
    "product_category_name_translation.csv",
}


def main() -> int:
    TARGET.mkdir(parents=True, exist_ok=True)

    cmd = ["kaggle", "datasets", "download", "-d", DATASET, "-p", str(TARGET), "--unzip"]
    print(f"$ {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr, file=sys.stderr)
        return result.returncode

    landed = {p.name for p in TARGET.glob("*.csv")}
    missing = EXPECTED_FILES - landed
    if missing:
        print(f"missing expected files: {sorted(missing)}", file=sys.stderr)
        return 1
    extra = landed - EXPECTED_FILES
    if extra:
        print(f"warning — unexpected files in {TARGET}: {sorted(extra)}")

    print(f"\nlanded {len(landed)} CSVs in {TARGET}")
    for f in sorted(landed):
        size_mb = (TARGET / f).stat().st_size / 1_048_576
        print(f"  {f:48s}  {size_mb:7.2f} MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
