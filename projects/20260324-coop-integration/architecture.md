# 기술 설계 — 카카오 선물하기 상품권 연동

## 1. 개요

쿠프마케팅 API를 통해 카카오 선물하기 상품권을 헬로우봇에서 사용할 수 있게 합니다. 기존 쿠폰 화면의 입력란을 재사용합니다.

**두 가지 상품 유형**:
- **하트 충전권**: 상품권 등록 → 즉시 하트 충전
- **스킬 교환권**: 상품권 등록 → 100% 할인 쿠폰 발급 → 기존 스킬 구매 플로우로 0하트 구매

**설계 원칙** (2026-04-19 ISS-011 해결로 확정):
- **서버 단일 진입점 (쿠폰 코드 등록 경로 한정)** — 사용자가 쿠폰 코드 문자열을 입력해 등록하는 플로우는 `POST /api/coupon/register` 하나로 통일. 서버가 DB 기반 `coupon_prefix_rule` 규칙으로 쿠폰 종류를 분류.
- **1단계 원샷 처리** — 쿠프마케팅 쿠폰도 check+use를 서버가 한 번의 요청으로 처리 (사용자 확인 팝업 없음).
- **폴리모픽 성공 응답** — `resultType: "ISSUED"` + `issuedType: "coupon" | "heart" | "skill"` 구분.
- **구버전 앱 호환** — 기존 `POST /api/coupon`의 **code 기반 경로**에 프리픽스 가드 추가. 90/91 입력 시 HTTP 406 + `CO012` 에러로 토스트 안내.
- **확장성** — 신규 프리픽스/제휴사 추가 시 `coupon_prefix_rule` 테이블 row 추가만으로 대응 (앱 업데이트 불필요).

### 기존 `POST /api/coupon`의 이중 경로 이해 (중요)

`POST /api/coupon`은 역사적으로 두 가지 경로를 지원합니다 ([controllers/coupon.ts:34-68](../../hellobot-server/src/controllers/coupon.ts)):

| 경로 | 요청 파라미터 | 용도 | 본 설계 영향 |
|------|-------------|------|-----------|
| **code 기반** | `{ code }` | 사용자가 쿠폰 코드 문자열을 직접 입력하여 등록 (SINGLE_CODE/MULTI_CODE 타입) | **신버전 클라이언트는 `/api/coupon/register`로 이전**. 기존 `/api/coupon`의 code 경로는 **구버전 앱 호환용으로만 유지** + 프리픽스 가드 추가 (가드 발동 조건 §5-4 참조) |
| **couponSpecSeq 기반** | `{ couponSpecSeq }` | 배너/프로모션 "쿠폰 받기" 버튼 등에서 CouponSpec을 지정해 클레임 (DOWNLOAD 타입) | **변경 없음** — 신/구 모든 클라이언트가 계속 `/api/coupon` 호출. 가드 대상 아님 |

**결과**:
- 신버전 클라이언트도 `POST /api/coupon`을 **`couponSpecSeq` 경로로는 계속 호출**함 (배너 클레임 등)
- 신버전 클라이언트는 `POST /api/coupon`을 **`code` 경로로는 호출하지 않음** (모두 `/register`로 이전)
- 가드는 `code`가 유효한 비어있지 않은 문자열인 경우에만 발동 (아래 §5-4 참조)

---

## 2. 시스템 데이터 흐름

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────┐
│  카카오       │     │  쿠프마케팅    │     │  헬로우봇 서버     │
│  선물하기     │────▶│  (인증 중계)   │◀───▶│  (상품제공업체)    │
└──────────────┘     └──────────────┘     └────────┬─────────┘
                                                    │
                                          ┌─────────┼─────────┐
                                          │         │         │
                                       ┌──▼──┐  ┌──▼──┐  ┌──▼──┐
                                       │ Web │  │ iOS │  │ AOS │
                                       └─────┘  └─────┘  └─────┘
```

### 전체 처리 시퀀스 — 신버전 클라이언트 (coop 쿠폰)

```
클라이언트                     헬로우봇 서버                    쿠프마케팅 API
    │                             │                                │
    │  POST /api/coupon/register  │                                │
    │ { code }                    │                                │
    │───────────────────────────▶│                                │
    │                             │  prefix 분류                    │
    │                             │  (coupon_prefix_rule 조회)      │
    │                             │  └─ couponType = coop_marketing │
    │                             │                                │
    │                             │  Redlock 획득                    │
    │                             │  L0 조회 (쿠폰 유효성)            │
    │                             │──────────────────────────────▶ │
    │                             │◀────────────────────────────── │
    │                             │  상품 매핑 (ProductCode → 상품)   │
    │                             │                                │
    │                             │  L1 사용 승인                    │
    │                             │──────────────────────────────▶ │
    │                             │◀────────────────────────────── │
    │                             │                                │
    │                             │  usage UPSERT (status: used)    │
    │                             │  [heart] HeartService.charge()  │
    │                             │  [skill] CouponService.issue()  │
    │                             │  Redlock 해제                    │
    │                             │                                │
    │  성공 응답 (HTTP 2xx)         │                                │
    │ { resultType: "ISSUED",     │                                │
    │   issuedType: "heart"|"skill",                               │
    │   productName,              │                                │
    │   heartQuantity 또는         │                                │
    │   skillName/fixedMenuSeq/chatbotSeq/issuedCouponSeq }         │
    │◀───────────────────────────│                                │
    │                             │                                │
    │  [실패 시 자동 복구]           │                                │
    │                             │  L2 취소 또는 L3 망취소           │
    │                             │──────────────────────────────▶ │
    │  에러 응답 (HTTP 4xx/5xx)     │                                │
    │ { error: { code, message } }│                                │
    │◀───────────────────────────│                                │
```

### 전체 처리 시퀀스 — 신버전 클라이언트 (일반 쿠폰)

```
클라이언트                     헬로우봇 서버
    │                             │
    │  POST /api/coupon/register  │
    │ { code }                    │
    │───────────────────────────▶│
    │                             │  prefix 분류
    │                             │  (매칭 없음)
    │                             │
    │                             │  CouponService.issueCoupon(code)
    │                             │  (기존 /api/coupon 로직 재사용)
    │                             │
    │  성공 응답 (HTTP 2xx)         │
    │ { resultType: "ISSUED",     │
    │   issuedType: "coupon",     │
    │   coupon: CouponDto }       │
    │◀───────────────────────────│
```

### 전체 처리 시퀀스 — 구버전 앱 (coop 쿠폰 90/91 입력)

```
구버전 앱                       헬로우봇 서버
    │                             │
    │  POST /api/coupon           │  (신규 API 모름 → 기존 API 호출)
    │ { code: "91..." }           │
    │───────────────────────────▶│
    │                             │  진입 가드:
    │                             │  coupon_prefix_rule 조회
    │                             │  └─ requiresNewFlow = true 매칭
    │                             │
    │                             │  throw HttpError(
    │                             │    406,
    │                             │    CO012
    │                             │  )
    │                             │
    │  에러 응답 (HTTP 406)         │
    │ { error: {                  │
    │   code: "CO012",
    │   message: "앱을 최신 버전으로 업데이트 해주세요"
    │ }}                          │
    │◀───────────────────────────│
    │                             │
    │  기존 에러 토스트 로직이       │
    │  message를 그대로 표시        │
    │  → 사용자: "앱을 최신 버전으로 │
    │            업데이트 해주세요"  │
