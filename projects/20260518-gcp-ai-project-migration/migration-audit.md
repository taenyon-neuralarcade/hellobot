# GCP AI 프로젝트 마이그레이션 — 현황 감사표

**기준일**: 2026-05-27  
**작업**: dlt-partners.com 조직 → thingsflow.kr 조직으로 이전  
**관련**: [TODO-018](../../todos/TODO-018-gcp-ai-project-migration.md)

| | 양도측 | 양수측 |
|--|--------|--------|
| **Org Name** | dlt-partners.com | thingsflow.kr |
| **Org ID** | `739207437319` | `1004075604592` |
| **작업 계정** | taenyon@neuralarcade.ai | taenyon@neuralarcade.ai |
| **Billing** | `016568-056D75-165D6B` (유지) | `016568-056D75-165D6B` (이번 이전에서 변경 없음) |

---

## 범위 확정

- **포함**: dlt-partners.com 조직 하위 AI/자동화 프로젝트
- **제외**: `dlt-partners.com > Between` 폴더 하위, `system-gsuite` 폴더 하위
- **확인**: 4월 빌링 CSV의 계층 구조 분석 결과 — 8개 대상 프로젝트 중 Between 폴더 하위는 없음 ✅
- **대상**: 8개 프로젝트 (2026-05-25 확정)

---

## 1. 프로젝트 현황 표

| # | Project ID | GCP 표시명 | 식별된 용도 | 폴더 위치 | Billing 상태 | Tier |
|---|-----------|----------|-----------|---------|------------|------|
| 1 | `ai-project-454009` | AI-project | **hellobot-studio AI 텍스트 생성** (Angular environment 하드코딩) | dlt-partners.com 루트 | ON (`016568-056D75-165D6B`) | 🔴 T1 운영 |
| 2 | `gen-lang-client-0403158203` | hellobot-llm | **hellobot-llm-prod** (서버 운영 LLM 호출, API key 3개) | dlt-partners.com 루트 | ON (`016568-056D75-165D6B`) | 🔴 T1 운영 |
| 3 | `gen-lang-client-0170471706` | (이름 미확인) | **hellobot-llm-dev** | ⚠ gcloud 확인 필요 | ON | 🟡 T2 개발 |
| 4 | `gen-lang-client-0465592155` | compatibility-ai | **compatibility-ai** (궁합책, 미배포 · 4월 소량 사용) | dlt-partners.com 루트 | ON (`016568-056D75-165D6B`) | 🟠 T3 운영준비 |
| 5 | `gen-lang-client-0605251657` | (이름 미확인) | **compatibility-api** (궁합책, 미배포) | ⚠ gcloud 확인 필요 | **OFF** | 🟠 T3 운영준비 |
| 6 | `ai-rule-auto-gen-test-hshan` | ai-rule-auto-gen-test-hshan | **본문 제작기** (현재 미사용 · 4/29 이상비용 이력) | dlt-partners.com 루트 | ON (`016568-056D75-165D6B`) | ⚪ T5 좀비 |
| 7 | `gen-lang-client-0627053898` | (이름 미확인) | 미상 | ⚠ gcloud 확인 필요 | **OFF** | ⚪ T5 좀비 |
| 8 | `automation-466602` | (이름 미확인) | 미상 | ⚠ gcloud 확인 필요 | **OFF** | ⚪ T5 좀비 |

---

## 2. 비용 현황

| # | Project ID | GCP 표시명 | 4월(4/1~30) | 5월(5/1~5/27) | 90일(2/1~5/31) | 비고 |
|---|-----------|----------|-----------|-------------|--------------|------|
| 1 | `ai-project-454009` | AI-project | ₩5,467,078 | ₩4,991,269 | **₩20,041,559** | 월 ~₩550만, 100% Gemini API |
| 2 | `gen-lang-client-0403158203` | hellobot-llm-prod | ₩1,527 | **₩120,864** | ₩122,391 | ⚠ 5월 79배 급증 — 서비스 본격 사용 시작 |
| 3 | `gen-lang-client-0170471706` | hellobot-llm-dev | ₩0 | ₩411 | ₩411 | 5월부터 소량 사용 시작 |
| 4 | `gen-lang-client-0465592155` | compatibility-ai | ₩2,147 | **₩0** | ₩2,147 | 4월만 사용, 5월 중단 — 담당자 확인 필요 |
| 5 | `gen-lang-client-0605251657` | — | ₩0 | ₩0 | ₩0 | Billing OFF · 확정 |
| 6 | `ai-rule-auto-gen-test-hshan` | ai-rule-auto-gen-test-hshan | ₩5,188,461 | **₩755,685** | ₩5,966,301 | ⚠ 아래 주석 참고 |
| 7 | `gen-lang-client-0627053898` | — | ₩0 | ₩0 | ₩0 | Billing OFF · 확정 |
| 8 | `automation-466602` | — | ₩0 | ₩0 | ₩0 | Billing OFF · 확정 |

