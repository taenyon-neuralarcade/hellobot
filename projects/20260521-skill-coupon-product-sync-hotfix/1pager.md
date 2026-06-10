# 1-pager — 스킬 교환권 상품 CRUD ↔ 쿠폰 정합성 핫픽스

## Problem

카카오 선물하기 1차 출시(2026-05-22) 직전, 운영자가 어드민(`AdminJS`)에서 스킬 교환권 상품을 등록·수정·삭제·재등록할 때 연동 쿠폰(`CouponSpec` + `CouponCondition`)이 의도와 다르게 정합성을 잃을 수 있다. /dev-server 코드 심층 분석 결과 결함 9 건 도출(P0 2 + P1 6 + P2 1, ISS-071).

특히 두 가지가 운영 폭발력이 큼:
- **P0-A**: `fixedMenuSeq` 를 A→B 로 수정하면 `CouponCondition.skillSeqs` 가 in-place 로 바뀌어, **이미 발급된 미사용 쿠폰의 적용 대상까지 retroactively 변경**됨. 사용 시점에 조건이 평가되기 때문(`src/services/coupon.ts:161-188, 242-260`).
- **P0-B**: 동일 스킬에 새 상품을 재등록할 때 옛 `CouponSpec` 의 cleanup 이 일어나지 않아, 동일 `skillSeqs` 에 두 개의 활성 spec 이 매칭됨 → 사용자가 두 쿠폰을 동시에 보유·사용 가능. 동일 상품명이면 `CouponSpec.name` UNIQUE 도 충돌.

운영자의 체감(2026-05-21): "어떤 동작을 해도 잘 등록되어 있을 것이다 라는 신뢰가 가는 상태가 아닌 것 같다."

## Customer Job

- **운영자** 가 어드민에서 상품 CRUD 를 수행할 때, 발급된 쿠폰의 적용 대상·신규 발급 가능 여부를 **결정론적으로 예측** 할 수 있다.
- **엔드유저** 가 발급받은 쿠폰의 적용 대상이 운영자 측 수정에 의해 바뀌지 않는다 (CS 폭탄 차단).
- **CS 팀** 이 "쿠폰이 갑자기 다른 스킬에 적용된다" 류 문의에 시달리지 않는다.

## Solution (방향만 — 상세 설계는 /architect)

1. **운영 즉시 진단** — 점검 SQL 3 종 (동일 skillSeqs 활성 spec 2 개 이상 / couponSpecSeq=null skill 상품 / orphan CouponSpec) 으로 현재 운영 DB 의 정합성 깨진 데이터 인벤토리 확보.
2. **동기화 정책 재설계** — `CoopMarketingProduct` 의 CRUD 가 `CouponSpec` / `CouponCondition` 에 미치는 영향을 결정론적 규칙으로 정의: 옛 spec 은 `issueEndDate` 로 동결(발급분 보존)·새 spec 으로 교체. 가드 위반은 silent skip 대신 validation error.
3. **운영자 가시화** — 부분 실패·UNIQUE 충돌·필수값 누락이 admin UI 상 success 로 보이지 않도록.
4. **정합화** — 진단으로 잡힌 케이스에 대해 운영 절차 또는 일회성 보정.

## Success Metric

- 운영 진단 SQL 3 종 실행 결과 = 0 row (정합성 위반 0 건)
- 핫픽스 배포 후 동일 SQL 재실행 결과 = 0 row 유지
- CS 문의 "쿠폰이 다른 스킬에 적용된다" 또는 "쿠폰 중복 발급" 발생 0 건
- 운영자가 "수정/삭제했는데 옛 상태가 남는다" 류 보고 0 건

## Non-Goals

- `CouponSpec` / `CouponCondition` 자체의 어드민 직접 수정 차단 (I, P2) — 본 핫픽스 후 별건
- 하트 충전권(`productType=heart`) 로직 — CouponSpec 무관
- 쿠폰 사용 시점 검증 로직(`coupon.ts`) — 동기화 정책 정상화로 충분히 커버되는 영역까지만
- 운영자 권한 분리 / 감사 로그 / 변경 이력 UI — 별 트랙

## 일정

- **5/22 1차 출시 직전·직후**: 진단 SQL 실행 (코드 수정 없이 사전 점검) — D-0
- **본격 핫픽스**: 1차 출시 안정화 + TODO-013 우선순위 협의 후 결정

## 관련 문서

- [ISS-071](../20260324-coop-integration/issues.md#iss-071-스킬-교환권-상품-crud-↔-couponspeccouponcondition-정합성-깨짐) (결함 매트릭스 9건 + 영향 범위)
- [TODO-026](../../todos/TODO-026-skill-coupon-product-sync-hotfix.md)
- 부모 프로젝트: [coop-integration](../20260324-coop-integration/)
- 핵심 코드: `src/admin/options/CoopMarketingProduct.options.ts`, `src/services/coupon.ts:161-260`, `src/models/entities/CouponSpec.ts:39` (name UNIQUE), `src/models/entities/CouponCondition.ts`
