# TODO-003 Android 하트 구매 OR-FGEMF-20 에러 — 원인 파악 및 대응

**유형**: 모니터링 (완료)
**상태**: ✅ 완료 (2026-05-14) — Google Payments 승인 → 계정 활성화 → Android 인앱결제 정상 동작 확인
**등록**: 2026-05-13
**시작**: 2026-05-13
**완료**: 2026-05-14
**마감**: - (5/11~5/14 매출 손실 발생)
**담당**: **영덕님 (직접 처리 완료)** + 사용자/코디네이터 (모니터링)
**관련**: 아직 프로젝트화 안 함

## 컨텍스트

### 사용자 보고 (2026-05-13)
> "안드로이드 앱에서 하트 구매할 때 모든 결제수단에서 OR-FGEMF-20 에러가 발생하고 있어. 이거 원인 파악해줘"

- 발생 범위: **다수 유저 / CS 폭증** (사용자 확인)
- 플랫폼: Android 한정 (iOS 보고 없음)
- 패턴: 결제수단(카드/통신사 등) 무관, 동일 OR-FGEMF-20 노출

### 사건 타임라인 (확정)

| 시각 (KST) | 사건 |
|-----------|------|
| **2026-05-10 17:41** | Play Console 결제 프로필 이슈 알림 수신 (신원/사업자 정보 확인 요청) |
| **2026-05-11 ~15:00** | 모든 결제수단에서 OR-FGEMF-20 발생 시작 (알림 후 약 21시간) |
| **2026-05-11 ~** | Android 인앱구매 건수 급격 감소 (0건은 아니지만 급속 감소중) |
| 2026-05-13 | 사용자 보고 → TODO-003 등록, 원인 확정 |

### `/dev-android` 1차 진단 결과

`OR-FGEMF-20`은 **Google Play / Google Wallet 결제 처리 시스템이 발생시키는 표준 거절 코드** (`OR-XXXXX-NN` 포맷). 헬로우봇 앱·서버 코드와 무관.

**근거**:
1. 워크스페이스 전체 코드베이스(Android/서버/웹) 어디에도 `FGEMF` 문자열 부재 — grep 검증 완료
2. Android 하트 구매 플로우는 Google Play Billing 사용
   - 사용자 결제 → `BillingClient.launchBillingFlow()` (← 여기서 OR 에러 발생)
   - 성공 시 → `StoreServer.depositHeart(receipt, signature)` (서버 호출은 여기. **현재 도달 못함**)
   - 관련 코드: [hellobot_android/app/src/main/java/com/thingsflow/hellobot/billing/util/BillingManager.kt](hellobot_android/app/src/main/java/com/thingsflow/hellobot/billing/util/BillingManager.kt), [hellobot_android/app/src/main/java/com/thingsflow/hellobot/heart_store/connector/StoreServer.kt](hellobot_android/app/src/main/java/com/thingsflow/hellobot/heart_store/connector/StoreServer.kt)
3. 서버 로그에 흔적이 없을 것 (receipt 발급 자체 거절)
4. iOS는 정상 → 서버 원인 가능성 제외

### 환경 정보 (조사 시점)
- Billing 라이브러리: `8.0.0` ([hellobot_android/versions.gradle:14](hellobot_android/versions.gradle:14))
- 앱 ID: `com.thingsflow.hellobot`

## 현재 상태

✅ **해결 완료 (2026-05-14)**

**해결 경로**: Google Payments에 필요 서류 제출 → 승인 → 계정 활성화 → Android 인앱결제 정상 동작 확인.
- 영덕님이 직접 Google Payments에 증빙 서류 전달 + 승인까지 완료
- D&B → Google 자동 동기화 5영업일 대기 우회 — Google Payments 직접 채널로 빠른 처리
- 총 손실 기간: 5/11(거절 시작) ~ 5/14(정상화) = 약 4일

**원인 (확정)**: Google Play Console 결제 프로필의 **조직(회사) 정보 변경(주소 등)이 미반영**되어 본인 인증 상태 불일치 발생 → Google이 결제 자동 거절(OR-FGEMF-20). 초기 추정인 "KYB 검증 미완료"는 정확하지 않았음 — KYB 자체는 완료된 상태이고, **변경된 사업자 정보가 Google 결제 시스템에 동기화되지 못한 것**이 정확한 원인.

**해결 채널**:
- 처음에 D&B → Google 자동 동기화 경로로 추정 (NICE D&B에 DUNS 업데이트 요청)
- 실제로는 **Google Payments 직접 서류 제출** 채널이 더 빠른 해결 경로였음 (재발 시 참고)

## 다음 단계

### Phase A — D&B 업데이트 완료 확인 (2026-05-14 오전)

- [ ] **NICE D&B 회신 확인** — 약속한 5/14 오전까지 업데이트 완료 회신 도착 여부
- [ ] **iupdate.dnb.com에서 등록 정보 검증** — DUNS 번호로 로그인하여 현재 D&B에 반영된 Legal Business Name / Registered Address가 최신 사업자등록증과 일치하는지 확인
- [ ] **회신 지연 시 follow-up** — 5/14 오전 미회신 시 NICE D&B에 다시 연락

### Phase B — D&B → Google 동기화 대기 (최대 5영업일)

