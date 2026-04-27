# 조사용 데이터 소스

Phase 1 원인 확정에 활용할 모든 데이터 소스와 접근 방법을 정리한 인덱스.

## 1. Google Play Console 월간 재무 리포트 (로컬)

앱 이전 전/후 두 계정의 IAP 거래 상세. `com.thingsflow.hellobot` 필터링 필수.

**위치**: `/Users/taenyon/Box Sync/[사용중] DLT Partners/월별 재무리포트/`

| 월 | 신 계정 (접미사 없음) | 구 계정 (띵스플로우) |
|---|---|---|
| 2025-02 | `2025.02 - 20250320 작성/Google_IAP_202502_확정.csv` (14,409행) | `2025.02 - 20250320 작성/Google_IAP_202502_확정_띵스플로우.csv` (15,259행) |
| 2025-03 | `2025.03 - 20250407 작성/Google_IAP_202503_확정.csv` (28,217행) | `2025.03 - 20250407 작성/Google_IAP_202503_확정_띵스플로우.csv` (2,581행) |
| 2025-04 | `2025.04 - 20250507 작성 (20250519 추가)/Google_IAP_202504_확정 PlayApps_202504.csv` (26,268행) | `2025.04 - 20250507 작성 (20250519 추가)/Google_IAP_202504_확정_띵스플로우 PlayApps_202504.csv` (217행) |

**컬럼**: Description(GPA 주문ID), Transaction Date/Time, Transaction Type, Refund Type, Product Title, Product id, Sku Id, Amount (Buyer Currency), Amount (Merchant Currency), Buyer Country, Group ID 등

**주의**
- 구 계정 파일엔 Between 등 타사 앱 거래가 섞여 있음 → `Product id = com.thingsflow.hellobot` 필터 필수
- 파일 크기 분포로 봤을 때 3월부터는 신 계정이 주력, 구 계정엔 잔여 환불/정산만 남음

**추가 가능 월**
- 2025-05 ~ 2026-02 월별 리포트 모두 같은 상위 디렉토리에 존재. 필요 시 동일 패턴으로 확장.

## 2. 서버 DB (hellobot-server, PostgreSQL)

### 2-1. `thingsflow.coin` 테이블
- 하트/재화 지급 내역. `receipt_id`가 있는 행이 결제 기반 지급
- 일자별 Android 신규 결제 집계용

```sql
SELECT
  DATE(create_at) AS day,
  COUNT(*) AS deposits,
  COUNT(DISTINCT user_seq) AS distinct_buyers
FROM thingsflow.coin
WHERE receipt_id IS NOT NULL
  AND create_at BETWEEN '2025-03-15' AND '2025-04-15'
GROUP BY 1 ORDER BY 1;
```

### 2-2. DU002 응답 로직
- `src/common/code.ts:306` — `ALREADY_DEPOSIT = "DU002"`
- `src/deprecated-controllers/coin.ts:186,194` — 응답
- `src/models/coin.ts:102,137` — `depositCoin` / `depositCoinByPurchase`에서 `receipt_id` 중복 시 HttpError 반환
- `src/deprecated-controllers/coin.ts:41~` — `[deposit process] user(N)` winston 로그 시리즈

### 2-3. 엔드포인트
- `POST /deposit` (Android가 호출) — `src/deprecated-controllers/coin.ts:32`

## 3. 애플리케이션 로그 — **본 프로젝트 범위 제외**

- winston 로그가 stdout → Kubernetes → 로그 수집 파이프라인으로 이동
- 조회 인프라 접근 권한이 어려워 본 프로젝트에서는 **제외**
- 대체 수단: DB(2번)와 Amplitude(4번)로 실제 결제 성공 건수 vs Play 환불 건수 교차 검증

## 4. Amplitude / Braze 이벤트

- `src/services/payment.ts:2573` — `analytics.sendPurchaseHeartProductEvent`
- Amplitude에서 `purchase_heart_product` 등 결제 성공 이벤트 건수 일별 추이 가능

## 5. Android 코드 (hellobot_android)

- 원본: `hellobot_android/` (master 고정)
- 핵심 파일:
  - `app/src/main/java/com/thingsflow/hellobot/billing/util/BillingService.kt`
  - `app/src/main/java/com/thingsflow/hellobot/billing/util/BillingManager.kt`
  - `app/src/main/java/com/thingsflow/hellobot/heart_store/viewmodel/PurchaseViewModel.kt`
  - `app/src/main/java/com/thingsflow/hellobot/chatbot_product/BaseChatbotProductViewModel.kt`

## 6. Play Console

- 월간 구매자 비율 시계열 (권한 필요)
- 재무 → 주문 → Refunded 필터 (별도로 월간 리포트 외의 상세 조회)
- 구독 해지 사유

## 7. CS 문의 시스템

- 키워드 검색: "결제 취소", "환불", "하트 안 왔어요", "결제됐는데"
- 2025-03~04 기간 문의 건수 추이 확인 가능
