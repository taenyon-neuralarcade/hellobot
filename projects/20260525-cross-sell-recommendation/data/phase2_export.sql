-- Phase 2 per-user export — A 앱퍼스트 신규코호트 (101,465) + topic/intents/content_type 조인
-- 출력: 사용자 1명 = 1행. 이후 모든 슬라이싱은 로컬에서 (추가 BQ 스캔 0)
WITH pays AS (
  SELECT user_id, event_timestamp, event_date, menu_seq, revenue_krw, user_age,
    CASE WHEN platform IN ('IOS','ANDROID') THEN 'APP' WHEN platform='WEB' THEN 'WEB' ELSE 'U' END AS plat
  FROM `hellobot-f445c.hlb_mart.mart_use_skill_se`
  WHERE event_name LIKE 'pay_%' AND revenue_krw > 0
),
u AS (
  SELECT user_id,
    ARRAY_AGG(STRUCT(event_timestamp AS ts, event_date AS d, menu_seq AS m, revenue_krw AS rev, user_age AS age, plat)
              ORDER BY event_timestamp ASC LIMIT 1)[OFFSET(0)] AS f,
    ARRAY_AGG(STRUCT(event_timestamp AS ts, event_date AS d)) AS allp
  FROM pays GROUP BY user_id
),
base AS (
  SELECT user_id, u.f,
    (SELECT COUNTIF(x.ts>u.f.ts AND DATE_DIFF(x.d,u.f.d,DAY)<=30) FROM UNNEST(u.allp) x) AS c_any30,
    (SELECT COUNTIF(x.ts>u.f.ts AND DATE_DIFF(x.d,u.f.d,DAY)<=60) FROM UNNEST(u.allp) x) AS c_any60,
    (SELECT COUNTIF(x.ts>u.f.ts AND DATE_DIFF(x.d,u.f.d,DAY)<=90) FROM UNNEST(u.allp) x) AS c_any90,
    (SELECT COUNTIF(x.d>u.f.d AND DATE_DIFF(x.d,u.f.d,DAY)<=90) FROM UNNEST(u.allp) x) AS c_rev90,
    (SELECT COUNTIF(x.ts>u.f.ts AND x.d=u.f.d) FROM UNNEST(u.allp) x) AS c_sameday,
    (SELECT MIN(IF(x.d>u.f.d, DATE_DIFF(x.d,u.f.d,DAY), NULL)) FROM UNNEST(u.allp) x) AS days_to_revisit
  FROM u
  WHERE u.f.plat='APP' AND u.f.d BETWEEN DATE '2024-03-02' AND DATE '2026-03-02'
),
fm AS (
  SELECT menu_seq, ANY_VALUE(chatbot_content_type) AS content_type
  FROM `hellobot-f445c.hlb_mart.mart_fixed_menu_server` GROUP BY menu_seq
)
SELECT
  EXTRACT(YEAR FROM b.f.d) AS f_year,
  b.f.age AS age,
  b.f.rev AS first_rev,
  t.topic AS topic,
  t.intents AS intents,
  fm.content_type AS content_type,
  IF(b.c_any30>0,1,0) AS any30,
  IF(b.c_any60>0,1,0) AS any60,
  IF(b.c_any90>0,1,0) AS any90,
  IF(b.c_rev90>0,1,0) AS rev90,
  IF(b.c_sameday>0,1,0) AS sameday,
  b.days_to_revisit AS days_to_revisit
FROM base b
LEFT JOIN `hellobot-f445c.google_sheet_sync.taenyon_temp_skill_tag_info_v2` t ON t.menu_seq=b.f.m
LEFT JOIN fm ON fm.menu_seq=b.f.m;
