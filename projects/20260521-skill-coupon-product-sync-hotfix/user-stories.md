# 사용자 스토리

> 본 핫픽스의 1차 사용자는 **운영자**(어드민 super admin)이고, 간접 영향을 받는 사용자는 **엔드유저**(쿠폰 보유자)와 **CS 팀**이다. 각 스토리는 INVEST + Acceptance Criteria (Given / When / Then) 형식으로 정리.

## 페르소나

| 페르소나 | 정의 | 본 핫픽스에서의 관심사 |
|---------|------|----------------------|
| **운영자 (Operator)** | AdminJS super admin. 카카오 선물하기 상품 등록·수정·삭제·재등록 권한 보유 | 어떤 동작을 해도 시스템이 "정의된 결과 상태"에 도달했음을 신뢰할 수 있어야 함 |
| **엔드유저 (End user)** | 카카오 선물하기에서 스킬 교환권을 받아 쿠폰을 사용하는 사람 | 발급받은 쿠폰의 적용 대상이 후속 운영자 액션으로 바뀌면 안 됨 |
| **CS 담당자** | 사용자 문의 대응 | 정합성 깨짐으로 인한 "다른 스킬에 적용된다" "두 개 받았다" 류 문의에 시달리지 않기 |

## 1순위 — P0 결함 직결 스토리 (반드시 처리)

### US-01: 발급된 쿠폰의 적용 대상 보호 (ISS-071 P0-A)

- **As an** 엔드유저
- **I want** 내가 발급받은 스킬 교환권 쿠폰의 적용 대상이 발급 시점 기준으로 고정되기를
- **So that** 운영자가 상품 정보를 수정해도 내 쿠폰이 다른 스킬에 적용되거나 사용 불가로 바뀌지 않는다.

**Acceptance Criteria**
- **G** 운영자가 A 스킬용 상품을 등록 → 엔드유저가 쿠폰 발급받음 (미사용 상태)
- **W** 운영자가 상품의 `fixedMenuSeq` 를 A 에서 B 로 수정
- **T** 엔드유저의 미사용 쿠폰은 여전히 **A 스킬** 에만 적용 가능해야 한다 (B 에는 적용 불가).
- **AND** 운영자가 의도한 "다음부터 B 로 발급" 동작은 별도로 정상 작동 (이후 신규 발급은 B 적용).

---

### US-02: 동일 스킬 재등록 시 단일 활성 spec 보장 (ISS-071 P0-B)

- **As an** 운영자
- **I want** 동일 스킬에 새 상품을 재등록할 때 옛 상품의 쿠폰스펙이 자동으로 비활성화(또는 정리)되기를
- **So that** 한 스킬에 활성 CouponSpec 이 항상 단 1 개만 매칭되어 사용자가 중복 쿠폰을 받지 않는다.

**Acceptance Criteria**
- **G** A 스킬용 상품 #1 이 활성 + 매칭 CouponSpec #1
- **W** 운영자가 상품 #1 을 비활성화(또는 삭제)하고 동일 A 스킬을 대상으로 상품 #2 등록
- **T** 동일 A 스킬에 매칭되는 **활성** CouponSpec 은 #2 하나만 존재해야 한다.
- **AND** 이미 발급된 #1 의 쿠폰은 사용 가능 상태 유지 (US-01 과 일관).
- **AND** 동일 상품명이라 `CouponSpec.name` UNIQUE 충돌이 잠재하더라도 등록은 성공해야 한다(이름 정책으로 회피).

---

## 2순위 — P1 결함 스토리

### US-03: 상품 삭제 시 신규 발급 차단 + 발급분 보존 (ISS-071 P1-C)

- **As an** 운영자
- **I want** 상품을 삭제할 때 연동 CouponSpec 도 함께 신규 발급 가능 상태에서 제외되기를
- **So that** orphan CouponSpec 이 남지 않고, 이미 발급된 쿠폰은 사용자 보호 차원에서 사용 가능한 채로 유지된다.

