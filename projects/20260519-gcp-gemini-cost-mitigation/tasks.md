# 조치 과업

> 메가존 가이드 + Tier 0·1 audit 결과 반영 (2026-05-19).
> 2026-05-20 — 현황 분석 완료. 후속 = **트랙 A (IP 제한 보완) + 트랙 B (메가존소프트 협의)**.
> 2026-05-21 — 메가존소프트로부터 **API Key 보안 점검 가이드** 추가 수신 → **트랙 3 (보안 점검)** 신설. 가이드: [planning/megazone-mitigation-guide/2026-05-21-api-key-security-checklist.md](planning/megazone-mitigation-guide/2026-05-21-api-key-security-checklist.md)

## ⏳ 트랙 A — 보안 보완 (IP 제한 적용) [2026-05-20~ · 혁수님 대기]

> 위험 키 전반에 APP_RESTR (allowed IPs) 추가. 사용처 확인된 키부터 순차 적용, 모르는 키는 audit log 로 IP 추출.
>
> **2026-05-20**: 혁수님께 IP 제한 조치 요청 전달 → 적용 완료 회신 대기. 적용 결과 도착 후 검증·정리 단계로 이행.

- [x] 혁수님께 IP 제한 조치 요청 전달 (2026-05-20)
- [ ] **사용처 확인된 키 IP 제한 즉시 적용** (혁수님 처리):
  - [ ] `hellobot-llm-prod` — 운영 서버 IP 확인 → APP_RESTR
  - [ ] `hellobot-llm-dev` — dev 환경 IP 확인 → APP_RESTR
  - [ ] `compatibility-ai` — 호출 위치 IP 확인 → APP_RESTR
  - [ ] `compatibility-api` — 호출 위치 IP 확인 → APP_RESTR
- [ ] **사용처 불명 키 — Audit Log IP 추출 후 APP_RESTR**:
  - [ ] `ai-product-417102` 키 `6d1f37aa` (CRITICAL) — Cloud Audit Logs 1주일치 IP 추출 → 일치 IP 만 허용
  - [ ] `ai-product-417102` 키 `ae5a3711` (CRITICAL) — 동일
  - [ ] `AI-project` 키 `23d59b64` — 동일
  - [ ] `Gemini API` 키 `09814bf7` — 동일
- [ ] **혁수님 기존 적용 키 확인**:
  - [ ] `ai-rule-auto-gen-test-hshan` 키 `f6e59b43` — IP 제한 적용 상태 확인 (1.234.131.174/32 동일 여부)
  - [ ] `ai-rule-auto-gen-test-hshan` 키 `57ea0b81` — 동일
- [ ] **적용 후 검증** — `gcloud services api-keys describe` 로 APP_RESTR 반영 확인 + 정상 호출 1건 테스트
- [ ] **트랙 A 결과 정리** — 키별 적용 IP + 적용 시각 + 검증 결과 → 트랙 B 보고에 첨부

## ⏳ 트랙 3 — 보안 점검 사항 (API Key 점검·권한 제한) [2026-05-21~]

> 메가존소프트 추가 가이드 기반. 전체 GCP 프로젝트 API Key 보안 상태 점검 + 유형 A/B 분류 + 권한 제한 적용 + 추가 예방 조치(결제 알림·Quota).
> 가이드 SSOT: [planning/megazone-mitigation-guide/2026-05-21-api-key-security-checklist.md](planning/megazone-mitigation-guide/2026-05-21-api-key-security-checklist.md)
> 트랙 A 와 일부 중복(IP 제한)되지만, 트랙 3 은 **API 제한사항(API Restrictions) 화이트리스트**가 중심 — Generative Language API / Vertex AI API 호출 차단이 핵심 차이.

### [1단계] 보안 상태 점검 (Unrestricted API Key 식별)

- [ ] 전체 GCP 프로젝트 콘솔 순회 — [API 및 서비스] > [사용자 인증 정보] 에서 ⚠️ 경고 아이콘 또는 '제한사항: 없음/적용 안 됨' 키 목록 추출
- [ ] Tier 0·1 audit 결과(CRITICAL 2 + HIGH 8) 와 매핑 — 신규 발견 키 있으면 audit 로그에 추가
- [ ] Tier 2 (HelloBot 본진 ~30개) 점검 — 같은 기준으로 Unrestricted 키 추출
- [ ] Tier 3 (sys-* 자동 ~150개) 점검 — Gemini 활성 + Unrestricted 교집합 위주

