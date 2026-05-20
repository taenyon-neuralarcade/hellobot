# 아키텍처 — 카카오 선물하기 운영 슬랙 알림

> 본 문서는 F1(서버 실시간 알림)·F2(Airflow 일일 통계 푸시) 의 기술 설계입니다.
> 요구사항·확정 결정 사항: [readme.md](./readme.md), [requirements.md](./requirements.md)
> 의존 기반: [coop-integration architecture.md](../20260324-coop-integration/architecture.md) §4 (데이터 모델), §5-1·5-2 (등록 흐름), [coop-integration data-measurement-plan.md](../20260324-coop-integration/data-measurement-plan.md) §2·§4·§8 (KPI·소스·쿼리)

## 1. 개요

두 개의 독립 트랙으로 구성됩니다.

```
F1 (서버, hellobot-server)
   사용자 등록 → POST /api/coupon/register → CoupMarketingService.registerOneShot()
     → usage UPSERT(used) + 상품 지급 + heartLogSeq/issuedCouponSeq 갱신
     → [신규] notifyKakaoGiftSlack(usage) fire-and-forget
         → Redis INCR daily counter
         → Webhook POST (env 비활성 시 skip)

F2 (데이터, common-data-airflow)
   매일 KST 09:00 schedule
     → ExternalTaskSensor (선행 ETL 완료 대기, 09:00~10:00 가변)
     → BQ 집계 task (어제 단일 + 출시일 이후 누적)
     → 메시지 조립 + SlackAPI.post_message(#chatops-hellobot-kakao-gift)
     (실패 시 on_failure_callback → #chatops_데이터_장애알림)
```

두 트랙은 **동일 채널** (`#chatops-hellobot-kakao-gift`) 에 발송하되 **독립 Webhook/토큰** 을 사용합니다 (서버는 Incoming Webhook URL, 데이터는 기존 `SLACK_API_TOKEN` + 채널 ID).

## 2. F1 — 서버 실시간 알림

### 2.1 발화 위치 (Hook)

**파일**: `hellobot-server/src/services/coop-marketing.ts`

[coop-integration architecture §5-2](../20260324-coop-integration/architecture.md) 의 처리 시퀀스 step 7 직후 — **usage 에 `heartLogSeq` 또는 `issuedCouponSeq` 까지 업데이트 완료된 시점**. 이 시점 이후 응답 조립 직전에 hook 을 끼웁니다.

```typescript
// CoopMarketingService.processHeartCoupon() / processSkillCoupon() — 응답 반환 직전
// 위치: coop-marketing.ts 의 usage UPSERT + heartLogSeq/issuedCouponSeq 갱신 완료 직후

void this.kakaoGiftNotifier.notify({
  usageSeq: usage.seq,
  userSeq: requestContext.user.seq,
  productName: product.productName,
  productType: product.productType,           // 'heart' | 'skill'
  priceKrw: product.currentPrice ?? product.price,
  usedAt: usage.usedAt ?? new Date(),
});
// void → 에러 swallow 보장. 응답은 즉시 반환.
```

> `void` 키워드로 `await` 하지 않음 — 알림 실패가 등록 트랜잭션 응답에 영향 주지 않음. 에러는 알림 클래스 내부에서 catch + winston.error.

> **5-2 step 7 위치 선택 이유**: usage `used` 가 커밋되어 "취소된 등록"이 알림에 노출되지 않음. 상품 지급까지 성공한 케이스만 알림 대상.

### 2.2 KakaoGiftNotifier (신규 클래스)

**파일**: `hellobot-server/src/services/kakao-gift-notifier.ts` (신규)

