-- fact_sessions.sql
-- Session-level aggregations for user behavior analysis

{{ config(
    materialized='table',
    indexes=[
        {'columns': ['session_date', 'user_id']},
        {'columns': ['user_session']}
    ]
) }}

WITH session_events AS (
    SELECT
        user_session,
        user_id,
        event_date,
        event_type,
        product_id,
        price,
        event_timestamp
    FROM {{ ref('fact_events') }}
),

session_agg AS (
    SELECT
        user_session,
        user_id,
        MIN(event_date) AS session_date,
        MIN(event_timestamp) AS session_start,
        MAX(event_timestamp) AS session_end,
        COUNT(*) AS total_events,
        COUNT(DISTINCT product_id) AS products_viewed,
        -- Event type counts
        COUNT(CASE WHEN event_type = 'view' THEN 1 END) AS view_count,
        COUNT(CASE WHEN event_type = 'cart' THEN 1 END) AS cart_count,
        COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS purchase_count,
        -- Revenue
        SUM(CASE WHEN event_type = 'purchase' THEN COALESCE(price, 0) ELSE 0 END) AS session_revenue,
        -- Max funnel stage reached
        MAX(CASE 
            WHEN event_type = 'purchase' THEN 3
            WHEN event_type = 'cart' THEN 2
            WHEN event_type = 'view' THEN 1
            ELSE 0
        END) AS max_funnel_stage
    FROM session_events
    GROUP BY user_session, user_id
)

SELECT
    user_session,
    user_id,
    session_date,
    session_start,
    session_end,
    EXTRACT(EPOCH FROM (session_end - session_start)) / 60 AS session_duration_minutes,
    total_events,
    products_viewed,
    view_count,
    cart_count,
    purchase_count,
    session_revenue,
    max_funnel_stage,
    -- Session outcome flags
    CASE WHEN cart_count > 0 THEN true ELSE false END AS has_cart,
    CASE WHEN purchase_count > 0 THEN true ELSE false END AS has_purchase,
    -- Conversion within session
    CASE 
        WHEN view_count > 0 AND cart_count > 0 
        THEN cart_count::FLOAT / view_count 
        ELSE 0 
    END AS view_to_cart_rate,
    CASE 
        WHEN cart_count > 0 AND purchase_count > 0 
        THEN purchase_count::FLOAT / cart_count 
        ELSE 0 
    END AS cart_to_purchase_rate
FROM session_agg
