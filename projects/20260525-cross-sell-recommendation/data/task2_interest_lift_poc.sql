-- 과제2 근본: 노출정규화 interest_lift 개념검증 (A 앱퍼스트, 최근 12m cohort)
-- interest_lift(B|A) = P(B구매 | B상세조회·A이후) / P(B구매 | B상세조회)
-- 자기강화 pair = 구매 co-occurrence는 높지만 노출 대비 전환은 평범 → lift≈1로 수렴해야 함
WITH pays AS (
  SELECT user_id, event_timestamp AS ts, menu_seq,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_timestamp) rn
  FROM `hellobot-f445c.hlb_mart.mart_use_skill_se`
  WHERE event_date BETWEEN '2025-03-01' AND '2026-02-28'
    AND event_name LIKE 'pay_for_%' AND revenue_krw > 0 AND platform IN ('IOS','ANDROID')
),
first_buy AS (SELECT user_id, menu_seq AS A, ts AS f_ts FROM pays WHERE rn = 1),
buys AS (SELECT user_id, menu_seq AS B, ts AS b_ts FROM pays),
views AS (
  SELECT user_id, menu_seq AS B, event_timestamp AS v_ts
  FROM `hellobot-f445c.hlb_mart.mart_v2_skill_funnel_fb`
  WHERE event_date BETWEEN '2025-03-01' AND '2026-02-28'
    AND event_name = 'open_skill_description' AND platform IN ('IOS','ANDROID')
),
va AS (   -- A 구매 후 B 상세조회(B≠A), 유저별 최초 조회시각
  SELECT f.A, vw.B, vw.user_id, MIN(vw.v_ts) AS v_ts
  FROM views vw JOIN first_buy f
    ON vw.user_id = f.user_id AND vw.v_ts > f.f_ts AND vw.B != f.A
  GROUP BY 1,2,3
),
conv AS (  -- 조회 후 14일내 B 구매한 유저
  SELECT va.A, va.B,
    COUNT(*) AS viewers,
    COUNT(DISTINCT IF(b.b_ts BETWEEN va.v_ts AND TIMESTAMP_ADD(va.v_ts, INTERVAL 14 DAY), va.user_id, NULL)) AS buyers
  FROM va LEFT JOIN buys b ON b.user_id = va.user_id AND b.B = va.B
  GROUP BY 1,2
),
vbase AS (SELECT B, user_id, MIN(v_ts) v_ts FROM views GROUP BY 1,2),
base AS (  -- B의 전체 조회→구매 base 전환율
  SELECT vb.B,
    COUNT(*) AS v_all,
    COUNT(DISTINCT IF(b.b_ts BETWEEN vb.v_ts AND TIMESTAMP_ADD(vb.v_ts, INTERVAL 14 DAY), vb.user_id, NULL)) AS buy_all
  FROM vbase vb LEFT JOIN buys b ON b.user_id = vb.user_id AND b.B = vb.B
  GROUP BY 1
)
SELECT c.A, c.B, c.viewers, c.buyers,
  ROUND(c.buyers/c.viewers, 3) AS cvr_from_A,
  ROUND(bs.buy_all/bs.v_all, 3) AS base_cvr,
  ROUND(SAFE_DIVIDE(c.buyers/c.viewers, NULLIF(bs.buy_all/bs.v_all, 0)), 2) AS interest_lift
FROM conv c JOIN base bs ON bs.B = c.B
WHERE c.viewers >= 30
ORDER BY c.viewers DESC
LIMIT 400
