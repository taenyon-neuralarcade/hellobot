# Braze 이벤트 발화 인벤토리 — 서버 / iOS / Android

> **목적**: 플랫폼별 Braze 발송 이벤트·속성 전수 조사 (TODO-035 — 신규 워크스페이스 캠페인 재제작·듀얼 발송 설계 기초 자료)
> **조사일**: 2026-06-12 (3개 리포 병렬 코드 조사) | 원본 리포 메인 브랜치 기준
> ⚠ 표기 = 추가 검증 필요

## 0. 핵심 발견 요약

1. **활성 캠페인 트리거 이벤트의 발화처가 확정됨** (1절 매트릭스). 트랜잭션 9건의 트리거는 **전부 서버 발화** — 6/15 서버 듀얼 발송이 B 워크스페이스 캠페인 동작의 전제. `스킬 진입`·`스킬 소비`도 앱이 아니라 **서버** 발화.
2. **서버에 구/신 키 분기 인프라가 이미 존재** — `BRAZE_API_KEY`/`BRAZE_OLD_API_KEY` + `isBrazeOldVersion` 컨텍스트 분기, 엔드포인트 iad-03(구)/iad-07(현). **직전 마이그레이션(iad-03→07)의 패턴을 이번(07→신규 계정)에 재사용 가능**. Android에도 같은 시기의 Remote Config 키 스위치(`ff_braze_old_key_change_AOS`)가 남아 있음.
3. **iOS는 API 키가 AppDelegate에 하드코딩** — 키 교체는 앱 빌드·배포 필수 (예정대로 6/15 배포에 포함).
4. ⚠ **`회원가입 성공` 이벤트가 iOS에서 미발견** (Android `BrazeLogin.kt:19` 확인, 서버에 없음) — '회원가입 직후 푸시(모수 26,275)'가 iOS에서 어떻게 트리거되는지 검증 필요 (신규 모듈 경로 재확인).
5. 마케팅 문서의 **'홉 탭 클릭'·'히트 탭 클릭'은 '홈 탭 클릭'·'하트 탭 클릭'의 오기**로 판단 (코드에 홉/히트 명칭 없음).
6. iOS가 SDK 초기화 시 `braze_test_event`를 무조건 발송 중 (`AppDelegate.swift:321`) — 신규 워크스페이스 전환 시 제거 권장 (데이터 포인트 낭비).

## 1. 활성 캠페인·캔버스 트리거 이벤트 → 발화처 매트릭스

| 이벤트 (캠페인 사용 명칭) | 발화처 | 코드 근거 | 사용 캠페인/캔버스 |
|---|---|---|---|
| 쿠폰 만료 임박 | **서버** (배치) | `braze.ts:647` | 쿠폰만료임박 캔버스 |
| 쿠폰 발급 | **서버** | `braze.ts:624` | 쿠폰 발급 푸시 |
| 스킬 결제 완료 | **서버** | `braze.ts:271` | 결제완료 이메일·알림톡 |
| 스킬 구매 | **서버** | `braze.ts:554` | 푸시 동의 유도(7일 구매 분기) |
| 스킬 소비 | **서버** | `braze.ts:137` | 오늘의운세 ON 팝업, 일복 레퍼럴 |
| 스킬 진입 | **서버** | `braze.ts:108` | (속성값 목록 기재) |
| 트레이닝 프로젝트 결제 완료 | **서버** | `braze.ts:400` | AI 프로필 알림톡 |
| hellobotllm 티켓 발급/받기 안내/만료 임박 | **서버** (배치·관리자) | `braze.ts:671-730` | LLM 푸시 3종 |
| 결과 보고서 완료 | **서버** → Campaign Trigger API | `summary-report.ts:387-413`, campaign_id `78fe52e9-0649-41c7-bf52-8c07c44181fe` | 결과보고서 푸시 |
| 스킬 상세 확인 | **iOS + Android** | `SkillDetailAnalyticsEvent.swift:98` / `BrazeSkill.kt:87` | 천년배필 미구매, 교차카테고리 캔버스 |
| 홈 탭 클릭 / 하트 탭 클릭 / 홈 하위 탭 진입 | **iOS + Android** | `BrazeHome.kt:188-192` 등 | 회원가입 유도 |
| 회원가입 성공 | **Android 확인 / ⚠ iOS 미발견 / 서버 없음** | `BrazeLogin.kt:19` | 회원가입 직후 푸시·온보딩 하트 |
| 스킬 피드백 완료 / 패키지 스킬 시작 | iOS + Android | `Chats.swift:61` / `BrazeFeedback.kt:20` 등 | (프로필 확인용) |

> **시사점**: 앱 발화 이벤트는 신 SDK 앱(6/15 배포) 사용자부터만 B에 쌓임. 서버 발화 이벤트는 듀얼 발송 시작 즉시 전 유저 커버.

## 2. 서버 (hellobot-server) — custom events 22종

중앙 정의: `src/common/braze.ts` (REST `/users/track`) · 래퍼: `src/common/analytics.ts`

