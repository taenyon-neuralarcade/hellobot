# 카카오 선물하기 운영 슬랙 알림

## 배경

카카오 선물하기 채널이 [coop-integration](../20260324-coop-integration/) 프로젝트로 출시(2026-05-22 1차)되지만, 운영팀이 채널의 실시간 흐름과 일일 성과를 슬랙으로 인지할 수단이 없습니다. 출시 초기 운영 가시성이 결정적인 시점에 BigQuery·Looker 대시보드를 별도로 열어 확인해야 하므로, 이상 신호 인지가 지연되고 운영 루틴화도 어렵습니다.

본 프로젝트는 **운영팀 전용 슬랙 채널**에 두 가지 알림을 추가합니다:

1. **쿠폰 등록 실시간 알림** — 카카오 선물하기 쿠폰이 등록되는 시점에 즉시 푸시 (ON/OFF 토글 포함)
2. **매일 오전 9시 전일자 통계 푸시** — 어제 등록 건수·매출·신규 구매자·환불 등 요약

상세 동기·트레이드오프: [1pager.md](./1pager.md)

## 목표

- 카카오 선물하기 출시 직후 운영팀의 실시간 가시성 확보
- 매일 어제 성과를 별도 액션 없이 슬랙으로 인지 가능한 일일 리포트 채널 구축
- 출시 안정화 후에도 지속 운영 가능한 가벼운 운영 도구 (DAG + Webhook)

## 범위

### 포함

- F1. 카카오 선물하기 쿠폰 등록 시 슬랙 채널 실시간 알림
- F1-1. Admin 페이지의 ON/OFF 토글 (즉시 반영, DB 설정 테이블 기반)
- F2. 매일 KST 09:00 슬랙 채널 전일자 통계 푸시 (Airflow DAG)
- F2-1. DAG 실패 시 `SLACK_DATA_ERROR_CHANNEL` 로 에러 알림
- 신규 슬랙 채널 1개(또는 기존 채널 활용 결정) + Webhook URL k8s Secret 등록

### 제외

- 헬로우봇 일반 쿠폰·giftiel 등 카카오 외 발급처 알림 (기존 `notifyToSlack` 의 동작은 유지하되 본 프로젝트는 카카오 분기만)
- 시간당 N건 초과 시 배치 요약 모드 (피드백 루프 후속 검토)
- 운영팀 대화형 액션(쿠폰 강제 취소·환불 등 인터랙티브 메시지) — 본 프로젝트는 단방향 알림만
- Looker 대시보드 신규 구축 — 기존 [coop-integration 의 `data-measurement-plan.md`](../20260324-coop-integration/data-measurement-plan.md) 의 분석 SSOT 재사용
- iOS·Android·웹 클라이언트 변경 — 본 프로젝트는 서버·데이터·인프라만

## 영향 범위

| 파트 | 영향 | 설명 |
|------|------|------|
| 서버 | O | F1 쿠폰 등록 알림 발송 로직 (기존 `notifyToSlack` 유틸 확장), Admin 페이지 ON/OFF 토글, 카카오 라우팅 분기 (`coupon_prefix_rule` 활용) |
| 데이터 | O | F2 Airflow DAG (매일 09:00 KST), BigQuery `coop_marketing_coupon_usage` 등 일배치 결과 집계, 슬랙 발송 task |
| 인프라 | O | 슬랙 Webhook URL k8s Secret 등록 (`SLACK_KAKAO_GIFT_NOTIFICATION_URI` 가칭), Airflow Variable 등록 |
| iOS | X | 해당없음 |
| Android | X | 해당없음 |
| 웹 | X | 해당없음 |
| 스튜디오 | X | 해당없음 |

## 가설 (검증 필요)

`/analyze` 단계에서 코드 미열람 가설로 진행. `/architect` 또는 `/dev-server`·`/dev-data` 가 검증 후 확정.

1. **G1. 기존 `notifyToSlack` 의 카카오 쿠폰 알림 범위는 부분적이거나 미정** — Explore 결과 `#chatops_hellobot_coupon` 채널에 일부 알림이 가지만, "카카오 선물하기만" 격리 분기는 부재로 추정
2. **G2. `coop_marketing_coupon_usage` + `coupon_prefix_rule` join 으로 카카오 vs 일반을 분기 가능** — Explore 결과 prefix `90`/`91` 등이 `coop_marketing` 타입 매칭
3. **G3. BigQuery `coop_marketing_coupon_usage` 일배치 ETL 은 KST 09:00 이전 종료** — 일반적인 일배치 cadence 가정. 종료 시각 미확인 시 DAG sensor 또는 09:30 등 안전 시간대로 조정
4. **G4. 신규 슬랙 채널 1개 생성이 운영팀 정책상 허용됨** — 사업·운영 합의 필요. 기존 `#chatops_hellobot_coupon` 채널 분기로 대체 가능
5. **G5. Admin ON/OFF 토글은 기존 Admin 페이지(AdminJS) 의 설정 테이블 패턴으로 구현 가능** — `hellobot-server/admin` 에 시스템 설정 테이블 존재 가정

## 확정 사항 (D1~D9, 2026-05-19)

`/analyze` 시점에 사용자 결정으로 확정. 일부 항목은 가설로 1차 확정 → `/architect`·`/dev-*` 가 코드 검증 후 최종.

