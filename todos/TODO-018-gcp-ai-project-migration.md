---
name: todo-018-gcp-ai-project-migration
description: GCP 마이그레이션 — dlt-partners.com 조직의 일부 AI 프로젝트를 신규 GCP 환경으로 이전
metadata:
  type: action
---

# TODO-018 GCP AI 프로젝트 마이그레이션 (dlt-partners.com 조직)

**유형**: 액션 (인프라 작업) + 모니터링 (파트너사 협업·후행 청구 대기)
**상태**: ✅ 완료 — 2026-05-27 8개 프로젝트 전부 thingsflow.kr 이전 완료. Org Policy 복구 완료. 후속 API 키 보안 점검 → TODO-038
**등록**: 2026-05-18
**시작**: 2026-05-18
**완료**: 2026-05-27
**마감**: **2026-05-22 (금) D-Day → 5/31 (토) 내 클로즈**
**담당**: 사용자 (총괄·외부 채널) → 인프라 실행은 `/dev-infra` 협업 / 메가존소프트 김종현 대표님 (양도측 실무 또는 자문)
**관련**: [[todo-005-infra-contract-monitoring]] (GCP 계약 5/18 완료) · [[todo-007-bitwin-infra-separation]] (DLT 인프라 분리 흐름) · [[project-gcp-gemini-cost-anomaly]] (GCP 비용 이슈 — 본 이전과 정합) · [[todo-010-ai-account-migration]] (AI 계정 이전 5/22 공지) · [[todo-031-aws-account-1-4-migration-neuralarcade]] (AWS 1~4 동일 PMI 흐름)

## 컨텍스트

5/18 GCP 계약 완료(TODO-005) 후속 작업. **dlt-partners.com 조직** GCP 리소스 중 AI 프로젝트 군을 PMI 흐름에 맞춰 **운영권·관리권·결제책임**을 이전.

### 5/22 — 메가존소프트 표준 가이드 PDF 수신

**보관 위치**: `Box Sync/[사용중] Neural Arcade/업무/PMI/GCP - 메가존소프트/[뉴럴아케이드] GCP 운영권·관리권 및 결제책임 이전 가이드_메가존소프트.pdf`

**핵심 원칙**: 동일 **GCP 조직 ID 유지**하면서 운영권·관리권·결제책임만 양도→양수. 리소스 재생성 없음(=조직 이동/프로젝트 이동이 아닌 권한·결제 주체 교체).

### 가이드 체크포인트 (4단계 + 사전준비 + 사후검토)

**[사전 준비 — 4종 / 양도측·양수측 분담]**

| 항목 | 상세 | 준비 주체 |
|------|------|----------|
| 도메인 통제권 | 가비아/AWS Route 53 등 등록처 관리권 | 양도측 실무 |
| Workspace Super Admin | Google Workspace / Cloud Identity 최고 관리자 | 양도측 실무 |
| GCP Org Admin | GCP 조직 수준 `roles/resourcemanager.organizationAdmin` | 양도측 실무 |
| 신규 결제 수단 | 양수 법인 명의 결제 정보 (카드/인보이스) | 양수측 실무 |

**[1단계 — 도메인 통제권·법적 귀속 이전]**

- 도메인 Registrar(가비아/AWS 등) WHOIS 명의 변경 → 법적 귀속 변경
- DNS 제어권(네임서버 관리 권한) 양수측 이관

**[2단계 — 관리자 권한 정비 (Workspace & GCP)]**

- Workspace Super Admin: 양수측 담당자에 '최고 관리자' 부여 → 기존 양도측 관리자 계정 권한 회수 또는 삭제/보관
- GCP Org Admin: 양수측 담당자에 `roles/resourcemanager.organizationAdmin` 부여
- **조직·폴더·프로젝트 IAM 검토**: 이전 법인 관계자 **직접 권한 + 상속 권한** 모두 제거

**[3단계 — 결제책임(Billing) 이전 + 후행 청구 관리]**

- 양수 법인 정보로 **신규 결제 계정 생성·연결** → 기존 프로젝트의 결제 대상 변경
- ⚠ **후행 청구(Trailing Charges)**: 변경 시점 이전 발생 사용량 비용은 **양도측 결제 계정으로 사후 청구** 가능 → 양도측 계정 즉시 삭제 금지. **최종 청구서 발행까지 모니터링**

**[4단계 — 표시 정보·대외 연락처]**

- 조직 표시 정보(이름·주소) 및 지원·알림 연락처 갱신 (필요 시)
- Google Support Case 기본 연락처·수신 이메일을 **양수측 실무자**로 변경

**[Post-Transfer 보안·권한 검토]**

- 상속된 권한 전수 조사: 조직/폴더 수준에서 내려오는 이전 법인 인원 권한 삭제 확인
- 서비스 계정 키 검토·**재발급**: 양도측이 소유했던 외부 시스템 연동용 SA 키(JSON)
- 조직 정책(Org Policy) 재검토: 법인 변경에 따라 보안 기준이 달라질 경우 정책 수정

**[주의사항]**

- **지원 약정 승계**: Premium Support 등 기업 전용 지원 플랜은 계약 승계 여부를 **Google 영업 담당자와 별도 확인** (자동 승계 아님)
- 본 가이드는 일반 절차 — Workspace/Cloud Identity 구성, Cloud Billing 계약 조건, 조직별 보안 정책에 따라 세부 절차 상이 가능 → 사전 검토 필요

**[실행 전 필수 체크리스트 6항]**

- [ ] 양수측 Super Admin 계정 준비 완료 (관리자 콘솔 접근·도메인 제어 가능)
- [ ] 양수측 Organization Admin 권한 부여 완료 (조직 수준 정책 편집 가능)
- [ ] 대상 프로젝트별 기존 Billing Account 확인 완료 (마이그레이션 누락 점검)
- [ ] **Billing 변경 시각 기록** (비용 분담 및 정산 시점 증빙)
- [ ] Essential Contacts & Support 연락처 갱신 대상 명단 확보
- [ ] 이전 법인 사용자/그룹 IAM 회수 계획 (작업 직후 제거 대상 리스트)

