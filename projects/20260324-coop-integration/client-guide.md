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
    "code": "CM001",
    "message": "쿠폰을 찾을 수 없습니다"
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
  - Web — `/images/heart/heart_charge.gif` 재사용 (해결 완료 — ISS-035 웹 적용, ISS-051 비율 보정 2026-04-28). Next.js `<Image>`는 GIF 애니메이션 미지원 → plain `<img>` + breakout 래퍼 사용
- 자산 이름/경로/포맷의 플랫폼 간 통일을 강제하지 않음.

### S4. 스킬 이용권 등록 완료

응답 `issuedType === "skill"` 인 경우:
1. 쿠폰 입력란 초기화
2. 쿠폰 리스트 최상단에 **스킬 이용권 카드** 추가
3. 토스트: "스킬 이용권이 등록되었어요" (2.5초 후 자동 사라짐)
4. 헤더 쿠폰 수 +1 업데이트

**스킬 이용권 카드 렌더 분기 규칙 (클라이언트 공통, 2026-04-24 ISS-048 재정의)**

api-spec.md는 `GET /api/coupon` 응답의 `fixedMenuSeq`(단일 스킬 식별자, api-spec.md:249)와 `isUnlimited`(유효기간 무제한, api-spec.md:251) 두 필드를 **의미적으로 독립(orthogonal)**하도록 정의한다. 따라서 스킬 이용권 카드의 분기는 **두 종류로 나누어 적용**한다 (design-spec.md §S4와 정합):

1. **"스킬 이용권 상품 자체를 식별"하는 분기** — 판별 기준 `isUnlimited === true && fixedMenuSeq != null` (**AND**)
   - **"이용권" 배지 노출** (ISS-040)
   - **부가 설명 행 숨김 (invisible reserve)** (ISS-041/046)
   - 사유: "이 쿠폰이 스킬 이용권 상품 그 자체다"라는 의미론적 판단에 두 속성 모두 필요

2. **"개별 필드 속성에 반응"하는 분기** — 각 필드 **단독 조건** (api-spec.md 적용 규칙 §247-258 준수)
   - **만료일 / 만료임박 숨김**: `isUnlimited === true` 단독 (ISS-021/022) — 향후 "무제한 일반 쿠폰" 도입 시에도 자연 반응
   - **"스킬 보러가기" 링크 노출**: `fixedMenuSeq != null` 단독 (ISS-019/024/048) — 향후 "스킬 지정 + 유한 만료" 쿠폰 도입 시에도 스킬 상세 숏컷 유지

> ⚠️ 과거(~2026-04-23) "모든 분기 동일 기준(AND)" 서술은 ISS-040 배지 derive 문구의 과잉 일반화였으며, api-spec.md의 필드 독립성 계약과 모순이라 폐기. iOS/Android는 api-spec 규약 기반 구현으로 이미 정합, Web은 ISS-048로 `CouponItem`에 링크 단독 조건 분기 추가 완료(2026-04-24).

**스킬 이용권 카드 구성 요소**:
- 라벨: "이용권" 태그 — 회색, 흰 배경 (분기 1, AND)
- 할인율: "100%" (분홍 강조)
- 쿠폰명: 응답의 `skillName`
- 챗봇명: 미노출
- **부가 설명 행 (`description`)**: "N하트 이상 결제 시 사용 가능" 문구 자체가 의미 없으므로 **invisible reserve** — 시각적으로 숨기되 레이아웃 공간은 유지. 일반 쿠폰 카드와 동일 높이/수직 리듬. 스크린리더(TalkBack/VoiceOver)는 해당 행을 **읽지 않아야 함** (ISS-041/046, 분기 1 AND)
- 링크: "스킬 보러가기" (보라색, **하단 우측 정렬** — ISS-023)
  - **노출 조건**: `fixedMenuSeq != null` **단독** (분기 2, `isUnlimited`와 무관 — ISS-048 정합)
  - **i18n 문구 (ISS-047 확정)**: ko "스킬 보러가기" / en "View Skill" / ja "スキルを見る"
  - `>`는 **텍스트에 포함하지 않음** — chevron 이미지(iOS `SF Symbol chevron.right`, Android/Web 대응 벡터, violet400 틴트)로 분리 렌더 (ISS-027 해결 정합)
  - 선택 모드(iOS CouponSelect 등) 화면에서는 노출 억제
- 카드 탭 또는 링크 탭 → 스킬 상세 페이지 이동 (`fixedMenuSeq` 사용)

