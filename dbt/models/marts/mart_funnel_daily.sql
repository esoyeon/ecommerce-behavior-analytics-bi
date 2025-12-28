-- mart_funnel_daily.sql
-- Daily funnel metrics with segmentation

{{ config(
    materialized='table',
    indexes=[
        {'columns': ['event_date']},
        {'columns': ['user_type', 'event_date']}
    ]
) }}

WITH daily_users AS (
    SELECT
        event_date,
        user_type,
        price_bucket,
        category_l1,
        user_id,
        -- User reached each stage
        MAX(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) AS has_view,
        MAX(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) AS has_cart,
        MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchase,
        SUM(CASE WHEN event_type = 'purchase' THEN revenue ELSE 0 END) AS user_revenue
    FROM {{ ref('fact_events') }}
    GROUP BY event_date, user_type, price_bucket, category_l1, user_id
)

SELECT
    event_date,
    user_type,
    price_bucket,
    category_l1,
    -- User counts by funnel stage
    COUNT(DISTINCT CASE WHEN has_view = 1 THEN user_id END) AS view_users,
    COUNT(DISTINCT CASE WHEN has_cart = 1 THEN user_id END) AS cart_users,
    COUNT(DISTINCT CASE WHEN has_purchase = 1 THEN user_id END) AS purchase_users,
    -- Revenue metrics
    SUM(user_revenue) AS revenue,
    AVG(CASE WHEN has_purchase = 1 THEN user_revenue END) AS avg_revenue_per_purchaser,
    -- Conversion rates
    CASE 
        WHEN COUNT(DISTINCT CASE WHEN has_view = 1 THEN user_id END) > 0 
        THEN ROUND(
            COUNT(DISTINCT CASE WHEN has_cart = 1 THEN user_id END)::NUMERIC / 
            COUNT(DISTINCT CASE WHEN has_view = 1 THEN user_id END) * 100, 2
        )
        ELSE 0 
    END AS cart_rate_pct,
    CASE 
        WHEN COUNT(DISTINCT CASE WHEN has_view = 1 THEN user_id END) > 0 
        THEN ROUND(
            COUNT(DISTINCT CASE WHEN has_purchase = 1 THEN user_id END)::NUMERIC / 
            COUNT(DISTINCT CASE WHEN has_view = 1 THEN user_id END) * 100, 2
        )
        ELSE 0 
    END AS purchase_rate_pct,
    CASE 
        WHEN COUNT(DISTINCT CASE WHEN has_cart = 1 THEN user_id END) > 0 
        THEN ROUND(
            COUNT(DISTINCT CASE WHEN has_purchase = 1 THEN user_id END)::NUMERIC / 
            COUNT(DISTINCT CASE WHEN has_cart = 1 THEN user_id END) * 100, 2
        )
        ELSE 0 
    END AS cart_to_purchase_rate_pct
FROM daily_users
GROUP BY event_date, user_type, price_bucket, category_l1
