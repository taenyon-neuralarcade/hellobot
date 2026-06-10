-- REVISION 3 #9: pay_for_ 이벤트가 한 결제당 다건 발화되는지 점검
-- raw 행수 vs (user_id, event_timestamp, menu_seq, revenue_krw) 중복제거 행수 비교.
-- 둘이 같으면 dedup 불필요(이벤트=구매 1:1), 차이 크면 count/sameday 인플레 위험.
SELECT
  COUNT(*) AS raw_rows,
  COUNT(DISTINCT FORMAT('%T|%T|%T|%T', user_id, event_timestamp, menu_seq, revenue_krw)) AS dedup_rows,
  COUNT(*) - COUNT(DISTINCT FORMAT('%T|%T|%T|%T', user_id, event_timestamp, menu_seq, revenue_krw)) AS dup_rows,
  COUNT(DISTINCT user_id) AS users
FROM `hellobot-f445c.hlb_mart.mart_use_skill_se`
WHERE event_name LIKE 'pay_for_%' AND revenue_krw > 0;
