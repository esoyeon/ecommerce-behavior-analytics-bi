# Metabase SQL 질문 템플릿

이 문서는 Metabase에서 사용할 수 있는 SQL 질문 템플릿을 제공합니다.

---

## 1. Executive Overview

### 핵심 KPI 카드

```sql
-- 전체 개요 KPI
SELECT 
    COUNT(DISTINCT user_id) AS total_users,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchasers,
    SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END) AS total_revenue,
    ROUND(SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END) / 
          NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END), 0), 2) AS arpu
FROM marts.fact_events
WHERE event_date >= CURRENT_DATE - INTERVAL '7 days';
```

### 일별 KPI 트렌드

```sql
-- DAU, 매출 일별 추이
SELECT 
    event_date,
    COUNT(DISTINCT user_id) AS dau,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchasers,
    SUM(revenue) AS revenue
FROM marts.fact_events
WHERE event_date >= {{start_date}} AND event_date <= {{end_date}}
GROUP BY event_date
ORDER BY event_date;
```

---

## 2. Funnel & Drop-off

### 전체 퍼널 (일별)

```sql
-- 일별 퍼널 전환율
SELECT 
    event_date,
    SUM(view_users) AS view_users,
    SUM(cart_users) AS cart_users,
    SUM(purchase_users) AS purchase_users,
    ROUND(SUM(cart_users)::NUMERIC / NULLIF(SUM(view_users), 0) * 100, 2) AS cart_rate_pct,
    ROUND(SUM(purchase_users)::NUMERIC / NULLIF(SUM(view_users), 0) * 100, 2) AS purchase_rate_pct
FROM marts.mart_funnel_daily
WHERE event_date >= {{start_date}} AND event_date <= {{end_date}}
GROUP BY event_date
ORDER BY event_date;
```

### 사용자 유형별 퍼널

```sql
-- 신규 vs 기존 사용자 퍼널 비교
SELECT 
    user_type,
    SUM(view_users) AS view_users,
    SUM(cart_users) AS cart_users,
    SUM(purchase_users) AS purchase_users,
    ROUND(SUM(cart_users)::NUMERIC / NULLIF(SUM(view_users), 0) * 100, 2) AS cart_rate_pct,
    ROUND(SUM(purchase_users)::NUMERIC / NULLIF(SUM(view_users), 0) * 100, 2) AS purchase_rate_pct
FROM marts.mart_funnel_daily
WHERE event_date >= {{start_date}} AND event_date <= {{end_date}}
GROUP BY user_type;
```

### 가격대별 퍼널

```sql
-- 가격대별 전환율
SELECT 
    price_bucket,
    SUM(view_users) AS view_users,
    SUM(cart_users) AS cart_users,
    SUM(purchase_users) AS purchase_users,
    ROUND(SUM(cart_users)::NUMERIC / NULLIF(SUM(view_users), 0) * 100, 2) AS cart_rate_pct,
    ROUND(SUM(purchase_users)::NUMERIC / NULLIF(SUM(view_users), 0) * 100, 2) AS purchase_rate_pct,
    SUM(revenue) AS revenue
FROM marts.mart_funnel_daily
WHERE event_date >= {{start_date}} AND event_date <= {{end_date}}
GROUP BY price_bucket
ORDER BY 
    CASE price_bucket
        WHEN '0-10' THEN 1
        WHEN '10-50' THEN 2
        WHEN '50-100' THEN 3
        WHEN '100-500' THEN 4
        WHEN '500+' THEN 5
        ELSE 6
    END;
```

### 카테고리별 퍼널 (Drop-off 분석)

```sql
-- 카테고리별 이탈 분석
SELECT 
    category_l1,
    SUM(view_users) AS view_users,
    SUM(cart_users) AS cart_users,
    SUM(purchase_users) AS purchase_users,
    -- 이탈률
    ROUND((1 - SUM(cart_users)::NUMERIC / NULLIF(SUM(view_users), 0)) * 100, 2) AS view_to_cart_dropoff_pct,
    ROUND((1 - SUM(purchase_users)::NUMERIC / NULLIF(SUM(cart_users), 0)) * 100, 2) AS cart_to_purchase_dropoff_pct
FROM marts.mart_funnel_daily
WHERE event_date >= {{start_date}} AND event_date <= {{end_date}}
  AND category_l1 IS NOT NULL
GROUP BY category_l1
ORDER BY view_users DESC
LIMIT 15;
```

---

## 3. Retention Cohort

### 코호트 리텐션 테이블

```sql
-- 주간 코호트 리텐션 (피벗용)
SELECT 
    cohort_week,
    cohort_size,
    MAX(CASE WHEN week_number = 0 THEN retention_rate_pct END) AS week_0,
    MAX(CASE WHEN week_number = 1 THEN retention_rate_pct END) AS week_1,
    MAX(CASE WHEN week_number = 2 THEN retention_rate_pct END) AS week_2,
    MAX(CASE WHEN week_number = 3 THEN retention_rate_pct END) AS week_3,
    MAX(CASE WHEN week_number = 4 THEN retention_rate_pct END) AS week_4,
    MAX(CASE WHEN week_number = 5 THEN retention_rate_pct END) AS week_5,
    MAX(CASE WHEN week_number = 6 THEN retention_rate_pct END) AS week_6,
    MAX(CASE WHEN week_number = 7 THEN retention_rate_pct END) AS week_7
FROM marts.mart_retention_cohort_weekly
GROUP BY cohort_week, cohort_size
ORDER BY cohort_week;
```

