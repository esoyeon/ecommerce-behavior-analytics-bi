-- stg_events.sql
-- Staging model: Clean and standardize raw events from PostgreSQL

{{ config(materialized='view') }}

SELECT
    event_timestamp,
    event_date,
    event_type,
    product_id,
    category_id,
    category_code,
    -- Extract category hierarchy
    SPLIT_PART(category_code, '.', 1) AS category_l1,
    SPLIT_PART(category_code, '.', 2) AS category_l2,
    SPLIT_PART(category_code, '.', 3) AS category_l3,
    brand,
    price,
    user_id,
    user_session,
    -- Derived fields
    EXTRACT(DOW FROM event_date) AS day_of_week,
    EXTRACT(HOUR FROM event_timestamp) AS hour_of_day,
    DATE_TRUNC('week', event_date)::DATE AS event_week,
    DATE_TRUNC('month', event_date)::DATE AS event_month
FROM {{ source('staging', 'stg_events') }}
WHERE event_type IN ('view', 'cart', 'purchase')
