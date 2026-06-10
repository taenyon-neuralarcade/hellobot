# 이슈 목록

## 이슈 분류
- **bug**: 구현이 설계와 다름
- **edge-case**: 설계에서 고려하지 못한 예외 상황
- **enhancement**: 기존 요구사항 범위 밖의 개선

---

### ISS-043: 신규 가입자 스킬이용권 사용 시 스킬 인트로 대신 스킬 챗봇 인트로 출력

| 분류 | bug |
| 발견일 | 2026-04-22 |
| 심각도 | P2 |
| 영향 파트 | 서버, 스튜디오(확인 필요) |
| 상태 | 미해결 |

**현상**: 신규 가입자로 스킬이용권 쿠폰 등록 → 쿠폰 클릭 → 스킬 '시작하기' → 대화방 자동 진입 시, 해당 스킬의 인트로가 아닌 "스킬의 챗봇(테스트 판밍밍) 인트로"가 출력됨. 재테스트 케이스(같은 계정 탈퇴 후 재가입)에서는 스킬 인트로가 정상 출력됨 — 최초 진입 경로 타이밍 이슈로 추정.
**재현**: 신규 가입 → 스킬이용권 쿠폰 등록 → 쿠폰 클릭 → 스킬 '시작하기' → 대화방 자동 진입 → 챗봇 인트로 출력.
**기대**: 스킬 챗봇과 대화 이력이 없어도 선택한 스킬의 인트로가 먼저 출력되어야 함.
**기기**: iOS 사파리 (다른 기기 추가 확인 필요).
**출처**: Notion DLT-HLB-1061.

**분석 (2026-04-22 서버)**: 서버 단독 결함보다는 **서버 + 스튜디오 챗봇 설정 + 클라 진입 이벤트 순서가 얽힌 복합 원인**으로 판단. 추가 재현 데이터 없이 단정 어려움 — 가설 정리 + `/dev-studio` 협의 제안.

**스킬 진입 서버 로직 검증**:
- 쿠폰함 카드 탭 → 스킬 상세 → "시작하기" 흐름은 기존 `purchaseFixedMenu`(`src/services/fixed-menu.ts:2527-2626`)를 재사용. `usedCouponSeq`로 이용권 사용 + 하트 차감(0)을 1 트랜잭션 처리.
- `startBlockSeq` 결정(같은 파일 :2581): `discountPrice ? fixedMenu.discountBlockSeq : fixedMenu.data[0]["blocks"][0]`.
  - `discountPrice`는 `getSkillPriceInfo`가 반환하는 **스킬 자체 할인가**(SkillSegment/할인 블록 연동)이지 쿠폰 할인가가 아님. 쿠폰(100%)은 `discountPrice`에 영향을 주지 않음.
  - 만약 대상 스킬에 **세그먼트 기반 신규 가입자 할인**이 활성화되어 있으면 신규 가입자만 `discountPrice`가 non-null → `startBlockSeq = discountBlockSeq`로 분기. 재가입(withdraw 후 재가입)시 userSeq가 새로 발급되어 "신규" 판정이 계속 유지되면 동일 분기가 떨어져야 하는데 QA는 "재테스트는 정상"이라 했으므로 이 단독 원인 가능성은 약함.
- 응답 DTO `PurchaseFixedMenuResponseDto.startBlockSeq`는 정상 전달되므로 서버는 클라에 올바른 진입 블록 번호를 알려준다고 가정.

**챗봇 진입 시 "챗봇 인트로"가 낄 수 있는 경로 (send.ts 기준)**:
- `src/models/send.ts:955` — `input.type === "enter"` 이벤트는 항상 `_processSunTalks`(먼저 말걸기)로 라우팅. 신규 가입자 + 대화방 lastBlockSeq=null + 해당 챗봇에 활성화된 suntalk 존재 시 **챗봇 인트로 성격의 suntalk 메시지**가 선행 송출 가능.
- 반면 `src/models/send.ts:994` — `input.type === "block"` 이벤트는 첫 진입이라도 지정 `blockSeq`로 바로 진입.
- 따라서 클라가 진입 시 보내는 이벤트 종류/순서가 인트로 결정을 좌우. iOS Safari(웹뷰 아닌 실제 Safari)와 네이티브 앱의 이벤트 시퀀스가 다르면 재현 편차 설명 가능.

**데이터 상태 의존 가설 정리**:
1. (유력) **스튜디오 챗봇 설정 문제** — 테스트 판밍밍 챗봇의 `fixedMenu.data[0].blocks[0]` 또는 `discountBlockSeq`가 **챗봇 공통 인트로 블록**을 가리키도록 잘못 구성되어 있을 가능성. 본래 스킬별 인트로 블록이어야 하는데 테스트 챗봇이라 미완성 상태. 이 경우 재가입 성공은 "서로 다른 응답 캐시 경로"(예: blockMessageService 캐시 히트)로 결과가 달라 보일 수 있으나 결정적으로 재현 불안정해야 함 — 보고상 "탈퇴 후 재가입=항상 정상"이면 설명력 약함. → **`/dev-studio` 실 설정 확인 필요** (fixedMenu seq, chatbotSeq, discountBlockSeq 덤프).
2. **Suntalk(먼저 말걸기) 잔존** — 신규 가입 직후 suntalk가 동작해 챗봇 수준 인사말이 선행 송출, 그 후 skill 진입. 재가입 시 `suntalk_log`가 이전 userSeq 기준이라 새 userSeq에도 영향 주지 않아야 하지만, `recyclable` 설정/로그 정리 누락에 따라 동작이 달라질 여지. `src/models/send.ts:1557` sunTalksService 경로 검증 필요.
3. **클라(쿠폰함 → 스킬 상세 자동 진입) 이벤트 순서 레이스** — 쿠폰함 UI가 "시작하기" 탭 시 `purchaseFixedMenu` 응답 전에 chatroom을 open하여 `enter` 먼저, `block` 나중. 신규가입 플로우가 탈퇴/재가입 플로우보다 초기화 waterfall이 길어 순서가 뒤집힘. 이 경우 서버는 "정상 응답"이지만 클라 체감은 챗봇 인트로가 먼저 그려짐.
4. **클라 재시도/딜레이** — iOS Safari에 캐시된 이전 세션 토큰/쿠키로 purchaseFixedMenu 호출 실패 → 폴백 경로(예: 일반 메뉴 진입)로 챗봇 인트로 발생. 서버 로그에서 `purchaseFixedMenu` 호출 성공 여부 확인하면 빠르게 배제 가능.

**수정 대상 파일 (서버)**: 현 단계에서는 없음. 재현 데이터 확보 후 추가 판단.

**해결 방안 (다음 단계 제안)**:
- A. **재현 데이터 확보** — QA 재현 시점의 서버 로그 3종 수집: (1) `purchaseFixedMenu` 호출+응답 `startBlockSeq`, (2) 해당 챗봇 `suntalk_log` 신규 row 여부, (3) 클라가 이어서 보낸 `getMessages` 요청의 `input.type`/`input.blockSeq`. 이 3건으로 위 가설 1-4가 대부분 배제 가능.
- B. **`/dev-studio` 협의 (권장)** — 테스트 판밍밍 스킬의 `SnapshotFixedMenu.data[0].blocks[0]`, `discountBlockSeq`가 올바른 **스킬 인트로 블록**을 가리키는지 확인. 잘못되어 있다면 스튜디오 측 콘텐츠 수정으로 해결(서버 코드 변경 불필요).
- C. (서버 fallback, 최후 수단) `_processSunTalks` 호출 전에 "직전 `block` 이벤트 처리 중이면 suntalk 생략" 가드 추가. 영향 범위가 챗봇 전반에 걸쳐 리스크 큼 — A/B가 선행되어야 함.

**영향 범위**:
- 코드 수정 없이 스튜디오 설정 교정만으로 해결되면 위험도 낮음.
- `_processSunTalks` 변경은 모든 챗봇의 첫 진입 UX 영향 → 실험/단계적 롤아웃 필요. 현 Phase 1 범위 밖.

**사용자 확인 요청**: 본 건은 서버 단독 해결 여부 불분명. A 로그 수집부터 진행하려면 QA 재현 + 타임스탬프 공유 필요. 병행하여 `/dev-studio` 호출해 B 경로 확인을 권장.

---

### ISS-042: 쿠폰 등록 버튼 응답 대기 중 버튼 비활성화 + 스피너 모션 필요

| 분류 | enhancement |
| 발견일 | 2026-04-22 |
| 심각도 | P3 |
| 영향 파트 | 웹, iOS, Android |
| 상태 | Android 해결 (2026-04-22) — `CouponListViewModel._isRegistering: MutableStateFlow<Boolean>` 신설, register 진입 시 true, `doFinally`로 종료 시 false 보장. `CouponListActivity` `collectAsState`로 구독 후 `CouponInputSection(isRegistering)` 전달. 버튼 `enabled = !isInputEmpty && !isRegistering`, 배경색도 동일 조건으로 토글, 내부에 라벨 대신 `CircularProgressIndicator(16dp, Gray900, 2dp strokeWidth)` 렌더. 등록 중 TextField `enabled=false` + clear 아이콘 숨김. 웹/iOS는 미해결. · **문서 정합 완료 (2026-04-22)** — 사용자 최종 결정(스피너 금지, disable + 회색 `#C6C8CC` 재사용)을 design-spec.md §공통 컴포넌트 — 등록 버튼 / client-guide.md "중복 탭 방지" / screen-plan.md §5-1·§5-2·§7·§4 플로우 / architecture.md §6에 반영. Web/Android 레거시 스피너 구현은 회귀 리스크로 rollback하지 않음을 모든 문서에 예외 각주 처리. |

**현상**: 스킬 교환권 쿠폰 등록 시 응답 대기 로딩이 길어 사용자가 버튼이 안 눌린 것으로 착각하고 중복 클릭할 가능성이 있음. 버튼 비활성화 + 스피너 표기로 진행 상태를 명확히 인지시킬 필요.
**출처**: Notion DLT-HLB-1060.

**분석 (2026-04-22 iOS)**: 근본원인 — 현재 iOS는 **중복 탭만 방지**하고 로딩 시각 피드백이 없음. `CouponInputFieldView.swift:111-113`에서 `sendButton.rx.tap.throttle(.seconds(1))`로 연속 탭 차단, `CouponListViewController.swift:74-78`에서 `rx.sendTap` → `sendCouponCode()` 호출. 하지만 (a) throttle은 1초 후 재탭이 가능하므로 응답이 1초 이상 걸릴 경우 중복 호출 가능, (b) 버튼 UI는 정상 상태 그대로 유지되어 진행 상태를 시각화하지 않음 — 사용자는 "응답이 없다"고 인지. 기존 유사 패턴 참고: `status.md` Phase 1 이전 설계에서 S2-A/B 확인 팝업 버튼이 `isRequesting + 로딩`(BonusCouponPopup 패턴)을 적용했음 → Phase 1에서 팝업 제거되며 이 UX가 누락됨. 해결방안 — (A) 권장: `CouponInputFieldView`에 `isLoading: Binder<Bool>` 추가. loading true 시 (1) `sendButton.isEnabled = false` + `setTitle("", for: .disabled)` + 스피너(`UIActivityIndicatorView(style: .medium)`) 중앙 표시, (2) `isUserInteractionEnabled = false`로 tap 차단. `CouponListViewController.registerCoupon(code:)` 전후에 `.do(onSubscribe:)`/`onDispose`로 isLoading 토글. 로딩 GIF(`heartChargeBtnLoading.gif`)를 `ImageContentView`로 띄우면 기존 헬로우봇 버튼 로딩 UX와 통일 가능 → A-1 변형안. (B) 풀스크린 오버레이 스피너(`ImageSaveIndicatorView`/`image_save_loading` Lottie 패턴) — 입력 차단은 확실하나 토스트/팝업과의 z-index 충돌 관리 필요, 스펙 "버튼 내 스피너" 의도와 다름. (C) 중복 호출 방지만 강화: `flatMapLatest` + relay 패턴으로 in-flight 요청 1건 제한 — 시각 피드백 부재라 본 이슈 해결 불가. A안(특히 A-1 GIF 변형) 추천 — 디자인 스펙/기존 컴포넌트와 정합. 수정 대상 — `Hellobot/Feature/Coupon/CouponList/Views/CouponInputFieldView.swift` (loading 상태 UI/Binder 추가), `Hellobot/Feature/Coupon/CouponList/CouponListViewController.swift:160-170` (registerCoupon 라이프사이클 훅). 영향 — iOS 단독(Web/Android 각 파트 별도). 디자인 스펙: design-spec.md/client-guide.md에 "쿠폰 등록 버튼 로딩 상태(버튼 내 스피너, 클릭 비활성)" 섹션이 없음 → `/architect`에 신규 섹션 추가 제안(버튼 치수, 스피너 크기/색, 로딩 표시 조건).

**분석 (2026-04-22 Web)**:
- **현 동작**: `couponCodeRegister.tsx:165` 버튼은 이미 `disabled={couponCode.length === 0 || loading}`로 비활성화 처리됨. `loading` true일 때 `couponCodeRegister.tsx:138`의 `<Loading />`(`components/loading.tsx`) 풀스크린 오버레이가 60×60 스피너를 화면 중앙에 띄움. 비활성화와 글로벌 스피너는 이미 동작 중이나, 시각적 피드백이 사용자가 누른 버튼과 분리되어 인지 어려움. 또한 `<Loading />`이 `withOverlay` 기본값 false라 dim 없이 떠 있어 깜빡 표시되면 눈에 띄지 않음.
- **근본 원인**: 응답 피드백을 글로벌 오버레이에 위임 → 버튼 내 즉시 변화 부재. 또한 disabled 톤(`#C6C8CC`)이 일반 비활성과 구분 없음.
- **수정 대상**: `app/coupon/components/couponCodeRegister.tsx:138`, `:161-174`.
- **해결 방안 (대안)**:
  1. **권장**: 버튼 내부에 인라인 스피너 추가 — `loading`일 때 라벨 대신 `loading.svg`(16~20px) 렌더. 풀스크린 `<Loading />` 제거로 z-index/토스트 충돌 방지.
  2. 풀스크린 Loading 유지 + `withOverlay={true}`로 dim을 켜 입력 차단을 명확히 인지. 단, 토스트·팝업과 z-index 충돌 점검 필요.
  3. `components/button.tsx`에 공통 로딩 상태 프로퍼티 도입(디자인 시스템화) — 본 등록 버튼 외 다른 버튼들에도 일관 적용.
- **영향 범위**: hellobot-web. iOS/Android 동일 enhancement는 별도 파트(이슈 영향 파트 = 웹/iOS/Android). hellobot-webview/-report-webview는 본 등록 플로우 미보유 — 영향 없음.

**분석 (2026-04-22 Android)**:
- **현 동작**: `CouponInputSection` (CouponListActivity.kt:352-445)의 "등록" 버튼 Box가 `clickable(enabled = !isInputEmpty)` (line 430)로 **입력 비어있음** 여부만 체크. 응답 대기 중에도 `enabled = true` → 중복 탭 가능. 인라인 스피너 없음. `CouponListViewModel.register`는 `isProcessing` 플래그로 **ViewModel 레벨**에서 중복 요청을 차단(line 122-123)하지만 UI에 노출되지 않음 → 사용자는 첫 탭이 수용되었는지 알 수 없어 반복 탭.
- **전역 로딩**: `_loadingEvent.value = Event(true/false)`가 emit되지만 `CouponListActivity.observeUi`는 `event(loadingEvent)` 구독을 하지 않음 → 전역 로딩 오버레이도 없음. 사용자 피드백 완전 부재.
- **근본 원인**: 등록 in-flight 상태(`isProcessing`)가 ViewModel 내부 mutable 변수로만 존재하고 UI로 노출되지 않음.
- **수정 대상**:
  1. `CouponListViewModel.kt` — `_isRegistering: MutableStateFlow<Boolean>` 신설 + register 진입/완료 시 true/false 전환. `isProcessing`을 StateFlow로 승격하거나 병행.
  2. `CouponListActivity.kt` — `CouponInputSection`에 `isRegistering: Boolean` 파라미터 추가, 버튼 enabled/스피너 분기.
- **해결 방안**:
  1. **권장 (iOS/웹과 정합)**: ViewModel에 `_isRegistering: MutableStateFlow<Boolean>(false)` 추가 → register 진입 시 true, onSuccess/onError 시 false. Activity에서 `collectAsState` 후 `CouponInputSection(..., isRegistering = isRegistering)`로 전달. 버튼 Box의 `clickable(enabled = !isInputEmpty && !isRegistering)`. 버튼 내부 `Box`에 스피너 렌더 분기:
     ```kotlin
     if (isRegistering) {
         CircularProgressIndicator(
             modifier = Modifier.size(16.dp),
             color = TfColor.Gray900,
             strokeWidth = 2.dp,
         )
     } else {
         Text(
             style = HbTextStyle.Body.Body02.hbDpToSp(),
             text = stringResource(R.string.coupon_title_btn_input),
             color = if (isInputEmpty) TfColor.White else TfColor.Gray900,
             modifier = Modifier.wrapContentSize(),
         )
     }
     ```
     버튼 배경색도 `if (isInputEmpty || isRegistering) TfColor.Gray400 else TfColor.Yellow400`으로 일관 처리해 비활성 톤 유지. 입력 X(`btn_search_clear`)도 `isRegistering`일 때 숨기거나 비활성화 고려.
  2. **대안 (로딩 이벤트 재사용)**: 기존 `_loadingEvent`를 Activity에서 `event(loadingEvent)` 구독하여 Compose state로 변환 후 동일 UI 분기. register 외 load도 `_loadingEvent.value = Event(true)`를 사용하므로 "쿠폰 목록 재조회" 중에도 버튼이 비활성화되는 부작용 — 비권장 (load vs register 구분 필요).
  3. **대안 (전역 오버레이)**: 웹 2안과 유사하게 앱 공통 ProgressDialog나 Dialog 오버레이 도입. 과잉 설계 + 토스트와 z-order 충돌 가능. 비권장.
