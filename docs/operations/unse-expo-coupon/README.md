# 2026 운세박람회 — 푸시온 유저 쿠폰 대상 추출

> 요청(REQ-002, 2026-06-09): 운세박람회 두 스킬 "소비 블록 진입" 유저 중 6/7까지 푸시온 유지 유저 추출 (쿠폰 지급용)

## 결과 요약

| 단계 | 인원 |
|---|---|
| 소비 블록 진입 코호트 (`consume_skill`, 둘 중 하나 이상) | **649** |
| └ 판밍밍(61036) 소비 | 589 |
| └ 라마마(61069) 소비 | 127 |
| └ 둘 다 소비 | 67 |
| **최종 — 마케팅 푸시온 (`os_on AND day_on`)** | **179** |

최종 179명 스킬 분포: 판밍밍만 116 · 라마마만 19 · 둘 다 44

**산출 파일**: [`pushon-users-marketing-20260609.csv`](./pushon-users-marketing-20260609.csv) (179행, 컬럼: `user_id, used_panmingming, used_ramama, push_os_on, push_day_on, push_app_on`)
**재현 쿼리**: [`extract-pushon-users.sql`](./extract-pushon-users.sql)

## 정의 및 가설 (검증 필요 표시)

### 1. "소비 블록 진입" = `consume_skill` 이벤트 ✅ 실측 기반
`hlb_mart.mart_use_skill_se` 실측(2026-06-09)으로 두 스킬을 menu_seq로 특정:

| 스킬 | menu_seq | consume_skill 블록 | 소비 유저 |
|---|---|---|---|
| 오행 사주 풀이 […판밍밍] | 61036 | 2125754 "운세박람회_생일받기" | 589 |
| 자유상담권 선물 […라마마] | 61069 | 2123040 "[LLM박람회] 멘트" | 127 |

소비 블록에서 발화하는 `consume_skill`을 "소비 블록 진입"으로 정의. (`enter_skill`은 인트로/로그인 블록에서 발화 — 별개)

### 2. "푸시온" = 마케팅 푸시 수신 가능 (`push_os_on=true AND push_day_on=true`) ⚠️ 정의 선택
쿠폰은 마케팅성 푸시이므로 카탈로그의 `marketing_push_user` 정의 채택. 원천: `server_rdb.user_push_settings` → `hlb_mart.mart_user_server`.

코호트 649명 기준 정의별 인원 (다른 정의로 즉시 재추출 가능):

| 정의 | 조건 | 인원 |
|---|---|---|
| **마케팅 푸시 (채택)** | `os_on AND day_on` | **179** |
| 정보성 푸시 | `os_on AND in_app_on` | 192 |
| OS 알림 권한 | `os_on` | 227 |
| 앱 푸시 마스터 토글 | `app_on` | 191 |

### 3. "6/7까지 유지" — 최신 스냅샷이 6/7 상태와 일치 ✅ 교차검증
`mart_user_server` / `user_push_settings`는 일별 히스토리 없는 **최신 스냅샷**(`CREATE OR REPLACE` / RDS 일별 export 덮어쓰기). 따라서 과거 특정일 상태를 일반적으로 재구성 불가.
단, 본 코호트 179명 **전원이 푸시 설정을 2026-06-06 01:59 이전 마지막 변경**(`user_push_settings.updated_at` max=2026-06-06) → 6/7 이후 변경자 0명이므로 **최신 스냅샷 = 6/7 시점 상태로 정확히 일치**. mart_user_server·user_push_settings 양쪽 179명 동일.

## 데이터 출처

- 스킬·이벤트: `hlb_mart.mart_use_skill_se` (서버 이벤트 기반 스킬 진입·소비)
- 푸시 설정: `hlb_mart.mart_user_server` ← `hlb_staging.staging_user_server` ← `server_rdb.user_push_settings`
- 푸시온 정의 근거: `dags/scripts/hellobot/report/report_crm_optin_total.sql` (marketing/info push 정의)

## 서버 DB 대조 (BQ 스냅샷 vs 라이브 PG)

BQ `server_rdb.*`는 RDS 일별 스냅샷이라 라이브 운영 PG와 시점 차이가 있을 수 있어, 코호트 전원(649명)을 라이브 서버 DB와 대조.

- **BQ 기준값**: [`bq-pushsettings-cohort649-20260609.csv`](./bq-pushsettings-cohort649-20260609.csv) (649행, 스냅샷 푸시설정 + `marketing_push_on` + 스냅샷 `updated_at`)
- **PG 추출 쿼리**: [`extract-pushsettings-serverdb.sql`](./extract-pushsettings-serverdb.sql) — 운영 PostgreSQL(`thingsflow` 스키마)에서 실행, BQ와 동일 컬럼·순서로 649행 반환

**PG 스키마 근거** (hellobot-server, SnakeNamingStrategy + `thingsflow` 스키마):
- 엔티티 `UserPushSettings` → 테이블 `thingsflow.user_push_settings` (PK `seq`, FK `user_seq`)
- 컬럼 snake_case: `os_on`/`day_on`/`app_on`/`night_on`/`updated_at` — BQ `server_rdb.user_push_settings` 스냅샷과 컬럼명 동일

**BQ 스냅샷 분포** (대조 기준): `marketing_push_on` = true **179** / false **455** / NULL **15**(설정행 없음)

### 대조 결과 (2026-06-09) — 100% 일치 ✅

PG 결과 파일: [`pg-pushsettings-cohort649-20260609.csv`](./pg-pushsettings-cohort649-20260609.csv) (라이브 서버 DB, 649행)

| 항목 | 결과 |
|---|---|
| user_id 집합 (BQ 649 ↔ PG 649) | 완전 동일 |
| `marketing_push_on` 분포 | BQ·PG 모두 **true 179 / false 455 / 설정행없음 15** |
| 필드 불일치 (`os_on`·`day_on`·`app_on`·`night_on`·`marketing_push_on`) | 전부 **0건** |
| `updated_at` 변경 | **0건** (전원 스냅샷=라이브 동일 시각, max 2026-06-06) |
| 설정행 없는 15명 | BQ·PG 동일 집합 |

**결론**: BQ `server_rdb.user_push_settings` 스냅샷 = 라이브 PG `thingsflow.user_push_settings` 완전 일치. **최종 쿠폰 대상 179명 운영 DB 검증 완료** (= [`pushon-users-marketing-20260609.csv`](./pushon-users-marketing-20260609.csv)). 설정행 없는 15명은 라이브에도 동일하게 없음 → 마케팅 푸시 수신 불가, 대상 제외 정당.