```typescript
import Redis from "ioredis";
import { notifyToSlack } from "../common/util";
import { config } from "../common/config";
import { logger } from "../common/logger";
import dayjs from "dayjs";
import "dayjs/plugin/timezone";

const DAILY_COUNTER_KEY_PREFIX = "kakao:gift:daily_count";

export interface KakaoGiftNotifyPayload {
  usageSeq: number;
  userSeq: number;
  productName: string;
  productType: "heart" | "skill";
  priceKrw: number;
  usedAt: Date;
}

export class KakaoGiftNotifier {
  constructor(private readonly redis: Redis) {}

  async notify(payload: KakaoGiftNotifyPayload): Promise<void> {
    try {
      if (process.env.KAKAO_GIFT_SLACK_NOTIFY_ENABLED !== "true") {
        logger.debug({ usageSeq: payload.usageSeq }, "kakao gift slack: env disabled, skip");
        return;
      }
      const webhookUrl = process.env.SLACK_KAKAO_GIFT_NOTIFICATION_URI;
      if (!webhookUrl) {
        logger.warn({ usageSeq: payload.usageSeq }, "kakao gift slack: webhook URL missing");
        return;
      }

      const todayCount = await this.incrDailyCounter(payload.usedAt);
      const text = this.formatMessage(payload, todayCount);

      // notifyToSlack 은 process.env.SLACK_NOTIFICATION_URI 사용 → 신규 webhook 전용 함수 사용 권장
      await this.postToWebhook(webhookUrl, text);
    } catch (err) {
      logger.error({ err, payload }, "kakao gift slack notify failed");
      // swallow — 등록 트랜잭션엔 영향 없음
    }
  }

  private async incrDailyCounter(usedAt: Date): Promise<number> {
    const dateKstStr = dayjs(usedAt).tz("Asia/Seoul").format("YYYY-MM-DD");
    const key = `${DAILY_COUNTER_KEY_PREFIX}:${dateKstStr}`;
    const count = await this.redis.incr(key);
    if (count === 1) {
      // 첫 INCR 시점에만 만료 설정 (다음날 KST 00:00 = UTC 15:00 직후)
      const expireAt = dayjs(usedAt).tz("Asia/Seoul")
        .add(1, "day").startOf("day").add(1, "hour").unix();
      await this.redis.expireat(key, expireAt);
    }
    return count;
  }

  private formatMessage(p: KakaoGiftNotifyPayload, todayCount: number): string {
    const timeKst = dayjs(p.usedAt).tz("Asia/Seoul").format("YYYY-MM-DD HH:mm:ss");
    const categoryLabel = p.productType === "heart" ? "하트 충전권" : "스킬 교환권";
    const userMasked = `****${String(p.userSeq).slice(-4).padStart(4, "0")}`;
    return [
      "🎁 [카카오 선물하기] 쿠폰 등록",
      `시각: ${timeKst} KST`,
      `상품: ${p.productName} (${categoryLabel})`,
      `금액: ${p.priceKrw.toLocaleString("ko-KR")}원`,
      `사용자: user_id=${userMasked}`,
      `오늘 누적: ${todayCount}건째`,
    ].join("\n");
  }

  private async postToWebhook(url: string, text: string): Promise<void> {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text }),
    });
    if (!res.ok) {
      throw new Error(`slack webhook ${res.status}: ${await res.text()}`);
    }
  }
}
```

**의존성 주입**: typedi 기반(`@Service()`) 또는 기존 패턴에 맞춰 `CoupMarketingService` 생성자에 주입.

### 2.3 환경변수·시크릿

| 키 | 위치 | 값 | 비고 |
|---|---|---|---|
| `KAKAO_GIFT_SLACK_NOTIFY_ENABLED` | `common-infra-eks-deploy` ConfigMap/Deployment env | `"true"` (초기값) | OFF 시 `"false"` + ArgoCD sync |
| `SLACK_KAKAO_GIFT_NOTIFICATION_URI` | `common-infra-eks-deploy` Secret | Slack Incoming Webhook URL | 채널 `#chatops-hellobot-kakao-gift` 전용 |

`process.env.SLACK_NOTIFICATION_URI` (기존 일반 webhook) 와 **분리**. 기존 `notifyToSlack()` 유틸은 본 알림에 사용하지 않음 (URL 분리·재사용 단순성).

### 2.4 누적 카운터 — Redis vs PostgreSQL 결정

