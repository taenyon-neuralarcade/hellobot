---
name: todo-018-gcp-ai-project-migration
description: GCP 마이그레이션 — dlt-partners.com 조직의 일부 AI 프로젝트를 신규 GCP 환경으로 이전
metadata:
  type: action
---

# TODO-018 GCP AI 프로젝트 마이그레이션 (dlt-partners.com 조직)

**유형**: 액션 (개발·인프라 작업) + 모니터링 (파트너사 회신 대기)
**상태**: 진행 중 — **파트너사 김종현 대표님께 요청사항 전달 완료 (5/18) · 회신 대기** / 5/22 (금) 완료 목표
**등록**: 2026-05-18
**시작**: 2026-05-18
**완료**: -
**마감**: **2026-05-22 (금)** — 사용자 지정 완료 목표
**담당**: 사용자 (총괄·외부 채널) → `/dev-infra` 위임 가능 / 파트너사 김종현 대표님 (협조)
**관련**: [[todo-005-infra-contract-monitoring]] (GCP 계약 5/18 완료) · [[todo-007-bitwin-infra-separation]] (DLT 인프라 분리 흐름) · [[todo-017-gcp-gemini-cost-anomaly]] (GCP 비용 이슈 — 함께 정리 검토 가능)

## 컨텍스트

5/18 GCP 계약 완료(TODO-005) 후속 작업. **dlt-partners.com 조직**에 속한 **일부 AI 프로젝트**를 신규 GCP 환경으로 마이그레이션 필요.

### 미파악 항목

- **대상 프로젝트 식별**: 어떤 AI 프로젝트들이 마이그레이션 대상? (전부? 일부? 기준?)
- **마이그레이션 대상 수**: 프로젝트 개수
- **마이그레이션 방식**:
  - gcloud project 이동 (organization move)
  - 리소스 export → import (BQ dataset / Cloud Storage / Vertex AI model 등)
  - 데이터 이전 + 서비스 계정 재발급
- **다운타임 허용 여부**
- **종속성**: 외부 서비스 호출 / API key / 빌링 어카운트 / IAM
- **일정·담당**: 마감 / 누가 실행 / 검증 책임자

### 관련 TODO

- **TODO-005**: GCP 계약 5/18 완료 (전제 조건)
- **TODO-007**: 비트윈 인프라 분리 — DLT 협업 흐름. PMI 일관성 확인 필요
- **TODO-017**: GCP Gemini 4/29 이상비용 — 본 마이그레이션 시 가드레일 함께 검토 권장

## 현재 상태

5/18 **파트너사 김종현 대표님께 요청사항 전달 완료** → 회신 대기. **5/22 (금) 완료 목표** — 4영업일 안에 식별 + 실행 + 검증. 외부 회신 대기 동안 우리 측 Phase 1 (대상 식별·인벤토리) 병행 가능. 본격 실행 시 프로젝트화 + `/dev-infra` 위임 권장.

## 다음 단계

### Phase 1 — 대상·범위 식별 (~5/19 화)

- [ ] dlt-partners.com 조직 GCP 프로젝트 목록 추출 (`gcloud projects list --organization=...`)
- [ ] 마이그레이션 대상 프로젝트 선정 기준·목록 확정 (사용자 의사결정)
- [ ] 각 프로젝트별 리소스 인벤토리 (BQ / GCS / Vertex AI / Functions / Run / Cloud SQL 등)
- [ ] 데이터 규모 + 외부 종속성 정리

### Phase 2 — 방식·일정 결정 (~5/20 수)

- [ ] 마이그레이션 방식 결정 (gcloud project move vs export/import vs 데이터+IAM 신규 셋업)
- [ ] 다운타임 허용 여부 + 영향 시점 결정
- [ ] 담당자 배정 (사용자 직접 / `/dev-infra` 위임 / 메가존 협업)
- [ ] 프로젝트화 결정 (`projects/YYYYMMDD-gcp-ai-migration/`)

### Phase 3 — 실행 (~5/22 금)

- [ ] 마이그레이션 실행 (Phase 2 결정대로)
- [ ] 검증 (서비스 동작 / 비용 흐름 / IAM 권한)
- [ ] TODO-007 (DLT 인프라 분리) 와 align 확인

### Phase 4 — 정리 (5/22 ~)

- [ ] 구 환경 정리 (resource cleanup / 빌링 종료)
- [ ] 재발 방지 가드레일 (TODO-017 가드레일과 통합 가능)

## 진행 로그

- 2026-05-18 — TODO 등록. GCP 계약 5/18 완료 후속. dlt-partners.com 조직 일부 AI 프로젝트 마이그레이션 필요. 대상·방식·일정 미파악
- 2026-05-18 — **사용자 마감 지정**: **2026-05-22 (금) 완료 목표**. 4영업일 압축 일정 → Phase 1~3 단계별 일정 추정 (5/19 대상 식별 / 5/20 방식 결정 / 5/22 실행·검증)
- 2026-05-18 — **파트너사 김종현 대표님께 관련 요청사항 전달 완료** → 회신 대기. 외부 회신 대기 동안 우리 측 Phase 1 (대상 식별·인벤토리) 병행 가능
