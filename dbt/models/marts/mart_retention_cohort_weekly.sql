-- mart_retention_cohort_weekly.sql
-- Weekly cohort retention analysis

{{ config(
    materialized='table',
    indexes=[
        {'columns': ['cohort_week']},
        {'columns': ['week_number']}
    ]
) }}

WITH user_cohorts AS (
    -- Assign each user to their first activity week (cohort)
    SELECT 
        user_id,
        DATE_TRUNC('week', MIN(event_date))::DATE AS cohort_week
    FROM {{ ref('fact_events') }}
    GROUP BY user_id
),

user_activity AS (
    -- Get weekly activity for each user
    SELECT DISTINCT
        e.user_id,
        DATE_TRUNC('week', e.event_date)::DATE AS activity_week
    FROM {{ ref('fact_events') }} e
),

cohort_activity AS (
    -- Join to get cohort info with activity
    SELECT
        c.user_id,
        c.cohort_week,
        a.activity_week,
        -- Calculate week number (0 = cohort week, 1 = next week, etc.)
        (a.activity_week - c.cohort_week) / 7 AS week_number
    FROM user_cohorts c
    JOIN user_activity a ON c.user_id = a.user_id
    WHERE a.activity_week >= c.cohort_week
),

cohort_sizes AS (
    -- Count users in each cohort
    SELECT
        cohort_week,
        COUNT(DISTINCT user_id) AS cohort_size
    FROM user_cohorts
    GROUP BY cohort_week
),

weekly_retention AS (
    -- Count active users per cohort per week
    SELECT
        cohort_week,
        week_number,
        COUNT(DISTINCT user_id) AS active_users
    FROM cohort_activity
    GROUP BY cohort_week, week_number
)

SELECT
    r.cohort_week,
    r.week_number,
    s.cohort_size,
    r.active_users,
    ROUND(r.active_users::NUMERIC / s.cohort_size * 100, 2) AS retention_rate_pct,
    -- Week label for display
    CASE 
        WHEN r.week_number = 0 THEN 'Week 0 (Cohort)'
        ELSE 'Week ' || r.week_number
    END AS week_label
FROM weekly_retention r
JOIN cohort_sizes s ON r.cohort_week = s.cohort_week
ORDER BY r.cohort_week, r.week_number
