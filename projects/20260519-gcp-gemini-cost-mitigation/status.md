# 개발 상태

## 현재 상태: 3-트랙 병행 (2026-05-21)

> 메가존 가이드 기반 audit + Cloud Monitoring forensic + 보안 취약 지점 도출 완료.
> **10개 위험 키 발견** (CRITICAL 2 + HIGH 8). 4/29 사건 = 미국 동부 abuser 의 자동화 봇 공격 확정.
> 2026-05-21 — 메가존소프트로부터 **API Key 보안 점검 가이드** 추가 수신 → **트랙 3 (보안 점검)** 신설.
>
> **트랙 A (IP 제한)** — ⏳ **혁수님께 IP 제한 조치 요청 전달, 적용 회신 대기**
> **트랙 B (메가존 협의)** — 진척:
>   - **B-2 (비용 세부 내역)**: ✅ **2026-05-22 비용 조회 권한 부여 받음** (billing AC `016568-056D75-165D6B`, role `organizations/597078905893/roles/971` 커스텀) → **Console Billing Reports 접근 가능 / BQ export 는 미부여** → 사용자 Console 직접 분석 단계 진입
>   - **B-3 (Google 구제 방안)**: 메가존소프트가 Google 측 진행 중 → 결과 회신 대기
> **트랙 3 (보안 점검)** — 🆕 **2026-05-21 신설**. API Key 보안 상태 점검 + 유형 A/B 분류 + API_RESTR 화이트리스트 적용 (Gemini 차단). 가이드 SSOT: [planning/megazone-mitigation-guide/2026-05-21-api-key-security-checklist.md](planning/megazone-mitigation-guide/2026-05-21-api-key-security-checklist.md)

📄 [audit-tier1-report.md](audit-tier1-report.md) — 혁수님·개발팀 공유용 상세 리포트 (전체)
📄 [meeting-summary.md](meeting-summary.md) — 2026-05-20 회의용 한 페이지 요약

## 파트별 현황

| 파트 | 상태 | 비고 |
|------|------|------|
| 인프라 — 트랙 A (IP 제한) | ⏳ **혁수님 적용 대기** | 혁수님께 IP 제한 조치 요청 전달 완료. 위험 키 전반 APP_RESTR 추가 (사용처 확인된 키부터 순차) — 적용 완료 회신 대기 |
| 인프라 — Tier 1 audit | ✅ 완료 | CRITICAL 2 + HIGH 8 발견 |
| 외부 — 트랙 B-1 (현황 공유) | ✅ 완료 | 메가존소프트 김종현 대표에게 현황·audit 결과 공유 완료 |
| 외부 — 트랙 B-2 (비용 세부 내역) | 🔄 **권한 부여 완료, Console 분석 단계** | ✅ 2026-05-22 Console Billing Reports 접근 권한 부여됨 (BQ export 는 미부여). 청구 발생 프로젝트가 25개로 좁혀짐. **`compatibility-api`·`Gemini API` 두 키는 billing 미연결 → 4/29 청구 원인 제외**. 사용자 Console 직접 분석 후 데이터 공유 단계 |
| 외부 — 트랙 B-3 (Google 구제 방안) | ⏳ **메가존 진행 중** | 메가존소프트가 Google 측에 외부 abuser 이상 사용 비용 구제(refund/credit/dispute) 방안 문의 진행 중 → 결과 회신 대기 |
| 외부 — 트랙 B-4 (결제 알림) | ⏳ 트랙 B 통합 진행 | 6개 위험 프로젝트 월 예산 $50 + 50/90/100% 알림 (DLT 권한 없음 → 메가존 경유) |
| 사업 (혁수님 외) | 키 사용처 회신 대기 | 리포트 공유 후 키별 답변 수집 → 트랙 A IP 결정에 입력 |
| 인프라 — 트랙 3 (보안 점검) | 🆕 **2026-05-21 신설** | API Key 점검·유형 A/B 분류·API_RESTR 화이트리스트(Gemini 차단)·Quota 제한 — [가이드](planning/megazone-mitigation-guide/2026-05-21-api-key-security-checklist.md) |

## 결정 로그