| 이벤트명 | 주요 properties | 발화 조건 | 위치 (braze.ts) |
|---|---|---|---|
| 스킬 진입 | chatbot_name, menu_title, block_name, menu_price, menu_seq, targets, subjects, content_types | 스킬 블록 진입 | :108 |
| 스킬 소비 | 위 + chatbot_seq | 콘텐츠 시작 블록 소비 | :137 |
| 프리미엄 하위 스킬 진입/종료 | chatbot_name, menu_title, sub_skill_title, sub_skill_order, was_locked | 프리미엄 하위 스킬 시작/종료 | :180/:205 |
| 결과이미지 메일 발송 | email, chatbot_name, result_image_* | 결과 이미지 메일 발송 | :230 |
| **스킬 결제 완료** | chatbot_seq, product_id/title/price/current_price, spent_heart_coin, spent_bonus_heart_coin, spent_cash_amount/currency, is_discount, is_bundle, bundle_*, **phone_number, email**, menu_seq, chatbot_name, targets, subjects, content_types | 스킬 결제 승인 | :271 |
| 패키지 결제 완료 | package_seq/title/price/current_price, spent_*, phone_number, email | 패키지 결제 승인 | :327 |
| 컬렉션 결제 완료 | product_*, spent_*, phone_number, email | 컬렉션(랜덤박스) 결제 승인 | :362 |
| **트레이닝 프로젝트 결제 완료** | product_*, spent_cash_*, phone_number, email, **transaction_id**, language_code | AI 프로필 결제 승인 | :400 |
| 트레이닝 프로젝트 승인 / 오픈 알림 | product_title, submit_log_*, training_project_* | 제출 승인 / 오픈 배치 | :436/:461 |
| 코칭 프로그램 결제 | menu_price/title/seq, chatbot_name/seq | 코칭 프로그램 결제 승인 | :491 |
| AI 챗봇 구독권 결제 | product_id/name, spent_cash_* | 구독권 결제 승인 | :512 |
| hellobotllm 티켓 결제 완료 | chatbot_seq/name, pass_type, pass_count, spent_cash_* | 티켓 결제 승인 | :532 |
| **스킬 구매** | chatbot_seq/name, heart_price, current_heart_price, price, current_price, menu_seq, menu_name, spent_* | 스킬 구매 (하트 차감) | :554 |
| 하트 상품 구매 | heart_quantity, product_title, product_current_price | 하트 상품 구매 | :582 |
| 패키지 구매 | package_seq/title/price, spent_* | 패키지 구매 (하트 차감) | :601 |
| **쿠폰 발급** | name, description, discount_type/value, expires_at, max_discount_price, min_purchase_price | 쿠폰 발급 | :624 |
| **쿠폰 만료 임박** | 위 + expires_in | 만료 예정 배치 | :647 |
| **hellobotllm 티켓 발급** | source, count, pass_type, expires_at, request_id | 티켓 발급 | :671 |
| **hellobotllm 티켓 받기 안내** | source, count, pass_type, claim_deadline, pending_batch_seq | 클레임 대기 | :692 |
| **hellobotllm 티켓 만료 임박** | expires_at, expires_in, remaining_count, nearest_batch_seq | 만료 예정 배치 | :713 |

**custom attributes (서버)**: email (결제 시) · 오늘의 운세/주간/야간 푸시 허용여부 (`push-settings-sync.ts:97`) · 동적 속성 전송 함수 (`braze.ts:168` sendUpdateAttribute)

**API 설정 주입**: `config.ts:677-679` (`BRAZE_API_KEY` / `BRAZE_OLD_API_KEY` / `BRAZE_BASIC_AUTH_PASSWORD`), 엔드포인트 하드코딩 `braze.ts:16` (iad-07 신 / iad-03 구), 버전 분기 `async-local-storage.ts:29-39`

## 3. iOS (hellobot_iOS) — 약 60종

- **라우팅 구조**: Amplitude 래퍼 경유 — `AmplitudeTarget.braze`/`.both` 지정 이벤트만 `AppDelegate.braze?.logCustomEvent()` 로 발송. Legacy(`AmplitudeAnalytics.swift`) + 신규(`AnalyticsEvent.swift`) 이중 경로
- **SDK 초기화**: `AppDelegate.swift:307-322` — **API 키 `6a31e0a9-…` + `sdk.iad-07.braze.com` 하드코딩**, SDK 8.0.1. 초기화 직후 `braze_test_event` 발송(:321)
- **주요 이벤트** (캠페인 관련): 스킬 상세 확인(`SkillDetailAnalyticsEvent.swift:98` — referral, menu_seq/name/price, current_price, is_in_package, is_free_today, chatbot_seq/name), 홈 탭 클릭, 홈 하위 탭 진입, 하트 탭 클릭, 스킬 피드백 완료, 패키지 스킬 시작, 하트 구매 성공 등
- **도메인별 분포**: 홈/친구들/검색/더보기 탭 · 스킬 상세·스크랩·공유 · 채팅(고정메뉴·캐로셀·캡처·종료) · 하트(사용/시도/충전/게이지/오퍼월) · 매칭(시도/완료/선물/리뷰) · 코칭 프로그램(6종) · 구독/타임어택 · 패키지 · 리포트 · 결과 이미지 — 상세 properties는 `AmplitudeAnalytics+*.swift` 확장 파일 참조
- **custom attributes 25종**: `AnalyticsUserProperty.swift:12-35` — 사용자번호, 이름(SDK firstName), email(SDK email), 생년/생월/생일, 별자리, 관심사, 성별, 서비스언어, 이메일 마케팅 수신 동의 여부, 테스터 여부, OS/앱/주간/야간 푸시 허용여부, **잔여 하트 개수**(+보너스/일반), **가입 여부**, 가입일자, 가입경로
- **logPurchase**: 하트 상품 IAP (`StoreViewController+Logging.swift:66`, `HeartProductPopupViewController.swift:201`) — SKProduct 통화·가격
- ⚠ 미발견: `회원가입 성공`, '스킬 진입'(서버 발화로 확인됨이라 정상)

