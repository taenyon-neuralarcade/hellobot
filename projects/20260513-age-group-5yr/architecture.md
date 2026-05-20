# 기술 설계 — age_group_5yr

## 1. 개요

`union_mart_user_key_actions` 와 동일 패턴 5개 마트 SQL 에 **5세 단위 균일 연령 버킷 컬럼** 추가. 분류 기준은 event_date 시점이며, 월간 추이·drift 분석은 마트 컬럼이 아닌 분석 시점 재계산 패턴(`user_birth_year` 기반)으로 표준화.

## 2. 버킷 정의

```sql
CASE
    WHEN a.user_age BETWEEN 13 AND 15 THEN '13-15'
    WHEN a.user_age BETWEEN 16 AND 20 THEN '16-20'
    WHEN a.user_age BETWEEN 21 AND 25 THEN '21-25'
    WHEN a.user_age BETWEEN 26 AND 30 THEN '26-30'
    WHEN a.user_age BETWEEN 31 AND 35 THEN '31-35'
    WHEN a.user_age BETWEEN 36 AND 40 THEN '36-40'
    WHEN a.user_age BETWEEN 41 AND 45 THEN '41-45'
    WHEN a.user_age BETWEEN 46 AND 50 THEN '46-50'
    WHEN a.user_age BETWEEN 51 AND 55 THEN '51-55'
    WHEN a.user_age BETWEEN 56 AND 60 THEN '56-60'
    WHEN a.user_age BETWEEN 61 AND 65 THEN '61-65'
    WHEN a.user_age BETWEEN 66 AND 99 THEN '66+'
    ELSE '정보없음'
END AS age_group_5yr
```

**구간 선택 근거**:
- **하한 13-15**: 5년 단위를 16부터 깔끔히 시작. 13~15세는 표본이 작고 청소년기 행동이 16+ 와 명확히 다르므로 별도 버킷 유지. 기존 `age_group` 의 `13-17` 과는 호환되지 않으나, 새 컬럼이므로 충돌 없음
- **상한 66+**: 60세 이상 노년층 표본이 작아 5년 단위 분할의 의미가 약하고, 광고/마케팅 타게팅 빈도도 낮음. 기존 `age_group` 의 `65+` 와 유사한 경계
- **`정보없음`**: `user_age IS NULL` 또는 비현실값 (>99) 처리. 기존 다른 age 컬럼 컨벤션과 일치

## 3. 분류 시점 결정 — Point-in-time (event_date 기준)

### 3-1. 선택안

마트 컬럼은 **event_date 시점의 `user_age` 로 분류**. 즉, 같은 사용자라도 생일 전후로 다른 버킷에 속할 수 있음.

### 3-2. 근거

| 근거 | 설명 |
|---|---|
| **그레인 일관성** | union_mart_user_key_actions 의 그레인이 event 단위. `user_age`, `age_group`, `age_generation` 모두 event_date 시점 기준 → 신규 컬럼도 동일 컨벤션 유지 |
| **일일 운영 즉시성** | "지금 16-20세인 사용자에게 마케팅" 같은 운영 액션에 자연스럽게 사용. 분석가 추가 가공 불필요 |
| **재계산 가능성** | `user_birth_year` 컬럼이 이미 마트에 있어, 다른 기준 시점(월 시작일·연 시작일·임의 D-day)으로 분류하고 싶을 때 SQL 1줄로 재계산 가능 → 마트에 추가 컬럼을 박을 이유가 없음 |
| **단일 진실 원천** | 마트에 "event 시점 age" 와 "frozen age" 두 가지를 박으면 분석가 혼란. 그레인에 맞는 한 가지만 박는 게 깔끔 |

### 3-3. 기각된 대안

| 대안 | 기각 사유 |
|---|---|
| Frozen age (가입 시점 영구 고정) | "현재 X세" 액션에 못 씀. user 속성이지 event 속성이 아니라 그레인 위반 |
| As-of period (월 시작 시점 분류) — 마트 컬럼화 | 일일 대시보드 정합성 깨짐 (1일 ≠ 15일 동일 사용자가 다른 버킷). 분석 시점 재계산으로 충분 |
| 두 컬럼 동시 박기 (event 시점 + 월 시점) | 어느 컬럼이 진실인지 혼란. 동일 정보의 두 표현 — 마트 비대화 |