**Redis INCR 채택**. 사유:

- 매 등록마다 `COUNT(*)` 쿼리는 카카오 노출 확대 시 비용 누적 (TimescaleDB 아닌 일반 PG, used_at 인덱스 가정 시에도 N건 스캔)
- ioredis 클라이언트 이미 도입 (`src/common/redis.ts`), `INCR + EXPIREAT` 단일 round-trip
- 카운터 누락 허용 — 메시지 내 표시값이므로 redis 장애 시 catch 후 메시지에서 "오늘 누적" 라인 생략 가능 (현 구현은 catch → 전체 skip; T-S4 에서 fallback 옵션 결정)

**대안**: `SELECT COUNT(*) FROM coop_marketing_coupon_usage WHERE used_at >= (CURRENT_DATE AT TIME ZONE 'Asia/Seoul') AND status = 'used' AND ${카카오 쿠폰 조건}`. 정확성 보장 (Redis flush 무관) 이지만 부하·KST 시간대 계산 오버헤드.

### 2.5 카카오 쿠폰 식별 (분기 위치)

코드 진입 시점에서 이미 카카오 분기 안에 있음. `CoupMarketingService.processHeartCoupon()` / `processSkillCoupon()` 자체가 [coop-integration §5-1](../20260324-coop-integration/architecture.md) 의 `couponType === "coop_marketing"` 분기 결과로만 호출됨 → 본 hook 은 자동으로 카카오만 발화.

> **검증 항목 (T-S1)**: 위 가정이 실제 구현과 일치하는지 (다른 진입 경로가 있는지) 확인. 기존 `notifyToSlack` 으로 카카오 쿠폰 알림이 이미 발송되고 있다면 본 알림과의 중복 방지 정책 결정.

### 2.6 시퀀스 (정상 + 에러)

```
[정상]
client → POST /api/coupon/register
  CouponPrefixRule.match() → coop_marketing
  CoopMarketingService.registerOneShot()
    [Redlock 획득]
    L0 조회 → L1 사용 승인 → usage UPSERT(used)
    HeartService.chargeHeart() / CouponService.issueCoupon()
    usage.update(heartLogSeq | issuedCouponSeq)
    [Redlock 해제]
    void kakaoGiftNotifier.notify(payload)  ◀ 신규
       async:
         env check → redis.incr → fetch(webhook) [에러 시 logger.error + swallow]
  → response 200 (notifier 결과와 무관)

[알림 실패]
... 같은 흐름, fetch 5xx 또는 timeout 발생
  → logger.error("kakao gift slack notify failed", err)
  → 클라이언트 응답은 정상 (200)

[알림 OFF 상태]
... env=false → 즉시 return, redis·webhook 호출 안 함
```

### 2.7 메시지 예시

```
🎁 [카카오 선물하기] 쿠폰 등록
시각: 2026-05-22 14:23:11 KST
상품: 하트 1만원 충전권 (하트 충전권)
금액: 10,000원
사용자: user_id=****1234
오늘 누적: 23건째
```

## 3. F2 — Airflow 일일 통계 푸시

### 3.1 DAG 구조

**파일**: `common-data-airflow/dags/hlb_dags/hellobot_kakao_gift_daily_slack.py`

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.sensors.external_task import ExternalTaskSensor
from datetime import datetime, timedelta
from scripts.etc.slack_alert_v2 import on_failure, SlackAPI, get_channel_id
from airflow.models import Variable
from scripts.etc.bq_query import run_query
from scripts.hellobot.kakao_gift_slack import (
    build_daily_metrics, build_cumulative_metrics, format_message,
)

KST = "Asia/Seoul"
LAUNCH_DATE_KST = "2026-05-22"  # F2 누적 기준 시작
SLACK_CHANNEL = "chatops-hellobot-kakao-gift"

default_args = {
    "owner": "data",
    "retries": 2,
    "retry_delay": timedelta(minutes=10),
    "on_failure_callback": on_failure,
}

