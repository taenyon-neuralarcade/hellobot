-- REVISION 3 master export — pay_for_% ONLY (pay_under_750 등 마이크로거래 제외)
-- A 앱퍼스트 신규코호트 + 1st/2nd 구매속성 + 30/60/90 윈도우 재구매 플래그
-- ★ REV3 추가: r_* = "첫 다른날(익일+) 90일 내 구매" = 진짜 재방문 SKU (전이/형식분석용 올바른 모집단)
WITH pays AS (
  SELECT user_id, event_timestamp, event_date, menu_seq, revenue_krw, user_age,
    CASE WHEN platform IN ('IOS','ANDROID') THEN 'APP' WHEN platform='WEB' THEN 'WEB' ELSE 'U' END AS plat
  FROM `hellobot-f445c.hlb_mart.mart_use_skill_se`
  WHERE event_name LIKE 'pay_for_%' AND revenue_krw > 0   -- ★ pay_for_ only
),
ordp AS (
  SELECT user_id, event_timestamp AS ts, event_date AS d, menu_seq, revenue_krw, user_age, plat,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_timestamp ASC) AS rn
  FROM pays
),
first_p AS (SELECT user_id, ts f_ts, d f_d, menu_seq f_menu, revenue_krw f_rev, user_age age, plat f_plat FROM ordp WHERE rn=1),
second_p AS (SELECT user_id, ts s_ts, d s_d, menu_seq s_menu, revenue_krw s_rev FROM ordp WHERE rn=2),
agg AS (
  SELECT user_id,
    ARRAY_AGG(STRUCT(ts, d, menu_seq, revenue_krw AS rev) ORDER BY ts) AS allp,
    COUNT(*) AS total_pays
  FROM ordp GROUP BY user_id
),
fm AS (SELECT menu_seq, ANY_VALUE(chatbot_content_type) ctype FROM `hellobot-f445c.hlb_mart.mart_fixed_menu_server` GROUP BY menu_seq),
tg AS (SELECT menu_seq, ANY_VALUE(topic) topic, ANY_VALUE(intents) intents FROM `hellobot-f445c.google_sheet_sync.taenyon_temp_skill_tag_info_v2` GROUP BY menu_seq),
base AS (
  SELECT
    EXTRACT(YEAR FROM f.f_d) AS f_year,
    f.age,
    f.f_menu, f.f_rev, tg1.topic AS f_topic, tg1.intents AS f_intents, fm1.ctype AS f_ctype,
    a.total_pays,
    (SELECT COUNTIF(x.ts>f.f_ts AND DATE_DIFF(x.d,f.f_d,DAY)<=30) FROM UNNEST(a.allp) x) AS c_any30,
    (SELECT COUNTIF(x.ts>f.f_ts AND DATE_DIFF(x.d,f.f_d,DAY)<=60) FROM UNNEST(a.allp) x) AS c_any60,
    (SELECT COUNTIF(x.ts>f.f_ts AND DATE_DIFF(x.d,f.f_d,DAY)<=90) FROM UNNEST(a.allp) x) AS c_any90,
    (SELECT COUNTIF(x.d>f.f_d AND DATE_DIFF(x.d,f.f_d,DAY)<=30) FROM UNNEST(a.allp) x) AS c_rev30,
    (SELECT COUNTIF(x.d>f.f_d AND DATE_DIFF(x.d,f.f_d,DAY)<=60) FROM UNNEST(a.allp) x) AS c_rev60,
    (SELECT COUNTIF(x.d>f.f_d AND DATE_DIFF(x.d,f.f_d,DAY)<=90) FROM UNNEST(a.allp) x) AS c_rev90,
    (SELECT COUNTIF(x.ts>f.f_ts AND x.d=f.f_d) FROM UNNEST(a.allp) x) AS c_sameday,
    s.s_menu, s.s_rev, tg2.topic AS s_topic, tg2.intents AS s_intents, fm2.ctype AS s_ctype,
    IF(s.user_id IS NULL,0,1) AS has_2nd,
    IF(s.s_d = f.f_d,1,0) AS second_sameday,
    IF(s.user_id IS NOT NULL, DATE_DIFF(s.s_d,f.f_d,DAY), NULL) AS days_to_2nd,
    IF(s.s_menu = f.f_menu,1,0) AS same_menu,
    -- ★ REV3: 첫 다른날(익일+) 90일 내 구매 = 진짜 재방문 SKU
    (SELECT AS STRUCT x.menu_seq, x.rev, DATE_DIFF(x.d,f.f_d,DAY) AS dd
     FROM UNNEST(a.allp) x
     WHERE x.d>f.f_d AND DATE_DIFF(x.d,f.f_d,DAY)<=90
     ORDER BY x.ts ASC LIMIT 1) AS rv,
    f.f_menu AS _fmenu_for_rev
  FROM first_p f
  JOIN agg a ON a.user_id=f.user_id
  LEFT JOIN second_p s ON s.user_id=f.user_id
  LEFT JOIN fm fm1 ON fm1.menu_seq=f.f_menu
  LEFT JOIN fm fm2 ON fm2.menu_seq=s.s_menu
  LEFT JOIN tg tg1 ON tg1.menu_seq=f.f_menu
  LEFT JOIN tg tg2 ON tg2.menu_seq=s.s_menu
  WHERE f.f_plat='APP' AND f.f_d BETWEEN DATE '2024-03-02' AND DATE '2026-03-02'
)
SELECT b.* EXCEPT(rv, _fmenu_for_rev),
  b.rv.menu_seq AS r_menu,
  b.rv.rev AS r_rev,
  b.rv.dd AS days_to_rev,
  tg3.topic AS r_topic,
  fm3.ctype AS r_ctype,
  IF(b.rv.menu_seq = b._fmenu_for_rev, 1, 0) AS rev_same_menu
FROM base b
LEFT JOIN fm fm3 ON fm3.menu_seq=b.rv.menu_seq
LEFT JOIN tg tg3 ON tg3.menu_seq=b.rv.menu_seq;