## 4. 월간 추이·Drift 분석 — Recipe 표준화

마트 컬럼이 아닌 **카탈로그 recipe 로 분석 패턴 표준화**. 신규 파일: `docs/hellobot-data/catalog/recipes/age-cohort-trend-analysis.md`

### 4-1. 패턴 A — 월 기준 분류 (월간 추이용)

```sql
WITH base AS (
  SELECT
    DATE_TRUNC(event_date, MONTH) AS event_month_start,
    user_id,
    user_birth_year,
    event_name,
    revenue_krw
  FROM `hellobot-f445c.hlb_mart_integrated.union_mart_user_key_actions`
  WHERE event_date BETWEEN '2025-01-01' AND '2026-04-30'
    AND user_birth_year IS NOT NULL
),
classified AS (
  SELECT
    event_month_start,
    user_id,
    event_name,
    revenue_krw,
    DATE_DIFF(event_month_start, DATE(user_birth_year, 1, 1), YEAR) AS age_at_month_start,
    CASE
      WHEN DATE_DIFF(event_month_start, DATE(user_birth_year, 1, 1), YEAR) BETWEEN 13 AND 15 THEN '13-15'
      WHEN DATE_DIFF(event_month_start, DATE(user_birth_year, 1, 1), YEAR) BETWEEN 16 AND 20 THEN '16-20'
      -- ... (마트 컬럼과 동일 버킷)
      ELSE '정보없음'
    END AS age_group_5yr_asof_month
  FROM base
)
SELECT
  event_month_start,
  age_group_5yr_asof_month,
  COUNT(DISTINCT user_id) AS active_users,
  COUNT(DISTINCT IF(event_name LIKE 'pay_%' OR event_name = 'purchase', user_id, NULL)) AS paying_users,
  SUM(revenue_krw) AS revenue_krw
FROM classified
GROUP BY 1, 2
ORDER BY 1, 2
```

**언제 쓰는가**: 월 단위 대시보드에서 "동일 인구 정의로 그룹별 활동 추이 모니터링". 같은 월 안에서는 같은 사용자가 항상 같은 그룹 → 분모 안정.

### 4-2. 패턴 B — Drift 매트릭스 (그룹 이동 추적)

```sql
WITH yoy_users AS (
  SELECT
    user_id,
    user_birth_year,
    MAX(IF(event_date BETWEEN '2025-01-01' AND '2025-01-31', 1, 0)) AS active_jan_2025,
    MAX(IF(event_date BETWEEN '2026-01-01' AND '2026-01-31', 1, 0)) AS active_jan_2026
  FROM `hellobot-f445c.hlb_mart_integrated.union_mart_user_key_actions`
  WHERE event_date IN UNNEST(GENERATE_DATE_ARRAY('2025-01-01', '2025-01-31'))
     OR event_date IN UNNEST(GENERATE_DATE_ARRAY('2026-01-01', '2026-01-31'))
  GROUP BY 1, 2
  HAVING active_jan_2025 = 1 AND active_jan_2026 = 1
)
SELECT
  -- 2025-01 시점 그룹
  bucket(DATE_DIFF(DATE '2025-01-01', DATE(user_birth_year, 1, 1), YEAR)) AS group_2025,
  -- 2026-01 시점 그룹
  bucket(DATE_DIFF(DATE '2026-01-01', DATE(user_birth_year, 1, 1), YEAR)) AS group_2026,
  COUNT(*) AS user_count
FROM yoy_users
GROUP BY 1, 2
ORDER BY 1, 2
```

**언제 쓰는가**: "16-20 그룹에서 21-25 그룹으로 이동한 사용자 비율" 같은 user-level cohort 매트릭스. 연말연시 그룹 이동 일괄 검토.

### 4-3. 패턴 C — Cohort decomposition (추이 분해)