- 2026-05-19 — TODO-017 → 본 프로젝트로 승격. 메가존 가이드 기반 조치 실행 단계로 전환
- 2026-05-19 — Tier 0 (`ai-rule-auto-gen-test-hshan`) audit 결과: HIGH × 2. 혁수님이 4/29 이후 IP `1.234.131.174/32` 로 이미 제한 적용. 출혈 멈춤
- 2026-05-19 — Tier 1 audit 결과: CRITICAL × 2 (ai-product-417102), HIGH × 6 (ai-project, hellobot-llm-{dev,prod}, compatibility-{ai,api}, Gemini API). 모두 APP_RESTR=NONE 공통
- 2026-05-19 — GCP Billing 권한이 메가존에 있어 예산 알림은 사용자 직접 설정 불가 → 메가존 경로 요청으로 분리
- 2026-05-19 — Cloud Monitoring 기반 사건 forensic 완료: ① 자동화 봇 공격 ② 미국 동부 시간대 abuser (cron 18:00 ET) ③ 총 성공 호출 122K 중 102K (83%) 가 4/29 단일 사건 ④ 두 키 모두 abuser 손에 있었음 ⑤ GCP throttling 이 5/12 시도의 93% 차단. 5/12·5/15 IP 제한 추가자 = 혁수님 본인 확정
- 2026-05-20 — **현황 분석 완료**. 후속을 **2-트랙으로 분리**: (A) **보안 보완 — IP 제한 추가** (위험 키 전반 APP_RESTR 적용) / (B) **메가존소프트 협의** — 현황 공유 + 4/29 비용 세부 내역 요청 + Google 외부 이상 사용 구제 방안 문의. 사용처 미파악 키는 audit log 기반 IP 추출 → IP 제한 적용 동시 진행
- 2026-05-20 — **트랙 A 진척**: 혁수님께 **IP 제한 조치 요청 전달** → 적용 완료 회신 대기. 코디네이터 측 추가 액션 없음 (혁수님 응답 모니터링)
- 2026-05-20 — **트랙 B 진척**: B-1 (현황 공유) 완료. **B-2 비용 조회 권한 부여 합의** (메가존) → 권한 부여 대기. **B-3 Google 구제 방안** 메가존이 Google 측 진행 중 → 결과 회신 대기. 즉 2-트랙 모두 외부 응답 대기 모드
- 2026-05-21 — 🆕 **트랙 3 (보안 점검) 신설**. 메가존소프트로부터 API Key 보안 점검·권한 제한 가이드 추가 수신 → 가이드 문서 [planning/megazone-mitigation-guide/2026-05-21-api-key-security-checklist.md](planning/megazone-mitigation-guide/2026-05-21-api-key-security-checklist.md) 보관. 트랙 A 와 일부 중복(IP 제한)되나 트랙 3 은 **API_RESTR 화이트리스트(Generative Language API / Vertex AI API 체크 해제)** 가 핵심 — 유형 B (모바일 앱 하드코딩 Firebase 키) 에서 키 교체 없이 Gemini 호출만 403 차단하는 방식
- 2026-05-22 — ✅ **트랙 B-2 비용 조회 권한 부여 완료**. billing AC `016568-056D75-165D6B` (DLTpartners, 메가존 master `011879-06EA7C-9ADB98` 의 sub-AC) 에 `tony@dlt-partners.com` 커스텀 role(`organizations/597078905893/roles/971`) 부여됨. 권한 검증 결과: ✅ `billing.accounts.list` · `billing.projects.get/list` · `billing.accounts.getIamPolicy` 모두 가능. ❌ BQ billing export dataset 은 25개 billing-enabled 프로젝트 어디에도 없음 (메가존 자체 프로젝트에 보관 추정) → Console UI 분석은 가능, BQ raw 쿼리는 불가. **인사이트**: organization 245개 중 청구 발생 프로젝트는 **25개로 한정**. 위험 키 7개 중 `compatibility-api` (gen-lang-client-0605251657) · `Gemini API` (gen-lang-client-0627053898) **2개는 billing 미연결** → 4/29 청구 원인에서 제외 (위험성은 차후 누군가 billing 연결 시 청구 발생 가능 — 유지). 4/29 청구 분석 대상은 **6개 프로젝트로 축소**: `ai-rule-auto-gen-test-hshan`, `ai-product-417102`, `ai-project-454009`, `gen-lang-client-0403158203`(hellobot-llm-prod), `gen-lang-client-0170471706`(hellobot-llm-dev), `gen-lang-client-0465592155`(compatibility-ai)
- 2026-05-22 — ✅ **`ai-rule-auto-gen-test-hshan` SKU 분해 1차 확보** (사용자 Console 직접 추출, CSV 저장 [billing-data/2026-04-22_to_2026-05-21_ai-rule-auto-gen-test-hshan_sku_breakdown.csv](billing-data/2026-04-22_to_2026-05-21_ai-rule-auto-gen-test-hshan_sku_breakdown.csv)). **30일 총 ₩5,924,383 (≈$4,455), 4/29 단일 ₩5M (84%)** 확정. **Image Generation SKU 78%** (Gemini 3.1 Flash Image 44% + Gemini 3 Pro Image 34%) — 텍스트가 아닌 이미지 abuse 가 손실 주범. 모든 모달리티(텍스트·이미지·비디오·TTS·임베딩) sweep, 최신 모델(3.1 Flash / 3 Pro) 위주 호출 — 자동화 봇 capability probing 흔적. audit-tier1-report.md 2.4b 섹션에 분해 반영. ✅ **3월 baseline 정상 확인**: 직전 30일(3/24~4/21) 총액 = 현재 ₩5,924,383 - 차이 ₩5,897,791 = **₩26,592 (≈$20)**. UI 의 "over ₩X" 는 차이(delta) 표시였음. 4/29 가 단일 사건임 청구 데이터로 재확정

