# 데이터 사전 (Data Dictionary)

이 문서는 Multi-category Store 분석 프로젝트의 테이블 및 컬럼 정의를 설명합니다.

---

## 원본 데이터 (Raw Data)

### 소스: Kaggle "E-commerce behavior data from multi category store"

| 컬럼명 | 타입 | 설명 | 예시 |
|--------|------|------|------|
| event_time | string | 이벤트 발생 시각 (UTC) | `2019-10-01 00:00:00 UTC` |
| event_type | string | 이벤트 유형 | `view`, `cart`, `purchase` |
| product_id | integer | 상품 고유 ID | `1307067` |
| category_id | integer | 카테고리 고유 ID | `2053013558920217191` |
| category_code | string | 계층형 카테고리 코드 | `electronics.smartphone` |
| brand | string | 브랜드명 | `samsung`, `apple` |
| price | float | 상품 가격 (USD) | `79.99` |
| user_id | integer | 사용자 고유 ID | `512754291` |
| user_session | string | 세션 고유 ID | `6c36dc4c-3c22-4c6f-8c6e-7c9c3d5c2b1a` |

---

## Staging 테이블

### staging.stg_events

PostgreSQL에 적재된 정제 이벤트 데이터.

| 컬럼명 | 타입 | Nullable | 설명 |
|--------|------|----------|------|
| event_timestamp | timestamp | NO | 이벤트 발생 시각 |
| event_date | date | NO | 이벤트 발생 일자 |
| event_type | varchar(20) | NO | 이벤트 유형 (view/cart/purchase) |
| product_id | bigint | YES | 상품 ID |
| category_id | bigint | YES | 카테고리 ID |
| category_code | varchar(255) | YES | 카테고리 코드 |
| brand | varchar(100) | YES | 브랜드명 |
| price | decimal(12,2) | YES | 상품 가격 |
| user_id | bigint | NO | 사용자 ID |
| user_session | varchar(50) | NO | 세션 ID |

---

## dbt 모델

### marts.fact_events

분석용 이벤트 팩트 테이블.

| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| event_timestamp | timestamp | 이벤트 발생 시각 |
| event_date | date | 이벤트 발생 일자 |
| event_week | date | 이벤트 발생 주 (월요일 기준) |
| event_month | date | 이벤트 발생 월 |
| event_type | varchar | 이벤트 유형 |
| product_id | bigint | 상품 ID |
| category_id | bigint | 카테고리 ID |
| category_code | varchar | 카테고리 코드 |
| category_l1 | varchar | 1차 카테고리 (예: electronics) |
| category_l2 | varchar | 2차 카테고리 (예: smartphone) |
| brand | varchar | 브랜드명 |
| price | decimal | 상품 가격 |
| user_id | bigint | 사용자 ID |
| user_session | varchar | 세션 ID |
| day_of_week | integer | 요일 (0=일, 1=월, ..., 6=토) |
| hour_of_day | integer | 시간대 (0-23) |
| price_bucket | varchar | 가격대 버킷 |
| first_event_date | date | 사용자 첫 활동일 |
| user_type | varchar | 사용자 유형 (new/returning) |
| revenue | decimal | 매출 (purchase일 경우에만) |

---

### marts.fact_sessions

세션 단위 집계 테이블.

| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| user_session | varchar | 세션 ID (PK) |
| user_id | bigint | 사용자 ID |
| session_date | date | 세션 시작 일자 |
| session_start | timestamp | 세션 시작 시각 |
| session_end | timestamp | 세션 종료 시각 |
| session_duration_minutes | float | 세션 지속 시간 (분) |
| total_events | integer | 총 이벤트 수 |
| products_viewed | integer | 조회한 고유 상품 수 |
| view_count | integer | 조회 이벤트 수 |
| cart_count | integer | 장바구니 이벤트 수 |
| purchase_count | integer | 구매 이벤트 수 |
| session_revenue | decimal | 세션 내 총 매출 |
| max_funnel_stage | integer | 도달한 최대 퍼널 단계 (1=view, 2=cart, 3=purchase) |
| has_cart | boolean | 장바구니 담기 여부 |
| has_purchase | boolean | 구매 완료 여부 |
| view_to_cart_rate | float | 세션 내 조회→장바구니 비율 |
| cart_to_purchase_rate | float | 세션 내 장바구니→구매 비율 |

---

### marts.mart_funnel_daily

일별 퍼널 지표 집계 테이블.

| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| event_date | date | 기준 일자 |
| user_type | varchar | 사용자 유형 (new/returning) |
| price_bucket | varchar | 가격대 버킷 |
| category_l1 | varchar | 1차 카테고리 |
| view_users | integer | 조회 사용자 수 |
| cart_users | integer | 장바구니 사용자 수 |
| purchase_users | integer | 구매 사용자 수 |
| revenue | decimal | 총 매출 |
| avg_revenue_per_purchaser | decimal | 구매자당 평균 매출 |
| cart_rate_pct | decimal | 조회→장바구니 전환율 (%) |
| purchase_rate_pct | decimal | 조회→구매 전환율 (%) |
| cart_to_purchase_rate_pct | decimal | 장바구니→구매 전환율 (%) |

---

### marts.mart_retention_cohort_weekly

주간 코호트 리텐션 테이블.

| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| cohort_week | date | 코호트 주 (첫 활동 주) |
| week_number | integer | 코호트 주 대비 경과 주 (0, 1, 2, ...) |
| cohort_size | integer | 코호트 사용자 수 |
| active_users | integer | 해당 주 활동 사용자 수 |
| retention_rate_pct | decimal | 리텐션율 (%) |
| week_label | varchar | 주차 라벨 (예: "Week 0 (Cohort)") |

---

### marts.mart_category_growth_weekly

카테고리별 주간 성장 테이블.

| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| event_week | date | 기준 주 |
| category_l1 | varchar | 1차 카테고리 |
| unique_users | integer | 고유 사용자 수 |
| view_users | integer | 조회 사용자 수 |
| cart_users | integer | 장바구니 사용자 수 |
| purchasers | integer | 구매 사용자 수 |
| purchase_count | integer | 구매 이벤트 수 |
| revenue | decimal | 매출 |
| unique_products | integer | 고유 상품 수 |
| revenue_share_pct | decimal | 매출 비중 (%) |
| purchase_conversion_pct | decimal | 구매 전환율 (%) |
| aov | decimal | 평균 주문 금액 |
| revenue_wow_growth_pct | decimal | 매출 WoW 성장률 (%) |
| purchasers_wow_growth_pct | decimal | 구매자 WoW 성장률 (%) |
| revenue_delta | decimal | 매출 변화량 |

---

## 인덱스

### staging.stg_events
- `idx_stg_events_date`: event_date
- `idx_stg_events_user`: user_id
- `idx_stg_events_date_user`: event_date, user_id
- `idx_stg_events_session`: user_session
- `idx_stg_events_product`: product_id
- `idx_stg_events_type`: event_type

### marts 테이블
각 테이블의 주요 필터 컬럼에 자동 인덱스 생성 (dbt config)

---

## 데이터 품질 규칙

| 테이블 | 컬럼 | 규칙 | 설명 |
|--------|------|------|------|
| stg_events | event_type | accepted_values | view, cart, purchase만 허용 |
| stg_events | event_timestamp | not_null | NULL 불가 |
| fact_events | user_type | accepted_values | new, returning만 허용 |
| fact_sessions | user_session | unique | 중복 불가 |
