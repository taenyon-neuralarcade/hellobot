-- Phase 3 per-user export — A 앱퍼스트 신규코호트, 1st + 2nd 구매 속성 (transition 분석용)
-- 2번째 구매 = 첫 결제 이후(타임스탬프) 최초 결제. 동일일 포함 여부 플래그 별도.
WITH pays AS (
  SELECT user_id, event_timestamp, event_date, menu_seq, revenue_krw, user_age,
    CASE WHEN platform IN ('IOS','ANDROID') THEN 'APP' WHEN platform='WEB' THEN 'WEB' ELSE 'U' END AS plat
  FROM `hellobot-f445c.hlb_mart.mart_use_skill_se`
  WHERE event_name LIKE 'pay_%' AND revenue_krw > 0
),
ord AS (
  SELECT user_id, event_timestamp AS ts, event_date AS d, menu_seq, revenue_krw, user_age, plat,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_timestamp ASC) AS rn
  FROM pays
),
first_p AS (
  SELECT user_id, ts AS f_ts, d AS f_d, menu_seq AS f_menu, revenue_krw AS f_rev, user_age AS age, plat AS f_plat
  FROM ord WHERE rn = 1
),
second_p AS (
  SELECT user_id, ts AS s_ts, d AS s_d, menu_seq AS s_menu, revenue_krw AS s_rev
  FROM ord WHERE rn = 2
),
fm AS (
  SELECT menu_seq, ANY_VALUE(chatbot_content_type) AS ctype, ANY_VALUE(menu_name) AS mname
  FROM `hellobot-f445c.hlb_mart.mart_fixed_menu_server` GROUP BY menu_seq
),
tg AS (
  SELECT menu_seq, ANY_VALUE(topic) AS topic, ANY_VALUE(intents) AS intents
  FROM `hellobot-f445c.google_sheet_sync.taenyon_temp_skill_tag_info_v2` GROUP BY menu_seq
)
SELECT
  f.user_id,
  f.age,
  -- 1st
  f.f_menu,
  f.f_rev,
  tg1.topic        AS f_topic,
  tg1.intents      AS f_intents,
  fm1.ctype        AS f_ctype,
  -- 2nd (NULL이면 재구매 없음)
  s.s_menu,
  s.s_rev,
  tg2.topic        AS s_topic,
  tg2.intents      AS s_intents,
  fm2.ctype        AS s_ctype,
  IF(s.user_id IS NULL, 0, 1)                          AS has_2nd,
  IF(s.s_d = f.f_d, 1, 0)                              AS second_sameday,
  IF(s.user_id IS NOT NULL, DATE_DIFF(s.s_d, f.f_d, DAY), NULL) AS days_to_2nd,
  IF(s.s_menu = f.f_menu, 1, 0)                        AS same_menu
FROM first_p f
LEFT JOIN second_p s ON s.user_id = f.user_id
LEFT JOIN fm fm1 ON fm1.menu_seq = f.f_menu
LEFT JOIN fm fm2 ON fm2.menu_seq = s.s_menu
LEFT JOIN tg tg1 ON tg1.menu_seq = f.f_menu
LEFT JOIN tg tg2 ON tg2.menu_seq = s.s_menu
WHERE f.f_plat = 'APP' AND f.f_d BETWEEN DATE '2024-03-02' AND DATE '2026-03-02';
