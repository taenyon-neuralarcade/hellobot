# 카카오 선물하기 운영 가이드 — 개요·인덱스

> **상태**: 🟡 초안 (2026-06-02) · **대상**: 내부 운영팀 인계용 · **언어**: 한국어
> **SSOT 추적**: [TODO-029](../../../todos/TODO-029-kakao-gift-operations-guide.md)
> 본 문서 세트는 카카오 선물하기 채널의 **하트 충전권 / 스킬 교환권** 상품을 운영자가 등록·수정·취소·정산·CS 대응하기 위한 실무 가이드입니다.

---

## 1. 한눈에 보기

- **무엇**: 카카오톡 선물하기에서 판매되는 헬로우봇 상품(하트 충전권·스킬 교환권)을 사용자가 쿠폰번호로 등록하면, 헬로우봇이 하트 충전 또는 100% 할인 쿠폰을 지급하는 연동.
- **중계사**: **쿠프마케팅(coopnc / inumber)** — 카카오와 헬로우봇 사이의 쿠폰 인증·정산 중계.
- **운영 도구**: **AdminJS** (상품 CRUD·사용이력 조회·사용취소).
- **연동 프로젝트**: [coop-integration](../../../projects/20260324-coop-integration/) (architecture / api-spec / issues 가 기술 SSOT).

---

## 2. 서비스 구조

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────┐
│  카카오       │     │  쿠프마케팅    │     │  헬로우봇 서버     │
│  선물하기     │────▶│  (인증 중계)   │◀───▶│  (상품제공업체)    │
└──────────────┘     └──────────────┘     └────────┬─────────┘
        구매             쿠폰 인증/정산              │ 상품 지급
                                          ┌─────────┼─────────┐
                                       ┌──▼──┐  ┌──▼──┐  ┌──▼──┐
                                       │ Web │  │ iOS │  │ AOS │
                                       └─────┘  └─────┘  └─────┘
```

1. 사용자가 카카오 선물하기에서 상품 구매 → 쿠폰번호 수신
2. 헬로우봇 앱/웹의 **쿠폰 등록** 화면에 쿠폰번호 입력
3. 서버가 프리픽스(`90`/`91`)로 카카오 쿠폰임을 판별 → 쿠프마케팅 API로 인증(L0)·사용승인(L1)
4. **하트 충전권** → 하트 즉시 충전 / **스킬 교환권** → 100% 할인 쿠폰 발급 후 0하트 구매

---

## 3. 상품 2종 비교

| 구분 | 하트 충전권 (`heart`) | 스킬 교환권 (`skill`) |
|------|----------------------|----------------------|
| 지급 방식 | 하트 즉시 충전 | 100% 할인 쿠폰 발급 → 기존 스킬 구매 플로우로 0하트 구매 |
| 핵심 필드 | `heart_quantity` (충전 수량) | `fixed_menu_seq` (대상 스킬) + `coupon_spec_seq` (자동 생성 쿠폰) |
| 등록 시 부수 동작 | 없음 | `CouponSpec`(100% 할인) + `CouponCondition`(skillSeqs=[fixedMenuSeq]) **자동 생성** |
| 사용 기록 참조 | `heart_log_seq` | `issued_coupon_seq` |
| 매출 인식 | 충전된 유료 하트가 콘텐츠 소비 시 자연 인식 (`spent_heart_coin`) | 사용 시 `pay_for_contents`에 `spent_cash_amount` 인젝션(판매가) |
| 취소 시 회수 | `useHeart`로 하트 차감 (잔액 부족 시 가능한 만큼) | 발급된 쿠폰 삭제(`Coupon.delete`) |

> 상품권은 **콘텐츠형 상품** — 사용자가 정상 사용한 후에는 취소 불가. 내부 오류 시에만 자동 취소(L2/L3), 운영자 수동 취소는 별도(→ [02 결제·쿠폰 취소](02-payment-cancellation.md)).

---

## 4. 외부 파트너 — 쿠프마케팅

| 항목 | 내용 |
|------|------|
| 역할 | 카카오 선물하기 쿠폰의 인증·사용승인·취소 중계 + 월 정산 |
| 실무 담당 | 이정우 (쿠프마케팅) <!-- 연락처/채널 확인 필요 --> |
| 인증 파라미터 | `compCode` + `authKey` (환경변수, 환경별 분리 — ISS-055) |
| compCode | **dev `A911` / prod `X259`** (환경 분리 완료, ISS-055 2026-05-05) |
| API URL | prod `https://authapi.inumber.co.kr/AuthUse` / dev `http://test.authapi.inumber.co.kr:9999/AuthUse` |
| 정산 | **월단위, 익월 10일** · 수수료 **8.0%** (VAT 포함) · **사용분**(`status='used'`) 기준 |

