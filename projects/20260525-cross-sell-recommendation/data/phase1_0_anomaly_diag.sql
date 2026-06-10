-- Phase 1.0 진단 — X_anomaly (first_paid_date > first_app_paid_date) 원인 규명
-- 실행: 2026-05-31
--
-- [진단 1] gap 분포 (스캔 ~4.65 GB)
--   결과: x_users=19,789 / gap_1d=978 / gap_2-7d=2,051 / gap_8-30d=2,547 / gap_>30d=14,213
--          quartiles=[1,21,186,623,1902] / max=1902일(5.2년)
--   → 단순 타임존 1일 오차 아님. 72%가 30일 초과 gap → 구조적 정의 차이.
WITH u AS (
  SELECT
    user_id,
    ANY_VALUE(user_first_paid_date)     AS first_paid_date,
    ANY_VALUE(user_first_app_paid_date) AS first_app_paid_date
  FROM `hellobot-f445c.hlb_mart_integrated.union_mart_user_key_actions`
  WHERE user_first_paid_date IS NOT NULL
  GROUP BY user_id
),
x AS (
  SELECT DATE_DIFF(first_paid_date, first_app_paid_date, DAY) AS gap_days
  FROM u
  WHERE first_app_paid_date IS NOT NULL AND first_paid_date > first_app_paid_date
)
SELECT
  COUNT(*) AS x_users,
  COUNTIF(gap_days = 1) AS gap_1d,
  COUNTIF(gap_days BETWEEN 2 AND 7) AS gap_2_7d,
  COUNTIF(gap_days BETWEEN 8 AND 30) AS gap_8_30d,
  COUNTIF(gap_days > 30) AS gap_over_30d,
  APPROX_QUANTILES(gap_days, 4) AS gap_quartiles,
  MAX(gap_days) AS gap_max
FROM x;

-- [진단 2] content_type null by group (스캔 ~5.74 GB)
--   결과: X_anomaly 19,789명 중 fp_ctype_null=312 (거의 전원 스킬결제 이력 보유)
--   → X_anomaly는 "스킬결제 없는 이상치"가 아니라, 통합/앱 컬럼의 소스 정의 차이에서 발생
--
-- [근본 원인] (SQL 정의 분석, union_mart_user_key_actions.sql)
--   first_paid_date (L575~581): union_user_actions 의 MIN(결제 event_date)
--       = pay_for_* + in_app_purchase/purchase, 전 플랫폼
--   first_app_paid_date (L466~474): app_pay_for_skill_with_type WHERE order=1
--       = mart_use_skill_se 의 pay_for_* 만, platform IN (IOS,ANDROID)
--   → 두 컬럼은 모집단·소스가 달라 "통합 ⊇ 앱" 포함관계가 성립하지 않음.
--     비교 기반 채널 분류는 근사치이며, X_anomaly(1.6%)는 별도 처리 필요.
