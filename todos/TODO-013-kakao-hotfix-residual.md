# TODO-013 카카오 선물하기 핫픽스 배포 잔여건

**유형**: 액션 (일정 결정 필요)
**상태**: 진행 중 — **🔥 5/22 (금) 까지 처리 방향 결정 완료 필수** (쿠폰 운영 영향 가능 항목 — 최대한 가벼운 방식으로)
**등록**: 2026-05-13
**시작**: 2026-05-21
**완료**: -
**마감**: **5/22 (금) — 처리 방향 결정 완료**
**담당**: 코디네이터 → /dev-* 위임 (일정 도래 시)
**관련**: [coop-integration](../projects/20260324-coop-integration/) (실제 구현은 프로젝트 워크트리에서)

## 컨텍스트

coop-integration(카카오 선물하기) 운영 배포 후 잔여 핫픽스 항목. 사용자 발화: "언제 처리할래?" — 일정 결정이 필요한 상태.

본 TODO 는 **일정 결정 + 배포 트리거** 게이트. 실제 구현·배포는 coop-integration 프로젝트의 워크트리·tasks.md 안에서.

## 현재 상태

🔥 **5/22 (금) 처리 방향 결정 완료 필수**. 쿠폰 운영에 문제가 될 수 있는 잔여 항목 식별됨 (TODO-022 정합화 + 5/21 신규 검토 항목 등). 사용자 방침: **최대한 가벼운 방식으로** — 1차 출시 안정성·운영 부담 최소화.

5/20 잔여 핫픽스 항목 도출 완료 (/analyze 결과). 5/22 까지 각 항목의 처리 방향(즉시 패치 vs 모니터링 vs P3 묶음 보류 vs 운영 SOP 대응) 결정 완료.

**도출된 P0/P1 핫픽스 (별도 TODO 로 가시화)**:
- [TODO-022](TODO-022-coop-admin-cancel-hotfix.md) — 운영 어드민 사용취소 (ISS-056, **P0**). ✅ **2026-05-21 11:30 운영 배포 완료** (PR #2421 머지). 운영 정합화 잔여 (별도 단계, 일정 결정)
- [TODO-023](TODO-023-coop-compcode-env-split.md) — 쿠프마케팅 compCode env 분리 (ISS-055, P1) — dev/prod 동일 `A911` 하드코딩, env 전환 + EKS 매니페스트 등록

**신규 검토 항목 (2026-05-21 사용자 보고)** → **TODO-026 으로 승격 (5/21)**:
- ✅ /dev-server 코드 심층 분석 완료 → 결함 9건 (P0 2 / P1 6 / P2 1) 도출
- ✅ ISS-071 정식 등록 (coop-integration/issues.md), 자식 프로젝트 [`projects/20260521-skill-coupon-product-sync-hotfix/`](../projects/20260521-skill-coupon-product-sync-hotfix/) 생성
- ✅ [TODO-026](TODO-026-skill-coupon-product-sync-hotfix.md) 로 승격 — 본 umbrella 추적 종료, TODO-026 에서 일정·스코프 결정 + 구현 진행

**나머지 잔여 (status.md §잔여 과업 + issues.md 미해결, P2/P3)**:
- 기능: ISS-043 (신규 가입자 스킬이용권 인트로), ISS-052 (L1+L3 자동 복구 — CS 발생 시), Phase 1 QA 재검증, DebugView 발화 검증, Firebase 화이트리스트 등록 + event-catalog SSOT 갱신, QA 통합 검증
- Android PR #1127 리뷰 후속 (ISS-058~070, 모두 P3, 다음 release/hotfix 묶음)
- 기획·운영: 카카오 딥링크, Admin 정산 통계, 메트릭/로그 수집, 스킬 이용권 라인업 + 상품 구성, Phase 2 `/api/coop/*` 제거 (안정 기간 후)

상세는 [coop-integration status.md §잔여 과업 요약](../projects/20260324-coop-integration/status.md) 및 [issues.md](../projects/20260324-coop-integration/issues.md).

## 다음 단계

- [x] **검토 (2026-05-21 신규)** — 스킬 교환권 상품 등록 수정 시 연동 쿠폰 상태 변경 정합성 → /dev-server 분석 → ISS-071(P0) 정식 등록 → **TODO-026 으로 승격**
- [ ] 1차 출시(5/22) 안정화 후 TODO-023 패치 일정 결정 (사용자 협의) — TODO-022 는 5/21 운영 배포 완료 / 운영 정합화만 잔여
- [ ] P2/P3 잔여 항목들의 묶음·우선순위 결정 — 다음 release 묶음 vs 별건 hotfix
- [ ] 일정 도래 시 해당 파트별 `/dev-*` 위임 → 본 umbrella TODO 종료, 작업 기록은 coop-integration 에 유지

## 진행 로그

- 2026-05-13 — TODO 등록, 일정 결정 보류
- 2026-05-20 — /analyze 결과 잔여 항목 도출. TODO-022 (ISS-056 P0), TODO-023 (ISS-055 P1) 별도 가시화. 나머지 P2/P3 항목은 본 umbrella 에서 추적 유지
- 2026-05-21 — TODO-022 ✅ 운영 배포 완료 (11:30 PR #2421 머지). 사용자 보고로 신규 검토 항목 추가 — 스킬 교환권 상품 등록 수정 시 연동 쿠폰 상태 변경 정합성. 의심 동작: 쿠폰 삭제 미적용 → 동일 스킬 쿠폰 재등록 시 쿠폰스펙 테이블 정합 문제 가능. 검토 후 결함 확인되면 ISS-NNN 정식 등록
- 2026-05-21 (오후) — /dev-server 코드 심층 분석 완료. `CoopMarketingProduct.options.ts` + `coupon.ts` 검토 → 결함 9건 (P0 2 / P1 6 / P2 1) 도출. ISS-071 정식 등록 (coop-integration/issues.md). 자식 프로젝트 `projects/20260521-skill-coupon-product-sync-hotfix/` 생성 + TODO-026 으로 승격. 본 umbrella 의 신규 검토 항목 트랙은 TODO-026 으로 이관
