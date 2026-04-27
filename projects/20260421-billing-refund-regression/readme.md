# Android 결제 자동 환불 회귀 조사 및 수정

## 배경

2025-03-18 배포된 hellobot_android 2.29.5 이후 Google Play Console의 "월간 구매자 비율" 지표가 13.11% → 6.63%로 반토막 났고, 1년 넘게 6~8%대에 고착되어 현재(2026-04)까지 이어지고 있다.

**강한 시그널**
- 앱 이전일(2025-02-10)과 급락일(2025-03-22~24) 사이 40일간은 변화 없음 → 앱 이전은 원인 아님
- 급락 시점이 2.29.5 유저 업데이트 확산 시기와 정확히 일치
- 2.29.5의 PR [#1044](https://github.com/thingsflow/hellobot_android/pull/1044)(결제 모듈 전면 리팩토링, 1,442줄/34파일)가 유력 용의자
- 현재 master(2.40.0.1)에도 동일 코드 잔존 → 버그 진행 중 가능성 매우 높음

**유력 가설 (선확정 필요)**
- [BillingService.kt](../../hellobot_android/app/src/main/java/com/thingsflow/hellobot/billing/util/BillingService.kt) `notConsumedPurchase()`의 INAPP 분기에 `isAcknowledged` 필터 누락
- `BillingManager.listener` 단일 레퍼런스가 여러 ViewModel 간 덮어씌워짐
- `consumeProduct` 에러 핸들러의 HTTP 400 자동 재시도
- `doFinally { alreadyConfirmPurchase() }`가 DU002 응답에도 Google consume 강행 → 72시간 초과 토큰은 Google 자동 환불 유발 가능

상세 근거: [references/android-billing-code-analysis.md](./references/android-billing-code-analysis.md)

## 목표

1. **원인 확정**: 위 가설을 재무 리포트·서버 DB·Android 코드 분석으로 교차 검증
2. **개선 방안 도출**: Google Play Billing Library 권장 패턴에 맞는 결제 모듈 설계
3. **적용·검증**: 수정 배포 후 Play Console 지표 회복 관찰 및 최종 매출 회복 확인

## 범위

### 포함
- hellobot_android 결제 모듈 (BillingService, BillingManager, Purchase/Subscription ViewModel 계열) 정적 분석 및 수정
- Google Play IAP 재무 리포트 분석 (2025-02 ~ 2025-04 자료 기반, 필요 시 이후 월 추가)
- 서버 `thingsflow.coin` 테이블 기반 실제 매출 추이 검증
- Amplitude `purchase_heart_product` 이벤트 교차 검증 (접근 가능 시)
- 버그 수정 후 회귀 방지 테스트 및 점진 배포

### 제외
- **서버 애플리케이션 로그(winston, DU002 카운트 등) 직접 조회** — 로그 수집 인프라 접근이 어려워 제외. 대신 DB + 재무 리포트로 대체 검증.
- 이미 발생한 자동 환불 유저에 대한 보상 정책 (별도 논의)
- iOS 결제 모듈 변경 (본 이슈는 Android 한정)
- 결제 모듈 외 리팩토링
- 이전 계정(띵스플로우) Play Console 관리자 액션 (조회용으로만 활용)

## 영향 범위

| 파트 | 영향 | 설명 |
|------|------|------|
| 서버 | O (소) | coin 테이블 조회 + 필요 시 DU002 응답 동작 조정. 스키마 변경은 선택적. |
| iOS | X | 해당없음 |
| Android | O (대) | 결제 모듈 전반 수정. 핵심 파트. |
| 웹 | X | 해당없음 |
| 스튜디오 | X | 해당없음 |
| 데이터 | O (중) | Google IAP CSV 분석. 조사 단계에서만 참여. 파이프라인/테이블 변경 없음. |

## 진행 방식

### Phase 1 — 원인 확정 (병렬)

3개 트랙 동시 진행. 결과는 `planning/root-cause-report.md`로 통합.

- **/dev-data**: Google IAP CSV 6개 분석 (환불 스파이크 존재 여부·사유·간격)
- **/dev-server**: coin 테이블 기반 Android 일일 결제 성공 건수, Amplitude 이벤트 (접근 시)
- **/dev-android**: master 코드 상세 분석, 2.29.4→2.29.5→master 변천, Google 권장 패턴 대비 gap

**의사결정 분기**
- Phase 1 결과가 "클라이언트 버그 확정"이면 → Phase 2/3 진행
- "원인이 클라이언트 외부(서버/Play 집계 등)"를 시사하면 → 범위 재정의 후 계획 수정

### Phase 2 — 개선 방안 설계

- **/architect**: 결제 모듈 개선 아키텍처 (architecture.md), 서버 API 변경 여부 (api-spec.md)
- **/qa**: 회귀 방지 테스트 케이스 초안 (qa-test-cases.md)

### Phase 3 — 구현·배포·검증

- **/dev-android**: 워크트리 생성 후 코드 수정, 단위 테스트
- **/dev-server**: 필요 시 서버 로직 보강
- **/qa**: 회귀 테스트 수행
- **/review**: PR 리뷰
- **배포**: 10% → 50% → 100% 점진 롤아웃
- **모니터링**: 2주간 Play Console 지표 + 월간 재무 리포트로 최종 확정

## 성공 기준

### Input metric (단기, 배포 후 1~4주)
- 월간 재무 리포트 자동 환불 건수·금액 유의미한 감소
- 서버 coin 테이블 Android 일일 deposit 건수 대비 재무 리포트 환불 비율 감소

### Output metric (중기, 배포 후 1~3개월)
- Play Console "월간 구매자 비율" 회복 — 반토막 이전 수준(13%대) 근접
- Android 순매출(환불 제외) 증가
- CS "결제 후 환불됨" 문의 감소

## 블로커 및 리스크

- **서버 로그 접근 제한**: 본 프로젝트에서는 DB + 재무 리포트로 대체 → 가설 확정 신뢰도 약간 하락할 수 있으나 충분히 진단 가능
- **재무 리포트는 월말 마감 후 발행**: 수정 배포 후 최종 환불 감소 확인까지 최소 1개월 + 리포트 발행일까지 소요
- **점진 롤아웃 필요**: 이전 회귀와 동일한 실수를 피하기 위해 10% → 50% → 100%. Play Store의 staged rollout 기능 활용
- **Android 버전 파편화**: 다수 구버전 유저 대상으로 update prompt 권장

## 문서 목록

| 문서 | 설명 |
|------|------|
| [1pager.md](./1pager.md) | 프로젝트 1-pager |
| [status.md](./status.md) | 진행 상태 대시보드 |
| [tasks.md](./tasks.md) | 파트별 과업 목록 |
| [issues.md](./issues.md) | 이슈 레지스트리 (ISS-001 등록됨) |
| [architecture.md](./architecture.md) | (추후) /architect 작성 |
| [api-spec.md](./api-spec.md) | (추후) /architect 작성 (필요 시) |
| [qa-test-cases.md](./qa-test-cases.md) | (추후) /qa 작성 |
| [references/timeline-and-metrics.md](./references/timeline-and-metrics.md) | 타임라인·지표 정리 |
| [references/android-billing-code-analysis.md](./references/android-billing-code-analysis.md) | Android 코드 분석 |
| [references/data-sources.md](./references/data-sources.md) | 조사 데이터 소스 인덱스 |
| [planning/](./planning/) | 기획·조사 산출물 |