### [2단계] 키별 유형 분류 (A: 교체 가능 / B: 교체 불가)

- [ ] **유형 A 후보 분류** — 백엔드 서버 전용 또는 즉시 재배포 가능한 키:
  - [ ] `hellobot-llm-prod` / `hellobot-llm-dev` — 서버 전용 여부 재확인
  - [ ] `compatibility-ai` / `compatibility-api` — 호출 위치 재확인
  - [ ] `ai-product-417102` 키 2종 — 사용처 확인 후 분류
  - [ ] `AI-project` / `Gemini API` 키 — 사용처 확인 후 분류
- [ ] **유형 B 후보 분류** — 모바일 앱 하드코딩 Firebase 키 (즉시 교체 불가):
  - [ ] hellobot_android Firebase 키 — google-services.json 추출
  - [ ] hellobot_iOS Firebase 키 — GoogleService-Info.plist 추출
  - [ ] 양 OS 키가 audit 결과의 어떤 키와 일치하는지 매핑

### [3단계] 유형 A 조치 (키 교체)

- [ ] 신규 키 생성 → APP_RESTR + API_RESTR (사용 API 화이트리스트) 즉시 설정
- [ ] 애플리케이션 반영 + 정상 동작 확인 (`/dev-server` 위임 가능)
- [ ] 구형 키 삭제 (`gcloud services api-keys delete`)

### [4단계] 유형 B 조치 (API 제한사항 — 호출 권한 통제)

- [ ] 키 값 유지 (앱 하드코딩 그대로)
- [ ] 각 키 편집 → 'API 제한사항' → [키 제한 (Restrict key)] 전환
- [ ] **Firebase 필수 API 만 화이트리스트** 체크:
  - Firebase Installations API (필수)
  - Identity Toolkit API / Firebase Authentication API (로그인 사용 시)
  - Cloud Firestore API (Firestore 사용 시)
  - Firebase Remote Config API (Remote Config 사용 시)
  - Firebase Cloud Messaging API (FCM 사용 시)
  - Google Analytics for Firebase API (Analytics 사용 시)
- [ ] **Generative Language API · Vertex AI API 체크 해제 확인** (가장 중요 — Gemini 차단의 핵심)
- [ ] 저장 후 5~10분 대기 → Gemini API 호출 시 403 Forbidden 반환 확인
- [ ] 앱 정상 작동 회귀 테스트 (`/qa` 또는 모바일 개발자 위임)

### [5단계] 추가 예방 조치

- [ ] **결제 알림 (Billing Alerts)** — 일일/월간 예상 비용 120% 초과 시 이메일 알람 (DLT 권한 없음 → 트랙 B-4 와 통합, 메가존 경유)
- [ ] **Generative Language API Quota 0 또는 최소치 설정** — Gemini 미사용 프로젝트 대상 [API 및 서비스] > [사용 설정된 API] > Generative Language API > [할당량] 탭. 트랙 A 의 IP 제한과 함께 이중 방어선 구축
- [ ] **Vertex AI API Quota** 도 동일 적용 검토 (사용 안 하는 프로젝트 한정)

### [6단계] 정리·보고

- [ ] 트랙 3 결과 정리 — 점검 대상 키 총수 / Unrestricted 키 발견 수 / 유형 A·B 분류 / 적용 완료 키 / 미적용 사유
- [ ] audit-tier1-report.md 갱신 또는 별도 tier 보고서 작성
- [ ] 메가존소프트에 적용 결과 회신 (트랙 B 와 연계)
- [ ] 거버넌스 트랙으로 이관 — 신규 키 생성 시 API_RESTR 필수 체크리스트화

## ⏳ 트랙 B — 메가존소프트 협의 [2026-05-20~ · 외부 응답 대기]

> 단일 채널: 파트너사 메가존소프트 김종현 대표님.