**부가 설명 행 구현 가이드 (invisible reserve, 플랫폼별)**

| 플랫폼 | 구현 방식 | 접근성 |
|--------|-----------|--------|
| Web | Tailwind `invisible` (또는 CSS `visibility: hidden`). `display: none` **금지** (카드 높이 축소됨). | `visibility: hidden`은 기본적으로 스크린리더가 읽지 않음. 추가 `aria-hidden` 불필요. |
| Android (Compose) | `Modifier.alpha(0f)` + `Modifier.clearAndSetSemantics { }` 체이닝 | `alpha(0f)` 단독은 TalkBack이 여전히 읽으므로 `clearAndSetSemantics` 필수 |
| iOS (UIKit) | `descriptionLabel.isHidden = true`. FlexLayout 사용 시 `flex.isIncludedInLayout`는 **`true` 유지** (기본값, `isHidden`만으로는 레이아웃에서 제외되지 않음). | `isHidden = true`면 VoiceOver 자동 제외 |

> ⚠️ **`display: none` / `flex.isIncludedInLayout = false` (collapse) 방식 금지**. 카드 높이가 축소되어 쿠폰함에서 일반 쿠폰과 섞여 렌더 시 수직 리듬이 어긋남. iOS ISS-041에서 한시적으로 collapse 방식이 적용되었으나 2026-04-23 재조정으로 reserve 전환 완료 (본 스펙과 정합).

**만료일/만료임박 표시 분기 (ISS-021/022, ISS-048 정합)** — `isUnlimited` **단독** 조건으로 판정 (분기 2, 개별 속성 반응):
- `GET /api/coupon` 응답 `coupon.isUnlimited === true`이면 카드에서 **만료일 행 + 만료임박 "N일 남음" 뱃지 모두 미표시** (점선 구분선도 숨김 권장)
- `isUnlimited`가 없거나 `false`이면 기존 일반 쿠폰 UI 유지 (만료일 + `remainDays < 6` 시 만료임박 배지)
- ⚠️ **sentinel 문자열(`2099-12-31T23:59:59.000Z`) 직접 비교 금지** — 추후 sentinel 값이 변경될 수 있으므로 반드시 `isUnlimited` 플래그로만 분기할 것
- `fixedMenuSeq`와 결합 판정하지 않음 — 향후 "무제한 일반 쿠폰"(스킬 지정 없음)이 도입되어도 만료일이 자연스럽게 숨겨지도록 한다
- 참고: 스킬 이용권은 발급 시 서버가 `isUnlimited: true`를 내려주며, `expiresAt`은 호환성 확보 위한 sentinel 날짜 값임 (null 아님)

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
| 400 | CM001 | 쿠폰을 찾을 수 없습니다 |
| 400 | CM002 | 만료된 쿠폰입니다 |
| 400 | CM003 | 이미 사용된 쿠폰입니다 |
| 400 | CM005 | 일시적인 서비스 오류가 발생했습니다 |
| 400 | CM010 | 결제가 취소된 쿠폰입니다 |
| 404 | CM004 | 상품을 찾을 수 없습니다 |
| 500 | CM006 | 일시적인 통신 오류가 발생했습니다 |
| 500 | CM007 | 하트 충전에 실패했습니다 |
| 500 | CM008 | 스킬 이용권 발급에 실패했습니다 |
| 500 | CM009 | 쿠폰 정보를 찾을 수 없습니다 |

> CM007, CM008 발생 시 서버가 자동으로 쿠프마케팅 승인 취소(L2)를 시도합니다. 쿠폰이 원복되므로 사용자에게 "다시 시도해주세요"를 안내해도 됩니다.

### 구버전 앱 전용 에러 (HTTP 406)

신버전 앱은 받을 일 없음. 구버전 앱이 기존 `POST /api/coupon` 호출 시에만 발생.

| HTTP | errorCode | 사용자 메시지 |
|------|-----------|-------------|
| 406 | CO012 | 앱을 최신 버전으로 업데이트 해주세요 |

---

## 주의사항

### 중복 탭 방지 / 등록 버튼 로딩 상태 (필수)

(2026-04-22 ISS-042 확정 — design-spec §"쿠폰 등록 버튼 로딩 상태" 참조)

- **등록 버튼**: 탭 즉시 **비활성화 + 회색 톤**으로 전환해 응답 수신(성공/실패)까지 유지.
  - 회색 톤은 기존 input empty 상태의 disabled 색상(`#C6C8CC` 배경 / `#EDEDEE` 텍스트)을 재사용 — 신규 색상 토큰 불필요.
  - **스피너/로딩 인디케이터 노출 금지** — 회색 비활성 톤 자체가 진행 상태 피드백.
