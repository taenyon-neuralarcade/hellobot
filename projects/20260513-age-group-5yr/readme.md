# age_group_5yr — 5세 단위 연령 버킷 컬럼 추가

## 배경

`union_mart_user_key_actions` 의 기존 연령 분류 컬럼은 두 가지:
- `age_group`: 13-17 / 18-24 / 25-34 / 35-44 / 45-54 / 55-64 / 65+ (불균등 크기 — 청소년/청년만 7년·5년·10년 혼합)
- `age_generation`: 10대 / 20대 / 30대 / 40대 / 50대 / 60대 / 70대 이상 (10년 단위)

세그먼트별 마케팅 액션과 월간 추이 모니터링을 위해 **균일한 5세 단위 버킷** 이 필요. 16-20 / 21-25 / 26-30 처럼 5세 간격이 유지되어야 함.

## 목표

1. `union_mart_user_key_actions` 에 `age_group_5yr` (event_date 시점 기준) 컬럼 추가
2. 동일 패턴을 사용하는 5개 마트 SQL 에도 추가하여 일관성 유지
3. 월간 추이 분석 / drift 분석을 위한 **분석 패턴 카탈로그 recipe 신규 작성** (실제 분석 시점에 `user_birth_year` 로 재계산)

## 범위

**포함**:
- 6개 SQL 파일에 `age_group_5yr` CASE 블록 추가
- `union_mart_user_key_actions.sql` 에 컬럼 description 추가
- 데이터 카탈로그 SSOT 갱신 (테이블 컬럼표 + 신규 recipe + Changelog)

**제외**:
- 6개 SQL 의 age CASE 중복 제거 리팩토링 → 별도 과업으로 분리 (BQ Persistent UDF 또는 dbt macro 검토)
- 월간 추이 / drift 분석을 위한 신규 마트 신설 → 분석 빈도가 높아져서 매번 재계산 비용이 부담되면 그때 별도 프로젝트로 분리
- 기존 `age_group` / `age_generation` 의 변경·제거 (호환성 유지)

## 핵심 설계 결정

| 결정 | 선택 | 근거 |
|---|---|---|
| 버킷 구간 | 13-15 / 16-20 / 21-25 / 26-30 / 31-35 / ... / 61-65 / 66+ | 5세 균일. 13-15만 3년 (만 13세부터 user_age 적재) |
| 분류 시점 | **event_date 시점** (`user_age` 와 동일) | 마트 그레인(event) 컨벤션 유지. 다른 age 컬럼과 동일 기준 |
| 월간 추이 분석 | 마트 컬럼 X, **분석 시점 재계산** (recipe 표준화) | `user_birth_year` 만으로 어떤 기준 시점이든 재계산 가능. 마트에 두 진실(event 시점/월 시점) 박지 않음 |
| Drift 추적 | 마트 컬럼 X, user-level 분석 패턴 | drift = user 단위 cohort 매트릭스. event 마트 컬럼이 아님 |
| 적용 범위 | union + 동일 패턴 5개 SQL 전체 | 일관성. 다운스트림 분석에서 컬럼 부재 차이 방지 |

상세: [architecture.md](./architecture.md)

## 영향 범위

| 파트 | 영향 | 설명 |
|------|------|------|
| 데이터 | O | 6개 SQL 수정 + 카탈로그 SSOT 갱신 + 신규 recipe |
| 서버 | X | 해당없음 |
| 웹/iOS/Android | X | 해당없음 |
| 스튜디오 | X | 해당없음 |
| QA | X | 데이터 무결성 검증은 `/dev-data` 자체 수행 (BQ dry-run + NULL 분포 확인) |

## 문서 목록

| 문서 | 설명 |
|------|------|
| [status.md](./status.md) | 진행 상태 |
| [tasks.md](./tasks.md) | 과업 목록 |
| [architecture.md](./architecture.md) | 기술 설계 (버킷 정의·SQL 변경·recipe 설계 근거) |
| [eda-by-age-group-5yr.md](./eda-by-age-group-5yr.md) | 컬럼 추가 후 30일 EDA (매출·이벤트·콘텐츠·유입·RFM·whale 6개 차원 + 신규/기존 + 4개년 YoY + 인사이트) |
| [eda-by-age-group-5yr-app.md](./eda-by-age-group-5yr-app.md) | APP-only EDA — 메인 EDA와 동일 차원, `platform_appweb='APP'` 필터. APP 매출 -58% 절벽, 채널 전환(APP→WEB), 사주가 타로보다 더 큰 폭 감소 등 새로운 결론 |
| [app-decline-decomposition.md](./app-decline-decomposition.md) | APP 매출·구매자 하락 세부 분해 — 매출 분해 방정식, 연령×플랫폼 매트릭스, 신규/기존 분리, whale 변화, iOS/Android 시점 분석. **매출 하락 80%가 사용자 유입 감소, Android 2023→2024 사용자 -42% 폭락이 핵심 사건** |
