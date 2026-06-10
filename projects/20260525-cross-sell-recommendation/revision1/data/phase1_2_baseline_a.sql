-- Phase 1.2 Baseline — A 앱퍼스트 신규 코호트 (단일 스캔, GROUPING SETS)
-- 대상: 첫 콘텐츠결제(pay_% & revenue>0)가 APP & 첫구매일 ∈ [2024-03-02, 2026-03-02]
-- topic 정규화: 제안 병합안. content_type = chatbot_category. 태그조인 menu_seq.
WITH pays AS (
  SELECT
    user_id,
    event_timestamp,
    event_date,
    menu_seq,
    chatbot_category,
    revenue_krw,
    user_age,
    user_gender,
    CASE WHEN platform IN ('IOS','ANDROID') THEN 'APP'
         WHEN platform = 'WEB' THEN 'WEB' ELSE 'U' END AS plat
  FROM `hellobot-f445c.hlb_mart.mart_use_skill_se`
  WHERE event_name LIKE 'pay_%' AND revenue_krw > 0
),
u AS (
  SELECT
    user_id,
    ARRAY_AGG(STRUCT(event_timestamp AS ts, event_date AS d, menu_seq AS m,
                     chatbot_category AS cat, revenue_krw AS rev,
                     user_age AS age, user_gender AS g, plat)
              ORDER BY event_timestamp ASC LIMIT 1)[OFFSET(0)] AS f,
    ARRAY_AGG(STRUCT(event_timestamp AS ts, event_date AS d)) AS allp
  FROM pays
  GROUP BY user_id
),
base AS (
  SELECT
    u.user_id,
    u.f,
    (SELECT COUNTIF(x.ts > u.f.ts AND DATE_DIFF(x.d, u.f.d, DAY) <= 30) FROM UNNEST(u.allp) x) AS c_any30,
    (SELECT COUNTIF(x.ts > u.f.ts AND DATE_DIFF(x.d, u.f.d, DAY) <= 60) FROM UNNEST(u.allp) x) AS c_any60,
    (SELECT COUNTIF(x.ts > u.f.ts AND DATE_DIFF(x.d, u.f.d, DAY) <= 90) FROM UNNEST(u.allp) x) AS c_any90,
    (SELECT COUNTIF(x.d > u.f.d AND DATE_DIFF(x.d, u.f.d, DAY) <= 30) FROM UNNEST(u.allp) x) AS c_rev30,
    (SELECT COUNTIF(x.d > u.f.d AND DATE_DIFF(x.d, u.f.d, DAY) <= 60) FROM UNNEST(u.allp) x) AS c_rev60,
    (SELECT COUNTIF(x.d > u.f.d AND DATE_DIFF(x.d, u.f.d, DAY) <= 90) FROM UNNEST(u.allp) x) AS c_rev90,
    (SELECT COUNTIF(x.ts > u.f.ts AND x.d = u.f.d) FROM UNNEST(u.allp) x) AS c_sameday,
    (SELECT MIN(IF(x.d > u.f.d, DATE_DIFF(x.d, u.f.d, DAY), NULL)) FROM UNNEST(u.allp) x) AS days_to_revisit
  FROM u
  WHERE u.f.plat = 'APP'
    AND u.f.d BETWEEN DATE '2024-03-02' AND DATE '2026-03-02'
),
cohort AS (
  SELECT
    b.user_id,
    b.f.age AS age,
    b.f.g AS gender,
    EXTRACT(YEAR FROM b.f.d) AS f_year,
    b.f.cat AS f_cat,
    CASE
      WHEN t.menu_seq IS NULL OR t.topic IS NULL THEN '(미태깅)'
      WHEN t.topic IN ('연애','연애운','연애일반','애정','애정운','연애시기') THEN '연애'
      WHEN t.topic IN ('재물','재물운') THEN '재물'
      WHEN t.topic IN ('신년','신년운세') THEN '신년'
      WHEN t.topic IN ('취업','취업운') THEN '취업'
      WHEN t.topic IN ('직업','직장운') THEN '직업'
      WHEN t.topic IN ('궁합','궁합운') THEN '궁합'
      ELSE t.topic
    END AS topic_norm,
    IF(t.menu_seq IS NOT NULL, 1, 0) AS matched,
    b.c_any30, b.c_any60, b.c_any90,
    b.c_rev30, b.c_rev60, b.c_rev90,
    b.c_sameday, b.days_to_revisit
  FROM base b
  LEFT JOIN `hellobot-f445c.google_sheet_sync.taenyon_temp_skill_tag_info_v2` t
    ON t.menu_seq = b.f.m
)
SELECT
  CASE
    WHEN GROUPING(f_year) = 0 THEN CONCAT('year:', CAST(f_year AS STRING))
    WHEN GROUPING(topic_norm) = 0 THEN CONCAT('topic:', topic_norm)
    WHEN GROUPING(f_cat) = 0 THEN CONCAT('cat:', IFNULL(f_cat, '(n)'))
    ELSE 'overall'
  END AS bucket,
  COUNT(*) AS users,
  ROUND(100 * AVG(IF(c_any30 > 0, 1, 0)), 1) AS any30,
  ROUND(100 * AVG(IF(c_any60 > 0, 1, 0)), 1) AS any60,
  ROUND(100 * AVG(IF(c_any90 > 0, 1, 0)), 1) AS any90,
  ROUND(100 * AVG(IF(c_rev90 > 0, 1, 0)), 1) AS rev90,
  ROUND(100 * AVG(IF(c_sameday > 0, 1, 0)), 1) AS sameday,
  ROUND(100 * AVG(matched), 1) AS tag_cov,
  ROUND(100 * AVG(IF(age IS NULL, 0, 1)), 1) AS age_fill,
  ROUND(100 * AVG(IF(gender IS NULL OR gender = '', 0, 1)), 1) AS gender_fill,
  CAST(APPROX_QUANTILES(days_to_revisit, 4)[OFFSET(2)] AS INT64) AS rev_days_med
FROM cohort
GROUP BY GROUPING SETS ((), (f_year), (topic_norm), (f_cat))
ORDER BY bucket;