- **iOS 해법과 정합성**: iOS는 `BehaviorSubject<Bool>`이나 ViewModel Output으로 isRegistering을 노출해 버튼 enabled/스피너를 동시 제어하는 것이 통상 패턴. Android 1안은 동일하게 ViewModel의 `StateFlow<Boolean>`으로 노출 → 동일 원칙. 웹 분석의 권장안 (버튼 내부 인라인 스피너)과도 정합.
- **영향 범위**: Android 단독. API/디자인 스펙 변경 없음. `CircularProgressIndicator` Material3 컴포넌트는 이미 사용 중(다른 화면)이므로 추가 의존 없음. 문자열 리소스 추가 없음.
- **리스크**: `isRegistering`과 `isProcessing` 상태 동기화 누락 시 무한 disabled 가능. `register.onSuccess`/`onError` 양쪽 finally에 false 리셋 보장 필요. RxJava `doFinally`로 래핑하거나 try-finally 구조화 권장.
- **부수 효과 (ISS-032 등 디자인 스펙 체크)**: 스피너 색상은 design-spec.md가 명시하지 않은 것으로 보임 — 기본 Yellow400 버튼 배경에 Gray900 스피너로 가독성 확보. 필요 시 디자이너 승인 후 색상 변경. `/design` 파트에 스피너 색상·크기 확인 요청 제안.

---

### ISS-041: iOS — 쿠폰 카드 타이틀 아래 "0하트 이상 결제 시" 문구 노출

| 분류 | bug |
| 발견일 | 2026-04-22 |
| 심각도 | P3 |
| 영향 파트 | iOS |
| 상태 | 해결 (2026-04-22) — `CouponItemCell.bind()`에서 스킬 이용권 판별(`coupon.fixedMenuSeq != nil && coupon.isUnlimited == true`) 시 `descriptionLabel.isHidden = true` + `flex.isIncludedInLayout = false`로 행 collapse. ISS-031(웹) "subtext 영역 공간 유지"는 iOS design-spec 미명시라 현재 collapse 채택 — 필요 시 `/architect`에 "isUnlimited 시 부가설명 행 처리 확정" 요청. |

**현상**: iOS 쿠폰 카드 타이틀 아래에 "0하트 이상 결제 시" 문구가 노출됨. 스킬 이용권(100% 할인 쿠폰)은 결제 금액 조건이 없으므로 해당 문구는 숨겨져야 함.
**재현**: D-007 케이스.
**출처**: Notion DLT-HLB-1059.

**분석 (2026-04-22 iOS)**: 근본원인 — iOS `CouponModel.description`은 **클라이언트 derive 값**. `Hellobot/Feature/Coupon/Model/Coupon+.swift:11-18`에서 `String(format: .Coupon.View.minValue, minPurchasePrice.decimalString)`로 무조건 생성 → `minPurchasePrice = 0`인 스킬 이용권에서도 `"0하트 이상 결제 시"` 문자열이 계산됨. `CouponItemCell.bind()` (`CouponItemModel.swift:279`) 는 `descriptionLabel.text = coupon.description` + 가시성 분기 없이 표시 → 스킬 이용권 카드에 0하트 문구가 노출됨. ISS-021/022에서 서버가 스킬 이용권에 대해 `isUnlimited: true` + `fixedMenuSeq` 제공하도록 정비했으므로 클라이언트에서 이 조건으로 숨김 분기 필요. 해결방안 — (A) 권장: `CouponItemCell.bind()`에서 스킬 이용권(`coupon.fixedMenuSeq != nil && coupon.isUnlimited == true`) 시 `descriptionLabel.isHidden = true` + `descriptionLabel.flex.isIncludedInLayout = false`로 행 자체 제거. titleLabel 하단 marginBottom도 재조정(기존 `marginBottom(2)` 유지 → 점선까지 간격이 조금 줄어들지만 이슈 본문 요구에 부합). (B) `Coupon+.swift`의 `description` computed property 자체에서 스킬 이용권 조건 시 빈 문자열/nil 반환 — 모델 레이어 변경. 향후 다른 셀에서 `description` 재사용 시 일관성 확보 장점 있으나 "표시 여부"와 "값" 결정을 한 곳에 섞는 설계 단점. (C) `minPurchasePrice == 0` 단독 가드 — 일반 쿠폰도 0하트 이상이 있으면 오답. 비권장. A안 추천(렌더 레이어에서 분기, 스킬 이용권 판별 기준은 ISS-022와 동일 `isUnlimited`). 수정 대상 — `Hellobot/Feature/Coupon/CouponList/Views/CouponItemModel.swift:279` 근처 + 레이아웃 재정렬(marginBottom). 영향 — iOS 단독. Android도 동일 현상 가능성 검토 권장(Android 파트 이슈). 서버/디자인 스펙 영향 없음. **스펙 제안**: design-spec.md §S4 스킬 이용권 카드에 "부가 설명 행(`minPurchase/maxDiscount`)은 `isUnlimited === true`일 때 미표시" 명시를 `/architect`에 요청 (ISS-022 Unlimited 분기와 동일 규칙 연장).

---

### ISS-040: iOS + Android — 스킬 이용권 카드 우측 상단 "이용권" 라벨 노출 안 됨

| 분류 | bug |
| 발견일 | 2026-04-22 |
| 심각도 | P2 |
| 영향 파트 | iOS, Android |
| 상태 | Android 해결 (2026-04-22) — `CouponItem.kt` 우상단 태그 Row에 스킬 이용권 client-derive 로직 추가. 판별 기준 `coupon.isUnlimited && coupon.fixedMenuSeq != null` (기존 하단 링크/만료일 분기와 동일). 기존 `R.string.coop_label_voucher`(ko/ja/en 3언어 보유) 재사용. 서버 `tags`에 이미 "이용권"이 포함된 경우 중복 노출 방지 가드 포함. iOS는 미해결. |

**현상**: iOS + Android 앱에서 스킬 이용권 카드 우측 상단의 '이용권' 라벨이 노출되지 않음. Web Chrome에서는 정상 노출됨 — 클라이언트 렌더링 분기 누락으로 추정.
**재현**: D-001 케이스.
**출처**: Notion DLT-HLB-1058.

**분석 (2026-04-22 iOS)**: 근본원인 — 웹은 스킬 이용권 전용 컴포넌트 `CoopSkillVoucherItem`을 사용하며 "이용권" 배지를 **하드코딩**(`coopSkillVoucherItem.tsx:36` `t('coop_skill_voucher_badge')`). 반면 iOS는 동일 셀(`CouponItemCell`)에서 서버 `coupon.tags: [String]` 배열을 루프 렌더(`CouponItemModel.swift:325-346`). api-spec.md §GET /api/coupon 예시에는 `"tags": ["이용권"]`로 표기되어 있으나 **웹이 서버 tags에 의존하지 않고 자체 문구를 붙이는 점으로 볼 때**, 현재 dev 서버가 스킬 이용권에 대해 실제로 `tags: ["이용권"]`을 내려주지 않는 것(또는 빈 배열)을 유력 가설로 봄. 부가 확인 — `Coupon.swift:14` `tags: [String]`은 non-optional이므로 서버가 필드 자체를 생략하면 decode 실패로 리스트 전체가 깨져야 함 — 이슈 본문("카드는 보이고 라벨만 안 보임")과 불일치 → **서버가 `tags: []` 빈 배열을 반환**하는 패턴으로 귀결. 해결방안 — (A) 권장(웹과 동일 모델): iOS 클라이언트에서 스킬 이용권 조건(`coupon.fixedMenuSeq != nil && coupon.isUnlimited == true`) 검출 시 `coupon.tags`에 "이용권"을 **클라이언트 측 derive**. `CouponItemCell.bind()`에서 `let effectiveTags = coupon.tags + (isSkillVoucher ? ["이용권"] : [])` 방식으로 렌더. 문자열은 `AppString.Coupon.View.skillVoucherTag` 신규(ko/en/jp) 추가. (B) 서버가 `tags: ["이용권"]`을 일관 반환하도록 수정 — Server 파트 변경 필요 + 번역(ko/en/jp) 책임이 서버로 이전. 장기적으로는 깔끔하나 스킬 이용권 판별 기준(무제한+fixedMenuSeq) 등을 Server가 다시 정의해야 함. A안 추천(웹의 하드코딩 패턴과 정합, Android도 동일 로직 적용 가능). 수정 대상 — `Hellobot/Feature/Coupon/CouponList/Views/CouponItemModel.swift:325-346` (tags 렌더 직전에 파생 태그 추가) + 로컬라이즈 리소스. 영향 — iOS 단독(Android 동일 방식 적용 시 대칭). 서버/디자인 스펙 변경 없음. **사전 검증 요청**: 실제 dev 서버 `/api/coupon` 응답에서 스킬 이용권 쿠폰의 `tags` 배열 내용을 QA/서버 파트에 조회하여 A/B 선택 근거 확정. tags에 이미 "이용권"이 들어있다면 렌더 버그(zPosition/subview 순서/prepareForReuse 잔존 등)를 추가 조사. design-spec.md §S4 "이용권" 배지가 client-derive인지 server-provided인지 명시 안 되어 있음 → `/architect`에 "스킬 이용권 태그는 클라이언트 측에서 `fixedMenuSeq + isUnlimited` 조건으로 derive" 문구 추가 제안.

**분석 (2026-04-22 Android)**:
- **코드 경로**: `CouponItem.kt` (line 177-197)에서 `coupon.tagList.forEach { tag -> Text(text = tag, ...) }`로 카드 우상단 배지 렌더. `tagList`는 서버 응답의 `tags` 필드(`CouponData.tags: List<String>`, `CouponItemModel.kt:171,202`)를 그대로 주입.
- **근본 원인 (iOS와 동일)**: 웹 `CoopSkillVoucherItem.tsx:36`이 `t('coop_skill_voucher_badge')`로 "이용권" 문구를 **클라이언트 하드코딩** vs Android/iOS는 서버 `tags` 배열에 의존. dev 서버가 스킬 이용권 응답에 `tags: []`(빈 배열) 또는 `tags: ["이용권"]` 없이 다른 값만 포함 → Android 카드에 배지 미표시. Moshi는 `tags: []`를 성공 decode하므로 카드 자체는 렌더되는 현상과 일치.
- **검증**: `CouponItem.kt` 하단 Column 아래 하단 Row(유효기간/링크)는 정상 렌더되므로 파싱·레이아웃 이슈 아님. `Row { align(Alignment.TopEnd) }` 우상단 컨테이너의 `tagList.forEach`만 빈 루프가 되어 아무것도 그리지 않는 구조.
- **이미 갖춰진 리소스**: `values-ko/strings.xml:1066` / `values-ja:984` / `values:1077`에 `coop_label_voucher` = "이용권" / "利用券" / "Voucher" 보유. **현재 코드에서 이 문자열이 참조되지 않음** → 스킬 이용권 전용 분기를 추가하면 즉시 활용 가능.
- **스킬 이용권 판별 기준**: 기존 코드에서 이미 `isUnlimited === true && fixedMenuSeq != null` 조합으로 스킬 이용권 분기(`CouponItem.kt:103-104` `hasBottomLeft = !coupon.isUnlimited`, `hasBottomRight = coupon.fixedMenuSeq != null`)를 사용 중 → 동일 조건으로 "이용권" 배지 파생 가능. 웹 `coupon/page.tsx:62`도 같은 기준(`c.isUnlimited === true && c.fixedMenuSeq != null`) 사용 — **플랫폼 간 판별 기준 통일**.
- **수정 대상**: `app/src/main/java/com/thingsflow/hellobot/coupon/CouponItem.kt` (line 177-197) 우상단 태그 Row.
- **해결 방안**:
  1. **권장 (클라이언트 derive, iOS A안과 정합)**: `CouponItem` 내부에서 스킬 이용권 조건 판별 후 `tagList` 앞에 "이용권" 배지 prepend하여 렌더. 서버 `tags`와 중복되지 않도록 중복 제거 필요 (서버가 향후 "이용권"을 포함해도 한 번만 표시).
     ```kotlin
     val isSkillVoucher = coupon.isUnlimited && coupon.fixedMenuSeq != null
     val voucherLabel = stringResource(R.string.coop_label_voucher)
     val effectiveTags = if (isSkillVoucher && voucherLabel !in coupon.tagList) {
         listOf(voucherLabel) + coupon.tagList
     } else {
         coupon.tagList
     }
     Row(
         modifier = Modifier
             .wrapContentSize()
             .align(Alignment.TopEnd)
             .padding(top = 12.dp, end = 12.dp),
         horizontalArrangement = Arrangement.spacedBy(2.dp),
     ) {
         val tagShape = RoundedCornerShape(percent = 50)
         effectiveTags.forEach { tag ->
             Text(
                 text = tag,
                 style = HbTextStyle.Headline.Label.hbDpToSp(),
                 color = TfColor.Gray600,
                 modifier = Modifier
                     .background(color = TfColor.White, shape = tagShape)
                     .border(width = 1.dp, color = TfColor.Gray200, shape = tagShape)
                     .padding(horizontal = 8.dp, vertical = 3.dp),
             )
         }
     }
     ```
  2. **대안 (서버 책임)**: 서버가 `/api/coupon` 응답에서 스킬 이용권에 `tags: ["이용권"]`(디바이스 언어 locale 반영)을 일관 반환. 장점: 클라 로직 없음. 단점: 서버가 태그 번역(ko/ja/en) 책임 → 새로 도입하는 계약이라 범위 큼. 웹은 이미 클라 derive이므로 서버 변경해도 웹은 무시 or 이중 렌더 위험. 비권장.
  3. **대안 (모델 레벨)**: `CouponData.toCouponItemModel()` 변환 시점에 `tags`를 보강 — 하지만 거기서는 Context가 없어 문자열 리소스 접근 불가. `TextString("이용권")` 하드코딩은 다국어 위반 → 비권장.
- **iOS 해법과의 정합성 및 차이**: iOS A안 ("클라이언트 derive + 로컬 문자열")과 동일 전략. 문자열 리소스는 iOS는 신규 `AppString.Coupon.View.skillVoucherTag` 필요, Android는 **이미 존재하는 `coop_label_voucher`**(ko/ja/en 3종) 재사용 가능 — Android가 구현 비용이 더 적음. 판별 기준도 `isUnlimited && fixedMenuSeq != null`로 동일.
- **영향 범위**: Android 단독. 서버/디자인 스펙 변경 없음. 기존 `tagList.forEach` 루프 구조 유지(effectiveTags로 치환) — 시각 디자인 영향 없음.
- **문서 제안**: iOS 분석의 제안("스킬 이용권 태그는 클라이언트 측에서 `fixedMenuSeq + isUnlimited` 조건으로 derive")에 동의. design-spec.md §S4에 배지 주체 명시 추가를 `/architect`에 요청. 또한 ISS-037(웹 "이용권" 라벨 스타일 차이)과 **라벨의 주체/기준**을 통일하는 점검 필요 — 웹/앱이 동일 판별 기준으로 동일 배지를 그리는지 재확인.

---

### ISS-039: 앱 — en/jp 로케일에서 "앱 업데이트 필요" 토스트 번역 텍스트 누락

| 분류 | bug |
| 발견일 | 2026-04-22 |
| 심각도 | P2 |
| 영향 파트 | Android, iOS |
| 상태 | 서버 해결 (2026-04-22) — `src/locales/en.ts`에 "Please update to the latest version.", `src/locales/ja.ts`에 "アプリを最新バージョンにアップデートしてください" 채움 (기대안 2번 문구 채택). 클라이언트(iOS/Android) 앱 번들 번역 검토는 별개 과업. |

**현상**: 앱 언어를 en/jp로 변경 후 구버전 가드 대상 쿠폰 코드를 등록하면 번역된 문구 없이 빈 문자열 또는 원문(ko) 그대로 표시됨. ISS-009 대응 시 서버 i18n 잔여(ja/en 빈 placeholder)에 따른 것으로 추정. iOS 앱도 재현 확인 필요.
**기대**:
- ko: "앱 업데이트가 필요한 쿠폰이에요."
- en: "This coupon requires an app update" 또는 "Please update to the latest version."
- jp: "このクーポンはアプリのアップデートが必要です" 또는 "アプリを最新バージョンにアップデートしてください"

**재현**: H-003 케이스 / Android 2.40.0-dev (204000023).
**출처**: Notion DLT-HLB-1057.

**분석 (2026-04-22 서버)**: 근본 원인은 서버 i18n 리소스의 ja/en placeholder 공란. 확인 포인트:
- `src/locales/ko.ts:356` — `CO_APP_UPDATE_REQUIRED: "앱 업데이트가 필요한 쿠폰이에요."` (정상)
- `src/locales/en.ts:357` — `CO_APP_UPDATE_REQUIRED: ""` (공란)
- `src/locales/ja.ts:357` — `CO_APP_UPDATE_REQUIRED: ""` (공란)
- ISS-009 Phase 1 구현(api-spec.md:434 기준 2026-04-19)에서 ko만 확정하고 ja/en은 placeholder로 남김 (해당 Changelog에 "ja/en placeholder" 명시됨).

**서버 메시지 의존도**:
- 에러 응답은 `src/common/error.ts:29` `handleHttpError`가 `errorLocalize(languageCode, code)`로 생성. `languageCode`는 `req.context.user.dbUser.languageCode` → fallback `LanguageCode.En`. 응답 바디는 `{ error: { code, message, reason }, code, message, reason }` 형태.
- i18next는 **빈 문자열 값**을 "존재하는 번역"으로 간주하여 **fallbackLng(ko)로 폴백하지 않음** (i18next 기본 동작). 따라서 en/ja 유저는 `message: ""` 수신.
- 클라이언트: `client-guide.md` S5에서 `error.message`를 토스트에 그대로 표시하는 계약. 즉 클라 미수정 시 빈 토스트. Android 2.40.0-dev 재현은 이 경로에 해당.
- iOS는 ISS-026 해결(`CouponRegisterErrorMapper`, 2026-04-21)로 "비-한글/빈 문자열이면 S5 매핑표 **ko 상수**로 폴백" 로직이 있어 빈 서버 메시지를 ko 고정 문자열로 덮어쓴다 → en/ja 로케일 사용자도 한글이 노출되는 부작용 가능 (ISS-039 재현 대상에 iOS 추가 확인 필요 사유).

**수정 대상 파일**:
- `src/locales/en.ts:357` — `CO_APP_UPDATE_REQUIRED: "Please update to the latest version to use this coupon."` (issues.md 기대안 2번째 기반, 쿠폰 주체 명시)
- `src/locales/ja.ts:357` — `CO_APP_UPDATE_REQUIRED: "最新バージョンにアップデートしてご利用ください。"`
- (선택) 동일 파일의 `CM_001`~`CM_010`, `WC001~003`도 공란 상태이나 본 이슈 범위 밖 — 별도 이슈로 분리 권장.