### 결정 사항 (2026-05-22 사용자 확정)

1. **양수/양도 방향**: ✅ **우리=양수측 (neuralarcade가 받음)** — TODO-031 AWS 이전·TODO-010 AI 계정 이전 흐름과 정합
2. **이전 단위**: ✅ **일부 AI 프로젝트만 분리** — 조직 전체 이전 아님 → 가이드의 1단계(도메인)는 비적용, 별도 `gcloud projects move` 절차 필요
3. **실무 분담**: ✅ **메가존 자문 + 우리 전담** — 실행은 우리, 메가존은 자문·승인 채널

### 대상 프로젝트 목록 (2026-05-25 사용자 확정 · 8개)

작년 org-to-org 마이그레이션 체크리스트의 2번 항목("마이그레이션 대상 프로젝트 리스트 작성") 완료.

| # | Project ID | 추정 성격 | 메모 |
|---|-----------|----------|------|
| 1 | `ai-project-454009` | AI 일반 프로젝트 (수동 생성) | 명명 패턴: `ai-project-{auto-num}` |
| 2 | `gen-lang-client-0627053898` | Google AI Studio 자동 생성 | Gemini API 키 발급 시 자동 생성 |
| 3 | `ai-rule-auto-gen-test-hshan` | AI 룰 자동 생성 테스트 | ⚠ **GCP Gemini 이상비용 발생 프로젝트** (4/29) · gcp-gemini-cost-mitigation 정합 필수 |
| 4 | `automation-466602` | 자동화 프로젝트 (수동 생성) | 명명 패턴: `automation-{auto-num}` |
| 5 | `gen-lang-client-0465592155` | Google AI Studio 자동 생성 | Gemini API 키 발급 시 자동 생성 |
| 6 | `gen-lang-client-0605251657` | Google AI Studio 자동 생성 | Gemini API 키 발급 시 자동 생성 |
| 7 | `gen-lang-client-0170471706` | Google AI Studio 자동 생성 | Gemini API 키 발급 시 자동 생성 |
| 8 | `gen-lang-client-0403158203` | Google AI Studio 자동 생성 | Gemini API 키 발급 시 자동 생성 |