- **레거시 예외 (후속 정합)**:
  - Web `couponCodeRegister.tsx`의 풀스크린 `<Loading />` 오버레이 → 제거 완료 (2026-04-22). 단, 동시 도입된 버튼 내 인라인 스피너(`animate-spin`)는 본 정책(스피너 금지)과 미정합 — 후속 정합 대상.
  - Android `CircularProgressIndicator(16dp)` (ISS-042 초기 해결본) → 2026-04-23 rollback으로 제거 완료, 회색 비활성 톤만 유지 (본 정책 정합).
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
| 2026-06-10 | 코디네이터 | **PR #2 머지 — 4/23 세션 잔여분 통합**: (1) ISS-035 일러스트 자산 정책 + ISS-042 등록 버튼 로딩 규칙(4/22 사용자 결정) 문구를 본 가이드에 반영 (구현·design-spec에는 존재했으나 본 문서에 누락). (2) ISS-031 카드 크기/여백 원칙 구버전 블록은 4/24 invisible reserve 명문화가 우선하므로 미반영. (3) 4/22 시점 표현 현행화 — ISS-035 웹 자산 `/images/heart/heart_charge.gif` 확정(ISS-051), ISS-042 Android rollback 완료·웹 인라인 스피너 미정합 잔존 명시. | 구현 변경 없음 (문서 정합) |
| 2026-04-28 | /dev-server | **ISS-050 코드 컨벤션 정합화** — §에러 매핑표(line 230~241) `CM_001~CM_010` → `CM001~CM010`, ko 메시지 어미 "~이에요" → "~습니다". `CM001`/`CM002`/`CM003`은 `CP001`/`CP003`/`CP002` 문구 그대로 채택. §구버전 앱 전용 에러(line 251) `CO_APP_UPDATE_REQUIRED` → `CO012(UPDATE_APP)` 통합 + 메시지 갱신("앱을 최신 버전으로 업데이트 해주세요"). 본문 응답 예시(line 102~103) 동기 갱신. iOS 매퍼 동기 + 클라이언트 회귀 후속. | iOS (/dev-ios) 매퍼 동기 대기 |
| 2026-04-24 | /architect | **S4 스킬 이용권 카드 렌더 분기 규칙 재정의 (ISS-048, design-spec.md §S4 정합)**: 기존 "스킬 이용권 카드 판별 기준 — 모든 분기 동일 AND 기준" 선언을 폐기하고 **2종 분기 구조**로 재작성. (1) 상품 자체 식별 분기(배지 ISS-040 / 부가설명 ISS-041·046): `isUnlimited && fixedMenuSeq != null` **AND**. (2) 개별 속성 반응 분기(만료일 ISS-021·022: `isUnlimited` 단독 / 링크 ISS-019·024·048: `fixedMenuSeq != null` 단독). api-spec.md의 두 필드 독립 계약(§247-258)과 정합. 링크 구성 요소 설명에 "노출 조건: `fixedMenuSeq != null` 단독" 명시 추가. 만료일 분기 블록 제목을 "isUnlimited 단독" 명시로 개정 + "fixedMenuSeq와 결합 판정 금지" 주석 추가. iOS/Android는 기존 구현이 재정의된 규칙과 이미 정합(코드 무수정), Web은 ISS-048 해결(2026-04-24)로 `CouponItem`에 링크 단독 조건 분기 추가 완료. | 전파트 구현 정합 확인 완료 |
| 2026-04-24 | /architect | **S4 스킬 이용권 카드 판별 기준 + 부가 설명 행 처리 규칙 명문화 (ISS-041/046 정합)**: (1) §S4에 "스킬 이용권 카드 판별 기준: `isUnlimited === true && fixedMenuSeq != null`" 단일 소스 선언(모든 스킬 이용권 분기 공통). (2) "부가 설명 행(description)"을 **invisible reserve**로 규정 — 문구 숨김 + 공간 유지 + 스크린리더 차단. (3) 플랫폼별 구현 가이드 표 신규 — Web `invisible`, Android `Modifier.alpha(0f) + clearAndSetSemantics`, iOS `isHidden = true`(FlexLayout `isIncludedInLayout` **유지**). (4) collapse 방식(`display:none` / `flex.isIncludedInLayout=false`) 금지 경고. 3 플랫폼 모두 reserve로 구현 완료 상태(Web ISS-031, Android ISS-046, iOS ISS-041 재조정 2026-04-23) — 본 변경은 사후 명문화. ※ 본 항목의 "판별 기준: 단일 소스(AND)" 선언은 2026-04-24 재정의(ISS-048)로 폐기 — 본 Changelog 상위 항목 참조 | 전파트 구현 정합 확인 완료 |
| 2026-04-23 | /analyze | S4 "스킬 보러가기 >" 링크 i18n 문구 3종 확정 명시 (ISS-047): ko "스킬 보러가기" / en "View Skill" / ja "スキルを見る". `>`는 텍스트 포함 금지 — chevron 이미지(ISS-027 해결 정합)로 분리 렌더 원칙 추가. Android는 기존 `coop_link_view_skill` 3종 대응 완료, iOS는 ISS-047 과업으로 대응 필요 | iOS (/dev-ios) 구현 대기 |
| 2026-04-22 | /design | **2026-04-22 사용자 결정 3건 반영** (design-spec.md와 동일 변경을 클라이언트 가이드에도 정합): (1) **ISS-031** S4 스킬 이용권 카드에 "카드 크기/여백 원칙" 추가 — 일반 쿠폰 카드와 동일 박스 높이·점선 하단 여백, 빈 요소는 공간 reserve(행 collapse 금지). iOS `flex.isIncludedInLayout = false` 전환 / Android `CouponItem.kt` 점검 / Web `CoopSkillVoucherItem.tsx` 수직 리듬 정합 지시. (2) **ISS-035** S3 일러스트 자산 정책 추가 — 재생되는 애니메이션 요건, 플랫폼별 기존 자산 재사용(iOS `imgHeartchargeComplete` Lottie, Android `img_heartcharge_completed.gif`, Web 탐색 예정), 신규 자산 발급 없음, 통일 강제 없음. (3) **ISS-042** "중복 탭 방지" 섹션을 "중복 탭 방지 / 등록 버튼 로딩 상태"로 확장 — 버튼 비활성 + 회색 톤만 허용, 스피너 금지(Web/Android 레거시 예외는 후속 정합), 기존 input disabled 색상 토큰 재사용. | 전파트 구현 반영 필요 / `/architect` 조율(architecture.md 영향 없음, 본 가이드·design-spec 동시 갱신으로 충분) |
| 2026-04-21 | /analyze | S4 스킬 이용권 카드에 "만료일/만료임박 표시 분기" 섹션 추가 (ISS-021/022): `isUnlimited === true`이면 만료일 + 만료임박 배지 + 점선 구분선 모두 숨김. sentinel 문자열 직접 비교 금지 경고. "스킬 보러가기 >" 링크 하단 우측 정렬 필수(ISS-023) 명시 | iOS/Android/Web 구현 완료 |
| 2026-04-19 | /review 반영 | **설계 보완**: "`POST /api/coupon` 기존 경로 중 계속 사용하는 것" 섹션 추가 — couponSpecSeq 기반 배너 클레임은 신버전 클라이언트도 변경 없이 유지. code 경로만 `/register`로 이전. | 전파트 구현 예정 |
| 2026-04-19 | /architect | **전면 개편** (ISS-011, ISS-009 해결): 서버 단일 진입점 `POST /api/coupon/register` + 1단계 원샷 + `issuedType` 기반 UI 분기로 재작성. S2 확인 팝업 섹션 제거. 에러는 HTTP 표준 포맷(`{ error: { code, message } }`) 사용으로 통일. `CO012`(HTTP 406) 구버전 앱 전용 에러 추가. `CM010` 에러 매핑 추가 (ISS-012 동시 해소). CM005 메시지를 api-spec과 동기화 "일시적인 서비스 오류가 발생했어요"로 통일 (ISS-013 동시 해소). `/api/coop/*` Deprecated 명시. | 전파트 구현 예정 |
| 2026-04-16 | /dev-android | design-spec과 불일치 항목 4건 수정: S3 이동 대상(내 하트→프로필 탭), S3 버튼(충전 확인하기→확인), S5 에러 팝업→에러 토스트, 힌트 텍스트(변경→기존 유지) | 사용자 확인 완료 |
| 2026-04-16 | /analyze | 기획 변경: S6 로그인 안내 팝업 → 로그인 화면 직접 이동으로 변경 (앱/웹 공통), 인증 섹션 업데이트 | |