**해결 방안**:
- 1안 (권장): ja/en 메시지 문구 확정 후 두 locale 파일 한 줄씩 수정. 번역 문구는 issues.md 기대안 2개 중 "업데이트 안내" 톤이 기존 에러 토스트 문맥(행동 유도)에 더 적합.
- 2안: fallback 전략 변경 (i18next `returnEmptyString: false` 옵션 추가) — ko 폴백으로 최소한 한글 노출. 영향 범위가 전체 locale 키에 걸쳐 있어 보수적으로 비권장. 1안이 근본 해결.

**영향 범위**:
- 서버 단일 파일 2건 수정, 배포 즉시 모든 클라이언트(iOS/Android/Web) 개선.
- 클라이언트 수정 불필요 (서버 메시지 그대로 표시 경로 유지).
- iOS의 ISS-026 폴백 로직은 빈 문자열 방지 차원에서 유지하되, 향후 서버가 올바른 ja/en을 주면 서버 값을 우선 사용하는 방향으로 점진 개선 검토 (별도 이슈).

**후속 제안 (계약 문서)**: api-spec.md §에러코드(CO_APP_UPDATE_REQUIRED 항목)에 ko/ja/en 3종 문구를 정식 기록. 현재는 ko 한 문구만 등재. `/architect` 승인 후 반영.

**분석 (2026-04-22 iOS)**: 근본원인 — 서버 i18n 빈 placeholder(Server 분석 참고) + iOS의 ISS-026 폴백 로직(`CouponRegisterErrorMapper.swift:18-30,52-58`)이 **ko 상수만** 테이블로 갖고 있어 en/jp 디바이스에서도 ko 문구로 덮어씀. 즉 서버가 en/jp 번역을 공란/영문으로 주거나 iOS 디바이스 언어가 en/jp여도 결과가 `"앱 업데이트가 필요한 쿠폰이에요."` 한글로 고정됨. Android의 "빈 토스트" 재현과 iOS의 "한글 노출" 재현은 표현형만 다름(서버·클라 양쪽 원인이 중첩). 재현 확인 — ISS-026 폴백이 서버 빈 메시지를 ko 상수로 치환하므로 "빈 토스트"는 iOS에서 발생하지 않을 것이고, en/jp 디바이스에서 ko 노출로 나타날 것. 해결방안 — (A) 권장 + Server 1안 연동: Server가 ja/en 메시지를 정상 발급하면 iOS는 **원칙적 무수정** (ISS-026 폴백은 서버 ko 우선 → 폴백순). 단, 현재 `CouponRegisterErrorMapper.resolve()`는 "Hangul 포함" 여부로 서버 메시지 신뢰를 판정 — 서버가 정상 en/jp 문구를 줘도 "한글 미포함"이라 폴백이 발동하여 ko 상수를 덮어씀 (회귀 위험). → `CouponRegisterErrorMapper`의 판정을 **"빈 문자열만 폴백, 비-한글이어도 서버 값 우선"** 으로 변경 필요. (B) iOS 로컬 i18n 테이블 추가: `codeMessages`를 ko/ja/en 3종으로 확장하고 `Locale.preferredLanguages[0]` 기반 선택 — 서버와 이중 번역 관리 부담 + 서버 변경 시 반영 지연. A안 추천. 수정 대상 — `Hellobot/Feature/Coupon/Network/CouponRegisterErrorMapper.swift:52-58` (`resolve` 판정 로직). 영향 — iOS 단독 (Server 1안 배포 이후에만 정상 동작). **후속**: Server ja/en locale 수정 배포 전에 iOS 폴백 판정부터 완화해야 "서버 en/jp 정상 + iOS ko 폴백" 회귀 예방. `/architect`에 client-guide.md S5 각주 "서버 `error.message`는 디바이스 로케일에 맞춘 문구 — 클라이언트는 **비어있을 때만** 로컬 폴백" 명시 추가 제안.

**분석 (2026-04-22 Android)**:
- **코드 경로**: `CoopRepositoryImpl.register(code)` (Single<CouponRegisterResponse>) → 실패 시 `CouponListViewModel.register.onError` → `extractServerMessage(error)` (line 175-190) → `CoopEvent.ShowError(message)` emit → Activity의 `is CoopEvent.ShowError -> if (event.message.isNotEmpty()) SafeToast.showToastForDurationMs(...)` (line 132-140). 즉 메시지가 빈 문자열이면 **토스트 자체를 표시하지 않음**.
- **재현 양상 (QA H-003, Android 2.40.0-dev)**: en/jp 디바이스 로케일 → 서버 `CO_APP_UPDATE_REQUIRED` 응답 `error.message: ""` → `extractServerMessage`가 `""` 반환 → ShowError(empty) → `isNotEmpty` 가드로 토스트 생략 → QA 관점에서 "번역 없음 + 빈 토스트". 디바이스 언어가 ko면 서버가 정상 ko 문구를 주므로 한글 노출로 정상.
- **근본 원인**: 주 원인은 **서버 i18n 리소스의 공란**(서버 분석 참고). Android는 서버 `error.message`를 그대로 노출하는 계약을 충실히 따르고 있음(iOS처럼 ko 상수 폴백 로직이 없으므로 "한글 노출" 부작용은 없고, 대신 "아무것도 노출 안 됨" 증상).
- **보조 원인 (Android 고유)**: `extractServerMessage`가 `error.code`를 **읽지 않고** message만 추출. 서버가 code는 정확히 보내주더라도 Android는 이를 활용할 수 없어 로컬 문구로 대체 불가.
- **수정 대상 판단**:
  - **1순위 (서버)**: `src/locales/en.ts:357`, `src/locales/ja.ts:357`의 `CO_APP_UPDATE_REQUIRED` 공란을 채움 — 서버 분석의 1안에 따름. 배포되면 Android 클라 무수정으로 정상화.
  - **2순위 (Android 방어적)**: 서버 1안 배포 전까지의 갭 방어 또는 장기적 공란 회귀 대비용으로 `error.code === "CO_APP_UPDATE_REQUIRED"` && `message` 비었을 때 앱 리소스(ko/en/ja strings.xml) 폴백.
- **해결 방안**:
  1. **권장 (서버 수정 + Android 무수정)**: 서버 locale 공란만 채우면 Android 클라이언트는 현 코드 유지로 정상화. 추가 개발·리소스 제작 없음. 서버 분석 1안과 동기 진행.
  2. **대안 (Android 방어적 폴백 추가)**: 서버 1안이 지연되거나, 향후 공란 재발 대비 Android 방어 계층 도입.
     - (a) `extractServerMessage`를 `Pair<code: String?, message: String>` 반환으로 확장. `ShowError` 이벤트에 `errorCode`를 포함해 Activity가 code+message 둘 다 인지.
     - (b) `strings.xml` (values/values-ko/values-ja)에 `coop_error_app_update_required` 3언어 추가:
       - ko: `"앱 업데이트가 필요한 쿠폰이에요."`
       - en: `"Please update to the latest version to use this coupon."`
       - ja: `"最新バージョンにアップデートしてご利用ください。"`
     - (c) Activity의 ShowError 핸들러에서 `event.message.isEmpty() && event.errorCode == "CO_APP_UPDATE_REQUIRED"`면 `R.string.coop_error_app_update_required`로 폴백.
     - 장점: 서버 공란 회귀에도 안전망. 단점: 서버·앱 번들 2중 번역 관리 부담. 리소스 드리프트 가능.
  3. **가드 강화 (최소)**: 폴백 문자열 없이 `event.message.isEmpty()` 시 일반 범용 "오류가 발생했어요" 토스트라도 표시 (기존 `common_*_error` 키 재사용). 사용자에게 "앱 업데이트 필요"라는 구체 안내는 못 주나 "무반응"은 개선.
- **iOS와의 해법 정합성 및 차이**:
  - iOS는 `CouponRegisterErrorMapper`에 ko 상수 폴백 로직이 기존 존재(ISS-026 해결) → en/jp 로케일에서도 ko 노출되는 **표현형 차이** 발생. iOS 분석의 A안은 "비어있을 때만 폴백 + 서버 값 우선" 판정 변경.
  - Android는 폴백 로직 자체가 없어 "빈 토스트" 표현형. 서버 수정만으로 해소되는 단순 케이스이므로 iOS의 복잡한 판정 변경이 필요 없음.
  - 장기적 일관성을 원한다면 2안 (a~c)로 Android에도 code 기반 폴백 추가 — iOS의 "Hangul 포함 판정"보다 명시적인 "빈 문자열 + code 매칭" 조건이 견고. 추천 우선순위: **1안 우선 적용, 2안은 별도 enhancement로 분리**.
- **영향 범위**: 1안은 Android 무수정. 2안 채택 시 `CoopRepository` 계약(반환 타입)은 유지, `CouponListViewModel.extractServerMessage` + `CoopEvent.ShowError` 시그니처 + strings.xml 3언어 수정 필요. API/디자인 스펙 변경 없음.
- **문서 제안**: client-guide.md S5 각주에 "서버 `error.message`는 디바이스 로케일에 맞춘 문구 — 클라이언트는 **비어있을 때만** 로컬 폴백(가능하면 `error.code` 매칭 기반)" 명시 추가 제안 (iOS 분석과 동일 제안).

**결정 (2026-04-22, Android)**: **서버 i18n 수정에 의존, Android 방어적 폴백 추가하지 않음** 확정. 근본 해결은 서버 `src/locales/en.ts` / `src/locales/ja.ts`의 `CO_APP_UPDATE_REQUIRED` 공란을 채우는 것(서버 분석 1안). Android 클라이언트는 **코드 수정 없음**. 본 이슈의 Android 파트 과업은 "서버 배포 확인 후 회귀 테스트"로 축소. 서버 번역 문구 확정 + 배포 이후 QA가 Android en/jp 디바이스에서 정상 노출 확인 → Android 파트 close. 향후 다른 에러 code(CM_001~CM_010, WC001~003) 공란 회귀가 표면화되면 별도 enhancement 이슈로 분리해 클라이언트 방어층 재검토.

---

### ISS-038: iOS — 쿠폰 등록 관련 토스트 좌우 여백이 기존 토스트와 달리 화면 꽉참

| 분류 | bug |
| 발견일 | 2026-04-22 |
| 심각도 | P3 |
| 영향 파트 | iOS |
| 상태 | 해결 (2026-04-22) — `CouponListViewController`에 `showCouponToast(_:)` 헬퍼 신설 → `Toast(text:, config: ToastConfig(displayTime: 2.5)).show()` (기본 `.adaptive(padding: 16)`로 콘텐츠 폭 중앙 배치). 레거시 `showToast(msg:)` 2개 호출부 + ISS-033 신규 호출을 일원화. 레거시 `VC + Toast.swift` 자체는 타 화면 영향 우려로 비변경. |

**현상**: 기존 운영서버 토스트와 다르게 이번 신규 추가된(쿠폰 등록 관련) 토스트의 좌우 여백이 꽉 차서 노출됨. 기존 토스트 컴포넌트와 동일한 좌우 여백(padding) 적용 필요.
**재현**: B-001 케이스.
**출처**: Notion DLT-HLB-1056.

**분석 (2026-04-22 iOS)**: 근본원인 — iOS에는 **2종의 토스트 구현**이 병존. (1) 신형 `Toast(text:).show()` — `CommonUIKit/Toast/Toast.swift`, `ToastConfig.widthStrategy` 기본값 `.adaptive(padding: 16)` 로 **콘텐츠 폭에 맞춰 중앙 배치**(짧은 메시지는 압축됨, 기존 운영 토스트 스타일). (2) 레거시 `UIViewController.showToast(msg:)` — `Legacy/Extensions/VC + Toast.swift:16-48`, `leadingAnchor/trailingAnchor`에 각각 16pt inset 적용 → **화면 폭-32pt를 차지하는 꽉참 형태**. 쿠폰 플로우는 `CouponListViewController.swift:167,185`에서 레거시 `showToast(msg:)`를 호출 → 꽉참 노출로 기존 토스트와 편차 발생 (기존 운영 화면들 대부분은 `Toast(text:).show()` 사용). 해결방안 — (A) 권장: 쿠폰 플로우의 2개 호출부를 `Toast(text: msg).show()`로 교체 (기본 `.adaptive(padding: 16)` 활용). ISS-033 신규 성공 토스트, ISS-039 에러 토스트까지 모두 동일 컴포넌트로 통일. (B) 레거시 `showToast(msg:)` 내부 구현을 `Toast(text:)`로 위임하여 앱 전역 자동 개선 — 다른 레거시 화면(Matching/MatchingChatroom 등)까지 바뀌어 회귀 리스크 큼, 비권장. A안 추천(범위 한정). 수정 대상 — `Hellobot/Feature/Coupon/CouponList/CouponListViewController.swift:167,185` (향후 ISS-033 추가 호출부 포함). 영향 — iOS 단독. 디자인 스펙/서버 파트 영향 없음. **부가**: Toast의 기본 `displayTime`은 `ToastConfig` 기본값 `5.0` (ISS-016 해결로 Web/Android는 2.5초 확정); 쿠폰 플로우 토스트는 `Toast(text: msg, config: ToastConfig(displayTime: 2.5))`로 override하여 스펙 준수하도록 동시 조정 권장. `/architect`에 client-guide.md/design-spec.md의 "토스트 2.5초" 규정이 iOS에도 적용되도록 이미 명시되어 있는지 크로스체크 제안.

---

### ISS-037: 웹 — 스킬 이용권 카드 우측 상단 "이용권" 라벨 디자인이 기존 라벨과 다름

| 분류 | bug |
| 발견일 | 2026-04-22 |
| 심각도 | P3 |
| 영향 파트 | 웹 |
| 상태 | 미해결 |

**현상**: 웹 스킬 이용권 카드 우측 상단의 "이용권" 라벨이 기존 라벨 디자인과 형태가 다름. 래디어스 값과 상하좌우 패딩을 기존 라벨 스펙에 맞게 조정 필요.
**재현**: D-001 케이스.
**출처**: Notion DLT-HLB-1055.

**분석 (2026-04-22 Web)**:
- **근본 원인**: `CoopSkillVoucherItem` 라벨 스타일이 기존 `CouponItem` 태그 스타일과 별도 정의되어 시각 어휘가 어긋남.
  - `coopSkillVoucherItem.tsx:35` — `px-[8px] pt-[2px] pb-[4px] bg-white border border-solid border-[#EDEDEE] text-[#7E8185] text-[11px] font-bold rounded-[10px] leading-[17px]`
  - `couponItem.tsx:20` — `px-[6px] text-[11px] text-gray-600 tracking-[-0.3px] font-bold leading-[18px] border-[1px] border-solid border-gray-200 rounded-full`
  - 차이: 패딩(수평 8/6 + 수직 2·4 vs 수직 0), border-radius(10px vs pill), leading(17 vs 18), 배경(명시 white vs 상위 상속).
- **수정 대상**: `app/coupon/components/coopSkillVoucherItem.tsx:34-38`.
- **해결 방안 (대안)**:
  1. **권장**: `CouponItem` 태그 스타일(`px-[6px]` + `rounded-full` + `text-gray-600 border-gray-200`)을 그대로 적용. "이용권"은 그레이 계열이라 직접 차용 가능.
  2. 공통 `<CouponTag>` 컴포넌트로 추출해 재사용(장기 과제).
  3. design-spec.md §S4(line 106) 라벨 사양이 pill/radius 10 중 무엇인지 명시 모호 — Figma 원본과 대조해 radius 값 확정 후 반영(디자인팀 확인).
- **영향 범위**: hellobot-web만. ISS-040(앱 라벨 미노출)과는 별개(앱은 렌더 누락, 웹은 렌더되나 스타일 불일치).

---

### ISS-036: 스킬이용권 사용 후 대화방 뒤로가기 → 쿠폰함 복귀 시 사용한 쿠폰이 목록에 남음

| 분류 | bug |
| 발견일 | 2026-04-22 |
| 심각도 | P2 |
| 영향 파트 | Android, 웹 (iOS 앱 확인 필요) |
| 상태 | Android 해결 (2026-04-22) — `CouponListActivity.onResume` 오버라이드 → `viewModel.load()` 호출. `loadData()`는 no-op로 변경해 onCreate 경로 중복 load 방지. onStart→onResume 시퀀스에서 실질 지연 없음. 뒤로가기/재진입 경로 모두 커버. 부수 효과로 ISS-034(이용권 접미사 탈락)의 Android 재현분 동반 해소 기대 — QA 재확인 필요. 웹/iOS는 미해결. |

**현상**: 스킬이용권 0원 결제 완료 후 대화방에서 하드웨어/소프트 뒤로가기 버튼으로 쿠폰함으로 복귀하면 사용한 쿠폰이 목록에 그대로 남아있음. 쿠폰함을 완전히 나갔다 재진입하면 정상적으로 사라짐 — 즉, 뒤로가기 경로에서 쿠폰 리스트 갱신(재조회)이 누락됨.
**재현**: 스킬이용권 쿠폰 등록 → 쿠폰 선택 → 대화방 진입 → 0원 결제 → 인트로 시작 → 뒤로가기로 대화방 이탈 → 쿠폰함 화면 유지 → 사용한 쿠폰도 유지됨.
**재현 기기**: Android 앱, PC 웹, iOS 웹에서 재현. iOS 앱 재현 여부 확인 필요.
**기대**: 뒤로가기 시 화면 갱신 → 사용한 쿠폰이 목록에서 제거됨. (제안: 사용한 쿠폰을 유지하되 '사용 완료' 표시 추가 옵션도 검토 가능)
**출처**: Notion DLT-HLB-1053.

