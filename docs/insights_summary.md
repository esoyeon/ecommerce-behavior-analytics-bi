# 인사이트 요약 (Insights Summary)

이 문서는 Multi-category Store 분석 프로젝트에서 도출된 주요 인사이트와 권장 액션을 요약합니다.

> [!NOTE]
> 아래 인사이트는 데이터 분석 후 실제 값으로 업데이트해야 합니다. 현재는 예상 인사이트 템플릿입니다.

---

## 핵심 인사이트 5가지

### 1. 퍼널 병목: 특정 카테고리/가격대에서 View→Cart 급락

**발견 사항**
- `electronics` 카테고리는 높은 조회수(View) 대비 장바구니 전환율(Cart Rate)이 평균보다 낮음
- 특히 `100-500` 가격대에서 Cart Rate가 급격히 하락
- 예상 원인: 고가 상품 결제 부담, 비교 쇼핑 행동

**확인 지표**
```sql
SELECT category_l1, price_bucket, cart_rate_pct
FROM marts.mart_funnel_daily
WHERE category_l1 = 'electronics'
ORDER BY cart_rate_pct ASC;
```

**권장 액션**
1. 고가 상품 할부/분할결제 옵션 강조
2. 비교 정보 제공 (리뷰, 스펙 비교표)
3. 장바구니 담기 시 할인 쿠폰 제공

---

### 2. 신규 유저 Activation 낮음

**발견 사항**
- 신규 사용자(`user_type = 'new'`)의 첫 세션 Cart Rate가 재방문 사용자 대비 현저히 낮음
- 첫 세션에서 장바구니까지 도달하는 비율이 전체 평균의 절반 수준
- 예상 원인: 신뢰 부족, 결제 수단 등록 장벽

**확인 지표**
```sql
SELECT user_type, AVG(cart_rate_pct), AVG(purchase_rate_pct)
FROM marts.mart_funnel_daily
GROUP BY user_type;
```

**권장 액션**
1. 첫 구매 할인 프로모션 강화
2. 신규 가입 시 쿠폰/포인트 즉시 지급
3. 간편 결제 수단 (Apple Pay, Google Pay) 도입

---

### 3. 리텐션 코호트: 특정 cohort 주에 유지율 급락

**발견 사항**
- 10월 마지막 주 코호트의 Week 1 리텐션이 이전 주 대비 급락
- 동일 코호트의 평균 세션 매출도 하락
- 예상 원인: 마케팅 캠페인 종료 후 저품질 트래픽 유입

**확인 지표**
```sql
SELECT cohort_week, week_number, retention_rate_pct
FROM marts.mart_retention_cohort_weekly
ORDER BY cohort_week, week_number;
```

**권장 액션**
1. 코호트별 유입 채널 분석 (데이터 확보 시)
2. 마케팅 캠페인 품질 지표(LTV) 기반 최적화
3. Week 1 리텐션 타겟 리마케팅 자동화

---

### 4. 성장 카테고리: 매출 성장 기여도 상위

**발견 사항**
- `electronics.smartphone` 카테고리가 전체 매출 성장의 40% 이상 기여
- `apparel` 카테고리는 구매자 수 증가에도 불구하고 AOV 하락으로 매출 성장 정체
- `appliances` 카테고리는 WoW 성장률 20%+ 로 급성장 중

**확인 지표**
```sql
SELECT category_l1, revenue_delta, revenue_wow_growth_pct
FROM marts.mart_category_growth_weekly
WHERE event_week = (SELECT MAX(event_week) FROM marts.mart_category_growth_weekly)
ORDER BY revenue_delta DESC;
```

**권장 액션**
1. 성장 카테고리(electronics, appliances)에 마케팅 예산 집중
2. apparel AOV 개선을 위한 번들/업셀 전략
3. 급성장 카테고리 재고 확보 및 공급망 점검

---

### 5. AOV 변동 원인: 고가 카테고리 믹스 변화

**발견 사항**
- 전체 AOV가 주간 변동폭이 큼 (+/- 15%)
- 주요 원인: `electronics` 카테고리 구매 비중 변화
- 프로모션 기간 중 저가 상품 구매 증가로 AOV 일시 하락

**확인 지표**
```sql
SELECT event_week, 
       SUM(revenue) / SUM(purchase_count) AS overall_aov,
       SUM(CASE WHEN category_l1 = 'electronics' THEN revenue END) / 
       SUM(CASE WHEN category_l1 = 'electronics' THEN purchase_count END) AS electronics_aov
FROM marts.mart_category_growth_weekly
GROUP BY event_week
ORDER BY event_week;
```

**권장 액션**
1. AOV 목표 달성을 위한 업셀/크로스셀 위젯 도입
2. 카테고리별 AOV 모니터링 대시보드 구축
3. 프로모션 효과 분석 시 AOV 변화 함께 추적

---

## 권장 액션 우선순위

| 순위 | 액션 | 예상 임팩트 | 난이도 | 담당 |
|------|------|------------|--------|------|
| 1 | 신규 유저 첫 구매 프로모션 강화 | 매출 +5% | 낮음 | 마케팅 |
| 2 | 고가 상품 분할결제 옵션 강조 | Cart Rate +2%p | 중간 | 프로덕트 |
| 3 | 업셀/크로스셀 위젯 도입 | AOV +10% | 높음 | 개발 |

---

## 추가 분석 권장 사항

1. **유입 채널 데이터 확보**: Acquisition 분석으로 채널별 ROI 최적화
2. **A/B 테스트**: 프로모션/UI 변경 효과 정량화
3. **RFM 세그먼트**: 고가치 사용자 식별 및 타겟 마케팅
4. **이탈 예측 모델**: 이탈 위험 사용자 사전 식별

---

## 대시보드 스크린샷

> 대시보드 구축 후 아래에 스크린샷을 추가합니다.

- [ ] Executive Overview
- [ ] Funnel & Drop-off
- [ ] Retention Cohort
- [ ] Category Growth
- [ ] Monitoring
