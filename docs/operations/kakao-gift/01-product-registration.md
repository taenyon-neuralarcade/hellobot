# 01. 상품 등록·수정 가이드 — 하트 충전권 / 스킬 교환권

> **상태**: 🟡 초안 (2026-06-02) · **대상**: 내부 운영팀 · **도구**: AdminJS `CoopMarketingProduct`
> 선행 문서: [README — 개요·구조·용어](README.md)

카카오 선물하기 상품을 AdminJS 에서 등록·수정·비활성하는 절차와 **수정 시 반드시 알아야 할 주의사항**(ISS-071)을 다룹니다.

---

## 1. 등록 전 준비물

| 항목 | 출처 | 비고 |
|------|------|------|
| 쿠프마케팅 상품코드(`product_code`) | 쿠프마케팅(이정우) | 예: `KH00001`, `HEART_5000`, `SKILL_VOUCHER_001`. **UNIQUE** |
| 상품명(`product_name`) | 기획 | 사용자 노출명 |
| 가격(`price`, 원) | 기획·계약 | 정산·매출 인식 기준가 |
| 쿠폰번호 프리픽스 | 고정 `90`/`91` | 이미 `coupon_prefix_rule`에 등록됨 — 신규 프리픽스가 아니면 작업 불필요 |
| (하트) 충전 수량(`heart_quantity`) | 기획 | heart 전용 |
| (스킬) 대상 스킬 `fixed_menu_seq` | 기획·스튜디오 | skill 전용. **등록 후 변경 위험 — §4 참조** |

> 새 프리픽스(예: 다른 제휴사)가 추가되는 경우에만 `CouponPrefixRule`에 row 추가(`prefix`, `coupon_type`, `is_active=true`, `requires_new_flow=true`). 카카오(90/91)는 이미 등록되어 있어 상품 등록 시 손댈 필요 없음.

---

## 2. 하트 충전권 등록

1. AdminJS → `CoopMarketingProduct` → **New**
2. 입력
   - `product_code` = 쿠프마케팅 상품코드
   - `product_name` = 상품명
   - `product_type` = **`heart`**
   - `price` = 판매가(원)
   - `heart_quantity` = 충전 하트 수량
   - `is_active` = `true`
   - `fixed_menu_seq` / `coupon_spec_seq` = **비움**(하트는 사용 안 함)
