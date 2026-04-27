-- Google IAP 재무 데이터: 구독(subscription) vs 상품(product) 분리 분석
-- 기존 iap 테이블(run.sql로 적재) 재사용. 동일 DuckDB 파일(iap.duckdb)에서 실행.
--
-- 분류 규칙:
--   subscription: base_plan_id IS NOT NULL        (hellobot_membership_*)
--   product:      base_plan_id IS NULL            (coin, heart, pass_7days 등 INAPP)
--
-- 산출물: planning/iap-analysis/split-* CSV

-- =========================================
-- STEP 0. 분류가 부여된 작업 뷰
-- =========================================

CREATE OR REPLACE VIEW iap_cat AS
SELECT
    *,
    CASE WHEN base_plan_id IS NOT NULL THEN 'subscription' ELSE 'product' END AS category
FROM iap;

-- 분류 sanity check
COPY (
  SELECT
    category,
    sku_id,
    COUNT(*) FILTER (WHERE tx_type = 'Charge')        AS charges,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund') AS refunds,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge')        AS charge_krw,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund') AS refund_krw
  FROM iap_cat
  GROUP BY 1,2
  ORDER BY 1,2
) TO 'split-category-sku-map.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 1. 카테고리별 전체 요약
-- =========================================

COPY (
  SELECT
    category,
    COUNT(*) FILTER (WHERE tx_type = 'Charge')                              AS charges,
    COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge')              AS charge_unique_orders,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge')                  AS charge_krw,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund')                       AS refunds,
    COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge refund')       AS refund_unique_orders,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund')           AS refund_krw,
    ROUND(100.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
          / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0), 2)       AS refund_rate_pct,
    SUM(amount_merchant) FILTER (WHERE tx_type IN ('Charge','Charge refund')) AS net_krw
  FROM iap_cat
  GROUP BY 1
  ORDER BY 1
) TO 'split-overall-summary.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 2. 카테고리별 일자별 집계 (구매/환불)
-- =========================================

-- 2-1. 구독 일자별
COPY (
  SELECT
    tx_date,
    COUNT(*) FILTER (WHERE tx_type = 'Charge')                          AS charge_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge')              AS charge_krw,
    COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge')          AS charge_unique_orders,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund')                   AS refund_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund')       AS refund_krw,
    COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge refund')   AS refund_unique_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
          / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0), 2)   AS refund_rate_pct
  FROM iap_cat
  WHERE category = 'subscription' AND tx_date IS NOT NULL
  GROUP BY 1
  ORDER BY 1
) TO 'split-daily-subscription.csv' (HEADER, DELIMITER ',');

-- 2-2. 상품 일자별
COPY (
  SELECT
    tx_date,
    COUNT(*) FILTER (WHERE tx_type = 'Charge')                          AS charge_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge')              AS charge_krw,
    COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge')          AS charge_unique_orders,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund')                   AS refund_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund')       AS refund_krw,
    COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge refund')   AS refund_unique_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
          / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0), 2)   AS refund_rate_pct
  FROM iap_cat
  WHERE category = 'product' AND tx_date IS NOT NULL
  GROUP BY 1
  ORDER BY 1
) TO 'split-daily-product.csv' (HEADER, DELIMITER ',');

-- 2-3. 카테고리 병렬 비교 (한 파일)
COPY (
  SELECT
    tx_date,
    -- 구독
    COUNT(*) FILTER (WHERE tx_type = 'Charge' AND category = 'subscription')        AS sub_charge_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge' AND category = 'subscription') AS sub_charge_krw,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund' AND category = 'subscription') AS sub_refund_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund' AND category = 'subscription') AS sub_refund_krw,
    -- 상품
    COUNT(*) FILTER (WHERE tx_type = 'Charge' AND category = 'product')             AS prod_charge_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge' AND category = 'product') AS prod_charge_krw,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund' AND category = 'product')      AS prod_refund_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund' AND category = 'product') AS prod_refund_krw
  FROM iap_cat
  WHERE tx_date IS NOT NULL
  GROUP BY 1
  ORDER BY 1
) TO 'split-daily-side-by-side.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 3. 카테고리별 환불 시점(charge→refund) 분포
-- =========================================

