---
name: todo-041-coop-admin-coupon-usage-visibility
description: "카카오 선물하기 어드민 — 쿠폰 사용 내역에 거래 식별 정보(스킬명/ProductCode/사용자명) 노출. /dev-server 위임"
metadata:
  type: action
---

# TODO-041 카카오 선물하기 어드민 — 쿠폰 사용 내역 거래 식별 정보 노출

**유형**: 액션 (어드민 기능 추가 — /dev-server 위임)
**상태**: 신규 등록 — 시작 전 (구현 위임 대기)
**등록**: 2026-06-04
**시작**: -
**완료**: -
**마감**: - (미정 — 운영 우선순위 따라 결정)
**담당**: 코디네이터 → `/dev-server` 위임 (hellobot-server AdminJS)
**관련**:
- [[todo-029-kakao-gift-operations-guide]] — 운영 가이드 (문서 2 결제·쿠폰 취소가 동일 화면을 다룸 — 본 개선이 가이드 품질로 직결)
- [[todo-022-coop-admin-cancel-hotfix]] — 운영 어드민 사용취소 (동일 CoopMarketingCouponUsage 레코드 대상)
- [[todo-013-kakao-hotfix-residual]] — 카카오 핫픽스 잔여 (umbrella)
- [coop-integration](../projects/20260324-coop-integration/) — 카카오 선물하기 프로젝트 (구현 scope)

## 컨텍스트

사용자 요청 (2026-06-04):
> 카카오 선물하기 어드민 기능 추가. 쿠폰 사용 내역 메뉴에서 관리자가 어떤 항목인지 인지할 수 없음. 스킬명이나, ProductCode, 사용자명이라도 어드민 화면 내에서 보여야 어떤 거래건인지 인지할 수 있을 것 같음.

**문제**: AdminJS 쿠폰 사용 내역 화면(추정: `CoopMarketingCouponUsage` 리소스)이 식별 정보 없이 표시되어, 운영자가 각 행이 **어떤 상품/어떤 사용자의 거래인지 인지 불가**. CS·사용취소·정합화 작업 시 거래 특정이 어려움.

**요청 개선**: 사용 내역 목록(및 상세)에 아래 식별 컬럼 노출
- **스킬명 / 상품명** (CoopMarketingProduct.productName 등)
- **ProductCode** (상품 식별 코드)
- **사용자명** (거래 사용자)

> ※ 위 3종 중 "스킬명이나 ProductCode, 사용자명이라도" — 전부 또는 식별 가능한 최소 1~2종이라도 노출되면 됨. 구현 난이도(조인 비용)에 따라 /dev-server 가 우선순위 제안.

## 영향 범위

| 파트 | 영향 | 설명 |
|---|---|---|
| 서버 (AdminJS) | O | hellobot-server — `CoopMarketingCouponUsage` 어드민 리소스에 식별 컬럼/조인 추가 |
| 데이터 모델 | △ | 스키마 변경 없음 (기존 엔티티 조인 표시만) 예상 — 확인 필요 |
| 디자인 | X | 어드민 내부 화면, 디자인 스펙 불요 |

> 단일 리포(hellobot-server) · 스키마 변경 없음 예상 · 1일 미만 추정 → **프로젝트 승격 불요**. coop-integration scope 의 /dev-server 단발 과업.

## 현재 상태

신규 등록. 시작 전. /dev-server 위임 대기.

## 다음 단계

- [ ] **/dev-server 위임** — AdminJS 쿠폰 사용 내역 리소스 확인 (`CoopMarketingCouponUsage` 추정) → 어떤 엔티티 조인으로 스킬명/ProductCode/사용자명 노출 가능한지 파악
- [ ] 노출 컬럼 확정 (3종 전부 vs 식별 최소 조합) + 목록/상세 어느 화면에 노출할지
- [ ] 구현 (조인·표시 컬럼 추가) → 워크트리에서 작업
- [ ] 운영팀 확인 (실제 거래 식별 가능해졌는지)
- [ ] 완료 시 [[todo-029-kakao-gift-operations-guide]] 문서 2(결제·쿠폰 취소)에 갱신 화면 반영

## 진행 로그

- 2026-06-04 — TODO 등록 (사용자 요청). 쿠폰 사용 내역 어드민에 거래 식별 정보 부재 → 스킬명/ProductCode/사용자명 노출 요청. 코드 변경 건 → /dev-server 위임 대상. coop-integration scope. 마감 미정.
