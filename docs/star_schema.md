# Star schema design

This document records the grain, key, and SCD decisions for the marts layer. Every decision below has a justification — these are the points a reviewer would push on, so the justifications are the actual deliverable, not the diagrams.

## Schema diagram

```
                       ┌─────────────────────┐
                       │      DIM_DATE       │
                       │  date_key (PK)      │
                       │  date, year, month, │
                       │  day, weekday,      │
                       │  is_weekend, ...    │
                       └─────────┬───────────┘
                                 │
                       (purchase_date_key,
                        delivered_date_key,
                        estimated_date_key)
                                 │
   ┌──────────────────┐          │           ┌──────────────────┐
   │   DIM_CUSTOMER   │          ▼           │    DIM_SELLER    │
   │ customer_sk (PK) │      ┌──────────────┐│  seller_sk (PK)  │
   │ customer_unique  ├─────►│ FACT_ORDERS  │◄─┤  seller_id      │
   │ city, state,     │      │  (grain =    │  │  city, state    │
   │ region, valid_   │      │   order-item)│  │                 │
   │  from, valid_to, │      │              │  └──────────────────┘
   │ is_current       │      │ order_id     │
   └──────────────────┘      │ order_item_id│  ┌──────────────────┐
                             │ price        │  │   DIM_PRODUCT    │
   ┌──────────────────┐      │ freight      │  │ product_sk (PK)  │
   │   DIM_PAYMENT    │      │ payment_value│◄─┤ product_id       │
   │ payment_sk (PK)  │◄─────┤ review_score │  │ category_en      │
   │ payment_type     │      │ delivery_days│  │ weight_g, vol_cm3│
   │ installments     │      │ is_late      │  └──────────────────┘
   └──────────────────┘      │ purchase_date│
                             │   _key (FK)  │  ┌──────────────────┐
                             │ delivered_   │  │  DIM_GEOGRAPHY   │
                             │   date_key   │◄─┤ geo_sk (PK)      │
                             │ estimated_   │  │ zip_prefix, city,│
                             │   date_key   │  │ state, region,   │
                             │ ...          │  │ lat, lng         │
                             └──────────────┘  └──────────────────┘
```

## Fact table

### `FACT_ORDERS`

**Grain:** one row per order × line item. This is the finest grain available without going below the customer's intent (an order line they decided to buy).

Why not at the order level?
- Orders can contain multiple products from multiple sellers.
- Margin and delivery story varies per seller within the same order.
- An order-level grain would force averaging seller dimensions, which destroys the seller-attribution story this project is about.

Why not at the payment level?
- Payments are 1:N with orders (a single order can have 2 credit-card installments + 1 voucher).
- Storing the fact at payment grain would multiplicatively inflate revenue when joined to product/seller.
- Payment info is attached as a non-additive snapshot (`payment_total_value`, `payment_methods_count`) at the order level instead.

### Measures

| Column | Additivity | Notes |
|---|---|---|
| `price` | fully additive | Sum is meaningful across any cut |
| `freight_value` | fully additive | Same |
| `payment_total_value` | **non-additive across line items in same order** | Repeats; sum at order_id grain only |
| `review_score` | semi-additive (avg only) | Snapshot of the order's review |
| `delivery_days` | semi-additive (avg only) | Computed from delivered − purchase |
| `is_late` | additive (0/1) | Boolean flag for late-delivery analyses |

### Foreign keys

| FK | Points to | Notes |
|---|---|---|
| `customer_sk` | `dim_customer` (SCD2) | Surrogate, not source `customer_id` |
| `seller_sk` | `dim_seller` | One-to-many is enforced by `order_items` |
| `product_sk` | `dim_product` | Same |
| `purchase_date_key` | `dim_date` | Role-playing — see below |
| `delivered_date_key` | `dim_date` | |
| `estimated_date_key` | `dim_date` | |
| `customer_geo_sk` | `dim_geography` | Customer's location |
| `seller_geo_sk` | `dim_geography` | Seller's location |
| `payment_sk` | `dim_payment` | Composite — see notes below |

## Dimensions

### `DIM_DATE` — conformed, role-playing