CREATE OR REPLACE TABLE refund_matched_cat AS
WITH charges AS (
  SELECT order_id,
         MIN(tx_date)                                            AS charge_date,
         ANY_VALUE(sku_id)                                       AS sku_id,
         CASE WHEN ANY_VALUE(base_plan_id) IS NOT NULL THEN 'subscription' ELSE 'product' END AS category,
         ANY_VALUE(account)                                      AS account,
         SUM(amount_merchant)                                    AS charge_krw
  FROM iap
  WHERE tx_type = 'Charge' AND tx_date IS NOT NULL
  GROUP BY order_id
),
refunds AS (
  SELECT order_id,
         MIN(tx_date)           AS refund_date,
         ANY_VALUE(refund_type) AS refund_type,
         SUM(amount_merchant)   AS refund_krw
  FROM iap
  WHERE tx_type = 'Charge refund' AND tx_date IS NOT NULL
  GROUP BY order_id
)
SELECT
  r.order_id,
  c.category,
  c.sku_id,
  c.account,
  c.charge_date,
  r.refund_date,
  r.refund_type,
  DATE_DIFF('day', c.charge_date, r.refund_date) AS days_to_refund,
  c.charge_krw,
  r.refund_krw
FROM refunds r
LEFT JOIN charges c USING(order_id);

COPY (
  SELECT
    category,
    CASE
      WHEN charge_date IS NULL THEN '매칭 실패(Charge 레코드 없음, 이전 달)'
      WHEN days_to_refund < 0 THEN '음수(이상)'
      WHEN days_to_refund <= 3 THEN '0-3일 (Google 72h 자동 환불 범위)'
      WHEN days_to_refund <= 7 THEN '4-7일'
      WHEN days_to_refund <= 14 THEN '8-14일'
      WHEN days_to_refund <= 30 THEN '15-30일'
      WHEN days_to_refund <= 60 THEN '31-60일'
      ELSE '60일 초과'
    END AS interval_bucket,
    COUNT(*) AS n,
    SUM(refund_krw) AS refund_krw
  FROM refund_matched_cat
  GROUP BY 1,2
  ORDER BY 1,
    CASE interval_bucket
      WHEN '매칭 실패(Charge 레코드 없음, 이전 달)' THEN 9
      WHEN '음수(이상)' THEN 8
      WHEN '0-3일 (Google 72h 자동 환불 범위)' THEN 0
      WHEN '4-7일' THEN 1
      WHEN '8-14일' THEN 2
      WHEN '15-30일' THEN 3
      WHEN '31-60일' THEN 4
      ELSE 5
    END
) TO 'split-refund-interval-by-category.csv' (HEADER, DELIMITER ',');

-- 카테고리 × 기간(2.29.5 전후) 환불 간격
COPY (
  SELECT
    category,
    CASE
      WHEN refund_date < DATE '2025-03-18' THEN '1_pre_2.29.5'
      WHEN refund_date <= DATE '2025-04-01' THEN '2_post_2.29.5'
      ELSE '3_later'
    END AS period,
    CASE
      WHEN charge_date IS NULL THEN '매칭 실패'
      WHEN days_to_refund < 0 THEN '음수'
      WHEN days_to_refund <= 3 THEN '0-3일'
      WHEN days_to_refund <= 7 THEN '4-7일'
      WHEN days_to_refund <= 14 THEN '8-14일'
      WHEN days_to_refund <= 30 THEN '15-30일'
      ELSE '31일+'
    END AS interval_bucket,
    COUNT(*) AS n
  FROM refund_matched_cat
  GROUP BY 1,2,3
  ORDER BY 1,2,3
) TO 'split-refund-interval-by-category-period.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 4. 카테고리별 Refund Type 분포 (유저 요청 vs 정책 환불)
-- =========================================