## 4. Android (hellobot_android) — 약 90종

- **구조**: `BrazeEvent` sealed class 23개 파일 (`util/analytics/event/braze/`) — eventType(한글명) + eventProperties(JSONObject) + isAvailable 필터. 발송: `BrazeAnalytics.fireEvent()` (초기화 전 이벤트는 earlyDataEvents 큐잉)
- **SDK 초기화·키**: `BrazeAnalytics.kt:72-117` — **Remote Config `ff_braze_old_key_change_AOS` 플래그로 구 키(iad-03, strings_sdk.xml)/신 키(BuildConfig.BRAZE_KEY, iad-07) 런타임 전환**. FCM sender `647544545755`
- **주요 이벤트** (캠페인 관련): 스킬 상세 확인(`BrazeSkill.kt:87` — chatbot_seq/name, menu_seq/name/price, is_in_package, is_free_today, current_price, used_coupon_*), 홈 탭 클릭(`BrazeHome.kt:188`), 홈 하위 탭 진입(:192), 하트 탭 클릭(`BrazeHeart.kt:62`), **회원가입 성공**(`BrazeLogin.kt:19` — type), 스킬 피드백 완료(`BrazeFeedback.kt:20`), 패키지 스킬 시작(`BrazeSkill.kt:90`)
- **도메인별 분포**: 홈 섹션류(배너·태그·리뷰·신규·인기무료 등 10+) · 스킬(상세/스크랩/공유/히스토리) · 하트 사용(콘텐츠/매칭/패키지/선물/코칭 — 시도/사용 쌍) · 구매(하트 IAP·굿즈 연계) · 채팅(블럭·캐로셀·캡처) · 로그인/탈퇴 · 매칭/CONNECT 리뷰 · 코칭(6종) · 구독/타임어택 · 검색/브라우징 · 리포트 · 결과 이미지 · 출석체크 · 푸시 설정 변경
- **custom attributes 6종**: 테스터 여부, 주간/야간 푸시 허용여부 (`BrazeAnalytics.kt:45-48`), 생년월일/생년 (`HellobotAnalytics.kt:140-146`), 성별 (`BrazeAnalytics.kt:160`)
- **logPurchase**: 하트 IAP (`HellobotAnalytics.kt:216-220`) — currency **KRW 고정**, quantity 1

## 5. 플랫폼 간 차이·후속 검증

| # | 항목 | 내용 |
|---|---|---|
| 1 | ⚠ 회원가입 성공 iOS 경로 | Android만 확인 — iOS 신규 모듈(AnalyticsEvent) 재확인 필요. 캠페인 2건(회원가입 직후 푸시·온보딩 하트)의 iOS 동작 여부와 직결 |
| 2 | iOS/Android 속성 비대칭 | iOS는 25종(잔여 하트·가입 여부 등 핵심 속성 포함), Android는 6종만 — 잔여 하트 개수·가입 여부가 Android에서 미설정이면 캔버스 분기가 iOS 유저에게만 정확할 가능성 ⚠ (Android 코드 추가 확인 필요) |
| 3 | 키 교체 작업 지점 | 서버 `config.ts`+`braze.ts:16` / iOS `AppDelegate.swift:307` (하드코딩→빌드 필요) / Android `BuildConfig.BRAZE_KEY`+Remote Config 플래그 |
| 4 | 듀얼 발송 선례 | 서버 `isBrazeOldVersion` 분기 + Android Remote Config 스위치 = 직전 iad-03→07 이관의 잔재. 이번 설계에 재사용 + 이관 완료 후 잔재 정리 과제 |
| 5 | braze_test_event | iOS 초기화 시 무조건 발송 — 신 워크스페이스 전환 시 제거 권장 |
| 6 | currency 차이 | Android logPurchase KRW 고정 vs iOS SKProduct 통화 — 결제 세그먼트($ 기준) 정합성 영향 가능 ⚠ |

## Changelog

| 날짜 | 변경자 | 내용 |
|------|--------|------|
| 2026-06-12 | 코디네이터 (3 플랫폼 병렬 조사) | 최초 작성 |