**Acceptance Criteria**
- **G** 활성 skill 상품 + 매칭 CouponSpec
- **W** 운영자가 상품을 삭제
- **T** 연동 CouponSpec 은 `issueEndDate = now()` 로 동결되어 신규 발급 차단. 이미 발급된 쿠폰은 만료 전까지 사용 가능.
- **AND** orphan 으로 남은 CouponSpec 이 정합성 진단 SQL 에서 잡히지 않는다.

> **결정 필요(사용자 협의)**: 삭제 동작을 "soft (issueEndDate 만)" 로 둘지, "hard (CouponSpec/Condition 도 삭제)" 로 둘지. 발급분 보존이 표준이라면 soft 권장.

---

### US-04: 상품 유형(productType) 전환 처리 (ISS-071 P1-D, P1-E)

- **As an** 운영자
- **I want** 상품 유형을 heart↔skill 로 바꿀 때, 그에 맞춰 CouponSpec 연결이 자동 정리되기를
- **So that** 좀비 상품(`couponSpecSeq=null` skill) 이나 orphan(heart 가 된 옛 skill spec) 이 생기지 않는다.

**Acceptance Criteria — heart → skill**
- **G** heart 상품 (`couponSpecSeq=null`)
- **W** 운영자가 productType 을 skill 로 변경 + `fixedMenuSeq` 입력
- **T** 새 CouponSpec + CouponCondition 자동 생성 + 상품의 couponSpecSeq 업데이트. 이후 정상 사용 가능.
- **OR** 이행 자체를 막아도 됨 (validation error 로 reject). **사용자 결정 필요**.

**Acceptance Criteria — skill → heart**
- **G** skill 상품 + 활성 CouponSpec
- **W** 운영자가 productType 을 heart 로 변경
- **T** 연동 CouponSpec 은 `issueEndDate = now()` 로 동결. 발급된 쿠폰은 만료까지 사용 가능. 상품의 couponSpecSeq 는 그대로 유지(이력 추적용) 또는 null 로 clear (정책 결정 필요).

> **결정 필요(사용자 협의)**: productType 변경 자체를 운영적으로 허용할지. 허용 안 한다면 validation error 만 추가하면 됨.

---

### US-05: 상품명 변경 시 UNIQUE 충돌 가시화 (ISS-071 P1-F)

- **As an** 운영자
- **I want** 상품명을 바꿨는데 `CouponSpec.name` UNIQUE 충돌이 발생하면 그 사실을 어드민 UI 에서 즉시 알기를
- **So that** 상품은 수정됐는데 쿠폰스펙은 옛 이름 그대로 남는 부분 정합성 깨짐을 만들지 않는다.

**Acceptance Criteria**
- **G** 다른 상품의 CouponSpec 이름이 `${newProductName} 이용권` 과 동일하게 이미 존재
- **W** 운영자가 상품명을 newProductName 으로 변경
- **T** 수정이 atomic 하게 reject 되거나(error notice + 상품 변경도 롤백), **또는** 이름 정책으로 자동 회피되어 성공 (예: suffix 로 productCode 부착)
- **AND** "수정됐다"라는 success notice 가 잘못 떠서 운영자가 후속 액션을 잘못 취하는 일이 없어야 한다.

---

### US-06: 필수값(fixedMenuSeq) 누락 좀비 차단 (ISS-071 P1-G)

- **As an** 운영자
- **I want** skill 상품을 등록·수정할 때 `fixedMenuSeq` 가 비어 있으면 그 자리에서 에러를 받기를
- **So that** `couponSpecSeq=null` 인 사용 불가 상품(좀비) 이 운영 DB 에 만들어지지 않는다.

**Acceptance Criteria**
- **G** productType=skill 등록 또는 수정 화면
- **W** 운영자가 `fixedMenuSeq` 비운 채 저장 시도
- **T** validation error 로 reject. CoopMarketingProduct row 가 생성/수정되지 않음.
- **AND** silent skip 으로 인한 좀비 데이터 발생 없음.

---

### US-07: 부분 실패 가시성 (ISS-071 P1-H)

- **As an** 운영자
- **I want** 상품 등록/수정의 한 부분만 성공하고 다른 부분이 실패한 상태가 화면에 success 처럼 보이지 않기를
- **So that** 운영자가 후속 액션(공지·홍보)을 잘못 취하지 않는다.

