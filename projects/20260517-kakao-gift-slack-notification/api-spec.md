# API 명세 — 카카오 선물하기 운영 슬랙 알림

> 본 프로젝트는 **신규 REST API 가 없습니다**. 단방향 알림(서버 → 슬랙, Airflow → 슬랙) 이므로 본 문서는 다음 세 종류의 "계약" 을 정의합니다:
>
> 1. **슬랙 메시지 contract** (F1·F2) — 발화 규약·필드 정의·예시
> 2. **환경변수·시크릿 contract** (서버 ↔ 인프라)
> 3. **Airflow Variable contract** (데이터 ↔ 인프라)

## 1. 슬랙 메시지 Contract

### 1.1 F1 — 쿠폰 등록 실시간 알림

| 항목 | 값 |
|------|---|
| 채널 | `#chatops-hellobot-kakao-gift` |
| 발화 주체 | hellobot-server (`KakaoGiftNotifier`) |
| 전송 방식 | Incoming Webhook (POST `{ "text": "..." }`) |
| 발화 조건 | `coupon_prefix_rule.coupon_type = 'coop_marketing'` 쿠폰의 `coop_marketing_coupon_usage` UPSERT(status='used') 완료 + 상품 지급(heart/skill) 완료 + 환경변수 `KAKAO_GIFT_SLACK_NOTIFY_ENABLED=true` |
| 발화 빈도 | 등록 1건당 1메시지 |
| 멱등성 | 보장 안 함 (재시도 미도입). Slack 측 중복은 동일 메시지 본문이라도 별건으로 노출 |

**메시지 본문 (mrkdwn, 6줄)**:

```
🎁 [카카오 선물하기] 쿠폰 등록
시각: {YYYY-MM-DD HH:mm:ss} KST
상품: {product_name} ({category_label})
금액: {price_krw:,}원
사용자: user_id=****{userSeqLast4}
오늘 누적: {todayCount}건째
```

**필드 정의**:

| 필드 | 소스 | 형식·규칙 |
|------|------|----------|
| 시각 | `coop_marketing_coupon_usage.used_at` (없으면 `now()`) | `YYYY-MM-DD HH:mm:ss`, `Asia/Seoul` 변환 |
| product_name | `coop_marketing_product.product_name` | 그대로 |
| category_label | `coop_marketing_product.product_type` 매핑 | `heart` → "하트 충전권", `skill` → "스킬 교환권" |
| price_krw | `coop_marketing_product.current_price ?? price` | `toLocaleString("ko-KR")` 천단위 콤마 |
| userSeqLast4 | `user.seq.toString().slice(-4).padStart(4, "0")` | 4자리 미만이면 0 패딩 |
| todayCount | Redis INCR `kakao:gift:daily_count:{YYYY-MM-DD KST}` 결과 | 1부터 시작 |

**예시**:

```
🎁 [카카오 선물하기] 쿠폰 등록
시각: 2026-05-22 14:23:11 KST
상품: 하트 1만원 충전권 (하트 충전권)
금액: 10,000원
사용자: user_id=****1234
오늘 누적: 23건째
```

### 1.2 F2 — 매일 오전 전일자 통계 푸시

| 항목 | 값 |
|------|---|
| 채널 | `#chatops-hellobot-kakao-gift` (F1 과 동일) |
| 발화 주체 | common-data-airflow `hellobot_kakao_gift_daily_slack` DAG |
| 전송 방식 | Slack Bot API (`chat.postMessage`) via `SlackAPI(Variable.get("SLACK_API_TOKEN")).post_message(channel_id, text)` |
| 발화 조건 | ExternalTaskSensor (선행 ETL 완료) 통과 후 즉시 |
| 발화 시각 | KST 09:00 schedule + sensor 대기 (실제 09:00~12:00 가변) |
| 발화 빈도 | 1일 1메시지 |

**메시지 본문**:

```
📊 [카카오 선물하기] 일일 리포트 — {d1} 자

▎ 어제 ({d1}) 성과
• 등록: {used_count}건 — 하트 {used_heart} · 스킬 {used_skill}
• 매출: {revenue_krw:,}원
• 신규 구매자: {new_buyers}명
• 환불·취소: {canceled_count}건
• 실패율: {failure_rate_pct}%

▎ 누적 (2026-05-22~{d1})
• 등록: {used_count_cum}건
• 매출: {revenue_cum:,}원
• 누적 등록자 (DISTINCT user): {distinct_users_cum}명

▎ {alerts_line}
```