> **출처**: `DLTpartners_보고서-4월 2026-04-01 — 2026-04-30.csv` / `DLTpartners_보고서-5월 2026-05-01 — 2026-05-27.csv` / `DLTpartners_보고서-90d 2026-02-01 — 2026-05-31.csv`  
> **90일 기간**: 실제 2/1~5/31 (약 4개월). 5개 프로젝트만 청구 발생, 나머지 3개 ₩0 확정.

### 주요 발견 및 정정

**① ai-rule-auto-gen-test-hshan 5월 ₩755,685 — 기존 "baseline 회귀 ~₩20" 판단 정정 필요**

- 기존 TODO-018 판단: "5/1 이후 baseline 정상 (월 ₩20 수준), 가드레일 효과 확인"
- 실제 5월 데이터: **₩755,685** (전혀 다름)
- 4/29 이상비용 ₩5M 외에도 5월에 추가 비용 발생 중
- 가드레일(IP 제한 + APP_RESTR + Org Policy)이 완전히 작동했다고 보기 어려움
- **이전 시 가드레일 재적용 우선순위를 더 높게 설정** — Phase A 이전 직후 즉시 검증 필수

**② hellobot-llm-prod 4월→5월 79배 급증 (₩1,527 → ₩120,864)**

- 4월까지 거의 미사용 → 5월부터 실 서비스 트래픽 유입 본격화
- 90일 합계 ₩122,391 (대부분 5월에 집중)
- Phase D 이전 시 영향도 주의 (운영 중인 상태에서 이전)
```

---

## 3. 리소스 인벤토리 (5/26 기준)

> 원본: `Box Sync/.../GCP Migration/inventory-20260526/_summary.txt`

### `ai-project-454009` — T1 운영 ⚠ (월 ~₩545만)
| 리소스 유형 | 상세 |
|-----------|------|
| **API key** | 1개 · 제한: `generativelanguage.googleapis.com`만 허용 · 도메인/IP 제한 없음 ⚠ |
| **Service Account** | 2개 · `sa-ai-vertex-ai` (roles/aiplatform.user) · USER_MANAGED 키 1개 (2025-03-21 발급) |
| **Dataform Repository** | 1개 (us-central1 · 빈 상태, 방치 흔적) |
| **Dataplex EntryGroup** | 1개 |
| **Monitoring** | AlertPolicy · Dashboard (Slack `#chatops_ai_monitoring` 연결, 호출 없어 silent) |
| **VPC** | default 잔여물 (44 Routes · 43 Subnets · 4 FW Rules) · 실 워크로드 없음 확인 |
| **활성 APIs** | 33개 |
| **사용처** | `hellobot-studio-web/src/environments/environment{,.prod,ja/environment.prod}.ts` 에 `contentGenGeminiApiKey` 하드코딩 |

### `gen-lang-client-0403158203` — T1 운영 (hellobot-llm-prod)
| 리소스 유형 | 상세 |
|-----------|------|
| **API key** | 3개 (hellobot-server 환경별 분리 추정) |
| **Service Account** | 없음 |
| **Billing** | ON · 4월 ₩1,527 (소량) |

### `gen-lang-client-0170471706` — T2 개발 (hellobot-llm-dev)
| 리소스 유형 | 상세 |
|-----------|------|
| **API key** | 1개 |
| **Service Account** | 없음 |
| **Billing** | ON · 4월 ₩0 (미사용 또는 최근 활성화) |

### `gen-lang-client-0465592155` — T3 운영준비 (compatibility-ai)
| 리소스 유형 | 상세 |
|-----------|------|
| **API key** | 1개 |
| **Service Account** | 없음 |
| **Billing** | ON · 4월 ₩2,148 ⚠ (미배포인데 사용 중 — 확인 필요) |

### `gen-lang-client-0605251657` — T3 운영준비 (compatibility-api)
| 리소스 유형 | 상세 |
|-----------|------|
| **API key** | 1개 |
| **Service Account** | 없음 |
| **Billing** | OFF → ₩0 확정 |