- [ ] **Play Console 계정 소유자 이메일 모니터링** — "개발자 신원 재인증" 안내 메일 수신 시 즉시 처리
- [ ] **2~3영업일 후 Play Console 확인** — 경고 옆 "View details" → "Review updates" 버튼 활성화 여부
- [ ] **동기화 지연 시 백업 경로**:
  - Play Console의 "문의하기 → 읽기 전용 정보 업데이트" 양식 제출 (제출 후 2~5일 내 Google 회신)
  - DUNS 정보는 그대로인데 표기 차이만 있는 경우 사용

### Phase C — Play Console 재인증

- [ ] **재인증 이메일 수신 후 Play Console 접속** — 알림 옆 "View details" → "Review updates"
- [ ] **D&B에서 가져온 새 조직 정보 확인 후 제출** — 사업자등록증·법인등기부등본 등 증빙 첨부 요구될 수 있음

### Phase D — 정상화 확인

- [ ] **Android 하트 구매 테스트** — 성공 응답 + receipt 정상 발급 + 서버 `depositHeart` 도달
- [ ] **OR-FGEMF-20 노출 종료 확인** — Sentry/Crashlytics에서 BillingResponseCode 분포 정상화, CS 인입량 감소
- [ ] **매출 회복 추세 확인** — 일별 인앱구매 건수 회복

### Phase E — 영향 완화 (지연 시 추가 검토)

- [ ] (선택) **사용자 안내문 검토** — D&B→Google 동기화가 길어질 경우 앱 내 공지 또는 CS 매뉴얼 갱신
- [ ] **재발 방지**:
  - Play Console Inbox 알림 채널을 운영 담당자/이메일·Slack에 즉시 전달되는 구조로 정비 (이번엔 알림 5/10 → 거절 5/11 → 발견 5/13, 약 3일 갭)
  - 사업자 정보 변경 시 D&B 갱신을 SOP로 등록

### Phase F — 운영 처리 완료 후

- [ ] **회고 메모** — 알림 수신부터 거절 발생까지 21시간, 발견까지 추가 2일 → 알림 모니터링 체계 개선 검토
- [ ] **TODO 완료 처리** — 결제 정상화 확인 후 TODO.md 완료 섹션으로 이동

## 참고 — D&B 채널

- NICE D&B (한국 채널): https://www.dnb.co.kr
- D&B 글로벌 iUpdate (자가 업데이트): https://iupdate.dnb.com — DUNS 번호로 로그인
- Google 공식 가이드: D&B 업데이트 후 Google 반영까지 D&B 처리 완료 시점부터 최대 5영업일

## 진행 로그

- 2026-05-13 — 사용자 요청 접수, `/dev-android`로 1차 원인 파악
- 2026-05-13 — 코드베이스 grep으로 `FGEMF` 부재 확인 (Android/서버/전체 워크스페이스)
- 2026-05-13 — Android 결제 플로우 확인: Google Play Billing 8.0.0 사용, 서버 `depositHeart`는 receipt 수신 후 호출되는 구조 → OR 에러는 서버 도달 전 단계
- 2026-05-13 — 사용자에게 발생 범위 확인 → "다수 유저 / CS 폭증" 응답
- 2026-05-13 — Google Play 측 시스템 원인 결론, 6개 점검 항목 사용자/운영 담당자에게 전달, Play Console 점검 결과 대기 (블록)
- 2026-05-13 — TODO-003으로 등록, 재개 시 Phase 1 결과부터 이어가기
- 2026-05-13 — **사용자 확인**: Play Console 결제 프로필 이슈 알림 수신(5/10 17:41), 결제 거부 시작(5/11 15:00경), 인앱구매 급격 감소중 → 1차 원인 추정: KYB 검증 미완료
- 2026-05-13 — 사용자에게 알림 유형 질의 → "신원/사업자 정보 확인" + "대표자/법인 정보 필요" 응답
- 2026-05-13 — 다음 단계 Phase A~D로 재구성, 상태 "대기 → 진행 중"으로 갱신
- 2026-05-13 — **사용자 추가 조사로 원인 정정**: KYB 검증 자체는 완료된 상태이고, 실제 원인은 **조직(회사) 정보 변경(주소 등) D&B 미반영**. 조직 계정 + 본인 인증 완료 상태에서는 Play Console 펜 아이콘 직접 수정 불가 — D&B가 SSOT
- 2026-05-13 — 사용자: **NICE D&B(나이스디앤비)에 DUNS 주소지 정보 업데이트 긴급 요청 완료** → 내일(5/14) 오전까지 업데이트 회신 약속 받음
- 2026-05-13 — 다음 단계 Phase A~F로 재구성 (D&B 회신 확인 → D&B→Google 동기화 대기 → Play Console 재인증 → 정상화 확인)
- 2026-05-14 — **사용자 업데이트**: 결제 프로필 이슈로 **증빙 서류 제출 완료**. **5/14 해결 예정**. **영덕님이 직접 처리 중** → 유형 액션 → 모니터링으로 전환 (우리 직접 액션 없음, 결과 추적). 다음 체크 = 5/14 결제 정상화 확인
- 2026-05-14 — ✅ **완료**: Google Payments 서류 제출 → 승인 → 계정 활성화 → **Android 인앱결제 정상 동작 확인**. 손실 기간 5/11~5/14 (약 4일). D&B 동기화 우회하고 Google Payments 직접 채널로 해결 — 재발 시 이 경로 우선 검토
