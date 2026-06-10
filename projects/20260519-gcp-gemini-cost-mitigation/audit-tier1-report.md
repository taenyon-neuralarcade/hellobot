# GCP Gemini API 키 점검 1차 리포트 + 사건 분석

> **작성**: 2026-05-19 (Tony, tony@dlt-partners.com)
> **출처**: 메가존소프트(김종현 대표) 제공 가이드 + Cloud Monitoring 추적
> **공유 대상**: 혁수님 / AI·LLM 개발 / 궁합 기능 담당 / 인프라
> **다음 단계**: 2026-05-20 혁수님과 협의 후 진행 방향 결정

---

## TL;DR (한 페이지 요약)

### 4/29 사건의 정체
- ✅ **외부 abuser 가 stolen Gemini API 키로 자동 호출**한 사건. **미국 동부 시간대 거주자**가 cron 으로 운영
- ✅ **abuse 의 83% 가 4/29 단일 사건** (2시간 안에 102K 성공 호출)
- ✅ GCP 자동 throttling 이 5/12 재시도의 93% 차단해서 추가 피해 최소화
- ✅ 두 키 모두 abuser 손에 있었음 — 한 키 막히니 다른 키로 즉시 시도
- ✅ 5/12 + 5/15 IP 제한 추가는 **혁수님 본인** (재확인 완료)

### 4/29 외 다른 프로젝트의 위험
- 🚨 **`ai-product-417102` 에 CRITICAL 키 2개** — LEGACY + 무제한. 4/29 키보다 더 위험. 안 터진 게 운
- 🟠 HIGH 키 6개 추가 — `hellobot-llm-{prod,dev}`, `compatibility-{ai,api}`, `AI-project`, `Gemini API`
- 모두 공통: APP_RESTR=NONE (IP/referrer 제한 없음)
- 점검한 8개 프로젝트 외 ~237개 미점검 — 추가 위험 가능

### 내일 결정해야 할 핵심 사항
1. **`ai-rule-auto-gen-test-hshan` 두 키 즉시 삭제 여부** (혁수님 합의)
2. **다른 위험 키 8개 사용처 확인 분담** — 혁수님 본인 + 다른 담당자 지정
3. **메가존에 요청할 사항 확정** — Billing 데이터·청구 보정·예산 알림 설정
4. **거버넌스 대책 방향** — 신규 키 발급 금지·정기 audit·ADC 전환 등

---

## 🗓 내일 협의할 결정 사항 (Meeting Agenda)

### A. ai-rule-auto-gen-test-hshan 키 처리

**현황**: 두 키 모두 IP `1.234.131.174/32` 제한 적용 (혁수님 5/12·5/15 설정). 출혈 멈춤.

**선택지**:

| 옵션 | 내용 | 비고 |
|---|---|---|
| 1. **두 키 모두 즉시 삭제** | abuser 키 값 보유 의심 강함. 재시도 가능성 영구 차단 | ✅ 권장 — 더 이상 ai-rule-auto-gen 테스트 안 하면 |
| 2. 한 키만 유지, 한 키 삭제 | 정상 사용 키만 보존 | 사용 중이라면 |
| 3. 둘 다 유지 + ADC 전환 | API 키 자체 폐기, service account 로 | 시간 더 걸림 (코드 수정) |

**혁수님께**: 이 키를 ai-rule-auto-gen 테스트에 계속 쓰실 건가요? 안 쓰시면 즉시 삭제 추천.

### B. 다른 위험 키 8개 사용처 파악

본 리포트 §3 의 키 목록을 보고, **본인이 만들었거나 사용 중인 키 식별 → 사용처 답변**.

특히 다음 4개는 사업 영향 큼:
- `hellobot-llm-prod` (운영 LLM) — 키 `138de159`
- `hellobot-llm-dev` — 키 `d01d65d3`
- `compatibility-ai` — 키 `49683251`
- `compatibility-api` — 키 `74bffccc`

**누가 어떤 키를 책임지고 확인할지** 분담 필요.

