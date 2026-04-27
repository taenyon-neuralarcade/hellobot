# 데이터 인프라 & ETL 문서화

## 배경

`common-data-airflow` 리포에 HelloBot의 ETL/데이터마트/리포트 파이프라인이 구축되어 있으나, 전체 구성과 흐름이 문서화되어 있지 않다.

- 현재 운영 중인 HelloBot DAG/데이터마트/리포트의 목록과 목적이 코드 외 형태로 정리되어 있지 않음
- 신규 데이터 수집/처리 시 기존 파이프라인 재사용 기준이 불명확
- 백엔드(RDS/BigQuery/Slack/Notion/GSheet) 간 데이터 흐름을 신규 참여자가 빠르게 파악하기 어려움

> 같은 리포에 StoryPlay/Between/TF 파이프라인도 존재하지만 이번 프로젝트의 대상은 **HelloBot만**이다. 공통 인프라(연결, 알림, 레이어 원칙)는 HelloBot 관점에서 필요한 수준으로만 정리한다.

## 목표

현재 구현된 ETL 프로젝트를 분석하여 **데이터 인프라 전체 그림과 데이터마트 카탈로그를 상시 참조 가능한 문서**로 정리한다. 개발 과업은 원칙적으로 없으며, 산출물은 문서다.

- 데이터 인프라 맵(외부 소스 → 스테이징 → 인터미디어트 → 마트 → 리포트) 정리
- 서비스별(HelloBot 중심) 데이터마트/리포트 테이블 카탈로그 작성
- 주요 KPI/지표 흐름과 데이터 정의 정리
- 신규 DAG/마트 추가 시 참고할 개발 가이드 초안 정비

## 범위

- **포함**
  - `common-data-airflow` 리포 내 **HelloBot 관련** DAG/스크립트/쿼리 분석 (`hlb_dags/`, `scripts/hellobot/`)
  - HelloBot 마트/리포트/KPI 카탈로그 정리
  - HelloBot 파이프라인이 사용하는 외부 시스템 연결(BigQuery, AWS RDS/S3, Slack, Notion, Google Sheets) 다이어그램화
  - 기존 분석 용도와 쓰임새 인벤토리 (어떤 의사결정/리포트가 어떤 마트를 참조하는지 가능한 범위)
  - 공통 인프라(태그 체계, 레이어 원칙, 알림 규칙)는 HelloBot 관점에서 필요한 수준만
- **제외**
  - StoryPlay/Between/TF 서비스 파이프라인 분석
  - `mart_integrated` 등 크로스 서비스 영역은 HelloBot 연결점만 언급, 내부 구조는 다루지 않음
  - 신규 DAG/마트 구현, 기존 파이프라인 리팩터링
  - 타 리포(server/web/app)의 데이터 모델 문서화 — 해당 리포의 관심사로 분리
  - 데이터 웨어하우스 비용 최적화 실행 (발견 사항은 issues.md에 기록만)

## 영향 범위

| 파트 | 영향 | 설명 |
|------|------|------|
| 기획 | O | 지표 정의 확인 및 현업 쓰임새 수집 필요 시 |
| 서버 | X | 해당없음 (소스 스키마 참고는 읽기 수준) |
| iOS | X | 해당없음 |
| Android | X | 해당없음 |
| 웹 | X | 해당없음 |
| 스튜디오 | X | 해당없음 |
| 데이터 | O | `/dev-data` 주도로 분석 및 문서 작성 |
| QA | X | 해당없음 |

## 산출물 위치

- **메인 카탈로그**: [`common-data-airflow/docs/hellobot-data/catalog/`](../../common-data-airflow/docs/hellobot-data/catalog/) — 2026-04-22 워크스페이스 `planning/` 에서 리포로 이전 완료 (단일 진실 원천)
  - 진입점: [`infra-map.md`](../../common-data-airflow/docs/hellobot-data/catalog/infra-map.md)
  - 카탈로그 동기화 규칙: `common-data-airflow/CLAUDE.md` §데이터 카탈로그 동기화
- **프로젝트 레벨** (이 디렉토리): 진행 기록, 의사결정 근거, 이슈 레지스트리
- **리포 레벨** (`common-data-airflow/docs/features/20260422-data-infra-documentation/`): 분석 과정, 결정 로그, 초안

## 문서 목록

| 문서 | 설명 |
|------|------|
| [status.md](./status.md) | 전체 진행 상태 |
| [tasks.md](./tasks.md) | 파트별 과업 목록 |
| [issues.md](./issues.md) | 이슈/개선사항 추적 (사본은 `common-data-airflow/docs/hellobot-data/catalog/issues.md` 에 존재) |
| **카탈로그** | [`common-data-airflow/docs/hellobot-data/catalog/`](../../common-data-airflow/docs/hellobot-data/catalog/) (메인 산출물 — 리포로 이전됨) |