**섹션 A — 어제 단일 (D-1)**:

| 필드 | 정의 | 소스 |
|------|------|------|
| `used_count` | `coop_marketing_coupon_usage` 중 어제 `used_at` 일자·`status='used'` 건수 | `server_rdb.coop_marketing_coupon_usage` |
| `used_heart` / `used_skill` | 위에서 `product_type` 별 분포 | + `coop_marketing_product` JOIN |
| `revenue_krw` | 어제 성공 등록건의 `current_price ?? price` 합계 | 동상 |
| `new_buyers` | 어제 `event_date` 의 카카오 신규 구매자 (coop-integration data-measurement-plan §8.1 정의) | `hlb_mart_integrated.union_mart_user_key_actions` |
| `canceled_count` | `coop_marketing_coupon_usage` 중 어제 `canceled_at` 일자·`status='canceled'` 건수 | `coop_marketing_coupon_usage` |
| `failure_rate_pct` | `L1 실패 / (L1 실패 + 성공)` × 100, 소수 1자리 | `coop_marketing_api_log` (process_type='L1', response_data.ResultCode≠'0000') |

**섹션 B — 누적 (출시일 ~ D-1)**:

| 필드 | 정의 |
|------|------|
| `used_count_cum` | 출시일(2026-05-22) ~ 어제 사이 `status='used'` 합계 |
| `revenue_cum` | 동기간 성공 등록건 가격 합계 |
| `distinct_users_cum` | 동기간 성공 등록한 `DISTINCT user_seq` |

**섹션 C — 이상 신호 (조건부 표기)**:

| 조건 | 표기 |
|------|------|
| `failure_rate_pct > 5.0` | `🚨 실패율 X% (>5%)` |
| `used_count == 0` | `⚠️ 등록 0건` (출시 1주차 이후에만 의미) |
| `canceled_count / used_count > 0.10` | `⚠️ 환불율 X%` |
| 위 모두 아님 | `✅ 이상 신호 없음` |

**예시**:

```
📊 [카카오 선물하기] 일일 리포트 — 2026-05-23 자

▎ 어제 (2026-05-23) 성과
• 등록: 47건 — 하트 38 · 스킬 7
• 매출: 583,000원
• 신규 구매자: 18명
• 환불·취소: 1건
• 실패율: 4.3%

▎ 누적 (2026-05-22~2026-05-23)
• 등록: 89건
• 매출: 1,107,000원
• 누적 등록자 (DISTINCT user): 34명

▎ ✅ 이상 신호 없음
```

### 1.3 메시지 변경 정책

- 본 문서가 두 메시지의 단일 출처 (SSOT). 변경 시 Changelog 등록 후 코드 반영
- 1.1·1.2 필드 추가는 호환 변경 (기존 운영팀 read 영향 없음). 필드 제거·이름 변경은 운영팀 사전 공지 필요
- 1.3 의 이상 신호 임계값(5%, 10%, 0건)은 출시 후 1주 피드백 루프에서 재조정 가능

## 2. 환경변수·시크릿 Contract (서버 ↔ 인프라)

### 2.1 hellobot-server 가 읽는 키

| 키 | 출처 | 타입 | 필수 | 기본값 | 비고 |
|---|---|---|---|---|---|
| `KAKAO_GIFT_SLACK_NOTIFY_ENABLED` | k8s ConfigMap or Deployment env | `string` (`"true"`/`"false"`) | O | 운영 `"true"`, dev `"false"` | OFF 시 등록 hook 진입 즉시 return (Redis·Webhook 호출 안 함) |
| `SLACK_KAKAO_GIFT_NOTIFICATION_URI` | k8s Secret (`hellobot-server-secrets`) | `string` (Slack Incoming Webhook URL) | O (위 ENABLED=true 시) | - | 키 누락 시 logger.warn + skip (등록은 정상) |

**dev 환경**: 별도 dev 전용 채널 + Webhook 사용 권장. 또는 ENABLED=false 로 운영 채널 오염 방지.