### C. 메가존에 요청할 사항

- [ ] 4/29 기간 (4/15~5/19) `ai-rule-auto-gen-test-hshan` 일별 SKU 비용 명세
- [ ] 위 데이터 기반 청구 보정 가능성 협의 — abuse 가 명확하므로 (자동화 봇 + 외부 abuser)
- [ ] 위험 프로젝트 6개 예산 알림 설정 (월 $50 임계값, 50/90/100% 알림)
- [ ] (선택) Cloud Audit Logs Data Access 활성화 — 향후 사건은 caller IP 까지 추적

### D. 거버넌스 (장기)

- AI Studio 즉석 키 발급 (`gen-lang-client-*` 프로젝트) 금지 또는 별도 허가
- 신규 키 발급 시 APP_RESTR (IP/referrer) 필수 체크리스트
- audit 스크립트 정기 실행 자동화 (월 1회)
- 서버용 키 → ADC/Secret Manager 단계적 전환

---

## 1. 배경 (1분 요약)

| 일자 | 사건 |
|---|---|
| 2026-04-29 | GCP `ai-rule-auto-gen-test-hshan` 프로젝트 Gemini 비용 폭증 |
| 2026-05-12 | 혁수님이 1차 발견, key 2 (`gemini-api-key`) IP 제한 추가 |
| 2026-05-15 | 혁수님이 key 1 (`Generative Language API Key`) IP 제한 추가 → 완전 차단 |
| 2026-05-18 | 혁수님이 Tony 에게 이슈 리포트 |
| 2026-05-18~19 | 파트너사 메가존소프트(김종현 대표) 도움 요청 → 점검 가이드라인 + 스크립트 수신 |
| 2026-05-19 | 가이드 기반 audit 진행 + Cloud Monitoring 사건 분석. 본 리포트 작성 |

---

## 2. 4/29 사건 — Cloud Monitoring 기반 Forensic 분석

`serviceruntime.googleapis.com/api/request_count` 메트릭(`ai-rule-auto-gen-test-hshan` 프로젝트, 2026-04-15 ~ 2026-05-19) 분석 결과.

### 2.1 일별 호출 패턴

| 날짜 | ✅ 200 (성공·결제) | 🛑 429 (자동 차단) | 합계 | 차단율 |
|---|---:|---:|---:|---:|
| 4/24 (1차 테스트) | 14,823 | 12,593 | 28,698 | 46% |
| **4/29 (메인 사건)** | **101,916** ⭐ | 17,655 | 121,112 | 15% |
| 5/02 (소규모 probe) | 760 | 1,730 | 2,810 | 69% |
| 5/11 (재시도 시작) | 536 | 5,444 | 6,038 | 91% |
| **5/12 (2차 peak)** | 1,713 | **29,415** ⭐ | 31,963 | 94% |
| 5/13 | 890 | 2,985 | 4,430 | 77% |
| 5/14 | 1,580 | 2,274 | 4,283 | 59% |
| **누적** | **122,218** | 72,096 | 194,668 | 37% |

> 정상 베이스라인은 30~300 req/day 수준.

### 2.2 시간대 분석 — 자동화된 cron 의 흔적

세 spike 의 peak 시각이 **미국 동부 시간(UTC-4 DST) 기준 매우 자연스러움**:

| 사건 | UTC peak | **ET (현지)** | KST | 해석 |
|---|---|---|---|---|
| 4/24 (1차 테스트) | 17:00 | **13:00 (점심)** | 02:00 (다음날) | 수동 키 작동 검증 |
| **4/29 (메인)** | **22:00** | **18:00 (퇴근 후)** | **07:00 (다음날)** | **자동화 cron 첫 가동** |
| **5/12 (재시도)** | **22:00** | **18:00 (퇴근 후)** | **07:00 (다음날)** | **같은 cron 재가동** |

### 2.3 핵심 결론 5가지