월별 그룹 인구 변화를 (a) 신규 유입 (b) 그룹 이탈 (드리프트 또는 비활동) (c) 행동 변화로 분해하는 분석. drift 분석과 결합하여 "16-20 그룹 활동 감소가 자연 노화인지 실제 행동 변화인지" 구분.

상세 SQL 은 recipe 문서에 작성 (본 architecture.md 에서는 의도만 기록).

## 5. 적용 범위 — 6개 SQL

`age_generation` / `age_group` CASE 가 동일 패턴으로 중복 정의된 6개 파일 전부:

| # | 파일 | 라인 (현재 age_generation) |
|---|---|---|
| 1 | `dags/scripts/hellobot/mart_integrated/union_mart_user_key_actions.sql` | 942 (`AS age_generation`) — **+ ALTER description 추가** |
| 2 | `dags/scripts/hellobot/mart_integrated/union_mart_use_skill_and_user_daily.sql` | 158 |
| 3 | `dags/scripts/hellobot/mart_integrated/union_mart_use_skill_from_home_banner.sql` | 238 |
| 4 | `dags/scripts/hellobot/mart_integrated/union_mart_use_skill_from_search_result.sql` | 226 |
| 5 | `dags/scripts/hellobot/mart_integrated/union_mart_use_skill_from_exhibition_page.sql` | 240 |
| 6 | `dags/scripts/hellobot/mart_adhoc/adhoc_mart_user_key_actions_for_targeting.sql` | 595 |

각 파일에서 `age_generation` CASE 블록 **바로 아래** 동일 들여쓰기로 `age_group_5yr` CASE 추가.

### 5-1. 중복 제거 별도 과업

6개 파일에 동일 CASE 가 중복 — 매번 동기 부담. 이번 작업으로 부채가 +1 됨 (`age_group_5yr` 도 6번 반복). 별도 후속 과업으로 분리 검토:
- 옵션 1: BigQuery Persistent UDF (`fn_age_buckets(user_age)` returning STRUCT)
- 옵션 2: dbt macro (dbt 마이그레이션 완료 후)

본 프로젝트에서는 **현재 패턴 유지하며 1줄 추가**. 리팩토링은 분리.

## 6. 백필 / 운영 영향

| 항목 | 영향 |
|---|---|
| 백필 | `union_mart_user_key_actions` 는 `CREATE OR REPLACE TABLE` 전체 치환 → 다음 일배치 (KST 11:00) 에서 자동 반영. 별도 백필 불필요 |
| 자기 참조 (ISS-005) | 컬럼 추가만 — 누적매출(`user_daily_revenue`) 계산에 영향 없음. 안전 |
| 비용 | 컬럼 1개 추가. 마트 크기·스캔 비용 영향 미미 |
| 다운스트림 | `report_pay_for_skill_with_target_info.sql` 가 본진 마트 컬럼을 SELECT — 신규 컬럼은 자동 반영 (해당 파일은 본 작업에서 변경 안 함, 필요시 후속에서 SELECT 추가) |
| 대시보드 (Looker Studio) | 신규 컬럼 추가만 — 기존 컬럼 보존이므로 영향 없음 |

## 7. 검증 절차

### 7-1. BQ 사전 검증 (Phase 1)

```sql
-- user_birth_year NULL 비중 (recipe 4-1, 4-2 가 NULL 처리 정책에 영향 받음)
SELECT
  event_date,
  COUNT(*) AS total_rows,
  COUNTIF(user_birth_year IS NULL) AS null_birth_year,
  COUNTIF(user_age IS NULL) AS null_age,
  COUNTIF(user_age IS NULL AND user_birth_year IS NOT NULL) AS age_null_but_birth_year_present
FROM `hellobot-f445c.hlb_mart_integrated.union_mart_user_key_actions`
WHERE event_date BETWEEN DATE_SUB(CURRENT_DATE('Asia/Seoul'), INTERVAL 7 DAY)
                    AND DATE_SUB(CURRENT_DATE('Asia/Seoul'), INTERVAL 1 DAY)
GROUP BY event_date
ORDER BY event_date
```