**분석 (2026-04-22 Web)**:
- **근본 원인 (웹)**: 다단계 원인.
  1. `coupon/page.tsx:51-53`의 `handleSkillVoucherClick`이 `location.href = ...`로 외부 풀 네비게이션(스킬스토어 호스트) 수행. 사용자가 `/chat` → 브라우저 back으로 복귀 시 대부분의 모바일 브라우저에서 **bfcache(back-forward cache)** hit로 페이지 JS 재실행 없음 → `useGetCoupon`이 `/api/coupon`을 재요청하지 않음 → Redux `coupons` 상태도 `useEffect([couponData])` 경로로 갱신되지 않음.
  2. `useGetCoupon` 기본 SWR 설정은 `revalidateOnFocus`가 기본 true이나, bfcache 복원 시 `focus` 이벤트만으로는 재요청이 일어나지 않는 케이스가 있음(브라우저별 차이, 특히 iOS Safari).
  3. 서버가 `/api/coupon` 응답에서 사용된 voucher를 제외해도 클라 캐시가 stale이면 남음. 서버가 여전히 포함한다면 재조회해도 사라지지 않음 — 서버 동작 확인 필요(Server 검토 단계).
- **수정 대상**:
  - `app/coupon/page.tsx` — bfcache 복원 감지 훅 추가.
  - `apis/coupon/useGetCoupon.ts` — SWR 옵션 명시(필요 시).
- **해결 방안 (대안)**:
  1. **권장**: `page.tsx`에 `useEffect(() => { const onShow = (e: PageTransitionEvent) => { if (e.persisted) mutate('/api/coupon'); }; window.addEventListener('pageshow', onShow); return () => window.removeEventListener('pageshow', onShow); }, [mutate])` 추가. bfcache 복원 시 즉시 재검증.
  2. `useGetCoupon` SWR 옵션에 `revalidateOnMount: true, revalidateIfStale: true` 명시 + `dedupingInterval`을 짧게 조정.
  3. 사용 여부를 옵티미스틱으로 표시 — 카드 탭 직후 해당 쿠폰을 로컬 상태로 `used=true` 마킹하고 채팅 경로 진입 전/직후 숨김. 단, 사용 실패 시 롤백 로직 필요.
  4. (기획/서버 확인 필요) `/api/coupon` 응답 정책 — 사용된 쿠폰을 응답에 포함하지 말거나, `isUsed: boolean`를 내려서 클라가 필터.
- **공통 원인 (ISS-034와 연계)**: 동일 back-nav 경로에서 발견된 두 이슈는 **SWR/bfcache 재조회 실패 + 서버가 used voucher를 여전히 응답** 두 요인이 겹쳐 발생. ISS-034는 "분류 오류" 표현형, ISS-036은 "잔존" 표현형. `mutate('/api/coupon')`로 재조회하면 두 증상이 동시에 해소될 가능성이 크지만, 근본은 서버의 used voucher 응답 정책을 Server 검토 단계에서 확인해야 완결.
- **영향 범위**: hellobot-web. hellobot-webview/-report-webview는 본 /coupon 페이지 미보유 — 영향 없음. Android/iOS 앱 대응은 별도 파트.

**업데이트 (2026-04-22 Web, Server 답변 반영)**:
- **서버 확인 결과**: `/api/coupon` 응답에서 **사용된 voucher는 자동 제외됨**. 즉 "서버가 used voucher를 여전히 응답" 가능성은 제거 → 웹측 원인은 **bfcache 재조회 미트리거 단일 요인**으로 확정.
- **확정 해결 방안**: 위 "해결 방안 1번" (`pageshow + mutate('/api/coupon')`) 단독 적용으로 완결. SWR 옵션 보강(2번)은 선택.
- **진행 상태**: 즉시 착수 가능. 서버 의존성 해소됨.

**분석 (2026-04-22 iOS)**: 근본원인 — **정적 코드 분석상 iOS 앱에서는 재현되지 않을 가능성이 높음**. `CouponListViewController.swift:80-85`에 `rx.viewWillAppear` 구독으로 `viewModel.refreshCoupon()`이 이미 바인딩됨. 스킬 상세는 `presentSkillDetail(fixedMenuSeq:)` → `UIApplication.topViewController()?.present(containerVC, ...)` modal present이므로 CouponListVC는 뒤에 남아있고, SkillDetailContainer+내부 ChatRoom 스택 dismiss 후 CouponListVC의 viewWillAppear가 발화하여 `/api/coupon`을 재조회. 엣지케이스로 미재현 여지 (1) 챗룸이 container 내부 push가 아닌 별도 window/rootVC 교체 방식으로 올라가는 경우 viewWillAppear 누락, (2) `CouponListViewModel.swift:47-54` `share(replay:1).elements()`가 직전 응답을 재활용해 UI 업데이트 타이밍이 밀리는 경우. 해결방안 — (A) 권장: **실기기 재현 우선 확인** (QA iOS app 재테스트). (B) 재현 확정 시: `presentSkillDetail`의 `present(containerVC, animated: true, completion:)` dismiss 경로에 `self?.viewModel.refreshCoupon()`을 직접 연결하거나, containerVC의 `rx.deallocated`를 구독하여 강제 refresh. (C) 추가 방어: 스킬 use 성공 이벤트(쿠폰 소진 확정 시점)를 `NotificationCenter`/공용 `PublishRelay`로 broadcast → CouponListVC가 관찰하여 refresh. 수정 대상(재현 확정 시) — `Hellobot/Feature/Coupon/CouponList/CouponListViewController.swift:133-139` `presentSkillDetail`와 `bind()` viewWillAppear 구독부. 영향 — iOS 단독(재현 시). API 계약/디자인 스펙 변경 없음. **후속**: QA에게 iOS 앱 실기기 재현 테스트를 우선 요청; 미재현이면 이슈 영향 파트에서 iOS 제거 (이슈 본문 "iOS 앱 재현 여부 확인 필요" 표현과 일치).

**분석 (2026-04-22 Android)**:
- **진입/이탈 경로 (Android)**: `CouponListActivity.ComposeUi`에서 스킬 이용권 카드 탭 시 `SkillDescriptionBottomSheet.show(this@CouponListActivity, seq, "coop_voucher_card")` (line 271-278) — BottomSheetDialogFragment가 CouponListActivity 위에 표시(별도 Activity 전환 X). 시트 내 `시작하기` → `ChatroomActivity.enterChatRoom(...)`로 ChatroomActivity가 startActivity됨. 사용자가 ChatroomActivity에서 뒤로가기 → Chatroom 종료 → CouponListActivity 표면화 → `onResume` 발화.
- **근본 원인**: `CouponListActivity.kt`는 `HbBaseComposeActivity`의 기본 `onResume`(super만 호출) 외 별도 재조회 훅 없음. `loadData()`(= `viewModel.load()`)는 `BaseActivity.onCreate`에서 1회만 호출(line 47-48). 즉 **최초 진입 시에만 `/api/coupon` 조회**, 이후 다른 Activity 왕복 시 자동 재조회 훅이 없음. 서버에서 SKILL use로 쿠폰이 목록에서 제외되어야 하지만, 클라는 재요청하지 않아 메모리의 `_state.value.data`가 그대로 유지됨 → QA 현상 재현. 쿠폰함을 완전히 이탈 후 재진입 시 정상인 이유도 Activity 재생성 → onCreate → load() 경로이기 때문.
- **보조 확인**: `CouponListActivity.onActivityResult`(line 156-168)는 `SignupActivity` 결과에만 `viewModel.load()` 호출. Chatroom은 `startActivity`로 호출되어 result 콜백 없음. 뒤로가기 경로의 갱신 훅 부재가 명백한 원인.
- **수정 대상**: `app/src/main/java/com/thingsflow/hellobot/coupon/CouponListActivity.kt` (onResume 오버라이드 추가).
- **해결 방안**:
  1. **권장 (최소 변경)**: `CouponListActivity.onResume`을 오버라이드하여 `viewModel.load()` 호출.
     ```kotlin
     override fun onResume() {
         super.onResume()
         viewModel.load()
     }
     ```
     단점: 최초 onCreate 직후에도 onResume이 발화하므로 **load()가 2회 호출됨**. onCreate의 `loadData()`를 삭제하거나, `viewModel`에 "초기 로드 여부" 가드(또는 500ms dedupe) 추가 필요. 단순 중복은 사용자 영향 없고 서버 호출 1회 추가 수준.
  2. **대안 (정밀)**: SKILL 이용권 "사용 완료 시점"을 이벤트로 관찰해 refresh. Chatroom이 0원 결제 use 확정 시 브로드캐스트(LiveEventBus/Shared EventFlow 또는 startActivityForResult). 구현 복잡도 상승 — 비권장.
  3. **대안 (활성 창만)**: `lifecycleScope.launch { repeatOnLifecycle(Lifecycle.State.RESUMED) { viewModel.load() } }`. 1번안과 동일 효과, 과잉 설계.
- **iOS와의 해법 정합성 및 차이**: iOS는 `rx.viewWillAppear`로 이미 refresh 바인딩된 구조라 수정 불필요(또는 미미). Android는 **refresh 훅 자체가 부재**라 명시적 onResume load가 필요. 플랫폼 차이에서 비롯된 해법 차이이며, "진입마다 재조회"라는 UX 원칙은 동일.
- **영향 범위**: Android 단독. API/디자인 스펙 변경 없음. `viewModel.load()`는 state Loading/Data 전환 + 에러 시 빈 리스트 fallback(line 103-107) — 재호출 안전.
- **부수 효과 (긍정)**: 본 수정 시 ISS-034(이용권 접미사 탈락)의 Android 재현 여부도 동일 경로라 함께 해소될 가능성 높음. 현재 ISS-034 영향 파트는 "웹 (앱 확인 필요)"로 명시 — Android 확인 시 본 수정으로 일괄 해소 예상.
- **리스크**: onResume 중복 load에 따른 네트워크 요청 증가. 간이 가드(예: `isLoadInFlight: AtomicBoolean` 또는 `lastLoadedAt` 500ms dedupe)를 `load()` 진입부에 추가 검토 가능.

---

### ISS-035: 쿠폰 등록 완료 하트 팝업 이미지 GIF 미재생 (정적 이미지로 표시)

| 분류 | bug |
| 발견일 | 2026-04-22 |
| 심각도 | P3 |
| 영향 파트 | iOS, 웹 (Android는 GIF 재생 확인됨) |
| 상태 | iOS 해결 (2026-04-22) — `CoopHeartCompletePopupView.illustrationImageView`를 `UIImageView` + 정적 PNG(`_Coop/img_heart_complete`) → `ImageContentView` + 기존 하트충전 Lottie(`imgHeartchargeComplete`.asLocalAnimation, loopMode=.loop)로 교체. Lottie 원본 1184×576(≈2.055:1)이 design-spec 240×117(≈2.05:1)와 비율 일치 → 기존 제약 그대로 `.scaleAspectFit`로 꼭 맞음. 웹은 미해결. · **문서 정합 완료 (2026-04-22)** — 사용자 최종 결정("플랫폼별 기존 하트 충전 애니메이션 자산 재사용, 신규 발급 없음, 자산명·경로 강제 금지, 재생되는 애니메이션·240×117 비율 유지만 규범화")을 design-spec.md §S3 + §에셋 목록(S3 일러스트 자산 블록) / client-guide.md S3 / screen-plan.md §3 S3 구성 요소에 반영. 웹 구현 자산 확정은 별도 과업(tasks.md ISS-035 웹 항목)에서 "디자인 스펙 자산 확정 대기" 차단이 해제됨 — 기존 헬로우봇 하트 충전 관련 GIF/Lottie 탐색하여 적용 가능. |

**현상**: 하트 충전 쿠폰 등록 완료 팝업 내 이미지가 정적 이미지로 표시됨. 기존 하트충전 팝업(쿠폰 외 경로)은 GIF로 재생되므로 쿠폰 등록 완료 팝업도 동일하게 GIF 재생되어야 함. Android 앱에서는 이미 GIF 재생 확인됨(화란 테스트). iOS/웹 확인 필요.
**재현**: A-002 케이스.
**출처**: Notion DLT-HLB-1052.

**분석 (2026-04-22 iOS)**: 근본원인 — `CoopHeartCompletePopupView.swift:27-32`의 `illustrationImageView`가 `UIImageView` + `UIImage(named: "_Coop/img_heart_complete")`로 구성되어 정적 PNG만 로드. `_Coop/img_heart_complete.imageset`은 PNG 단일 에셋(`Contents.json`에 `img_heart_complete.png`만 등록). 반면 기존 하트충전 완료 팝업(`Legacy/Chatroom/ChargeHeartPopup/ChargeHeartPopupViewController.swift:69`)은 `ImageContentView.fetch("imgHeartchargeComplete".asLocalAnimation)` + `loopMode = .loop`로 Lottie 애니메이션(`Resources/Gif/imgHeartchargeComplete.json`) 재생. 해결방안 — (A) 권장: `illustrationImageView`를 `UIImageView` → `ImageContentView`로 교체 후 `fetch("imgHeartchargeComplete".asLocalAnimation)` + `loopMode = .loop`. 기존 Lottie JSON 자원 재사용이라 에셋 추가 비용 없고 성능·메모리도 Lottie 최적. (B) GIF 파일(`IconHeartCharge.gif` 등)로 로드 — `Bundle.main.url(forResource:withExtension:"gif")` + `ImageContentView.fetch(url)` (BonusCouponPopup 패턴). 단 하트 충전 완료 시나리오에 맞는 기존 GIF가 없어 디자인 에셋 신규 발급 필요. A안 추천(기존 자원 재사용, 기존 하트충전 팝업과 UX 통일). 수정 대상 — `Hellobot/Feature/Coupon/Coop/Popup/CoopHeartCompletePopupView.swift` (속성 타입/초기화/제약 유지). 기존 치수(`240×117`)는 Lottie JSON의 aspectRatio에 따라 재확인 필요. 영향 — iOS 단독. 기존 `_Coop/img_heart_complete.imageset`은 코드상 유일 참조라 A안 적용 후 정리 가능. 디자인 스펙 영향 — design-spec.md §S3의 "`img_heart_complete.png`" 문구를 "하트충전 완료 Lottie(`imgHeartchargeComplete`)"로 수정하도록 `/architect`에 스펙 보강 제안.

**분석 (2026-04-22 Web)**:
- **근본 원인**: `coopHeartCompletePopup.tsx:22-28`이 `<Image src="/images/coop/img_heart_complete.png" />` 정적 PNG를 로드. 실제 파일은 `public/images/coop/img_heart_complete.png` (1184×576 PNG, 32KB) — Android의 `img_heartcharge_completed.gif`와 달리 GIF 자산이 없음. design-spec.md §S3(line 93)와 §자산 목록(line 193)에도 PNG로만 명시됨 — **자산/스펙 모두 PNG로 정의되어 있어 본질적으로 GIF 미재생은 의도된 결과**. QA가 Android 동작을 기준으로 "GIF 재생되어야 함"이라 제기한 enhancement 성격.
- **수정 대상**:
  - design-spec.md §S3(line 89-97) + §자산 목록(line 193) — 디자인 스펙 보강 필요(`/architect` 작업).
  - `public/images/coop/` — GIF 신규 자산 또는 Lottie JSON 추가.
  - `app/coupon/components/coopHeartCompletePopup.tsx:23` — src 변경.
- **해결 방안 (대안)**:
  1. **권장**: 디자이너로부터 하트 충전 완료 GIF(또는 Lottie JSON) 발급받아 적용. iOS와 동일 의도(`imgHeartchargeComplete`) — 디자인 일관성 확보. `coopHeartCompletePopup.tsx`의 `<Image>`를 `<img>` 태그로 변경(Next.js `<Image>`는 GIF 애니메이션 미지원 — `unoptimized` prop 또는 일반 `<img>`로 대체 필수). Lottie 채택 시 `lottie-react`/`@lottiefiles/react-lottie-player` 도입 필요(번들 크기 검토).
  2. **임시(자산 재사용)**: Android의 `img_heartcharge_completed.gif`(가용 시)를 `public/images/coop/img_heart_complete.gif`로 복제 후 src 변경 + `<Image>` → `<img>` 또는 `<Image unoptimized>`. 디자인 검수 통과 후 정식 자산 받아 교체.
  3. **반려(현 PNG 유지)**: design-spec이 PNG로 명시되어 있으므로 스펙대로 두는 옵션. Android 동작과 격차 발생, QA 재기 가능성 → 비권장.
- **선결 작업**: design-spec.md §S3 자산 정의를 GIF/Lottie로 변경할지 `/architect`와 디자이너 합의 필요. 본 결정 후에야 1·2안 진행 가능 → **본 이슈는 단독 구현보다 `/architect` 보강 → 디자인 자산 발급 → 3-파트(웹/iOS) 병행 적용** 흐름이 정합.
- **영향 범위**: hellobot-web만. Android는 이미 GIF 재생 OK, iOS는 별도 분석에서 Lottie 채택 권장. hellobot-webview/-report-webview에는 본 팝업 미존재.

**업데이트 (2026-04-22 Web)**:
- **Android 구현 방식 확인 대기**: Android는 이미 GIF 재생 중(`img_heartcharge_completed.gif`). 웹에도 동일 자산/방식 적용을 위해 Android 파트로부터 아래 3가지 정보 확인 필요 — (1) 사용 중인 자산 파일명/경로/포맷(GIF or Lottie JSON), (2) 자산의 원본 출처(디자이너 제공 파일 또는 기존 헬로우봇 legacy 자산 재사용?), (3) 자산 치수/프레임레이트/반복 설정.
- **Android 답변 후 결정 흐름**:
  - (A) Android가 **legacy GIF `img_heartcharge_completed.gif`를 재사용** 중이라면 → 웹도 동일 GIF를 `public/images/coop/`로 복제 + `<Image>` → `<img>`(또는 `<Image unoptimized>`) 교체로 즉시 적용 가능. design-spec.md §S3 포맷도 PNG→GIF로 `/architect` 보강.
  - (B) Android가 **신규 자산**을 발급받았다면 → 디자이너에게 웹 대응 자산 동일 발급 요청 후 적용. 병행하여 `/architect`가 design-spec 업데이트.
- **진행 상태**: Android 답변 대기. 답변 수령 시 스펙 보강 + 자산 확보 2-step으로 즉시 착수 가능.

---

### ISS-034: 스킬이용권 사용 후 뒤로가기 시 쿠폰 이름의 "이용권" 텍스트 탈락

| 분류 | bug |
| 발견일 | 2026-04-22 |
| 심각도 | P2 |
| 영향 파트 | 웹 (앱 확인 필요) |
| 상태 | 미해결 |

