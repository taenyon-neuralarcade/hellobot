-- Phase 1.1 (β) — 정밀 채널 재분류 (raw 결제이벤트 단일 소스)
-- 출처: hlb_mart.mart_use_skill_se (콘텐츠 결제)
-- 실행: 2026-05-31, 스캔 10.98 GB (dry-run 10,978,107,047 bytes)
--   ※ stdin 방식 실행: bq ... < beta.sql (heredoc 한글주석이 셸 파싱 깨뜨려 파일 경유로 전환)
--
-- 채택 배경: 마트 컬럼(user_first_paid_date vs user_first_app_paid_date) 비교 채널판별은
--   두 컬럼 소스 정의 차이로 X_anomaly 1.6% 발생 (Phase 1.0). β로 단일소스 재계산하여 제거.
--
-- 콘텐츠 구매 정의: event_name LIKE 'pay_%' AND revenue_krw > 0
--   포함: pay_for_contents / pay_under_750 / pay_for_package / pay_for_collection /
--         pay_for_coaching_program / pay_for_chatbot_subscription
--   제외: enter_skill·consume_skill(무료), 스토어 IAP(mart_purchase_fb=하트충전, 콘텐츠 아님)
--
-- platform 분포 검증 (pay_% & revenue>0, 별도 쿼리):
--   IOS 316,616 / ANDROID 203,754 / WEB 831,602 / null 2 users → WEB 콘텐츠 결제 실재, β 유효
--
-- 첫구매 플랫폼: 최초 결제 event_timestamp 의 platform (APP=IOS/ANDROID, WEB)
-- 채널:
--   A 앱퍼스트 = 첫 콘텐츠 결제가 APP
--   B 웹→앱    = 첫 콘텐츠 결제가 WEB & 이후 APP 결제 존재 (정의상 2건 이상 → 재구매any 100%)
--   C 웹온리   = 모든 콘텐츠 결제가 WEB (APP 결제 0)
--   U 미상     = platform NULL (2명, 무시)
--
-- 2회차 정의 (date 그레인):
--   users_2plus_pays  = 결제 2건 이상(동일일 포함) = 재구매(any)
--   users_revisit     = 서로 다른 결제일 2개 이상 = 재방문 재구매 (리텐션 핵심)
--   users_sameday_only= 2건 이상이나 모두 첫날 = 동일일 업셀만, 재방문 없음

WITH pays AS (
  SELECT
    user_id,
    event_date,
    event_timestamp,
    CASE WHEN platform IN ('IOS','ANDROID') THEN 'APP'
         WHEN platform = 'WEB' THEN 'WEB'
         ELSE 'UNKNOWN' END AS plat_grp
  FROM `hellobot-f445c.hlb_mart.mart_use_skill_se`
  WHERE event_name LIKE 'pay_%' AND revenue_krw > 0
),
user_pay AS (
  SELECT
    user_id,
    ARRAY_AGG(plat_grp ORDER BY event_timestamp ASC LIMIT 1)[OFFSET(0)] AS first_plat,
    COUNTIF(plat_grp = 'APP') AS app_pay_rows,
    COUNT(DISTINCT event_date) AS distinct_pay_dates,
    COUNT(*) AS total_pay_rows
  FROM pays
  GROUP BY user_id
)
SELECT
  CASE
    WHEN first_plat = 'APP' THEN 'A_app_first'
    WHEN first_plat = 'WEB' AND app_pay_rows > 0 THEN 'B_web_to_app'
    WHEN first_plat = 'WEB' AND app_pay_rows = 0 THEN 'C_web_only'
    ELSE 'U_unknown'
  END AS channel,
  COUNT(*) AS users,
  COUNTIF(total_pay_rows >= 2) AS users_2plus_pays,
  COUNTIF(distinct_pay_dates >= 2) AS users_revisit,
  COUNTIF(total_pay_rows >= 2 AND distinct_pay_dates = 1) AS users_sameday_only
FROM user_pay
GROUP BY channel
ORDER BY users DESC;
