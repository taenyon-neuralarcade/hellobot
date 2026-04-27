# 과업 목록

## Phase 1 — 원인 확정 (조사)

### 기획 (planning/)
- [ ] Phase 1 산출물 통합 정리 — 데이터/서버/클라이언트 조사 결과를 root-cause 보고서로 통합 (planning/root-cause-report.md)

### 데이터 (/dev-data)
- [ ] Google IAP 재무 리포트 CSV 6개 통합 로딩 (2025-02/03/04 × 두 계정, planning/iap-analysis/)
- [ ] `com.thingsflow.hellobot` 필터링 후 일자별 Charge / Charge refund 건수·금액 집계
- [ ] 환불 시점 분석: `refund_date - charge_date` 간격 분포 (72시간 이내 자동 환불 비중 확인)
- [ ] Refund Type 분포 (Google 정책 자동 환불 vs 유저 요청 환불)
- [ ] SKU별 환불율 (`hellobot_coin10`, `hellobot_coin50` 등)
- [ ] 2.29.5 배포 전/후 환불 건수 비교 (3/18 전후 ±2주)
- [ ] 분석 결과 요약 (planning/iap-analysis/summary.md) + 원본 집계 데이터 (CSV/xlsx)
- [x] 구독 vs 상품 분리 집계 (일별·주별·월별) 및 특이점 검토 (planning/iap-analysis/category-split-analysis.md, 2026-04-22)

### 서버 (/dev-server)
- [ ] `thingsflow.coin` 테이블 조회 — 2025-02~04 Android 일자별 `receipt_id` 있는 신규 deposit 건수 (서버 기준 실제 결제 성공 건)
- [ ] Amplitude `purchase_heart_product` 이벤트 일별 수 확보 (접근 가능 시)
- [ ] 서버 기준 실제 매출 vs Play Console 통계 교차 검증 결과 정리

> 서버 애플리케이션 로그(winston, DU002 카운트 등)는 조회 인프라 접근이 어려워 본 프로젝트에서는 제외. DB + Amplitude 데이터로 대체 검증.

### Android (/dev-android)
- [ ] BillingService / BillingManager 현행(master) 코드 상세 분석 — INAPP/SUBS 처리 차이, 에러 핸들링, 리스너 라우팅
- [ ] 레이스 컨디션 재현 시나리오 정리 (화면 전환 순서별)
- [ ] Google Play Billing Library 권장 패턴과의 gap 분석
- [ ] 2.29.4 → 2.29.5 → master 코드 변화 요약 문서 (references/android-billing-code-analysis.md 갱신)

## Phase 2 — 개선 방안 설계

### 아키텍처 (/architect)
- [ ] 결제 모듈 개선 아키텍처 설계 (architecture.md)
  - BillingService: queryPurchases 결과 필터링 규칙 (isAcknowledged, purchaseState)
  - BillingManager: 리스너 다중 등록 가능한 구조 (Set 또는 orderId → productType 라우팅)
  - 에러 핸들링: HTTP 400 재시도 제거, DU002 시 서버 상태 동기화만
  - unprocessedPurchases 큐 관리 규칙
- [ ] 서버 API 변경 필요 여부 검토 (api-spec.md)

### QA (/qa)
- [ ] 회귀 방지 테스트 케이스 초안 설계 (qa-test-cases.md)

## Phase 3 — 구현·배포·검증

### Android (/dev-android)
- [ ] 워크트리 생성: `projects/20260421-billing-refund-regression/worktrees/hellobot_android/` (브랜치 `feat/billing-refund-regression`)
- [ ] BillingService.notConsumedPurchase INAPP 필터 수정
- [ ] BillingManager 리스너 라우팅 구조 변경
- [ ] consumeProduct 에러 핸들러 정리
- [ ] 단위 테스트 추가
- [ ] QA 대응 및 이슈 수정

### 서버 (/dev-server)
- [ ] (필요 시) DU002 응답 시 동작 조정 (예: 서버가 이미 성공 처리한 건에 대해 Google consume 허용 여부 명시적 응답)
- [ ] 결제 관련 DB 레코드 보강 검토 (결제 상태/consume 상태/acknowledge 상태 컬럼 보완으로 이후 조회 가능하도록)

### QA (/qa)
- [ ] 정식 테스트 케이스 작성 및 실행
- [ ] 회귀 검증 (기존 결제 플로우 전체)

### 리뷰 (/review)
- [ ] PR 리뷰 및 배포 전 크로스 체크
- [ ] 점진 롤아웃 계획 확인

### 배포·모니터링
- [ ] 10% → 50% → 100% 점진 롤아웃
- [ ] 배포 후 2주간 Play Console 월간 구매자 비율 일일 모니터링
- [ ] 배포 후 1개월 후 월간 재무 리포트로 최종 검증

## 의존 관계

- Phase 1의 3개 조사 과업(데이터/서버/Android)은 **병렬 진행 가능**
- Phase 2는 Phase 1 통합 보고서 완료 후 착수
- Phase 3 구현은 Phase 2 설계 확정 후 착수
- 데이터 분석 결과가 "원인이 클라이언트 외부"를 시사하면 Phase 2/3 범위 재정의 필요