→ NULL 비중이 어느 정도인지 확인. 매우 높으면 recipe 의 `정보없음` 처리 정책 강조 필요.

```sql
-- user_age 계산 기준 (만 나이인지 검증) — 12월 31일 출생자 샘플
SELECT
  user_age,
  user_birth_year,
  event_date,
  DATE_DIFF(event_date, DATE(user_birth_year, 1, 1), YEAR) AS age_if_jan1,
  DATE_DIFF(event_date, DATE(user_birth_year, 12, 31), YEAR) AS age_if_dec31
FROM `hellobot-f445c.hlb_mart_integrated.union_mart_user_key_actions`
WHERE event_date = DATE_SUB(CURRENT_DATE('Asia/Seoul'), INTERVAL 1 DAY)
  AND user_birth_year IS NOT NULL
  AND user_age IS NOT NULL
LIMIT 100
```

→ `user_age` 가 어떤 기준으로 계산되었는지 (만 나이 / 한국 나이 / 단순 `현재년 - birth_year`) 검증. 그 결과를 `age_group_5yr` description 에도 정확히 명시.

### 7-3. 검증 결과 (Phase 1 — 2026-05-16 실측)

> 실행자: `/dev-data` · 실행일 KST 2026-05-16 · 누적 스캔 ~7.7 MB

#### NULL 비중 (최근 7일 `hlb_mart_integrated.union_mart_user_key_actions`)

| event_date | total_rows | null_birth_year | null_age | null_ratio |
|---|---|---|---|---|
| 2026-05-09 | 62,632 | 21,376 | 21,376 | 34.1% |
| 2026-05-10 | 63,891 | 25,195 | 25,195 | 39.4% |
| 2026-05-11 | 61,866 | 23,218 | 23,218 | 37.5% |
| 2026-05-12 | 56,740 | 20,696 | 20,696 | 36.5% |
| 2026-05-13 | 52,799 | 19,783 | 19,783 | 37.5% |
| 2026-05-14 | 50,072 | 17,404 | 17,404 | 34.8% |
| 2026-05-15 | 54,110 | 20,518 | 20,518 | 37.9% |
| **평균** | **57,444** | **21,170** | **21,170** | **~36.8%** |

- `null_birth_year ≡ null_age`, `age_null_but_birth_year_present = 0` → `user_age` 는 `user_birth_year` 에서 파생되며 두 컬럼은 페어. NULL 일관성 OK.
- 사용자 사전 게이트 30% 초과 → 진행 여부 결정 요청

#### `user_age` 계산 기준 — **단순 연도차** (만 나이 아님)

100개 샘플 모두 다음 4개 값이 동일:
- `user_age`
- `EXTRACT(YEAR FROM event_date) - SAFE_CAST(user_birth_year AS INT64)` (simple_year_diff)
- `DATE_DIFF(event_date, DATE(birth_year, 1, 1), YEAR)` (age_if_jan1)
- `DATE_DIFF(event_date, DATE(birth_year, 12, 31), YEAR)` (age_if_dec31)

→ `user_age` 는 출생년만 가지고 **`EXTRACT(YEAR FROM event_date) - user_birth_year`** (소위 "한국식 빠른 나이") 로 계산. 만 나이 X.

**영향**:
- §2 본문 "13-15만 3년 (만 13세부터 user_age 적재)" 표현 정정 필요 → "단순 연도차 13세부터" 가 정확
- `age_group_5yr` 도 동일 기준으로 분류됨 → 컬럼 description / 카탈로그에 "기준: 출생년도 단순 연도차" 명시 필요

#### 컬럼 타입 실측 (BQ `show` 기준)

| 컬럼 | 타입 | 비고 |
|---|---|---|
| `event_date` | DATE | |
| `user_id` | STRING | |
| `user_birth_year` | **STRING** | INT 가정 검증 쿼리에서 타입 오류 발생 → CAST 필요 |
| `user_age` | INTEGER | 예상 일치 |
| `age_group` | STRING | |
| `age_generation` | STRING | |