## 블로커

- (해소) 위험 키 사용처 미파악 → IP 제한 우선 적용으로 출혈 차단 후 사용처 회신 수집 병행. 사용처 모르는 키는 audit log 에서 IP 추출

## 다음 마일스톤

| # | 작업 | 상태 |
|---|------|------|
| 1 | 프로젝트 디렉토리 + 가이드 폴더 생성 | ✅ 2026-05-19 |
| 2 | 가이드 문서 + 스크립트 추가 (사용자) | ✅ 2026-05-19 |
| 3 | Tier 0·1 audit + 1차 리포트 | ✅ 2026-05-19 |
| 4 | 현황 분석 완료 + 후속 액션 2-트랙 분리 | ✅ 2026-05-20 |
| 5 | **트랙 A** — 10개 위험 키 IP 제한 (APP_RESTR) 적용 | ⏳ **혁수님 적용 대기** (2026-05-20 요청 전달) |
| 6 | **트랙 B-1** — 메가존소프트에 현황 공유 | ✅ 2026-05-20 |
| 7 | **트랙 B-2** — 4/29 비용 세부 내역 요청 | 🔄 **권한 부여 완료 (2026-05-22), Console 직접 분석 단계** — 사용자가 Console Billing Reports 접근 후 4/29 청구 분해 데이터 추출·공유 |
| 8 | **트랙 B-3** — Google 외부 이상 사용 구제 방안 문의 (메가존 경유) | ⏳ **메가존 진행 중, 결과 회신 대기** |
| 9 | 1차 리포트 팀 공유 + 키 사용처 회신 수집 | ⏳ 트랙 A 와 병행 |
| 10 | Tier 2 (HelloBot 본진 ~30개) audit | ⏳ |
| 11 | Tier 3 (sys-* 자동 ~150개) 일괄 점검 | ⏳ |
| 12 | 메가존 측 결제 알림 설정 요청 | ⏳ (트랙 B 와 통합) |
| 13 | 메가존과 청구 보정 협의 | ⏳ (트랙 B-2 결과 후) |
| 14 | 거버넌스 정리 (키 생성 규칙·정기 audit 자동화·ADC 전환 전략) | ⏳ 별도 트랙 |
| 15 | **트랙 3** — API Key 보안 점검 (Unrestricted 키 식별) | 🆕 **2026-05-21 신설** |
| 16 | **트랙 3** — 유형 A 키 교체 + 유형 B 키 API_RESTR 화이트리스트 (Gemini 차단) | ⏳ |
| 17 | **트랙 3** — Quota 0 또는 최소치 (Gemini 미사용 프로젝트) | ⏳ |