COPY (
  SELECT
    category,
    COALESCE(refund_type, '(empty)') AS refund_type,
    COUNT(*) AS n,
    SUM(amount_merchant) AS refund_krw
  FROM iap_cat
  WHERE tx_type = 'Charge refund'
  GROUP BY 1,2
  ORDER BY 1,3 DESC
) TO 'split-refund-type-by-category.csv' (HEADER, DELIMITER ',');

-- 월별 × 카테고리 × refund_type (변화 감지)
COPY (
  SELECT
    src_month,
    category,
    COALESCE(refund_type, '(empty)') AS refund_type,
    COUNT(*) AS n,
    SUM(amount_merchant) AS refund_krw
  FROM iap_cat
  WHERE tx_type = 'Charge refund'
  GROUP BY 1,2,3
  ORDER BY 1,2,4 DESC
) TO 'split-refund-type-by-month-category.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 5. 카테고리 × 2.29.5 배포 전후 비교
-- =========================================

COPY (
  WITH buckets AS (
    SELECT
      category,
      CASE
        WHEN tx_date BETWEEN DATE '2025-03-04' AND DATE '2025-03-17' THEN '1_pre_2.29.5(3/04-3/17)'
        WHEN tx_date BETWEEN DATE '2025-03-18' AND DATE '2025-03-31' THEN '2_post_2.29.5(3/18-3/31)'
        WHEN tx_date BETWEEN DATE '2025-04-01' AND DATE '2025-04-14' THEN '3_stable_post(4/01-4/14)'
        ELSE NULL
      END AS period,
      tx_type,
      amount_merchant,
      order_id
    FROM iap_cat
    WHERE tx_date IS NOT NULL
  )
  SELECT
    category,
    period,
    COUNT(*) FILTER (WHERE tx_type = 'Charge')                              AS charges,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge')                  AS charge_krw,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund')                       AS refunds,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund')           AS refund_krw,
    ROUND(100.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
          / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0), 2)       AS refund_rate_pct
  FROM buckets
  WHERE period IS NOT NULL
  GROUP BY 1,2
  ORDER BY 1,2
) TO 'split-pre-post-2.29.5-by-category.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 6. 카테고리별 주별 추이
-- =========================================

COPY (
  SELECT
    DATE_TRUNC('week', tx_date)::DATE AS week_start,
    category,
    COUNT(*) FILTER (WHERE tx_type = 'Charge')                          AS charge_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge')              AS charge_krw,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund')                   AS refund_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund')       AS refund_krw,
    ROUND(100.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
          / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0), 2)   AS refund_rate_pct
  FROM iap_cat
  WHERE tx_date IS NOT NULL
  GROUP BY 1,2
  ORDER BY 1,2
) TO 'split-weekly-by-category.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 7. 카테고리별 이상 탐지(특이점) 플래그
-- =========================================
-- rolling median/MAD 기반 z-score — 카테고리 내에서 당일 charge/refund가 튀는지 확인

