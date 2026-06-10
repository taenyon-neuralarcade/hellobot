-- 2026 운세박람회 쿠폰 대상 추출
-- 요청: 두 운세박람회 스킬 "소비 블록 진입" 유저 중 6/7까지 푸시온 유지 유저
-- 작성: /dev-data, 2026-06-09 (REQ-002)
--
-- [스킬 식별] hlb_mart.mart_use_skill_se 실측 (2026-06-09)
--   menu_seq 61036 = 오행 사주 풀이 [2026 운세박람회 x 헬로우봇 판밍밍]
--                    consume_skill 블록 2125754 "운세박람회_생일받기"
--   menu_seq 61069 = 자유상담권 선물 [2026 운세박람회 x 헬로우봇 라마마]
--                    consume_skill 블록 2123040 "[LLM박람회] 멘트"
--   "소비 블록 진입" = consume_skill 이벤트 발화로 정의 (소비 블록에서 발화)
--   실제 consume_skill 발생일: 2026-05-27 ~ 2026-06-06
--
-- [푸시온 정의] 쿠폰 = 마케팅성 푸시 → "마케팅 푸시 수신 가능" 기준
--   push_os_on = true (OS 알림 권한) AND push_day_on = true (마케팅/주간 푸시 동의)
--   = report_crm_optin_total.sql 의 marketing_push_user 정의와 동일
--   대안: 정보성(os_on AND in_app_on)=192 / 앱토글(app_on)=191 / OS권한만(os_on)=227
--
-- [6/7 시점성] mart_user_server / user_push_settings 는 일별 히스토리 없는 '최신 스냅샷'.
--   단, 본 코호트 179명 전원이 푸시 설정을 2026-06-06 01:59 이전 마지막 변경 →
--   최신 스냅샷 = 6/7 시점 상태와 정확히 일치 (user_push_settings.updated_at 로 교차검증).
--
-- 결과: 179명 (판밍밍만 116 / 라마마만 19 / 둘 다 44)

WITH expo_cohort AS (
  SELECT
    CAST(user_id AS STRING) AS user_id,
    COUNTIF(menu_seq = "61036") > 0 AS used_panmingming,  -- 판밍밍 (오행 사주 풀이)
    COUNTIF(menu_seq = "61069") > 0 AS used_ramama         -- 라마마 (자유상담권 선물)
  FROM `hellobot-f445c.hlb_mart.mart_use_skill_se`
  WHERE event_date BETWEEN "2026-05-20" AND "2026-06-09"   -- consume_skill 실발생(5/27~6/6) 포괄
    AND event_name = "consume_skill"                       -- 소비 블록 진입
    AND menu_seq IN ("61036", "61069")
  GROUP BY user_id
)
SELECT
  c.user_id,
  c.used_panmingming,
  c.used_ramama,
  u.push_os_on,
  u.push_day_on,
  u.push_app_on
FROM expo_cohort c
JOIN `hellobot-f445c.hlb_mart.mart_user_server` u
  ON c.user_id = CAST(u.user_id AS STRING)
WHERE u.push_os_on = true AND u.push_day_on = true          -- 마케팅 푸시 수신 가능
ORDER BY SAFE_CAST(c.user_id AS INT64);