**관찰**:
- `gen-lang-client-*` 5개는 모두 [aistudio.google.com](https://aistudio.google.com) 에서 Gemini API 키 발급 시 자동 생성된 프로젝트. 5개 = 5명의 다른 사용자가 dlt-partners.com 도메인 계정으로 API 키를 만들었을 가능성. **각 프로젝트의 소유자/사용처(어떤 외부 시스템이 이 API 키를 쓰는가) 식별이 SA 키 재발급보다 먼저 필요**.
- `ai-rule-auto-gen-test-hshan` 은 이름의 `hshan` 접미사로 보아 특정 인물 명의로 생성된 테스트성 프로젝트 — 비용 이상이 발생한 곳이므로 **이전 직후 Quota·API Restriction 정책 즉시 적용 필요** (gcp-gemini-cost-mitigation 트랙 3 정합).
- `ai-project-454009`, `automation-466602` 는 수동 생성된 프로젝트로 보임 — 명명 의도가 명확. 리소스 인벤토리 통해 실제 사용 여부 확인 필요.

### 작년 체크리스트 진행 상태 (2026-05-26)

| # | 항목 | 상태 |
|---|------|------|
| 1 | 마이그레이션 진행할 계정의 권한 부여 | ✅ 완료 |
| 2 | 마이그레이션 대상 프로젝트 리스트 작성 | ✅ 완료 (8개) |
| 3 | 마이그레이션 대상 프로젝트의 사용 리소스 파악 | ✅ **완료** (5/26 인벤토리 스크립트 실행) — `inventory-20260526/_summary.txt` |

### 인벤토리 분석 결과 (2026-05-26)

스크립트 위치: `Box Sync/[사용중] Neural Arcade/업무/PMI/GCP - 메가존소프트/GCP Migration/2025.02.04 띵플 > DLT 마이그레이션/GCP Migration DLT to Neural/inventory-20260526/`

**4그룹 분류**:

| 그룹 | 프로젝트 | 특성 | 이전 난이도 |
|------|---------|------|------------|
| A. 본격 운영 | `ai-project-454009` | Billing ON · 33 APIs · VPC 자원(44 Routes/43 Subnets/4 FW — default 잔여물 추정) · SA 2 + 키 3 · API key 1 · Monitoring Dashboard | 高 |
| B. 이상비용·테스트 | `ai-rule-auto-gen-test-hshan` | Billing ON · 26 APIs · API key 2 + SA 키 3 · Org Policy 1 · RecentQuery 3 | 中 (가드레일 재적용 필수) |
| C. 자동화·결제차단 | `automation-466602` | **Billing OFF** · 23 APIs · SA 2 + 키 3 · Org Policy 2 · apikeys API 비활성 | 中 (폐기 검토) |
| D. Gemini API key 보관 | `gen-lang-client-*` 5개 | 거의 빈 프로젝트 · 각 1 API key (`-0403158203` 만 3개) · SA 없음 | 低 (개수 많지만 단순) |

**핵심 인벤토리 숫자**:

- **API key 8개 분포** (재발급 + 사용처 식별 핵심):
  - gen-lang-client-0627053898: 1 (Billing OFF)
  - gen-lang-client-0465592155: 1
  - gen-lang-client-0605251657: 1 (Billing OFF)
  - gen-lang-client-0170471706: 1
  - gen-lang-client-0403158203: **3** ⚠ 다른 gen-lang-client 와 달리 키 3개 — 사용처 분산 가능성
  - ai-rule-auto-gen-test-hshan: 2
  - ai-project-454009: 1

- **SA 키 9개 분포** (외부 시스템 연동):
  - ai-project-454009: 3
  - ai-rule-auto-gen-test-hshan: 3
  - automation-466602: 3

- **Org Policy 흔적** (이전 시 사라짐 → 재적용 대상):
  - ai-rule-auto-gen-test-hshan: 1
  - automation-466602: 2

- **Billing OFF 프로젝트 3개**: gen-lang-client-0627053898, automation-466602, gen-lang-client-0605251657 → 폐기 검토

### Tier 분류 (2026-05-27 — 빌링 검증 후 최종)

| Tier | 프로젝트 | 실 용도 | 5월 비용(₩) | 이전 영향 |
|------|---------|--------|------------|---------|
| 🔴 T1 운영 | gen-lang-client-0403158203 | **hellobot-llm-prod** · API key 3개 | ? (확인 필요) | 매우 큼 — 무중단 전환 |
| 🔴 T1 운영 | **ai-project-454009** | **사용자 조사 = "과거 개발용"이지만 실제는 운영 호출 중** · API key 1개 + SA 1개 | **약 491만원/27일 = 월 545만원** · Gemini 3 Flash + 2.5 Flash · 100억 토큰 | 매우 큼 — 사용처 식별 무선결 |
| 🟡 T2 개발 | gen-lang-client-0170471706 | **hellobot-llm-dev** · API key 1개 | ? | 낮음 |
| 🟠 T3 운영 준비 | gen-lang-client-0605251657 | **compatibility-api** (궁합책 · 미배포) | 0 (Billing OFF) | 낮음 — 담당자 문의 필요 |
| 🟠 T3 운영 준비 | gen-lang-client-0465592155 | **compatibility-ai** (궁합책 · 미배포) | 0 추정 | 낮음 — 담당자 문의 필요 |
| ⚪ T5 좀비 확정 | ai-rule-auto-gen-test-hshan | 본문 제작기 (현재 미사용 · 4/29 이상비용 이력) | **30일 ₩5.9M (4/29 단일 ₩5M = 84%) · 5/1 이후 baseline 정상 (월 ₩20 수준)** — TODO-017/cost-mitigation 정합 | 낮음 BUT **가드레일 재적용 필수** (Org Policy 1개 + IP 제한 + APP_RESTR — 이전 시 모두 검증) |
| ⚪ T5 좀비 확정 | gen-lang-client-0627053898 | 미상 (Billing OFF) | 0 | 0 |
| ⚪ T5 좀비 확정 | automation-466602 | 미상 (Billing OFF · Org Policy 2개) | 0 | 0 |

⚠ **ai-project-454009 = "감춰진 운영" 위험 자산**: 담당자 인지 = "과거 개발용", 실제 = 월 545만원 Gemini 호출. **누군가 과거에 만든 키가 어디 운영 시스템에 박혀있고 그게 살아있는 상태**. 이전 시 깨지면 어디서 깨지는지조차 모르는 위험 — 사용처 식별이 이전 강행 전 무조건 선행.

### 이전 Phase (안전 순 — 빌링 검증 반영 최종)

- **Phase A (5/28~29) — 진짜 좀비 3개**: gen-lang-client-0627053898 → automation-466602(Org Policy 2개 재적용) → ai-rule-auto-gen-test-hshan(Org Policy 1개 + 가드레일 재적용)
- **Phase B (5/29~30) — 미배포 궁합책 2개**: gen-lang-client-0465592155 → gen-lang-client-0605251657 (담당자 분리 이유 문의 결과 반영)
- **Phase C (5/30) — 개발 환경**: gen-lang-client-0170471706 (dev LLM 호출 정상성 확인)
- **Phase D (5/30~31) — 운영 2개** ⚠️: gen-lang-client-0403158203 (hellobot-llm-prod) + **ai-project-454009** (감춰진 운영) — 트래픽 저점 시간대 + 즉시 모니터링 + 사용처 식별 선행

### 사용자 결정 추가 (2026-05-26)

5. **hellobot-llm-prod 이전 전략**: ✅ **이전만 (키 그대로) + 즉시 모니터링** — gcloud projects move 후 결제 변경 시각 정밀 기록 + 1시간 호출량 모니터링
6. **compatibility-ai vs compatibility-api 분리 이유**: ⏳ **확인 필요** — 담당 개발자 문의 후 결정 (Phase B 진행 전)
7. **ai-project-454009 도메인 제한 추가 시점**: ✅ **이전 후 양수 조직에서 처리** — 이전 자체는 단순화, 도메인 잠금은 후속 보안 작업으로

### 사용자 결정 4건 (2026-05-26 확정)

1. **API key·SA 키 사용처 식별 방식**: ✅ **자체 추적 + 기존 사용자 문의 병행**. 비용 등으로 현재 실 사용 확인된 건 우선으로 직접 수행, 그 외는 DLT 측 사용자들에게 문의 요청
2. **Billing OFF 3개 프로젝트**: ✅ **일괄 이전** (폐기 없음, 8개 모두 이전)
3. **ai-project-454009 VPC 실태 확인**: ✅ **GCE/Cloud Run/Functions 인스턴스 검증** — 추가 명령으로 default 잔여물 vs 실 워크로드 구분
4. **SA 키 9개 재발급 정책**: ✅ **그대로 유지** (재발급 없이 프로젝트와 함께 이동)

⚠ **결정 4의 리스크 메모**: 메가존 가이드의 Post-Transfer 권장은 "외부 시스템 연동용 SA 키 재발급". 그대로 유지 결정은 ① 양도 법인 관계자가 키 사본을 보유했을 경우 이전 후에도 접근 가능 ② 양수 조직 보안 기준 변동 시 키 무력화 위험. **이전 직후 IAM 권한 회수로 보완 (SA 자체의 역할 축소 + 양도측 인원 IAM 제거)**.

### 결정으로 인한 가이드 적용 범위 조정

원본 가이드는 "조직 ID 유지 + 운영권·관리권·결제책임 양도→양수" 표준 시나리오. 우리는 **"일부 프로젝트 분리 이전"** 이라 4단계 중 일부만 적용:

| 가이드 단계 | 우리 시나리오 적용 |
|------------|--------------------|
| 1단계 도메인 | ❌ **비적용** — dlt-partners.com 조직 ID는 양도 안 함, 도메인 그대로 |
| 2단계 권한 | ⚙ **부분 적용** — 대상 프로젝트 IAM 만 갱신 (Workspace Super Admin·조직 Org Admin 이전은 비적용) |
| 3단계 Billing | ✅ **핵심 적용** — 대상 프로젝트들의 Billing Account 를 양수 법인 명의 신규 계정으로 |
| 4단계 표시 정보·연락처 | ⚙ **부분 적용** — 대상 프로젝트의 Essential Contacts·Support 연락처만 |
| Post-Transfer SA 키 재발급 | ✅ **적용** — 대상 프로젝트 SA 키 재발급 + 사용처 갱신 |
| Post-Transfer 상속 권한 검토 | ✅ **적용** — 이동 후 신규 위치(조직/폴더) 상속 권한 검증 |
| Post-Transfer Org Policy | ⚙ **부분 적용** — 이동 후 신규 조직 Org Policy 가 대상 프로젝트에 적합한지만 확인 |
| 후행 청구 모니터링 | ✅ **적용** — 구 Billing Account 의 trailing charges 4~8주 모니터링 |

### 핵심 메커니즘 (시나리오 명확화)

1. **신규 양수 조직(또는 폴더) 준비**: 가설 — neuralarcade.ai Workspace 기반 신규 GCP 조직 (TODO-010 AI 계정 이전 흐름과 정합). **확인 필요**: 이미 존재 / 신설 여부, Org ID
2. **대상 AI 프로젝트 식별**: dlt-partners.com 조직 내 어떤 프로젝트 (예: `ai-rule-auto-gen-test-hshan` 외) — 메가존 또는 우리 자체 인벤토리
3. **프로젝트 이동**: `gcloud beta projects move PROJECT_ID --organization=NEW_ORG_ID` (또는 `--folder=...`). 단, **사전 조건** = 양 조직에 적절한 권한 + 동일 Cloud Identity 도메인 또는 외부 ID 허용 정책
4. **Billing 교체**: 양수 법인 명의 신규 Billing Account → 대상 프로젝트들의 결제 대상 변경
5. **IAM·SA 키·Essential Contacts·Support 갱신**: 프로젝트 단위
6. **검증·후행 청구 모니터링**

### 메가존에 추가 자문 요청 후보

- [ ] 대상 AI 프로젝트 목록 확정 (메가존 측 인벤토리 공유 요청)
- [ ] `gcloud projects move` 사용 가능 여부 (조직 정책 상 제약 / 양 조직 IAM 사전 조건)
- [ ] 양수측 신규 조직 = neuralarcade.ai Workspace 기반 신설 vs 기존 활용
- [ ] 구 Billing Account 후행 청구 모니터링 책임 분담 (어디서 청구서 확인)
- [ ] dlt-partners.com 조직 내 헬로우봇 본진 프로젝트는 그대로 유지 — 영향 없음 확인

### 관련 TODO·프로젝트

- **TODO-005**: GCP 계약 5/18 완료 (전제 조건)
- **TODO-007**: 비트윈 인프라 분리 — DLT 협업 흐름. PMI 일관성 확인 필요
- **TODO-010**: AI 계정 이전 (Workspace 사용자 계정 이전 흐름과 정합) — 본 TODO 의 신규 양수 조직 토대
- **TODO-031**: AWS 1~4 neuralarcade.ai 이전 — 동일 PMI 흐름, 결제 주체 교체 패턴 공통
- **gcp-gemini-cost-mitigation**: 진행 중 비용 이슈. **본 이전 대상 프로젝트(예: `ai-rule-auto-gen-test-hshan`) 가 비용 이슈 발생 프로젝트와 겹칠 가능성 높음** → 이전 전후 비용 분담·정산 시점 정밀 기록 필요

### 관련 TODO·프로젝트

- **TODO-005**: GCP 계약 5/18 완료 (전제 조건)
- **TODO-007**: 비트윈 인프라 분리 — DLT 협업 흐름. PMI 일관성 확인 필요
- **TODO-010**: AI 계정 이전 (Workspace 사용자 계정 이전 흐름과 정합)
- **TODO-031**: AWS 1~4 neuralarcade.ai 이전 — 동일 PMI 흐름, 결제 주체 교체 패턴 공통
- **gcp-gemini-cost-mitigation**: 진행 중 비용 이슈. 본 이전 전후로 결제 계정·IAM 변동 영향 받음 — Billing 변경 시각 기록 시 본 프로젝트 status 도 함께 갱신

## 작업 감사표 (단계별 진행용)

→ **[projects/20260518-gcp-ai-project-migration/migration-audit.md](../projects/20260518-gcp-ai-project-migration/migration-audit.md)**

- 8개 프로젝트 현황 표 (폴더·Billing·Tier)
- 비용 현황 (기지급 데이터 + 미확인 데이터 추출 방법)
- 리소스 인벤토리 (5/26 기준)
- Phase A~D 체크리스트 + 미해결 질문 6건

---

## 현재 상태

**2026-05-22 — 메가존 표준 가이드 PDF 수신 + 사용자 결정 3건 완료**:
- 양수/양도: 우리=양수측 (neuralarcade)
- 이전 단위: 일부 AI 프로젝트만 분리
- 실무 분담: 메가존 자문 + 우리 전담

→ 가이드의 1단계(도메인)는 비적용, 2/4단계는 부분 적용, 3단계(Billing)·SA 키 재발급·후행 청구 모니터링이 핵심. **시나리오는 `gcloud projects move`** 기반 프로젝트 단위 이동 + Billing 교체.

5/22 D-Day는 가이드 검토·체크포인트 정리·결정 명확화로 충족. 다음: 양수측 조직 결정 + 대상 프로젝트 식별이 실행 게이트. **5/31 내 클로즈** 목표.

## 다음 단계

### Phase 0 — 가이드 검토·결정 (✅ 5/22 완료)

- [x] 메가존 가이드 PDF 검토 + 체크포인트 정리
- [x] **사용자 결정 ①**: 양수/양도 방향 — 우리=양수측 확정
- [x] **사용자 결정 ②**: 이전 단위 — 일부 AI 프로젝트만 분리 확정
- [x] **사용자 결정 ③**: 양도측 실무 분담 — 메가존 자문 + 우리 전담 확정
- [x] 결정에 따른 가이드 적용 범위 조정 (1단계 비적용 / 2·4단계 부분 / 3단계·SA 키·후행 청구 핵심)

### Phase 1 — 양수측 조직·대상 프로젝트 식별 (5/23~5/26)

**[양수측 조직 결정 — 우리]**

- [ ] **신규 양수 조직 결정**: neuralarcade.ai Workspace 기반 GCP 조직 (가설) — 이미 존재 / 신설 여부 확인
- [ ] 신규 조직의 **Org ID** 확보, 사용자(본인) Org Admin 권한 보유 확인
- [ ] **신규 Billing Account** 생성 또는 기존 확인 (양수 법인 명의)
- [ ] `gcloud projects move` 가능 여부 사전 점검 (양 조직 IAM 사전 조건 + Cloud Identity 도메인 정책)

**[대상 AI 프로젝트 식별 — 메가존 협업 또는 자체]**

- [x] dlt-partners.com 조직 내 **GCP 프로젝트 전체 목록** 추출 (메가존 측 정리 요청 또는 우리 권한으로 `gcloud projects list --organization=...`)
- [x] **마이그레이션 대상 AI 프로젝트 선정** (5/25 확정 — 8개)
- [x] 각 프로젝트별 **현행 Billing Account** 매핑 — 5개 `billingAccounts/016568-056D75-165D6B` 연결, 3개 Billing OFF (gen-lang-client-0627053898, automation-466602, gen-lang-client-0605251657)
- [x] 각 프로젝트별 **리소스 인벤토리** — Cloud Asset Inventory 5/26 스냅샷 완료
- [x] 각 프로젝트별 **서비스 계정·키 인벤토리** — SA 키 9개(ai-project-454009/ai-rule-auto-gen-test-hshan/automation-466602 각 3개), SA 6개
- [x] 각 프로젝트별 **Gemini API key 인벤토리** — API key 총 8개. gen-lang-client-0403158203 가 3개로 분산, 나머지 gen-lang-client-* 4개는 각 1개, ai-rule-auto-gen-test-hshan 2개, ai-project-454009 1개
- [ ] **외부 시스템 종속성**: 앱·서버·외부 시스템에서 본 프로젝트 SA 키·API key 사용처 — ⏳ 사용자 결정 필요 (직접 추적 vs DLT·메가존 협업)

### Phase 2 — 사전 정합 (5/26~5/28)

- [ ] **메가존 자문 요청 발신**: 대상 프로젝트 목록 + `gcloud projects move` 실행 가능성 + 양수측 조직 권한 사전 조건 + 헬로우봇 본진 프로젝트 영향 없음 확인
- [ ] **양수측 Essential Contacts 명단** 작성 (Billing·Security·Technical·Legal)
- [ ] **gcp-gemini-cost-mitigation 정합 점검**: 본 이전 대상이 비용 이슈 프로젝트와 겹치는지 + 정산 시점 정밀 기록 방식 합의

### Phase 3 — 실행 (5/28~5/30)

**[3-1] 프로젝트 이동** (가이드 외 절차)

- [ ] 사전: 양수측 조직에 충분한 quota 확인 + 대상 프로젝트의 미해결 청구서·결제 잔액 정산
- [ ] `gcloud beta projects move {PROJECT_ID} --organization={NEW_ORG_ID}` (또는 folder)
- [ ] 이동 직후 IAM·메타데이터 정상성 확인 (`gcloud projects get-iam-policy`)

**[3-2] Billing 교체** (가이드 3단계 핵심)

- [ ] 대상 프로젝트의 Billing Account 를 **신규 양수 법인 명의 계정**으로 변경
- [ ] ⚠ **Billing 변경 시각 정확히 기록** (정산 증빙) — 본 TODO 진행 로그 + gcp-gemini-cost-mitigation status.md 양쪽

**[3-3] IAM·SA 키·연락처 갱신** (가이드 2·4단계 부분 적용)

- [ ] 대상 프로젝트 IAM: 이전 법인 관계자 직접·상속 권한 제거, 양수측 운영자 권한 부여
- [ ] **SA 키 재발급**: 신규 키 발급 → 외부 시스템 갱신 → 구 키 폐기 (롤백 가능 기간 1주일 유지)
- [ ] Essential Contacts 카테고리별 양수측 수신자로 변경
- [ ] Google Support Case 기본 연락처·수신 이메일 양수측 실무자로 변경

### Phase 4 — Post-Transfer 검증·보안 (5/30~5/31)

- [ ] **상속 권한 전수 검증**: 이동 후 신규 조직/폴더 위치에서 상속되는 권한이 적절한지 (`gcloud projects get-iam-policy` + 신규 조직 IAM)
- [ ] **신규 조직 Org Policy** 가 대상 프로젝트에 적합한지 검토 (gcp-gemini-cost-mitigation 트랙 3 API_RESTR 가이드와 통합)
- [ ] **서비스 동작 검증**: 외부 연동 시스템에서 SA 키 갱신 후 정상 호출 확인
- [ ] **Premium Support 등 지원 약정 승계**: Google 영업 담당자와 별도 확인 (해당 시)

### Phase 5 — 후행 청구 모니터링 (5/31~ / 4~8주 지속)

- [ ] 구 Billing Account (양도측) 즉시 폐기 금지 → 다음 청구 사이클 종료 + 최종 청구서까지 보존
- [ ] 후행 청구 발생 시 정산 처리 → 정산 완료 후 구 Billing Account 정리
- [ ] gcp-gemini-cost-mitigation status.md 에 이전 시점 기준 비용 분담 기록

## 진행 로그

- 2026-05-18 — TODO 등록. GCP 계약 5/18 완료 후속. dlt-partners.com 조직 일부 AI 프로젝트 마이그레이션 필요. 대상·방식·일정 미파악
- 2026-05-18 — **사용자 마감 지정**: 2026-05-22 (금) 완료 목표. 4영업일 압축 일정
- 2026-05-18 — 파트너사 김종현 대표님께 관련 요청사항 전달 완료 → 회신 대기
- 2026-05-22 — **메가존소프트로부터 표준 절차 가이드 PDF 수신** (`Box Sync/[사용중] Neural Arcade/업무/PMI/GCP - 메가존소프트/[뉴럴아케이드] GCP 운영권·관리권 및 결제책임 이전 가이드_메가존소프트.pdf`). 가이드 검토 + 체크포인트 정리 완료 — 핵심: 조직 ID 유지 + 운영권·관리권·결제책임 양도→양수의 4단계 절차 (도메인 → 권한 → Billing → 표시정보) + Post-Transfer 보안 검토 + 후행 청구 모니터링
- 2026-05-22 — **사용자 결정 3건 확정**: ① 우리=양수측 (neuralarcade) ② 일부 AI 프로젝트만 분리 ③ 메가존 자문 + 우리 전담. 결정 결과 가이드의 1단계(도메인) 비적용 + 2·4단계 부분 적용 + 3단계 Billing·SA 키 재발급·후행 청구 모니터링이 핵심. 시나리오는 `gcloud projects move` 기반. 5/22 D-Day는 정리·결정으로 충족, **실제 실행 5/31 클로즈** 목표. 다음 게이트: ① 양수측 신규 조직 결정 (neuralarcade.ai 기반 가설) ② 대상 AI 프로젝트 식별 (메가존 협업 또는 자체)
- 2026-05-25 — **작년 org-to-org 마이그레이션 체크리스트 기준 진행 상황 확인**: 1번(권한 부여) 완료, 2번(대상 프로젝트 리스트) 완료, 3번(리소스 파악) 미진행. 대상 8개 프로젝트 ID 확정 — `ai-project-454009`, `gen-lang-client-0627053898`, `ai-rule-auto-gen-test-hshan`, `automation-466602`, `gen-lang-client-0465592155`, `gen-lang-client-0605251657`, `gen-lang-client-0170471706`, `gen-lang-client-0403158203`. 관찰: gen-lang-client-* 5개는 Google AI Studio 에서 Gemini API 키 발급 시 자동 생성된 프로젝트 (= 5명의 사용자가 각자 키 발급). ai-rule-auto-gen-test-hshan 은 이상비용 발생 프로젝트(gcp-gemini-cost-mitigation 정합). 리소스 파악 방법: Cloud Asset Inventory(`gcloud asset`) 1순위 + Service Usage API + 빌링 BQ 데이터 교차 검증 + 서비스별 list 보조. 다음: 8개 프로젝트에 cloudasset.googleapis.com 활성화 후 자동 스크립트로 일괄 스냅샷 추출
- 2026-05-26 — **인벤토리 스크립트 실행 완료** (`Box Sync/[사용중] Neural Arcade/업무/PMI/GCP - 메가존소프트/GCP Migration/2025.02.04 띵플 > DLT 마이그레이션/GCP Migration DLT to Neural/inventory-20260526/_summary.txt`). 4그룹 분류: A.본격운영(ai-project-454009 — VPC default 자원 추정), B.이상비용·테스트(ai-rule-auto-gen-test-hshan), C.자동화·결제차단(automation-466602 — Billing OFF), D.Gemini API key 보관(gen-lang-client-* 5개). 핵심 숫자: API key 8개·SA 키 9개·Org Policy 흔적 3개(이전 시 사라짐, 재적용 필요)·Billing OFF 3개(폐기 검토 대상). Tier 분류 잠정: Tier1=gen-lang-client 5개 → Tier2=ai-rule-auto-gen-test-hshan → Tier3=automation-466602(폐기 검토) → Tier4=ai-project-454009. 사용자 결정 4건 대기: ① API key 사용처 식별 방식 ② Billing OFF 3개 이전/폐기 ③ ai-project-454009 VPC 실태 ④ SA 키 9개 재발급 정책
- 2026-05-26 — **사용자 결정 4건 확정**: ① 사용처 식별 = 자체 추적 + 기존 사용자 문의 병행, 비용 발생 키 우선 직접 추적 ② Billing OFF 3개 = 일괄 이전 (폐기 없음) ③ ai-project-454009 VPC = GCE/Cloud Run/Functions 인스턴스 검증으로 default 잔여물 여부 확인 ④ SA 키 9개 = 재발급 없이 그대로 유지 (메가존 가이드 보안 권장과 다름 → 이전 직후 IAM 권한 회수로 보완). 결정 결과 Tier 3(automation-466602) 폐기 옵션 제거, 8개 전수 이전으로 시나리오 단순화. 다음 액션: A) ai-project-454009 VPC 검증 명령 실행 B) 비용 발생 키 우선 사용처 추적 C) DLT 측 사용자 문의 발신 — 5개 gen-lang-client 발급자·API key 사용처
- 2026-05-26 — **ai-project-454009 VPC 검증 + 정밀 인벤토리 완료**. compute 워크로드 0개 확정 (GCE/Cloud Run/Functions/SQL/App Engine 모두 비어있음), VPC 자원 = default 잔여물 100%. 그러나 **방치 프로젝트가 아닌 데이터·AI 호출 전용 프로젝트**로 판명: Dataform Repository 1 + Dataplex EntryGroup 1 + SA `sa-ai-vertex-ai` (roles/aiplatform.user) + USER_MANAGED SA 키 1개 (2025-03-21 발급, 14개월째 사용 중) + Gemini API key 1개 + AlertPolicy/Dashboard 운영 모니터링 활성. 추정 용도: 외부 시스템에서 SA 키/API key 로 Vertex AI·Gemini API 호출 + Dataform 으로 BQ 파이프라인 운영. 이전 시 영향: ① Dataform 대상 BQ 가 cross-project 면 IAM 끊김 위험 ② AlertPolicy NotificationChannel 수신처가 양도측이면 알림 끊김. 다음: Audit Log 로 SA 키 호출 IP/User-Agent 추적 → 사용처 즉시 식별
- 2026-05-26 — **ai-project-454009 = 좀비 프로젝트 확정**. 검증 결과: ① SA `sa-ai-vertex-ai` 90일 호출 0건 ② Vertex AI / Gemini API 90일 호출 0건 ③ Dataform Repository 위치 us-central1 (`37631e2c-1593-40f0-8813-a13edbb318e8`) 확인했으나 콘솔에서 빈 Repository 확정 (워크스페이스·SQL 파일 없음) ④ Slack `#chatops_ai_monitoring` 채널은 살아있지만 호출이 없어 알림 fire 안 됨. → 누군가 처음 Dataform 켜보고 방치한 흔적. **이전은 8개 전수 이전 결정대로 그대로 진행, 단 ai-project-454009 만 후속 액션 별도**: 이전 후 1~3개월 모니터링 → 호출 0 유지 시 SA 키 2개 + API key 1개 + Dataform Repository + 프로젝트 자체 폐기 검토. Slack 채널 갱신 불요 (어차피 fire 안 됨). 이 트랙 닫음. 다음: ai-rule-auto-gen-test-hshan (4/29 이상비용 발생 프로젝트) 동일 추적 — audit log 풍성할 것이므로 사용처 식별 훨씬 빠를 것
- 2026-05-26 — **실사용자 조사 결과 수신 → 우선순위 전면 재정렬**. 8개 중 6개의 실 용도 식별: gen-lang-client-0403158203=hellobot-llm-prod(운영 배포 · API key 3개 = 헬로우봇 운영 LLM 호출), gen-lang-client-0170471706=hellobot-llm-dev, gen-lang-client-0605251657=compatibility-api(궁합책 미배포), gen-lang-client-0465592155=compatibility-ai(궁합책 미배포), ai-rule-auto-gen-test-hshan=본문 제작기(미사용), ai-project-454009=과거 개발자용(좀비 확정). 미상 2개: gen-lang-client-0627053898, automation-466602. 좀비 가설이 흔들림 — **8개 중 4개가 실 운영 또는 운영 준비**. 새 Tier: T1 운영(prod) / T2 개발(dev) / T3 운영 준비(궁합책 2개) / T4 가드레일(hshan) / T5 좀비 후보(나머지 3개). 4 Phase 이전 순서 확립: 좀비→미배포→개발→운영. 사용자 결정 추가 2건: ⑤ hellobot-llm-prod = 이전만 + 즉시 모니터링 ⑥ compatibility 분리 이유 = 담당자 문의 후 결정. 다음 즉시 액션: A) T5 좀비 후보 3개 + ai-rule-auto-gen-test-hshan 90일 비용 0 검증 (빌링 BQ 쿼리) B) hellobot-llm-prod API key 3개 사용처 우리 리포에서 grep 추적 C) compatibility 분리 이유 담당자 문의
- 2026-05-26 — **트랙 2(prod API key 사용처) 방식 변경**: 워크스페이스 grep 대신 담당자 문의로 (사용자 결정 ① 사용자 문의 병행 방식과 일관). **트랙 1(90일 비용 0 검증)** 인벤토리 파일(`/Users/taenyon/Development/neuralarcade/pmi-dlt-partners-to-neural-arcade/gcp/inventory-20260526/_summary.txt`) 분석 결과: **Billing OFF 3개(gen-lang-client-0627053898, gen-lang-client-0605251657, automation-466602) = 신규 비용 90일 0 확정** (Billing 비활성 시 API 호출 자체 차단). 나머지 2개(ai-project-454009, ai-rule-auto-gen-test-hshan)는 Billing ON 이라 인벤토리 파일만으론 불가 → GCP Console Billing Reports 1회 접속(https://console.cloud.google.com/billing/016568-056D75-165D6B/reports)으로 5분 안에 확정 가능. 다음: 콘솔 빌링 리포트 확인 → 트랙 1 닫고 Phase A 이전 실행 게이트 진입
- 2026-05-27 — **🔴 좀비 가설 완전 폐기 — ai-project-454009 는 활성 운영 자산**. 빌링 리포트(5/1~5/27 27일, `~/Downloads/DLTpartners_보고서, 2026-05-01 — 2026-05-27.csv`) 결과: 4,911,749원 (월 환산 약 545만원), 100% Gemini API. SKU 분포: Gemini 3 Flash input 31억토큰(48%) + output 2.4억토큰(22%) + cached 61억토큰(9%) + Gemini 2.5 Flash output 1.65억토큰(12%) + input 8.5억토큰(8%). 총 100억 토큰. **Audit log 가 0건이었던 이유 = Gemini API Data Access Log 기본 OFF** (우리 audit 검색이 잘못된 게 아님, 정상이지만 데이터 로깅이 안 됨). 사용자 조사 "과거 개발용 추정"과 실제 월 545만원 호출이 모순 = **담당자가 인지 못하는 운영 의존성**이 어딘가 있음. 누군가 과거에 만든 API key 가 어딘가 운영 시스템에 박혀 있는 상태. 이전 시 깨지면 어디서 깨지는지 알 수 없음 → 사용처 식별이 이전 강행 전 무조건 선행. Tier 재분류: T5 좀비 → T1 운영 (hellobot-llm-prod 동급). Phase A 에서 제거 → Phase D 운영으로 격상. 사용자 결정 ④(SA 키 그대로 유지) 결정은 ai-project-454009 의 경우 오히려 정당화됨 (실 사용 중이므로 폐기 X). 다음 즉시 액션: ① ai-project-454009 의 API key 1개 restrictions 확인 (도메인/IP/API 제한이 사용처 단서) ② 워크스페이스 grep 으로 ai-project-454009 / GEMINI_API_KEY 패턴 추적 ③ ai-rule-auto-gen-test-hshan 빌링 0 확인 → 4/29 이상비용 후 가드레일 효과 검증됨
- 2026-05-27 — **🎯 ai-project-454009 사용처 식별 완료 — hellobot-studio-web AI 텍스트 생성 모듈**. 워크스페이스 grep 결과 `contentGenGeminiApiKey: 'AIzaSyCQb-591loYJNBH8...'` 가 `hellobot-studio-web/src/environments/{environment.ts, environment.prod.ts, ja/environment.prod.ts}` 3개 파일에 하드코딩. 사용 모듈: `hellobot-studio-web/src/app/modules/ai-txt-gen/` (AI 글짓기 기능). 월 545만원 = 스튜디오 챗봇 빌더 사용자들이 AI 텍스트 생성 기능 호출량. 이전 시 영향 평가: 키는 사용자 결정 ④대로 그대로 따라가므로 호출 단절 위험 매우 낮음, Angular 빌드 재배포 불요. ⚠ **부수 발견: 보안 이슈 2건 — Gemini API key + OpenAI API key (`backOfficeApiKey: 'sk-W3V4iu...'`) 가 Angular environment 에 하드코딩되어 클라이언트 번들에 노출**. 4/29 이상비용 사태와 동일 패턴 재발 위험. TODO-018 이전 작업과 분리해서 별도 보안 강화 TODO 로 spin off (spawn_task chip 등록 완료, 사용자가 별도 세션으로 시작 가능). 대기: API key restrictions 명령 결과 (도메인 잠금 여부)
- 2026-05-27 — **빌링 CSV 3개(4월/5월/90일) 수신 → 비용 현황 전수 업데이트** (`migration-audit.md` 반영). 5개 프로젝트에 청구 발생, 3개 Billing OFF 확정. 정정 2건: ① ai-rule-auto-gen-test-hshan 5월 = ₩755,685 (기존 "~₩20 baseline" 판단 오류 — 가드레일 완전 작동 아님, 이전 시 재적용 우선순위 상향) ② hellobot-llm-prod 5월 = ₩120,864 (4월 ₩1,527 대비 79배 급증 — 본격 트래픽 유입). 신규 발견: compatibility-ai 5월 ₩0 (4월 ₩2,147 후 중단), hellobot-llm-dev 5월 ₩411 (4월 ₩0 후 첫 사용). 90일 합계: ai-project-454009 ₩20,041,559 / ai-rule-auto-gen-test-hshan ₩5,966,301.
- 2026-05-27 — **프로젝트 현황 감사표 작성** (`projects/20260518-gcp-ai-project-migration/migration-audit.md`). 4월 빌링 CSV 분석으로 신규 발견: gen-lang-client-0465592155(compatibility-ai) 4월 ₩2,148 실사용 확인 (기존 "0 추정" 정정 필요), gen-lang-client-0403158203(hellobot-llm-prod) 4월 ₩1,527, gen-lang-client-0170471706(hellobot-llm-dev) 4월 ₩0. 계층 구조 확인: 비용 발생 4개 프로젝트는 모두 dlt-partners.com 루트 레벨, Between 폴더 하위 없음 확인. 미확인 데이터: 3개 프로젝트 5월 비용 + 전체 90일 비용 (콘솔 빌링 리포트 또는 BQ 필요). Billing OFF 4개 프로젝트 폴더 위치 (gcloud reauth 필요).
- 2026-05-27 — **API key restrictions 결과 확인 + ai-project-454009 트랙 종료**. 현재 restrictions: `apiTargets: generativelanguage.googleapis.com` 만 있음 (Gemini 만 허용). 도메인 제한·IP 제한 없음 = 키 탈취 시 무제한 Gemini 호출 가능 구조 (4/29 사태와 동일 패턴). 사용자 결정 ⑦: **도메인 제한 추가는 이전 후 양수 조직에서 처리** — 이전 자체 단순화 우선, 5월 한 달 무사했으니 며칠 더 견디는 판단. ai-project-454009 트랙 최종 종료. **다음 큰 게이트**: Phase A 좀비 3개 이전 실행 전 ① 양수측 신규 GCP 조직 결정·Org ID 확보 ② 신규 Billing Account 생성·연결 ③ `gcloud projects move` 가능 여부 사전 점검 (Phase 1 미해결 항목). 트랙 3 compatibility 분리 이유 담당자 문의는 병행 가능
- 2026-05-27 — **⚠ 측정 오류 정정: ai-rule-auto-gen-test-hshan 비용 판정**. TODO-017/cost-mitigation 프로젝트와 대조 결과, "90일 비용 0" 판정은 오류. 원인: 본 TODO 가 본 빌링 리포트가 **5/1~5/27 기간** 한정이라 **4/29 이상비용 사건(₩5M 단일)이 직전에 발생해 누락**된 것. TODO-017 데이터 (사용자 콘솔 직접 추출): 4/22~5/21 30일 = ₩5,924,383 (≈$4,455), 4/29 단일 ₩5M (84%), 3/24~4/21 baseline ₩26,592 (≈$20). 5/1~5/27 baseline 회귀 = 가드레일 효과 (혁수님 IP 제한 1.234.131.174/32 + 트랙 3 APP_RESTR + Org Policy). **이전 시 의미 재정정**: ① 4/29 ₩5M 청구는 양도측 부담 (후행 청구 4~8주 모니터링 필수) ② 가드레일 재적용 "권장" → "필수" 격상 — Org Policy 1개 + IP 제한 + APP_RESTR 모두 양수 조직에서 검증·재적용 ③ TODO-018 과 cost-mitigation 프로젝트 정합: 이전 전 가드레일 효과 정상 유지 확인 → 이전 직후 양수에서 동일 효과 검증 → 이전 후 1주 baseline 정상 유지 확인