with DAG(
    dag_id="hellobot_kakao_gift_daily_slack",
    schedule="0 0 * * *",        # UTC 00:00 = KST 09:00
    start_date=datetime(2026, 5, 22),
    catchup=False,
    default_args=default_args,
    max_active_runs=1,
    tags=["hellobot", "kakao-gift", "slack"],
) as dag:

    wait_etl = ExternalTaskSensor(
        task_id="wait_for_coop_etl",
        external_dag_id="<DAG_ID_TBD_T-D1>",       # T-D1 에서 확정
        external_task_id="<TASK_ID_TBD_T-D1>",      # T-D1 에서 확정 (None 이면 DAG 전체)
        execution_delta=timedelta(0),               # 동일 KST 일자 기준
        timeout=60 * 60 * 2,                        # 최대 2시간 대기 (KST 11:00)
        poke_interval=60 * 5,                       # 5분 간격
        mode="reschedule",                          # worker slot 점유 회피
    )

    def _send_slack(**ctx):
        execution_kst = ctx["data_interval_start"].in_timezone(KST)
        d1 = execution_kst.subtract(days=1).format("YYYY-MM-DD")  # 어제 KST
        daily = build_daily_metrics(d1)
        cumulative = build_cumulative_metrics(LAUNCH_DATE_KST, d1)
        text = format_message(d1, daily, cumulative)

        slack = SlackAPI(Variable.get("SLACK_API_TOKEN"))
        channel_id = get_channel_id(SLACK_CHANNEL)
        slack.post_message(channel_id, text)

    send_slack = PythonOperator(
        task_id="send_slack",
        python_callable=_send_slack,
    )

    wait_etl >> send_slack
```

### 3.2 ExternalTaskSensor 대상 (T-D1)

**식별 절차**:
1. `coop_marketing_coupon_usage` 가 BigQuery `hellobot-f445c.server_rdb.coop_marketing_coupon_usage` 로 적재되는 경로 추적
2. 가설 A: `server_rdb_replicate` 류의 PostgreSQL → BQ sync DAG 가 있음 → 해당 DAG 의 `coop_marketing_coupon_usage` 적재 task 가 sensor 대상
3. 가설 B: `hellobot_datamart_staging_pipeline` 이 server_rdb 전체 staging 후 시작한다면 그 staging 단계의 종료 task 가 sensor 대상
4. 가설 C: 신규 구매자 KPI 가 필요한 경우 `union_mart_user_key_actions` 의 갱신 완료 (mart_integrated 레이어 종료) 까지 대기 필요 — 이 경우 sensor 대상은 `hellobot_datamart_mart_integrated_pipeline` 의 종료 task

**우선 가정 (C)**: 신규 구매자 KPI 가 출시 직후엔 0~소수이지만 핵심 지표이므로 mart_integrated 까지 기다리는 것이 안전. T-D1 에서 실제 DAG 명 확인 후 코드 갱신.

**Timeout 11:00 KST 초과 시**: `ExternalTaskSensor` 가 timeout → DAG 실패 → `on_failure_callback` → `#chatops_데이터_장애알림` 자동 알림 (기존 `slack_alert_v2.on_failure` 패턴).

### 3.3 BigQuery 집계 쿼리

**파일**: `common-data-airflow/dags/scripts/hellobot/kakao_gift_slack.py` (신규)