1. **🤖 자동화된 봇 공격** — 102K 호출이 2시간 안에 (~14 calls/sec 지속). 사람·정상 서비스 불가능
2. **🌍 abuser 는 미국 동부 시간대 거주자** — 4/29·5/12 모두 ET 18:00 (퇴근 후) cron 가동
3. **🛡️ GCP throttling 이 피해 최소화** — 4/29 학습 전 15% 차단 → 5/12 학습 후 93% 차단. 이 자동 가드 없었으면 비용 2~3배
4. **🔓 두 키 모두 abuser 손에** — 한 키 막히니 다른 키로 즉시 전환. 동시 유출 명확
5. **💥 abuse 의 83% 가 4/29 단일 사건** — 122K 성공 중 102K, 2시간 집중. 비용 대부분 그날 발생

### 2.4 추정 비용 (정확한 건 Billing 데이터 필요)

122K 성공 호출 × 모델별 단가:

| 모델 가정 | 평균 토큰 | 추정 비용 |
|---|---|---|
| gemini-1.5-flash | 2000 | ~$40 |
| gemini-1.5-pro | 2000 | ~$500 |
| gemini-2.5-pro | 2000 | ~$1,000 |
| gemini-2.5-pro | 4000 | ~$2,000 |

### 2.4b ✅ 실측 청구 분해 (2026-05-22 Console Billing Reports 접근권 부여 후)

**출처**: Cloud Console Billing Reports — billing AC `016568-056D75-165D6B` / 프로젝트 `ai-rule-auto-gen-test-hshan` / 기간 2026-04-22 ~ 2026-05-21 (30일) / Group by SKU. CSV: [billing-data/2026-04-22_to_2026-05-21_ai-rule-auto-gen-test-hshan_sku_breakdown.csv](billing-data/2026-04-22_to_2026-05-21_ai-rule-auto-gen-test-hshan_sku_breakdown.csv)

**총액**:

| 항목 | 값 |
|---|---|
| 30일 총 비용 (4/22~5/21) | **₩5,924,383** (≈ $4,455 @ ₩1,330) |
| **4/29 단일 spike** | **약 ₩5,000,000** (≈ $3,760, 전체의 약 84%) |
| 직전 30일 (3/24~4/21) 총액 | **₩26,592** (≈ $20) — ✅ 정상 baseline 확인 |
| 증가 차이 | +₩5,897,791 (직전 30일 대비), 비율 +22,177.98% |

**Top 10 SKU 분해** (총 ₩5.9M 중 비중):

| 순위 | SKU | 사용량 | 비용 (₩) | 비중 |
|---|---|---|---|---|
| 1 | **Gemini 3.1 Flash Image — Image Output** | 28.7M count | 2,592,332 | 43.8% |
| 2 | **Gemini 3 Pro Image — image output token** | 11.1M count | 2,009,328 | 33.9% |
| 3 | Gemini 3 Flash — text output | 68.8M tokens | 311,831 | 5.3% |
| 4 | Gemini 3 Pro Short — text output | 16.7M tokens | 301,892 | 5.1% |
| 5 | Gemini 3 Flash — text input | 239.7M tokens | 180,946 | 3.1% |
| 6 | Gemini 2.5 Flash Native Image Generation | 2.4M count | 108,569 | 1.8% |
| 7 | Gemini 3 Flash — video input | 113.3M tokens | 85,561 | 1.4% |
| 8 | Gemini 2.5 Pro Short — text output | 5.1M tokens | 76,769 | 1.3% |
| 9 | Gemini 3 Pro Short — text input | 20.9M tokens | 63,137 | 1.1% |
| 10 | Gemini 3.1 Flash Lite Preview — text output | 20.7M tokens | 46,865 | 0.8% |
| **꼬리 47 SKU** | (TTS·Embedding·Cached·Audio·기타) | — | 약 ₩260K | 4.4% |

**실측 기반 핵심 인사이트** (forensic 보강):

