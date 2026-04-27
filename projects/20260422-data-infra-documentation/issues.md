# 이슈 레지스트리

> **원칙**: 등록만 여기서, 해결 내역은 git log + tasks.md에 남김. 상태 필드만 업데이트.
> 이슈 발견 시 등록 → 사용자와 협의 → 필요 시 설계 반영 (여기선 코드 없음, 문서 규약) → 구현 → 상태 "해결 (YYYY-MM-DD)"

> **2026-04-22 프로젝트 종료** — ISS-001 해결 처리, ISS-002~011 (10건) 은 데이터 인프라 영속 이슈로 SSOT([`common-data-airflow/docs/hellobot-data/catalog/issues.md`](../../common-data-airflow/docs/hellobot-data/catalog/issues.md))로 이전. 본 파일은 종료 시점 스냅샷이며, 추적은 SSOT에서 계속됩니다.

## 종료 시점 이슈 현황 (2026-04-22)

### ISS-001 — 기존 테이블 스키마 문서의 심각한 실제 SQL 불일치

- **분류**: `bug` (문서 정확성 결함)
- **심각도**: ★★★
- **발견**: 2026-04-22 (`/dev-data` 포맷 샘플 작성 중)
- **상태**: 해결 (2026-04-22)
- **해결**: `docs/hellobot-data/tables/` 58개 파일에 deprecated 배너 부착 + 신규 카탈로그(`docs/hellobot-data/catalog/`) 경로 안내. PR [#176](https://github.com/thingsflow/common-data-airflow/pull/176) 머지 완료.

**현상**
- `common-data-airflow/docs/hellobot-data/tables/mart/mart_user_daily_info.md` (295줄)가 실제 `scripts/hellobot/mart/mart_user_daily_info.sql` 과 **심각하게 불일치**
  - 문서 주장: `sessions_count`, `engagement_score`, `churn_risk_score`, `skill_completion_rate`, ML 예측 필드 등 80+ 컬럼
  - 실제 SQL: 22개 컬럼의 단순 SELECT (사용자 마스터 × 날짜 속성만)
- 문서의 "사용 예시 SQL"들은 **존재하지 않는 컬럼을 참조**하여 실행 불가

**원인 (추정)**
- 문서가 LLM 등으로 자동 생성됐을 가능성 — 실제 스키마 검증 없이 "이상적" 컬럼을 상상해 작성한 것으로 보임
- `tables/README.md` 에 "16개 주요 테이블 문서화 완료"라고 명시되어 있으나 실제 정확성은 미검증

**영향**
- 이 문서를 참조한 신규 쿼리가 전부 실패
- 분석가가 잘못된 컬럼이 존재한다고 오해하여 설계 지연
- "어떤 마트에서 뭘 할 수 있는지" 판단이 왜곡

**대응**
- 본 프로젝트: 신규 카탈로그는 **실제 SQL 기준으로만** 작성하는 규약 고정
- 기존 16개 문서는 deprecated 표기 (Phase 7)
- 나머지 15개 문서의 정확성 검증은 **범위 외** — 필요 시 별도 이슈 분리

---

### ISS-002 — `mart_user_daily_info` 파티션 키 미적용

- **분류**: `enhancement`
- **심각도**: ★★
- **발견**: 2026-04-22
- **상태**: 이관 (2026-04-22, SSOT: `common-data-airflow/docs/hellobot-data/catalog/issues.md`)

**현상**
- `scripts/hellobot/mart/queries.py` 의 `mart_user_daily_info` 생성 쿼리가 `PARTITION BY` 없이 `CREATE OR REPLACE TABLE` 수행
- 조회 시 `WHERE event_date = …` 조건을 걸어도 **전체 테이블 풀스캔** → BQ 비용 증가

**대응**
- 본 프로젝트 범위: 문서의 "파티션" 필드에 현재 상태(미적용) + 권장 사항(`PARTITION BY event_date`) 기록
- 실제 파이프라인 수정은 **별도 개선 프로젝트**로 분리 제안

---

### ISS-003 — `mart_skill_open_date_se` 가 동일 레이어 mart를 참조

- **분류**: `edge-case`
- **심각도**: ★
- **발견**: 2026-04-22
- **상태**: 이관 (2026-04-22, SSOT: `common-data-airflow/docs/hellobot-data/catalog/issues.md`)

**현상**
- `mart_skill_open_date_se.sql` 의 유일한 소스가 `hlb_mart.mart_use_skill_se` — 같은 mart 레이어의 다른 마트를 참조
- 이 때문에 `mart_skill_open_date_se` 는 `mart_use_skill_se` 이후에 실행되어야 하는 암묵적 순서 의존

**영향**
- 레이어 원칙(staging→intermediate→mart) 위반: mart ≠ mart consumer
- DAG 의존 체인 복잡화, 장애 시 원인 추적 어려움
- dbt 이식 시 `ref()` 체인 재설계 필요 (mart 간 참조인 경우 `intermediate` 또는 `marts/base/` 로 이동 제안)

---

### ISS-004 — intermediate 테이블 정의가 `.sql` 파일 / `queries.py` inline 혼재

- **분류**: `enhancement`
- **심각도**: ★
- **발견**: 2026-04-22
- **상태**: 이관 (2026-04-22, SSOT: `common-data-airflow/docs/hellobot-data/catalog/issues.md`)

**현상**
- `intermediate_ir_dashboard_metrics_fb` 는 `.sql` 파일이 없고 `scripts/hellobot/intermediate/queries.py` 내에 inline SQL 문자열로만 존재
- 반면 `intermediate_use_skill_se.sql` 등 다수는 별도 `.sql` 파일
- 두 패턴이 혼재

**영향**
- 테이블 이름으로 파일 검색 시 누락
- 자동화된 lineage 추출 어려움
- dbt 이식 시 전체 `.sql` 파일화 필요

---

### ISS-005 — `union_mart_user_key_actions` 자기 참조 (준-증분 패턴)

- **분류**: `edge-case`
- **심각도**: ★★
- **발견**: 2026-04-22
- **상태**: 이관 (2026-04-22, SSOT: `common-data-airflow/docs/hellobot-data/catalog/issues.md`)

**현상**
- `union_mart_user_key_actions.sql` 내 `user_daily_revenue` CTE 가 생성 대상 테이블 자신(`hlb_mart_integrated.union_mart_user_key_actions`)을 `FROM` 으로 읽음
- `CREATE OR REPLACE TABLE` 이 수행되기 직전의 이전 스냅샷을 참조하여 누적 매출을 계산하는 패턴
- 결과적으로 매일 실행 시 "어제까지의 누적" 기반으로 "오늘자 이벤트의 누적"을 계산

**영향**
- 부트스트랩 문제: 최초 실행 또는 테이블이 없는 환경에서는 누적값이 초기화되어 실행 실패 또는 0 시작
- 누적 값 오류 시 롤백/재계산 복잡
- dbt 이식 시 `incremental` materialization + `{{ this }}` 참조로 명시적으로 표현 필요
- 테스트 환경 구축 시 "이전 스냅샷" 복제 필요

---

### ISS-006 — `google_sheet_sync.taenyon_temp_skill_tag_info_v2` 단일 담당자 의존 (본인 소유)

- **분류**: `enhancement`
- **심각도**: ★★
- **발견**: 2026-04-22
- **상태**: 이관 (2026-04-22, SSOT: `common-data-airflow/docs/hellobot-data/catalog/issues.md`)

**현상**
- 프로덕션 파이프라인(`union_mart_user_key_actions`)이 `google_sheet_sync.taenyon_temp_skill_tag_info_v2` 참조
- 네이밍(`taenyon_temp`, `_v2`)이 개인 작업물임을 시사
- 소유자 확인: **taenyon = 사용자 본인** (운영 담당자 인지 O)

**영향**
- 개인 소유 GSheet에 프로덕션 의존 → 유지보수 단일점
- `_v2` 버전 관리 규약 불명 (v1/v3 존재 여부, 마이그레이션 계획)
- 스킬 태깅 정보는 `topic`, `intents`, `temporal` 등 운영상 중요 메타 → 공식 BQ 테이블 또는 공식 GSheet로 승격 필요

**대응 (향후)**
- 스킬 태그 관리 프로세스를 팀 공유 GSheet 또는 서버 테이블로 이관하는 별도 프로젝트 제안

---

### ISS-007 — `manual_server_rdb.product` 수동 업로드 의존

- **분류**: `enhancement`
- **심각도**: ★★
- **발견**: 2026-04-22
- **상태**: 이관 (2026-04-22, SSOT: `common-data-airflow/docs/hellobot-data/catalog/issues.md`)

**현상**
- `mart_purchase_fb` 가 `manual_server_rdb.product` 참조
- "manual" 데이터셋은 자동화되지 않은 수동 업로드 테이블임을 시사

**영향**
- 업로드 주체·주기·스키마 변경 관리 불투명
- 실수/누락 시 mart_purchase_fb 에 이어 `union_mart_user_key_actions` 까지 누적 영향
- 데이터 freshness SLA 부재

**대응**
- 업로드 주체·주기 확인 (외부 과업 리스트)
- 가능하면 `hlb_staging` 의 자동 스냅샷으로 흡수 (별도 개선 프로젝트)

---

### ISS-008 — `adhoc_mart_user_rfm_info_daily` 이력 보존 여부 불명

- **분류**: `edge-case`
- **심각도**: ★★
- **발견**: 2026-04-22
- **상태**: 이관 (2026-04-22, SSOT: `common-data-airflow/docs/hellobot-data/catalog/issues.md`)

**현상**
- SQL 주석: "매일 어제자 데이터를 추가/업데이트"
- 실제 쿼리 구조는 `WHERE event_date <= TARGET_DATE` 로 **전체 이력 재계산** 후 반환
- `CREATE OR REPLACE TABLE` 인지 `INSERT` 인지는 `mart_adhoc_func.py` 확인 필요
- `union_mart_user_key_actions`는 `WHERE event_date = CURRENT_DATE() - 1` 로 **어제 한 날짜만** 가져다 모든 이벤트 행에 붙임 → 이력 축적이 안 되면 과거 이벤트의 RFM 이 최신 RFM으로 왜곡

**영향**
- 이력 축적: 과거의 "당시 RFM"으로 코호트별 세그먼트 이동 추적 가능
- 스냅샷 덮어쓰기: 과거 이벤트 행의 RFM이 **항상 어제 기준** → 시계열 분석 왜곡
- 현재 어느 쪽인지 확정해야 `union_mart_user_key_actions` 의 RFM 컬럼 해석이 정해짐

**대응**
- `mart_adhoc_func.py` 의 `update_adhoc_mart_user_rfm_info_daily_table` 함수 구현 확인 (외부 과업)
- 이력 축적이 원래 의도라면 `INSERT` 로 수정, 스냅샷이 의도라면 컬럼 설명에 명시

---

### ISS-010 — `staging_key_events_fb.sql` 주석과 SQL의 WEB user_id 전환 시점 불일치

- **분류**: `bug` (문서 결함, 기능 영향 없음)
- **심각도**: ★
- **발견**: 2026-04-22
- **상태**: 이관 (2026-04-22, SSOT: `common-data-airflow/docs/hellobot-data/catalog/issues.md`)

**현상**
- `staging_key_events_fb.sql` 주석 (10행): "WEB 의 경우에는 2019-12-01 이후로 user_id 사용"
- 실제 SQL (53행, 92행): `platform = "WEB" AND PARSE_DATE("%Y%m%d", event_date) < "2022-12-01" THEN user_pseudo_id`
- 즉, 실제 전환 시점은 **2022-12-01**이나 주석은 2019-12-01 로 오기되어 있음

**영향**
- 주석만 보고 작업하는 사람이 2019-12-01~2022-11-30 구간의 WEB `user_id_processed` 정의를 오해할 수 있음
- 실제 데이터는 이 구간에서 `user_pseudo_id` 가 들어감 (올바른 동작)

**대응**
- 주석 수정: `2019-12-01` → `2022-12-01`
- 본 프로젝트 범위는 문서화만이므로 이벤트 카탈로그의 `user_id_processed` 컬럼 설명에 실제 SQL 기준으로 기록

---

### ISS-011 — 이벤트 수집 목록 테이블(`staging_key_events_*_events_list`)의 관리 주체·절차 미문서화

- **분류**: `enhancement`
- **심각도**: ★★
- **발견**: 2026-04-22
- **상태**: 이관 (2026-04-22, SSOT: `common-data-airflow/docs/hellobot-data/catalog/issues.md`)

**현상**
- `staging_key_events_fb.sql` 은 수집할 이벤트를 3개 BQ 테이블에서 LOOKUP:
  - `hlb_staging.staging_key_events_fb_events_list`
  - `hlb_staging.events_list` (Firebase 목록과 UNION)
  - `hlb_staging.staging_key_events_se_events_list` (서버용)
- 이 테이블들이 **어떻게 채워지는지**는 파이프라인(`common-data-airflow`) 코드에 없음
- 따라서 **신규 이벤트가 수집 대상에 포함되는 절차**가 문서화되어 있지 않음

**영향**
- 새 기능 배포 시 이벤트 로깅했는데도 `staging_key_events_fb` 에 안 들어오는 경우 발생 가능 (events_list 등록 누락)
- 플레이북 작성 시 "이벤트 등록" 단계 명확화 불가

**대응**
- 외부 확인 과업:
  - 각 events_list 테이블을 **누가 / 어떤 도구로** 업데이트하는가 (수동 INSERT? Airflow Variable? GSheet sync?)
  - 신규 이벤트 등록 절차
- 결과가 확인되면 `event-catalog.md` 의 "신규 이벤트 등록 절차" 섹션에 기록

---

### ISS-009 — `payment_segment` CASE WHEN 순서로 인한 dead branch 가능성

- **분류**: `bug`
- **심각도**: ★
- **발견**: 2026-04-22
- **상태**: 이관 (2026-04-22, SSOT: `common-data-airflow/docs/hellobot-data/catalog/issues.md`)

**현상**
- `adhoc_mart_user_rfm_info_daily.sql` 의 `payment_segment` CASE WHEN 순서:
  1. `Need Attention`: `R_pay_score >= 2 AND F_pay_score >= 2`
  2. `About to Sleep`: `R_pay_score >= 2 AND F_pay_score >= 2 AND M_score >= 2`
- `Need Attention` 조건이 `About to Sleep` 의 슈퍼셋 → About to Sleep 으로 분류되는 사용자가 나올 수 없음 (dead branch)

**영향**
- 세그먼트 수가 11개로 실효 (About to Sleep = 0명일 것)
- RFME.md 기준 세그먼트 정의와 실제 분류 불일치

**대응**
- `About to Sleep` 조건을 `Need Attention` 보다 먼저 평가하도록 순서 변경, 또는 조건 세분화
- 실측으로 About to Sleep = 0 확인 후 수정 (별도 개선 프로젝트)

---

## 해결된 이슈

*없음*

---

## 이슈 번호 규칙

- 순번 부여: 본 파일의 마지막 번호 + 1
- 분류: `bug` / `edge-case` / `enhancement`
- 상태: `미해결` / `해결 (YYYY-MM-DD)`
- 심각도: ★★★ (즉시 대응) / ★★ (이번 프로젝트 내) / ★ (백로그)