```python
from scripts.etc.bq_query import run_query
from scripts.etc.bq_client import connect_hellobot_bigquery

DAILY_SQL = """
WITH usage_daily AS (
  SELECT
    u.status,
    u.product_type,
    p.current_price,
    p.price,
    u.user_seq,
    DATE(u.used_at, 'Asia/Seoul') AS used_date_kst,
    DATE(u.created_at, 'Asia/Seoul') AS created_date_kst,
    DATE(u.canceled_at, 'Asia/Seoul') AS canceled_date_kst
  FROM `hellobot-f445c.server_rdb.coop_marketing_coupon_usage` u
  LEFT JOIN `hellobot-f445c.server_rdb.coop_marketing_product` p
    ON u.coupc_product_seq = p.seq    -- 컬럼명 코드 검증 필요 (T-D1)
)
SELECT
  COUNTIF(status = 'used' AND used_date_kst = @d1) AS used_count,
  COUNTIF(status = 'used' AND product_type = 'heart' AND used_date_kst = @d1) AS used_heart,
  COUNTIF(status = 'used' AND product_type = 'skill' AND used_date_kst = @d1) AS used_skill,
  SUM(IF(status = 'used' AND used_date_kst = @d1,
         COALESCE(current_price, price), 0)) AS revenue_krw,
  COUNTIF(status = 'canceled' AND canceled_date_kst = @d1) AS canceled_count,
FROM usage_daily;
"""

# 신규 구매자 — coop-integration data-measurement-plan §8.1 재사용
NEW_BUYERS_SQL = """
SELECT COUNT(DISTINCT user_id) AS new_buyers
FROM `hellobot-f445c.hlb_mart_integrated.union_mart_user_key_actions`
WHERE event_date = @d1
  AND event_name LIKE '%pay_for%'
  AND coop_kakao_first_used_date = DATE(user_created_at, 'Asia/Seoul')
  AND coop_kakao_first_used_date = @d1;
"""

CUMULATIVE_SQL = """
SELECT
  COUNTIF(status = 'used') AS used_count_cum,
  SUM(IF(status = 'used', COALESCE(p.current_price, p.price), 0)) AS revenue_cum,
  COUNT(DISTINCT IF(status = 'used', user_seq, NULL)) AS distinct_users_cum
FROM `hellobot-f445c.server_rdb.coop_marketing_coupon_usage` u
LEFT JOIN `hellobot-f445c.server_rdb.coop_marketing_product` p
  ON u.coupc_product_seq = p.seq
WHERE DATE(u.used_at, 'Asia/Seoul') BETWEEN @launch_date AND @d1;
"""

def build_daily_metrics(d1: str) -> dict:
    client = connect_hellobot_bigquery()
    daily = next(iter(run_query(client, sql=DAILY_SQL, params={"d1": d1})))
    new_buyers = next(iter(run_query(client, sql=NEW_BUYERS_SQL, params={"d1": d1})))
    used = daily["used_count"]
    failure_rate = 0.0 if used == 0 else daily.get("failure_count", 0) / (used + daily.get("failure_count", 0))
    return {**dict(daily), "new_buyers": new_buyers["new_buyers"], "failure_rate": failure_rate}

def build_cumulative_metrics(launch_date: str, d1: str) -> dict:
    client = connect_hellobot_bigquery()
    return dict(next(iter(run_query(client, sql=CUMULATIVE_SQL,
                                    params={"launch_date": launch_date, "d1": d1}))))

def format_message(d1: str, daily: dict, cumulative: dict) -> str:
    failure_rate_pct = round(daily["failure_rate"] * 100, 1)
    alerts = []
    if failure_rate_pct > 5.0:
        alerts.append(f"🚨 실패율 {failure_rate_pct}% (>5%)")
    if daily["used_count"] == 0:
        alerts.append("⚠️ 등록 0건")
    if daily["used_count"] > 0 and daily["canceled_count"] / daily["used_count"] > 0.10:
        alerts.append(f"⚠️ 환불율 {round(daily['canceled_count']/daily['used_count']*100, 1)}%")
    alerts_line = "✅ 이상 신호 없음" if not alerts else " / ".join(alerts)

    return f"""📊 [카카오 선물하기] 일일 리포트 — {d1} 자

▎ 어제 ({d1}) 성과
• 등록: {daily['used_count']}건 — 하트 {daily['used_heart']} · 스킬 {daily['used_skill']}
• 매출: {daily['revenue_krw']:,}원
• 신규 구매자: {daily['new_buyers']}명
• 환불·취소: {daily['canceled_count']}건
• 실패율: {failure_rate_pct}%

▎ 누적 (2026-05-22~{d1})
• 등록: {cumulative['used_count_cum']}건
• 매출: {cumulative['revenue_cum']:,}원
• 누적 등록자 (DISTINCT user): {cumulative['distinct_users_cum']}명

▎ {alerts_line}
"""
```

