-- Google IAP Financial Report Analysis
-- Scope: 2025-02 ~ 2025-04, 두 계정(신 계정 + 구 계정[띵스플로우]) 통합
-- Filter: com.thingsflow.hellobot
-- Output: planning/iap-analysis/*.csv

-- =========================================
-- STEP 1. 6개 CSV 통합 + hellobot 필터
-- =========================================

CREATE OR REPLACE TABLE iap_raw AS
SELECT *, 'new' AS account, '2025-02' AS src_month
FROM read_csv_auto('/Users/taenyon/Box Sync/[사용중] DLT Partners/월별 재무리포트/2025.02 - 20250320 작성/Google_IAP_202502_확정.csv', header=true, all_varchar=true)
UNION ALL BY NAME
SELECT *, 'legacy' AS account, '2025-02' AS src_month
FROM read_csv_auto('/Users/taenyon/Box Sync/[사용중] DLT Partners/월별 재무리포트/2025.02 - 20250320 작성/Google_IAP_202502_확정_띵스플로우.csv', header=true, all_varchar=true)
UNION ALL BY NAME
SELECT *, 'new' AS account, '2025-03' AS src_month
FROM read_csv_auto('/Users/taenyon/Box Sync/[사용중] DLT Partners/월별 재무리포트/2025.03 - 20250407 작성/Google_IAP_202503_확정.csv', header=true, all_varchar=true)
UNION ALL BY NAME
SELECT *, 'legacy' AS account, '2025-03' AS src_month
FROM read_csv_auto('/Users/taenyon/Box Sync/[사용중] DLT Partners/월별 재무리포트/2025.03 - 20250407 작성/Google_IAP_202503_확정_띵스플로우.csv', header=true, all_varchar=true)
UNION ALL BY NAME
SELECT *, 'new' AS account, '2025-04' AS src_month
FROM read_csv_auto('/Users/taenyon/Box Sync/[사용중] DLT Partners/월별 재무리포트/2025.04 - 20250507 작성 (20250519 추가)/Google_IAP_202504_확정 PlayApps_202504.csv', header=true, all_varchar=true)
UNION ALL BY NAME
SELECT *, 'legacy' AS account, '2025-04' AS src_month
FROM read_csv_auto('/Users/taenyon/Box Sync/[사용중] DLT Partners/월별 재무리포트/2025.04 - 20250507 작성 (20250519 추가)/Google_IAP_202504_확정_띵스플로우 PlayApps_202504.csv', header=true, all_varchar=true);

-- 정규화된 작업 테이블
CREATE OR REPLACE TABLE iap AS
SELECT
    account,
    src_month,
    "Description" AS description,
    -- GPA 주문ID 정규화 (예: GPA.xxx..97 → GPA.xxx, 구독 갱신 카운트 제거)
    regexp_extract("Description", '^(GPA\.[0-9]+-[0-9]+-[0-9]+-[0-9]+)', 1) AS order_id,
    regexp_extract("Description", '\.\.([a-z0-9]+)$', 1) AS desc_suffix,
    strptime("Transaction Date", '%b %d, %Y')::DATE AS tx_date,
    "Transaction Time" AS tx_time,
    "Transaction Type" AS tx_type,
    "Refund Type" AS refund_type,
    "Product id" AS product_id,
    "Sku Id" AS sku_id,
    "Product Title" AS product_title,
    "Product Type" AS product_type,
    "Buyer Country" AS country,
    "Buyer Currency" AS buyer_currency,
    TRY_CAST("Amount (Buyer Currency)" AS DOUBLE) AS amount_buyer,
    TRY_CAST("Amount (Merchant Currency)" AS DOUBLE) AS amount_merchant,
    "Merchant Currency" AS merchant_currency,
    "Base Plan ID" AS base_plan_id,
    "Offer ID" AS offer_id,
    "Group ID" AS group_id
FROM iap_raw
WHERE "Product id" = 'com.thingsflow.hellobot';

-- 로드 요약
CREATE OR REPLACE TABLE load_summary AS
SELECT account, src_month, COUNT(*) AS rows, MIN(tx_date) AS min_date, MAX(tx_date) AS max_date
FROM iap
GROUP BY 1,2
ORDER BY 2,1;

COPY load_summary TO 'load-summary.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 2. Transaction Type 분포 전체
-- =========================================

COPY (
  SELECT
    account,
    src_month,
    tx_type,
    COUNT(*) AS n_rows,
    SUM(amount_merchant) AS sum_krw
  FROM iap
  GROUP BY 1,2,3
  ORDER BY 2,1,3
) TO 'tx-type-summary.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 3. 일자별 Charge / Charge refund 건수·금액 (두 계정 합산)
-- =========================================

COPY (
  SELECT
    tx_date,
    -- Charge (결제)
    COUNT(*) FILTER (WHERE tx_type = 'Charge') AS charge_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge') AS charge_krw,
    COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge') AS charge_unique_orders,
    -- Charge refund (환불)
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund') AS refund_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund') AS refund_krw,
    COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge refund') AS refund_unique_orders,
    -- 환불율
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
      / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0),
      2
    ) AS refund_rate_pct
  FROM iap
  WHERE tx_date IS NOT NULL
  GROUP BY 1
  ORDER BY 1
) TO 'daily-aggregates.csv' (HEADER, DELIMITER ',');

-- 계정별 일자별
COPY (
  SELECT
    tx_date,
    account,
    COUNT(*) FILTER (WHERE tx_type = 'Charge') AS charge_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge') AS charge_krw,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund') AS refund_cnt,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund') AS refund_krw
  FROM iap
  WHERE tx_date IS NOT NULL
  GROUP BY 1,2
  ORDER BY 1,2
) TO 'daily-aggregates-by-account.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 4. 환불 시점 분석 — charge_date vs refund_date 매칭
-- =========================================

-- 각 order_id별로 Charge와 Charge refund의 날짜를 비교
CREATE OR REPLACE TABLE refund_matched AS
WITH charges AS (
  SELECT order_id, MIN(tx_date) AS charge_date, MIN(sku_id) AS sku_id,
         MIN(product_type) AS product_type, MIN(account) AS account
  FROM iap
  WHERE tx_type = 'Charge' AND tx_date IS NOT NULL
  GROUP BY order_id
),
refunds AS (
  SELECT order_id, MIN(tx_date) AS refund_date, MIN(refund_type) AS refund_type,
         MIN(account) AS refund_account
  FROM iap
  WHERE tx_type = 'Charge refund' AND tx_date IS NOT NULL
  GROUP BY order_id
)
SELECT
  r.order_id,
  c.sku_id,
  c.product_type,
  c.account,
  c.charge_date,
  r.refund_date,
  r.refund_type,
  DATE_DIFF('day', c.charge_date, r.refund_date) AS days_to_refund
FROM refunds r
LEFT JOIN charges c USING(order_id);

-- 환불 간격 분포 (일 단위)
COPY (
  SELECT
    CASE
      WHEN charge_date IS NULL THEN '매칭 실패(Charge 레코드 없음)'
      WHEN days_to_refund < 0 THEN '음수(이상)'
      WHEN days_to_refund <= 3 THEN '0-3일 (Google 72h 자동 환불 범위)'
      WHEN days_to_refund <= 7 THEN '4-7일'
      WHEN days_to_refund <= 14 THEN '8-14일'
      WHEN days_to_refund <= 30 THEN '15-30일'
      WHEN days_to_refund <= 60 THEN '31-60일'
      ELSE '60일 초과'
    END AS interval_bucket,
    COUNT(*) AS n
  FROM refund_matched
  GROUP BY 1
  ORDER BY
    CASE interval_bucket
      WHEN '매칭 실패(Charge 레코드 없음)' THEN 9
      WHEN '음수(이상)' THEN 8
      WHEN '0-3일 (Google 72h 자동 환불 범위)' THEN 0
      WHEN '4-7일' THEN 1
      WHEN '8-14일' THEN 2
      WHEN '15-30일' THEN 3
      WHEN '31-60일' THEN 4
      ELSE 5
    END
) TO 'refund-interval-distribution.csv' (HEADER, DELIMITER ',');

-- 환불 간격 분포 (2.29.5 배포 전후 비교)
COPY (
  SELECT
    CASE
      WHEN refund_date < DATE '2025-03-18' THEN 'pre_2.29.5 (< 3/18)'
      WHEN refund_date <= DATE '2025-04-01' THEN 'post_2.29.5 (3/18-4/1)'
      ELSE 'later (>4/1)'
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
  FROM refund_matched
  GROUP BY 1,2
  ORDER BY 1,2
) TO 'refund-interval-by-period.csv' (HEADER, DELIMITER ',');

-- 매칭된 개별 환불 내역 (조사용)
COPY (
  SELECT * FROM refund_matched ORDER BY refund_date, order_id
) TO 'refund-matched-detail.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 5. Refund Type 분포
-- =========================================

COPY (
  SELECT
    COALESCE(refund_type, '(empty)') AS refund_type,
    COUNT(*) AS n,
    SUM(amount_merchant) AS sum_krw
  FROM iap
  WHERE tx_type = 'Charge refund'
  GROUP BY 1
  ORDER BY 2 DESC
) TO 'refund-type-distribution.csv' (HEADER, DELIMITER ',');

-- 월별 refund type (변화 확인)
COPY (
  SELECT
    src_month,
    COALESCE(refund_type, '(empty)') AS refund_type,
    COUNT(*) AS n
  FROM iap
  WHERE tx_type = 'Charge refund'
  GROUP BY 1,2
  ORDER BY 1,3 DESC
) TO 'refund-type-by-month.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 6. SKU별 환불율
-- =========================================

COPY (
  WITH per_sku AS (
    SELECT
      COALESCE(sku_id, '(null)') AS sku_id,
      COALESCE(product_type, '?') AS product_type,
      COUNT(*) FILTER (WHERE tx_type = 'Charge') AS charges,
      COUNT(*) FILTER (WHERE tx_type = 'Charge refund') AS refunds,
      SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge') AS charge_krw,
      SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund') AS refund_krw
    FROM iap
    GROUP BY 1,2
  )
  SELECT
    sku_id,
    product_type,
    charges,
    refunds,
    ROUND(100.0 * refunds / NULLIF(charges, 0), 2) AS refund_rate_pct,
    charge_krw,
    refund_krw,
    (charge_krw + refund_krw) AS net_krw
  FROM per_sku
  WHERE charges > 0 OR refunds > 0
  ORDER BY charges DESC
) TO 'sku-refund-rates.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 7. 2.29.5 배포 전/후 비교
-- =========================================

COPY (
  WITH buckets AS (
    SELECT
      CASE
        WHEN tx_date BETWEEN DATE '2025-03-04' AND DATE '2025-03-17' THEN '1_pre_2.29.5(3/04-3/17)'
        WHEN tx_date BETWEEN DATE '2025-03-18' AND DATE '2025-03-31' THEN '2_post_2.29.5(3/18-3/31)'
        WHEN tx_date BETWEEN DATE '2025-04-01' AND DATE '2025-04-14' THEN '3_stable_post(4/01-4/14)'
        ELSE NULL
      END AS period,
      tx_type,
      amount_merchant,
      order_id
    FROM iap
    WHERE tx_date IS NOT NULL
  )
  SELECT
    period,
    COUNT(*) FILTER (WHERE tx_type = 'Charge') AS charges,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge') AS charge_krw,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund') AS refunds,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund') AS refund_krw,
    ROUND(100.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
      / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0), 2) AS refund_rate_pct,
    COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge') AS unique_buyers_or_orders
  FROM buckets
  WHERE period IS NOT NULL
  GROUP BY 1
  ORDER BY 1
) TO 'pre-post-2.29.5-comparison.csv' (HEADER, DELIMITER ',');

-- =========================================
-- STEP 8. 최종 요약 (콘솔 출력용)
-- =========================================
-- (콘솔에서 별도 쿼리로 확인)

-- =========================================
-- STEP 9. 3/22 분기점 분석 — 재무 데이터 기반 구매자수 절대값 재집계
-- =========================================
-- 목적: Play Console "월간 구매자 비율" 3/22 반토막 원인 규명
-- (실제 구매 건수 변화 vs 지표 아티팩트 구분)
-- 주의: Google IAP 재무 리포트에 user_id 없음 → order_id를 구매 건수 proxy로 사용

-- STEP 9-1. 주별 구매건수 + 환불건수 추이 (두 계정 합산)
COPY (
  SELECT
    DATE_TRUNC('week', tx_date)::DATE AS week_start,
    COUNT(*) FILTER (WHERE tx_type = 'Charge') AS charge_cnt,
    COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge') AS charge_unique_orders,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge') AS charge_krw,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund') AS refund_cnt,
    COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge refund') AS refund_unique_orders,
    SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund') AS refund_krw,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
      / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0),
      2
    ) AS refund_rate_pct
  FROM iap
  WHERE tx_date IS NOT NULL
  GROUP BY 1
  ORDER BY 1
) TO 'weekly-trend-combined.csv' (HEADER, DELIMITER ',');

-- STEP 9-2. 계정별 vs 합산 일자별 구매건수 추이 (앱 이전 효과 시각화)
COPY (
  SELECT
    tx_date,
    COUNT(*) FILTER (WHERE tx_type = 'Charge' AND account = 'new')        AS charge_cnt_new,
    COUNT(*) FILTER (WHERE tx_type = 'Charge' AND account = 'legacy')     AS charge_cnt_legacy,
    COUNT(*) FILTER (WHERE tx_type = 'Charge')                            AS charge_cnt_combined,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund' AND account = 'new')    AS refund_cnt_new,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund' AND account = 'legacy') AS refund_cnt_legacy,
    COUNT(*) FILTER (WHERE tx_type = 'Charge refund')                        AS refund_cnt_combined,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
      / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0),
      2
    ) AS refund_rate_combined_pct
  FROM iap
  WHERE tx_date IS NOT NULL
  GROUP BY 1
  ORDER BY 1
) TO 'daily-buyer-trend-by-account.csv' (HEADER, DELIMITER ',');

-- STEP 9-3. 2025-03-22 기준 전후 4주(28일) 비교 (두 계정 합산)
COPY (
  WITH buckets AS (
    SELECT
      CASE
        WHEN tx_date BETWEEN DATE '2025-02-22' AND DATE '2025-03-21' THEN 'pre_0322'
        WHEN tx_date BETWEEN DATE '2025-03-22' AND DATE '2025-04-20' THEN 'post_0322'
        ELSE NULL
      END AS period,
      tx_type,
      order_id,
      amount_merchant
    FROM iap
    WHERE tx_date IS NOT NULL
  ),
  agg AS (
    SELECT
      period,
      COUNT(*) FILTER (WHERE tx_type = 'Charge') AS charges,
      COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge') AS charge_unique_orders,
      SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge') AS charge_krw,
      COUNT(*) FILTER (WHERE tx_type = 'Charge refund') AS refunds,
      COUNT(DISTINCT order_id) FILTER (WHERE tx_type = 'Charge refund') AS refund_unique_orders,
      SUM(amount_merchant) FILTER (WHERE tx_type = 'Charge refund') AS refund_krw,
      ROUND(
        100.0 * COUNT(*) FILTER (WHERE tx_type = 'Charge refund')
        / NULLIF(COUNT(*) FILTER (WHERE tx_type = 'Charge'), 0),
        2
      ) AS refund_rate_pct,
      CASE
        WHEN period = 'pre_0322'  THEN DATE_DIFF('day', DATE '2025-02-22', DATE '2025-03-21') + 1
        WHEN period = 'post_0322' THEN DATE_DIFF('day', DATE '2025-03-22', DATE '2025-04-20') + 1
      END AS days_in_period
    FROM buckets
    WHERE period IS NOT NULL
    GROUP BY 1
  )
  SELECT
    period,
    charges,
    charge_unique_orders,
    charge_krw,
    refunds,
    refund_unique_orders,
    refund_krw,
    refund_rate_pct,
    days_in_period,
    ROUND(1.0 * charges / NULLIF(days_in_period, 0), 2) AS avg_daily_charges,
    ROUND(1.0 * refunds / NULLIF(days_in_period, 0), 2) AS avg_daily_refunds
  FROM agg
  ORDER BY period
) TO 'pre-post-0322-comparison.csv' (HEADER, DELIMITER ',');
