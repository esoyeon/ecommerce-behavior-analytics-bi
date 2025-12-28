-- mart_price_performance.sql
-- Price Sensitivity Analysis: Funnel metrics by price bucket

{{ config(
    materialized='table',
    indexes=[
        {'columns': ['price_bucket']},
        {'columns': ['category_l1']}
    ]
) }}

WITH daily_metrics AS (
    SELECT
        price_bucket,
        category_l1,
        COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END) AS view_users,
        COUNT(DISTINCT CASE WHEN event_type = 'cart' THEN user_id END) AS cart_users,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchase_users,
        SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END) AS revenue
    FROM {{ ref('fact_events') }}
    WHERE price_bucket IS NOT NULL
    GROUP BY price_bucket, category_l1
)

SELECT
    price_bucket,
    category_l1,
    SUM(view_users) AS view_users,
    SUM(cart_users) AS cart_users,
    SUM(purchase_users) AS purchase_users,
    SUM(revenue) AS revenue,
    
    -- Conversion Rates
    ROUND(SUM(cart_users)::NUMERIC / NULLIF(SUM(view_users), 0) * 100, 2) AS view_to_cart_rate,
    ROUND(SUM(purchase_users)::NUMERIC / NULLIF(SUM(cart_users), 0) * 100, 2) AS cart_to_purchase_rate,
    ROUND(SUM(purchase_users)::NUMERIC / NULLIF(SUM(view_users), 0) * 100, 2) AS overall_conversion_rate,
    
    -- Average Revenue per Viewer
    ROUND(SUM(revenue) / NULLIF(SUM(view_users), 0), 2) AS revenue_per_viewer
FROM daily_metrics
GROUP BY price_bucket, category_l1
ORDER BY price_bucket, revenue DESC
