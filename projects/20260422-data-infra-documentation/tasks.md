# 과업 목록

> **프로젝트 목표**: 새 기능 투입 시 "어떤 이벤트를 남기고 어느 마트에서 조회하면 된다"는 플레이북을 작성할 수 있도록, HelloBot 데이터 인프라의 **이벤트·지표·마트**를 dbt-ready 포맷으로 카탈로그화한다.

> **2026-04-22 카탈로그 위치 변경**: 카탈로그 산출물은 워크스페이스 `planning/` 에서 [`common-data-airflow/docs/hellobot-data/catalog/`](../../common-data-airflow/docs/hellobot-data/catalog/) 로 이전됨. 본 문서의 경로 표기는 신규 위치 기준. 동기화 규칙은 `common-data-airflow/CLAUDE.md` §데이터 카탈로그 동기화 참조.

## 기획

- [ ] 주요 지표의 **오너십 확정** (어떤 팀/담당자가 해당 숫자에 책임지는지) — 지표 사전 작성 후 협의
- [ ] 주요 대시보드·알림의 **현업 쓰임새** 수집 — 마트 카탈로그 초안 기반 인터뷰 (선택)

## 서버 / iOS / Android / 웹 / 스튜디오
해당없음

## 데이터 (/dev-data)

산출물 전반의 포맷은 샘플 (`mart_user_daily_info`) 참조 — dbt-ready 구조.
실제 작업은 `docs/hellobot-data/catalog/` 하위에 신규 구축, 기존 `common-data-airflow/docs/hellobot-data/tables/`는 deprecated 처리.

### Phase 1 — 테이블 우선순위 확정 *[사용자 액션 대기]*

- [ ] `draft-hellobot-tables.md`에 중요도 마킹 (★★★ / ★★ / ★ / ✗) — 사용자 직접 작업
- [ ] 마킹 결과 바탕으로 **카탈로그화 대상 테이블 확정** (★★★/★★ 우선)
- [ ] 비표준 DAG · JP 계열 테이블의 범위 포함 여부 결정

### Phase 2 — 마트 카탈로그 (`docs/hellobot-data/catalog/mart-catalog.md` + `docs/hellobot-data/catalog/tables/`)

- [x] 포맷 샘플 1건 작성 (`mart_user_daily_info`) — 확정 포맷 기반
- [x] 샘플을 공식 `docs/hellobot-data/catalog/tables/mart/mart_user_daily_info.md`로 승격
- [x] 스코프 재정의 — `union_mart_user_key_actions` 계보 우선 ([scope-union-user-key-actions.md](../../common-data-airflow/docs/hellobot-data/catalog/scope-union-user-key-actions.md))
- [x] **P0: union_mart_user_key_actions 직접 소스 (9건)**
  - [x] `union_mart_user_key_actions` (타겟)
  - [x] `mart_user_daily_info`
  - [x] `mart_use_skill_se`
  - [x] `mart_purchase_fb`
  - [x] `mart_fixed_menu_server`
  - [x] `mart_skill_open_date_se`
  - [x] `mart_home_action_fb`
  - [x] `mart_v2_skill_funnel_fb`
  - [x] `adhoc_mart_user_rfm_info_daily`
- [ ] **P1: intermediate 요약** (union_mart_user_key_actions 체인 이해용)
- [ ] **P2: staging 요약** (이벤트 카탈로그에서 staging_key_events_* 담당)
- [ ] ★★ 추가 마트로 범위 확장 (우선순위 마킹 이후)

### Phase 3 — 이벤트 카탈로그 (`docs/hellobot-data/catalog/event-catalog.md`)

- [x] Firebase 이벤트 수집 대상 목록 (코드 스캔 범위, mart P0까지)
- [x] 서버 이벤트 수집 대상 목록 (코드 스캔 범위)
- [x] 각 이벤트의 **트리거 조건** 및 소비 마트 매핑 (P0 기준)
- [x] 수집 게이트키핑 메커니즘 (events_list 화이트리스트, 테스터 제외, env 필터, 중복 제거) 문서화
- [x] user_id_processed 계산 규칙 문서화
- [ ] 이벤트 파라미터 스키마 *[외부 DB 조회 필요 — 외부 과업]*
- [ ] 화이트리스트 전수 조회 후 코드에서 미발견 이벤트 보강 *[외부 과업]*
- [ ] 화이트리스트 업데이트 절차·담당자 확인 ([ISS-011](./issues.md)) *[외부 과업]*

