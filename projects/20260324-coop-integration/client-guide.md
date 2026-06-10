# 클라이언트 개발 가이드 — 카카오 선물하기 상품권

## 개요

카카오 선물하기로 받은 상품권(쿠폰번호)을 기존 쿠폰 탭에서 입력하여 **하트 충전** 또는 **스킬 이용권 발급**을 받는 기능입니다. 별도 화면 신규 개발 없이 기존 쿠폰 화면과 스킬 상세 페이지를 재사용합니다.

**설계 원칙** (2026-04-19 ISS-011 해결로 확정):
- **서버 단일 진입점** — 모든 쿠폰 코드는 `POST /api/coupon/register`로 전송. 클라이언트는 프리픽스를 판별하지 않음.
- **1단계 원샷** — 쿠프마케팅 쿠폰도 중간 확인 팝업 없이 바로 발급.
- **응답 기반 UI 분기** — `issuedType: "coupon" | "heart" | "skill"` 으로 성공 후 UI를 결정.

> **화면 기획서**: [screen-plan.md](./screen-plan.md)
> **API 명세**: [api-spec.md](./api-spec.md)
> **디자인 스펙**: [design-spec.md](./design-spec.md)

---

## 연동 흐름

### 단일 API 호출

사용자가 쿠폰번호를 입력하고 등록 버튼을 탭하면 `POST /api/coupon/register` 하나만 호출합니다.

```
POST /api/coupon/register
Authorization: Bearer {token}
Content-Type: application/json

{ "code": "901914216415" }
```

### 응답 분기

| HTTP | 조건 | 처리 |
|------|------|------|
| 2xx | `issuedType: "coupon"` | 기존 쿠폰 발급 완료 처리 (쿠폰 리스트 갱신 + 토스트) |
| 2xx | `issuedType: "heart"` | S3 하트 충전 완료 팝업 표시 |
| 2xx | `issuedType: "skill"` | S4 스킬 이용권 카드 추가 + 토스트 |
| 4xx/5xx | `error.code = CM_*` 등 | S5 에러 토스트 표시 (`error.message` 사용) |

---

## 응답 예시

### 성공 — 일반 쿠폰 발급 (201)

```json
{
  "data": {
    "resultType": "ISSUED",
    "issuedType": "coupon",
    "coupon": {
      "seq": 12345,
      "specSeq": 678,
      "name": "신년 할인 쿠폰",
      "tags": [],
      "platform": "ALL",
      "discountType": "percentage",
      "discountValue": 10,
      "minPurchasePrice": 0,
      "maxDiscountPrice": null,
      "expiresAt": "2026-07-18T23:59:59+09:00"
    }
  }
}
```

### 성공 — 하트 충전권 (200)

```json
{
  "data": {
    "resultType": "ISSUED",
    "issuedType": "heart",
    "productName": "카카오 하트 충전권 5천원",
    "heartQuantity": 25
  }
}
```

### 성공 — 스킬 이용권 발급 (200)

```json
{
  "data": {
    "resultType": "ISSUED",
    "issuedType": "skill",
    "productName": "그 사람과 나의 사주 궁합",
    "skillName": "그 사람과 나의 사주 궁합",
    "fixedMenuSeq": 2166,
    "chatbotSeq": 123,
    "issuedCouponSeq": 456
  }
}
```

### 에러 (HTTP 4xx/5xx)

```json
{
  "error": {
    "code": "CM_001",
    "message": "유효하지 않은 쿠폰이에요"
  }
}
```

---

## 화면별 구현 상세

### 쿠폰 화면 (기존 화면 수정)

- 기존 쿠폰 입력란 그대로 사용
- 힌트 텍스트: 기존 유지 ("쿠폰 코드를 입력해주세요")
- **등록 버튼 탭 시 `POST /api/coupon/register` 단일 호출** — 클라이언트에서 프리픽스 분기 불필요
- 응답의 `issuedType`에 따라 후속 UI 분기

### S3. 하트 충전 완료 팝업

응답 `issuedType === "heart"` 인 경우 표시.

| 요소 | 데이터 소스 |
|------|-----------|
| 일러스트 | 하트 충전 **애니메이션** (플랫폼별 기존 자산 재사용, design-spec §S3 참조) |
| 캡션 | 이벤트/상품명 (Red400) |
| 제목 | "하트가 {heartQuantity}개 충전되었어요!" |
| 본문 | "하트는 \<프로필\>탭에서 확인 가능해요" |
| 확인 버튼 | 프로필 탭으로 이동 |

