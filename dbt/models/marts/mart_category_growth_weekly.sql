-- mart_category_growth_weekly.sql
-- Category performance and growth analysis

{{ config(
    materialized='table',
    indexes=[
        {'columns': ['event_week']},
        {'columns': ['category_l1', 'event_week']}
    ]
) }}

WITH weekly_category AS (
    SELECT
        event_week,
        category_l1,
        -- Metrics
        COUNT(DISTINCT user_id) AS unique_users,
        COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END) AS view_users,
        COUNT(DISTINCT CASE WHEN event_type = 'cart' THEN user_id END) AS cart_users,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchasers,
        COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS purchase_count,
        SUM(revenue) AS revenue,
        COUNT(DISTINCT product_id) AS unique_products
    FROM {{ ref('fact_events') }}
    WHERE category_l1 IS NOT NULL AND category_l1 != ''
    GROUP BY event_week, category_l1
),

weekly_total AS (
    SELECT
        event_week,
        SUM(revenue) AS total_revenue,
        SUM(purchasers) AS total_purchasers
    FROM weekly_category
    GROUP BY event_week
),

with_prev_week AS (
    SELECT
        c.*,
        t.total_revenue,
        -- Revenue share
        CASE 
            WHEN t.total_revenue > 0 
            THEN ROUND(c.revenue / t.total_revenue * 100, 2)
            ELSE 0 
        END AS revenue_share_pct,
        -- Previous week metrics (for WoW calculation)
        LAG(c.revenue) OVER (
            PARTITION BY c.category_l1 ORDER BY c.event_week
        ) AS prev_week_revenue,
        LAG(c.purchasers) OVER (
            PARTITION BY c.category_l1 ORDER BY c.event_week
        ) AS prev_week_purchasers
    FROM weekly_category c
    JOIN weekly_total t ON c.event_week = t.event_week
)

SELECT
    event_week,
    category_l1,
    unique_users,
    view_users,
    cart_users,
    purchasers,
    purchase_count,
    revenue,
    unique_products,
    revenue_share_pct,
    -- Conversion rate
    CASE 
        WHEN view_users > 0 
        THEN ROUND(purchasers::NUMERIC / view_users * 100, 2)
        ELSE 0 
    END AS purchase_conversion_pct,
    -- AOV
    CASE 
        WHEN purchase_count > 0 
        THEN ROUND(revenue / purchase_count, 2)
        ELSE 0 
    END AS aov,
    -- Week-over-Week growth
    CASE 
        WHEN prev_week_revenue > 0 
        THEN ROUND((revenue - prev_week_revenue) / prev_week_revenue * 100, 2)
        ELSE NULL 
    END AS revenue_wow_growth_pct,
    CASE 
        WHEN prev_week_purchasers > 0 
        THEN ROUND((purchasers - prev_week_purchasers)::NUMERIC / prev_week_purchasers * 100, 2)
        ELSE NULL 
    END AS purchasers_wow_growth_pct,
    -- Growth contribution (category revenue change / total revenue change)
    revenue - COALESCE(prev_week_revenue, 0) AS revenue_delta
FROM with_prev_week