```

---

## 3. API 계약

### 현행 엔드포인트 (신규 설계)

| Method | Path | 설명 | 인증 |
|--------|------|------|------|
| POST | `/api/coupon/register` | **[NEW]** 쿠폰 통합 등록 — 일반/하트/스킬 모두 처리 | @Authorized (JWT) |
| POST | `/api/coupon` | (기존) 쿠폰 발급 — 프리픽스 가드 추가 (구버전 앱 대응) | @Authorized (JWT) |
| GET | `/api/coupon` | (기존) 쿠폰 리스트 조회 — `CouponDto`에 `fixedMenuSeq` optional 필드 포함 | @Authorized (JWT) |

### Deprecated 엔드포인트 (Phase 1 유지, Phase 2 제거)

| Method | Path | 설명 |
|--------|------|------|
| POST | `/api/coop/check` | ~~쿠폰 유효성 확인~~ — 신규 `POST /api/coupon/register`로 통합 |
| POST | `/api/coop/use` | ~~쿠폰 사용~~ — 신규 `POST /api/coupon/register`로 통합 |

> 상세 스펙: **[api-spec.md](./api-spec.md)**
> 신규 API는 HTTP 표준 에러 포맷(`{ error: { code, message } }`)을 사용. 폴리모픽은 성공 응답에만 적용.

---

## 4. 데이터 모델

### 신규 테이블 (4개)

```
coupon_prefix_rule               (프리픽스 분류 규칙 — 신규)

coupc_marketing_product          (상품 정의)
  │ 1:N
  └── coupc_marketing_coupon_usage   (사용 이력)
  │ 1:N
  └── coupc_marketing_api_log        (API 호출 로그)
```

#### coupon_prefix_rule (프리픽스 분류 규칙)

쿠폰 코드 프리픽스로 쿠폰 종류를 판별하는 동적 규칙 테이블. 운영 중 AdminJS에서 추가/비활성 가능 → 신규 프리픽스/제휴사 대응 시 앱 업데이트 불필요.

| 필드 | 타입 | 설명 |
|------|------|------|
| seq | SERIAL PK | 고유 식별자 |
| prefix | VARCHAR(20) | 쿠폰 코드 프리픽스 (예: `"90"`, `"91"`) |
| coupon_type | VARCHAR(50) | 쿠폰 타입 식별자 (예: `"coop_marketing"`) — 처리 핸들러 라우팅 키 |
| is_active | BOOLEAN default true | 활성 여부 (false면 매칭 무시) |
| requires_new_flow | BOOLEAN default true | 기존 `POST /api/coupon` 진입 시 가드 발동 여부 (true면 구버전 앱에 `CO012` 반환) |
| created_at | TIMESTAMPTZ default now() | 생성 시각 |
| updated_at | TIMESTAMPTZ default now() | 수정 시각 |

**인덱스**: `IDX_coupon_prefix_rule_prefix` on `(prefix)` — 가드/분류 시 starts-with 매칭용

**시드 데이터** (마이그레이션에 포함):

| seq | prefix | coupon_type | is_active | requires_new_flow |
|-----|--------|------------|-----------|-------------------|
| 1 | 90 | coop_marketing | true | true |
| 2 | 91 | coop_marketing | true | true |

> 시드 INSERT는 `thingsflow` 스키마 prefix 포함 Raw SQL로 작성 (`hellobot-server/CLAUDE.md` Migration 규칙 준수).

**마이그레이션 이름**: `CreateCouponPrefixRule`

**조회 전략** (확정):
- **매 요청마다 DB 조회** — 테이블 row 수가 소수(~10개 이내 예상)이고, 인덱스된 PK + prefix 조회는 비용 무시 가능 수준.
- 복잡한 캐싱(인메모리/Redis+TTL/pub-sub 무효화) 도입 안 함. AdminJS에서 row 추가/수정 시 **즉시 반영**되는 이점 (운영 민첩성).
- 추후 부하가 문제되면 `typeorm-cache` 또는 단순 인메모리 캐시(TTL 60s) 도입 검토 — 현 시점에는 불필요.

#### coupc_marketing_product (상품 매핑)

쿠프마케팅 상품코드 ↔ 헬로우봇 내부 상품의 매핑.

| 필드 | 타입 | 설명 |
|------|------|------|
| seq | SERIAL PK | 고유 식별자 |
| product_code | VARCHAR(50) UNIQUE | 쿠프마케팅 상품코드 (예: KH00001) |
| product_name | VARCHAR(200) | 상품명 |
| product_type | VARCHAR(20) | `heart` / `skill` |
| price | INTEGER | 상품 금액(원) |
| heart_quantity | INTEGER? | 하트 충전 수량 (heart 전용) |
| fixed_menu_seq | INTEGER? | 스킬 식별자 (skill 전용) |
| coupon_spec_seq | INTEGER? | 100% 할인 쿠폰 스펙 FK (skill 전용) |
| is_active | BOOLEAN | 활성화 여부 |

#### coupc_marketing_coupon_usage (사용 이력)

사용자의 상품권 사용 현황. 쿠폰 1장 = 1행.

| 필드 | 타입 | 설명 |
|------|------|------|
| seq | SERIAL PK | 고유 식별자 |
| user_seq | INTEGER | 사용자 FK |
| coupon_code | VARCHAR(100) | 쿠폰번호 (user_seq + coupon_code UNIQUE) |
| coupc_product_seq | INTEGER | 상품 FK |
| product_type | VARCHAR(20) | `heart` / `skill` |
| status | VARCHAR(20) | `used` / `canceled` |
| brand_auth_code | VARCHAR(100) | 브랜드 승인번호 (취소 시 필요) |
| heart_log_seq | INTEGER? | 하트 충전 로그 FK (heart 전용) |
| issued_coupon_seq | INTEGER? | 발급된 쿠폰 FK (skill 전용) |

#### coupc_marketing_api_log (API 전문 로그)

트러블슈팅용. Append only.

| 필드 | 타입 | 설명 |
|------|------|------|
| seq | SERIAL PK | 고유 식별자 |
| process_type | VARCHAR(20) | `L0` / `L1` / `L2` / `L3` / `L1_COMPLETE` |
| coupon_code | VARCHAR(100) | 쿠폰번호 |
| request_data | JSONB | 요청 전문 |
| response_data | JSONB | 응답 전문 |

### 기존 테이블 연동

| 테이블 | 연동 방식 |
|--------|----------|
| `heart_log` | heart 충전 시 HeartService가 자동 생성 → `heart_log_seq`로 참조 |
| `coupon_spec` | skill 상품 등록 시 자동 생성 (100% 할인) → `coupon_spec_seq`로 참조 |
| `coupon` | skill 이용권 사용 시 CouponService가 발급 → `issued_coupon_seq`로 참조 |

---

## 5. 처리 로직

### 5-1. `POST /api/coupon/register` — 메인 진입점

```
1. 요청 수신: { code }
2. 프리픽스 분류:
   - CouponPrefixRule.find({ isActive: true }) (캐싱 조회)
   - code.startsWith(rule.prefix) 매칭
   ├─ 매칭 + couponType === "coop_marketing" → 5-2 coop 플로우
   ├─ 매칭 + 미지원 couponType → throw HttpError(406, CO012)
   └─ 매칭 없음 → 5-3 일반 쿠폰 플로우
```

### 5-2. Coop 원샷 처리 (check + use 통합)

```
1. Redlock 획득 (key: `coop:lock:${code}`, TTL 10s — 중복 사용 방지)
2. L0 조회 API 호출 (CoopMarketingService.checkCoupon 재사용)
   L0 응답 검증:
   - ResultCode ≠ "0000" → 에러 분기:
       - 8003 → CM002 (기간 만료)
       - 8005 → CM003 (이미 사용)
       - 8099 → CM010 (결제 취소)
       - 그 외 → CM001 (유효하지 않음)
   - UseYN = "Y" → CM003
   - 타임아웃/네트워크 오류 → CM006
3. ProductCode로 coupc_marketing_product 조회
   - 매핑 없음 또는 비활성 → CM004
4. L1 사용 승인 요청
   - L1 타임아웃 → L3 망취소 시도 → 에러 반환 (CM006)
   - L1 실패 → 에러 반환 (CM005)
5. L1 성공 → usage UPSERT (status: "used")
   - INSERT 또는 ON CONFLICT (user_seq, coupon_code) → UPDATE
   - usage를 상품 지급보다 먼저 기록 (누수 방지)