**일러스트 자산 정책** (2026-04-22 ISS-035 확정):
- 정적 이미지 금지. **재생되는 애니메이션**이어야 합니다.
- 본 피쳐용 신규 자산 발급 없음. 각 플랫폼은 **기존 하트 충전 관련 애니메이션 자산을 재사용**합니다.
  - iOS — `imgHeartchargeComplete` Lottie (`Resources/Gif/imgHeartchargeComplete.json`, loopMode=.loop)
  - Android — `img_heartcharge_completed.gif` (기 반영됨)
  - Web — 기존 애니메이션 자산 탐색 후 결정. Next.js `<Image>`는 GIF 애니메이션 미지원 → `<img>` 또는 `<Image unoptimized>` 사용
- 자산 이름/경로/포맷의 플랫폼 간 통일을 강제하지 않음.

### S4. 스킬 이용권 등록 완료

응답 `issuedType === "skill"` 인 경우:
1. 쿠폰 입력란 초기화
2. 쿠폰 리스트 최상단에 **스킬 이용권 카드** 추가
3. 토스트: "스킬 이용권이 등록되었어요" (2.5초 후 자동 사라짐)
4. 헤더 쿠폰 수 +1 업데이트

**스킬 이용권 카드**:
- 라벨: "이용권" 태그 (회색, 흰 배경)
- 할인율: "100%" (분홍 강조)
- 쿠폰명: 응답의 `skillName`
- 챗봇명: 미노출
- 링크: "스킬 보러가기 >" (보라색)
- 카드 탭 또는 링크 탭 → 스킬 상세 페이지 이동 (`fixedMenuSeq` 사용)

**카드 크기/여백 원칙** (2026-04-22 ISS-031 확정 — design-spec §S4 참조):

> **"같은 모양·같은 크기 — 빠진 요소는 빈 공간으로 유지"**

스킬 이용권 카드는 일반 쿠폰 카드와 **동일한 박스 높이** 및 **동일한 점선 하단 여백**을 유지합니다. 스킬 이용권에 없는 요소(서브텍스트 "N원 이상 결제 시", 만료일 등)는 **레이아웃 공간을 reserve하고 내용만 미노출**로 처리합니다.

- 허용: invisible placeholder (`visibility: hidden` / `opacity: 0` / 동일 높이 spacer)
- 금지: 행 collapse — `display: none`, 높이 0, iOS `flex.isIncludedInLayout = false`, Android 조건부 remove 등
- 신규 px 값을 지정하지 않습니다. 기존 일반 쿠폰 카드의 실제 렌더 결과 높이와 일치시키면 충분합니다.

**플랫폼 정합 작업**:
- iOS — ISS-041 해결본의 `descriptionLabel.flex.isIncludedInLayout = false`는 본 원칙과 어긋남. **reserve 방식으로 전환** 필요 (isHidden만 유지, 레이아웃 공간은 보존).
- Android — `CouponItem.kt` 태그 Row 및 서브텍스트 영역 분기가 공간 reserve 원칙을 준수하는지 점검. 조건부 행 제거가 있으면 invisible placeholder로 전환.
- Web — `CoopSkillVoucherItem.tsx`에 `CouponItem`과 동일한 수직 리듬(서브텍스트 reserve + 점선 상하 `my-[12px]` 마진) 적용.

### 일반 쿠폰 발급 완료

응답 `issuedType === "coupon"` 인 경우:
1. 쿠폰 입력란 초기화
2. 쿠폰 리스트 갱신 (`coupon` 필드를 상태에 추가)
3. 헤더 쿠폰 수 +1 업데이트
4. (기존 동작과 동일)

### S5. 에러 토스트

에러 발생 시 토스트로 표시합니다 (design-spec 확정).

| 요소 | 스펙 |
|------|------|
| 배경 | `rgba(36,37,38,0.8)`, radius 8px |
| 텍스트 | `error.message` (서버에서 i18n 처리) |
| 위치 | 하단 중앙 |
| 자동 사라짐 | 2.5초 |
| 에러 후 동작 | 쿠폰 화면 복귀, 입력 필드 유지 |

### S6. 미로그인 시 로그인 화면 이동 (기획 변경: 2026-04-16)

~~기존: 로그인 안내 팝업 표시~~ → **변경: 로그인 화면으로 직접 이동**

미로그인(anonymous) 사용자가 쿠폰 입력란을 포커스할 때 즉시 로그인 화면으로 이동합니다.

**동작 규칙 (앱/웹 공통)**:
- 쿠폰 입력란 포커스 시 로그인 상태 체크 → anonymous이면 로그인 화면으로 즉시 이동
- 로그인/회원가입 완료 후 쿠폰 입력 페이지로 복귀 (fallbackUrl/딥링크 활용)
- 팝업 없이 바로 이동 — 별도 확인 UI 불필요

**플랫폼별 구현**:
| 플랫폼 | 로그인 후 복귀 방법 |
|--------|-------------------|
| 웹 | `fallbackUrl=/coupon` 파라미터로 로그인 후 리다이렉트 |
| iOS | 로그인 완료 콜백에서 쿠폰 화면으로 네비게이션 복귀 |
| Android | 로그인 완료 콜백에서 쿠폰 화면으로 네비게이션 복귀 |

