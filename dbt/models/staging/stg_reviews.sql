{{ config(materialized='view') }}

-- Some orders have multiple review rows (a write-then-update history).
-- For the mart, we collapse to the *latest* review per order — defined
-- by review_answer_timestamp (the customer's most recent action).
-- Dedup happens here so downstream models don't have to think about it.

with src as (
    select
        order_id,
        review_id,
        review_score                                as score,
        review_comment_title                        as comment_title,
        review_comment_message                      as comment_message,
        review_creation_date                        as created_at,
        review_answer_timestamp                     as answered_at,
        row_number() over (
            partition by order_id
            order by review_answer_timestamp desc nulls last
        )                                           as rn
    from {{ source('raw', 'order_reviews') }}
)

select * exclude (rn) from src where rn = 1
