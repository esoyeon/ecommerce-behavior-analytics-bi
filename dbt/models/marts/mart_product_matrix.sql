-- mart_product_matrix.sql
-- Product Strategy Matrix: Popularity (Views) vs Profitability (Conversion/Revenue)

{{ config(
    materialized='table',
    indexes=[
        {'columns': ['category_l1']},
        {'columns': ['brand']}
    ]
) }}

WITH product_metrics AS (
    SELECT
        product_id,
        category_l1,
        brand,
        COUNT(CASE WHEN event_type = 'view' THEN 1 END) AS view_count,
        COUNT(CASE WHEN event_type = 'cart' THEN 1 END) AS cart_count,
        COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS purchase_count,
        SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END) AS revenue
    FROM {{ ref('fact_events') }}
    WHERE product_id IS NOT NULL
    GROUP BY product_id, category_l1, brand
)

SELECT
    product_id,
    category_l1,
    COALESCE(brand, 'Unknown') AS brand,
    view_count,
    cart_count,
    purchase_count,
    revenue,
    
    -- Metrics
    ROUND(purchase_count::NUMERIC / NULLIF(view_count, 0) * 100, 2) AS conversion_rate,
    ROUND(revenue / NULLIF(purchase_count, 0), 2) AS avg_price,
    
    -- Quadrant Classification (based on medians - simplified logic)
    CASE 
        WHEN view_count > (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY view_count) FROM product_metrics)
             AND revenue > (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) FROM product_metrics)
        THEN 'Star (High View, High Rev)'
        
        WHEN view_count > (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY view_count) FROM product_metrics)
             AND revenue <= (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) FROM product_metrics)
        THEN 'Problem Child (High View, Low Rev)'
        
        WHEN view_count <= (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY view_count) FROM product_metrics)
             AND revenue > (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) FROM product_metrics)
        THEN 'Cash Cow (Low View, High Rev)'
        
        ELSE 'Dog (Low View, Low Rev)'
    END AS matrix_quadrant
FROM product_metrics
WHERE view_count > 10  -- Filter out noise
ORDER BY revenue DESC