- [x] **B-1: 현황 공유** (2026-05-20) — audit 결과·forensic 패키지 메가존에 공유 완료
- [x] **B-2 합의: 비용 조회 권한 부여** (2026-05-20) — 메가존이 비용 조회 권한 부여하기로 합의
- [x] **B-2 권한 부여 완료** (2026-05-22) — billing AC `016568-056D75-165D6B`(DLTpartners) 에 `tony@dlt-partners.com` 커스텀 role 부여. ✅ Console Billing Reports 접근 가능 / ❌ BQ billing export 미부여 (메가존 자체 프로젝트 보관 추정). organization 245개 → **billing-enabled 25개로 축소**. 위험 키 중 `compatibility-api`·`Gemini API` **2개 billing 미연결** → 4/29 청구 원인에서 제외, **6개 프로젝트로 분석 범위 축소**
- [x] **B-2 사용자 1차 Console 분석** (2026-05-22 완료) — `ai-rule-auto-gen-test-hshan` 4/22~5/21 30일 SKU 분해 CSV 추출 + 차트 캡처 공유
- [x] **B-2 코디네이터 1차 forensic 보강** (2026-05-22) — CSV 분석 → audit-tier1-report.md 2.4b 섹션 추가: ₩5.9M / 4/29 84%·₩5M / Image SKU 78% / 자동화 봇 multimodal sweep 패턴 확정
- [x] **3월 baseline 확인** (2026-05-22) — UI "over ₩X" = 차이(delta) 의미 정정. 직전 30일 = 현재 - delta = ₩26,592 ($20) 정상 baseline. 4/29 단일 사건 확정
- [ ] **B-2 추가 분석 (우선순위 순)**:
  - [ ] **다른 5개 위험 프로젝트 동일 SKU 보고서** — `ai-product-417102` (CRITICAL × 2), `ai-project-454009`, `gen-lang-client-0403158203`(prod), `gen-lang-client-0170471706`(dev), `gen-lang-client-0465592155`(comp-ai). Console 에서 프로젝트 필터 변경 후 동일 30일 CSV export. **`ai-product-417102` 우선**
  - [ ] **4/29 단일일 프로젝트 분포** — group by = Project, 기간 = 4/29 단일일. abuser 가 다른 프로젝트도 동시 공격했는지 확인
  - [ ] **4/29 시간대별 분포** (가능하면) — Console UI 가 hour 단위 지원하는지 확인. 미지원 시 메가존에 BQ export 또는 hourly CSV 추가 요청
  - [ ] 모든 추가 데이터 수신 시 audit-tier1-report.md 2.4b·3.x 섹션 보강 + 트랙 B-3 구제 협상 자료 강화
- [ ] **B-3: Google 측 구제 방안 문의** ⏳ (메가존 진행 중) — 메가존소프트가 Google 측에 외부 abuser 이상 사용 비용 구제(refund/credit/dispute) 방안 문의 중 → 결과 회신 대기
- [ ] **B-4: 결제 알림 설정 요청** — 6개 위험 프로젝트 월 예산 $50, 50/90/100% 알림. 수신자: tony@dlt-partners.com + 혁수님 (DLT 권한 없어 메가존 경유 필수)
- [ ] **회신 정리** — B-2 Console 분석 + B-3 Google 답변 수신 후 결과 정리 → 청구 보정 협의 (다음 단계) 입력

## 가이드 분석

- [x] 가이드 문서 정독 → 조치 항목 갯수 파악
- [x] 스크립트 실행 환경 요구사항 확인 (gcloud · BQ · 권한 등) — gcloud, jq 필요. tony@dlt-partners.com 계정으로 245개 프로젝트 접근 가능
- [x] 영향 범위 점검 — read-only 스크립트라 위험 없음. 조치는 별도 수동

## audit 진행

