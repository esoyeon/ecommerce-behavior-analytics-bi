-- mart_rfm.sql
-- RFM (Recency, Frequency, Monetary) Segmentation
-- NOTE: Frequency and Monetary are based on 'purchase' events only.
--       Recency is based on the last event (any type) to capture engagement.

{{ config(
    materialized='table',
    indexes=[
        {'columns': ['user_id'], 'unique': True},
        {'columns': ['rfm_segment']}
    ]
) }}

WITH user_metrics AS (
    SELECT
        user_id,
        MAX(event_date) AS last_seen_date,
        -- Frequency: count of distinct purchase sessions or orders
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_session END) AS frequency,
        -- Monetary: sum of purchase prices
        COALESCE(SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END), 0) AS monetary
    FROM {{ ref('fact_events') }}
    GROUP BY user_id
),

rfm_scores AS (
    SELECT
        user_id,
        monetary,
        frequency,
        last_seen_date,
        -- Calculate Recency (days since last activity relative to max date in dataset)
        (SELECT MAX(event_date) FROM {{ ref('fact_events') }}) - last_seen_date AS recency_days,
        
        -- Score Calculation (Quintiles: 5 is best, 1 is worst)
        NTILE(5) OVER (ORDER BY (SELECT MAX(event_date) FROM {{ ref('fact_events') }}) - last_seen_date DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM user_metrics
)

SELECT
    user_id,
    monetary,
    frequency,
    last_seen_date,
    recency_days,
    r_score,
    f_score,
    m_score,
    -- Concatenated RFM Score (e.g. '555')
    r_score::VARCHAR || f_score::VARCHAR || m_score::VARCHAR AS rfm_score,
    
    -- Segmentation Logic
    CASE
        WHEN (r_score >= 5 AND f_score >= 5 AND m_score >= 5) THEN 'Champions'
        WHEN (r_score >= 4 AND f_score >= 4 AND m_score >= 4) THEN 'Loyal Customers'
        WHEN (r_score >= 3 AND f_score >= 3 AND m_score >= 3) THEN 'Potentials'
        WHEN (r_score <= 2 AND last_seen_date >= (SELECT MAX(event_date) - 7 FROM {{ ref('fact_events') }})) THEN 'New Customers'
        WHEN (r_score <= 2 AND f_score >= 4) THEN 'At Risk'
        WHEN (r_score <= 2 AND f_score <= 2) THEN 'Lost'
        ELSE 'Others'
    END AS rfm_segment
FROM rfm_scores
