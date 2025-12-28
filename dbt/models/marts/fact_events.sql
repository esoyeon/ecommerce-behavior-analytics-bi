-- fact_events.sql
-- Fact table: Analysis-ready events with derived metrics

{{ config(
    materialized='table',
    indexes=[
        {'columns': ['event_date', 'user_id']},
        {'columns': ['user_session']},
        {'columns': ['product_id']},
        {'columns': ['event_type']}
    ]
) }}

WITH user_first_event AS (
    -- Get first event date for each user (for new/returning segmentation)
    SELECT 
        user_id,
        MIN(event_date) AS first_event_date
    FROM {{ ref('stg_events') }}
    GROUP BY user_id
)

SELECT
    e.event_timestamp,
    e.event_date,
    e.event_week,
    e.event_month,
    e.event_type,
    e.product_id,
    e.category_id,
    e.category_code,
    e.category_l1,
    e.category_l2,
    e.brand,
    e.price,
    e.user_id,
    e.user_session,
    e.day_of_week,
    e.hour_of_day,
    -- Price bucket for segmentation
    CASE
        WHEN e.price IS NULL THEN 'unknown'
        WHEN e.price < 10 THEN '0-10'
        WHEN e.price < 50 THEN '10-50'
        WHEN e.price < 100 THEN '50-100'
        WHEN e.price < 500 THEN '100-500'
        ELSE '500+'
    END AS price_bucket,
    -- User type segmentation
    u.first_event_date,
    CASE 
        WHEN e.event_date = u.first_event_date THEN 'new'
        ELSE 'returning'
    END AS user_type,
    -- Revenue (only for purchases)
    CASE 
        WHEN e.event_type = 'purchase' THEN COALESCE(e.price, 0)
        ELSE 0
    END AS revenue
FROM {{ ref('stg_events') }} e
LEFT JOIN user_first_event u ON e.user_id = u.user_id