1. **Image Generation 이 손실의 78%** — Gemini 3.1 Flash Image (44%) + Gemini 3 Pro Image (34%). 단순 텍스트 호출이 아닌 **이미지 생성 API 가 주 abuse 타겟**. 이미지 SKU 단가가 텍스트 토큰 대비 매우 비쌈 → abuser 가 비용 최대화 노린 패턴
2. **모든 모달리티 sweep** — 이미지·텍스트·비디오 입력·TTS·임베딩까지 광범위 호출. ₩0 SKU 라인 (`search query gemini 3 free`) 까지 흔적 → **자동화 봇의 capability probing / fingerprinting 시도**
3. **최신 모델 위주** — Gemini 3.1 Flash, Gemini 3 Pro 가 압도적. Gemini 2.5 Pro/Flash 는 1~5%. abuser 가 의도적으로 가장 강력한 최신 모델 선택
4. **호출 횟수(122K) × SKU 단가** 매핑 확정 — 추정 $40~$2,000 → **실측 $3,760** (이미지 SKU 가 텍스트 추정보다 훨씬 비쌌음)
5. ✅ **3월 baseline = ₩26,592 ($20)** — 정상 사용 수준. 4/29 가 단일 사건임 청구 데이터로 재확인 (이전 "직전 30일도 ₩5.9M" 해석은 UI 표기 오독, "over ₩X" = 차이 의미)
6. **5/12 이후 잔여 호출** — 차트에서 5/5, 5/11~5/14 미세 spike 존재. IP 제한(5/12) 직전 abuser 재시도 가능성

**구제 협상 입력 (트랙 B-3)**:
- "abuser 가 Gemini 3.1 Flash Image / Gemini 3 Pro Image SKU 를 단일일 ₩5M (84%) 폭주" 라는 구체적 사실 제시 가능
- SKU 단위 정량 데이터 → refund/credit dispute 협상 근거 강화

### 2.5 Forensic 미해결 — 키 유출 경로

- Cloud Monitoring 데이터는 **caller IP 를 노출하지 않음** (Data Access Logs 미활성 — 4/29 당시 활성 안 되어 있었음)
- 키 값이 어디로 유출됐는지(GitHub, 슬랙, 클라이언트 코드, 노트북 침투 등) 별도 추적 필요
- **abuser 가 5/15 까지도 키를 갖고 있었음** = 키 값이 확실히 외부에 있는 상태
- 권장: GitHub 검색, gitleaks/trufflehog 스캔, 슬랙 키 ID 검색

---

## 3. 다른 프로젝트의 위험 키 — Tier 1 Audit 결과

메가존 제공 read-only 스크립트(`firebase_gemini_key_audit.sh`)로 HelloBot/thingsflow 조직 245개 GCP 프로젝트 중 AI/Gemini 관련 8개 우선 점검.

### 3.1 발견 — 위험 키 10개

| # | Project | 표시 이름 | RISK | 키 ID (앞 8자리) | 생성일 | 비고 |
|---|---|---|---|---|---|---|
| 1 | `ai-product-417102` | ai-product | 🚨 **CRITICAL** | `6d1f37aa` | 2024-04-04 | LEGACY + UNRESTRICTED — Gemini·Vertex 둘 다 |
| 2 | `ai-product-417102` | ai-product | 🚨 **CRITICAL** | `ae5a3711` | 2024-03-13 | LEGACY + UNRESTRICTED |
| 3 | `ai-project-454009` | AI-project | 🟠 HIGH | `23d59b64` | 2025-04-17 | APP_RESTR=NONE |
| 4 | `gen-lang-client-0170471706` | **hellobot-llm-dev** | 🟠 HIGH | `d01d65d3` | 2026-05-06 | APP_RESTR=NONE, 최근 생성 |
| 5 | `gen-lang-client-0403158203` | **hellobot-llm-prod** | 🟠 HIGH | `138de159` | 2026-04-27 | ⭐ **운영 LLM**, APP_RESTR=NONE |
| 6 | `gen-lang-client-0465592155` | compatibility-ai | 🟠 HIGH | `49683251` | 2026-04-08 | APP_RESTR=NONE |
| 7 | `gen-lang-client-0605251657` | compatibility-api | 🟠 HIGH | `74bffccc` | 2026-04-07 | APP_RESTR=NONE |
| 8 | `gen-lang-client-0627053898` | Gemini API | 🟠 HIGH | `09814bf7` | 2025-02-06 | APP_RESTR=NONE |
| 9 | `ai-rule-auto-gen-test-hshan` | (혁수님 테스트, 4/29 발생) | 🟠 HIGH | `f6e59b43` | 2025-08-04 | IP 제한 적용됨 |
| 10 | `ai-rule-auto-gen-test-hshan` | (동일) | 🟠 HIGH | `57ea0b81` | 2025-08-04 | IP 제한 적용됨 |