| # | 항목 | 확정 | 비고 |
|---|------|------|------|
| D1 | 알림 대상 채널 | **신규 채널 `#chatops-hellobot-kakao-gift`** | F1·F2 동일 채널 사용. T-I1 에서 채널 생성 + Webhook 발급 |
| D2 | 쿠폰 등록 트리거 시점 | **`POST /api/coupon/register` 성공 시 (서버 사이드 hook)** | 가설 — T-S1 코드 검증 후 최종 |
| D3 | F1 알림 항목 (필수) | 시각, 상품명, 카테고리, 금액, 사용자 ID(마스킹 ****1234), 그날 누적 등록 건수 | 발급 채널·재고·만료일은 1차 제외 |
| D4 | F2 일별 통계 항목 (필수) | 등록 건수·매출·신규 구매자·환불·실패율 + 누적(출시일~어제) | 시간대별 분포·상품별 매진율은 후속 |
| D5 | F2 데이터 소스 | **BigQuery `coop_marketing_coupon_usage` 일배치** | coop-integration data-measurement-plan §2.1 KPI 정의 재사용 |
| D6 | F2 기술 스택 | **Airflow DAG (common-data-airflow)** | DAG 명: `hellobot_kakao_gift_daily_slack.py` 가칭 |
| D7 | F1 ON/OFF 토글 구현 | **환경변수 + 재시작** | Admin UI 작업 없음. OFF 가 필요한 시점엔 ArgoCD sync 필요(수 분~10분). 환경변수명 `KAKAO_GIFT_SLACK_NOTIFY_ENABLED` 가칭. → §결정 트레이드오프 참조 |
| D8 | 에러·장애 처리 | **F1: 알림 실패 시 서버 로그만 (트랜잭션 영향 없음), F2: DAG 실패 시 `SLACK_DATA_ERROR_CHANNEL` 알림** | 재시도 큐 미도입 |
| D9 | F2 발화 시각 | **ETL 완료 sensor 후 즉시 발화 (동적)** | 발화 시각 가변(09:00~10:00 예상). T-D1 에서 의존 ETL DAG·완료 마커 식별 필요. 운영팀에 "오전 중 도착" 사전 안내 필요 |

### 결정 트레이드오프 (D7 환경변수 선택 영향)

D7 을 환경변수로 결정한 결과 1pager 의 "즉시 OFF" 요구사항(F1 §1.3 반영 즉시성)이 변경됩니다. `/architect` 와 운영 매뉴얼에 다음 사항을 명시해야 합니다:

- **OFF 절차**: 환경변수 변경 → PR 머지 → ArgoCD sync 대기 (실측 수 분~10분)
- **긴급 OFF 대안**: 알림 폭증으로 즉시 차단이 필요하면 슬랙 채널 측에서 Webhook 비활성화 또는 슬랙 채널 Mute (서버 측 변경 없음). 운영 매뉴얼에 절차 기재
- **장점**: Admin UI·DB 설정 테이블 신설 불필요, 시크릿과 동일 관리 패턴, 코드 단순

## 의존 관계

- 본 프로젝트는 [coop-integration](../20260324-coop-integration/) 의 카카오 선물하기 출시(2026-05-22 1차)에 맞춰 운영 가시성을 보강하는 운영 도구 트랙입니다.
- F1 (서버) 은 `coop-integration` 의 `POST /api/coupon/register` 엔드포인트와 `coupon_prefix_rule` 분기 로직에 직접 의존합니다.
- F2 (데이터) 는 `coop-integration` 의 `data-measurement-plan.md` 의 KPI 정의(신규 구매자·매출 등)를 재사용합니다.

## 문서 목록

| 문서 | 설명 |
|------|------|
| [1pager.md](./1pager.md) | 프로젝트 1-pager (PRD) |
| [readme.md](./readme.md) | 본 문서 — 요구사항·배경·영향 범위 |
| [requirements.md](./requirements.md) | 상세 요구사항 정의서 (F1·F2 기능 명세) |
| [status.md](./status.md) | 진행 상태 |
| [tasks.md](./tasks.md) | 파트별 과업 목록 |
| (이후) architecture.md | `/architect` 가 작성 — 데이터 모델·시퀀스·메시지 포맷 |
| (이후) api-spec.md | `/architect` 가 작성 — Admin 토글 API |

## 일정

- 2026-05-17 (오늘) — `/analyze` 프로젝트 생성, PRD·요구사항 작성
- 2026-05-18~19 — D1~D8 결정 필요 항목 사용자 확정 → `/architect` 호출
- 2026-05-20 (TODO-016 마감) — 설계 완료, 구현 위임 결정. F2(데이터)·F1(서버) 분할 위임 또는 둘 다 동시 진행
- 2026-05-22 (coop-integration 1차 출시) 이후 — F1 알림 운영 검증
- 2026-05-26 이후 — F2 일일 통계 첫 푸시 (출시 후 누적 데이터 확보 시점)

## 관련 TODO

- [TODO-016](../../todos/TODO-016-kakao-gift-slack-notification.md) — 본 프로젝트의 소스 TODO. 본 프로젝트로 승격되어 `프로젝트로 추적` 섹션으로 이동