### `ai-rule-auto-gen-test-hshan` — T5 좀비 (본문 제작기)
| 리소스 유형 | 상세 |
|-----------|------|
| **API key** | 2개 |
| **Service Account** | `sa-ai-content-generator` (roles/owner) · `sa-gemini-test` (roles/owner) + USER_MANAGED 키 3개 |
| **IAM 사용자** | `su@dlt-partners.com` (roles/owner) ⚠ **이전 후 제거 필수** |
| **Org Policy** | `constraints/iam.managed.disableServiceAccountKeyCreation` — `enforce: false` (상위 DLT org 정책 오버라이드용) · thingsflow.kr 이동 후 상위 정책 없으므로 **재적용 불필요** |
| **활성 APIs** | 26개 |
| **가드레일** | API key에 IP 제한 (1.234.131.174/32) + APP_RESTR 설정 · 프로젝트와 함께 이동 ✅ |

### `gen-lang-client-0627053898` — T5 좀비
| 리소스 유형 | 상세 |
|-----------|------|
| **API key** | 1개 |
| **IAM** | 비어있음 (사용자/SA 없음) |
| **Org Policy** | 없음 |
| **Billing** | OFF → ₩0 확정 |

### `automation-466602` — T5 좀비
| 리소스 유형 | 상세 |
|-----------|------|
| **Service Account** | `googleplayaccess@automation-466602` (roles/androidmanagement.user + roles/financialservices.admin) + USER_MANAGED 키 3개 |
| **IAM 사용자** | 없음 |
| **Org Policy** | `constraints/iam.disableServiceAccountKeyCreation` (enforce: true, v1) · `constraints/iam.managed.disableServiceAccountApiKeyCreation` (v2 managed) ⚠ **이전 후 재적용 필수** |
| **활성 APIs** | 23개 (apikeys API 비활성) |
| **Billing** | OFF → ₩0 확정 |

---

## 4. 이전 Phase 체크리스트

### 선행 조건 (2026-05-27 기준)

- [x] **양수측 GCP 조직 Org ID 확보** — thingsflow.kr · `1004075604592`
- [x] **Billing 전략 결정** — 이번 이전에서 Billing 변경 없음. `016568-056D75-165D6B` 유지. 분리는 TODO-007 흐름에서 별도 처리
- [x] **`gcloud projects move` 사전 점검** — 양쪽 org 권한 확인 완료
- [x] **gcloud 계정 전환** — `taenyon@neuralarcade.ai` 활성
- [x] **타겟 org 구조 확인** — thingsflow.kr에 `system-gsuite` 폴더만 존재. 8개 AI 프로젝트는 **org 루트에 바로 이동**
- [x] **타겟 org org policy 확인** — 없음 (충돌 없음)
- [x] **Phase A 3개 프로젝트 IAM 확인** — 완료 (아래 Phase A 참조)
- [x] **Org 간 이동 허용 정책 설정** — 2026-05-27 (아래 이력 참조)

### Org 간 이동 허용 정책 설정 이력 (2026-05-27)

A-1 최초 실행 시 두 org policy 충돌로 `FAILED_PRECONDITION` 오류 발생. 원인 및 해결:

| 항목 | 내용 |
|------|------|
| **오류** | `constraints/resourcemanager.allowedExportDestinations` (소스 org) + `constraints/resourcemanager.allowedImportSources` (타겟 org) 모두 기본 deny 상태 |
| **원인** | 두 정책이 값 없이 설정만 된 상태 = 모든 조직 간 이동 차단 |
| **해결** | 소스 org에 타겟 허용값 추가, 타겟 org에 소스 허용값 추가 |
| **적용 범위** | 이후 A-2~D-2 전 Phase에 동일 적용 (재설정 불필요) |

```bash
# 소스 org (dlt-partners.com / 739207437319)
# → thingsflow.kr으로 내보내기 허용
gcloud resource-manager org-policies set-policy \
  --organization=739207437319 /dev/stdin << 'EOF'
constraint: constraints/resourcemanager.allowedExportDestinations
listPolicy:
  allowedValues:
  - under:organizations/1004075604592
EOF

# 타겟 org (thingsflow.kr / 1004075604592)
# → dlt-partners.com에서 가져오기 허용
gcloud resource-manager org-policies set-policy \
  --organization=1004075604592 /dev/stdin << 'EOF'
constraint: constraints/resourcemanager.allowedImportSources
listPolicy:
  allowedValues:
  - under:organizations/739207437319
EOF
```

> ✅ **2026-05-27 정리 완료**: 모든 Phase 완료 후 두 정책 삭제. 기본 deny 상태로 복구 확인.

---

### Phase A — 좀비 3개

**순서**: `gen-lang-client-0627053898` → `automation-466602` → `ai-rule-auto-gen-test-hshan`