> Tier 2 (HelloBot 본진 ~30개), Tier 3 (`sys-*` 자동 생성 ~150개) 미점검.

### 3.2 위험 등급 기준 (메가존 가이드)

| 조건 | 등급 |
|---|---|
| 2024-05-01 이전 생성 (LEGACY) + 모든 API 호출 가능 (UNRESTRICTED) | **CRITICAL** — 즉시 조치 |
| UNRESTRICTED 또는 Gemini 명시 허용 | **HIGH** — 신속 조치 |
| LEGACY + 일부 제한 | WARN |
| 그 외 | OK |

### 3.3 🚨 가장 시급 — `ai-product-417102` CRITICAL 키 2개

| 위험 요소 | 상태 | 의미 |
|---|---|---|
| LEGACY (2024-05-01 이전 생성) | ✅ 해당 | Firebase 자동 제한 정책 이전 — 어떤 자동 제한도 적용 안 됨 |
| Application restrictions | **NONE** | IP/referrer/Android/iOS 제한 없음 — 어디서든 호출 가능 |
| API restrictions | **UNRESTRICTED** | 프로젝트의 모든 활성 API 호출 가능 |
| Gemini API | **ENABLED** | Generative Language API 사용 가능 |
| Vertex AI API | **ENABLED** | Vertex 도 사용 가능 (모델 폭이 더 넓음, 비용도 더 큼) |

→ 이 키 값이 유출되면 4/29 보다 큰 사건 가능. **즉시 조치 권장**.

### 3.4 🟠 HIGH 키 6개 공통 패턴

`AI-project`, `hellobot-llm-{dev,prod}`, `compatibility-{ai,api}`, `Gemini API` 모두:
- **APP_RESTR = NONE** (IP/referrer/Android/iOS 제한 없음)
- API restrictions 로 Gemini 만 호출하도록 좁힘 (그래서 HIGH, CRITICAL 아님)
- 키 값만 알면 누구나 어디서나 Gemini 호출 가능

특히 **`hellobot-llm-prod`** 는 운영 LLM 키 — 유출 시 직접적 사업 영향.

### 3.5 핵심 인사이트