> ⚠ compCode/authKey 는 운영 시크릿 — 노출 금지. 변경은 `/dev-infra`(EKS 시크릿·매니페스트) 경유.

---

## 5. 운영 도구 (AdminJS)

| 리소스(엔티티) | 용도 | 비고 |
|---------------|------|------|
| `CoopMarketingProduct` | 상품 등록·수정·비활성 | → [01 상품 등록·수정](01-product-registration.md) |
| `CoopMarketingCouponUsage` | 사용 이력 조회·**사용취소** | → [02 결제·쿠폰 취소](02-payment-cancellation.md) |
| `CoopMarketingApiLog` | 쿠프마케팅 API 호출 전문 로그(조회 전용) | 트러블슈팅용, append-only |
| `CouponPrefixRule` | 프리픽스 분류 규칙(`90`/`91` → coop_marketing) | 신규 제휴/프리픽스 추가 시 row 추가 |

> AdminJS 의 정확한 메뉴 라벨·버튼 명칭은 운영 어드민 화면 기준으로 확인 필요(본 가이드는 엔티티명 기준 기술). <!-- 캡처 첨부 예정 -->

---

## 6. 핵심 데이터 모델

| 테이블 | 역할 | 주요 컬럼 |
|--------|------|----------|
| `coupon_prefix_rule` | 프리픽스 → 쿠폰 종류 분류 | `prefix`, `coupon_type`, `is_active`, `requires_new_flow` |
| `coop_marketing_product` | 쿠프마케팅 상품코드 ↔ 헬로우봇 상품 매핑 | `product_code`(UNIQUE), `product_type`, `price`, `heart_quantity`, `fixed_menu_seq`, `coupon_spec_seq`, `is_active` |
| `coop_marketing_coupon_usage` | 쿠폰 1장 = 1행 사용 이력 | `user_seq`, `coupon_code`(user_seq+coupon_code UNIQUE), `status`(used/canceled), `brand_auth_code`, `heart_log_seq`, `issued_coupon_seq`, `canceled_at`, `recovered_at` |
| `coop_marketing_api_log` | API 호출 전문 | `process_type`(L0/L1/L2/L3/L1_COMPLETE), `coupon_code`, `request_data`, `response_data` |

> 실제 테이블명은 `coop_marketing_*` (엔티티 `CoopMarketingProduct` 등의 snake_case). 일부 설계 문서의 `coupc_marketing_*` 표기는 오기.

---

## 7. 쿠폰 처리 흐름 (요약)

```
쿠폰 등록 → 프리픽스 분류(90/91 → coop_marketing)
  → Redlock(coop:lock:{code}, 10s)
  → L0 조회(유효성·상품코드)  → L1 사용승인
  → usage UPSERT(status=used) → 상품 지급(하트 충전 | 쿠폰 발급)
  → 응답(issuedType: heart|skill)

[실패 보상] L1 타임아웃 → L3 망취소 / 지급 실패 → L2 취소 + usage=canceled
```

| 레벨 | 의미 |
|------|------|
| **L0** | 쿠폰 유효성 조회 (상품코드 추출·기간·사용여부) |
| **L1** | 사용 승인 (쿠폰 소진) · `L1_COMPLETE` = 완료 기록 |
| **L2** | 사용취소 (운영자 수동 취소 시) |
| **L3** | 망취소 (L1 타임아웃 등 자동 보상) |

---

## 8. 용어집

