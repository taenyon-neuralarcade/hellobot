# TODO-037 iOS 2.52.0 해외 사용자 앱 실행 오류 (카카오 선물하기 릴리즈)

**유형**: 액션
**상태**: ✅ **완료 (2026-06-01 — 경문님 처리)**
**등록**: 2026-05-27
**시작**: 2026-05-27
**완료**: 2026-06-01
**마감**: - (자체 해결 가능성 있음 — 1차 원인 분석 후 결정)
**담당**: /dev-ios 위임 (분석)
**관련**: [TODO-004 카카오 선물하기 1차 출시](TODO-004-kakao-gift-launch.md) / [TODO-013 카카오 핫픽스 잔여](TODO-013-kakao-hotfix-residual.md)
**중요도**: ⭐⭐ 높음 (운영·해외 사용자 영향, 단 신규 리뷰 없음으로 자체 해결 가능성)

## 컨텍스트

### 사용자 요청 원문 (2026-05-27)

> iOS 카카오 선물하기 업데이트. 릴리즈 2.52.0 버전부터 해외 사용자는 앱 실행시 오류 메시지 뜨면서 사용안됨
>
> 아이폰
> 앱 버전: 2.52.0 (카카오 선물하기 쿠폰 등록기능 추가)
>
> 해외 거주자로부터 서비스 이용이 되지 않는다는 앱스토어 리뷰가 등록되었습니다.
> 테스트플라이트 2.52.0버전과 마켓 최신 버전에서 기기 지역 설정을 해외로 바꾸고 앱 테스트중인데 저는 정상적으로 진행이 됩니다.
> 최신 버전도 출시되었고, 5/23일 이후 신규 리뷰가 없어서 자체 해결되었는지는 모르겠지만 우선은 제보 남겨둡니다!

### 배경 / 정황

- **릴리즈 버전**: iOS 2.52.0 — 카카오 선물하기 쿠폰 등록 기능 추가 (TODO-004 1차 출시 산출물)
- **증상**: 해외 사용자가 앱 실행 시 오류 메시지가 뜨면서 사용 불가
- **재현 상태**:
  - 사용자(기획자) 측: 기기 지역 설정을 해외로 변경하여 TestFlight 2.52.0 / 마켓 최신 버전 둘 다 테스트 → **재현 안 됨 (정상 동작)**
  - 앱스토어 리뷰: 해외 거주자로부터 제보 1건 이상
- **추세**: 5/23 이후 신규 리뷰 없음 → 자체 해결 또는 후속 릴리즈에서 해소된 가능성
- **제보 시점**: 5/23 이전 (정확한 날짜 미상)
- **현재 마켓 버전**: 2.52.0 이후 후속 버전이 이미 출시됨 (어떤 버전인지 dev-ios 확인 필요)

### 의심 가능 영역 (가설, dev-ios 분석 전)

해외 사용자에게만 발생하는 패턴이라면 다음 영역을 의심해볼 수 있음:

- **Locale / 지역 설정 의존 로직** — 카카오 선물하기 쿠폰 등록 기능이 한국어 또는 KR locale 가정 코드를 포함했을 가능성
- **네트워크 / API 지역 제한** — 해외 IP 에서 차단되는 API 호출 (카카오/CDN/내부 API)
- **결제·통화 관련 초기화** — 해외 통화 환경에서 SKU 또는 가격 정보 로딩 실패
- **푸시 / Firebase / 광고 SDK** — 지역 제한이 있는 외부 SDK 초기화 실패
- **시간대 / 날짜 파싱** — KST 가정 코드가 다른 timezone 에서 깨지는 경우

다만 자체 재현이 안 되는 상태라 가설 단계. dev-ios 가 2.52.0 릴리즈 diff 와 후속 버전 diff 를 함께 보고 원인 후보를 좁혀야 함.

### 관련 정보

- **2.52.0 릴리즈 노트**: 카카오 선물하기 쿠폰 등록 기능 추가 (TODO-004 1차 출시 항목)
- **앱스토어 리뷰**: 사용자가 원본 리뷰 텍스트 보유 가능성 — 필요 시 추가 요청
- **TestFlight 환경**: 사용자 측은 정상 동작 확인 완료
- **리포**: `hellobot_iOS` (메인 브랜치: `develop`, Swift / ReactorKit / RxSwift / Tuist)