**Acceptance Criteria**
- **G** 상품 INSERT/UPDATE 는 commit 되었지만 CouponSpec 동기화가 실패한 시점
- **W** AdminJS 응답 렌더링
- **T** 상품 데이터까지 동일 트랜잭션으로 롤백되거나, 명백한 **error notice** (success 와 구분되는 빨간 배너) 로 표시되어야 한다.
- **AND** 운영자가 "성공했네"라고 착각할 여지가 없어야 한다.

---

## 3순위 — 진단·운영 스토리 (코드 수정 없이 사전 실행 가능)

### US-08: 운영 DB 정합성 진단

- **As a** 서버 개발자(코디네이터 위임 받은 /dev-server)
- **I want** 현재 운영 DB 의 정합성 위반 데이터를 식별할 수 있는 SQL 3 종을 갖기를
- **So that** 1차 출시 직전·직후 사전 점검 + 핫픽스 배포 후 회복 검증 모두 가능하다.

**Acceptance Criteria**
- **G** 운영 DB 접근 가능 상태 (PR #2421 배포 시 사용한 SSH 터널 동일 패턴)
- **W** 진단 SQL 3 종 실행
  1. 동일 `skillSeqs` 가 활성 CouponSpec 2 개 이상에 매칭되는 행
  2. `productType=skill && couponSpecSeq IS NULL` 인 상품
  3. `coop_marketing_product` 에서 참조되지 않는 orphan CouponSpec (이름 패턴 `% 이용권` + 단일 skillSeqs 매칭 등)
- **T** 각 SQL 의 결과 row 수와 sample row 가 status.md (또는 점검 노트) 에 기록된다.
- **AND** 결과 row > 0 인 항목은 정합화 액션이 필요한 데이터로 등록되어 별 트랙(또는 US-09)에서 처리.

---

### US-09: 정합화 (기존 위반 데이터 보정)

- **As an** 운영자 + 서버 개발자
- **I want** US-08 에서 발견된 위반 데이터를 운영 영향 최소화하면서 보정할 수 있기를
- **So that** 핫픽스 배포 전후로 운영 상태가 깨끗하게 유지된다.

**Acceptance Criteria**
- **G** US-08 결과로 위반 row N 개 존재
- **W** 각 케이스별 보정 절차 수립(일회성 SQL 또는 어드민 액션) → 사용자 승인 후 적용
- **T** 보정 후 US-08 진단 재실행 결과 = 0 row.
- **AND** 보정 과정에서 발급된 쿠폰의 사용 가능 여부가 의도와 다르게 변하지 않는다 (US-01 보존).

> **결정 필요(사용자 협의)**: 일회성 SQL 직접 적용 vs 어드민 액션 정리 절차 vs 보정 없이 운영 절차로만 회피.

---

## Non-User-Stories (의도적 제외)

- **CouponSpec/CouponCondition 어드민 직접 수정 차단** — 본 핫픽스 범위 외 (ISS-071 P2-I, 별건)
- **변경 이력 UI** — 본 핫픽스 범위 외
- **권한 분리(누가 어떤 상품을 수정할 수 있는지)** — 본 핫픽스 범위 외
- **하트 충전권 로직** — CouponSpec 무관

## 사용자 결정 필요 사항 요약

| ID | 결정 사항 | 영향 |
|----|----------|------|
| D-1 | US-03: 상품 삭제 시 cleanup 정책 — soft(issueEndDate 만) vs hard(spec/condition 도 삭제) | 발급분 보존 정책과 직결 |
| D-2 | US-04: productType heart↔skill 전환 자체를 운영적으로 허용할지 | 허용 안 하면 단순 validation error 만 추가 |
| D-3 | US-05: CouponSpec.name UNIQUE 충돌 회피 전략 — atomic reject vs suffix(productCode) 정책 | 운영자 UX 와 운영 데이터 일관성 |
| D-4 | US-09: 정합화 방법 — 일회성 SQL vs 어드민 액션 vs 운영 절차 회피 | 핫픽스 범위와 배포 사이즈 |
| D-5 | 핫픽스 스코프 — 최소(P0 A·B 만) vs 풀(P0+P1 전부) | 일정 / 배포 사이즈 |