**현상**: 스킬이용권 사용 후 뒤로가기 버튼으로 쿠폰함 복귀 시 "스킬명 + 이용권" 형태였던 쿠폰 이름이 "스킬명"으로 바뀌어 표시됨. 즉, "이용권" 접미사가 사라짐. ISS-036(사용 쿠폰이 목록에 남는 문제)과 같은 재현 경로에서 발견됨.
**재현**: 스킬이용권 쿠폰 등록 → 쿠폰 선택 → 대화방 진입 → 0원 결제 → 인트로 시작 → 뒤로가기로 대화방 이탈 → 쿠폰함 유지 → 사용 쿠폰 이름 변경 확인.
**기대**: 쿠폰 이름은 변동 없이 원본 그대로 유지되어야 함.
**출처**: Notion DLT-HLB-1051.

**분석 (2026-04-22 Web)**:
- **렌더 분기 흐름**: `app/coupon/page.tsx:61-72` — `isSkillVoucher = (c) => c.isUnlimited === true && c.fixedMenuSeq != null`로 쿠폰 분류. true → `CoopSkillVoucherItem`(line 105-111), false → `CouponItem`(line 112-114). `CoopSkillVoucherItem`은 `t('coop_skill_voucher_name', { value: data.productName })` = `"{value} 이용권"`(ko.json:1252). 즉 **"이용권" 접미사는 번역 템플릿에서 부착**됨. 반면 `CouponItem`(line 27-29)은 `coupon.name`을 그대로 출력하며 "이용권" 후처리 없음.
- **근본 원인 (가설)**: 쿠폰 사용 후 SWR가 `/api/coupon`을 재조회(또는 cache hit)할 때, 서버가 응답에서 `isUnlimited` 또는 `fixedMenuSeq`를 누락한 채 voucher를 반환 → `isSkillVoucher` 필터 false → `CouponItem` 분기로 떨어짐 → "이용권" 접미사 미부착으로 노출. 등록 직후에는 `pendingLocalSkillVouchers`(`page.tsx:70-72`)가 `CoopSkillVoucherItem`으로 노출되어 정상이었음.
  - 가능 원인 (서버 A): 사용 처리 후 직렬화 분기에서 `isUnlimited`/`fixedMenuSeq` 부착 누락.
  - 가능 원인 (서버 B): 사용된 voucher는 응답에서 제외돼야 하는데 포함됨(ISS-036) — 그 과정에서 일부 필드가 비정상 직렬화될 가능성.
  - 가능 원인 (데이터 형상): register 응답의 `data.productName`(=스킬명) vs `/api/coupon`의 `coupon.name`(=CouponSpec name)이 서로 다른 형식일 수 있음(api-spec.md:114 vs :229 예시 비교) — 분기에 정상 진입해도 텍스트 변형 가능. 단 QA가 보고한 "이용권 탈락"은 접미사 자체 사라짐이므로 분기 오류 가설(첫 번째)이 더 설명력 있음.
- **수정 대상**:
  - 1차(서버): `/api/coupon` used voucher 응답 확인 — Server 검토 단계로 이관. `isUnlimited` + `fixedMenuSeq`가 일관 응답되는지 검증.
  - 2차(웹, 보조 안전망): `app/coupon/page.tsx:61-62` — `isSkillVoucher` 필터에 OR 조건 추가. e.g., `(c.isUnlimited === true && c.fixedMenuSeq != null) || (c.discountType === 'PERCENTAGE' && c.discountValue === 100 && c.fixedMenuSeq != null)`. 100% + fixedMenu = voucher 의미적 안전망. 단 일반 100% 쿠폰 오탐 가능성 → **서버 정정 후 클라 보강** 우선순위.
- **공통 원인 (ISS-036과 연계)**: 두 이슈 모두 "사용 → back-nav → /coupon 재조회" 경로. 핵심은 **사용된 voucher의 `/api/coupon` 응답 처리** — 서버가 (a) 응답에서 제외하면 ISS-036/034 동시 해소, (b) 포함하되 필드 일관 유지하면 ISS-034만 해소. ISS-036의 bfcache 재조회 보강(pageshow + mutate)을 적용하면 stale 캐시 잔존도 함께 제거됨.
- **영향 범위**: hellobot-web. iOS/Android는 자체 voucher 모델이라 별개. hellobot-webview/-report-webview는 본 화면 미보유.

**업데이트 (2026-04-22 Web, ISS-036 Server 답변 반영)**:
- **부분 해소 예상**: 서버가 `/api/coupon`에서 사용된 voucher를 자동 제외함이 확인됨(ISS-036 업데이트 참조). ISS-036의 bfcache 재조회 훅(`pageshow + mutate`)을 적용하면 "사용 후 back-nav → 재조회 → used voucher 응답에서 사라짐" 흐름이 성립 → **ISS-034도 함께 해소될 가능성 높음**(다시 렌더되지 않으므로 "이용권 접미사 탈락" 현상 자체 발생 안 함).
- **잔여 확인 필요**: 단, QA가 본 이슈를 별건으로 등록한 이유 — register 직후/사용 전 상태에서 이미 텍스트가 달랐는지, 아니면 사용 후 한순간이라도 다른 텍스트가 보였는지 — 를 Server 답변 후 재확인 필요. 구체적으로:
  - 서버가 사용 **직전** 단계의 `/api/coupon` 응답에서 voucher의 `isUnlimited`/`fixedMenuSeq`를 일관 반환하는지
  - register 응답 `data.productName`과 `/api/coupon` `coupon.name`의 형식(스킬명 단독 vs "스킬명 이용권" 포함)이 일치하는지
- **진행 상태**: ISS-036 bfcache 훅 반영 후 **QA 재현 재테스트** → 재현 안 되면 클로즈. 재현 시에만 클라 `isSkillVoucher` 필터 보강 또는 Server 추가 조치.

---

### ISS-033: 일반 쿠폰 등록 성공 시 "쿠폰이 등록되었어요" 토스트 미노출

| 분류 | bug |
| 발견일 | 2026-04-22 |
| 심각도 | P3 |
| 영향 파트 | 웹, iOS, Android (확인 필요) |
| 상태 | iOS 해결 (2026-04-22) — `CouponListViewController.handleRegisterResponse(_:)` `.coupon` 분기에 `showCouponToast(.Coupon.Register.successToast)` 추가. 신규 로컬라이즈 `coupon_register_success_toast` ko/en/jp 등록(Android 문구와 통일). 스킬 성공 토스트도 `.Coupon.Register.skillSuccessToast`로 분리(문자열 리터럴 제거). 호출은 ISS-038 공용 `showCouponToast(_:)` 경유. 웹/Android는 미해결. |

**현상**: 일반(기존) 쿠폰이 성공적으로 등록되었을 때 확인 토스트가 노출되지 않음. 이전 쿠폰 기획에 포함되어 있었으나 구현이 누락된 것으로 보임. ISS-020 기준 스킬 이용권 등록 시 토스트는 노출됨 — 일반 쿠폰 플로우만 누락.
**재현**: A-001 케이스.
**출처**: Notion DLT-HLB-1049.

**분석 (2026-04-22 iOS)**: 근본원인 — `CouponListViewController.swift:172-187` `handleRegisterResponse(_:)`의 `switch issuedType` 분기에서 `.skill` 경로만 `showToast(msg: "스킬 이용권이 등록되었어요")`를 호출하고, `.coupon`(일반 쿠폰)은 `viewModel.refreshCoupon()`만 수행 — 성공 토스트 미호출. `.heart`는 S3 완료 팝업으로 대체되므로 제외. 해결방안 — (A) 권장: `.coupon` 케이스에 `showToast(msg: .Coupon.Register.successToast)` 추가. 문자열은 신규 `AppString.Coupon.Register.successToast`(ko/en/jp) 추가. (B) 서버 응답의 optional `toastMessage` 필드를 받아 표시 — API 확장 필요해 범위가 커짐, 반려. A안 추천. 수정 대상 — `Hellobot/Feature/Coupon/CouponList/CouponListViewController.swift:176` + 로컬라이즈 리소스 (`AppString` 정의). ISS-038 해결 후 `Toast(text:).show()`로 통일되어 있다면 그쪽 경로 사용. 영향 — iOS 단독. 문자열 스펙은 client-guide.md `"쿠폰이 등록되었어요"` 와 일치해야 함(웹 공통). 디자인 스펙 변경 없음. **스펙 제안**: client-guide.md S4(일반 쿠폰 성공 분기)에 "토스트 문구 '쿠폰이 등록되었어요' / 2.5초 / 1회 표시" 명시 추가를 `/architect`에 요청.

**분석 (2026-04-22 Android)**:
- **코드 경로**: `CouponListViewModel.register` onSuccess → `viewModelScope.launch { when(response.issuedType) { IssuedType.COUPON -> { load(); _toastEvent.value = Event(ResString(R.string.coupon_description_coupon_registered_successfully)) } ... } }` (line 137-143). Activity `observeUi()`의 `event(toastEvent) { SafeToast.showToastForDurationMs(...) }` (line 84-91)가 구독.
- **정적 분석상 결론**: iOS와 달리 Android는 `.COUPON` 분기에서 `_toastEvent.value = Event(...)`를 **emit하고 있음**. 문자열 리소스 3언어 보유(values-ko:1015 / values-ja:933 / values:1025 = "쿠폰이 등록되었어요").
- **의심 원인 후보** (QA "미노출" 재현이 사실이라면):
  1. **토스트 호출 이원화로 인한 Event 유실/타이밍 꼬임**: SKILL/HEART/ShowError는 `SharedFlow(coopEvent)` 단일 경로로 `SafeToast`를 호출. COUPON만 `LiveData<Event<StringModel>>(_toastEvent)` → 별도 Observer 경로. 두 경로의 수명주기/Event 1회성 처리가 다르고, `load()`가 `_loadingEvent` + Rx 체인을 동시에 트리거하는 찰나에 `_toastEvent.value =` 가 끼어 관찰 순서가 뒤바뀔 여지 존재.
  2. **구성 변경(화면 회전 등) 또는 재진입 시점**: `Event`는 1회 소비 래퍼. 재구독 시점에 이미 consumed 상태면 재노출 불가. 현실에서 재현도 낮지만 검증 필요.
  3. **Android 12+ 토스트 rate-limit**: 등록 직전 다른 토스트가 떠 있었다면 시스템 억제 가능. 낮은 개연성.
- **수정 대상**: `app/src/main/java/com/thingsflow/hellobot/coupon/CouponListViewModel.kt` (line 137-143), 필요 시 `CouponListActivity.kt` observeUi의 `event(toastEvent)` 블록.
- **해결 방안**:
  1. **권장 (SKILL 경로와 정합)**: LiveData `_toastEvent` 간접 경로를 버리고, `CoopEvent`에 `GeneralCouponIssued` 케이스 추가 → Activity에서 `SafeToast.showToastForDurationMs(ctx, R.string.coupon_description_coupon_registered_successfully, COOP_TOAST_DURATION_MS)`로 직접 호출. 이미 `SKILL`/`HEART`/`ShowError` 3분기가 모두 `coopEvent` SharedFlow를 쓰고 있어 일원화로 관찰 유실 여지 제거.
     ```kotlin
     // ViewModel
     IssuedType.COUPON -> {
         _coopEvent.emit(CoopEvent.GeneralCouponIssued)
         load()
     }
     // Activity
     is CoopEvent.GeneralCouponIssued -> {
         SafeToast.showToastForDurationMs(
             this@CouponListActivity,
             R.string.coupon_description_coupon_registered_successfully,
             COOP_TOAST_DURATION_MS,
         )
     }
     ```
  2. **대안(최소 변경)**: 현 코드에서 `load()` 호출과 `_toastEvent.value = Event(...)` 순서를 뒤집어 토스트 먼저 emit → `load()` 나중 호출. 타이밍 꼬임 가능성만 해소, LiveData Observer 경로는 유지 → 보수적.
  3. **검증용**: 디버그 빌드에서 `Log.d`로 (a) `_toastEvent.value = Event(...)` 진입 여부, (b) `event(toastEvent)` 콜백 진입 여부, (c) `SafeToast.showToastForDurationMs` 내부 진입 여부를 로그 → 원인 층위 좁힘 후 권장안 적용.
- **iOS 해법과의 정합성 및 차이**: iOS는 "emit 자체가 누락"되어 `.coupon` 분기 호출만 추가하면 끝. Android는 "emit은 되나 노출이 불확실"이라 관찰 경로를 SharedFlow로 일원화해 플랫폼 일관성 확보가 핵심. 양 플랫폼 모두 "성공 토스트를 직접 호출"하는 방향으로 수렴.
- **영향 범위**: Android 단독. `CoopEvent` 정의 확장은 `CouponListActivity` 단일 소비자 → 로컬 영향. 서버/디자인/문자열 추가 없음.
- **문서 제안**: iOS 분석이 제안한 "client-guide.md S4에 일반 쿠폰 성공 토스트 스펙 명시"에 동의 — Android도 동일 스펙 필요.

**결정 (2026-04-22, Android)**: **A안(SharedFlow 일원화)로 진행** 확정. `CoopEvent.GeneralCouponIssued` 신규 케이스 추가 → Activity에서 `SafeToast.showToastForDurationMs(ctx, R.string.coupon_description_coupon_registered_successfully, COOP_TOAST_DURATION_MS)` 직접 호출. `when(response.issuedType)`은 배타적 분기이므로 HEART/SKILL 케이스에 부수 영향 없음(하트 팝업+토스트 동시 노출 등 회귀 없음 — 사용자 확인). `_toastEvent` LiveData 경로는 본 이슈에서는 유지(다른 피처 사용처 확인 불필요, 범위 제한). 실기기 재현 검증은 구현 후 QA 회귀 테스트로 갈음.

**분석 (2026-04-22 Web)**:
- **근본 원인**: `app/coupon/components/couponCodeRegister.tsx:70-81` `case 'coupon'` 분기에 **성공 토스트 호출 자체가 없음**. 동일 함수의 `case 'skill'`(line 92-110)은 `dispatch(setToastMessage(t('coop_skill_complete_toast')))`를 호출하지만 일반 쿠폰 분기는 누락. iOS와 동일 패턴(분기 누락) — Phase 1 전환 시 skill 분기만 토스트 추가되고 일반 쿠폰 분기는 갱신 누락.
- **수정 대상**: `app/coupon/components/couponCodeRegister.tsx:73` 직후 (또는 `setUser(...)` 라인 위).
- **해결 방안**:
  1. **권장**: `dispatch(setToastMessage(t('coupon_register_complete_toast')))` 추가. 번역 키 신규 `coupon_register_complete_toast` = "쿠폰이 등록되었어요"(ko) + ja/en 동일 의미. 기존 `coop_skill_complete_toast`("스킬 이용권이 등록되었어요")와 일관 패턴.
  2. (대안) 기존 키 재사용 — 단 일본/영문 표현이 "스킬 이용권" vs "쿠폰" 차이가 있어 별도 키가 안전.
- **문구 정합성**: client-guide.md S4(일반 쿠폰 성공)에 토스트 스펙(문구 "쿠폰이 등록되었어요" / 2.5초 / 1회 표시)이 누락됨. iOS/Android 분석에서도 동일하게 `/architect`에 명시 추가 제안 — **본 이슈 구현 전 client-guide.md 보강 → 3-파트(웹/iOS/Android) 동일 문구 동시 적용**이 정합성 권장.
- **영향 범위**: hellobot-web만. iOS/Android 별도 파트. hellobot-webview/-report-webview는 본 등록 플로우 미보유.

---

### ISS-032: 웹 — 스킬 이용권 카드 "스킬 보러가기" 화살표 컬러가 텍스트와 다름

| 분류 | bug |
| 발견일 | 2026-04-22 |
| 심각도 | P3 |
| 영향 파트 | 웹 |
| 상태 | 미해결 |

**현상**: 웹 스킬 이용권 카드 하단 "스킬 보러가기 >" 링크의 화살표(chevron) 컬러가 텍스트 컬러와 일치하지 않음. 텍스트와 동일한 `#BE7AFE` (violet400)로 지정되어야 함.
**관련**: ISS-027은 iOS/Android의 아이콘 리소스 교체 건 — 웹은 별개 대응 필요.
**출처**: Notion DLT-HLB-1047.

**분석 (2026-04-22 Web)**:
- **근본 원인**: `coopSkillVoucherItem.tsx:47-53`이 공통 SVG `public/images/common/icon_arrow_right_small.svg`를 사용. SVG 본문은 `fill="#C6C8CC"` 하드코딩(원본 회색). 보라색 변환을 CSS `[filter:brightness(0)_saturate(100%)_invert(56%)_sepia(52%)_saturate(3619%)_hue-rotate(239deg)_brightness(102%)_contrast(99%)]`로 시도하지만 **filter chain은 정확한 hex 매칭을 보장하지 않음**(near-color, 브라우저별 차이). 결과적으로 텍스트(`#BE7AFE`)와 시각적으로 다른 보라/회보라가 노출됨.
- **수정 대상**: `app/coupon/components/coopSkillVoucherItem.tsx:47-53`(Image 부분), 필요 시 `public/images/common/` 자산 추가.
- **해결 방안 (대안)**:
  1. **권장**: 인라인 `<svg>`로 교체하고 path `fill="#BE7AFE"` 직접 지정. SVG는 16×16 단순 chevron이라 인라인 비용 미미. 아이콘 size는 12×12dp(Android와 동일) 또는 디자인 스펙 확인 필요.
  2. 신규 violet 변형 자산 추가 — `public/images/coop/icon_arrow_right_small_violet.svg` (`fill="#BE7AFE"`) 생성 후 `<Image src="...violet.svg" />`로 교체. 자산 한 개 추가 비용. 다른 화면에서도 재사용 가능성 있음.
  3. 원본 SVG의 `fill="#C6C8CC"` → `fill="currentColor"` 수정 후 부모에 `text-[#BE7AFE]` 적용. 단 **이 SVG는 다른 화면에서도 사용될 가능성**이 있어(`icon_arrow_right_small`이라는 일반명) 영향 범위가 넓음 — `Grep` 결과에 따라 안전성 결정 필요. 안전하지 않으면 1·2안 우선.
  4. CSS filter 매개변수를 정확한 #BE7AFE에 맞게 재계산 — 가능하나 브라우저 렌더링 차이로 fragile. 비권장.
