-- REVISION 3 Phase 2 검증 배치 — pay_% 1회 스캔으로 4개 항목 동시 확인
--   (1) maturity: pay_for_ 이벤트 min/max event_date  (#7)
--   (2) left-censoring/re-dating: 첫 pay_%가 첫 pay_for_%보다 앞선(=마이크로 선행) 유저 수  (#7)
--   (3) 채널 재사이징: pay_for_ 기준 첫구매 플랫폼 A/WEB 분포  (#6)
--   (4) B 누수: pay_for_ 앱퍼스트인데 그 전에 WEB pay_%가 있던 유저 수  (#6/#8)
WITH p AS (
  SELECT user_id, event_timestamp AS ts, event_date AS d,
    CASE WHEN platform IN ('IOS','ANDROID') THEN 'APP' WHEN platform='WEB' THEN 'WEB' ELSE 'U' END AS plat,
    event_name
  FROM `hellobot-f445c.hlb_mart.mart_use_skill_se`
  WHERE event_name LIKE 'pay_%' AND revenue_krw > 0
),
peruser AS (
  SELECT user_id,
    MIN(ts) AS first_any_ts,
    ARRAY_AGG(plat ORDER BY ts ASC LIMIT 1)[OFFSET(0)] AS first_any_plat,
    MIN(IF(event_name LIKE 'pay_for_%', ts, NULL)) AS first_for_ts,
    ARRAY_AGG(IF(event_name LIKE 'pay_for_%', plat, NULL) IGNORE NULLS ORDER BY ts ASC LIMIT 1)[SAFE_OFFSET(0)] AS first_for_plat
  FROM p GROUP BY user_id
)
SELECT
  (SELECT MIN(d) FROM p) AS pay_min_date,
  (SELECT MAX(d) FROM p) AS pay_max_date,
  COUNT(*) AS users_any_pay,
  COUNTIF(first_for_plat IS NOT NULL) AS users_forpay,
  COUNTIF(first_for_plat='APP') AS A_appfirst_forpay,
  COUNTIF(first_for_plat='WEB') AS web_first_forpay,
  COUNTIF(first_for_ts > first_any_ts) AS redated_microfirst_users,
  COUNTIF(first_for_plat='APP' AND first_any_ts < first_for_ts AND first_any_plat='WEB') AS A_with_prior_web_pay
FROM peruser;