> **등록 실패 건수** 는 `coop_marketing_coupon_usage` 에 기록되지 않음 (UPSERT 가 L1 성공 후에만 발생). 실패는 `coop_marketing_api_log` 또는 `register_coupon_failure` Firebase 이벤트로 집계 가능. T-D1 에서 어느 소스를 쓸지 확정. 1차는 **`coop_marketing_api_log` 의 L1 실패** 만 집계 (서버 로그 기반, 가장 신뢰).

### 3.4 데이터 소스 (BigQuery 테이블)

| 용도 | 테이블 | 갱신 의존 |
|------|--------|----------|
| 등록 건수·매출·환불 | `hellobot-f445c.server_rdb.coop_marketing_coupon_usage` | server_rdb 동기화 DAG |
| 상품 매핑 (가격) | `hellobot-f445c.server_rdb.coop_marketing_product` | 동상 |
| 등록 실패 | `hellobot-f445c.server_rdb.coop_marketing_api_log` (process_type='L1' AND response_data.ResultCode != '0000') | 동상 |
| 신규 구매자 | `hellobot-f445c.hlb_mart_integrated.union_mart_user_key_actions` | `hellobot_datamart_mart_integrated_pipeline` (KST 11:00 트리거 체인 종료) |

> **주의**: 신규 구매자 KPI 는 mart_integrated 종료까지 대기해야 정확. sensor 를 mart_integrated 종료로 맞추면 발화 시각이 KST 11~12시까지 늦어질 수 있음. 정확성 vs 적시성 트레이드오프. **권장**: sensor 를 mart_integrated 종료로 설정 (정확성 우선). 운영팀에 "오전 중 도착" 사전 안내.

### 3.5 슬랙 발송 — `SlackAPI.post_message`

기존 `dags/scripts/etc/slack_alert_v2.py` 의 `SlackAPI(Variable.get("SLACK_API_TOKEN"))` 패턴 재사용. Webhook URL 이 아닌 Slack Bot Token 사용 → 채널 ID 동적 조회 (`get_channel_id("chatops-hellobot-kakao-gift")`).

신규 인프라 작업:
- Slack Bot 을 `#chatops-hellobot-kakao-gift` 채널에 invite (`/invite @hellobot_data_bot` 등)
- Airflow Variable `SLACK_API_TOKEN` 은 이미 존재 — 재사용

### 3.6 에러·장애 처리

| 단계 | 실패 시 처리 |
|------|------------|
| ExternalTaskSensor timeout | DAG 실패 → `on_failure_callback` → `#chatops_데이터_장애알림` ("ETL 미완료") |
| BQ 쿼리 실패 | 동상 ("쿼리 에러") |
| Slack API 호출 실패 | Airflow retries=2 (10분 간격) → 최종 실패 시 동상 |

## 4. 인프라 (`common-infra-eks-deploy`, MWAA)

### 4.1 hellobot-server 환경변수·시크릿

**위치**: `overlays/hlb/{prod,dev}/[apn1]/hellobot-server/`

```yaml
# kustomization.yaml 또는 ConfigMap/Secret patch
spec:
  template:
    spec:
      containers:
        - name: hellobot-server
          env:
            - name: KAKAO_GIFT_SLACK_NOTIFY_ENABLED
              value: "true"     # prod 초기값. OFF 시 "false" + ArgoCD sync
          envFrom:
            - secretRef:
                name: hellobot-server-secrets
---
# Secret patch (sealed-secrets 또는 external-secrets)
apiVersion: v1
kind: Secret
metadata:
  name: hellobot-server-secrets
stringData:
  SLACK_KAKAO_GIFT_NOTIFICATION_URI: https://hooks.slack.com/services/...
```

dev 환경: `KAKAO_GIFT_SLACK_NOTIFY_ENABLED=false` 또는 별도 dev 전용 채널 webhook.

