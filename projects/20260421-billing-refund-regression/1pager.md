## Problem

2025-03-18 배포된 hellobot_android **2.29.5** 이후 Google Play Console의 "월간 구매자 비율"이 **13.11% → 6.63%로 반토막**. 이후 1년 넘게 6~8%대에 고착되어 현재(2026-04)까지 이어지고 있다.

- 앱 이전일(2025-02-10)부터 2.29.5 확산 직전(3/22)까지는 13%대 정상 유지 → 앱 이전은 원인 아님
- 급락 시점(3/22~24)이 2.29.5의 유저 업데이트 확산 타이밍과 정확히 일치
- 2.29.5의 핵심 변경은 PR [#1044](https://github.com/thingsflow/hellobot_android/pull/1044) "자동 환불" — 실제로는 결제 모듈 전면 리팩토링(1,442줄, 34개 파일)
- 현재 master(2.40.0.1)에도 동일 코드 유지 → **버그가 지속 중일 가능성 매우 높음**

## Customer Job

1. 유저: 결제한 상품을 정상적으로 받고, 의도치 않은 환불·결제 실패를 겪지 않는다
2. 회사: 실제 발생한 매출이 Google 자동 환불로 소실되지 않는다
3. 운영/CS: "결제했는데 환불됐어요" 문의 감소

## Solution / Feature

**3단계로 진행**:

### Phase 1 — 원인 확정 (조사)
- Google IAP 재무 리포트(CSV) 분석: 2025-02~04 환불 건수·사유·간격 분포
- 서버 DB 교차 검증: coin 테이블 실제 구매 추이 (서버 애플리케이션 로그는 접근 어려워 제외)
- Android 코드 상세 정적 분석: 가설 A/B/C/D 중 주 원인 확정

### Phase 2 — 개선 방안 설계
- 버그 수정 설계 (BillingManager 큐 관리, 리스너 라우팅, 에러 핸들링)
- Google Play Billing Library 권장 패턴 재정립
- 회귀 방지 테스트 케이스 설계

### Phase 3 — 구현·배포·검증
- hellobot_android 코드 수정 + 테스트
- 서버 DU002 처리 경로 보강 (필요 시)
- 점진 롤아웃 + Play Console "월간 구매자 비율" 회복 여부 관찰

## Success Metric

**Input metric**
- 월간 재무 리포트(IAP CSV) 기준 자동 환불 건수·금액이 수정 배포 전/후 유의미하게 감소
- 서버 `thingsflow.coin` 테이블 Android 일일 deposit 건수 대비 Google 재무 리포트 환불 건수 비율 감소

**Output metric**
- **월간 구매자 비율 회복**: 6~7%대 → 수정 직전 정상 수준(이전 계정 포함 동기간 기준) 근사치로 회복
- Android 순매출(환불 제외) 증가
- CS 문의 "결제 후 환불됨" 감소

## Benchmark

- Google Play Billing Library 공식 가이드: `queryPurchasesAsync` → **반드시 `isAcknowledged=false && purchaseState=PURCHASED` 필터링 후 처리**
- Google Developer Policy: consumable은 72시간 이내 consume 또는 acknowledge 필요, 위반 시 자동 환불

## Trade off

- 수정 범위가 결제 모듈 전반 → 회귀 위험 高. 충분한 QA 필요
- 점진 롤아웃(10%→50%→100%) 필수 — 이전 회귀와 동일한 실수 방지
- 소급 환불 이미 발생한 유저에 대한 보상은 별도 정책 논의 필요 (이 프로젝트 범위 외)

## Unhappy Path

- 버그 수정 배포 후에도 월간 구매자 비율이 회복되지 않으면 → 원인이 클라이언트 외에 있음 (서버/Play Console 집계 정책 등). 가설 재수립 필요
- 수정 과정에서 신규 회귀 유발 시 → 하트 미지급·이중 지급 이슈. QA 커버리지 강화 필요

## Feedback loop

- 배포 후 **2주 단위로** Play Console 월간 구매자 비율 모니터링
- 서버 `thingsflow.coin` 테이블로 Android 일일 결제 성공 건수 주 단위 확인
- 월간 재무 리포트(IAP CSV) 환불 건수로 최종 검증 (다음 월 재무 리포트 발행 시)

---

> 이 1pager는 워크스페이스 관리자가 조사 대화 내용을 정리한 초안입니다. 사용자 확인 후 `/analyze`로 정식 요구사항 문서(readme.md)를 생성하세요.