- **부가**: ISS-027(iOS/Android)는 텍스트 ` >` 문자열을 아이콘 리소스로 교체하는 별개 작업. 웹은 이미 SVG를 사용하지만 컬러만 어긋남.
- **영향 범위**: hellobot-web만. 3안 채택 시 `icon_arrow_right_small.svg` 사용처 전수 조사 필요(영향 확장 가능). hellobot-webview/-report-webview에는 본 카드 미존재.

---

### ISS-031: 웹 — 스킬 이용권 쿠폰 카드 여백이 기존 쿠폰과 불일치

| 분류 | bug |
| 발견일 | 2026-04-22 |
| 심각도 | P3 |
| 영향 파트 | 웹, iOS(규범 정합 후속) |
| 상태 | 미해결 (구현). · **문서 정합 완료 (2026-04-22)** — 사용자 최종 결정("일반 쿠폰 카드 실측 기준으로 동일 박스 높이·점선 여백 유지, 누락 요소는 레이아웃 공간 reserve + 내용 미노출(invisible), 신규 측정값/행 collapse 금지")을 design-spec.md §S4 "레이아웃 일관성 규범" / client-guide.md S4 / screen-plan.md §3 S4 구성표·§7 고려사항에 반영. iOS는 ISS-041에서 collapse(`isIncludedInLayout = false`) 방식으로 이미 구현되어 있어 reserve 규범과 상충 — 별도 "iOS reserve 정합" 후속 과업으로 추적(본 이슈 범위 내 구현은 웹 미해결 유지). |

**현상**: 웹 스킬 이용권 쿠폰 카드의 여백이 기존 쿠폰 카드와 맞지 않음. 다음 3가지 조정 필요:
1. 서브 텍스트("30,000원 이상 결제 시") 영역 — 스킬 이용권은 해당 텍스트가 없으므로 **그 영역만큼의 빈 공간**이 유지되어야 함 (기존 쿠폰과 수직 정렬 맞추기 위함).
2. 점선 아래 영역이 기존 쿠폰과 동일한 간격/여백을 가져야 함.
3. 쿠폰 카드 자체 높이값이 기존 쿠폰과 동일해야 함 (현재는 더 좁게 렌더링됨).

**재현**: A-001 케이스.
**출처**: Notion DLT-HLB-1045.

**분석 (2026-04-22 Web)**:
- **근본 원인 (3가지 차이 매핑)**:
  1. **서브텍스트 영역 누락**: `CouponItem`(`couponItem.tsx:30-41`)은 `<p>`로 `coupon_discount_min_value` ("N원 이상 결제 시")를 항상 렌더하여 텍스트 1행 분량의 수직 공간 점유. `CoopSkillVoucherItem`(`coopSkillVoucherItem.tsx:23-32`)는 할인율 + 제목만 렌더하고 서브텍스트 자리(reserve)가 없음 → 카드 상단 블록이 1행만큼 짧음.
  2. **점선 아래 간격 차이**: `CouponItem`은 점선 `<div className="my-[12px] ...">`(상하 12px 마진) + 만료일 행(text-[12px]/leading-[18px]) 노출. `CoopSkillVoucherItem`은 점선이 외부 `flex-col gap-[12px]` 컨테이너의 형제로 들어가고, 점선 다음 영역이 `pt-[4px]`만 가져 점선~링크 사이 간격이 짧음. `flex` `gap`은 점선 자체에 마진을 주지 않아 시각적 패딩 불일치.
  3. **카드 높이 단축**: 1번 + 2번 영향이 누적되어 카드 내부 콘텐츠 높이가 약 18~24px 정도 작아져 전체 카드가 짧게 보임. `CoopSkillVoucherItem`의 외부 `<li>`에는 명시적 `min-height` 없음.
- **수정 대상**: `app/coupon/components/coopSkillVoucherItem.tsx` 전반(주로 line 17-56).
- **해결 방안**:
  1. **권장(레이아웃 모방)**: `CouponItem`의 마크업 구조(블록 + my-[12px] 점선 + 하단 행)와 동일한 수직 리듬을 채택. 구체적으로:
     - 컨테이너 `flex flex-col gap-[12px]` 대신 자유 마진 사용 (`mb-[2px]` 제목, 그 뒤 reserved spacer, `my-[12px]` 점선, 하단 행).
     - 서브텍스트 자리 reserve: 빈 `<p className="text-[12px] leading-[18px] tracking-[-0.3px] invisible" aria-hidden>placeholder</p>` 또는 `<div style={{height: '18px'}} />` 추가 (가시 텍스트 노출 금지).
     - 점선 마진 `my-[12px]` 적용 (현재 `border-t border-dashed` 자체엔 마진 없이 외부 gap 의존 → 명시적 마진).
     - 하단 행 padding `pt-[4px]` 제거(혹은 `CouponItem`과 동일하게).
  2. **대안(높이 강제)**: 카드 외부 `<li>`에 `min-h-[N]px` 직접 지정. 단 내부 정렬 문제(서브텍스트 자리 부재)는 해소 안 됨 → 1안 권장.
  3. **장기**: `CouponItem`/`CoopSkillVoucherItem` 공통 베이스 컴포넌트 추출. 현재 시점에선 범위 초과.
- **부가 검증 필요**: design-spec.md §S4(line 99-129)에 카드 height 명시값이 없음 — Figma 원본 측정값을 디자이너에게 확인 후 1안 적용. 픽셀 정합 위해 현 `CouponItem` 렌더 결과(서브텍스트 + 만료일 노출 시 카드 height)를 기준으로 reserve 높이 산출.
- **영향 범위**: hellobot-web만. ISS-037(라벨 디자인), ISS-032(화살표 컬러)와 같이 `CoopSkillVoucherItem` 한 컴포넌트 안에서 발생하는 시각 이슈 군집 — 함께 수정하면 작업 효율적.

**업데이트 (2026-04-22 Web)**:
- **디자이너 답변 대기**: Figma 원본 측정값 필요 — (1) S4 스킬 이용권 카드의 **전체 높이** (기존 쿠폰 카드와 동일한지, 동일하면 정확한 px), (2) **서브텍스트 reserve 영역 높이**(leading-18px 한 행 분량인지 별개 spacing인지), (3) **점선 위·아래 수직 여백**(기존 `my-[12px]`와 동일 여부).
- **답변 후 즉시 착수 가능**: 답변 수령 시 "해결 방안 1번(CouponItem 구조 모방)" + 확인된 픽셀 값으로 적용. ISS-037/ISS-032와 동일 컴포넌트라 동반 PR 권장.
- **진행 상태**: 디자이너 답변 대기.

---

### ISS-030: 앱 — 미로그인 상태 쿠폰 입력창 포커스 시 로그인 토스트 누락 (iOS/Android)

| 분류 | enhancement |
| 발견일 | 2026-04-21 |
| 심각도 | P3 |
| 영향 파트 | iOS, Android |
| 상태 | Android 해결 (2026-04-22) — `CouponListActivity.CoopEvent.NavigateToLogin` 분기를 호출 측 선표시 방식으로 전환. `SafeToast.showToastForDurationMs(ctx, R.string.common_toast_plz_login, COOP_TOAST_DURATION_MS)` 호출 후 `SignupActivity.enterForResult(activity, null, "coop_coupon_input")`로 Intent extra 토스트는 null 전달(중복 회피). / iOS 해결 (2026-04-22) — `CouponListViewController`의 editingDidBegin 핸들러와 `sendCouponCode()` 미로그인 가드 2개 `presentSingup()` 호출부에 `AppString.toastPlzLogin` 인자 전달 → `goSignupModal(message:)`가 로그인 화면 전환 시 안내 토스트 노출. client-guide.md S6 "로그인 화면 전환 시 안내 토스트 1회 노출" 명시 추가는 `/architect` 대기. |

**현상**: 미로그인 상태에서 쿠폰 입력창 포커스 시 화면 전환(goToLogin) 과정에 '로그인이 필요합니다' 토스트가 노출되어야 하는데 미노출. 웹은 ISS-002/007을 통해 해결된 케이스의 앱 동등 적용 건.
**기대**: 입력창 포커스 시 로그인 화면으로 이동하면서 안내 토스트 표시.
**출처**: Notion DLT-HLB-1034.

**분석 (2026-04-22 iOS)**: 근본원인 — `CouponListViewController.swift:87-96`의 editingDidBegin 핸들러와 `sendCouponCode()` 미로그인 분기가 모두 `presentSingup()`을 **인자 없이** 호출. `presentSingup(with message: String? = nil)`이 `goSignupModal(message: nil, ...)`로 전달하는데, `RouterProtocols.swift:19-26`는 message가 nil일 때 토스트 표시 블록을 건너뜀. 반면 StoreVC/MyHeartVC/FreeHeartInjector 등 다른 화면은 모두 `AppString.toastPlzLogin`을 명시 전달. 해결방안 — (A) 권장: `editingDidBegin` 핸들러와 `sendCouponCode()`의 두 `presentSingup()` 호출부에 `presentSingup(with: AppString.toastPlzLogin)`로 변경. (B) `presentSingup` 디폴트 값을 `AppString.toastPlzLogin`으로 변경 — 간단하나 향후 의도적 무음 호출의 여지 차단. A안 추천(명시성). 수정 대상 — `Hellobot/Feature/Coupon/CouponList/CouponListViewController.swift` 2개 호출부. 영향 — iOS 단독. 문자열은 기존 `AppString.toastPlzLogin` (ko/en/jp 기존 번역 보유) 재사용 → 서버/디자인 파트 영향 없음. **문서 불일치 제안**: client-guide.md S6 본문이 "팝업 없이 바로 이동 — 별도 확인 UI 불필요"로 토스트를 명시하지 않음. `/architect`가 S6에 "로그인 화면 전환 시 안내 토스트 1회 노출(앱/웹 공통)" 문구를 추가하도록 제안.

**분석 (2026-04-22 Android)**:
- **코드 경로**: `CouponListViewModel.onInputFocused()` (line 79-85)가 anonymous일 때 `CoopEvent.NavigateToLogin` emit → `CouponListActivity.observeUi` NavigateToLogin 분기 (line 142-149) → `SignupActivity.enterForResult(ctx, getString(R.string.common_toast_plz_login), "coop_coupon_input")`. `SignupActivity.onCreate:219-223`이 Intent extra `KEY_TOAST_MESSAGE`를 꺼내 `SafeToast.showToast(this, toastMsg, Toast.LENGTH_SHORT)`로 도착지에서 토스트 노출.
- **근본 원인**: 토스트를 "호출 측 Activity(쿠폰함)"가 아닌 "도착지 Activity(Signup)"에서 띄우는 설계. Signup이 `overridePendingTransition(R.anim.slide_up_anim, R.anim.hold)`로 슬라이드업 전환되는 찰나에 토스트가 도착지 화면에 시작되어 사용자 인지에서 묻힘. 또한 "원래 화면에서 안내 → 전환"이라는 UX 순서를 제공하지 못함. Web(ISS-002/007)/iOS(본 이슈의 권장안)는 모두 "쿠폰함에서 토스트 → 로그인 이동" 흐름을 전제.
- **보조 원인**: `SafeToast.showToast(..., Toast.LENGTH_SHORT)` = 약 2초. 전환 애니메이션 중 짧은 지속으로 시각 인지 저하.
- **수정 대상**: `app/src/main/java/com/thingsflow/hellobot/coupon/CouponListActivity.kt` NavigateToLogin 분기 (line 142-149).
- **해결 방안 (권장 A)**: 쿠폰함 Activity에서 먼저 토스트 → 그다음 Signup 전환. Intent extra 토스트는 중복 노출 회피를 위해 `null` 전달.
  ```kotlin
  is CoopEvent.NavigateToLogin -> {
      currentFocus?.clearFocus()
      SafeToast.showToastForDurationMs(
          this@CouponListActivity,
          R.string.common_toast_plz_login,
          COOP_TOAST_DURATION_MS,  // 2500ms, ISS-016 기준과 일치
      )
      SignupActivity.enterForResult(this@CouponListActivity, null, "coop_coupon_input")
  }
  ```
- **대안 B**: Intent extra 토스트 유지 + `SignupActivity.onCreate`의 `SafeToast.showToast(..., Toast.LENGTH_SHORT)`를 `SafeToast.showToastForDurationMs(..., 2500L)`로 변경. 그러나 "쿠폰함에서 노출" UX 기대와 어긋나 비권장. iOS 권장안("호출 측에서 명시")과도 정합 X.
- **iOS와의 해법 정합성**: iOS는 `presentSingup(with: AppString.toastPlzLogin)`으로 **호출 직전** 호출 측 라우터가 토스트를 띄움. Android A안은 "호출 측에서 명시적으로 띄우고 이동"이라는 동일 원칙 → 플랫폼 일관성 확보.
- **영향 범위**: Android 단독. CouponInputSection `onFocus` 콜백 경로 + `onInputCoupon` 클릭 경로 둘 다 동일 NavigateToLogin 이벤트를 쓰므로 한 곳 수정으로 양쪽 해결.
- **문자열 리소스**: `common_toast_plz_login` ko(values-ko:354) / ja(values-ja:324) / en(values:357) 보유 확인 — 추가 번역 불필요.
- **잔존 리스크**: 로그인 취소 후 쿠폰함 재진입 시 `TextField` 자동 재포커스로 `onFocusChanged`가 재발사 → NavigateToLogin 중복 트리거 가능. 현행 코드도 동일 리스크로 본 이슈 범위 밖이나 재현되면 `CouponListViewModel`에 단발 가드(예: `hasPromptedLogin` 플래그) 별도 과업화 권장.

---

### ISS-029: Admin — "Coupon Prefix Rule" 메뉴명 한글화 필요

| 분류 | enhancement |
| 발견일 | 2026-04-21 |
| 심각도 | P3 |
| 영향 파트 | 서버 (Admin) |
| 상태 | 해결 (2026-04-22) — `src/admin/locale.ts` labels에 `CouponPrefixRule: "쿠폰 분류 규칙 설정"` 추가 (COOP_MARKETING 라벨 블록 하단 인접 배치). AdminJS 표준 번역 경로로 DB/API 영향 없음. |

**현상**: AdminJS 사이드바의 `Coupon Prefix Rule` 메뉴명이 영문으로 노출됨.
**기대**: 한글 "쿠폰 분류 규칙 설정"으로 변경.
**출처**: Notion DLT-HLB-1026.

**분석 (2026-04-22 서버)**: 근본 원인은 `src/admin/locale.ts`의 `translations.labels` 사전에 `CouponPrefixRule` 엔트리가 누락된 것. AdminJS는 labels 매핑이 없으면 리소스 클래스명(`CouponPrefixRule`)을 공백 구분 단어화(`Coupon Prefix Rule`)해 기본 렌더링함. 동일 사이드바(COOP_MARKETING)의 `CoopMarketingProduct`(locale.ts:69), `CoopMarketingCouponUsage`(:70), `CoopMarketingApiLog`(:71) 3건은 한글 라벨이 등록되어 있으나 `CouponPrefixRule`만 ISS-009/ISS-011 Phase 1 구현 시(api-spec.md:434 기준 2026-04-19) locale 추가가 누락됨.
- **수정 대상**: `src/admin/locale.ts` labels 블록에 한 줄 추가 — 예: `CouponPrefixRule: "쿠폰 분류 규칙 설정",`. 주변 COOP 라벨(69-71라인) 인접 배치가 정렬상 자연스러움.
- **대안**: `src/admin/options/CouponPrefixRule.options.ts`의 ResourceOptions에 `navigation.name` 또는 `id: "쿠폰 분류 규칙 설정"` 지정도 가능하나, 기존 리포 컨벤션(locale.ts 중앙집중)에서 벗어나므로 비권장.
- **영향 범위**: AdminJS UI 단일 파일 변경. API/DB 영향 없음. 배포 즉시 반영, 호환성 리스크 없음. P3 수준으로 다른 서버 수정과 번들 배포 가능.
- **후속**: hellobot-studio 측 AdminJS는 별도 locale이라 본 수정 대상 아님 (리포 확인 불필요).

---

### ISS-028: Android — 하트충전완료 모달(S3) 디자인 이슈 (가로 꽉참 + 이미지 작음)

| 분류 | bug |
| 발견일 | 2026-04-21 |
| 심각도 | P2 |
| 영향 파트 | Android |
| 상태 | 해결 (2026-04-21) |

**현상**:
- 하트 충전 완료 모달 박스가 화면 가로로 꽉 참 — 양쪽 여백 필요.
- 하트 충전 일러스트 이미지가 너무 작게 노출됨.

**재현**: 하트 충전권 등록 완료(`issuedType=heart`) → S3 완료 모달 노출.
**스펙 기준**: design-spec.md §S3 — 캐릭터+하트 일러스트(`img_heart_complete.png`) + 여백 포함 카드형 모달.
**원인**: `BaseDialogFragment` window가 MATCH_PARENT라 내부 Column의 `fillMaxWidth()`가 화면 끝까지 확장. 일러스트는 `size(131.dp)` 단일 제약으로 iOS(240×117dp) 대비 소폭.
**조치**: design-spec §"공통 컴포넌트 팝업"(너비 288dp / radius 20 / padding 24 / shadow `0 8 24 rgba(0,0,0,0.24)`)에 맞춰 `CoopHeartCompleteScreen`를 재정렬. 외곽 `Box(fillMaxSize, contentAlignment = Center)` + 카드 `Column`에 `width(288.dp)` 고정 + `shadow(elevation = 24.dp, RoundedCornerShape(20.dp), ambientColor/spotColor = Color.Black.copy(alpha = 0.24f))` 추가. 일러스트는 `width(240.dp).height(117.dp)`로 확대(iOS 치수 동일, 288 - 24×2 = 240 내부 폭과 일치).
**출처**: Notion DLT-HLB-1022.

---

### ISS-027: S4 "스킬 보러가기 >" 화살표가 이미지 리소스가 아닌 텍스트로 구현됨 (iOS + Android)