### Phase 4 — 지표 사전 (`docs/hellobot-data/catalog/metric-dictionary.md`)

- [x] KPI 알림(`kpi_noti/queries.py`) 및 `lookerstudio_resources/report_kpi_metrics_daily.sql`에서 지표 정의 역추출
- [x] 핵심 지표 정의 (DAU/WAU/MAU, 결제자, ARPPU, LTV, ROAS, 리텐션 개요, RFM, CRM, AI 챗봇, 콘텐츠)
- [x] 지표별 계산식·소스 테이블·디멘션 (MetricFlow 호환 YAML 예시 포함)
- [x] 공통 상수·용어·매출 정의 2종(revenue_krw vs spent_total_amount_krw) 정리
- [ ] `report_*` 레이어 쿼리까지 스캔 확장 (report_kpi_total_skill_*, report_key_metrics_by_daily 등)
- [ ] Looker Studio 대시보드의 실제 노출 지표명 매칭 [외부]
- [ ] **지표 오너십** 기획팀 협의 후 채움 [외부]
- [ ] 지표 변경 관리 규약 합의

### Phase 5 — 플레이북 (`docs/hellobot-data/catalog/playbook.md`)

- [x] "새 기능 투입 시" 5단계 체크리스트 (지표/이벤트/로그/파이프라인/분석)
- [x] 판단 트리 전체 다이어그램
- [x] Firebase vs 서버 선택 기준
- [x] 이벤트 재사용 판단 트리
- [x] 공통 함정 9종 정리
- [x] 케이스 스터디 1건 (가상 — "신년운세 2026 섹션 추가")
- [ ] 실제 과거 기능 1건 케이스 스터디 보강 (기능 선정 후)

### Phase 6 — 아키텍처 맵 & 통합 (`docs/hellobot-data/catalog/architecture.md`)

- [x] 수집→저장→가공→활용 전체 흐름 다이어그램 (Mermaid)
- [x] 레이어·데이터셋·주요 DAG 매핑표
- [x] DAG 체인 시각화
- [x] 외부 의존 시스템 맵 (자동 수집 · 수동 · 출력 채널)
- [x] 공통 규약 (시간대, 사용자 식별, 이벤트 게이트키핑, 매출 정의, 파티션, 실패 처리)
- [x] 데이터 품질 현황 · 갭
- [x] dbt 이식 시 디렉토리/materialization 매핑
- [x] 컨벤션 레지스트리 (DAG, BigQuery 쿼리, 문서)
- [x] 현재 알려진 갭 우선순위 표

### Phase 7 — 기존 자산 정리

- [x] `common-data-airflow/docs/hellobot-data/tables/README.md` deprecated 배너 삽입
- [x] `common-data-airflow/docs/hellobot-data/tables/` 하위 57개 md 파일 deprecated 배너 일괄 삽입
- [x] `common-data-airflow/docs/hellobot-data/events_list.md` 이벤트 — 신규 [event-catalog.md](../../common-data-airflow/docs/hellobot-data/catalog/event-catalog.md) 로 이관 완료 (코드 스캔 범위)
- [ ] 리포 PR 시 신규 카탈로그 위치 안내 (PR 설명에 반영)

### Phase 10 — 카탈로그 리포 이전 (2026-04-22)

- [x] 워크스페이스 `projects/.../planning/` → 리포 `common-data-airflow/docs/hellobot-data/catalog/` 이전
- [x] `docs/hellobot-data/tables/` deprecated 배너 신규 위치(`docs/hellobot-data/catalog/`) 로 갱신
- [x] 리포 `CLAUDE.md` 에 "데이터 카탈로그 동기화" 섹션 추가 (코드 변경 시 카탈로그도 동일 PR 갱신 규칙)
- [x] 워크스페이스 `/dev-data` 에이전트 (`.claude/commands/dev-data.md`) 카탈로그 경로 갱신
- [x] 메모리 (`reference_data_infra_entry.md`) 경로 갱신
- [x] 워크스페이스 `planning/` 디렉토리 제거