-- 7-1. 환불 스파이크 (카테고리 내 환불율 z-score)
COPY (
  WITH daily AS (
    SELECT
      tx_date,
      category,
      COUNT(*) FILTER (WHERE tx_type = 'Charge')                        AS charge_cnt,
      COUNT(*) FILTER (WHERE tx_type = 'Charge refund')                 AS refund_cnt,
      1.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
        / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0)         AS refund_rate
    FROM iap_cat
    WHERE tx_date IS NOT NULL
    GROUP BY 1,2
  ),
  stats AS (
    SELECT
      category,
      MEDIAN(refund_rate) AS median_rate,
      MEDIAN(refund_cnt)  AS median_cnt,
      MEDIAN(charge_cnt)  AS median_charge
    FROM daily
    GROUP BY 1
  )
  SELECT
    d.tx_date,
    d.category,
    d.charge_cnt,
    ROUND(d.charge_cnt / NULLIF(s.median_charge, 0), 2)    AS charge_ratio_vs_median,
    d.refund_cnt,
    ROUND(d.refund_cnt / NULLIF(s.median_cnt, 0), 2)       AS refund_ratio_vs_median,
    ROUND(100.0 * d.refund_rate, 2)                        AS refund_rate_pct,
    ROUND(100.0 * s.median_rate, 2)                        AS median_refund_rate_pct,
    CASE
      WHEN d.refund_rate > s.median_rate * 3 AND d.refund_cnt >= 5 THEN 'HIGH_REFUND_SPIKE'
      WHEN d.charge_cnt  < s.median_charge * 0.5 AND s.median_charge >= 10 THEN 'LOW_CHARGE_DROP'
      WHEN d.charge_cnt  > s.median_charge * 2.0 AND s.median_charge >= 10 THEN 'HIGH_CHARGE_SPIKE'
      ELSE NULL
    END AS flag
  FROM daily d
  JOIN stats s USING(category)
  WHERE CASE
      WHEN d.refund_rate > s.median_rate * 3 AND d.refund_cnt >= 5 THEN 1
      WHEN d.charge_cnt  < s.median_charge * 0.5 AND s.median_charge >= 10 THEN 1
      WHEN d.charge_cnt  > s.median_charge * 2.0 AND s.median_charge >= 10 THEN 1
      ELSE 0
    END = 1
  ORDER BY d.category, d.tx_date
) TO 'split-anomaly-flags.csv' (HEADER, DELIMITER ',');

-- 7-2. 카테고리별 일자별 전체 with 이상 플래그 (탐색용)
COPY (
  WITH daily AS (
    SELECT
      tx_date,
      category,
      COUNT(*) FILTER (WHERE tx_type = 'Charge')                        AS charge_cnt,
      SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge')            AS charge_krw,
      COUNT(*) FILTER (WHERE tx_type = 'Charge refund')                 AS refund_cnt,
      SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund')     AS refund_krw,
      1.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
        / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0)         AS refund_rate
    FROM iap_cat
    WHERE tx_date IS NOT NULL
    GROUP BY 1,2
  ),
  stats AS (
    SELECT
      category,
      MEDIAN(refund_rate) AS median_rate,
      MEDIAN(refund_cnt)  AS median_cnt,
      MEDIAN(charge_cnt)  AS median_charge
    FROM daily
    GROUP BY 1
  )
  SELECT
    d.tx_date,
    d.category,
    d.charge_cnt,
    d.charge_krw,
    d.refund_cnt,
    d.refund_krw,
    ROUND(100.0 * d.refund_rate, 2) AS refund_rate_pct,
    ROUND(d.charge_cnt / NULLIF(s.median_charge, 0), 2) AS charge_ratio_vs_median,
    CASE
      WHEN d.refund_rate > s.median_rate * 3 AND d.refund_cnt >= 5 THEN 'HIGH_REFUND_SPIKE'
      WHEN d.charge_cnt  < s.median_charge * 0.5 AND s.median_charge >= 10 THEN 'LOW_CHARGE_DROP'
      WHEN d.charge_cnt  > s.median_charge * 2.0 AND s.median_charge >= 10 THEN 'HIGH_CHARGE_SPIKE'
      ELSE NULL
    END AS flag
  FROM daily d
  JOIN stats s USING(category)
  ORDER BY d.tx_date, d.category
) TO 'split-daily-with-flags.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 8. 월별 카테고리 요약 (macro view)
-- =========================================

COPY (
  SELECT
    src_month,
    category,
    COUNT(*) FILTER (WHERE tx_type = 'Charge')                              AS charges,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge')                  AS charge_krw,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund')                       AS refunds,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund')           AS refund_krw,
    ROUND(100.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
          / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0), 2)       AS refund_rate_pct,
    SUM(amount_merchant) FILTER (WHERE tx_type IN ('Charge','Charge refund')) AS net_krw
  FROM iap_cat
  GROUP BY 1,2
  ORDER BY 1,2
) TO 'split-monthly-by-category.csv' (HEADER, DELIMITER ',');
