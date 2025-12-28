# KPI 정의서 (KPI Definition Guide)

이 문서는 Multi-category Store 분석 프로젝트에서 사용되는 핵심 지표(KPI)의 정의와 계산 방법을 설명합니다.

---

## 1. 사용자 활동 지표

### DAU (Daily Active Users)
- **정의**: 하루에 최소 1개 이상의 이벤트(view/cart/purchase)를 발생시킨 고유 사용자 수
- **계산식**: `COUNT(DISTINCT user_id) WHERE event_date = 특정일`
- **용도**: 일일 서비스 이용 규모 파악
- **주의점**: 세션 단위가 아닌 사용자 단위로 집계

### WAU (Weekly Active Users)
- **정의**: 주간 최소 1개 이상의 이벤트를 발생시킨 고유 사용자 수
- **계산식**: `COUNT(DISTINCT user_id) WHERE event_week = 특정주`
- **용도**: 주간 사용자 기반 추이 분석

### 신규 사용자 (New Users)
- **정의**: 해당 일자가 첫 이벤트 발생일인 사용자
- **계산식**: `user_type = 'new'`
- **용도**: 신규 유입 규모 모니터링

### 재방문 사용자 (Returning Users)
- **정의**: 이전에 이벤트를 발생시킨 적 있는 사용자
- **계산식**: `user_type = 'returning'`

---

## 2. 퍼널 지표

### View Users
- **정의**: 상품 상세 페이지를 조회한 고유 사용자 수
- **계산식**: `COUNT(DISTINCT user_id) WHERE event_type = 'view'`

### Cart Users
- **정의**: 장바구니에 상품을 담은 고유 사용자 수
- **계산식**: `COUNT(DISTINCT user_id) WHERE event_type = 'cart'`

### Purchase Users (Purchasers)
- **정의**: 구매를 완료한 고유 사용자 수
- **계산식**: `COUNT(DISTINCT user_id) WHERE event_type = 'purchase'`

### Cart Rate (장바구니 전환율)
- **정의**: 조회 사용자 중 장바구니에 담은 사용자 비율
- **계산식**: `cart_users / view_users * 100`
- **단위**: 퍼센트 (%)
- **벤치마크**: 일반적으로 5-15%가 양호

### Purchase Rate (구매 전환율)
- **정의**: 조회 사용자 중 구매까지 완료한 사용자 비율
- **계산식**: `purchase_users / view_users * 100`
- **단위**: 퍼센트 (%)
- **벤치마크**: E-commerce 평균 1-3%

### Cart-to-Purchase Rate (장바구니→구매 전환율)
- **정의**: 장바구니 담은 사용자 중 구매 완료한 사용자 비율
- **계산식**: `purchase_users / cart_users * 100`
- **용도**: 결제 과정 이탈 분석

---

## 3. 매출 지표

### Revenue (매출)
- **정의**: 구매 이벤트의 가격 합계
- **계산식**: `SUM(price) WHERE event_type = 'purchase'`
- **주의점**: 
  - `order_id`가 없어 개별 구매 이벤트를 독립 주문으로 간주
  - 환불/취소 데이터 없음 (Gross Revenue)

### AOV (Average Order Value, 평균 주문 금액)
- **정의**: 구매 이벤트당 평균 금액
- **계산식**: `Revenue / COUNT(purchase events)`
- **주의점**: 실제 주문 단위가 아닌 이벤트 단위 근사치
- **대안 정의**: 구매 사용자당 평균 지출 = `Revenue / purchase_users`

### ARPU (Average Revenue Per User)
- **정의**: 활성 사용자당 평균 매출
- **계산식**: `Revenue / DAU` 또는 `Revenue / WAU`

---

## 4. 리텐션 지표

### Cohort Week (코호트 주)
- **정의**: 사용자의 첫 활동이 발생한 주
- **계산식**: `DATE_TRUNC('week', MIN(event_date))`

### Week N
- **정의**: 코호트 주 대비 N주 후
- **계산식**: `(activity_week - cohort_week) / 7`
- **예시**: Week 0 = 코호트 주, Week 1 = 1주 후, ...

### Retention Rate (리텐션율)
- **정의**: 코호트 사용자 중 Week N에 활동한 사용자 비율
- **계산식**: `active_users_week_n / cohort_size * 100`
- **단위**: 퍼센트 (%)
- **해석**: 
  - Week 0 = 항상 100%
  - Week 1 = 첫 주 후 재방문율 (중요 지표)

---

## 5. 카테고리 성장 지표

### Revenue Share (매출 비중)
- **정의**: 전체 매출 대비 카테고리 매출 비율
- **계산식**: `category_revenue / total_revenue * 100`

### WoW Growth (주간 성장률)
- **정의**: 전주 대비 이번 주 변화율
- **계산식**: `(this_week - last_week) / last_week * 100`
- **적용 대상**: Revenue, Purchasers

### Revenue Delta (매출 변화량)
- **정의**: 전주 대비 매출 변화 절대값
- **계산식**: `this_week_revenue - last_week_revenue`
- **용도**: 전체 성장에 대한 카테고리 기여도 분석

---

## 6. 세그먼트 정의

### 가격대 버킷 (Price Bucket)
| 버킷 | 가격 범위 |
|------|-----------|
| 0-10 | $0 ~ $10 미만 |
| 10-50 | $10 ~ $50 미만 |
| 50-100 | $50 ~ $100 미만 |
| 100-500 | $100 ~ $500 미만 |
| 500+ | $500 이상 |
| unknown | 가격 정보 없음 |

### 사용자 유형 (User Type)
| 유형 | 정의 |
|------|------|
| new | 해당 일자가 첫 이벤트 발생일 |
| returning | 이전에 이벤트 발생 이력 있음 |

---

## 7. 데이터 제약 및 가정

> [!WARNING]
> 이 데이터셋에는 다음과 같은 제약이 있습니다:

1. **Order ID 없음**: 개별 구매 이벤트를 독립 주문으로 근사
2. **유입 채널 없음**: Acquisition 분석 제외
3. **환불/취소 없음**: Gross Revenue만 계산 가능
4. **디바이스 정보 없음**: 플랫폼별 분석 불가
5. **UTC 시간**: 현지 시간 변환 필요 시 주의
