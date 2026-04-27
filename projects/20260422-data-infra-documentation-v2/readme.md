# 데이터 인프라 & ETL 문서화 — 2차 (지속 보강)

## 배경

[1차 프로젝트 (`20260422-data-infra-documentation`)](../20260422-data-infra-documentation/) 에서 HelloBot 데이터 카탈로그를 구축하고 SSOT([`common-data-airflow/docs/hellobot-data/catalog/`](../../common-data-airflow/docs/hellobot-data/catalog/))로 이전했습니다. 그러나 카탈로그 완성도는 부분적이며 (스코프가 `union_mart_user_key_actions` 계보로 한정됨, 외부 DB 의존 항목 미해결, recipes 1종만 존재 등), 다른 프로젝트 진행 시 누적적으로 보강해야 합니다.

본 프로젝트는 그 **지속 보강 활동을 묶는 장기 컨테이너**입니다.

## 목표

다른 프로젝트(coop-integration, billing-refund-regression 등)를 진행하며 식별되는 카탈로그 갭·신규 마트·이벤트·지표·레시피 등을 SSOT 에 점진적으로 추가하여 카탈로그 완성도를 높입니다.

## 운영 모드 (1차와 다른 점)

- **장기 진행** — 종료일을 미리 정하지 않음. 의미 있는 마일스톤(예: P1 마트 카탈로그 완성, recipes 4종 보강 등) 도달 시 마일스톤 단위로 정리·중간 회고
- **반응형 과업 추가** — 다른 프로젝트가 카탈로그 확장을 요구하는 시점에 tasks.md 에 신규 과업 추가
- **장기 보류 항목 주기 검토** — 분기마다 backlog 재평가하여 실현 가능/불가능 판별

## 범위

- **포함**
  - SSOT 카탈로그(`common-data-airflow/docs/hellobot-data/catalog/`) 의 모든 확장·보강
  - 다른 프로젝트가 새로 추가하는 마트·이벤트·지표의 카탈로그 등록 (해당 프로젝트의 `/dev-data` 책임이지만, 본 프로젝트가 catalog 정합성 추적)
  - SSOT issues.md 의 영속 이슈 추적·해결 (1차에서 이전된 ISS-002~011)
  - recipes 추가 (add-new-event / add-new-metric / add-new-mart 등)
- **제외**
  - 1차에서 이미 다룬 항목의 재작성 — 변경 사항은 SSOT 직접 갱신 (CLAUDE.md §데이터 카탈로그 동기화 규칙 적용)
  - 데이터 파이프라인 코드 변경 — 별도 개선 프로젝트 분리

## 영향 범위

| 파트 | 영향 | 설명 |
|------|------|------|
| 기획 | O | 지표 정의·오너십 협의 필요 시 |
| 서버 | X | |
| iOS | X | |
| Android | X | |
| 웹 | X | |
| 스튜디오 | X | |
| 데이터 | O | `/dev-data` 주도 |
| QA | X | |

## 산출물 위치

- **SSOT (메인 산출물 누적 위치)**: [`common-data-airflow/docs/hellobot-data/catalog/`](../../common-data-airflow/docs/hellobot-data/catalog/)
- **프로젝트 레벨** (이 디렉토리): 본 프로젝트의 진행 추적 — 백로그·결정·이슈
- **리포 레벨**: 별도 워크트리/`docs/features/` 작성하지 않음 — 직접 SSOT 갱신

## 1차 프로젝트와의 관계

| 항목 | 1차 (`20260422-data-infra-documentation`) | 2차 (본 프로젝트) |
|------|--------------------------------------------|------------------|
| 성격 | 1회성 구축 | 장기 보강 |
| 산출물 | 카탈로그 5종 + 내비게이션 + recipes 1종 + SSOT 이전 + 동기화 규칙 | SSOT 의 점진적 확장 |
| 종료 | 2026-04-22 (PR [#176](https://github.com/thingsflow/common-data-airflow/pull/176), [#177](https://github.com/thingsflow/common-data-airflow/pull/177)) | 미정 (마일스톤 단위 정리) |
| 백로그 인계 | §종료 정보 §미완 과업 | 본 프로젝트 [tasks.md](./tasks.md) 에 이전 |

## 문서 목록

| 문서 | 설명 |
|------|------|
| [status.md](./status.md) | 진행 상태, 마일스톤 추적 |
| [tasks.md](./tasks.md) | 백로그 + 신규 과업 |
| [issues.md](./issues.md) | 본 프로젝트 진행 중 발견된 이슈 (영속 이슈는 SSOT `catalog/issues.md` 추적) |
| **SSOT 카탈로그** | [`common-data-airflow/docs/hellobot-data/catalog/`](../../common-data-airflow/docs/hellobot-data/catalog/) (메인 산출물 위치) |
