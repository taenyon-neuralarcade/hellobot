# 이슈 목록

## 이슈 분류
- **bug**: 구현이 설계와 다름
- **edge-case**: 설계에서 고려하지 못한 예외 상황
- **enhancement**: 기존 요구사항 범위 밖의 개선

---

### ISS-001: Android 2.29.5 이후 Google Play 자동 환불 대량 발생 추정

| 분류 | bug |
| 발견일 | 2026-04-21 |
| 심각도 | P1 |
| 영향 파트 | Android (hellobot_android), 서버(hellobot-server) 연관 |
| 상태 | **해결 (2026-04-22)** — 비즈니스 문제 아님, 지표 정상화 현상 확정 |

**현상**
Google Play Console "월간 구매자 비율" 지표가 2025-03-22 ~ 03-24 사이 13.11% → 6.63%로 급락 후 현재(2026-04)까지 6~8%대 고착. 시점이 hellobot_android 2.29.5(2025-03-18 배포) 유저 업데이트 확산 시기와 정확히 일치.

**추정 원인**
PR [#1044](https://github.com/thingsflow/hellobot_android/pull/1044)의 결제 모듈 리팩토링에 포함된 회귀:

1. [BillingService.kt `notConsumedPurchase()`](../../hellobot_android/app/src/main/java/com/thingsflow/hellobot/billing/util/BillingService.kt) — INAPP 분기에 `isAcknowledged` 필터 없음. SUBS는 `!isAcknowledged` 필터 있음 (비대칭)
2. 앱 시작 시 자동으로 `queryPurchasesAsync(INAPP)` 결과를 모두 `onPurchased` 콜백에 전달 → ViewModel이 서버 consume API 자동 호출
3. 서버 `DU002(ALREADY_DEPOSIT)` 응답 시 `unprocessedPurchases` 큐에 추가 → `doFinally { alreadyConfirmPurchase() }` 에서 `consumeAsync` 강행
4. 결과적으로 **서버 지급은 완료됐는데 Google 측 consume 타이밍 문제로 자동 환불 유발** 가능

**레이스·구조적 문제**
- `BillingManager.listener` 단일 레퍼런스 → 여러 ViewModel(PurchaseViewModel, CurrentChatbotProductsViewModel, ChatroomChatbotProductsViewModel, BaseChatbotProductViewModel)이 서로 덮어씀
- `consumeProduct` 에러 핸들러가 HTTP 400도 자동 재시도 (반대 타입 API로)
- `PurchaseViewModel.consumePurchases`가 모든 orderId를 HeartStore API로 1차 시도 (하드코딩)

**현재 상태 (2026-04-21 업데이트)**

⚠️ **재무 리포트 분석 결과 원 가설이 기각됨.** PR #1044는 **자동 환불 문제를 수정한 릴리즈**였음 (참고: [planning/iap-analysis/summary.md](./planning/iap-analysis/summary.md))

- 2.29.5 **이전**: 환불율 3~19%대 (2/10 앱 이전 당일 19.16% 최고점)
- 2.29.5 **이후**: 환불율 0.85% → 0.31%로 급감
- 실제 Charge 건수는 2.29.5 전후 거의 일정
- 순매출 감소 없음

**조사 완료 (2026-04-22 확정)**:

Play Console 실제 그래프(MAU, 구매건수, 구매자당 구매건수 등 5종) 분석으로 원인 확정.

**원인 확정: 앱 이전(2/10) 후 Play Console 지표 자연 정상화**

| 검증 항목 | 결과 |
|----------|------|
| MAU 추이 3/22 전후 | 급변 없음 — 완만한 하락 추세 (55k→35k, -36%) |
| 일별/월별 구매건수 3/22 전후 | 급변 없음 — 완만한 하락 추세 |
| 구매자당 구매건수 | 매우 안정적 (1.92~2.16), 계절성만 존재 → 구매 행동 불변 |
| MAU 급증 가설 | **기각** — MAU는 급증이 아닌 하락 중 |
| Google 참여도 측정항목 개선 | **기각** — 공식 적용일 4/22, 3/22와 무관 |

**실제 구매 행동은 2025-03-22에 변하지 않았다.** 구매자 비율 반토막은 앱 이전 초기 고관여 사용자 선택 편향이 해소되면서 실제 서비스 수준(6.6%)으로 정상화된 현상이다.

**남은 코드 품질 이슈 (별도 관리 가능)**:
- BillingService.notConsumedPurchase INAPP isAcknowledged 필터 누락 → 기술적 품질 이슈, 현재 매출 영향 없음
- BillingManager.listener 단일 레퍼런스 구조 → 레이스 조건 가능성 있으나 직접적 환불 원인 아님

**참고 자료**
- [references/timeline-and-metrics.md](./references/timeline-and-metrics.md)
- [references/android-billing-code-analysis.md](./references/android-billing-code-analysis.md)
- [references/data-sources.md](./references/data-sources.md)

**관련 과업**: Phase 1 전체

---

### ISS-002: 2025-01-08 신규 사용자/구매자 획득 완전 소멸

| 분류 | edge-case |
| 발견일 | 2026-04-22 |
| 심각도 | P1 |
| 영향 파트 | 마케팅/UA (Growth), 기획 |
| 상태 | 미해결 |

**현상**

Play Console "사용자 획득 - 신규 사용자" 지표가 2025-01-08부로 급감하여 미회복 상태:

| 지표 | 1/8 이전 | 1/8 이후 |
|------|---------|---------|
| 일일 신규 사용자 | 400~800명/일 (12월 최고 1,200) | **100~200명/일** (-75%) |
| 일일 신규 구매자 | 50~100명/일 | **≈ 0명 (완전 소멸)** |
| 일일 전체 구매자 | 300~450명/일 | 250~400명/일 (정상) |
| 일별 수익 | 7M~14M KRW | 7M~14M KRW (정상) |

신규 유저와 신규 구매자만 급감; 기존 유저의 DAU/구매/수익은 정상 유지.

**추정 원인**

전형적인 UA(User Acquisition) 캠페인 종료 패턴:
- 2024년 12월 대규모 연말 캠페인 집행 (신규 유저 1,200명/일까지 상승)
- 2025년 1월 1~7일: 신년 캠페인 연장
- **2025-01-08**: 캠페인 예산 소진 또는 일정 종료 → 유기적(Organic) 유입만 남음
- 이후: 신규 유저 100~200명/일, 신규 구매자 사실상 0명으로 고착

**3/22 구매자 비율 급락과의 관계**

독립적 사건이나 구조적으로 연결:
- 1/8 이후 신규 유입 없음 → 앱 이전(2/10) 시 신계정은 기존 충성 고객만 포함
- 3/22 구매자 비율 정상화(6.63%) 이후 신규 구매자 공급이 없어 개선 불가
- **6.63%는 현재 구조에서의 실질 천장** — UA 재개 없이는 상향 불가

**남은 확인 사항**

- 1/8 시점 UA 캠페인 집행 이력 확인 (마케팅팀)
- 유기적 신규 유입 100~200명/일이 자연 수준인지 확인
- UA 재개 시 신규 구매자 전환율 예측

**참고 자료**
- [planning/iap-new-paid/](./planning/iap-new-paid/) — 신규 사용자/구매자 시계열 그래프 (8종)

**관련 과업**: 신규 — UA 전략 검토 (마케팅/기획 파트)