| 용어 | 뜻 |
|------|----|
| 쿠프마케팅 | 카카오↔헬로우봇 쿠폰 인증·정산 중계사 |
| compCode / authKey | 쿠프마케팅 API 인증값 (환경별 분리) |
| 프리픽스 | 쿠폰번호 앞자리(`90`/`91`)로 카카오 쿠폰 판별 |
| CouponSpec | 쿠폰 "스펙"(발급 틀). 스킬 교환권 등록 시 100% 할인 spec 자동 생성 |
| CouponCondition | CouponSpec의 적용 조건(`skillSeqs` 등). 대상 스킬 한정 |
| fixedMenuSeq | 스킬(메뉴) 식별자. 스킬 교환권의 대상 스킬 |
| 사용취소(L2) | 운영자가 사용 완료 쿠폰을 수동 취소 |
| 망취소(L3) | 통신 오류 시 자동 사용 원복 |
| 회수 | 취소 시 이미 지급한 상품(하트/쿠폰)을 되돌림 (`recovered_at`로 중복 방지) |
| 정합화 | DB 상태와 실제 지급/취소 상태의 불일치를 SQL로 보정 |

---

## 9. 문서 인덱스

| # | 문서 | 내용 |
|---|------|------|
| 0 | **README** (이 문서) | 개요·구조·용어·인덱스 |
| 1 | [상품 등록·수정 가이드](01-product-registration.md) | 하트/스킬 상품 등록·수정·비활성 + 수정 시 주의 |
| 2 | [결제·쿠폰 취소 가이드](02-payment-cancellation.md) | 사용취소·망취소·회수·정합화 |
| 3 | 상품 운영 가이드 *(예정)* | 정산·일상 운영·모니터링·상품별 특이사항 |
| 4 | CS·트러블슈팅 가이드 *(예정)* | CS 처리 절차·조회 쿼리·에스컬레이션 (에러 메시지별 조치는 → 06 FAQ) |
| 5 | 정합성 점검·인시던트 런북 *(예정)* | 진단 SQL·Do/Don't·인시던트 사례 |
| 6 | [운영 FAQ](06-operations-faq.md) | **앱 에러 메시지별 조치**(CO012·CM001~CM010) + 운영 Q&A |

---

## 10. 이슈 레지스트리 매핑

> 상세: [coop-integration/issues.md](../../../projects/20260324-coop-integration/issues.md)

| ISS | 요지 | 상태 |
|-----|------|------|
| ISS-055 | 쿠프마케팅 compCode 환경 분리 누락(dev/prod 동일) | ✅ 해결 (2026-05-05) |
| ISS-056 | 운영 사용취소 L2 `8005` 미동기 + 회수 가드 부재 → 하트 중복 회수 | ✅ 해결 (2026-05-20 패치, 5/21 배포) — `recovered_at` 추가 |
| ISS-071 | 스킬 교환권 상품 CRUD ↔ CouponSpec/CouponCondition 정합성(결함 9건) | 🔴 처리 방향 결정 중 ([TODO-026](../../../todos/TODO-026-skill-coupon-product-sync-hotfix.md)) |

---

## 11. 구현 현황 (운영자 주의)

| 기능 | 상태 | 대안 |
|------|------|------|
| 상품 CRUD (AdminJS) | ✅ 구현 | — |
| 사용 이력 조회·사용취소 | ✅ 구현 (ISS-056 반영) | — |
| **정산 통계 페이지** | ❌ 미구현 | 수동 집계(SQL/BigQuery) — [03 운영 가이드](03-operations.md) 예정 |
| **CS 조회 쿼리(UI)** | ❌ 미구현 | 직접 SQL — [04 CS 가이드](04-cs-troubleshooting.md) 예정 |
| **Slack 운영 알림** | ❌ 미정 | [TODO-016](../../../todos/TODO-016-kakao-gift-slack-notification.md) |
| 스킬 교환권 CRUD 정합성 가드 | ⚠ 일부 미해결(ISS-071) | 수정 시 주의 SOP — [01](01-product-registration.md) |

---

## 변경 이력

| 날짜 | 작성자 | 내용 |
|------|--------|------|
| 2026-06-02 | 코디네이터 | 초안 — 개요/구조/용어/인덱스. coop-integration architecture·api-spec 및 서버 엔티티 기준 식별자 확정 |