### 2.2 인프라가 제공해야 하는 리소스 (T-I1~T-I3)

| 리소스 | 위치 | 비고 |
|--------|------|------|
| Slack 채널 `#chatops-hellobot-kakao-gift` | Slack workspace | 운영팀·사업·CS·데이터 초대 (D1 확정) |
| Slack Incoming Webhook URL | Slack App settings → 채널 매핑 | 발급 후 `SLACK_KAKAO_GIFT_NOTIFICATION_URI` 로 등록 |
| k8s Secret | `common-infra-eks-deploy/overlays/hlb/{prod,dev}/[apn1]/hellobot-server/` | sealed-secrets 또는 external-secrets 패턴 |
| ConfigMap/env | 동상 | `KAKAO_GIFT_SLACK_NOTIFY_ENABLED` |

## 3. Airflow Variable Contract (데이터 ↔ 인프라)

### 3.1 DAG 가 읽는 키

| 키 | 출처 | 타입 | 필수 | 기본값 | 비고 |
|---|---|---|---|---|---|
| `SLACK_API_TOKEN` | Airflow Variable | string (Slack Bot OAuth Token, `xoxb-...`) | O | (기존) | 재사용. Bot 이 `#chatops-hellobot-kakao-gift` 채널에 invite 되어야 발송 가능 |
| `KAKAO_GIFT_LAUNCH_DATE_KST` (선택) | Airflow Variable | string `YYYY-MM-DD` | △ | `2026-05-22` | DAG 코드 상수 vs Variable 화 — `/dev-data` 결정. 출시일 변경 시 코드 수정 회피용으로 Variable 권장 |

### 3.2 인프라가 제공해야 하는 리소스 (T-I4)

| 리소스 | 위치 | 비고 |
|--------|------|------|
| Slack Bot 채널 초대 | Slack workspace | `/invite @hellobot_data_bot` (가칭 — 기존 봇 이름 확인 필요) |
| BigQuery 권한 | `hellobot-f445c` 프로젝트 | DAG 실행 SA 가 `server_rdb.coop_marketing_*` 와 `hlb_mart_integrated.union_mart_user_key_actions` 에 read 권한 있어야 함 (기존 hellobot DAG 와 동일 SA 면 재확인만) |

## 4. ExternalTaskSensor Contract (데이터 내부)

본 DAG 가 의존하는 선행 DAG 의 task 명세. T-D1 에서 확정 후 본 표 갱신.

| 항목 | 값 (T-D1 확정 전 임시) | 비고 |
|------|------------------------|------|
| `external_dag_id` | TBD — 후보: `hellobot_datamart_mart_integrated_pipeline` | 신규 구매자 KPI 의존 시 mart_integrated 종료 대기 |
| `external_task_id` | TBD — 후보: 해당 파이프라인의 종료 task | None 이면 DAG 전체 완료 대기 |
| `execution_delta` | `timedelta(0)` | 동일 KST 일자 |
| `timeout` | `2h` | 11:00 KST 까지 대기 |
| `mode` | `"reschedule"` | worker slot 점유 회피 |

## 5. 변경 가이드라인

| 변경 종류 | 영향 |
|----------|------|
| F1 메시지 필드 추가 | 서버 코드 + 본 §1.1 필드 정의 표 갱신 |
| F1 메시지 필드 제거·이름 변경 | 운영팀 사전 공지 + 서버 코드 + 본 문서 + Changelog |
| F2 지표 추가 | DAG `build_daily_metrics` / `build_cumulative_metrics` 수정 + 본 §1.2 + 메시지 포맷 |
| F2 임계값 조정 (5%, 10%, 0건) | DAG `format_message` 수정 + 본 §1.2 섹션 C + Changelog |
| 환경변수 명 변경 | 본 §2 + 인프라 매니페스트 + 서버 코드 동시 |
| 채널 변경 | 인프라 (채널 생성 + Webhook 재발급) + Slack Bot 초대 + 본 문서 §1·§2 |

## Changelog

| 날짜 | 버전 | 변경자 | 내용 | 확인 |
|------|------|--------|------|------|
| 2026-05-19 | v1.0 | /architect | 신규 작성. F1·F2 슬랙 메시지 contract / 환경변수·시크릿 contract / Airflow Variable contract / ExternalTaskSensor contract | - |