**영향**:
- 본 architecture.md §7-1 검증 쿼리·§4 recipe 패턴 A/B 의 `DATE(user_birth_year, 1, 1)` 표현 → `DATE(SAFE_CAST(user_birth_year AS INT64), 1, 1)` 로 수정 필요
- 6개 SQL 의 `age_group_5yr` CASE 는 `user_age` (INT) 만 사용 → SQL 변경 자체에는 영향 없음
- recipe 신규 작성 시 `SAFE_CAST` 적용 필수

#### 이상치

- `user_age = 0` 사례 존재 (`user_birth_year = '2026'`) — `ELSE '정보없음'` 으로 자동 흡수, 별도 처리 불필요
- (참고) 음수 (`user_birth_year > 현재년`) 케이스도 동일하게 `정보없음` 으로 흘러감

#### 카탈로그 갱신 후보 (사용자 승인 후 처리)

| 항목 | 위치 | 현재 | 제안 |
|---|---|---|---|
| `user_birth_year` 타입 STRING | `catalog/tables/mart_integrated/union_mart_user_key_actions.md` §사용자 기본 컬럼 | 컬럼명만 줄글, 타입 없음 | 본 프로젝트 Phase 4 에서 새 `age_group_5yr` 추가 시 함께 컬럼표(타입 포함)로 정형화 |
| `user_age` 가 만 나이 아닌 "단순 연도차" | 위 동일 | 정의 없음 | 컬럼 description 에 "기준: `EXTRACT(YEAR FROM event_date) - user_birth_year` (단순 연도차, 만 나이 아님)" 명시 |
| §검증 쿼리 INT 가정 | 본 architecture.md §7-1 | INT 가정 | §7-1 쿼리도 `SAFE_CAST` 로 보정 (위 §7-3 확정 후) |

### 7-2. 변경 후 검증

```sql
-- 신규 컬럼 분포 확인
SELECT
  age_group_5yr,
  COUNT(*) AS rows,
  COUNT(DISTINCT user_id) AS users
FROM `hellobot-f445c.hlb_mart_integrated.union_mart_user_key_actions`
WHERE event_date = DATE_SUB(CURRENT_DATE('Asia/Seoul'), INTERVAL 1 DAY)
GROUP BY age_group_5yr
ORDER BY age_group_5yr
```

```sql
-- age_group 과 age_group_5yr 의 매핑 정합성 (교차 분포)
SELECT
  age_group,
  age_group_5yr,
  COUNT(DISTINCT user_id) AS users
FROM `hellobot-f445c.hlb_mart_integrated.union_mart_user_key_actions`
WHERE event_date = DATE_SUB(CURRENT_DATE('Asia/Seoul'), INTERVAL 1 DAY)
GROUP BY 1, 2
ORDER BY 1, 2
```

→ `13-17` (age_group) 이 `13-15` + `16-17` (age_group_5yr 의 `13-15` + `16-20` 일부) 로 자연스럽게 분해되는지 확인.

## 8. 데이터 측정 / 이벤트 영향

- **신규 이벤트**: 없음 → `event-spec.md` 작성 불필요
- **신규 KPI**: 없음 — 기존 지표를 `age_group_5yr` 로 추가 분해할 뿐 → `data-measurement-plan.md` 작성 불필요

---

## Changelog

| 날짜 | 이슈 | 변경 내용 |
|------|------|----------|
| 2026-05-13 | 초안 | architecture.md 초안 — 버킷 정의·분류 시점 결정·6개 SQL 적용 범위·recipe 표준화 방침 |
| 2026-05-16 | Phase 1 검증 | §7-3 검증 결과 추가 — NULL ~36.8% (사전 게이트 30% 초과), `user_age` = 단순 연도차(만나이 아님), `user_birth_year` STRING 발견, 카탈로그 갱신 후보 3건 식별 |
| 2026-05-16 | Phase 3 경로 정정 | §5 의 SQL 파일 경로 `scripts/hellobot/...` → `dags/scripts/hellobot/...` 정정 (실 위치 기준) |
