# 조치 과업

> 메가존 가이드 + Tier 0·1 audit 결과 반영 (2026-05-19).
> 2026-05-20 — 현황 분석 완료. 후속 = **트랙 A (IP 제한 보완) + 트랙 B (메가존소프트 협의)**.

## 🔥 트랙 A — 보안 보완 (IP 제한 적용) [2026-05-20~]

> 위험 키 전반에 APP_RESTR (allowed IPs) 추가. 사용처 확인된 키부터 순차 적용, 모르는 키는 audit log 로 IP 추출.

- [ ] **사용처 확인된 키 IP 제한 즉시 적용**:
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

## 🔥 트랙 B — 메가존소프트 협의 [2026-05-20~]

> 단일 채널: 파트너사 메가존소프트 김종현 대표님.

- [ ] **B-1: 현황 공유** — audit-tier1-report.md + meeting-summary.md + 트랙 A 적용 결과 패키지화 → 메가존에 전달
- [ ] **B-2: 4/29 비용 세부 내역 요청** — 해당 기간(4/29 + 인근일) Gemini 호출 raw 데이터 / 청구 금액 분해 / 시간대별 분포 요청
- [ ] **B-3: Google 측 구제 방안 문의** — 외부 abuser 의 무단 사용으로 발생한 비용에 대해 Google 의 구제 (refund, credit, dispute) 방안이 있는지 메가존 경유로 Google 측 문의 요청
- [ ] **B-4: 결제 알림 설정 요청** — 6개 위험 프로젝트 월 예산 $50, 50/90/100% 알림. 수신자: tony@dlt-partners.com + 혁수님 (DLT 권한 없어 메가존 경유 필수)
- [ ] **회신 정리** — B-1~B-4 답변 수신 후 결과 정리 → 청구 보정 협의 (다음 단계) 입력

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
