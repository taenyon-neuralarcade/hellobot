# 개발 상태

## 현재 상태: ✅ 적용완료 (2026-05-16)

> PR: [thingsflow/common-data-airflow#180](https://github.com/thingsflow/common-data-airflow/pull/180) (커밋 `3e23516`, `Feat/age-group-5yr` → `develop`)

> 2026-05-16 `/dev-data` 가 Phase 1~4 일괄 수행 완료. PR #180 머지 → **적용완료**. 다음 일배치 후 컬럼 분포·age_group 교차 검증 남음.
>
> **주요 발견** (architecture.md §7-3):
> - NULL 비중 ~36.8% — 사전 게이트 30% 초과 but 사용자 결정으로 그대로 진행 (`정보없음` 버킷에 흡수)
> - `user_age` = **단순 연도차** (만 나이 아님)
> - `user_birth_year` = STRING (카탈로그 정형화 + dbt schema.yml 보강 처리)

## 파트별 현황

| 파트 | 상태 | 브랜치 | 워크트리 | 비고 |
|------|------|--------|---------|------|
| 데이터 | ✅ 적용완료 (PR #180 머지, 2026-05-16) | Feat/age-group-5yr | worktrees/common-data-airflow | 6개 SQL + 카탈로그 4개. 커밋 3e23516. [PR #180](https://github.com/thingsflow/common-data-airflow/pull/180). 다음 일배치 후 검증 남음 |
| 기타 파트 | 해당없음 | - | - | |

## 블로커

- **잠재 충돌**: 원본 리포 `develop` 의 `docs/hellobot-data/catalog/{architecture,event-catalog,external-tasks,infra-map,issues,mart-catalog}.md` 가 미커밋 상태. 본 PR 의 `infra-map.md` / `union_mart_user_key_actions.md` 갱신과 머지 시 충돌 가능. PR 전 사용자가 in-progress 변경 처리 필요

## 확정 사항

| 항목 | 내용 |
|------|------|
| 버킷 구간 | 13-15, 16-20, 21-25, 26-30, 31-35, 36-40, 41-45, 46-50, 51-55, 56-60, 61-65, 66+, 정보없음 |
| 컬럼명 | `age_group_5yr` |
| 분류 시점 | event_date 시점 (user_age 와 동일 컨벤션) |
| 적용 범위 | union_mart_user_key_actions + 동일 패턴 5개 SQL 전체 (총 6개) |
| 월간 추이/drift | 마트 컬럼 신설 X — 신규 recipe `age-cohort-trend-analysis.md` 로 표준화 |
| 6개 SQL 중복 제거 | 별도 과업 분리 (UDF/macro 검토) |

## 마일스톤

| # | 작업 | 상태 |
|---|------|------|
| 1 | 프로젝트 문서 작성 | ✅ |
| 2 | BQ 사전 검증 (user_birth_year NULL 비중, user_age 계산 기준) | ✅ 2026-05-16 (architecture.md §7-3) |
| 3 | 워크트리 생성 (Phase 1 통과 후) | ✅ 2026-05-16 (`Feat/age-group-5yr` from origin/develop) |
| 4 | 6개 SQL 수정 | ✅ 2026-05-16 (union 본진 28줄 / 나머지 5개 각 15줄, 총 103줄 추가) |
| 5 | 카탈로그 SSOT 갱신 (union 컬럼표 정형화 + dbt schema.yml 보강 + Changelog) | ✅ 2026-05-16 |
| 6 | 신규 recipe 작성 (`age-cohort-trend-analysis.md`) | ✅ 2026-05-16 |
| 7 | infra-map 진입 색인 / catalog readme 인벤토리 갱신 | ✅ 2026-05-16 |
| 8 | PR 생성 | ✅ 2026-05-16 — [PR #180](https://github.com/thingsflow/common-data-airflow/pull/180) |
| 9 | PR #180 머지 / 적용완료 | ✅ 2026-05-16 |
| 10 | 머지 후 검증 (다음 일배치 + 컬럼 분포 + age_group 교차) | ⏳ 다음 일배치 후 |