- [x] Tier 0: `ai-rule-auto-gen-test-hshan` (4/29 발생) — HIGH × 2 (혁수님 IP 제한으로 출혈 멈춤)
- [x] Tier 1: AI/Gemini 관련 7개 — **CRITICAL × 2 + HIGH × 6** (ai-product-417102, ai-project, hellobot-llm-{dev,prod}, compatibility-{ai,api}, Gemini API)
- [x] 4/29 사건 Forensic 분석 (Cloud Monitoring 4/15~5/19 데이터) — 자동화 봇 / 미국 동부 시간대 / cron / 4/29 가 83% / GCP throttling 효과 확인
- [x] 1차 리포트 작성 → [audit-tier1-report.md](audit-tier1-report.md)
- [x] 회의용 요약 작성 → [meeting-summary.md](meeting-summary.md)
- [x] **2026-05-20 현황 분석 완료** — 보안 취약 지점 도출. 후속 = 트랙 A (IP 제한) + 트랙 B (메가존 협의) 로 분리
- [ ] Tier 2: HelloBot 본진 ~30개 audit (hellobot-*, between-*, chitchat-* 등)
- [ ] Tier 3: `sys-*` 자동 생성 ~150개 일괄 점검 (Gemini 활성 여부 위주)

## 키별 사용처 확인 (회신 대기)

### CRITICAL (즉시)
- [ ] `ai-product-417102` 키 `6d1f37aa` (2024-04-04, LEGACY+UNRESTRICTED) — 사용처·소유자 확인
- [ ] `ai-product-417102` 키 `ae5a3711` (2024-03-13, LEGACY+UNRESTRICTED) — 사용처·소유자 확인

### HIGH (신속)
- [ ] `hellobot-llm-prod` (gen-lang-client-0403158203) 키 `138de159` — 운영 LLM 호출 서비스 확인 + Secrets Manager 등록 여부
- [ ] `hellobot-llm-dev` (gen-lang-client-0170471706) 키 `d01d65d3` — dev 사용처 확인
- [ ] `compatibility-ai` (gen-lang-client-0465592155) 키 `49683251` — 궁합 기능 호출 위치 확인
- [ ] `compatibility-api` (gen-lang-client-0605251657) 키 `74bffccc` — 동일
- [ ] `AI-project` (ai-project-454009) 키 `23d59b64` — 소유자·사용처 확인
- [ ] `Gemini API` (gen-lang-client-0627053898) 키 `09814bf7` — 소유자·사용처 확인
- [ ] `ai-rule-auto-gen-test-hshan` 키 `f6e59b43` — 혁수님 사용 여부 확인 (현재 IP 제한 적용 상태)
- [ ] `ai-rule-auto-gen-test-hshan` 키 `57ea0b81` — 동일

## 키별 조치 (회신 받은 후)

답변에 따라 키별로:
- [ ] 안 쓰는 키 → 삭제 (`gcloud services api-keys delete`)
- [ ] 운영 중 + IP 알아냄 → APP_RESTR 추가 (Application restrictions → allowed IPs)
- [ ] 운영 중 + 서버 호출 → ADC 또는 Secret Manager 전환 (코드 수정 동반, `/dev-server` 위임)
- [ ] 사용처 모름 → Cloud Audit Logs 로 호출 IP·계정 추적 후 결정

## 재발 방지

- [ ] **메가존에 결제 알림 설정 요청** (DLT 권한 없음) — 6개 위험 프로젝트 월 예산 $50, 50/90/100% 알림. 수신자: tony@dlt-partners.com + 혁수님
- [ ] 신규 키 생성 잠정 중단 안내 (조치 완료까지)
- [ ] (TODO-018 GCP 마이그레이션 가드레일과 통합 검토)

## 청구 보정

- [ ] 메가존 김종현 대표와 청구 보정 가능 여부 협의
- [ ] 가능 시 보정 금액·절차 합의 → 영덕님 또는 재무팀 공유

## 거버넌스 (별도 트랙, 본 프로젝트 범위 밖일 수 있음)

- [ ] AI Studio 즉석 키 발급 규칙 수립 (`gen-lang-client-*` 패턴 5개가 흔적)
- [ ] 모든 신규 키 발급 시 APP_RESTR 필수 체크리스트
- [ ] audit 스크립트 정기 실행 자동화 (월 1회 CronJob 또는 GitHub Actions)
- [ ] 서버용 키 → ADC/Secret Manager 단계적 전환 로드맵
