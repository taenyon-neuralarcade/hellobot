-- Phase 1.0 — 첫구매 채널 3그룹 사이징
-- 출처: hlb_mart_integrated.union_mart_user_key_actions (event-grain → user 단위 dedup)
-- 실행: 2026-05-31, 스캔 ~6.1 GB
--
-- ★ 채널 판별 컬럼 (실제 스키마 검증, 132컬럼 중):
--   user_first_paid_date      (DATE) — 통합 첫구매일
--   user_first_app_paid_date  (DATE) — 앱 첫구매일
--   user_second_paid_date     (DATE) / user_second_app_paid_date (DATE)
--   ※ user_* 컬럼은 전체기간 집계값이 모든 event 행에 반복 → user_id GROUP BY + ANY_VALUE 로 dedup
--
-- ⚠ 두 컬럼의 소스 정의가 다름 (X_anomaly 원인):
--   first_paid_date     = union_user_actions 기반, 모든 결제(pay_for_* + in_app_purchase/purchase), 전 플랫폼의 MIN(event_date)
--   first_app_paid_date = mart_use_skill_se 기반, 앱 스킬결제(pay_for_*)만, IOS/ANDROID, order=1
--   → 두 컬럼 직접 비교(=,<,>) 시 정의 불일치로 X_anomaly(fp>fap) 발생 (1.6%)
--   → 정밀 채널 판별은 raw 결제이벤트로 재계산 필요 (Phase 1.1 후보)

WITH u AS (
  SELECT
    user_id,
    ANY_VALUE(user_first_paid_date)       AS first_paid_date,
    ANY_VALUE(user_first_app_paid_date)   AS first_app_paid_date,
    ANY_VALUE(user_second_paid_date)      AS second_paid_date,
    ANY_VALUE(user_second_app_paid_date)  AS second_app_paid_date
  FROM `hellobot-f445c.hlb_mart_integrated.union_mart_user_key_actions`
  WHERE user_first_paid_date IS NOT NULL
  GROUP BY user_id
)
SELECT
  CASE
    WHEN first_app_paid_date IS NULL           THEN 'C_web_only'
    WHEN first_paid_date = first_app_paid_date  THEN 'A_app_first'
    WHEN first_paid_date < first_app_paid_date  THEN 'B_web_to_app'
    ELSE 'X_anomaly'
  END AS channel_group,
  COUNT(*)                                       AS users,
  COUNTIF(second_paid_date IS NOT NULL)          AS users_2nd_any,
  COUNTIF(second_app_paid_date IS NOT NULL)      AS users_2nd_app
FROM u
GROUP BY channel_group
ORDER BY users DESC;