3. 저장 → 부수 동작 없음(쿠폰 스펙 미생성).
4. [§5 등록 후 검증](#5-등록-후-검증) 수행.

---

## 3. 스킬 교환권 등록

1. AdminJS → `CoopMarketingProduct` → **New**
2. 입력
   - `product_code` = 쿠프마케팅 상품코드
   - `product_name` = 상품명 (자동 생성되는 쿠폰 스펙 이름의 기반이 됨)
   - `product_type` = **`skill`**
   - `price` = 판매가(원)
   - `fixed_menu_seq` = **대상 스킬 식별자** (필수 — 누락 시 §4-G 좀비 상품)
   - `is_active` = `true`
   - `heart_quantity` = 비움
3. 저장 → **부수 동작(자동)**:
   - `CouponSpec` 생성 (100% 할인)
   - `CouponCondition` 생성 (`skillSeqs = [fixed_menu_seq]`)
   - 생성된 spec 의 seq 가 상품의 `coupon_spec_seq` 에 연결
4. [§5 등록 후 검증](#5-등록-후-검증) 수행 — 특히 `coupon_spec_seq` 가 채워졌는지 확인.

> 스킬 교환권은 "사용자가 쿠폰 등록 → 100% 할인 쿠폰 발급 → 기존 스킬 구매 플로우로 0하트 구매" 구조. 쿠폰 스펙은 운영자가 직접 만들지 않고 **상품 등록이 자동 생성**합니다. CouponSpec/CouponCondition 을 직접 수정하지 마세요(§4-I).

---

## 4. ⚠ 수정·삭제 시 주의 (ISS-071)

스킬 교환권은 상품과 쿠폰 스펙이 자동 연동되지만, **현재 일부 케이스에서 동기화가 깨지는 결함이 미해결**입니다([TODO-026](../../../todos/TODO-026-skill-coupon-product-sync-hotfix.md)). 가드가 들어오기 전까지는 아래를 **운영 수칙으로 회피**하세요.

| # | 위험한 작업 | 무슨 일이 생기나 | 운영 수칙 |
|---|-----------|----------------|----------|
| A | 출시된 스킬 교환권의 `fixed_menu_seq` 를 다른 스킬로 변경 | `CouponCondition.skillSeqs` 가 즉시 갱신 → **이미 발급된 쿠폰까지 소급 적용**되어 엉뚱한 스킬에 쓰임 | **변경 금지.** 스킬을 바꾸려면 기존 상품 비활성 + **신규 상품 등록** |
| B | 같은 스킬로 상품을 또 등록 | 옛 CouponSpec 정리 안 됨 → 활성 spec 2개 중복 → 중복 발급·사용 가능 | 동일 스킬 중복 등록 금지. 재출시는 기존 상품 재활성 |
| C | 상품 삭제 | 연결된 CouponSpec 이 고아(orphan)로 잔존 | 삭제 대신 **`is_active=false`(비활성)** 사용 |
| D | `heart` → `skill` 로 타입 변경 | 가드 스킵 → CouponSpec 미생성 → 사용 시 `CM009`(쿠폰 정보 없음) | 타입 전환 금지. 신규 상품으로 등록 |
| E | `skill` → `heart` 로 타입 변경 | CouponSpec/CouponCondition 고아 잔존 | 타입 전환 금지 |
| F | 스킬 교환권의 `product_name` 변경 | CouponSpec 이름 UNIQUE 충돌 시 silent 처리 → **상품명만 바뀌고 쿠폰 스펙은 그대로** | 이름 변경 후 §5 로 spec 동기 여부 확인. 불일치 시 개발 문의 |
| G | 스킬 교환권 등록 시 `fixed_menu_seq` 누락 | silent skip → `coupon_spec_seq=null` 좀비 상품(사용 시 오류) | 등록 직후 `coupon_spec_seq` 채워졌는지 §5 확인 |
| H | 등록·수정이 부분 실패 | 상품은 저장됐는데 CouponSpec 생성/수정 실패 → 부분 상태 커밋(운영자 인지 어려움) | 저장 후 항상 §5 검증. 이상 시 개발 문의 |
| I | CouponSpec/CouponCondition 을 어드민에서 직접 수정 | 상품으로 역동기 안 됨 → 양방향 불일치 | **직접 수정 금지** — 상품을 통해서만 |

> 요약 수칙: **출시된 스킬 교환권은 "수정"하지 말고 "비활성 + 신규 등록"으로 갈아끼운다.** 가능한 변경은 `is_active`, `price`(매출 영향 검토), `product_name`(스펙 동기 확인) 정도로 최소화.

---

## 5. 등록 후 검증

저장 직후 다음을 확인합니다(특히 스킬 교환권).

**A. AdminJS 화면 확인**
- 상품이 목록에 보이고 `is_active=true`
- (스킬) `coupon_spec_seq` 값이 채워져 있음 (비어 있으면 §4-G/H 결함)

**B. 정합성 진단 SQL** (스킬 교환권 등록·수정 시 권장)
```sql
-- 1) skill 인데 coupon_spec_seq 가 비어있는 좀비 상품
SELECT seq, product_code, product_name
FROM coop_marketing_product
WHERE product_type = 'skill' AND coupon_spec_seq IS NULL;

-- 2) 같은 스킬에 활성 CouponSpec 이 2개 이상 (중복)
SELECT cc.skill_seqs, COUNT(*) AS cnt
FROM coupon_condition cc
JOIN coupon_spec cs ON cc.fk_coupon_spec = cs.seq
WHERE cs.issue_end_date IS NULL
GROUP BY cc.skill_seqs
HAVING COUNT(*) > 1;
```
> 위 쿼리의 컬럼명(`fk_coupon_spec`, `skill_seqs`, `issue_end_date`)은 스키마 확인 후 확정 필요. 이상 발견 시 자체 수정하지 말고 개발(`/dev-server`)에 정합화 요청.

**C. 사용자 플로우 스모크 테스트** (가능 시 dev/스테이징)
- 테스트 쿠폰 등록 → 하트 충전 또는 스킬 0하트 구매까지 확인

---

## 6. 비활성 / 종료

- 판매 종료: `is_active = false` 로 설정(삭제 금지 — §4-C).
- 비활성해도 **이미 발급된 쿠폰/충전된 하트는 회수되지 않음** (정상). 신규 등록만 차단.
- 스킬 교환권을 완전 종료할 때 CouponSpec 도 닫아야 하면 개발에 soft delete(`issueEndDate=NOW`) 요청.

---

## 7. 2차 출시 대량 등록 (TODO-027)

[TODO-027](../../../todos/TODO-027-kakao-skill-coupon-2nd-launch-spec.md) 스킬 교환권 추가 20종(6/8 10종 · 6/15 10종) 등록 시:

1. 상품코드·스킬(`fixed_menu_seq`)·가격 매핑표를 쿠프마케팅·기획과 사전 확정
2. **건별로 등록 후 즉시 §5 검증** (대량 등록 시 §4-G/H 부분 실패가 묻히기 쉬움)
3. 전체 등록 후 §5-B 진단 SQL 일괄 1회 실행으로 좀비·중복 점검
4. 출시 전 대상 스킬이 스토어에 노출/구매 가능한 상태인지 스튜디오 측과 교차 확인

---

## 변경 이력

| 날짜 | 작성자 | 내용 |
|------|--------|------|
| 2026-06-02 | 코디네이터 | 초안 — 등록 절차(하트/스킬)·수정 주의(ISS-071 A~I)·검증·대량 등록. SQL 컬럼명 일부 확인 필요 |