| # | 프로젝트 | IAM 정리 | Org Policy 재적용 | 완료 |
|---|---------|---------|----------------|------|
| A-1 | `gen-lang-client-0627053898` | 없음 (IAM 비어있음) | 없음 | [x] 2026-05-27 |
| A-2 | `automation-466602` | 없음 (SA만 존재) | `iam.disableServiceAccountKeyCreation` 재적용 | [x] 2026-05-27 |
| A-3 | `ai-rule-auto-gen-test-hshan` | *(IAM 정리는 별도 진행)* | 불필요 (enforce:false 오버라이드였음) · API key 제한 프로젝트와 함께 이동 | [x] 2026-05-27 |

#### A-1. gen-lang-client-0627053898 ✅ 2026-05-27 완료
> **사전 장애**: `allowedExportDestinations` / `allowedImportSources` org policy 충돌 → 양쪽 org에 `under:organizations/{상대방_org_id}` 허용값 추가 후 해결 (정책 전파 ~60초 소요)

```bash
# 소스 org export 허용 (1회 설정, 이후 Phase 모두 적용)
gcloud resource-manager org-policies set-policy --organization=739207437319 /dev/stdin << 'EOF'
constraint: constraints/resourcemanager.allowedExportDestinations
listPolicy:
  allowedValues:
  - under:organizations/1004075604592
EOF

# 타겟 org import 허용 (1회 설정)
gcloud resource-manager org-policies set-policy --organization=1004075604592 /dev/stdin << 'EOF'
constraint: constraints/resourcemanager.allowedImportSources
listPolicy:
  allowedValues:
  - under:organizations/739207437319
EOF

# 이동 (--quiet 로 확인 프롬프트 자동 승인)
gcloud beta projects move gen-lang-client-0627053898 --organization=1004075604592 --quiet
# 결과: parent.id=1004075604592 / type=organization ✅
```

#### A-2. automation-466602 ✅ 2026-05-27 완료

```bash
# 이동
gcloud beta projects move automation-466602 --organization=1004075604592 --quiet
# 결과: parent.id=1004075604592 / type=organization ✅

# org policy API 활성화 (이동 전 비활성 상태였음)
gcloud services enable orgpolicy.googleapis.com --project=automation-466602

# v1 policy 재적용
gcloud resource-manager org-policies enable-enforce \
  constraints/iam.disableServiceAccountKeyCreation --project=automation-466602
# → booleanPolicy.enforced: true ✅

# v2 managed constraint 재적용 (project number: 817480568091)
gcloud org-policies set-policy /dev/stdin --project=automation-466602 << 'EOF'
name: projects/817480568091/policies/iam.managed.disableServiceAccountApiKeyCreation
spec:
  rules:
  - enforce: true
EOF
# → ENFORCED: True ✅
```

#### A-3. ai-rule-auto-gen-test-hshan

**리소스 이동 동작 (2026-05-27 사전 확인)**

`gcloud projects move`는 프로젝트 메타데이터(org 소속)만 변경. 프로젝트 내 모든 리소스는 그대로 따라감.

| 리소스 | 이동 여부 | 비고 |
|--------|---------|------|
| SA `sa-gemini-test` + 키 2개 | ✅ 그대로 이동 | 별도 작업 불필요 |
| SA `sa-ai-content-generator` + 키 1개 | ✅ 그대로 이동 | 별도 작업 불필요 |
| API key 2개 (IP 제한 1.234.131.174/32 포함) | ✅ 그대로 이동 | 가드레일 보존 ✅ |
| 활성 API 26개 | ✅ 그대로 이동 | |
| Org Policy `iam.managed.disableServiceAccountKeyCreation` (enforce:false) | ⚠️ 정책 잔류하나 무의미 | DLT org 상위 정책 오버라이드용이었으므로 thingsflow.kr 이동 후 효과 없음. 동작 변화 없음 |
| IAM 프로젝트 레벨 바인딩 (`su@dlt-partners.com` 등) | ✅ 그대로 이동 | 직접 제거 예정 |

```bash
gcloud beta projects move ai-rule-auto-gen-test-hshan \
  --organization=1004075604592 --quiet
# 결과: parent.id=1004075604592 / type=organization ✅

# API key 가드레일 보존 확인
# Generative Language API Key → allowedIps: 1.234.131.174/32 ✅
# gemini-api-key              → allowedIps: 1.234.131.174/32 ✅
```

---

### Phase B — 미배포 궁합책 2개