### Phase 8 — 리포 레벨 기록

- [x] `common-data-airflow/docs/features/20260422-data-infra-documentation/status.md` — 결정 로그 · 포맷 규약 · 이슈 요약 · 변경 파일 목록
- [ ] (이후) 리뷰 후 `docs/hellobot-data/catalog/` 산출물 중 일부를 리포 `docs/` 로 승격 검토 — 본 프로젝트 범위 외, 후속 논의

### Phase 9 — 내비게이션 · 레시피 레이어

> **동기**: 15개 문서가 축적되어 "지금 과업에 뭘 먼저 읽어야 하는가" 가 불명확. Map → Recipe → Detail 의 3축 구조 도입.

- [x] `docs/hellobot-data/catalog/infra-map.md` 신규 작성 — 1페이지 인프라 지도 (레이어·핵심 테이블 10·이벤트 그룹·지표 도메인·DAG 체인·컨벤션)
- [x] `docs/hellobot-data/catalog/readme.md` 재작성 — task-indexed 진입점 (기존 문서 목록 → 과업별 시작 문서)
- [x] `docs/hellobot-data/catalog/recipes/feature-performance-measurement.md` 신규 — 4 카테고리 택소노미(Purchase/Content/UI/Retention) 템플릿 포함
- [x] `docs/hellobot-data/catalog/playbook.md` 상단에 기능 택소노미 섹션 추가 + recipe 링크
- [x] `docs/hellobot-data/catalog/event-catalog.md` 상단에 유스케이스 색인 추가
- [x] 메모리 참조 규칙 — 데이터 과업 시작 시 `infra-map.md` 먼저 읽기
- [ ] coop-integration 실전 진행 후 템플릿 A(Purchase) 케이스 스터디 보강
- [ ] recipes 추가 (add-new-event / add-new-metric / add-new-mart) — 반복 빈도 관찰 후

## 데이터 (/architect) — 선택

- [ ] 레이어 원칙·네이밍·태그 체계가 신규 카탈로그와 일치하는지 검토 및 정비 제안

## QA (/qa)
해당없음

---

## 외부 DB / 시스템 확인이 필요한 과업 *[사용자가 직접 채움]*

> 코드 분석만으로는 확정 불가 → 사용자가 BigQuery/Airflow/Looker/Braze 등을 직접 조회한 결과를 본 섹션에 채워 넣거나 별도 파일로 전달.

- [ ] **Firebase 이벤트 파라미터 스키마** — `analytics_164027297.events_*` 테이블에서 주요 이벤트 15~20개의 `event_params` (파라미터명·타입·예시값)
- [ ] **서버 RDS 소스 테이블 스키마** — `staging_*_server.sql` 에서 복사하는 원본 테이블 현재 스키마 (users / chatbot / payment / fixed_menu / block)
- [ ] **Looker Studio 대시보드 목록** — 운영 중인 대시보드 이름, 참조 테이블 → exposures 매핑
- [ ] **Braze / Amplitude / Airbridge** 별도 이벤트 관리 체계 (Firebase 외 수집 경로)
- [ ] **Airflow Variables / Connections** 이름 목록 (민감값 제외) — sources freshness 연결용
- [ ] **JP 파이프라인 범위** — KR와 별도로 추적하는 KPI 범위 / 책임자
- [ ] **지표 오너십** — 각 지표에 책임지는 팀·담당자

---

## 의존 관계

- Phase 2 (마트 카탈로그)는 Phase 1 우선순위 확정 후 확장 착수
- Phase 3 (이벤트 카탈로그) · Phase 4 (지표 사전)은 Phase 2 초안 이후 병렬 가능
- Phase 5 (플레이북)은 Phase 2~4의 **초안**이 있어야 의미 있음
- Phase 6 (아키텍처 맵) · Phase 7 (deprecation)은 언제든 병렬
- 외부 DB 과업은 Phase 3 · 4 보강에 필수 — 들어오는 순서대로 카탈로그 갱신