## 현재 상태

**홈 원인 식별 — `featuredSkillsTabs` 섹션 (2026-05-28, dev-server)**. 높은 확신. 다른 3개 화면은 별개 가능.

### 홈 화면 근본 원인 (높은 확신)

- **`featuredSkillsTabs` 홈 섹션** (PR #2414, **5/18 운영 배포**, 프로젝트 `20260511-home-rank-skill-section`)
- 노출 조건 ([home.ts:186-225](hellobot-server/src/services/home.ts:186)): 버전게이트(iOS≥2.54.0/Android≥2.43.0/web) AND FeatureFlag `featured-skills-tabs` ON AND (public off→UserTestGroup 테스터만 / public on→Hackle 실험 "B" treatment 버킷)
- 조건 만족 클라가 받는 섹션(`tabs:[{targetSection, showRanking,...}]`) 디코드 실패 → 홈 `CommonResponse` 전체 throw → 홈 빈 화면 + "일시적인 오류" (iOS·Android 동시, 서버 구동)
- **미스터리 전부 설명**: "일시적"=A/B·테스터 버킷만 / 기획자 재현 불가=control 버킷·테스터 미등록 / "해외"=A/B 버킷팅 착시 / force-quit마다=테스터면 결정적 노출+cold start 홈 재요청
- **계약 드리프트 정황**: 섹션 shape가 5/18 하루 4번 변경 (Create→Alter→Rename rankSkills→featuredSkillsTabs→AddShowRanking). iOS 2.54.0 빌드가 이른 shape로 컷됐으면 현 서버 직렬화와 불일치

### 즉시 완화책 (앱 릴리즈 불필요·가역·~1분)

운영 FeatureFlag **`featured-skills-tabs` → `isActivated=false`** → masterEnabled=false → 섹션 제외 → 전 유저 홈 즉시 복구 (캐시 TTL 1분, [feature-flag.ts:16](hellobot-server/src/services/feature-flag.ts:16)). **운영 데이터 변경 — 사용자 확인 후 진행.**

### 확인 필요

1. 운영 `featured-skills-tabs` / `featured-skills-tabs-public-enabled` 플래그 현재 상태
2. 재현 기기 정확한 iOS 버전 (2.54.0이면 게이트 통과 정상. <2.54.0에서도 홈 터지면 버전게이트 누수 = 더 큰 버그)
3. 재현 계정이 UserTestGroup 등록 or Hackle "B" 버킷인지
4. 재현 기기 홈 응답 raw JSON → featuredSkillsTabs 포함 + 디코드 codingPath

### 다른 3개 증상 (별개 가능)

iOS 채팅방 / Android 친구목록 / iOS 챗봇 상세 스킬목록 = 홈 섹션 아님 → featuredSkillsTabs로 설명 안 됨. 플래그 끈 뒤 재테스트 → 남으면 화면별 raw JSON + codingPath 별도 추적 (스킬 썸네일 A/B `newSkillBannerImageUrl` 등 공유 스킬필드 의심).

---

**(참고) 원인 재규정 — 서버 응답 디코딩 실패 (2026-05-28 오후, 에러 화면 공유 후)**. cold-start serviceCheck/exit(0) 가설 폐기. 메커니즘 분석은 아래 유지:

### 증상 (사용자 공유, 스크린샷 2장)

- 홈 화면: "일시적인 오류입니다 / 잠시 후 다시 시도" + 디버그 토스트 **"올바른 포맷이 아니기 때문에 해당 데이터를 읽을 수 없습니다"** (iOS·Android 둘 다, 콘텐츠 로드 실패)
- iOS 채팅방 진입: "어머나! 뭔가 잘못되었어요!" 토스트 (Android 미발생)
- Android 친구들 목록: "문제가 발생했어요!" 토스트 (iOS 목록 미발생)
- iOS 챗봇 상세: **스킬 보유 챗봇만 오류, 스킬 없으면 정상** → 스킬 목록 디코드 지점

### 진단 (dev-ios)

- "올바른 포맷이 아니기 때문에..." = 코드 문자열 아님 = **OS 가 주는 `DecodingError` 로컬라이즈 메시지** → JSON 디코딩 실패 100% 확정
- `RequestBuilder.decode` 가 `CommonResponse<T>` 를 통째로 디코드 → **필드 1개만 깨져도 응답 전체 throw** → handleError 가 에러 화면/토스트 ([RequestBuilder.swift:95](hellobot_iOS/Modules/Service/ThingsNetwork/ThingsNetwork/RequestBuilder/RequestBuilder.swift:95))
- 공통분모 = **스킬(skill)/쿠폰 데이터**. 스킬 들어간 모든 화면 동시 붕괴와 정확히 일치
- **릴리즈 앱은 불변 → 잘 되다 깨졌으면 서버가 응답 포맷을 바꾼 것.** 시점(5/21~22)·증상이 `skill-coupon-product-sync-hotfix(20260521)`/카카오 선물하기 출시와 정렬

### 디코드 지뢰 (클라 필수 필드)

- **FixedMenu**(홈/목록): `type: FixedMenuType`(enum, 필수) — 서버 신규 메뉴타입값 시 폭발 / `price`·`rating` 등은 `decodeIfPresent` 라도 **키 있는데 타입 다르면 throw**
- **SkillCoupon**(상세/스킬목록): 필수 `expiresAt`(ISS-022 non-null)·`discountGap`·`isMaxDiscount` + enum `platform`/`discountType`(신규값 시 throw). expiresAt 은 최근 nullable↔non-null 두 번 뒤집힘(ISS-021→022)

### 범위 재정의

iOS 단독 아님 — **iOS + Android 동시 + 서버 원인**. `/dev-server` 주도 점검 필요, Android/web 영향 확인, `20260521-skill-coupon-product-sync-hotfix` 통합 또는 프로젝트 승격 권장.

---

**(폐기) 로그 기반 검증 단계 (2026-05-28 오전)** — cold-start serviceCheck 가설용. 아래 유지하나 본 건과 무관 판명:

### 새 재현 정보 (2026-05-28, 사용자)

- **최신 마켓 릴리즈에서도 동일 현상 재현** (2.52.0 한정 아님) → "2.52.0 신규 + stale CDN 캐시" 한정 설명만으로는 부족
- **앱 완전 종료(force-quit) 후 재실행 시 "바로" 발생** = cold start 트리거. 백그라운드 복귀(warm)에선 미발생 추정

### dev-ios 판단 (2026-05-28)

- cold-start-only 증상은 `MainTabBarController.bindServiceCheck` 의 `rx.viewWillAppear.take(1)` 경로와 **정확히 일치** (탭바 생명주기당 1회 = cold start 한정). serviceCheck → `exit(0)` 경로 가능성 ↑. 단 에러 원문 미확인이라 로그로 확정 필요
- **로그 캡처 핵심 난점**: force-quit 시 디버거 detach → 일반 재실행 시 `print()` 안 보임
  - 방법 A (로컬 재현 가능 시 최속): Xcode scheme → Run → Info → Launch **"Wait for the executable to be launched"** → 아이콘 직접 탭 = 디버거 붙은 cold start
  - 방법 B (Release/TestFlight/디버거 없이): `os.Logger(subsystem:category:)` + 맥 Console.app subsystem 필터
- **★ 최우선 로그 2개**:
  1. `checkServiceCheck()` 의 `.filter { $0.showMessage }` 직전 — 요청 URL + HTTP status + raw 응답 body + 디코드된 showMessage/title/message/date
  2. `handleExitApp()` 의 `exit(0)` 직전 — 뜨면 점검 alert + 강제종료 100% 확정
- 추가 breadcrumb: AppDelegate didFinishLaunching 각 SDK init 경계 + return true / viewDidLoad 각 bind 후 / bindServiceCheck 발화 시점 / presentMaintenanceAlertController show 직전
- **빌드 전 최저비용 단서**: 재현된 에러 다이얼로그 스크린샷 확보 (점검 alert vs 시스템 alert vs 토스트 vs 빈 화면 → 출처 절반 즉시 거름)
- 판단 트리: handleExitApp 로그 뜸 → 백엔드/CDN(globalconfig.json) 사안 (`/dev-server`·`/dev-infra`) / 안 뜨는데 에러 뜸 → 마지막 breadcrumb 이 범인

---

**이전 1차 식별 (2026-05-27, VPN 미국 재현 확인 후)** — 아래 유지 (로그로 재확정 대상):

**`GlobalConfigManager.checkServiceCheck()` 가 받는 `serviceCheck.showMessage == true` 응답으로 Alert 노출 + `exit(0)` 강제 종료**

- 호출 흐름: `MainTabBarController.viewDidLoad` (line 51) → `bindServiceCheck` (line 273) → `viewWillAppear.take(1) + delay(500ms)` → `GlobalConfigManager.shared.checkServiceCheck()` → `GET {GLOBAL_CONFIG_URL}/globalconfig.json` → 응답 `serviceCheck.showMessage == true` 이면 Alert + 확인 시 `exit(0)`
- 메시지 출처: **앱 하드코딩 아님**. 서버 응답 `serviceCheck.{title, message, date}` 동적 표출
- API: `GET https://platform.thingsflow.com/hlb/prod/globalconfig.json` (운영) / `.../hlb/dev/...` (베타)
- 2.52.0 신규 이슈 아님 — 이 코드는 2.24.2 (2024-01-31) 부터 존재. **VPN 미국에서만 재현되는 이유는 백엔드/CDN 측 응답 분기 또는 stale 캐시**

→ 결론 **(b)** 으로 변경: 진짜 핫픽스 필요. 단 **iOS 코드 핫픽스가 아니라 백엔드/인프라 (CDN, globalconfig.json 운영) 확인이 1차**

## 다음 단계

- [ ] **(긴급) 홈 완화 — `featured-skills-tabs` 플래그 OFF**: 운영 DB/AdminJS 에서 isActivated=false → 홈 즉시 복구 (~1분). **사용자 확인 후 진행** (운영 데이터 변경). 끄기 전 현재 ON 여부·public 플래그 상태 확인
- [ ] **(검증) 재현 환경 확정**: 재현 기기 iOS 버전(2.54.0?) + 계정의 UserTestGroup/Hackle 버킷 + 홈 raw JSON 에 featuredSkillsTabs 포함 여부
- [ ] **(서버↔클라 정합) /dev-ios 재호출**: iOS 2.54.0 의 featuredSkillsTabs 섹션 디코드 모델이 현 서버 shape(targetSection/showRanking/tabs)와 일치하는지. 불일치면 클라 디코드 resilient 처리 or 서버 버전게이트 상향
- [ ] **(별개) 나머지 3화면**: 플래그 OFF 후 재테스트 → 잔존 시 화면별 raw JSON + codingPath
- [ ] **(이관) 프로젝트화**: iOS+Android+서버 동시 운영장애 → 20260511-home-rank-skill-section 핫픽스 트랙 or 신규 프로젝트
- [ ] **(참고) 결정타 — 실패 응답 raw JSON + `DecodingError.codingPath` 확보**: 챗봇 상세 스킬 목록 API(스킬 보유=실패/미보유=정상 대조군)를 Proxyman/Charles 캡처 → 모델 디코드 → codingPath 가 범인 필드 지목. 또는 워크트리에서 [RequestBuilder.swift:69](hellobot_iOS/Modules/Service/ThingsNetwork/ThingsNetwork/RequestBuilder/RequestBuilder.swift:69) catch 에 DecodingError 상세 + raw body 로그
- [ ] **(2) 서버 직렬화 변경 점검 — `/dev-server`**: 5/20~5/22 skill/product/coupon 응답 필드 추가/제거/타입변경/enum 신규값. `skill-coupon-product-sync-hotfix(20260521)` 디플로이 1순위 의심
- [ ] **(3) 범위·이관 결정 — 코디네이터/사용자**: iOS+Android+서버 동시 영향. `20260521-skill-coupon-product-sync-hotfix` 통합 또는 프로젝트 승격. Android/web 영향 범위 확인
- [ ] **(참고) 디코드 지뢰 대조**: FixedMenu `type`(enum)·타입변경 필드 / SkillCoupon `expiresAt`·`discountGap`·`isMaxDiscount`·`platform`·`discountType`
- [ ] **백엔드/인프라 위임** — `/dev-server` 또는 `/dev-infra`:
  - `platform.thingsflow.com` 호스팅 인프라 (S3 + CloudFront 추정) 확인
  - 미국 region edge cache invalidate
  - globalconfig.json 최근 변경 이력 (5/22 카카오 출시 전후) 확인 — 점검 안내 임시 표출 가능성
  - 미국 IP 응답 정상화 후 사용자에게 회신 + 5/23 이후 신규 리뷰 없음의 의미 보강 (CDN TTL 자연 만료로 점진적 회복했을 가능성)
- [ ] **장기 권고 (코디네이터/사용자 결정)** — `exit(0)` 강제 종료 흐름의 UX 위험 검토:
  - globalconfig.json 가 잘못 표출되면 모든 사용자가 앱 종료당함 (Kill switch). 점검 알림 dismiss 후 재시도 가능 흐름으로 개선 검토 → 별도 백로그/improvement TODO 등록 권장

## 코드 위치 (요약)

- 호출: [Hellobot/MainTabBarController/MainTabBarController.swift:51,273-279](hellobot_iOS/Hellobot/MainTabBarController/MainTabBarController.swift)
- Manager: [Hellobot/Manager/GlobalConfigManager/GlobalConfigManager.swift:49,78,106](hellobot_iOS/Hellobot/Manager/GlobalConfigManager/GlobalConfigManager.swift)
- Builder: [Hellobot/Network/GlobalConfig/GlobalConfigRequestBuilder/GlobalConfigRequestBuilder.swift](hellobot_iOS/Hellobot/Network/GlobalConfig/GlobalConfigRequestBuilder/GlobalConfigRequestBuilder.swift)
- 모델: [Hellobot/Model/GlobalConfig/ServiceCheck.swift](hellobot_iOS/Hellobot/Model/GlobalConfig/ServiceCheck.swift) (`showMessage: Bool`, `title/message/date: String?`)
- URL 설정: [Config/Hellobot-Shared.xcconfig:59](hellobot_iOS/Config/Hellobot-Shared.xcconfig) (`https://platform.thingsflow.com/hlb/prod`)

## 진행 로그 추가

- 2026-05-27 — VPN 미국 재현 확인. dev-ios 재호출. **단일 원인 식별 완료** — `globalconfig.json` 의 `serviceCheck.showMessage` 응답으로 인한 Alert + `exit(0)`. 2.52.0 신규 이슈 아니라 백엔드/CDN 측 응답 분기 또는 stale 캐시 사안. 다음 단계 = `/dev-server` 또는 `/dev-infra` 위임.

## 진행 로그

- 2026-06-01 — ✅ **완료**. 경문님이 처리 완료 (2026-06-02 사용자 보고). 상세 처리 내용은 경문님 측 기록 참조. TODO 종료.
- 2026-05-28 (오후 3) /dev-server — **홈 화면 원인 식별 (높은 확신)**: `featuredSkillsTabs` 홈 섹션(PR #2414, 5/18 운영 배포) 디코드 실패. 버전게이트(iOS≥2.54.0/Android≥2.43.0)+FeatureFlag `featured-skills-tabs`+Hackle A/B(또는 UserTestGroup 테스터) 노출 → A/B 버킷팅이 "일시적"·"기획자 재현불가"·"해외 착시" 전부 설명. 섹션 shape가 5/18 4번 변경(rankSkills→featuredSkillsTabs+showRanking)된 계약 드리프트 정황. **즉시 완화 = featured-skills-tabs 플래그 OFF (앱 릴리즈 불필요, ~1분 복구). 운영 변경이라 사용자 확인 대기.** 나머지 3화면(채팅방/친구목록/챗봇상세)은 홈 섹션 아님 → 별개 가능, 플래그 OFF 후 재테스트 필요. 로컬 hellobot-server master 가 stale(origin/master 에 featuredSkillsTabs 존재) — 분석은 origin/master 기준.
- 2026-05-28 (오후 2) — 에러 화면 스크린샷 2장 + 발생 위치 4종 공유 (홈/iOS채팅방/Android친구목록/iOS챗봇상세). dev-ios 분석: **서버 응답 JSON 디코딩 실패**로 원인 재규정 (OS DecodingError 메시지 확인). CommonResponse 통째 디코드라 필드 1개로 전체 throw. 공통분모=스킬/쿠폰, 릴리즈 앱 불변→서버 포맷 변경 추정. skill-coupon-product-sync-hotfix(20260521)/카카오 출시와 정렬. 디코드 지뢰(FixedMenu.type enum, SkillCoupon expiresAt/discountGap/isMaxDiscount/platform/discountType enum) 식별. **다음 결정타 = 실패 raw JSON + DecodingError codingPath. 원인 위치는 서버 → /dev-server 위임 필요. iOS+Android 동시라 범위 재정의·이관 결정 필요.**
- 2026-05-28 (오후) — 사용자: **에러 문구가 초기 실행 외 여러 곳에서도 발견됨**. 정리해 공유 예정. → cold-start serviceCheck/exit(0) 단일 경로 가설 약화. 여러 플로우 공유 에러 출처(공통 에러 핸들러 / 서버 응답 표출) 가능성. **다음 액션: 사용자가 (1) 에러 문구 원문 (2) 각 문구 발화 위치 공유 → dev-ios 가 해당 문자열 코드 grep 으로 공통 출처 직격 (로그보다 우선).** 계측 빌드는 보류.
- 2026-05-28 — 사용자 새 재현 정보 2건 (최신 릴리즈도 재현 / force-quit 후 즉시 = cold start). 코드 가설 대신 로그 계측 방침으로 전환. /dev-ios 가 cold-launch 로그 캡처 방법(방법 A/B) + ★ 로그 2개 위치 + 판단 트리 제시. cold-start-only 증상이 take(1) serviceCheck→exit(0) 경로와 일치함을 확인. 워크트리 생성·계측 빌드는 사용자 승인 대기.
- 2026-05-27 — 사용자 제보 접수. TODO-037 등록 (⭐⭐ 높음). /dev-ios 분석 요청 진행.
- 2026-05-27 /dev-ios — 코드 변경 이력 기반 1차 분석 완료. 결론: **(c) 추가 정보 필요 → 사용자 재요청 권고**. 상세 ↓

### /dev-ios 분석 결과 (2026-05-27)

#### 1) 2.52.0 신규 변경 영역 식별

`origin/release/2.52.0 ^origin/main` 의 신규 커밋 흐름 (시간순):

| 커밋 | 내용 | 영역 |
|------|------|------|
| `603a6c863` (4/20) | 카카오 쿠폰 등록 Phase 1 단일 진입점 전환 | 카카오 선물하기 (메인 기능) |
| `c5a324949` ~ `7458d3917` | 쿠폰 등록 QA 피드백 일괄 반영 (ISS-019 ~ ISS-050) | 카카오 선물하기 |
| `99000cbbb` | 카카오 쿠폰 등록 Firebase 이벤트 3종 + D1~D5 스펙 픽스 | 카카오 선물하기 |
| `e48634129` (4/30) | 마케팅 버전 2.52.0 | 메타 |
| `0ac0c7976` | 홈 섹션 섬네일 A/B 및 Hackle 이벤트 (#1415) | Hackle A/B 운영 시작 |
| `df06b905f` → `e850f43ed` (5/8) | LoginViewController 강참조 cycle 차단 (ISS-057) PR #1416 | 로그인 회로 |

추가로 main 흐름에서 2.51.x → 2.52.0 으로 누적된 영역:
- `d89ab6e3f` "feat: Hackle 이벤트 연동, 리뷰 가입일 표시, **원화 가격 필드 추가**" — 스토어/상품 모델 확장
- `1888fed84` "fix: Hackle A/B 테스트 파라미터를 getBool로 변경"
- `43472b9a5` "fix: 로그인 화면이 present되지 않던 문제 수정" — `hotfix/login-present` (LoginViewController nav 를 strong stored property 로 보관)

파일 단위 (main vs release/2.52.0) — 31 파일, 1086+/69- 변경:
- Coupon 신규 파일군 (CouponList, CoopHeartCompletePopup, CouponRegister*, etc.)
- LoginViewController.swift 23줄 변경 (retain cycle fix 포함)
- Localizable.strings ko/en/ja 4줄씩 (다국어 영향 영역)
- BaseSettings.swift (마케팅 버전 2.52.0)
- SkillCoupon 모델 25줄 변경

#### 2) 앱 실행 시퀀스 (AppDelegate.swift, 355줄)

`didFinishLaunchingWithOptions` 흐름 — 외부 의존성·SDK 초기화:

1. BuildConfig / RxKeyboard / PurchaseManager 인스턴스화
2. `amplitude` / `airbridge` application 호출
3. **Adison.shared.initialize** (한국 오퍼월 SDK)
4. **FirebaseApp.configure()**
5. **Hackle.initialize(sdkKey:)** — 한국 회사 (5/8 직전 도입, 2.52.0 본격 운영)
6. setupSentry / setupBraze
7. **KakaoSDK.initSDK** — 카카오 SDK (한국)
8. **LoginManager (LineSDK)** — 라인 (일본)
9. window 생성 + `MainTabBarController` 를 rootViewController 로
10. **MobileAds.shared.start** (Google AdMob, callback)
11. ApplicationDelegate.shared (Facebook) + AppLinkUtility.fetchDeferredAppLink
12. **KakaoAdTracker.activate**
13. **DaroAds.shared.initialized** — 한국 광고 SDK (callback)

해외 IP 차단/지연 가능성이 있는 한국 의존 SDK: **Hackle, KakaoSDK, Adison, KakaoAdSDK, DaroAds**. 다만 위 코드는 모두 비동기 callback 또는 silent fail (Hackle.app() nil 시 print 후 return) — 메인 스레드 차단으로 앱 실행 차단까지 가는 명확한 경로는 코드 표면에서 보이지 않음.

#### 3) 가설 후보 (재현 불가 상태에서)

| # | 가설 | 근거 | 비중 |
|---|------|------|------|
| A | **로그인 화면 present 실패** (LoginViewController.init 의 nav 가 ARC 로 조기 해제) | 동일 이슈 fix 가 4/17(`cae03d3fe` develop) + 5/8 직전(`43472b9a5` main, hotfix/login-present) **두 번** 들어감. 즉 4/17 fix 가 develop 만 갔다가 main 으로 별도 hotfix 가 따로 들어감 → **release/2.52.0 cut 시점에 따라 마켓 빌드에 fix 가 포함되지 않았을 위험**. 해외 = 네트워크 지연 시 자동 로그인 실패 시점이 길어져 race condition 노출 가능성. 5/8 ISS-057 (retain cycle fix, `e850f43ed`) 가 마켓 빌드 cut 이후 들어갔다면 자체 해결 흔적 가능 | **중상** — 마켓 빌드 번호로 검증 필요 |
| B | **Hackle 홈 섹션 A/B 응답 지연** | `0ac0c7976` "홈 섹션 섬네일 A/B" 가 2.52.0 핵심 신규. Hackle 한국 서버 → 해외 IP timeout. 사용처는 `HackleEventTracker.swift` / `UserManagerInjector.swift` 이고 모두 `Hackle.app()` nil 가드 + print 후 return 형태 → 직접 차단 가능성은 낮지만, Hackle.app() 호출 자체가 SDK 내부에서 동기 대기하면 1차 진입 화면이 멈출 수 있음 | **중** — SDK 내부 동작 미상 |
| C | **카카오 쿠폰 등록 URL scheme 자동 진입** | 카카오톡 선물하기 → 발송된 메시지의 URL → 앱 실행 시 자동으로 `/api/coupon/register` 호출. 해외 IP 에서 백엔드가 차단되거나, S3 정책으로 이미지 로딩 실패 → 에러 다이얼로그 노출. 다만 "앱 실행시" 라는 표현이 일반 실행이라면 이 가설은 약함 (URL scheme 진입에 한정) | 중하 |
| D | **DaroAds / Adison / KakaoAdSDK 초기화 실패** | 한국 광고 SDK. 다만 모두 callback 형태이고 fatal error 없음 — 직접 앱 실행 차단 가능성 낮음 | 하 |
| E | **원화 가격 필드 회귀** (`d89ab6e3f`) | 해외 통화 환경에서 KRW 필드 nil/decoding 실패 → 스토어 화면에서 에러. **앱 실행 시 자동 호출되지 않음** (사용자가 스토어 진입해야 함) → 본 케이스와 매치 어려움. 다만 자동 로그인 후 사용자 정보·상품 정보 prefetch 시점에 호출되면 영향 가능 | 하 |
| F | **자동 로그인·토큰 갱신 API timeout** | 해외 네트워크 지연 → ThingsNetwork 서버 도달 실패 → Sentry `failedRequestTargets` 로 노출되는 토스트·alert | 중 — 다만 2.52.0 신규는 아님 |

#### 4) 결정적 미해결 사항

- **마켓 2.52.0 빌드 번호** (예: 2.52.0 (1) / (2) / (3)) 미확인 → release/2.52.0 의 어느 커밋까지 마켓 빌드에 포함되었는지 모름. 특히 5/8 ISS-057 fix (`e850f43ed`) 가 마켓에 들어갔는지가 가설 A 비중을 좌우
- **오류 메시지 원문 텍스트** 미확보 → 시스템 alert / 내부 에러 다이얼로그 / Sentry 토스트 / 카카오 SDK alert / 빈 화면 + 토스트 등 출처 식별 불가
- **영향받은 사용자 지역·디바이스·iOS 버전** 미확보 → 가설 좁히기 어려움
- ASC 크래시 리포트 / Sentry 의 5/13 ~ 5/23 시점 해외 지역 트래픽 미확인

#### 5) 결론 권고 — (c) 추가 정보 필요

자체 재현 불가 + 코드 변경 이력만으로 단일 원인을 좁히기 어려움. 다음을 사용자에게 추가 요청 권고:

1. **앱스토어 리뷰 원문 텍스트** — "오류 메시지"의 정확한 문구. 가설 다수가 메시지 한 줄로 매우 좁혀짐
2. **마켓 2.52.0 빌드 번호** — App Store Connect 의 마켓 빌드 (예: 2.52.0 (1)) 와 이후 출시된 버전. release/2.52.0 의 어느 커밋까지 들어갔는지 검증
3. **5/23 이후 신규 리뷰 없음의 의미 보강** — App Store Connect 의 같은 기간 해외 크래시·세션 통계 / Sentry 의 해당 지역 에러 발생률 확인 (사용자 직접 확인 필요)
4. **사용자 영향 범위** — 영향받은 국가·디바이스·iOS 버전 (앱스토어 리뷰에 명시되어 있을 가능성)

위 정보가 보강되면 가설 A/B/C 중 1~2개로 좁혀 핫픽스 필요 여부를 명확히 판단 가능. 현 상태에선 "자체 해결 가능성 + 명확한 단일 원인 식별 불가" 로 단정도 보류도 어려움.

#### 6) 다음 단계 권고

- **사용자 액션 4건 (위 5)** — 코디네이터를 통해 회신 받기
- 회신 수신 후 dev-ios 재호출하여 가설 좁히기 + 코드 정확 위치 식별
- 만약 마켓 빌드에 ISS-057 retain cycle fix 가 들어가지 않았던 것이 확인되면 → **(b) 핫픽스 필요 → 승격** (TODO-013 잔여 또는 별도 hotfix 트랙). 그 외 가설 검증 결과에 따라 (a) 또는 (b) 분기

#### 7) 참고 — release/2.52.0 의 PR #1416 (ISS-057) 디테일

`df06b905f` 커밋 메시지 발췌:
> `hotfix/login-present` (43472b9a5) 에서 nav controller 의 autorelease 조기 해제를 막기 위해 `containerNavigationController` 를 strong stored property 로 보유했으나, 동일 nav 가 self 를 viewControllers[0] 로 강참조하므로 self ↔ nav 양방향 강참조 사이클이 발생. dismiss 후 LoginViewController 가 dealloc 되지 않아 Debug 빌드의 메모리 릭 디텍터(ViewController.checkDeallocation) 가 토스트로 노출.

→ 이 fix 는 **개발자 빌드 토스트 노출** 가 직접 동기로 보이지만, retain cycle 의 부작용으로 **재로그인 시 새 LoginViewController present 가 안 되는 회귀** 가 production 에서 나타날 가능성이 이론적으로 있음 (이전 인스턴스가 nav 와 함께 살아있음). 해외 사용자가 자동 로그인 실패 + 재로그인 시도 경로를 더 자주 타게 되면 노출률 차이 발생 가능 — 단 추측. 마켓 빌드 cut 시점 검증이 결정적.