6. 상품 지급:
   - [heart] HeartService.chargeHeart(userSeq, heartQuantity, ChargeByGiftCoupon)
       - 실패 → L2 자동 취소 + usage UPDATE (status: "canceled") → CM007
   - [skill] CouponService.issueCoupon(userSeq, couponSpecSeq)
       - 실패 → L2 자동 취소 + usage UPDATE (status: "canceled") → CM008
7. usage에 heartLogSeq 또는 issuedCouponSeq 업데이트
8. Redlock 해제
9. 응답 반환:
   - [heart]
     {
       resultType: "ISSUED",
       issuedType: "heart",
       productName, heartQuantity
     }
   - [skill]
     {
       resultType: "ISSUED",
       issuedType: "skill",
       productName, skillName, fixedMenuSeq, chatbotSeq, issuedCouponSeq
     }
```

> **외부 API 호출은 트랜잭션 밖**: axios 호출은 비동기이므로 DB 트랜잭션 내에 포함하지 않음. Redlock + usage UPSERT UNIQUE로 동시성 방어.

> **DB 트랜잭션 경계 (ISS-001 설계 기준 유지)**: usage UPSERT와 상품 지급(heart_log / coupon)은 **단일 DB 트랜잭션이 아닌 두 단계 커밋**이다.
> 1. usage UPSERT (`status: "used"`) — 먼저 커밋하여 중복 사용 진입을 차단
> 2. 상품 지급 (HeartService.chargeHeart 또는 CouponService.issueCoupon) — 별도 트랜잭션. 실패 시 L2 취소 + usage `status: "canceled"`로 UPDATE (보상 패턴)
>
> 두 단계 사이에서 프로세스가 죽을 가능성이 있으나, 그 경우 쿠프마케팅 L1은 성공 + 서버 usage `used` 상태 + 상품 미지급으로 귀결됨. 복구는 Admin 수동 취소로 커버 (§5-6).

> **Redlock 해제 순서**: 상품 지급 실패로 L2 보상 수행 시에도 **Redlock은 보상 완료 후 해제**. 보상 중 다른 요청이 같은 code로 진입하여 재시도 중복을 방어.

### 5-3. 일반 쿠폰 플로우

```
1. CouponService.issueCoupon(requestContext, undefined, code)
   (기존 POST /api/coupon 로직 재사용 — createCoupon 핵심 로직)
2. 응답 반환:
   {
     resultType: "ISSUED",
     issuedType: "coupon",
     coupon: CouponDto,
     issuedCoupon?: IssuedCouponDto  // FeatureFlag: SkillPurchasePromotion 활성 시
   }
```

### 5-4. 기존 `POST /api/coupon` — 프리픽스 가드 (신규 추가)

```
1. 요청 수신: { couponSpecSeq?, code? }
2. 프리픽스 가드 (신규):
   조건: code가 "비어있지 않은 유효한 문자열" 이고,
         CouponPrefixRule.find({ isActive: true, requiresNewFlow: true }) 중
         code.startsWith(rule.prefix) 매칭되는 rule 존재
   → throw HttpError(NOT_ACCEPTABLE/406, CO012)
3. 가드 통과 → 기존 CouponService.issueCoupon(context, couponSpecSeq, code) 실행 (변경 없음)
```

**가드 발동 조건 세부 정의**:

| 요청 입력 | 가드 동작 |
|----------|----------|
| `{ couponSpecSeq: 123 }` (code 없음) | **가드 통과** — DOWNLOAD 타입 클레임 경로, 신/구 클라이언트 공용 |
| `{ couponSpecSeq: 123, code: "91..." }` | 가드 **발동** (code 기준 매칭) — 정상 사용에서 발생 안 하나 안전 장치 |
| `{ code: "91..." }` | 가드 **발동** → 406 |
| `{ code: "ABC123" }` (매칭 없음) | **가드 통과** → 기존 쿠폰 발급 로직 |
| `{ code: "" }` (빈 문자열) | **가드 통과** → 기존 로직에서 파라미터 검증 에러 처리 (현행 유지) |
| `{ }` (둘 다 없음) | **가드 통과** → 기존 로직에서 파라미터 검증 에러 처리 |

> 구버전 앱은 90/91 쿠폰을 입력 시 이 경로로 들어와 에러 토스트 수신.
> 신버전 앱은 **code 기반 등록 시 항상 `/api/coupon/register`로 진입**하므로 이 가드에 닿지 않음. 단, 배너 클레임 등 `couponSpecSeq` 기반 요청은 신버전도 계속 `/api/coupon` 호출 — 가드 통과하여 정상 동작.

### 5-5. 자동 복구 (Compensation)

| 실패 시점 | 복구 동작 | 결과 |
|----------|----------|------|
| L0 실패 | 별도 복구 없음 | 쿠폰 미소진, 사용자 재시도 가능 |
| L1 타임아웃 | L3 망취소 | 쿠폰 원복, 사용자 재시도 가능 |
| L1 성공 후 하트 충전 실패 | L2 취소 + usage canceled | 쿠프마케팅 승인 취소, 쿠폰 원복. 하트 미지급 상태이므로 회수 불필요. |
| L1 성공 후 쿠폰 발급 실패 | L2 취소 + usage canceled | 쿠프마케팅 승인 취소, 쿠폰 원복. 이용권 미발급 상태이므로 회수 불필요. |

> **누수 방지**: usage를 상품 지급보다 먼저 기록하여, 지급 실패 시에도 중복 사용 방지 상태가 유지됨.
> **재사용 지원**: usage INSERT를 UPSERT로 처리하여, 취소 후 재사용 시 기존 레코드를 갱신.

### 5-6. Admin 수동 취소

운영자가 Admin에서 사용 완료된 쿠폰을 취소하는 경우, 지급된 상품 회수를 함께 수행한다.

```
1. Admin 취소 버튼 클릭
2. Guard 메시지에 상품 정보 + 회수 가능 여부 표시
   - 하트: 충전 수량, 현재 잔여 하트 (부족 시 경고)
   - 스킬: 이용권 사용 여부 (사용 완료 시 경고)
3. 운영자 확인 → 취소 진행 (회수 불가 상태에서도 진행 가능)
4. 상품 회수:
   - 하트: useHeart(UseByGiftCouponRecovery)로 차감 + 회수 로그. 잔여 부족 시 남은 만큼만 차감
   - 스킬: 발급된 100% 할인 쿠폰 삭제 (Coupon.delete)