---

## 에러 처리

모든 에러는 HTTP 4xx/5xx + 표준 포맷(`{ error: { code, message } }`)으로 반환됩니다. 클라이언트는 `error.message`를 토스트에 그대로 표시하면 됩니다.

### 에러 매핑표

| HTTP | errorCode | 사용자 메시지 |
|------|-----------|-------------|
| 400 | CM_001 | 유효하지 않은 쿠폰이에요 |
| 400 | CM_002 | 기간이 만료된 쿠폰이에요 |
| 400 | CM_003 | 이미 사용된 쿠폰이에요 |
| 400 | CM_005 | 일시적인 서비스 오류가 발생했어요 |
| 400 | CM_010 | 결제가 취소된 쿠폰이에요 |
| 404 | CM_004 | 상품을 찾을 수 없어요 |
| 500 | CM_006 | 일시적인 통신 오류가 발생했어요 |
| 500 | CM_007 | 하트 충전에 실패했어요 |
| 500 | CM_008 | 스킬 이용권 발급에 실패했어요 |
| 500 | CM_009 | 쿠폰 스펙을 찾을 수 없어요 |

> CM_007, CM_008 발생 시 서버가 자동으로 쿠프마케팅 승인 취소(L2)를 시도합니다. 쿠폰이 원복되므로 사용자에게 "다시 시도해주세요"를 안내해도 됩니다.

### 구버전 앱 전용 에러 (HTTP 406)

신버전 앱은 받을 일 없음. 구버전 앱이 기존 `POST /api/coupon` 호출 시에만 발생.

| HTTP | errorCode | 사용자 메시지 |
|------|-----------|-------------|
| 406 | CO_APP_UPDATE_REQUIRED | 앱 업데이트가 필요한 쿠폰이에요. |

---

## 주의사항

### 중복 탭 방지 / 등록 버튼 로딩 상태 (필수)

(2026-04-22 ISS-042 확정 — design-spec §"쿠폰 등록 버튼 로딩 상태" 참조)

- **등록 버튼**: 탭 즉시 **비활성화 + 회색 톤**으로 전환해 응답 수신(성공/실패)까지 유지.
  - 회색 톤은 기존 input empty 상태의 disabled 색상(`#C6C8CC` 배경 / `#EDEDEE` 텍스트)을 재사용 — 신규 색상 토큰 불필요.
  - **스피너/로딩 인디케이터 노출 금지** — 회색 비활성 톤 자체가 진행 상태 피드백.
- **레거시 예외 (후속 정합)**:
  - Web `couponCodeRegister.tsx`의 풀스크린 `<Loading />` 오버레이 → 제거 예정.
  - Android `CircularProgressIndicator(16dp)` (ISS-042 Android 해결본) → 제거하고 회색 비활성 톤만 유지로 정합.
  - iOS (ISS-042 미해결) → 본 확정대로 **스피너 미도입**, 비활성 + 회색 톤만 적용.
- register API는 쿠프마케팅 외부 API(L0+L1)를 내부 호출하므로 응답이 느릴 수 있음 (최대 15초).
- 중복 호출 시 과금/중복 발급 위험 → 반드시 클라이언트 상태 플래그(예: `isRegistering`)로 차단. throttle/debounce만으로는 부족.
- 응답 수신 후: 성공 → 입력 초기화 → empty 비활성으로 복귀 / 실패 → 입력 유지 → 활성 복귀.

### 쿠폰번호 형식

- **클라이언트에서 쿠폰 형식 판별 불필요** — 서버가 DB 기반 `coupon_prefix_rule`로 판별
- 기존 쿠폰과 카카오 상품권 모두 동일한 입력란 사용
- 붙여넣기 지원 필수 (카카오 선물하기에서 복사해오는 동선)

### 인증

- API는 `@Authorized()` (로그인 필수)
- **미로그인 처리 필수 (앱/웹 공통)**: 쿠폰 입력란 포커스 시 anonymous 체크 → 로그인 화면 이동 → 로그인 후 쿠폰 페이지 복귀 (S6 참조)
- 카카오 딥링크로 미로그인 상태에서 쿠폰 화면에 직접 진입할 수 있으므로 클라이언트에서 반드시 처리

### 딥링크

- 카카오 선물하기에서 쿠폰 화면으로 직접 랜딩하는 딥링크 지원 필요
- 딥링크 URL 스킴은 추후 확정

### Deprecated API

`POST /api/coop/check`, `POST /api/coop/use`는 Phase 1 기간 동안 기존 클라이언트 호환을 위해 유지되나 **신규 구현에서는 사용 금지**. Phase 2에서 제거됩니다.

### `POST /api/coupon` 기존 경로 중 계속 사용하는 것 (중요)

