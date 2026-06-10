# 스킬 교환권 상품 CRUD ↔ 쿠폰 정합성 핫픽스

> **부모 프로젝트**: [coop-integration](../20260324-coop-integration/)
> **이슈**: [ISS-071](../20260324-coop-integration/issues.md#iss-071-스킬-교환권-상품-crud-↔-couponspeccouponcondition-정합성-깨짐)
> **상위 TODO**: [TODO-013](../../todos/TODO-013-kakao-hotfix-residual.md) (umbrella) → [TODO-026](../../todos/TODO-026-skill-coupon-product-sync-hotfix.md) (본 핫픽스)

## 배경

카카오 선물하기 1차 출시(5/22) 직전, 운영자가 어드민에서 스킬 교환권 상품을 등록·수정·삭제·재등록할 때 연동 쿠폰(`CouponSpec` / `CouponCondition`) 상태가 의도와 달리 정합성을 잃을 수 있다는 것이 코드 심층 분석으로 확인됨. 사용자 발화(2026-05-21): "어떤 동작을 해도 잘 등록되어 있을 것이다 라는 신뢰가 가는 상태가 아닌 것 같아."

발견된 결함은 P0 2 건(retroactive in-place 갱신·동일 스킬 재등록 누적) + P1 6 건(orphan·UNIQUE 충돌·silent skip·부분 실패). 상세는 ISS-071 결함 매트릭스.

## 목표

운영자가 어드민에서 상품을 어떻게 다루든 발급된 쿠폰의 적용 대상·사용 가능 여부가 **결정론적으로 예측 가능한 상태**를 보장한다.

- 이미 발급된 쿠폰의 적용 대상이 운영자 의도 외로 retroactively 바뀌지 않음
- 옛 상품에 대한 발급 쿠폰은 사용 가능하되, 신규 발급은 단일 진입점만 활성
- couponSpecSeq=null 좀비 상품·orphan CouponSpec 의 발생을 차단하거나 운영자가 즉시 인지

## 범위

### 포함

- `src/admin/options/CoopMarketingProduct.options.ts` 의 new/edit/delete 훅 재설계
- `CouponSpec` / `CouponCondition` 동기화 정책 정립 (변경 시 옛 spec issueEndDate 처리 + 새 spec 생성, productName UNIQUE 회피, delete 시 cleanup)
- 운영 즉시 점검용 진단 SQL (이미 발생한 정합성 깨진 데이터 식별)
- 점검 결과로 잡힌 데이터 정합화(필요 시 일회성 보정 마이그레이션 또는 운영 절차)

### 제외

- `CouponSpec` / `CouponCondition` 의 일반 어드민 직접 수정 차단(I, P2) — 본 핫픽스 후 별건
- 가격·하트 충전권(heart) 로직 — CouponSpec 무관
- 쿠폰 사용 시점 검증 로직(`coupon.ts`) — 동기화 정책 정상화로 충분히 커버되는 영역까지만

## 산출물

| 문서 | 작성 시점 | 비고 |
|------|-----------|------|
| [1pager.md](./1pager.md) | 5/21 작성 | Problem / Customer Job / Solution / Success Metric / Non-Goals |
| [user-stories.md](./user-stories.md) | 5/21 작성 | 운영자·엔드유저·CS 페르소나별 9 개 스토리 (P0 2 / P1 5 / 진단 2) + Acceptance Criteria |
| [requirements.md](./requirements.md) | 5/21 작성 | FR / NFR / 제약 / 의존 관계 / 검증 기준 / D-1~D-5 결정 보류 |
| `readme.md` | 본 문서 | 배경·목표·범위 |
| `status.md` | 초기 생성 + 5/21 갱신 | 진행 상태 대시보드 |
| `tasks.md` | 초기 생성 + 5/21 갱신 | 파트별 과업 (서버 단일) |
| `architecture.md` | 설계 단계 (대기) | 동기화 정책·시퀀스 — /architect 산출. D-1~D-5 합의 후 착수 |

부모 프로젝트의 `architecture.md` / `api-spec.md` 변경이 필요해지면 변경 + Changelog 갱신.

## 일정

- 5/22 1차 출시 직전 단순 진단 + 위험 데이터 점검은 사전 실행
- 코드 핫픽스 일정은 사용자 협의 후 결정 (1차 출시 안정화 가 우선)
