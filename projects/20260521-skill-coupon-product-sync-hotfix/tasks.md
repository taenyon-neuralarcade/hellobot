# 파트별 과업

> 부모 [ISS-071](../20260324-coop-integration/issues.md#iss-071-스킬-교환권-상품-crud-↔-couponspeccouponcondition-정합성-깨짐) · [requirements.md](./requirements.md) · [user-stories.md](./user-stories.md) 참조. 모든 과업은 `hellobot-server` 단일 파트. FR ID 는 requirements.md 와 매핑.

## 기획 파트

- [x] T-0a: 코드 심층 분석 → 결함 매트릭스 9 건 도출 → ISS-071 등록 (2026-05-21)
- [x] T-0b: 1pager.md 작성 (2026-05-21)
- [x] T-0c: user-stories.md 작성 — 9 스토리 (US-01~US-09) (2026-05-21)
- [x] T-0d: requirements.md v1 작성 — FR-1~FR-4 / NFR-1~NFR-5 / C-1~C-5 / 검증 기준 / D-1~D-5 결정 보류 (2026-05-21)
- [x] T-0e: 비판적 리뷰 5 종 + 통합 요약 (SUMMARY.md) — 69 건 결함, C-1~C-8 (2026-05-21)
- [x] T-0f: 메타-리뷰 + requirements.md v2 — FR 14 / NFR 7 / C 6 / D 9, 매핑 검증 표, Non-Goals (2026-05-21)
- [ ] T-0g: **D-1~D-9 사용자 협의** → requirements.md §8 갱신 (v3)
- [ ] T-0h: **C-6 이해관계자 사인오프** (CS·운영·재무·데이터) — D-7 채널로
- [ ] T-0i: **§10 신규 산출물 책임자·일정 확정** — 운영 SOP (FR-5.1) / CS 조회 쿼리 (FR-5.2) / 정량 추정 (FR-5.3)
- [ ] T-0j: 본 핫픽스 일정 결정 (진단 결과 + D-5 2단계 옵션 확정 후) → status.md 마감일 갱신

## 서버 파트

### 진단·정량화 (FR-3 / FR-5.3 — 코드 수정 없이 가능 · /architect 게이트의 선행 입력)

- [ ] T-1: 진단 SQL 작성 — 동일 `skillSeqs` 에 활성 CouponSpec 2 개 이상 매칭되는 케이스 식별 (`coupon_condition.skill_seqs` ↔ `coop_marketing_product.fixed_menu_seq`) — FR-3.1①
- [ ] T-2: 진단 SQL — `productType=skill && couponSpecSeq IS NULL` 좀비 상품 — FR-3.1②
- [ ] T-3: 진단 SQL — `coop_marketing_product` 에서 참조되지 않는 orphan CouponSpec (이름 패턴 `% 이용권` + 단일 skillSeqs 매칭 등) — FR-3.1③
- [ ] T-4: 운영 DB 에 진단 SQL 실행, 점검 결과 status.md 또는 별도 점검 노트에 기록 — FR-3.2 (D-8 마감 결정 후)
- [ ] T-4b: **정량 임팩트 추정** — 진단 row 수 + 영향받을 발급 쿠폰 수 추정 + 운영자 작업 빈도 (어드민 로그 1회 샘플링) — FR-5.3
- [ ] T-4c: **D-9 (`CouponSpec.name` 노출 경로) 1줄 확인** — /dev-server grep — D-3 재결정 입력

### 설계 (FR-1 / FR-2 — /architect 단계)

- [ ] T-5: 동기화 정책 명세 — 5 케이스 (fixedMenuSeq 변경 · productName 변경 · delete · productType 전환 · afterNew 실패) 각각의 결정론적 결과 상태 정의 — FR-1.1~1.5, FR-2.1~2.3
- [ ] T-6: 트랜잭션 경계 설계 — 상품 INSERT/UPDATE 와 CouponSpec 동기화의 atomic 단위 결정 — FR-2.3
- [ ] T-7: name UNIQUE 회피 정책 명세 (D-3 결정 반영) — FR-1.5

### 구현 (FR-1 / FR-2)

- [ ] T-8: AdminJS 훅 재구현 — `src/admin/options/CoopMarketingProduct.options.ts`
  - `beforeSave`: skill 상품 필수값(`fixedMenuSeq`) validation — FR-2.1
  - `afterNew`: 가드 위반 silent skip 제거, error 승격 — FR-2.1, FR-2.2
  - `afterEdit`: `fixedMenuSeq` 변경 시 옛 spec issueEndDate + 새 spec 생성·교체 — FR-1.1, FR-4.1
  - `afterEdit`: productName 변경 시 D-3 정책 적용 — FR-1.5
  - `afterEdit`: productType 전환 D-2 정책 적용 — FR-1.4
  - `afterDelete` 신규: spec 동결 (D-1 정책) — FR-1.3, FR-4.2
- [ ] T-9: 트랜잭션 통합 / 보상 로직 — T-6 명세대로 — FR-2.3
- [ ] T-10: 정합화 (D-4 결정 + T-4 결과 반영) — FR-3.3

### 검증 (NFR-1 · 검증 기준 §7)

- [ ] T-11: QA 시나리오 — A→B 수정 후 옛 쿠폰 적용 대상 보호, 동일 스킬 재등록 시 활성 spec 단일성, delete 후 발급 쿠폰 사용 가능, productName UNIQUE 충돌 UX, fixedMenuSeq 누락 reject, 부분 실패 가시성 — US-01~US-07
- [ ] T-12: 핫픽스 배포 후 진단 SQL 재실행 → 3 종 모두 0 row 확인 — §7 검증 항목
- [ ] T-13: 운영 배포 절차 — TODO-022(PR #2421) 와 동일 패턴 (로컬 SSH 터널 마이그레이션 → PR 머지) — C-3

## 비고

- 모든 변경은 즉시 배포 가능한 단위로 (CLAUDE.md 배포 호환성 규칙, NFR-2)
- 본 핫픽스로 부모 coop-integration 의 architecture.md / api-spec.md 의미가 바뀌면 Changelog 동반 갱신 (C-5)
- 신규 테이블·컬럼 도입 시 영향 범위 매트릭스(requirements.md §2) 갱신

## 비고

- 모든 변경은 즉시 배포 가능한 단위로 (CLAUDE.md 배포 호환성 규칙).
- 부모 coop-integration 의 architecture.md / api-spec.md 변경 필요 없음 (운영 어드민 내부 정합성 한정). 변경되면 Changelog 동반.