Standard date dimension. Generated, not loaded — one row per day from 2016-01-01 to 2020-12-31 (covers Olist's range with a buffer).

Plays three roles on `fact_orders`: `purchase_date_key`, `delivered_date_key`, `estimated_date_key`. Each gets its own alias in queries:

```sql
SELECT
    purchase_dt.year,
    purchase_dt.quarter,
    AVG(estimate_dt.date - delivered_dt.date) AS days_early
FROM marts.fact_orders f
JOIN marts.dim_date purchase_dt  ON f.purchase_date_key  = purchase_dt.date_key
JOIN marts.dim_date delivered_dt ON f.delivered_date_key = delivered_dt.date_key
JOIN marts.dim_date estimate_dt  ON f.estimated_date_key = estimate_dt.date_key
WHERE f.is_delivered = TRUE
GROUP BY 1, 2;
```

### `DIM_CUSTOMER` — **SCD Type 2**

Why SCD2? Customer city/state changes over time (people move). A late-2018 order being attributed to a customer's 2016 city would skew geographic analyses. The natural-key vs surrogate distinction matters here:

- `customer_id` (source PK) is actually **per-order**, not per-person — Olist generates a new `customer_id` for each transaction.
- `customer_unique_id` is the actual person.

So the SCD2 keys are:
- `customer_sk` (surrogate, monotonic)
- `customer_unique_id` (business key)
- `valid_from`, `valid_to`, `is_current`

Same `customer_unique_id` → multiple `customer_sk` rows if they relocate. Fact rows always join through the SCD2 row that was current at the time of `order_purchase_timestamp`.

### `DIM_SELLER` — SCD1

Sellers shouldn't move enough to justify SCD2 overhead at this scale. If they do, overwrite. The seller story this project tells (which sellers are at risk, which have margin pressure) is dominated by *behavior over time*, not by *seller attribute changes over time*. SCD1 keeps the joins simple.

### `DIM_PRODUCT` — SCD1 + denormalized category

Source has Portuguese category names; the translation table is denormalized into the dim during the build. Adding `category_english` as a column avoids a join through `product_category_name_translation` on every query.

A `category_group` column rolls 73 leaf categories into ~12 readable groups (`bed_bath_table`, `health_beauty`, `home_garden`, etc.) for higher-level analyses without needing a category hierarchy dim.

### `DIM_GEOGRAPHY` — shared, with region rollup

One row per Brazilian zip prefix. Used by both customer and seller dimensions. Includes `region` (`Sudeste`, `Nordeste`, etc.) so dashboards roll up to Brazil's 5 official regions without join chains.

Why a separate dim instead of denormalizing into customer/seller? Because the same zip can appear under multiple customers *and* multiple sellers, and conforming the geography across both lets you ask "which sellers operate in the same region as their customer base?" without source-vs-source mismatches.

### `DIM_PAYMENT` — composite

One row per (`payment_type`, `installments`) combination. Small (typically ~30 rows total). Joining via this conformed dim makes "what % of fashion-category orders use 5+ installments?" a single GROUP BY.

## Things deliberately *not* modeled

- **Slowly changing seller**. As above, SCD1 is the call.
- **Review fact table**. Reviews are at most 1:1 with orders, so they're attributes on `fact_orders`, not a separate fact. If we wanted to analyze review text (sentiment, topic clustering), then a separate `fact_review` at the review-comment grain would be justified.
- **Payment installment detail**. A single order can have multiple payment methods, but the line-item story doesn't need to track which method paid for which line. Order-level `payment_methods_count` + `payment_total_value` is what gets pulled in.

## When this design would need to change

- **Adding inventory**: would justify a `fact_inventory_snapshot` (periodic snapshot grain) and an `accumulating_snapshot` for the order lifecycle (purchase → approve → ship → deliver → review). The current single-fact model burns the order-lifecycle into columns, which is fine for ~100k orders and questionable at 100M.
- **Adding customer behavior**: A `fact_customer_session` at the page-view grain would push customer activity into Big Query / Snowflake territory and warrant its own conformed customer dim. Different scale, different design.
