# 과업 목록

## 기획 (planning/)

- [x] PRD (`1pager.md`) 작성 — 2026-05-17
- [x] 요구사항 정의서 (`requirements.md`) 작성 — 2026-05-17
- [x] 영향 범위·가설·결정 필요 항목 정리 (`readme.md`) — 2026-05-17
- [x] D1~D9 결정 필요 항목 사용자 확정 — 2026-05-19 (D1 신규채널 `#chatops-hellobot-kakao-gift`, D5 BigQuery, D7 환경변수, D9 ETL sensor)
- [x] requirements.md 결정 사항 반영 (1.3 토글 환경변수, 2.1 ETL sensor) — 2026-05-19
- [ ] (선택) F2 메시지 포맷 운영팀 리뷰 — 출시 후 1주차에 피드백 수집
- [ ] 운영팀에 F2 발화 시각 가변(09:00~12:00, mart_integrated 종료 후) 사전 공지 — 출시 전
- [ ] F1 긴급 OFF 매뉴얼 작성 (환경변수 변경 절차 + 슬랙 측 Webhook 비활성화 대안)

## 설계 (`/architect`)

- [x] architecture.md 작성 — F1·F2 통합 설계 (2026-05-19)
- [x] api-spec.md 작성 — 슬랙 메시지·환경변수·Airflow Variable contract (2026-05-19)
- [ ] V1·V2 (서버) / V3·V4·V5 (데이터) / V6 (데이터 dev 환경) — 구현 단계에서 코드 검증 후 본 문서 갱신

## 서버 (`/dev-server`)

- [ ] T-S1. 가설 G1·G2 검증 — `notifyToSlack` 의 현재 카카오 쿠폰 알림 범위, `coupon_prefix_rule` 의 카카오 분기 식별 컬럼 확인
- [ ] T-S2. F1 쿠폰 등록 알림 발송 로직 구현 (카카오 분기, 메시지 포맷, 마스킹)
- [ ] T-S3. 환경변수 `KAKAO_GIFT_SLACK_NOTIFY_ENABLED` (가칭) 추가 + 로직에서 분기 (D7 환경변수 확정 — Admin UI 작업 없음)
- [ ] T-S4. 누적 카운터 — 그날 KST 자정 이후 등록 건수 산출 (Redis 캐시 또는 PostgreSQL 쿼리, `/architect` 결정)
- [ ] T-S5. Webhook 실패 시 에러 로깅·트랜잭션 영향 차단
- [ ] T-S6. 통합 테스트 — 카카오/일반 쿠폰 분기, 환경변수 ON/OFF, Webhook 실패 케이스

## 데이터 (`/dev-data`)

- [ ] T-D1. 의존 ETL DAG·완료 마커 식별 — `coop_marketing_coupon_usage` 일배치 ETL 의 DAG 명·task id·완료 신호(ExternalTaskSensor/Dataset/BQ table) 확정. (D9 sensor 결정의 선행)
- [ ] T-D2. Airflow DAG 생성 — `hellobot_kakao_gift_daily_slack.py` (가칭). ETL 완료 sensor → 집계 → 슬랙 발송. sensor timeout 11:00 (가칭)
- [ ] T-D3. BigQuery 집계 쿼리 — 어제 단일 + 출시일 이후 누적 (5 지표 × 2 섹션)
- [ ] T-D4. 슬랙 메시지 포맷팅 (requests.post + Webhook URL)
- [ ] T-D5. 이상 신호 임계값 적용 (실패율 5%, 환불율 10%)
- [ ] T-D6. on_failure_callback + sensor timeout 시 `SLACK_DATA_ERROR_CHANNEL` 에러 알림
- [ ] T-D7. 출시 전 DAG schedule OFF, 출시 후 활성화 운영 절차 작성

## 인프라 (`/dev-infra`)

- [ ] T-I1. 슬랙 워크스페이스에서 신규 채널 `#chatops-hellobot-kakao-gift` 생성 + Webhook 발급 (D1 확정)
- [ ] T-I2. Webhook URL k8s Secret 등록 (`SLACK_KAKAO_GIFT_NOTIFICATION_URI` 가칭) — `common-infra-eks-deploy`
- [ ] T-I3. 환경변수 `KAKAO_GIFT_SLACK_NOTIFY_ENABLED=true` 등록 — `common-infra-eks-deploy` (D7 확정)
- [ ] T-I4. Airflow Variable 등록 (동일 Webhook URL) — `common-data-airflow` 또는 MWAA

## 웹 (`/dev-web`)

해당없음

## iOS (`/dev-ios`)

해당없음

## Android (`/dev-android`)

해당없음

## 스튜디오 (`/dev-studio`)

해당없음

## QA (`/qa`)

- [ ] T-Q1. F1·F2 의 검증 기준 (`requirements.md §4`) 기반 테스트 케이스 작성
- [ ] T-Q2. 출시 후 1주차 운영 검증 — F1 알림 정확성, F2 메시지 수치 정합

## 의존 관계

```
설계 (D1~D9 확정 ✅ → /architect)
    │
    ├─ 서버 (T-S1~T-S6) ── 출시 (5/22 coop-integration) ── F1 운영 검증
    │
    ├─ 데이터 (T-D1~T-D7) ── 5/23 첫 F2 메시지
    │
    └─ 인프라 (T-I1~T-I4) ── 서버·데이터 시작 전 완료 (선행)
```

- **인프라 (T-I1~T-I4)** 가 선행 — 서버·데이터 모두 Webhook URL 필요. T-I3 환경변수도 서버 구현 전 등록
- **서버 F1 출시** 는 [coop-integration](../20260324-coop-integration/) 의 1차 출시(5/22) 와 동시 또는 직후
- **데이터 F2 첫 발송** 은 출시 +1 일 (5/23) — 누적 데이터 1일치 확보 후
- **G1·G2 검증 (T-S1)** 는 서버 구현 착수 전 필수 — 기존 `notifyToSlack` 의 카카오 쿠폰 알림이 이미 있다면 중복 방지·통합 정책 결정 필요
- **T-D1 (의존 ETL DAG 식별)** 는 T-D2 의 선행 — sensor 대상 확정되어야 DAG 구조 결정