> 선행 확인 (2026-05-27): compatibility-ai 4월 ₩2,147 — **궁합책 기능 개발 중 사용**으로 확인. compatibility-api — **초기 테스트 후 미사용** 확인.

| # | 프로젝트 | 특이사항 | 완료 |
|---|---------|---------|------|
| B-1 | `gen-lang-client-0465592155` | API key 1개 · 4월 ₩2,148 (개발 중 사용 확인) | [x] 2026-05-27 |
| B-2 | `gen-lang-client-0605251657` | API key 1개 · Billing OFF | [x] 2026-05-27 |

```bash
# B-1
gcloud beta projects move gen-lang-client-0465592155 --organization=1004075604592 --quiet
# 결과: parent.id=1004075604592 / type=organization ✅

# B-2
gcloud beta projects move gen-lang-client-0605251657 --organization=1004075604592 --quiet
# 결과: parent.id=1004075604592 / type=organization ✅
```

---

### Phase C — 개발 환경

| # | 프로젝트 | 특이사항 | 완료 |
|---|---------|---------|------|
| C-1 | `gen-lang-client-0170471706` | API key 1개 · 이전 후 dev LLM 호출 정상 확인 | [x] 2026-05-27 |

```bash
gcloud beta projects move gen-lang-client-0170471706 --organization=1004075604592 --quiet
# 결과: parent.id=1004075604592 / type=organization ✅
```

---

### Phase D — 운영 2개 ⚠ 트래픽 저점 시간대

| # | 프로젝트 | 특이사항 | 완료 |
|---|---------|---------|------|
| D-1 | `gen-lang-client-0403158203` | API key 1개 (base-key) · hellobot-server 운영 · 이전 후 호출량 모니터링 | [x] 2026-05-27 |
| D-2 | `ai-project-454009` | API key 1개 + SA 키 · studio-web AI 텍스트 생성 (월 ~₩550만) · 이전 후 즉시 모니터링 | [x] 2026-05-27 |

> ⚠ **기존 "API key 3개" 정정** — 2026-05-27 실제 조회 결과 1개(base-key)만 존재. 환경별 분리 추정은 오판.

```bash
# D-1
gcloud beta projects move gen-lang-client-0403158203 --organization=1004075604592 --quiet
# 결과: parent.id=1004075604592 / type=organization ✅

# D-2
gcloud beta projects move ai-project-454009 --organization=1004075604592
gcloud projects describe ai-project-454009 --format="value(parent.id,parent.type)"
# 이전 직후 studio-web AI 텍스트 생성 기능 정상 확인
```

**D-2 이전 후 후속 (별도 작업)**:
- [ ] API key HTTP 레퍼러/도메인 제한 추가 (현재 generativelanguage API만 허용, 도메인/IP 제한 없음)
- [ ] 1~3개월 모니터링 후 Dataform Repository + 미사용 리소스 정리 검토

---

## 5. 이전 공통 체크 (각 Phase 완료 시)

```bash
# 1. 이동
gcloud beta projects move {PROJECT_ID} --organization=1004075604592

# 2. 이동 확인 (1004075604592 / organization 이면 성공)
gcloud projects describe {PROJECT_ID} --format="value(parent.id,parent.type)"

# 3. IAM 잔류 계정 확인 (제거는 직접 진행)
gcloud projects get-iam-policy {PROJECT_ID} \
  --flatten="bindings[].members" \
  --filter="bindings.members:dlt-partners.com" \
  --format="table(bindings.role,bindings.members)"

# 4. (해당 프로젝트만) Org Policy 재적용
# 5. (운영 프로젝트만) 서비스 정상 확인
```

---

## 6. 미해결 질문

| # | 질문 | 관련 Phase | 상태 |
|---|-----|-----------|------|
| Q1 | 양수측 GCP 조직 Org ID | 선행 조건 | ✅ `1004075604592` (thingsflow.kr) |
| Q2 | 양수측 Billing Account | 선행 조건 | ✅ 이번 이전에서 변경 없음 (`016568-056D75-165D6B` 유지) |
| Q3 | compatibility-ai(0465592155)의 4월 ₩2,148 사용 원인 | Phase B 선행 | ⏳ 담당자 문의 중 |
| Q4 | compatibility-ai vs compatibility-api 분리 이유 | Phase B 선행 | ⏳ 담당자 문의 중 |
| Q5 | hellobot-llm-dev 5월 비용 | Phase C | ✅ ₩411 (5/1~5/27) |
| Q6 | hellobot-llm-prod 5월 비용 | Phase D | ✅ ₩120,864 (5/1~5/27, 4월 대비 79배 급증) |