### 4.2 Airflow Variable

MWAA / common-data-airflow Airflow UI:

| Variable | 값 | 비고 |
|---|---|---|
| `SLACK_API_TOKEN` | (기존) | 재사용 |
| `KAKAO_GIFT_LAUNCH_DATE_KST` | `2026-05-22` | (선택) DAG 상수로 두기보다 Variable 화 권장 |

### 4.3 슬랙 채널·Webhook 생성 절차 (T-I1)

1. Slack 워크스페이스에서 `#chatops-hellobot-kakao-gift` 채널 생성 (public, 운영팀·사업·CS·데이터 초대)
2. F1용 Incoming Webhook 앱 생성 → 채널 매핑 → URL 발급 → `SLACK_KAKAO_GIFT_NOTIFICATION_URI` Secret 등록
3. F2용 Bot 초대 (`@hellobot_data_bot` 또는 기존 슬랙 봇)
4. 운영 매뉴얼 1페이지 작성 (긴급 OFF: ① 환경변수 OFF + ArgoCD sync, ② 즉시 OFF 가 필요하면 Slack 측 앱 비활성화 또는 채널 알림 Mute)

## 5. 검증 항목 (구현 전 확정 필요)

| ID | 항목 | 담당 | 결과 반영 |
|----|------|------|----------|
| V1 | `coop-marketing.ts` 의 정확한 hook 위치 (processHeartCoupon/processSkillCoupon return 직전) | /dev-server (T-S1) | 본 문서 §2.1 갱신 |
| V2 | 기존 `notifyToSlack` 으로 카카오 쿠폰 알림이 이미 발송되는지 — 중복 방지 정책 | /dev-server (T-S1) | 필요 시 §2.1 에 분기 추가 |
| V3 | `coop_marketing_coupon_usage` BigQuery 적재 DAG·task 명 | /dev-data (T-D1) | §3.1 sensor 인자 갱신 |
| V4 | `mart_integrated` 종료 task 명 (신규 구매자 KPI 의존) | /dev-data (T-D1) | §3.1 sensor 인자 갱신 |
| V5 | `coop_marketing_api_log` 의 L1 실패 식별 컬럼 (response_data JSONB 스키마) | /dev-data (T-D1) | §3.3 실패 쿼리 갱신 |
| V6 | dev 환경에 `coop_marketing_*` 테이블이 적재되어 있는지 (DAG 동작 검증 가능 여부) | /dev-data (T-D1) | 출시 전 DAG smoke test 가능성 |

## 6. 위험·완화

| 위험 | 완화 |
|------|------|
| F1 알림 폭증 → 채널 과부하 | 환경변수 OFF (ArgoCD sync 수 분~10분). 긴급 시 Slack 측 앱 비활성화 |
| F1 Redis 장애 → 카운터 INCR 실패 | catch → notify 자체 skip (현 설계). 알림 누락은 운영 가시성 일시 손실로 한정 |
| F2 mart_integrated 지연 → 메시지 지연 (KST 12시까지) | sensor timeout 11:00 → 실패 알림. 운영팀에 "오전 중 도착" 사전 공지 |
| F2 신규 구매자 정의 변경 (data-measurement-plan) | DAG 내 쿼리 한 곳만 수정. data-measurement-plan §8.1 과 sync 유지 |
| 환경변수 OFF 후 운영팀 인지 못함 | 운영 매뉴얼에 "OFF 시 사업/CS Slack 별도 안내" 절차 명시 |

## Changelog

| 날짜 | 버전 | 변경자 | 내용 | 확인 |
|------|------|--------|------|------|
| 2026-05-19 | v1.0 | /architect | 신규 작성. F1 KakaoGiftNotifier 클래스·hook 위치·Redis INCR·환경변수 분기 / F2 DAG 구조·ExternalTaskSensor·BQ 집계 쿼리·SlackAPI 발송 / 인프라 매니페스트·Webhook·Airflow Variable / V1~V6 검증 항목 | - |
