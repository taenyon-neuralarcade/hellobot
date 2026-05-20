# 과업 목록

## 데이터 (/dev-data)

### Phase 1 — 사전 검증
- [x] `user_birth_year IS NULL` 비중 측정 (최근 7일 union_mart_user_key_actions) — 평균 ~36.8%
- [x] `user_age` 계산 기준 확인 — **단순 연도차** (만 나이 아님)
- [x] 결과를 architecture.md §7-3 "검증 결과" 섹션에 기록 (2026-05-16)
- [x] 부수: `user_birth_year` 타입 STRING 발견 — 카탈로그 갱신 후보 식별

### Phase 2 — 워크트리 생성
- [x] `Feat/age-group-5yr` 브랜치 + worktree 생성 (origin/develop 기준, 2026-05-16)

### Phase 3 — SQL 수정 (워크트리 내)
- [x] `dags/scripts/hellobot/mart_integrated/union_mart_user_key_actions.sql`
  - [x] `age_group_5yr` CASE 블록 추가 (`age_generation` 바로 아래, 942 라인 직후)
  - [x] `ALTER COLUMN age_group_5yr SET OPTIONS(description=...)` 추가
- [x] `dags/scripts/hellobot/mart_integrated/union_mart_use_skill_and_user_daily.sql` — CASE 블록 추가
- [x] `dags/scripts/hellobot/mart_integrated/union_mart_use_skill_from_home_banner.sql` — CASE 블록 추가
- [x] `dags/scripts/hellobot/mart_integrated/union_mart_use_skill_from_search_result.sql` — CASE 블록 추가
- [x] `dags/scripts/hellobot/mart_integrated/union_mart_use_skill_from_exhibition_page.sql` — CASE 블록 추가
- [x] `dags/scripts/hellobot/mart_adhoc/adhoc_mart_user_key_actions_for_targeting.sql` — CASE 블록 추가

> ⚠ architecture.md §5 의 파일 경로 (`scripts/hellobot/...`) 는 부정확 — 실제는 `dags/scripts/hellobot/...`. Phase 5 PR 전에 architecture.md 경로 정정 필요.

### Phase 4 — 카탈로그 SSOT 갱신
- [x] `docs/hellobot-data/catalog/tables/mart_integrated/union_mart_user_key_actions.md` §사용자 기본 정형 표화 + `age_group_5yr` 추가 + dbt schema.yml 초안에 3개 컬럼 예시 추가 + 개정 이력 (2026-05-16)
- [x] `docs/hellobot-data/catalog/recipes/age-cohort-trend-analysis.md` 신규 작성 (패턴 A 월 단위 / B Drift / C decomposition + 함정 체크리스트)
- [x] `docs/hellobot-data/catalog/infra-map.md` §과업 유형 → 진입 문서 표에 신규 recipe 진입 행 추가 + 개정 이력 (2026-05-16)
- [x] `docs/hellobot-data/catalog/readme.md` 인벤토리에 신규 recipe 등록

### Phase 5 — PR
- [x] architecture.md §5 의 SQL 파일 경로 정정 (`scripts/` → `dags/scripts/`)
- [x] 변경 사항 커밋 (`Feat/age-group-5yr` · 3e23516) — 2026-05-16
- [x] PR 생성 ([thingsflow/common-data-airflow#180](https://github.com/thingsflow/common-data-airflow/pull/180), develop 대상) — 2026-05-16
- [ ] Slack 데이터팀 채널에 PR 공유 (선택, 사용자 판단)
- [ ] **머지 전 충돌 점검**: 원본 리포 `develop` 의 `docs/hellobot-data/catalog/{architecture, event-catalog, external-tasks, infra-map, issues, mart-catalog}.md` 미커밋 변경 정리 필요 (PR 본문에도 명시)
- [ ] 머지 후 검증 (다음 KST 11:00 일배치 + architecture.md §7-2 쿼리)

## 의존 관계

- Phase 1 (BQ 검증) → Phase 2 (워크트리) — 검증 결과로 컬럼 정의 미세 조정 가능 (NULL 비중이 매우 높으면 처리 방식 재논의)
- Phase 2 → Phase 3, 4 병렬 가능 (SQL 수정과 카탈로그 갱신은 독립)
- Phase 3, 4 완료 → Phase 5