5. 쿠프마케팅 L2 취소 API 호출
6. usage status → "canceled", canceledAt 기록
```

---

## 6. 파트별 구현 포인트

### 서버

**Phase 1 (ISS-011/009 해결) 구현 대상**:
- `CouponPrefixRule` 엔티티 + 마이그레이션 + 시드 데이터
- `CO012` 에러코드 + i18n(ko/ja/en)
- `POST /api/coupon/register` 컨트롤러 + 서비스
- `POST /api/coupon` 진입 가드
- `/api/coop/check`, `/api/coop/use` Deprecated 주석 (Phase 2에서 삭제)
- AdminJS에 `CouponPrefixRule` 관리 페이지

**Phase 0 구현 완료**: Entity 3개(CoopMarketingProduct/Usage/ApiLog), Service, Controller, Admin (상품관리/사용이력/로그)
**잔여**: Admin 정산 통계 custom page

### 웹 (hellobot-web)

**Phase 1 수정 대상**:
- `app/coupon/components/couponCodeRegister.tsx` 프리픽스 분기 제거 (`COOP_PREFIXES`, `isCoopCouponCode` 삭제)
- 신규 hook `usePostCouponRegister` 도입, `usePostCoopCheck`/`usePostCoopUse` 호출 제거
- 기존 `usePostCoupon` (POST `/api/coupon`) 호출은 **배너 클레임 등 couponSpecSeq 경로에서는 유지** (신버전 클라이언트도 계속 사용)
- 응답 `resultType`/`issuedType` 기반 UI 분기
- 컴포넌트 삭제: `coopHeartConfirmPopup.tsx`, `coopSkillConfirmPopup.tsx` (1단계 플로우로 S2 불필요)
- 컴포넌트 유지: `coopHeartCompletePopup.tsx`, `coopSkillVoucherItem.tsx`
- 타입 정의 정리: `CoopCheckResponse`/`CoopUseResponse` 제거 또는 `CouponRegisterResponse`로 통합

**Phase 0 구현 완료**: 타입, API 훅, 팝업 3종, 이용권 카드, CouponCodeRegister 통합, 번역, Figma 디자인 반영
**잔여**: (없음 — "모바일 웹뷰 환경 검증" 항목은 2026-04-21 아키텍처 확정 결과 해당 없음으로 종결. 하단 "앱 WebView 임베딩 여부" 참조)

### 앱 WebView 임베딩 여부 (2026-04-21 확정)

**결론: 쿠폰 등록 화면은 어떤 플랫폼에서도 앱 WebView로 임베딩되지 않음.**

| 플랫폼 | 쿠폰 등록 화면 구현 | 진입 경로 |
|--------|----------------------|-----------|
| iOS 앱 | **네이티브** `Hellobot/Feature/Coupon/CouponList/CouponListViewController.swift` (ReactorKit) | 프로필 탭 내 네이티브 네비게이션 |
| Android 앱 | **네이티브** `app/src/main/java/com/thingsflow/hellobot/coupon/CouponListActivity.kt` (Jetpack Compose) | 프로필 탭 내 네이티브 Intent |
| 웹 브라우저 | **Next.js** `hellobot-web/app/coupon/page.tsx` | 스킬스토어 웹(`NEXT_PUBLIC_SKILLSTORE_URL`)에서 직접 라우팅. back/완료 시 `${SKILLSTORE_URL}/user`로 복귀 |

### 웹뷰 (hellobot-webview, hellobot-report-webview)

**영향 없음** (2026-04-19 확인):
- 두 웹뷰 리포 모두 쿠폰 등록 엔드포인트(`/api/coupon`, `/api/coop/*`) 호출 경로 없음
- `/coupon` 경로 자체가 없어 앱 WebView에 임베딩될 대상도 아님
- Phase 1에서 수정 대상 아님

**결과: 웹 클라이언트 변경이 앱 동작에 주는 영향은 없음. 반대도 마찬가지.** Coop Phase 1은 iOS/Android/웹 세 플랫폼이 각각 독립적으로 `/api/coupon/register`를 호출하는 구조.

### iOS / Android (네이티브)

클라이언트 개발 가이드: [client-guide.md](./client-guide.md)

#### 쿠폰 화면 수정 (Phase 1)

**삭제**:
- iOS `CouponListViewController.swift:156-161` 프리픽스 if문 + `checkCoopCoupon` 메서드
- Android `CouponListViewModel.kt:114-123` `isCoopCouponCode` 함수 + `coopCheck`/`coopUse` 메서드
- S2 확인 팝업 컴포넌트 (iOS: CoopHeartConfirm/SkillConfirmPopup, Android: CoopEvent.ShowHeartConfirm/ShowSkillConfirm + 팝업 다이얼로그)

**수정**:
- 신규 API 호출 `POST /api/coupon/register` (단일 엔드포인트)
- 힌트 텍스트: 기존 유지 ("쿠폰 코드를 입력해주세요")

#### 팝업 구현 (1종만 유지)

| 팝업 | 표시 조건 | 주요 데이터 | 사용자 액션 |
|------|----------|-----------|-----------|
| S3 하트 완료 | register → `heart` 성공 | productName, heartQuantity | "확인" → 프로필 탭 |

> S2 확인 팝업 2종(하트/스킬)은 1단계 플로우 전환으로 제거.
> 팝업 디자인: Figma 확정 디자인 참조 ([designs/designs.md](./designs/designs.md))

#### 스킬 이용권 처리 (S4)

register API → `issuedType: "skill"` 성공 시 (확인 팝업 없이 바로):
1. 토스트: "스킬 이용권이 등록되었어요" (2.5초)
2. 쿠폰 리스트 최상단에 **이용권 카드** 추가
3. 이용권 카드 구성: "이용권" 태그, "100%", 스킬명, 만료일, "스킬 보러가기 >"
4. 카드 탭 → 스킬 상세 페이지 (`fixedMenuSeq`로 이동)

#### 에러 처리 (S5)

- 모든 에러는 HTTP 4xx/5xx + 표준 포맷(`{ error: { code, message } }`) — 기존 에러 토스트 로직 재사용
- `CO012`(HTTP 406)는 신버전에는 도달하지 않음 (가드는 기존 `/api/coupon` 경로에만 존재)
- 토스트 스타일: 검정 반투명 배경, 하단 중앙, 2.5초 자동 사라짐

#### 중복 탭 방지 (필수)

- 등록 버튼: register API 호출 중 **`disabled` + 회색 톤 표시**(기존 비활성 색상 토큰 `#C6C8CC` 재사용). 스피너/인디케이터/GIF/오버레이 **금지** — ISS-042 규범 (2026-04-22 확정, 상세는 design-spec.md §공통 컴포넌트 — 등록 버튼 / client-guide.md "중복 탭 방지" 참조).
- register API는 쿠프마케팅 외부 API(L0+L1)를 내부 호출하므로 응답이 느릴 수 있음 (최대 15초). 중복 호출 방지 필수.

#### 카카오 딥링크

- 카카오 선물하기에서 쿠폰 화면으로 직접 랜딩하는 딥링크 처리
- **딥링크 URL 스킴은 추후 확정** (client-guide.md 참조)

#### 페이지 이동

| 이동 | 방법 |
|------|------|
| 프로필 탭 | S3 완료 후 이동 (프로필 탭에서 하트 확인 가능) |
| 스킬 상세 페이지 | `fixedMenuSeq`로 기존 스킬 상세 이동 (쿠폰 적용 → 0하트 표시) |
| 챗봇 채팅방 | 스킬 상세에서 "지금 보러가기" → 기존 챗봇 진입 플로우 |

---

## 7. 확정 사항

| 항목 | 결정 |
|------|------|
| 상용 인증키 (Auth_Key) | 개발/상용 동일 |
| 쿠폰번호 프리픽스 | 90, 91 (DB `coupon_prefix_rule` 시드 데이터로 관리 — 추가 시 AdminJS에서 row 추가) |
| 쿠폰 형식 판별 | **서버 단일 진입점** (`POST /api/coupon/register`) — DB 규칙 기반 분류. 클라이언트는 하드코딩된 프리픽스 분기 없음 (ISS-011 해결: 2026-04-19) |
| 쿠폰 등록 단계 | **1단계 원샷** — 쿠프마케팅 쿠폰도 서버가 check+use를 한 번에 처리. 사용자 확인 팝업(S2) 제거 (ISS-011 해결: 2026-04-19) |
| 구버전 앱 대응 | 기존 `POST /api/coupon`의 **code 경로** 진입 가드 — 90/91 프리픽스 입력 시 HTTP 406 + `CO012` 에러코드. `couponSpecSeq` 경로는 영향 없음. 메시지: "앱을 최신 버전으로 업데이트 해주세요" 기존 에러 토스트 로직이 자동 표시 (ISS-009 해결: 2026-04-19) |
| 신버전 클라이언트 APP_UPDATE_REQUIRED 수신 시 | `POST /api/coupon/register` 응답으로도 `CO012`(HTTP 406) 수신 가능 — 미래에 서버가 신규 `couponType`(예: 새 제휴사 플로우)을 추가했으나 해당 클라이언트 버전이 지원 못 하는 경우. 구버전과 동일 에러 메시지 "앱을 최신 버전으로 업데이트 해주세요" 표시. 현 시점 Phase 1에서는 발생 경로 없음 (확장 대비) |
| 스킬 교환 방식 | 100% 할인 쿠폰 발급 → 기존 구매 플로우로 0하트 구매 |
| 취소 정책 | 콘텐츠형 상품 — 사용 후 취소 불가, 내부 오류 시에만 자동 L2 |
| 에러 표시 | 팝업 → 토스트로 변경 (Figma 확정) |
| 이용권 카드 | 기존 쿠폰 카드 형식 (Figma 확정) |

---

## 8. 미확정 사항

| 항목 | 상태 | 영향 |
|------|------|------|
| 카카오 딥링크 URL 스킴 | 미확정 | iOS/Android 딥링크 처리 |
| Admin 정산 통계 | 미구현 | 운영 배포 전 필요 |

---

## 9. 배포 순서 및 롤백 (Phase 1)

### 배포 순서 (엄수 필수)

신버전 클라이언트가 서버에 존재하지 않는 `/api/coupon/register`를 호출하여 장애가 발생하지 않도록 **서버 선행 배포**가 필수입니다.

```
1. 서버 배포 (프로덕션)
   - CouponPrefixRule 엔티티 + 마이그레이션 + 시드
   - POST /api/coupon/register 신규 엔드포인트
   - POST /api/coupon 가드 추가
   - CO012 에러코드 + i18n
   - 기존 /api/coop/check, /api/coop/use는 유지 (deprecated 주석만)
   ↓
   서버 프로덕션 배포 완료 + 헬스체크 + 스모크 테스트 확인

2. 웹 배포
   - /api/coupon/register 호출 전환 + UI 정리
   ↓
   웹 배포 완료

3. iOS / Android 앱스토어 제출
   - 심사 후 순차 릴리스
   ↓
   신버전 앱 배포 시작 — 구버전 앱 잔존율 모니터링

4. Phase 2 준비 (몇 릴리스 후)
   - /api/coop/check, /api/coop/use 호출률 ≈ 0 확인 후 삭제
```

### 롤백 시나리오

| 문제 | 롤백 방향 |
|------|----------|
| 서버 장애 (신규 API 버그) | 서버 이전 버전 롤백. 신버전 클라이언트는 신규 API 경로가 사라져 기능 이용 불가 — 클라이언트 hotfix 또는 수동 복구 필요 |
| 서버 배포 후 클라이언트 배포 전 | 안전. 구버전 앱/웹은 기존 `/api/coop/*` 계속 사용 |
| 클라이언트 배포 후 서버 롤백 | **위험** — 신버전 클라이언트가 없는 엔드포인트 호출. 반드시 서버 롤백 전 클라이언트도 되돌려야 함 |

> **원칙**: Phase 1 기간 동안 서버는 `/api/coop/*`를 **절대 제거하지 않음** (롤백 안전성 확보). Phase 2에서만 삭제.

### Phase 2 제거 조건 (정량 기준)

다음 조건 모두 만족 시 `/api/coop/check`, `/api/coop/use` 제거:
- Phase 1 배포 후 **최소 4주 경과**
- 최근 2주간 `/api/coop/*` 호출률 **≤ 0.1%** (전체 쿠폰 등록 요청 대비)
- iOS/Android 구버전(Phase 1 이전 빌드) 사용자 비율 **≤ 5%**
- 호출자 식별(User-Agent/앱버전 로그)로 잔존 클라이언트 파악 완료

---

## 10. 데이터 분석 설계

> **이전됨** — 본 섹션 내용 전체가 [data-measurement-plan.md](./data-measurement-plan.md) 으로 이전. KPI 정의·거래액 인식 정책(Q1)·하트 충전권(Q2)·카카오 유입자 식별(Q4)·갭/보류는 거기서 SSOT.

<details>
<summary>이전 전 본문 (2026-04-28 까지) — 보존용</summary>

### 10-1. 거래액 인식 정책 — `spent_cash_amount` 인젝션 (2026-04-27 결정)

**문제**

기존 데이터 파이프라인 [mart_use_skill_se.sql:26-32](../../common-data-airflow/dags/scripts/hellobot/mart/mart_use_skill_se.sql:26) 의 `pay_under_750` 자동 격리 규칙에 의해, 카카오 100% 할인 쿠폰(스킬 교환권) 사용 결제는 모든 `spent_*` 가 0이 되어 다음 다운스트림에서 자동 누락됨:

- 구매자수 집계 (`event_name LIKE '%pay_for%'`) — `pay_under_750` 미매칭
- 거래액 집계 (`SUM(spent_heart_coin*150 + spent_cash_amount)`) — 모두 0이라 합산 영향 없음

**결정 (Q1)**

서버는 카카오 쿠폰 사용 결제 시 `pay_for_contents` 이벤트의 `spent_cash_amount` 파라미터에 **쿠폰 판매가** (`coop_marketing_product.current_price ?? coop_marketing_product.price`) 를 인젝션. 이를 통해:

- `revenue_krw > 0` 이 되어 `pay_under_750` 재분류 회피
- 모든 다운스트림 매출/구매자 공식이 변경 없이 자동 합산
- 카카오 정산금 = HelloBot 매출 (회계 원칙 일치)

**시멘틱 변경**

| 항목 | 변경 전 | 변경 후 |
|---|---|---|
| `spent_cash_amount` | 사용자가 콘텐츠 구매에 실제 지불한 현금 | 이 트랜잭션의 현금 매출 (사용자 직접 결제 + 외부 결제 채널 환산금) |
| `revenue_krw` | 유료 하트 + 현금 (실제 회수 매출) | 유료 하트 + 현금 (외부 결제 채널 환산금 포함) |

→ 데이터 카탈로그 [ISS-017](../../common-data-airflow/docs/hellobot-data/catalog/issues.md) 등록.

### 10-2. 인젝션 트리거 조건 (D1)

서버는 결제 흐름에서 다음 조건을 모두 만족할 때 `spent_cash_amount` 인젝션:

1. `usedCouponSeq` 존재
2. 사용한 쿠폰이 **카카오 쿠폰** 임 — `coop_marketing_coupon_usage.issued_coupon_seq` 매칭으로 식별

→ 서버는 카카오 쿠폰임을 인지할 수 있는 식별 메커니즘 추가가 필요 (예: `CouponService` 가 `usedCouponSeq` 로 `coop_marketing_coupon_usage` 를 조회하여 카카오 발급 여부 판단).

**인젝션 값**: `coop_marketing_product.current_price ?? coop_marketing_product.price` (KRW)

### 10-3. 하트 충전권 매출 인식 정책 (Q2)

카카오 하트 충전권 등록 시 [coop-marketing.ts:383-393](../worktrees/hellobot-server/src/services/coop-marketing.ts:383) 의 `chargeHeart` 호출은 `expiredAt` 미전달 → HeartLog `expiredAt = NULL` → [heart.ts:155-189](../worktrees/hellobot-server/src/services/heart.ts:155) `useHeartLogic` 의 보너스 분기 (`willBeExpiredAt` 체크) 미진입 → **유료 하트 (`spent_heart_coin`) 로 적립**.

→ 하트 충전권으로 적립된 하트는 사용자가 콘텐츠 소비 시 `pay_for_contents` 의 `spent_heart_coin > 0` 으로 자연 매출 인식. **별도 인젝션 불필요**.

> 카탈로그 신규 enum [`HeartLogType.ChargeByGiftCoupon`](../worktrees/hellobot-server/src/models/entities/HeartLog.ts:32) 로 충전 logType 분류 가능 (참고용).

### 10-4. 데이터 측 변경 사항

| 레이어 | 파일 | 변경 |
|---|---|---|
| mart_integrated | [union_mart_user_key_actions.sql:1098-1101](../../common-data-airflow/dags/scripts/hellobot/mart_integrated/union_mart_user_key_actions.sql:1098) | BQ 컬럼 description 4건 갱신 (외부 채널 환산금 포함 명시) |
| mart | [mart_use_skill_se.sql:103-108](../../common-data-airflow/dags/scripts/hellobot/mart/mart_use_skill_se.sql:103) | 인라인 코멘트 갱신 |
| 카탈로그 | [tables/mart/mart_use_skill_se.md](../../common-data-airflow/docs/hellobot-data/catalog/tables/mart/mart_use_skill_se.md), [event-catalog.md](../../common-data-airflow/docs/hellobot-data/catalog/event-catalog.md), [metric-dictionary.md](../../common-data-airflow/docs/hellobot-data/catalog/metric-dictionary.md), [issues.md](../../common-data-airflow/docs/hellobot-data/catalog/issues.md) | description 갱신 + ISS-017 등록 |

**SQL 변경 0건 (다운스트림 무영향)**. `used_coupon_*` 마트 컬럼 추출은 보류 (필요 시점에 추가).

### 10-5. 보류·미반영 사항

- **환불·취소 시 처리 정책 (C2)**: 미정. 발생 시 추가 검토. 현 인젝션은 `pay_for_contents` 발화 시점 1회만 처리하며 사후 정정 메커니즘 없음.
- **카카오 정산 데이터 인입 (Q3)**: 불필요. 쿠폰 판매가 인젝션으로 매출 자동 집계 충족.
- **재무/회계 매출 인식 시점 컨펌 (C3)**: 본 프로젝트 범위 외.
- **`used_coupon_*` 마트 추출**: 사용자 결제 vs 외부 환산금 분리 분석은 향후 필요 시점에 추가.

### 10-6. 분석 쿼리 영향

기존 매출/구매자수 공식이 그대로 유효합니다 (변경 불필요):

```sql
-- 거래액 (변경 없음, 카카오 결제 자동 포함)
SUM(spent_heart_coin * 150 + spent_cash_amount) AS revenue_krw
FROM hlb_mart.mart_use_skill_se
WHERE event_name LIKE '%pay_for%'

-- 구매자수 (변경 없음)
COUNT(DISTINCT user_id) AS num_users_paying
FROM hlb_mart.mart_use_skill_se
WHERE event_name LIKE '%pay_for%'
```

향후 카카오 결제만 분리하려면 `used_coupon_seq IS NOT NULL` 식별이 필요하며, 이는 마트 컬럼 추출 후 가능 (현재 보류).

### 10-7. 카카오 유입자 식별 (Q4 결정, 2026-04-28)

**정의**

| 시간 단위 | 조건 (KST) |
|---|---|
| **일간 신규** | `coop_kakao_first_used_date = DATE(user_created_at, 'Asia/Seoul')` |
| **주간 신규** | `DATE_TRUNC(coop_kakao_first_used_date, ISOWEEK) = DATE_TRUNC(DATE(user_created_at, 'Asia/Seoul'), ISOWEEK)` |
| **월간 신규** | `DATE_TRUNC(coop_kakao_first_used_date, MONTH) = DATE_TRUNC(DATE(user_created_at, 'Asia/Seoul'), MONTH)` |

→ ISO Week 기준 (월요일 시작), KST 시간대. `coop_kakao_first_used_date` 가 NULL 이면 카카오 미경험 사용자.

**판정 정책**

- **등록일만 사용**: `coop_marketing_coupon_usage.used_at` 의 `MIN()` (사용자별). `status` 필터 없음 (`used` + `canceled` 모두 포함). 카카오로 진입한 사실 자체를 유입으로 인정하며, 결제로 이어졌는지(구매자/미구매자)는 `pay_for_*` 이벤트로 자연 분류됨.

**파이프라인 변경**

| 레이어 | 파일 | 변경 |
|---|---|---|
| RDS 스냅샷 | [hellobot_snapshot_to_bigquery DAG](../../common-data-airflow/hlb_dags/) | `coop_marketing_coupon_usage` 일 1회 인입 (Glue/Airflow) → `server_rdb.snapshot_coop_marketing_coupon_usage` |
| staging | `hlb_staging.staging_coop_marketing_coupon_usage` (신규) | 정제 SQL 신규 |
| intermediate | `hlb_intermediate.intermediate_coop_kakao_first_used` (신규) | 사용자별 `MIN(used_at)` 집계 SQL 신규 (~10줄) |
| mart | [mart_user_daily_info.sql](../../common-data-airflow/dags/scripts/hellobot/mart/mart_user_daily_info.sql) | `coop_kakao_first_used_date` (DATE, NULL 허용) 컬럼 1개 추가 + LEFT JOIN |
| mart_integrated | [union_mart_user_key_actions.sql](../../common-data-airflow/dags/scripts/hellobot/mart_integrated/union_mart_user_key_actions.sql) | 동일 컬럼 propagate (mart_user_daily_info 또는 별도 LEFT JOIN) |
| 카탈로그 | `tables/mart/mart_user_daily_info.md` 외 | 컬럼 description 갱신 |

**분석 쿼리 (KPI 측정 — 출시 후 일평균 신규 구매자 +20명)**

```sql
SELECT
  event_date,
  -- 카카오 신규 구매자수 (3종 시간 단위)
  COUNT(DISTINCT CASE
    WHEN coop_kakao_first_used_date = DATE(user_created_at, 'Asia/Seoul')
    THEN user_id END) AS kakao_new_user_daily_paying,
  COUNT(DISTINCT CASE
    WHEN DATE_TRUNC(coop_kakao_first_used_date, ISOWEEK)
       = DATE_TRUNC(DATE(user_created_at, 'Asia/Seoul'), ISOWEEK)
    THEN user_id END) AS kakao_new_user_weekly_paying,
  COUNT(DISTINCT CASE
    WHEN DATE_TRUNC(coop_kakao_first_used_date, MONTH)
       = DATE_TRUNC(DATE(user_created_at, 'Asia/Seoul'), MONTH)
    THEN user_id END) AS kakao_new_user_monthly_paying,
  -- 카카오 경험자 전체 결제자
  COUNT(DISTINCT CASE WHEN coop_kakao_first_used_date IS NOT NULL
                      THEN user_id END) AS kakao_total_paying
FROM `hellobot-f445c.hlb_mart_integrated.union_mart_user_key_actions`
WHERE event_date BETWEEN DATE_SUB(CURRENT_DATE('Asia/Seoul'), INTERVAL 30 DAY)
                     AND DATE_SUB(CURRENT_DATE('Asia/Seoul'), INTERVAL 1 DAY)
  AND event_name LIKE '%pay_for%'  -- 결제자만
GROUP BY event_date
ORDER BY event_date DESC;
```

**일정**

- **2026-04-30 까지 데이터 인프라 구현 완료** 목표
- 출시 4/30, D+1 (5/1) 부터 카카오 데이터 측정 가능
- 분석 시작 일자(5/11)까지 안정화 기간 확보

</details>

---

## 11. 쿠폰 등록 이벤트 스펙 (2026-04-28 결정)

> **이전됨** — 본 섹션 내용 전체가 [event-spec.md](./event-spec.md) 으로 이전. Firebase 클라이언트 이벤트 3종(`view_coupon_register`, `register_coupon_success`, `register_coupon_failure`)의 발화 시점·파라미터·화이트리스트·검증 절차는 거기서 SSOT.

<details>
<summary>이전 전 본문 (2026-04-28 까지) — 보존용</summary>

쿠폰 등록 funnel(진입 → 성공/실패)을 측정하기 위한 이벤트 3종. **모두 클라이언트(Firebase) 발화** — 서버 트랜잭션은 이미 `coupon` / `coop_marketing_coupon_usage` / `coop_marketing_api_log` 테이블에 진실 원천이 있으므로 이벤트 중복 불필요. 단, 클라이언트는 서버 응답 DTO 에서 파라미터 값을 읽어 발화한다.

### 11-1. 이벤트 명명 컨벤션

- 화면 이벤트는 `view_*` (Firebase 자동 수집 보강), 액션 이벤트는 동사 시작 (`register_*`, `pay_for_*`, `touch_*`).
- `coupon_type` 파라미터(`kakao` | `hellobot` | `giftiel`)로 채널 분류 — 이벤트명에 채널을 박지 않음.
- 3채널 통합 단일 진입점(`POST /api/coupon/register`)이므로 채널과 무관하게 동일 이벤트.

### 11-2. 이벤트 정의

#### EVT-1. `view_coupon_register` (화면 진입)

| 항목 | 값 |
|------|----|
| 발화 주체 | 클라이언트 (iOS/Android/Web Firebase) |
| 발화 시점 | 쿠폰 등록 화면(iOS `CouponListViewController` / Android `CouponListActivity` / Web `/coupon`) 진입 시 1회 |
| 데이터셋 | `analytics_164027297.events_*` |
| 파라미터 | (없음 — Firebase 자동 수집 user_id, platform 만 사용) |

#### EVT-2. `register_coupon_success` (등록 성공)

| 항목 | 값 |
|------|----|
| 발화 주체 | 클라이언트 (iOS/Android/Web Firebase) |
| 발화 시점 | `POST /api/coupon/register` 200 응답 직후 |
| 데이터셋 | `analytics_164027297.events_*` |

| 파라미터 | 타입 | 필수 | 소스 (응답 DTO) | 설명 |
|---|---|---|---|---|
| `coupon_number` | string | ✅ | (클라이언트 입력값) | 입력한 쿠폰번호. 분석용 1:1 대사 |
| `coupon_type` | string | ✅ | `prefixRule.couponType` 또는 응답 분기 | `kakao` \| `hellobot` \| `giftiel` |
| `issued_type` | string | ✅ | 응답 `issuedType` | `heart` \| `skill` |
| `product_code` | string | conditional | 응답 `productCode` | 카카오 한정. 일반/giftiel 쿠폰은 미전달 |
| `fixed_menu_seq` | int | conditional | 응답 `fixedMenuSeq` | 스킬 교환권일 때만 |
| `heart_amount` | int | conditional | 응답 `heartAmount` | 하트 충전권일 때만 |
| `bonus_heart_amount` | int | conditional | 응답 `bonusHeartAmount` | 하트 충전권일 때만 |
| `latency_ms` | int | ✅ | 클라이언트 측정 | 등록 버튼 탭 → 응답 수신까지 ms |

#### EVT-3. `register_coupon_failure` (등록 실패)

| 항목 | 값 |
|------|----|
| 발화 주체 | 클라이언트 (iOS/Android/Web Firebase) |
| 발화 시점 | `POST /api/coupon/register` non-200 응답 또는 네트워크 에러 직후 |
| 데이터셋 | `analytics_164027297.events_*` |

| 파라미터 | 타입 | 필수 | 소스 | 설명 |
|---|---|---|---|---|
| `coupon_number` | string | ✅ | (클라이언트 입력값) | |
| `coupon_type` | string | nullable | prefixRule 매칭 결과 또는 응답 | prefix 매칭 실패 시 NULL — 분석은 `coupon_prefix` 보조 필드로 |
| `coupon_prefix` | string | ✅ | (클라이언트 입력값 앞 2자리) | `coupon_type` NULL 일 때 보조 분류 |
| `error_code` | string | ✅ | 응답 `code` 또는 클라이언트 분류 | `CM001`~`CM010`, `CO012`, `NETWORK_ERROR`, `UNKNOWN` 등. 분석·대시보드 1차 키 |
| `reason` | string | ✅ | 응답 `message` 또는 에러 객체 | 자유 텍스트. CS 케이스별 문맥 파악용 |
| `latency_ms` | int | ✅ | 클라이언트 측정 | |

### 11-3. 이벤트 화이트리스트 등록 (3건)

```sql
INSERT INTO `hellobot-f445c.hlb_staging.staging_key_events_fb_events_list` (event_name) VALUES
  ('view_coupon_register'),
  ('register_coupon_success'),
  ('register_coupon_failure');
-- 또는 `events_list` 에 등록 (1차 게이트와 OR 처리이므로 한 곳이면 통과)
```

### 11-4. 서버 의존성

클라이언트가 EVT-2 파라미터를 채울 수 있도록 **응답 DTO 보강 필요**:

| 응답 필드 | 현재 상태 | 필요 보강 |
|---|---|---|
| `issuedType` | 이미 존재 (architecture.md §3) | — |
| `productCode` | 카카오 응답에만 — 확인 필요 | 미포함 시 추가 |
| `fixedMenuSeq` | 스킬 교환권 응답에 존재 | — |
| `heartAmount`, `bonusHeartAmount` | 하트 충전권 응답에 존재 (확인 필요) | 미포함 시 추가 |
| `code`, `message` (에러) | 표준 에러 포맷 존재 | — |

> 서버 측 보강 과업은 [tasks.md §서버](./tasks.md) 에 추가. 응답 DTO 점검은 [api-spec.md](./api-spec.md) 에서 수행.

### 11-5. 분석 쿼리 예시

**일별 등록 funnel (전환율)**:
```sql
WITH events AS (
  SELECT
    DATE(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul') AS event_date,
    event_name,
    user_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key='coupon_type') AS coupon_type,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key='error_code')  AS error_code
  FROM `hellobot-f445c.analytics_164027297.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20260501' AND '20260531'
    AND event_name IN ('view_coupon_register','register_coupon_success','register_coupon_failure')
)
SELECT
  event_date,
  COUNT(DISTINCT IF(event_name='view_coupon_register', user_id, NULL))            AS viewers,
  COUNTIF(event_name='register_coupon_success')                                   AS success,
  COUNTIF(event_name='register_coupon_failure')                                   AS failure,
  SAFE_DIVIDE(COUNTIF(event_name='register_coupon_success'),
              COUNTIF(event_name IN ('register_coupon_success','register_coupon_failure'))) AS success_rate
FROM events
GROUP BY event_date
ORDER BY event_date;
```

**카카오 채널 등록 분포 (상품별)**:
```sql
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key='product_code') AS product_code,
  COUNT(*) AS register_count
FROM `hellobot-f445c.analytics_164027297.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20260501' AND '20260531'
  AND event_name = 'register_coupon_success'
  AND (SELECT value.string_value FROM UNNEST(event_params) WHERE key='coupon_type') = 'kakao'
GROUP BY product_code
ORDER BY register_count DESC;
```

**에러 코드 분포 (운영 R1 일일 리포트)**:
```sql
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key='error_code') AS error_code,
  COUNT(*) AS occurrences
FROM `hellobot-f445c.analytics_164027297.events_*`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', CURRENT_DATE('Asia/Seoul') - 1)
  AND event_name = 'register_coupon_failure'
GROUP BY error_code
ORDER BY occurrences DESC;
```

### 11-6. 마트 반영 (후속)

- `intermediate_coop_coupon_event.sql` 신규 — 3종 이벤트 + `coop_marketing_product` 조인으로 분석용 view
- `mart_coop_coupon_usage.sql` 신규 — 그레인: 쿠폰 1장. `is_new_user`, `is_first_paying`, `success/failure` 컬럼
- `union_mart_user_key_actions` 의 `funnel_from_coop_coupon` 컬럼은 [tasks.md §164](./tasks.md) 의 기존 설계 유지

### 11-7. 보류·확장

- `register_coupon_attempt` (등록 버튼 탭 시점) — 네트워크 끊김 측정용. 운영 중 의미있게 발생 시 추가
- 서버 이벤트(`pay_for_contents` 외 추가) — DB 진실 원천 활용 가능하므로 불필요로 판단

</details>

---

## 참조 문서

| 문서 | 설명 |
|------|------|
| [data-measurement-plan.md](./data-measurement-plan.md) | 데이터 측정 계획 SSOT (KPI·정의·정책·소스 매핑·분석 쿼리) |
| [event-spec.md](./event-spec.md) | 이벤트 발화 스펙 SSOT (Firebase 이벤트·파라미터·검증 절차) |
| [api-spec.md](./api-spec.md) | API 상세 명세 (필드, 에러 코드, 처리 흐름) |
| [client-guide.md](./client-guide.md) | 클라이언트 연동 가이드 (화면별 구현 상세, 에러 처리) |
| [screen-plan.md](./screen-plan.md) | 화면 기획서 (화면 흐름, 구성 요소, 인터랙션) |
| [designs/designs.md](./designs/designs.md) | Figma 디자인 링크 |
| [designs/design-review.md](./designs/design-review.md) | 디자인 리뷰 체크리스트 (웹 반영 완료) |
| [user-stories.md](./user-stories.md) | 사용자 스토리 (US-1~US-6) |
| [requirements.md](./requirements.md) | 요구사항 정의서 |
| [issues.md](./issues.md) | 이슈 목록 |

---

## Changelog

| 날짜 | 이슈 | 변경 내용 |
|------|------|----------|
| 2026-04-28 | ISS-050 | **에러 코드 컨벤션 정합화**. 신규 에러 코드 `CM_001~CM_010` → `CM001~CM010` (언더바 제거, 기존 `CO`/`CP` 시리즈와 동일 형식). 의미 중복 enum 이름 `CM_INVALID_COUPON`/`CM_EXPIRED_COUPON`/`CM_ALREADY_USED_COUPON` → `CM_COUPON_NOT_FOUND`/`CM_COUPON_EXPIRED`/`CM_COUPON_ALREADY_USED` (CP 접미사 통일). `CO_APP_UPDATE_REQUIRED` 항목 삭제 → 기존 의미 중복 코드 `CO012(UPDATE_APP)`로 통합. ko 메시지 어미 "~이에요" → "~습니다" 정합화 + 의미 일치(`CM001~003`)는 ko/ja/en 모두 `CP001/003/002` 문구 그대로 채택. 서버 코드 적용 완료. iOS `CouponRegisterErrorMapper` 키 표 동기 + 클라이언트 회귀 후속. 운영 배포 전이라 하위 호환성 무시 가능 결정. |
| 2026-04-28 | 문서 분리 | **§10 → [data-measurement-plan.md](./data-measurement-plan.md), §11 → [event-spec.md](./event-spec.md) 이전**. 데이터 측정 SSOT 와 이벤트 스펙 SSOT 를 별도 계약 문서로 분리 (다른 *-spec.md 와 컨벤션 통일). architecture.md §10/§11 자리에는 이전 안내 + `<details>` 보존 본문 유지. 참조 문서 표에 두 문서 추가. planning/ 의 success-metrics-kpi.md, performance-analysis-design.md 는 본 분리 작업으로 deprecated. |
| 2026-04-28 | 이벤트 설계 | **§11 쿠폰 등록 이벤트 스펙 신설**. Firebase 클라이언트 이벤트 3종 — `view_coupon_register` (화면 진입), `register_coupon_success` / `register_coupon_failure` (등록 결과). 서버 이벤트 미발화 (DB 진실 원천 사용). success 파라미터 9개 (coupon_number, coupon_type, issued_type, product_code, fixed_menu_seq, heart_amount, bonus_heart_amount, latency_ms), failure 파라미터 6개 (coupon_number, coupon_type, coupon_prefix, error_code, reason, latency_ms). 응답 DTO 보강 필요 항목(productCode, heartAmount/bonusHeartAmount) 명시. 화이트리스트 등록 3건. |
| 2026-04-28 | ISS-049 (Q4 결정) | §10-7 카카오 유입자 식별 추가. 등록일 기준 시간 단위(일/주/월) 신규 사용자 분류. `coop_kakao_first_used_date` (DATE) 컬럼 1개 추가 — `mart_user_daily_info` + `union_mart_user_key_actions` 양쪽. RDS `coop_marketing_coupon_usage` 일 1회 스냅샷 인입. `status` 무관하게 모든 등록 행을 유입으로 인정 (구매자/미구매자 분류는 `pay_for_*` 으로 자연 분리). 4/30 구현 완료 목표. |
| 2026-04-27 | ISS-049 (Q1 결정) | **§10 데이터 분석 설계 신설**. 카카오 쿠폰 사용 결제의 거래액 인식 방식을 `spent_cash_amount` 인젝션으로 확정. 서버 측에서 카카오 쿠폰임을 인지하여 `coop_marketing_product.current_price ?? price` 를 인젝션. 데이터 측 SQL 변경 0건, 카탈로그 description 4건 갱신 + 카탈로그 ISS-017 등록. 하트 충전권은 유료 하트(`expiredAt=NULL`) 적립으로 자연 매출 인식 검증 완료. `coop_marketing_product.current_price` 컬럼 신설 마이그레이션 필요(서버). |
| 2026-04-22 | /architect | **ISS-042 문구 정합**: §6 "중복 탭 방지" 블록의 "등록 버튼: register API 호출 중 disabled + 로딩" 표현을 "disabled + 회색 톤(기존 비활성 토큰 `#C6C8CC` 재사용), 스피너/인디케이터/GIF/오버레이 금지"로 명확화. ISS-031/035는 설계 근거가 design-spec/screen-plan/client-guide에만 존재하므로 architecture.md 본문 수정 없음(본 Changelog로만 기록). |
| 2026-04-21 | /architect | §6 "앱 WebView 임베딩 여부" 섹션 신설 — iOS `CouponListViewController`, Android `CouponListActivity`, Web `hellobot-web/app/coupon/page.tsx`의 세 플랫폼이 독립 구현이며 앱 WebView 공유 경로 없음을 확정. "모바일 웹뷰 환경 검증" 항목 해당 없음으로 종결 근거 기록. |
| 2026-04-19 | /architect (via /workspace) | **2차 리뷰 반영**: §1 이중 경로 표 code 기반 행의 "기존 경로는 구버전 앱 전용" 문구를 "기존 `/api/coupon`의 code 경로는 구버전 앱 호환용으로만 유지"로 명확화 (셀 범위 해석 모호성 제거). |
| 2026-04-19 | /review 반영 | **설계 보완** (리뷰 발견 사항 반영): §1에 "기존 `/api/coupon` 이중 경로(code/couponSpecSeq) 이해" 테이블 추가 — couponSpecSeq 경로 미변경 명시. §4 CouponPrefixRule "조회 전략" 확정(매 요청마다 DB 조회, 캐시 없음) + Raw SQL 시드 스키마 prefix 주의. §5-2에 DB 트랜잭션 경계 명시(two-phase commit, 보상 패턴) + Redlock 보상 완료 후 해제 규칙. §5-4 가드 발동 조건 세부 테이블 추가(6가지 입력 케이스별 동작). §6 웹뷰 영향 없음 확인 추가. §7에 신버전 클라이언트 APP_UPDATE_REQUIRED 수신 시나리오 추가. §9 "배포 순서 및 롤백" 신설(서버 선행 배포, Phase 2 정량 제거 조건). |
| 2026-04-19 | ISS-011, ISS-009 | **아키텍처 전면 개편**: §1 개요에 설계 원칙 추가. §2 시퀀스 다이어그램을 신버전(coop/일반)+구버전 3종으로 재구성. §3 API 계약을 `/api/coupon/register`(신규 통합 단일 진입점) + `/api/coupon`(가드 추가)로 변경, `/api/coop/check`/`/api/coop/use`는 deprecated. §4에 `coupon_prefix_rule` 테이블 추가(동적 프리픽스 관리). §5 처리 로직을 1단계 원샷 플로우로 재작성(check+use 통합, S2 확인 팝업 제거). §5-4 `/api/coupon` 진입 가드 추가. §6 파트별 구현 포인트에 Phase 1 삭제/수정 대상 명시. §7 확정사항에 서버 단일 진입점/1단계/구버전 가드 추가. |
| 2026-04-14 | ISS-003 | check API 응답에서 expiryDate 필드 제거. 교환된 상품(하트/이용권)에는 유효기간이 없으므로 쿠폰 만료일을 클라이언트에 전달할 필요 없음. |
| 2026-04-14 | ISS-001 | §5-2, §5-3: usage UPSERT 우선 기록 후 상품 지급 (순서 변경). §5-4: 자동 복구 시 usage canceled 처리 명시. §5-5: Admin 수동 취소 + 상품 회수 로직 추가. |
