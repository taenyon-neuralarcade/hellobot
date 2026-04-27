# 개발 상태

## 현재 상태: 완료 (2026-04-22)

**최근 결정 (2026-04-22)**
- 산출물 포맷: dbt-ready (sources/schema/metrics/exposures 호환 YAML 병기)
- 문서 위치: **[`common-data-airflow/docs/hellobot-data/catalog/`](../../common-data-airflow/docs/hellobot-data/catalog/)** (리포 내, SSOT) — 워크스페이스 `planning/` 에서 이전 완료
- 동기화 규칙: `common-data-airflow/CLAUDE.md` §데이터 카탈로그 동기화 (코드 PR 시 함께 갱신 의무)
- 기존 `common-data-airflow/docs/hellobot-data/tables/` 는 deprecated
- 이슈는 종료 시점에 SSOT(`catalog/issues.md`) 로 이전 — [§종료 정보](#종료-정보) 참조

## 파트별 현황

| 파트 | 상태 | 브랜치 | 워크트리 | 비고 |
|------|------|--------|---------|------|
| 기획 | 보류 | - | - | 지표 오너십·쓰임새 수집은 미수행 — §종료 정보 미완 과업 |
| 서버 | 해당없음 | - | - | |
| iOS | 해당없음 | - | - | |
| Android | 해당없음 | - | - | |
| 웹 | 해당없음 | - | - | |
| 스튜디오 | 해당없음 | - | - | |
| 데이터 | 완료 | Feat/data-infra-documentation | worktrees/common-data-airflow | Phase 1~10 핵심 산출물 완료 — 카탈로그 5종 + recipes + 내비게이션 + 리포 SSOT 이전 + 동기화 규칙 |
| QA | 해당없음 | - | - | |

## 블로커

없음

## 확정 사항

| 항목 | 내용 |
|------|------|
| 산출물 성격 | 코드 변경 없음, 문서만 산출 |
| 주요 리포 | common-data-airflow (워크트리: `worktrees/common-data-airflow`, 브랜치: `Feat/data-infra-documentation`) |
| 대상 범위 | HelloBot 한정 (`hlb_dags/`, `scripts/hellobot/`) — 타 서비스 제외 |

---

## 종료 정보

**종료일**: 2026-04-22
**종료 상태**: 완료 (정상 종료)

### 머지된 PR

| 리포 | PR | 제목 | 머지일 |
|------|----|----|--------|
| common-data-airflow | [#176](https://github.com/thingsflow/common-data-airflow/pull/176) | docs: HelloBot 데이터 카탈로그를 리포 docs/hellobot-data/catalog/ 로 이전 + 동기화 규칙 추가 | 2026-04-22 |

### 승격된 영속 산출물

| 산출물 | 원위치 | 승격 위치 |
|--------|--------|----------|
| 데이터 카탈로그 (infra-map · architecture · event-catalog · metric-dictionary · mart-catalog · playbook · recipes/ · tables/ · external-tasks · issues · scope-union-user-key-actions · readme) | `projects/20260422-data-infra-documentation/planning/` (워크스페이스, 삭제됨) | [`common-data-airflow/docs/hellobot-data/catalog/`](../../common-data-airflow/docs/hellobot-data/catalog/) |
| 카탈로그 동기화 규칙 (코드 변경 시 카탈로그 동시 갱신 의무) | (신규) | `common-data-airflow/CLAUDE.md` §데이터 카탈로그 동기화 |
| `/dev-data` 에이전트 카탈로그 진입 경로 | (신규) | [`.claude/commands/dev-data.md`](../../.claude/commands/dev-data.md) |
| 데이터 인프라 진입 메모리 | (신규) | `~/.claude/.../memory/reference_data_infra_entry.md` |

### 미해결 이슈 처리

| ID | 분류 | 처리 | 비고 |
|----|------|------|------|
| ISS-001 | bug | **해결 (2026-04-22)** | `docs/hellobot-data/tables/` 58개 파일 deprecated 배너 부착, PR #176 머지 |
| ISS-002 | enhancement | **SSOT 이전** | `mart_user_daily_info` 파티션 미적용 — 영속 이슈, 별도 개선 프로젝트 대상 |
| ISS-003 | edge-case | **SSOT 이전** | `mart_skill_open_date_se` 동일 레이어 mart 참조 — 영속 이슈 |
| ISS-004 | enhancement | **SSOT 이전** | intermediate `.sql` / inline SQL 혼재 — 영속 이슈 |
| ISS-005 | edge-case | **SSOT 이전** | `union_mart_user_key_actions` 자기 참조 (준-증분 패턴) — 영속 이슈 |
| ISS-006 | enhancement | **SSOT 이전** | 스킬 태그 GSheet (`taenyon_temp_skill_tag_info_v2`) 단일 담당자 — 영속 이슈 |
| ISS-007 | enhancement | **SSOT 이전** | `manual_server_rdb.product` 수동 업로드 — 영속 이슈 |
| ISS-008 | edge-case | **SSOT 이전** | `adhoc_mart_user_rfm_info_daily` 이력 보존 불명 — 영속 이슈, 외부 확인 필요 |
| ISS-009 | bug | **SSOT 이전** | `payment_segment` dead branch — 영속 이슈 |
| ISS-010 | bug | **SSOT 이전** | `staging_key_events_fb.sql` 주석 불일치 (2019→2022) — 영속 이슈 |
| ISS-011 | enhancement | **SSOT 이전** | 이벤트 화이트리스트 관리 절차 미문서화 — 영속 이슈, 외부 확인 필요 |

> ISS-002~011 (10건) 은 모두 데이터 인프라의 영속 이슈로, 본 프로젝트(문서화 전용) 범위 외 수정 대상입니다. SSOT([`common-data-airflow/docs/hellobot-data/catalog/issues.md`](../../common-data-airflow/docs/hellobot-data/catalog/issues.md))에서 추적합니다.

### 미완 과업 (후일 결정 보류)

본 프로젝트 종료 시점 기준 미체크 과업 목록. 후속 프로젝트나 별도 결정 시 참조용 (현 시점에서 어디로 이관·drop 할지 결정하지 않음).

**기획 (외부 협의 필요)**
- 주요 지표의 오너십 확정 — 어떤 팀/담당자가 해당 숫자에 책임지는지
- 주요 대시보드·알림의 현업 쓰임새 수집 — 마트 카탈로그 초안 기반 인터뷰 (선택)

**카탈로그 확장 (Phase 2)**
- P1: intermediate 요약 (union_mart_user_key_actions 체인 이해용)
- P2: staging 요약 (이벤트 카탈로그 보완)
- ★★ 추가 마트 카탈로그화 (스코프가 union_mart_user_key_actions 계보로 한정되어 보류)

**카탈로그 보강 (Phase 4·5·9)**
- `report_*` 레이어 쿼리까지 스캔 확장 (지표 사전)
- 지표 변경 관리 규약 합의
- 실제 과거 기능 케이스 스터디 보강 (플레이북) — 기능 선정 후
- coop-integration 종료 후 템플릿 A(Purchase) 케이스 스터디 보강
- recipes 추가 (add-new-event / add-new-metric / add-new-mart) — 사용 패턴 관찰 후

**선택 과업**
- `/architect` 레이어 원칙·네이밍·태그 체계 검토 및 정비 제안

**외부 DB·시스템 확인 과업** — 모두 [`common-data-airflow/docs/hellobot-data/catalog/external-tasks.md`](../../common-data-airflow/docs/hellobot-data/catalog/external-tasks.md) 에 이전되어 추적 중

### 워크트리/브랜치 정리

| 리포 | 브랜치 | 워크트리 | 정리 예정일 |
|------|--------|---------|------------|
| common-data-airflow | `Feat/data-infra-documentation` | `worktrees/common-data-airflow` | 2026-05-06 (hotfix 윈도우 종료 후) |

### 회고

**잘된 점**
- Map → Recipe → Detail 3축 구조 도입으로 신규 과업 시 진입점 명확화
- 카탈로그를 리포 SSOT 로 이전 + CLAUDE.md 동기화 규칙으로 sync drift 방지 체계 구축
- 기존 문서의 SQL 불일치 (ISS-001) 발견 → 신규 카탈로그는 실제 SQL 기준 작성 규약 고정

**개선할 점**
- 카탈로그 위치(워크스페이스 vs 리포)를 초기에 결정하지 않아 작성 후 이전 단계 발생 → 향후 영속 자산이 예상되는 프로젝트는 시작 시 위치 결정
- 외부 DB 확인이 필요한 항목이 많아 카탈로그 완성도가 부분적 → 외부 의존 과업은 프로젝트 시작 시 별도 트랙으로 분리