| 분류 | bug |
| 발견일 | 2026-04-21 |
| 심각도 | P3 |
| 영향 파트 | iOS, Android |
| 상태 | iOS 해결 (2026-04-21) — CouponItemCell의 skillLinkLabel 텍스트에서 ">" 제거. "스킬 보러가기" 라벨 + chevron UIImageView(SF Symbol `chevron.right`, violet400 틴트, 10pt bold)를 horizontal flex 컨테이너로 묶어 우측 정렬 유지. `_Coop` 에셋 추가 없이 SF Symbol로 해결(별도 리소스 불필요). / Android 해결 (2026-04-22) — `coop_link_view_skill` 문자열 3종(ko/ja/en)에서 ` >` 제거, `CouponItem.kt` 우측 링크를 `Row(Text + Icon)` 구조로 재구성. 기존 벡터 드로어블 `R.drawable.icon_arrow_right_16` 재사용 + `Icon(tint = Color(0xFFBE7AFE))`로 violet400 틴트 오버라이드(원본 fillColor `#C6C8CC`는 Compose `Icon` 틴트에 의해 가려짐). 아이콘 크기 12×12dp. |

**현상**: 스킬 이용권 카드의 "스킬 보러가기" 텍스트 링크 오른쪽 `>` 화살표가 텍스트 문자로 들어가 있음. 디자인 스펙은 이미지(아이콘) 리소스.
**재현**: 스킬 교환권 쿠폰 등록 완료 → 쿠폰 리스트의 스킬 이용권 카드 관찰.
**관련**: ISS-019(링크 추가), ISS-023(우측 정렬) — 두 건은 04-21 해결됨. 본 건은 후속 아이콘 리소스 교체 이슈.
**출처**: Notion DLT-HLB-1020.

---

### ISS-026: iOS — 쿠폰 코드 등록 에러 메시지 표시 오류 (영문 노출, 빈 토스트)

| 분류 | bug |
| 발견일 | 2026-04-21 |
| 심각도 | P2 |
| 영향 파트 | iOS |
| 상태 | 해결 (2026-04-21) — `CouponRegisterErrorMapper` 신설하여 CouponListViewController.registerCoupon 에러 파이프라인에 적용. 서버 `error.message`가 Hangul을 포함하면 그대로 표시, 비-한글/빈 문자열이면 client-guide.md S5 매핑표(CM_001~CM_010, CO_APP_UPDATE_REQUIRED) ko 상수로 폴백. URLError/AFError `.notConnectedToInternet` 등 오프라인 케이스는 "인터넷 연결이 오프라인 상태입니다." 고정 메시지, 기타 원인 불명 에러는 일반 ko 메시지로 치환. ReasonServerError 경로도 한글 포함 여부 기반 선택으로 통일. |

**현상**: 쿠폰 코드 등록 시 에러 케이스별로 메시지가 잘못 노출됨.
- 유효하지 않은 쿠폰 코드 → `invalid coupon code` 영문 메시지 노출 (한글로 표기되어야 함).
- 이미 사용된 쿠폰 → 빈 메시지 토스트.
- 결제 취소/기간 만료 쿠폰 → 빈 메시지 토스트.
- B-008 오프라인 상태 → 영문 포함 메시지. "인터넷 연결이 오프라인 상태입니다." 한글 부분만 노출되어야 함.

**특이사항**: 잠시 후 재시도하면 정상 노출되는 경우도 있음 — 구현상 타이밍 이슈 검토 필요.
**스펙 기준**: client-guide.md S5 에러 매핑표(CM_001~CM_010, CO_APP_UPDATE_REQUIRED). 서버 응답 `error.message`(ko)를 그대로 표시하도록 되어 있음.
**원인 (추정)**: iOS 에러 처리 로직이 서버 `error.message` 대신 원시 영문 ResultMessage나 로컬 상수를 일부 케이스에서 폴백으로 사용하는 것으로 보임.
**출처**: Notion DLT-HLB-1016.

---

### ISS-025: 웹 — 스킬 교환권 쿠폰 카드 재진입 시 하단 "스킬 보러가기" 영역 사라짐 + 탭 미동작

| 분류 | bug |
| 발견일 | 2026-04-21 |
| 심각도 | P2 |
| 영향 파트 | 웹 |
| 상태 | 해결 (2026-04-21) |

**현상**:
- 카카오 스킬 교환권 쿠폰 등록 직후에는 스킬 이용권 카드가 정상 표기됨 (하단 "스킬 보러가기 >" 링크 포함, 카드 탭 동작).
- 이후 새로고침 또는 화면 이탈(뒤로가기 → 프로필) 후 쿠폰 화면에 재진입하면 카드 하단 "스킬 보러가기" 영역이 사라지고, 쿠폰 카드 탭 이벤트도 동작하지 않음.

**재현**:
1. 웹 `/coupon` 진입
2. 카카오 스킬 교환권 쿠폰 코드 등록 → 정상 표기 확인
3. 뒤로가기로 프로필 화면 이동
4. 다시 쿠폰 화면으로 재진입
5. 스킬 이용권 카드 하단 섹션 미노출 + 탭 무반응

**스펙 기준**: design-spec.md §S4 — 스킬 이용권 카드는 하단 "스킬 보러가기 >" 링크 포함, 카드 탭/링크 탭으로 스킬 상세 이동.
**원인 (추정)**: 최초 등록 직후에는 Redux 스토어의 신규 쿠폰 객체(`fixedMenuSeq`/`isUnlimited` 포함)로 렌더링되지만, 재진입 시 `useGetCoupon` SWR 응답으로 덮어쓰면서 `fixedMenuSeq` 필드나 스킬 카드 전용 렌더링 분기가 누락되는 것으로 보임. ISS-017(즉시 반영) 수정으로 SWR mutate가 활성화된 뒤 재노출된 가능성 있음.
**영향**: 재진입 후 사용자가 스킬 상세로 이동할 경로가 없어 쿠폰 활용 불가.
**출처**: Notion DLT-HLB-1002.

---

### ISS-024: S4 스킬 이용권 카드 — Android에서 "스킬 보러가기 >" 링크가 좌측 정렬됨 (iOS ISS-023과 동일 패턴)

| 분류 | bug |
| 발견일 | 2026-04-21 |
| 심각도 | P3 |
| 영향 파트 | Android |
| 상태 | 해결 (2026-04-21) |

**현상**: Android 이용권 카드 하단의 "스킬 보러가기 >" 링크가 좌측 정렬됨. `CouponItem.kt`에서 만료일 Row 아래에 별도 `MarginSpacer(8.dp)` + `Text(modifier = wrapContentSize)`로 수직 스택 배치되어 있음. design-spec.md S4 확정 레이아웃은 하단 행이 `space-between`(좌=유효기간, 우=링크)이어야 함.
**원인**: design-spec.md S4 레이아웃 명시 누락(2026-04-21 보강) 이전에 구현되어 iOS와 동일한 편차 발생. 링크 텍스트(ISS-019)를 추가할 때 하단 좌우 분할 구조로 통합하지 못하고 별도 행으로 추가.
**조치**: `CouponItem.kt` 하단 Row를 `Modifier.fillMaxWidth()` + 좌측 Row(`weight(1f)` 적용, 유효기간/`isUnlimited` 분기 포함)와 우측 링크의 2-child 레이아웃으로 재구성. ISS-022 무제한 분기는 좌측 컨텐츠 빈 처리로 흡수.
**관련**: ISS-019(링크 추가), ISS-022(무제한 케이스 좌측 비움), ISS-023(iOS 동일 이슈)

---

### ISS-023: S4 스킬 이용권 카드 — iOS에서 "스킬 보러가기 >" 링크가 좌측 정렬됨 + design-spec 레이아웃 명시 누락

| 분류 | bug |
| 발견일 | 2026-04-21 |
| 심각도 | P3 |
| 영향 파트 | iOS, design-spec |
| 상태 | design-spec 보강 완료 (2026-04-21), iOS 해결 (2026-04-21) |

**현상**: iOS 이용권 카드 하단의 "스킬 보러가기 >" 링크가 좌측 정렬됨. Figma 디자인(`10:12563`, `10:12592`, `10:12594`, `10:12622`)은 하단 좌=유효기간, 우=링크의 `space-between` 구조.
**원인**: design-spec.md S4 섹션이 요소별 스타일(폰트/색상)만 기재하고 **하단 좌우 분할 레이아웃을 명시하지 않아** 구현 편차 발생. iOS는 요소를 수직 스택으로 구현하여 좌측 정렬됨.
**조치**:
- design-spec.md S4에 레이아웃 다이어그램 + "스킬 보러가기 >" 우측 정렬 필수 명시 (Changelog 2026-04-16)
- iOS/Android 리뷰 체크리스트에 "하단 우측 정렬" 명시 추가
- iOS 구현에서 `HStack` + `Spacer`로 수정 필요
**관련**: ISS-019 (링크 텍스트 미노출과 별개 — 여기는 정렬 문제)

---

### ISS-022: ISS-021 구현이 API 호환성 원칙 위반 — `CouponDto.expiresAt` nullability 변경

| 분류 | bug |
| 발견일 | 2026-04-21 |
| 심각도 | P1 |
| 영향 파트 | 서버, iOS, Android, 웹 |
| 상태 | 서버 해결 (2026-04-21), iOS 해결 (2026-04-21), Android 해결 (2026-04-21), Web 해결 (2026-04-21) |

**현상**: ISS-021 해결 과정에서 `GET /api/coupon` 응답의 `CouponDto.expiresAt` 필드 타입을 `Date` → `Date | null`로 변경. CLAUDE.md "기존 필드 수정 금지, 필드 추가 우선" 호환성 원칙 위반. dev 환경에서 nullable 미대응 클라이언트가 NULL expiresAt 쿠폰을 응답으로 받으면 디코딩 실패 → 보유 쿠폰 0건 표시 회귀 발생 (taenyon@neuralarcade.ai 케이스로 확인).

**원인**: ISS-021 설계 시 호환성 원칙을 반영하지 못함. DB NULL 의미 보존만 우선, API 인터페이스 안정성 누락.

**영향**:
- **dev 환경**: nullable 미대응 클라이언트(웹/Android)에서 Coop 스킬 이용권 보유 사용자의 쿠폰 리스트 디코딩 실패 → 0건 표시
- **production 영향 (현재)**: 직접적 회귀 미미 — Coop 자체 미배포 + ISS-009 가드로 구버전 앱이 NULL 쿠폰 받을 수 없음. 단 신·구 다운그레이드/멀티 디바이스 엣지 케이스 위험
- **production 영향 (Coop 배포 후)**: 신버전 앱에서 받은 NULL 쿠폰을 같은 계정의 구버전 디바이스가 조회 시 쿠폰함 깨짐 가능

**해결 방안 (확정 2026-04-21)**: **DB는 NULL 유지 + API 응답은 sentinel + isUnlimited 신규 필드** (Option D)
- DB `coupon.expires_at`: NULL 유지 (스펙 의미 보존)
- `findUsableCoupons` 쿼리: `(expires_at IS NULL OR > NOW())` 유지 (영구 쿠폰 리스트 노출)
- `CouponDto.expiresAt: Date` (non-null로 복귀) — 직렬화 시 NULL → `UNLIMITED_EXPIRES_AT_SENTINEL = "2099-12-31T23:59:59.000Z"`
- `CouponDto.isUnlimited?: boolean` 신규 optional 필드 — true면 클라이언트가 만료일 행 미표시 권장
- 신버전 클라이언트(iOS/Android/Web): `isUnlimited === true`이면 만료일 행 숨김
- 구버전 클라이언트: sentinel 날짜 그대로 표시 ("2099-12-31") — 사용 정상, 표시만 이상 (비크리티컬, 일반 호환)
- Phase 2 장기: 모든 클라이언트 보급 충분 시 sentinel 제거 후 진짜 NULL 직렬화 전환 검토 (선택)

**호환성 매트릭스**:
| 시나리오 | 결과 |
|---------|------|
| 구버전 + 일반 쿠폰 | 정상 |
| 구버전 + Coop 스킬 이용권 보유 | 사용 정상, "2099-12-31" 표시 |
| 신버전 + 일반/Coop 쿠폰 | 정상, isUnlimited true 시 만료일 행 숨김 |
| 신·구 다운그레이드/멀티 디바이스 | 정상 (디코딩 실패 없음) |

**참조**:
- 호환성 원칙: hellobot-server/CLAUDE.md "API 호환성"
- ISS-021: 본 문제의 원천 변경

---

### ISS-021: 스킬 이용권(100% 할인 쿠폰) 발급 시 유효기간이 설정됨 — 스펙은 무제한

| 분류 | bug |
| 발견일 | 2026-04-21 |
| 심각도 | P1 |
| 영향 파트 | 서버 |
| 상태 | 서버 해결 (2026-04-21), 부수 이슈(클라이언트 카드 유효기간 행 조건부 표시)는 별개 |

**현상**: 스킬 교환권 쿠폰 등록(`issuedType: "skill"`) 후 발급되는 100% 할인 쿠폰에 이용 유효기간이 설정되어 있음. 쿠폰 리스트에서 만료일이 표시됨.
**스펙 기준**: readme.md F3 — "발급된 스킬 이용권에는 유효기간 없음 — 발급 즉시 영구 사용 가능". ISS-003 해결 시 확인 — "교환된 상품(하트/이용권)에는 유효기간이 없음".
**원인 (추정)**: `CouponService.issueCoupon(userSeq, couponSpecSeq)` 호출 시 CouponSpec에 설정된 유효기간이 그대로 적용되거나, 발급 로직에서 기본 유효기간(예: 90일)이 자동 부여되는 것으로 추정. 스킬 이용권용 CouponSpec의 유효기간을 무제한으로 설정하거나, 발급 시 유효기간을 null로 override해야 함.
**영향**: 사용자가 발급받은 스킬 이용권이 기간 경과 후 만료되어 사용 불가해지는 치명적 문제. 카드 UI에도 불필요한 만료일/만료임박 표시.
**부수 이슈**: design-spec.md, screen-plan.md S4 카드 구성표에 유효기간/만료임박 행이 있으나, 스킬 이용권에 유효기간이 없으므로 조건부 표시(유효기간이 있는 쿠폰만 노출)로 수정 필요. → **해결 (2026-04-21)**: design-spec.md / screen-plan.md / client-guide.md S4 섹션에 `isUnlimited === true`일 때 만료일/만료임박 행 미표시 + sentinel 직접 비교 금지 명시 완료.

---

### ISS-020: Android 스킬 이용권 등록 후 스킬 팝업이 즉시 노출됨 — 스펙은 토스트 + 리스트 업데이트

| 분류 | bug |
| 발견일 | 2026-04-21 |
| 심각도 | P2 |
| 영향 파트 | Android |
| 상태 | 해결 (2026-04-21) |

**현상**: 스킬 교환권 쿠폰 등록 성공(`issuedType: "skill"`) 후, 스펙에 정의된 "토스트 + 쿠폰 리스트 상단에 카드 추가" 대신 스킬 팝업이 바로 노출됨. 사용자가 능동적으로 카드를 탭하기 전에 스킬 상세로 유도되는 동작.
**스펙 기준**: screen-plan.md S4 — "팝업이 아닌 토스트 + 리스트 업데이트 방식" (명시적 설계 결정). client-guide.md S4 — 토스트 "스킬 이용권이 등록되었어요" (2.5초) → 카드 추가 → 사용자 탭 시 스킬 상세 이동. design-spec.md S4 — 카드 탭 또는 "스킬 보러가기 >" 링크 탭으로 이동.
**원인 (추정)**: Phase 1 전환 시 `issuedType: "skill"` 분기에서 기존 S2-B 확인 팝업 제거 후 스킬 상세 이동 로직이 즉시 실행 경로에 잔존한 것으로 추정.
**영향**: 사용자가 쿠폰 리스트에서 스킬 이용권 카드를 확인할 기회 없이 스킬 상세로 이동됨. 되돌아왔을 때 카드가 보이지 않을 수 있음.

---

### ISS-019: iOS/Android 스킬 이용권 카드에 '스킬 보러가기' 링크 텍스트 미노출

| 분류 | bug |
| 발견일 | 2026-04-21 |
| 심각도 | P2 |
| 영향 파트 | iOS, Android |
| 상태 | iOS 해결 (2026-04-21), Android 해결 (2026-04-21) |

**현상**: 스킬 교환권 쿠폰 등록 후 쿠폰 리스트에 추가되는 스킬 이용권 카드에 "스킬 보러가기 >" 링크 텍스트가 표시되지 않음. 카드 탭으로 스킬 상세 이동은 가능하나 명시적 링크 UI가 누락.
**스펙 기준**: design-spec.md S4 — "스킬 보러가기 >" 12px Bold, `#BE7AFE` (SUB PURPLE). client-guide.md S4 — 카드 구성요소에 "스킬 보러가기 >" (보라색) 포함. screen-plan.md S4 — 카드 구성표 Link 행에 명시.
**원인 (추정)**: 쿠폰 카드 UI가 기존 할인 쿠폰 레이아웃을 재사용하면서 스킬 이용권 전용 링크 영역이 추가되지 않은 것으로 추정.
**영향**: 사용자가 카드를 탭하면 스킬 상세로 이동 가능하나, 시각적 어포던스(보라색 링크)가 없어 탭 가능 여부를 인지하기 어려움.

---

### ISS-018: iOS S3 하트 완료 팝업 이미지 미노출 + 확인 버튼 프로필 탭 이동 미작동

| 분류 | bug |
| 발견일 | 2026-04-19 |
| 심각도 | P2 |
| 영향 파트 | iOS |
| 상태 | 해결 (2026-04-19) |

**현상**:
1. 하트 충전 완료 팝업(S3)의 상단 캐릭터+하트 일러스트가 표시되지 않음.
2. "확인" 버튼 탭 시 팝업은 닫히지만 프로필 탭으로 이동하지 않음.

**원인 (분석 가설)**:
1. `Hellobot/Resources/Assets.xcassets/_Coop/Contents.json`에 `provides-namespace: true`로 설정되어 있어 실제 에셋 이름이 `_Coop/img_heart_complete`. 코드(`CoopHeartCompletePopupView.swift:30`)는 `UIImage(named: "img_heart_complete")`로 네임스페이스 없이 호출 → nil 반환.
2. `CoopHeartCompletePopupViewController.swift:52-56`의 `self?.dismiss(animated: true) { self?.onConfirm?() }` 패턴에서 completion 클로저 내부 `self?`가 dismiss 직후 weak 해제 타이밍으로 nil이 되어 `onConfirm` 미호출 가능. 또는 호출되더라도 dismiss 완료 후의 탭 전환 타이밍 이슈. 일반 패턴(RecoverViewController 등)은 `selectTab → dismiss` 순서로 호출.

