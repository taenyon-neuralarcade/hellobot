# TODO-046 하트 잔액 이상치(outlier) 사용자 정리 — heart-balance-mart 후속

**유형**: 액션
**상태**: 대기 (백로그 — 후속 시점 미정, 나중에라도 수행 가능하게 보존)
**등록**: 2026-06-12
**시작**: -
**완료**: -
**마감**: -
**담당**: 코디네이터 (BQ 추적은 /dev-data 위임, 운영 DB INSERT 는 사용자 승인·실행)
**관련**: [projects/20260513-heart-balance-mart/](../projects/20260513-heart-balance-mart/) (tasks.md §High-balance outlier 섹션이 과업 SSOT)

## 컨텍스트

heart-balance-mart 프로젝트의 R1 마트(`mart_user_heart_balance_daily`) 백필 검증 중 발견된 이상치 사용자 정리 후속 작업. R1 본류(마트 구축·일배치)는 2026-06-12 모니터링 완료로 종결됐고, 이상치 처리만 별도 TODO 로 분리 (사용자 지시 2026-06-12: "별도 후속 TODO로 남겨서 나중에라도 할 수 있게").

- **발견 (2026-05-21)**: balance ≥ 1000 normal heart 보유 실사용자 667명 분석 → subscription 86% / admin 9% / purchase 5%. admin-dominant 58명 description 전수 조사로 5개 카테고리 분류:
  - **A (입력 실수, 2명)**: `59927025`("지선 테스터" 10억), `49246379`("ㅁㄴㅇㄹ" 1천만)
  - **B (명백한 테스터·QA·운영진, 24명)**: user_seq 목록은 [tasks.md](../projects/20260513-heart-balance-mart/tasks.md) 참조
  - **C (직원 이름 명시 충전, 4명)**: `292000` "예리님" / `59121963` "수지님 요청" / `41560291` "박성희님 선물" / `18865870` "로블록스 마켓핏"
  - **D (2024-06-13 외부 시스템 이관 batch, 10명)**: user_seq `58286xxx~58287xxx` 연속, description `기존 하트 | 보너스 하트`, 사용 0
  - **E (2021-01~ 초기 "기존 하트" 단독, 18명)**: 베타·이전 시스템 이관 잔액 가설 (미검증)
- **처리 방안 (결정 2026-05-21)**: 기존 데이터파이프라인 표준 필터 `server_rdb.user_test_group` 재사용 — 추가만 하면 모든 마트에서 자동 제외. A·B 26명 INSERT SQL 은 5/21 세션에서 작성 완료 (운영 DB 미실행 — user_seq 목록은 tasks.md 에 보존되어 재생성 가능)
- **별건 이상치**: 음수 잔액 1건/일 (0.0001%, min_bal -1313 동일 user 추정) — heart_log 데이터 이상 여부 미조사
- **원본 자료**: `projects/20260513-heart-balance-mart/high-balance-outlier-candidates-20260522.csv` (로컬 보존 — 이메일·실명 PII 포함으로 의도적 미커밋)

## 현재 상태

분석·분류·처리 방안 결정까지 완료된 상태에서 동결. 실행 단계(운영 DB INSERT, C·D·E 데이터 추적, 음수 잔액 조사)는 모두 미착수. R1 마트 자체는 운영 안정 상태이므로 긴급하지 않음 — 단, A·B 26명이 `user_test_group` 에 없는 동안 평균 잔고 등 집계가 미세하게 오염될 수 있음 (667명 중 대부분은 정상 subscription 사용자라 영향 제한적).

## 다음 단계

- [ ] **A·B 26명 `user_test_group` INSERT** — 운영 PostgreSQL 실행 (사용자 승인·실행 필요. SQL 은 tasks.md user_seq 목록으로 재생성)
- [ ] **A 2명 잔여 하트 회수 요청** (운영팀) — `59927025`: 84,231 / `49246379`: 1,651
- [ ] **C 확장 식별** (/dev-data) — `description LIKE '%님%'` 패턴 + 직원 user_seq 매칭 쿼리
- [ ] **D batch 전체 식별** (/dev-data) — `event_date='2024-06-13' AND log_type='chargeByAdmin'` 범위 식별 후 마킹 정책 결정 (`is_migrated_user` 컬럼 신설 vs `user_test_group` 일괄 추가)
- [ ] **E batch 식별·가설 검증** (/dev-data) — `created_at < '2022-12-31' AND description='기존 하트' AND log_type='chargeByAdmin'` + 당시 가입 패턴으로 베타 이관 가설 검증
- [ ] **음수 잔액 1건/일 조사** — heart_log 이상치 여부 확인 (min_bal -1313 동일 user 추정)
- [ ] **모니터링 쿼리 정기화** — admin-dominant + description 키워드 신규 매칭 주기 탐지 SQL (운영진 신규 가입·QA 신규 충전 대응)

## 진행 로그

- 2026-05-21 — (heart-balance-mart 프로젝트 내) outlier 667명 분석, A~E 분류, `user_test_group` 재사용 방안 결정, A·B INSERT SQL 작성
- 2026-06-12 — R1 1주 모니터링 완료 (사용자 확인: BQ 파이프라인 정상 동작). 이상치 후속을 본 TODO 로 분리 등록 (사용자 지시 — 백로그로 보존, 나중에라도 수행)