본 피쳐 해결 후에도 `POST /api/coupon`은 **couponSpecSeq 경로**로 신버전 클라이언트도 계속 호출합니다:

| 경로 | 용도 | 신버전 클라이언트 처리 |
|------|------|---------------------|
| `{ code }` (쿠폰 코드 등록) | SINGLE_CODE/MULTI_CODE | **금지** — `POST /api/coupon/register`로 이전 |
| `{ couponSpecSeq }` (배너 클레임) | DOWNLOAD | **계속 사용** — 변경 없음 |

배너 "쿠폰 받기" 버튼 등 `couponSpecSeq` 기반 클레임 플로우는 Phase 1에서도 변경 대상이 아닙니다. 해당 경로는 서버 가드에 발동되지 않습니다.

---

## 플로우 요약

```
[쿠폰 화면] ─ 코드 입력 ─ [등록]
     │
     ▼
POST /api/coupon/register (단일 호출, 서버가 종류 분류)
     │
     ├── 2xx issuedType: "coupon" ──→ 쿠폰 리스트 갱신 + (필요시) 토스트
     │
     ├── 2xx issuedType: "heart"  ──→ [S3 완료 팝업] → 프로필 탭
     │
     ├── 2xx issuedType: "skill"  ──→ 토스트 "스킬 이용권이 등록되었어요"
     │                                  │ 쿠폰 리스트에 이용권 카드 추가
     │                                  │ 카드 탭
     │                                  ▼
     │                             스킬 상세 (♥0) → 챗봇 채팅방
     │
     └── 4xx/5xx error ──→ [S5 에러 토스트] → 쿠폰 화면
```

---

## Changelog

| 날짜 | 변경자 | 변경 내용 | 확인 |
|------|--------|----------|------|
| 2026-04-22 | /design | **2026-04-22 사용자 결정 3건 반영** (design-spec.md와 동일 변경을 클라이언트 가이드에도 정합): (1) **ISS-031** S4 스킬 이용권 카드에 "카드 크기/여백 원칙" 추가 — 일반 쿠폰 카드와 동일 박스 높이·점선 하단 여백, 빈 요소는 공간 reserve(행 collapse 금지). iOS `flex.isIncludedInLayout = false` 전환 / Android `CouponItem.kt` 점검 / Web `CoopSkillVoucherItem.tsx` 수직 리듬 정합 지시. (2) **ISS-035** S3 일러스트 자산 정책 추가 — 재생되는 애니메이션 요건, 플랫폼별 기존 자산 재사용(iOS `imgHeartchargeComplete` Lottie, Android `img_heartcharge_completed.gif`, Web 탐색 예정), 신규 자산 발급 없음, 통일 강제 없음. (3) **ISS-042** "중복 탭 방지" 섹션을 "중복 탭 방지 / 등록 버튼 로딩 상태"로 확장 — 버튼 비활성 + 회색 톤만 허용, 스피너 금지(Web/Android 레거시 예외는 후속 정합), 기존 input disabled 색상 토큰 재사용. | 전파트 구현 반영 필요 / `/architect` 조율(architecture.md 영향 없음, 본 가이드·design-spec 동시 갱신으로 충분) |
| 2026-04-19 | /review 반영 | **설계 보완**: "`POST /api/coupon` 기존 경로 중 계속 사용하는 것" 섹션 추가 — couponSpecSeq 기반 배너 클레임은 신버전 클라이언트도 변경 없이 유지. code 경로만 `/register`로 이전. | 전파트 구현 예정 |
| 2026-04-19 | /architect | **전면 개편** (ISS-011, ISS-009 해결): 서버 단일 진입점 `POST /api/coupon/register` + 1단계 원샷 + `issuedType` 기반 UI 분기로 재작성. S2 확인 팝업 섹션 제거. 에러는 HTTP 표준 포맷(`{ error: { code, message } }`) 사용으로 통일. `CO_APP_UPDATE_REQUIRED`(HTTP 406) 구버전 앱 전용 에러 추가. `CM_010` 에러 매핑 추가 (ISS-012 동시 해소). CM_005 메시지를 api-spec과 동기화 "일시적인 서비스 오류가 발생했어요"로 통일 (ISS-013 동시 해소). `/api/coop/*` Deprecated 명시. | 전파트 구현 예정 |
| 2026-04-16 | /dev-android | design-spec과 불일치 항목 4건 수정: S3 이동 대상(내 하트→프로필 탭), S3 버튼(충전 확인하기→확인), S5 에러 팝업→에러 토스트, 힌트 텍스트(변경→기존 유지) | 사용자 확인 완료 |
| 2026-04-16 | /analyze | 기획 변경: S6 로그인 안내 팝업 → 로그인 화면 직접 이동으로 변경 (앱/웹 공통), 인증 섹션 업데이트 | |