**범위**: iOS 단독. S3 팝업은 register API 응답 `issuedType=heart` 분기에서 호출.

---

### ISS-017: 웹 일반 쿠폰 등록 완료 후 리스트에 즉시 반영되지 않음 (새로고침해야 보임)

| 분류 | bug |
| 발견일 | 2026-04-19 |
| 심각도 | P2 |
| 영향 파트 | 웹 |
| 상태 | 해결 (2026-04-19) |

**현상**: 헬로우봇 쿠폰 코드를 입력해 등록 성공(`issuedType: "coupon"`) 후에도 쿠폰 리스트 화면에 신규 쿠폰이 즉시 나타나지 않음. 페이지를 수동으로 새로고침해야 목록에 보임.
**재현**: `/coupon` 진입 → 일반 쿠폰 코드 입력 → "등록" 탭 → 성공 처리됨 → 목록 미갱신 → 새로고침 시 반영.
**원인 (추정)**: `couponCodeRegister.tsx`의 `issuedType === 'coupon'` 분기에서 `dispatch(setCoupons([...(coupons ?? []), data.coupon]))`로 Redux 스토어를 갱신하지만, `/coupon` 페이지가 `useGetCoupon` SWR 캐시 기반으로 렌더링되거나 페이지의 `useEffect([couponData])`가 재실행되며 SWR의 기존 응답으로 덮어쓰는 것으로 보임. SWR `mutate`를 호출해 `/api/coupon` 캐시를 invalidate하지 않음.
**영향**: Phase 1 전환 전후 공통 버그로 추정되며 `skill` 이용권 플로우(카드 추가 로컬 상태)에는 해당 없음. 일반 쿠폰 사용자 경험 저하.
**해결 방향 후보**: (1) `usePostCouponRegister` 성공 시 `mutate('/api/coupon')`로 SWR 재조회, (2) 페이지의 `couponData` 기반 `setCoupons`를 일회성(초기 마운트) 로직으로 변경.

---

### ISS-016: 에러 토스트 지속시간 불일치 (Web 3초, Android LENGTH_LONG) — 계약 2.5초

| 분류 | bug |
| 발견일 | 2026-04-18 |
| 심각도 | P3 |
| 영향 파트 | 웹, Android |
| 상태 | Web 해결 (2026-04-21), Android 해결 (2026-04-21) |

**현상**: design-spec.md §에러 토스트, client-guide.md S5, screen-plan.md S5는 자동 사라짐 시간을 "2.5초"로 규정. 실제 구현은 Web `components/toast.tsx:5` `DURATION_TIME = 3000` (3초), Android `CouponListActivity.kt:148,164`는 `Toast.LENGTH_LONG`(약 3.5초) 사용.
**원인**: Web은 공통 Toast 컴포넌트의 기본값 3초를 그대로 사용. Android는 기본 Toast API의 고정 상수를 사용하여 2.5초 표기 불가.
**영향**: 사용자 노출 시간이 스펙 대비 0.5~1초 길어짐. 기능 동작에는 영향 없으나 디자인 스펙 불준수.

---

### ISS-015: 서버 Redlock 미구현 — architecture §5-2/5-3 설계와 불일치

| 분류 | edge-case |
| 발견일 | 2026-04-18 |
| 심각도 | P2 |
| 영향 파트 | 서버 |
| 상태 | 해결 (2026-04-19) — Phase 1 `CoopMarketingService.registerOneShot`에 `redLock.lock("coop:lock:${code}", config.redlock.ttl)` 적용. try/finally로 보상(L2/L3) 완료 후 unlock 보장. spec 키와 일치 (architecture.md §5-2). |

**현상**: architecture.md §5-2(하트 충전권 use 처리) 및 §5-3(스킬 교환권 use 처리)에 "Redlock 획득 (coupon_code 기준, 중복 사용 방지)"이 2번째 단계로 명시되어 있으나, 실제 `CoopMarketingService` 구현 코드에 Redlock import/호출이 존재하지 않음.
**원인**: 구현 과정에서 usage 테이블의 `(user_seq, coupon_code)` UNIQUE 제약 + UPSERT만으로 중복 사용을 방어하는 방식으로 단순화됨. 설계 문서는 갱신되지 않음.
**영향**: 동일 유저가 동일 쿠폰으로 동시에 2회 이상 use를 호출할 경우 쿠프마케팅 L0/L1 API가 중복 호출될 수 있음(최종 UPSERT 단계에서만 차단). 설계 문서와 구현 간 진실 기준이 다름.

---

### ISS-014: screen-plan.md S3 완료 팝업 디자인이 design-spec 확정본과 상이

| 분류 | bug |
| 발견일 | 2026-04-18 |
| 심각도 | P2 |
| 영향 파트 | 기획 (문서) |
| 상태 | 해결 (2026-04-19) |

**현상**: design-spec.md §S3(확정본)은 캐릭터+하트 일러스트(`img_heart_complete.png`) + 캡션(Red400) + 제목 "하트가 {N}개 충전되었어요!" + 본문 "하트는 \<프로필\>탭에서 확인 가능해요" + "확인" 단일 버튼 구성. 반면 screen-plan.md:165-175는 구 초안 기준으로 "✓ 초록 원형 아이콘 + 메시지 '하트 {N}개가 충전되었어요'"로 기술되어 있음.
**원인**: Figma 확정 디자인 반영 시 design-spec.md만 갱신되고 screen-plan.md는 초기 와이어프레임 기준이 잔존.
**영향**: 문서만 혼선. 실제 구현(iOS/Android/Web)은 design-spec 기준으로 올바르게 구현됨.

---

### ISS-013: CM_005 사용자 메시지 문구 api-spec vs client-guide 불일치

| 분류 | bug |
| 발견일 | 2026-04-18 |
| 심각도 | P3 |
| 영향 파트 | 서버 (문서) |
| 상태 | 해결 (2026-04-19) |

**현상**: 동일 에러코드 CM_005(외부 서비스 오류)에 대해 계약 문서 2종의 사용자 안내 메시지가 다름.
- api-spec.md:198 — "일시적인 서비스 오류가 발생했습니다"
- client-guide.md:244 — "쿠프마케팅 API 오류가 발생했습니다"
**원인**: api-spec, client-guide 작성 시점 차이로 인한 표기 일관성 누락.
**영향**: 클라이언트가 어느 문서를 기준으로 표시할지 모호함. 사용자에게 "쿠프마케팅"이라는 내부 제휴사 명칭이 노출될 위험.

---

### ISS-012: CM_010 에러코드가 api-spec/client-guide에 누락 — 계약 문서 미갱신

| 분류 | bug |
| 발견일 | 2026-04-18 |
| 심각도 | P2 |
| 영향 파트 | 서버 (문서) |
| 상태 | 해결 (2026-04-19) — Phase 1 `/architect` 작업 시 동시 해소. api-spec.md 에러코드 표(CM_010, 400, "결제가 취소된 쿠폰이에요") + 매핑표(CM_010 ← L0 응답 ResultCode "8099") 반영. client-guide.md S5 에러 매핑표(400 / CM_010 / "결제가 취소된 쿠폰이에요") 반영. |

**현상**: ISS-006 해결 시 결제 취소 쿠폰(쿠프마케팅 응답 8099) 대응을 위해 CM_010 "결제가 취소된 쿠폰입니다" 에러코드가 추가되어 서버 코드(`src/common/code.ts CM_PAYMENT_CANCELED_COUPON`, `service.ts:191-192 8099→CM_010`)에 반영되고 tasks.md/issues.md에도 기록됨. 그러나 api-spec.md:192-202 에러코드 테이블에는 CM_001~CM_009만 존재하며, client-guide.md:219-249 check/use 에러 매핑표에도 CM_010이 누락됨.
**원인**: ISS-006 처리 시 계약 문서(api-spec/client-guide) 동반 업데이트 누락. architecture.md Changelog에만 다른 변경이 기록됨.
**영향**: 구현은 정상 동작하나 클라이언트 개발자가 계약 문서만 보면 CM_010 수신 시 매핑 불가. screen-plan.md §S5에 "결제가 취소된 쿠폰이에요" 메시지가 있어 문서 간 단서는 있음.

---

### ISS-011: 쿠폰 프리픽스 판별 주체 계약 문서 간 불일치 (architecture vs client-guide/screen-plan)

| 분류 | bug |
| 발견일 | 2026-04-18 |
| 심각도 | P2 |
| 영향 파트 | 문서 (architecture, client-guide, screen-plan), 서버, iOS, Android, Web |
| 상태 | 해결 (2026-04-19) |

**현상**: 쿠폰번호 프리픽스(90/91) 판별 주체에 대해 계약 문서 3건이 서로 상반된 내용을 기술.
- architecture.md:254-256 — "쿠폰번호 프리픽스 90, 91로 시작하면 → POST /api/coop/check 호출, 그 외 → 기존 쿠폰 등록 API 호출" (클라이언트 분기)
- client-guide.md:129, 265 — "등록 버튼 탭 시 서버가 쿠폰 형식을 판별 (클라이언트에서 분기 불필요)"
- screen-plan.md:87, 129 — "서버가 쿠폰 코드 형식을 판별"

실제 구현은 architecture 기준으로 iOS(`CouponListViewController.swift:156-161`)/Android(`CouponListViewModel.kt:121-123`) 양쪽에서 프리픽스 분기 로직이 구현되어 있음.
**원인**: API 설계는 `/api/coop/*`와 기존 쿠폰 API를 분리했으므로 클라이언트가 엔드포인트를 선택해야 함. client-guide/screen-plan 작성 시 서버가 통합 판별하는 것으로 잘못 기술됨.
**영향**: 클라이언트 개발자가 어느 문서를 기준으로 삼느냐에 따라 구현 방향이 엇갈림. ISS-009(구버전 앱 대응)와도 연관되어 해결 방안 논의 시 기준 문서 필요.
**해결 방안** (2026-04-19): 근본 해결을 위해 **서버 단일 진입점**으로 전환 결정. 클라이언트 하드코딩된 프리픽스 분기 제거.
- 신규 단일 엔드포인트 `POST /api/coupon/register` 도입 — 서버가 `coupon_prefix_rule` 테이블 기반으로 분류. 응답은 폴리모픽 (`resultType: "ISSUED"`, `issuedType: "coupon"|"heart"|"skill"`).
- 쿠프마케팅 check+use를 단일 API에서 원샷 처리 (1단계 플로우). S2 확인 팝업 제거.
- 기존 `/api/coop/check`, `/api/coop/use`는 Phase 1 deprecated → Phase 2 제거.
- 향후 프리픽스/제휴사 추가 시 DB row 추가만으로 대응 (앱 강제 업데이트 불필요).
- 전 문서 일괄 정합성 수정.

---

### ISS-010: 쿠폰 리스트 API(/api/coupon) 응답에 fixedMenuSeq 필드 부재 — 스킬 이용권 카드 탭 → 스킬 상세 이동 불가

| 분류 | edge-case |
| 발견일 | 2026-04-18 |
| 심각도 | P2 |
| 영향 파트 | 서버, iOS, Android |
| 상태 | 해결 (2026-04-18) |

**현상**: client-guide.md:179에 "스킬 이용권 카드 탭 또는 '스킬 보러가기 >' 링크 탭 → 스킬 상세 페이지 이동 (`fixedMenuSeq` 사용)"로 정의되어 있으나, 기존 `/api/coupon` 응답(`CouponDto`)에 `fixedMenuSeq` 필드가 포함되지 않아 클라이언트가 스킬 상세로 이동할 식별자를 확보할 수 없음.
**원인**: 서버 DB에는 `CouponCondition.skillSeqs[0]`으로 정보가 존재하나, `CouponDto`가 이를 노출하지 않음. Coop 스킬 이용권은 `skillSeqs`에 단일 fixedMenuSeq를 담아 발급됨.
**영향**: iOS S4 스킬 이용권 카드 탭 플로우 구현 불가. Android 동일 이슈 예상(동일 API 사용).

---

### ISS-009: 구버전 앱에서 카카오 쿠폰(90/91 프리픽스) 입력 시 "유효하지 않은 쿠폰입니다" 에러 표시

| 분류 | edge-case |
| 발견일 | 2026-04-16 |
| 심각도 | P2 |
| 영향 파트 | 서버, iOS, Android |
| 상태 | 해결 (2026-04-19) |

**현상**: 구버전 앱에서 사용자가 카카오 선물하기 쿠폰번호(90/91 프리픽스)를 입력하면 coop 연동 코드가 없으므로 기존 쿠폰 검증 로직에서 "유효하지 않은 쿠폰입니다" 에러가 표시됨.
**원인**: 구버전 앱은 coop 연동 API(`/api/coop/check`)를 호출하지 않고 기존 쿠폰 API를 사용하기 때문에 90/91 프리픽스 쿠폰을 인식하지 못함.
**제약**: 강제 업데이트 없이 해결해야 함. 서버 사이드 대응 방안 검토 필요.
**해결 방안** (2026-04-19): 기존 `POST /api/coupon`의 **code 기반 경로**에 **프리픽스 가드** 추가. `code`가 비어있지 않은 문자열이고 `coupon_prefix_rule`의 `requiresNewFlow=true` rule과 매칭 시 HTTP 406 + `CO_APP_UPDATE_REQUIRED` 에러코드 반환.
- 에러 메시지 (ko): `"앱 업데이트가 필요한 쿠폰이에요."`
- 구버전 앱은 기존 에러 토스트 로직이 `message`를 그대로 표시 → 재빌드/강제 업데이트 불필요.
- 신버전 앱은 **code 기반 등록 경로만** `/api/coupon/register`로 이전되어 가드에 닿지 않음. `couponSpecSeq` 경로(배너 "쿠폰 받기" 등 DOWNLOAD 클레임)는 신/구 모두 계속 `POST /api/coupon` 사용하며 가드 영향 없음.
- 향후 새로운 제휴사 프리픽스 추가 시에도 DB row 추가만으로 구버전 앱에 동일 안내 자동 노출.
- ISS-011과 동일 해결 방안 하에 통합 처리.

---

### ISS-008: Admin 쿠폰 사용 취소 시 상품 상태 정보가 확인 팝업에 표시되지 않음

| 분류 | enhancement |
| 발견일 | 2026-04-15 |
| 심각도 | P2 |
| 영향 파트 | 서버 (Admin) |
| 상태 | 해결 (2026-04-15) |

**현상**: Admin에서 쿠폰 사용 취소 시 단순 확인 메시지만 표시. 운영자가 상품 상태를 인지할 수 없음.
**원인**: `getAdminCancelInfo()` 구현되어 있었으나 미호출. AdminJS `guard`가 정적 문자열만 지원.

---

### ISS-007: 미로그인 시 쿠폰 입력 포커스에서 로그인 안내 팝업 대신 즉시 리다이렉트됨

| 분류 | bug |
| 발견일 | 2026-04-15 |
| 심각도 | P2 |
| 영향 파트 | 웹 |
| 상태 | 해결 (2026-04-15) |

**현상**: ISS-002 해결 시 `goToLogin()` 직접 호출로 구현. Figma 디자인의 로그인 안내 팝업(S6) 누락.
**원인**: Figma 확정 디자인에 팝업이 있었으나 구현 시 `goToLogin()` 직접 호출로 대체됨.

---

### ISS-006: 쿠프마케팅 응답코드 8099(결제취소 쿠폰)에 대한 별도 에러 메시지 없음

| 분류 | enhancement |
| 발견일 | 2026-04-14 |
| 심각도 | P3 |
| 영향 파트 | 서버 |
| 상태 | 해결 (2026-04-14) |

**현상**: 결제 취소된 쿠폰(8099)에 대해 범용 에러 메시지만 표시.
**원인**: 8099 응답코드에 대한 전용 에러코드 미정의.

---

### ISS-005: admin locale 띄어쓰기 불일치 (unuse vs cancel)

| 분류 | bug |
| 발견일 | 2026-04-14 |
| 심각도 | P3 |
| 영향 파트 | 서버 |
| 상태 | 해결 (2026-04-14) |

**현상**: Admin UI에서 "사용취소"와 "사용 취소" 띄어쓰기 불일치.
**원인**: locale 정의 시 띄어쓰기 누락.

---

### ISS-004: useCoupon L0 재검증의 에러코드가 check와 불일치

| 분류 | bug |
| 발견일 | 2026-04-14 |
| 심각도 | P2 |
| 영향 파트 | 서버 |
| 상태 | 해결 (2026-04-14) |

**현상**: useCoupon L0 재검증 시 에러코드가 check API와 다르게 반환됨.
**원인**: useCoupon에서 범용 CM_001만 반환, check의 세분화된 에러코드 분기 미적용.

---

### ISS-003: 사용 완료 모달에서 쿠폰 유효기간(expiryDate)이 불필요하게 표시됨

| 분류 | bug |
| 발견일 | 2026-04-14 |
| 심각도 | P2 |
| 영향 파트 | 서버, 웹 |
| 상태 | 해결 (2026-04-14) |

**현상**: 사용 완료 모달에 쿠폰 유효기간(EndDay)이 교환 상품의 유효기간으로 오인되어 표시됨.
**원인**: EndDay는 쿠폰 사용 기한이며, 교환된 상품(하트/이용권)에는 유효기간이 없음.

---

### ISS-002: 미로그인 상태에서 쿠폰 입력창 클릭/등록 시 로그인 안내 팝업 미표시

| 분류 | bug |
| 발견일 | 2026-04-14 |
| 심각도 | P2 |
| 영향 파트 | 웹 |
| 상태 | 해결 (2026-04-14) |

**현상**: 미로그인 상태에서 쿠폰 입력창/등록 버튼에 로그인 체크 없음 → 401 에러가 토스트로 표시.
**원인**: couponCodeRegister.tsx에 anonymous 체크 누락.

---

### ISS-001: 쿠폰 취소 후 재사용 시 CM_007 에러 (유니크 제약 위반 + 하트 누수)

| 분류 | edge-case |
| 발견일 | 2026-04-13 |
| 심각도 | P1 |
| 영향 파트 | 서버 |
| 상태 | 해결 (2026-04-14) |

**현상**: 쿠폰 취소(L2) 후 재사용 시 usage 유니크 제약 위반 → CM_007 에러 + 하트 누수.
**원인**: usage DELETE 없이 status UPDATE만 수행. chargeHeart가 별도 트랜잭션이라 부분 실패 시 하트만 충전됨.