**① 5개 키가 `gen-lang-client-*` 패턴 — AI Studio 즉석 발급 흔적**
- [aistudio.google.com](https://aistudio.google.com) 에서 "Get API key" 클릭 시 자동 생성되는 프로젝트 ID 패턴
- 정식 프로젝트 명명 규칙 밖, 거버넌스 부재 신호

**② 모든 위험 키에서 APP_RESTR=NONE — 조직 차원 습관**
- 키 생성 시 IP 제한을 거는 절차가 정착되지 않음
- 메가존 가이드의 근본 해법 ADC/Secret Manager 가 필요한 이유

**③ 4/29 이상비용은 빙산의 일각**
- 같은 위험 패턴 키가 10개 산재. 한 곳에서 먼저 터졌을 뿐

---

## 4. 🙏 요청 사항 — 본인이 만든/쓰는 키 확인 부탁드립니다

### 우선순위 1 — 🚨 CRITICAL

**`ai-product-417102` 의 두 키 (`6d1f37aa`, `ae5a3711`)**

- 누가 만드셨는지?
- 어디서 호출 중인지?
- 지금도 사용 중인지?

### 우선순위 2 — 🟠 HIGH (사업 영향 큼)

**`hellobot-llm-prod` (gen-lang-client-0403158203) 키 `138de159`**
- 누가 만드셨는지? 호출하는 서비스가 뭔지?
- 현재 AWS Secrets Manager (`hlb/prod/*`) 에 이 키 값이 들어가 있는지?

**`hellobot-llm-dev` (gen-lang-client-0170471706) 키 `d01d65d3`** — 위와 동일 (dev)

**`compatibility-ai` / `compatibility-api` 키 2개** — 궁합 기능 어디서 호출? 왜 ai 와 api 가 분리?

**`AI-project`, `Gemini API` 키 2개** — 만든 분 + 사용처?

### 권장 조치 트리 (답변별)

| 답변 | 조치 |
|---|---|
| "안 씀, 삭제 OK" | 즉시 삭제 (`gcloud services api-keys delete <KEY_ID> --project=<PROJ>`) |
| "쓰지만 IP 알아냄" | APP_RESTR 추가 (IP) |
| "운영 중, 서버에서 호출" | ADC 또는 Secret Manager 로 전환 (코드 수정, 점진) |
| "쓰는데 누가/어디서 모름" | Cloud Audit Logs 로 추적 후 결정 |
| "회신 없음" | 일단 APP_RESTR 0.0.0.0 으로 차단 → 깨지는 서비스가 알려옴 |

---

## 5. 다음 단계 일정

| # | 단계 | 상태 |
|---|---|---|
| 1 | 메가존 가이드 + 점검 환경 준비 | ✅ |
| 2 | Tier 0 (`ai-rule-auto-gen-test-hshan`) audit + Forensic | ✅ |
| 3 | Tier 1 (AI/Gemini 8개) audit + 본 리포트 | ✅ |
| 4 | **🗓 2026-05-20 혁수님 + 팀과 협의 → 진행 방향 결정** | ⏳ |
| 5 | 키별 사용처 답변 수집 (혁수님 + 담당자 분담) | ⏳ |
| 6 | 키별 조치 (삭제·제한·rotate·ADC 전환) | ⏳ |
| 7 | Tier 2 (HelloBot 본진 ~30개) audit | ⏳ |
| 8 | Tier 3 (`sys-*` ~150개) 일괄 점검 | ⏳ |
| 9 | 메가존 측 Billing 데이터 + 청구 보정 + 예산 알림 요청 | ⏳ |
| 10 | 거버넌스 정리 (별도 트랙) | ⏳ |

---

## 6. 메가존 가이드 핵심 (참고)

정적 API 키 대신 다음 중 하나로 전환 권장:

1. **ADC + 서비스 계정** (서버↔서버) — 가장 권장. 단명 토큰 자동 rotate
2. **Secret Manager** — 키 불가피하게 써야 할 때. IAM 로 최소 권한
3. **OAuth 2.0** — 최종 사용자 대신 호출할 때

---

## 7. 데이터 산출물

| 파일 | 내용 |
|---|---|
| `audit-tier1-report.md` | **본 리포트 (공유용)** |
| `status.md` | 프로젝트 진행 상태 |
| `tasks.md` | 조치 과업 체크리스트 |
| `planning/megazone-mitigation-guide/audit-tier1-20260519.log` | Tier 1 audit 원본 로그 |
| `planning/megazone-mitigation-guide/investigation-april-requests.json` | Cloud Monitoring 4/15~5/19 데이터 (2MB) |
| `planning/megazone-mitigation-guide/all-projects.csv` | 245개 프로젝트 인벤토리 |
| `planning/megazone-mitigation-guide/GCP API 관련 체크리스트/` | 메가존 제공 가이드 PDF 5종 + 스크립트 |

---

## 8. 회신 채널

회신은 슬랙 또는 이메일로 **Tony (tony@dlt-partners.com)** 에게.

긴급 사항 (키 유출 의심·신규 abuse 발견 등) 은 즉시 알려주세요.