### 평균 리텐션 트렌드

```sql
-- 주차별 평균 리텐션
SELECT 
    week_number,
    week_label,
    AVG(retention_rate_pct) AS avg_retention_pct,
    MIN(retention_rate_pct) AS min_retention_pct,
    MAX(retention_rate_pct) AS max_retention_pct
FROM marts.mart_retention_cohort_weekly
GROUP BY week_number, week_label
ORDER BY week_number;
```

---

## 4. Category Growth

### 카테고리별 주간 성장

```sql
-- 카테고리별 WoW 성장률
SELECT 
    event_week,
    category_l1,
    revenue,
    revenue_share_pct,
    revenue_wow_growth_pct,
    purchasers,
    aov
FROM marts.mart_category_growth_weekly
WHERE event_week >= {{start_date}}
ORDER BY event_week DESC, revenue DESC;
```

### 성장 TOP/하락 TOP

```sql
-- 성장률 TOP 10
SELECT 
    category_l1,
    revenue,
    revenue_wow_growth_pct,
    revenue_delta
FROM marts.mart_category_growth_weekly
WHERE event_week = (SELECT MAX(event_week) FROM marts.mart_category_growth_weekly)
  AND revenue_wow_growth_pct IS NOT NULL
ORDER BY revenue_wow_growth_pct DESC
LIMIT 10;

-- 하락 TOP 10
SELECT 
    category_l1,
    revenue,
    revenue_wow_growth_pct,
    revenue_delta
FROM marts.mart_category_growth_weekly
WHERE event_week = (SELECT MAX(event_week) FROM marts.mart_category_growth_weekly)
  AND revenue_wow_growth_pct IS NOT NULL
ORDER BY revenue_wow_growth_pct ASC
LIMIT 10;
```

### 매출 기여도 분석

```sql
-- 전체 성장에 대한 카테고리 기여도
WITH weekly_totals AS (
    SELECT 
        event_week,
        SUM(revenue_delta) AS total_delta
    FROM marts.mart_category_growth_weekly
    GROUP BY event_week
)
SELECT 
    c.event_week,
    c.category_l1,
    c.revenue_delta,
    t.total_delta,
    CASE 
        WHEN t.total_delta != 0 
        THEN ROUND(c.revenue_delta / t.total_delta * 100, 2) 
        ELSE 0 
    END AS contribution_pct
FROM marts.mart_category_growth_weekly c
JOIN weekly_totals t ON c.event_week = t.event_week
WHERE c.event_week = (SELECT MAX(event_week) FROM marts.mart_category_growth_weekly)
ORDER BY ABS(c.revenue_delta) DESC
LIMIT 15;
```

---

## 5. Monitoring (이상징후 감지)

### 전주 대비 급변 감지

```sql
-- 주간 KPI 급변 모니터링
WITH weekly_kpi AS (
    SELECT 
        DATE_TRUNC('week', event_date)::DATE AS week,
        COUNT(DISTINCT user_id) AS users,
        SUM(revenue) AS revenue,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchasers
    FROM marts.fact_events
    GROUP BY DATE_TRUNC('week', event_date)::DATE
)
SELECT 
    week,
    users,
    revenue,
    purchasers,
    LAG(users) OVER (ORDER BY week) AS prev_users,
    LAG(revenue) OVER (ORDER BY week) AS prev_revenue,
    ROUND((users - LAG(users) OVER (ORDER BY week))::NUMERIC / 
          NULLIF(LAG(users) OVER (ORDER BY week), 0) * 100, 2) AS users_change_pct,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY week))::NUMERIC / 
          NULLIF(LAG(revenue) OVER (ORDER BY week), 0) * 100, 2) AS revenue_change_pct,
    CASE 
        WHEN (revenue - LAG(revenue) OVER (ORDER BY week))::NUMERIC / 
             NULLIF(LAG(revenue) OVER (ORDER BY week), 0) < -0.20 THEN '⚠️ 급락' 
        WHEN (revenue - LAG(revenue) OVER (ORDER BY week))::NUMERIC / 
             NULLIF(LAG(revenue) OVER (ORDER BY week), 0) > 0.30 THEN '📈 급등'
        ELSE '✅ 정상'
    END AS status
FROM weekly_kpi
ORDER BY week DESC
LIMIT 8;
```

### 카테고리별 이상징후

```sql
-- 카테고리별 전주 대비 급락 감지
SELECT 
    category_l1,
    revenue,
    revenue_wow_growth_pct,
    CASE 
        WHEN revenue_wow_growth_pct < -30 THEN '🔴 급락' 
        WHEN revenue_wow_growth_pct < -10 THEN '🟡 주의'
        WHEN revenue_wow_growth_pct > 50 THEN '🟢 급성장'
        ELSE '⚪ 정상'
    END AS alert_level
FROM marts.mart_category_growth_weekly
WHERE event_week = (SELECT MAX(event_week) FROM marts.mart_category_growth_weekly)
  AND revenue > 1000  -- 소규모 카테고리 제외
ORDER BY revenue_wow_growth_pct ASC;
```

---

## 필터 변수

Metabase에서 사용할 수 있는 필터 변수:
- `{{start_date}}`: 시작 날짜
- `{{end_date}}`: 종료 날짜
- `{{category}}`: 카테고리 필터
- `{{user_type}}`: 사용자 유형 (new/returning)
- `{{price_bucket}}`: 가격대 버킷
