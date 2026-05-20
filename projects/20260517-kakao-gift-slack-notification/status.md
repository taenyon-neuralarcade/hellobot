# 개발 상태

## 현재 상태: 설계완료 — `/dev-infra` 선행 후 `/dev-server`·`/dev-data` 병렬

## 파트별 현황

| 파트 | 상태 | 브랜치 | 워크트리 | 비고 |
|------|------|--------|---------|------|
| 기획 | 완료 | - | - | `/analyze` PRD·요구사항·D1~D9 확정 (2026-05-19) |
| 설계 | 완료 | - | - | `/architect` architecture.md + api-spec.md 작성 (2026-05-19). V1~V6 검증은 구현 단계에서 처리 |
| 서버 | 대기 | - | - | F1 KakaoGiftNotifier 클래스 + coop-marketing.ts hook. T-S1 검증(V1·V2) 선행 |
| 데이터 | 대기 | - | - | F2 hellobot_kakao_gift_daily_slack DAG. T-D1 검증(V3·V4·V5) 선행 |
| 인프라 | 대기 | - | - | T-I1~T-I4: Slack 채널 생성·Webhook·환경변수·Airflow Variable |
| iOS | 해당없음 | - | - | |
| Android | 해당없음 | - | - | |
| 웹 | 해당없음 | - | - | |
| 스튜디오 | 해당없음 | - | - | |
| QA | 대기 | - | - | F1·F2 검수 — 출시 후 운영 검증 |

## 블로커

- 없음. D1~D9 사용자 확정 완료 (2026-05-19)

## 확정 사항

| 항목 | 내용 |
|------|------|
| 프로젝트 생성일 | 2026-05-17 |
| 분석완료일 | 2026-05-19 |
| 설계완료일 | 2026-05-19 |
| 영향 범위 | 서버 + 데이터 + 인프라 (클라이언트 X) |
| 일정 | 5/22 출시 직후 F1 가동, 5/23 첫 F2 메시지 |
| 의존 프로젝트 | [coop-integration](../20260324-coop-integration/) — 출시 일정 5/22 |
| 소스 TODO | [TODO-016](../../todos/TODO-016-kakao-gift-slack-notification.md) |
| 핵심 결정 (D1) | 신규 슬랙 채널 `#chatops-hellobot-kakao-gift` |
| 핵심 결정 (D5) | F2 데이터 소스: BigQuery `coop_marketing_coupon_usage` 일배치 |
| 핵심 결정 (D7) | F1 토글: 환경변수 `KAKAO_GIFT_SLACK_NOTIFY_ENABLED` + 재시작 |
| 핵심 결정 (D9) | F2 발화: ETL 완료 sensor 후 동적 발화 (09:00~12:00 가변, mart_integrated 종료 후) |
| 설계 결정 (F1) | KakaoGiftNotifier 신규 클래스, hook = coop-marketing.ts 의 usage 갱신 직후, Redis INCR 누적 카운터, fire-and-forget |
| 설계 결정 (F2) | DAG `hellobot_kakao_gift_daily_slack`, ExternalTaskSensor → BQ 집계 → SlackAPI.post_message (기존 `slack_alert_v2` 패턴) |

## 다음 단계

1. **`/dev-infra`** 선행 — T-I1 채널 생성·Webhook 발급, T-I2 k8s Secret, T-I3 환경변수, T-I4 Airflow Bot 초대
2. **`/dev-server`** (병렬) — T-S1 V1·V2 검증 → T-S2~T-S6 구현
3. **`/dev-data`** (병렬) — T-D1 V3·V4·V5 검증 (선행 ETL DAG·task 식별, L1 실패 컬럼 확정) → T-D2~T-D7 구현
4. F1 출시 5/22 (coop-integration 1차 출시 직후), F2 첫 발송 5/23 (D-1 데이터 1일치 확보 후)
5. 출시 후 1주차 운영팀 피드백 루프 — 메시지 포맷·임계값 재조정 검토
