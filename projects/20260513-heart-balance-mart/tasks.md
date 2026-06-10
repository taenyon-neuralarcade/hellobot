# 과업 — 일자별 보유 하트 잔액 마트

## 스코프 (2026-05-15 확정)

- **포함**: R1 (사용자별 일자별 잔고·증감), R2 (전체 평균 잔고 추이)
- **제외**: 하트 사용 취소 이벤트 추적 / Hackle·GA 이벤트 발화·연동 (readme.md §Requirement 참조)

## 데이터 (/dev-data)

### 설계 단계 (완료 — 유형 A)

- [x] 원천 SSOT 식별 — `server_rdb.heart_log[_detail]` 확정, 옛 위치 stale 확인 ([ISS-017](../../common-data-airflow/docs/hellobot-data/catalog/issues.md))
- [x] 잔액 산식 정의 (서버 `getUsableHeart` 와 동등, server_rdb.* 기준)
- [x] self-ref 가정 실측 검증 (NULL 0, self-ref 80.09%, 사용 19.91%)
- [x] 1일치 풀 recompute 비용 측정 (dry-run 10.16 GB / $0.05)
- [x] 마트 설계 초안 (`mart_user_heart_balance_daily` + 보조 `mart_user_heart_flow_daily`)
- [x] 카탈로그 SSOT 정정 + 신규 staging 테이블 문서 등록
- [x] 요구사항 스코프 확정 (R1+R2, 사용취소·Hackle·GA 제외)
- [ ] R2 리포트 마트 설계 (`report_avg_heart_balance_daily`) — 모집단·분포 컬럼 정의 → architecture.md 반영

### 구현 단계 — R1 (유형 B 전환)

- [x] 워크트리 생성 — `Feat/heart-balance-mart` 브랜치 + `projects/20260513-heart-balance-mart/worktrees/common-data-airflow/` (2026-05-15)
- [x] SQL: `dags/scripts/hellobot/mart/mart_user_heart_balance_daily.sql` (산식 + GENERATE_DATE_ARRAY 다일자 일괄 산출)
- [x] SQL: `dags/scripts/hellobot/mart/mart_user_heart_flow_daily.sql` (보조)
- [x] queries.py — 2개 쿼리 추가 (CREATE TABLE IF NOT EXISTS + DELETE + INSERT 패턴)
- [x] mart_func.py — `update_mart_user_heart_balance_daily_table`, `update_mart_user_heart_flow_daily_table` 추가 (`run_query_with_previous_date(days_before=2)`)
- [x] DAG: `hellobot_datamart_mart_pipeline.py` — task 2개 + dummy_task → tasks → success 체인 등록
- [x] 카탈로그 갱신 — `tables/mart/mart_user_heart_balance_daily.md`, `mart_user_heart_flow_daily.md` 신규, `mart-catalog.md` 인벤토리 추가
- [x] dry-run 비용 검증 — balance 11.3 GB / $0.057, flow 5.1 GB / $0.026 (1일·1년 동일, BQ 컬럼 스캔 1회)
- [x] Python syntax 검증 (ast.parse)
- [x] PR 생성 — [#185](https://github.com/thingsflow/common-data-airflow/pull/185) (Feat/heart-balance-mart → develop, 2026-05-15)
- [x] PR 머지 완료 (commit 2494343, 2026-05-20)
- [x] **전체 백필 실행** (2021-01-21 ~ 2026-05-19, 1,945일)
  - balance 마트: **917M rows** 적재
  - flow 마트: **63M rows** 적재
  - 정상성: 5월 최근 5일 평균 잔액 214 하트, 67.6만 사용자/일. flow 부호 (충전+/사용−) 정상
  - 알려진 이슈: 음수 잔액 1건/일 발견 (0.0001%) — 추후 조사
- [x] **일배치 운영 모드 전환** (수동 → mart_pipeline 스케줄에 흡수) — 2026-05-21 Airflow develop sync + 옵션 A 전체 `hellobot_datamart_mart_pipeline` 수동 트리거로 5/20·5/21 파티션 추가 적재 검증 완료. balance +1.35M / flow +10.8K rows. avg balance 214.6~214.8 안정. 다음 KST 11시부터 자동 흡수.
- [ ] 1주 모니터링 (5/22~5/28 daily run 정상성 확인 — D-2~D 부분 갱신, row count 안정성)
- [ ] 음수 잔액 케이스 조사 (1건/일, min_bal -1313 동일 user 추정)

### High-balance outlier 분석 및 정리 (2026-05-21 신규 발견)

balance ≥ 1000 normal heart 보유 실사용자 667명 분석 결과 — admin-dominant 그룹 59명 중 대다수가 테스터·운영진·이관 batch.

- [x] balance ≥ 1000 사용자 분포·클러스터링 (subscription 86% / admin 9% / purchase 5%)
- [x] admin-dominant 58명 description 전수 조사 → 5개 카테고리(A·B·C·D·E) 분류
- [ ] **카테고리 A·B 26명 `user_test_group` 추가** — PostgreSQL INSERT SQL 작성 완료, 운영 DB 실행 대기
  - A(입력 실수): `59927025`("지선 테스터" 10억), `49246379`("ㅁㄴㅇㄹ" 1천만)
  - B(명백한 테스터·QA·운영진, description 키워드 매칭): `49034964 / 58756086 / 8711371 / 17431069 / 21707213 / 25602775 / 43 / 50128064 / 21785977 / 516548 / 1274100 / 16400216 / 60085277 / 24074438 / 306731 / 61977816 / 73546674 / 20500192 / 53635653 / 4008668 / 45951377 / 5043386 / 16290221 / 40209138`
- [ ] **카테고리 A 2명 잔여 하트 회수 요청** (운영팀) — `59927025`: 84,231 / `49246379`: 1,651
- [ ] **카테고리 C 4명 — 데이터 추적**: 직원 이름 명시 충전 (`292000` "예리님" / `59121963` "수지님 요청" / `41560291` "박성희님 선물" / `18865870` "로블록스 마켓핏"). `description LIKE '%님%'` 패턴 + 직원 user_seq 매칭 쿼리로 확장 식별
- [ ] **카테고리 D 10명 — 2024-06-13 외부 시스템 이관 batch**: user_seq `58286xxx~58287xxx` 연속, description = `기존 하트 | 보너스 하트`, 사용 0. `event_date='2024-06-13' AND log_type='chargeByAdmin'` 으로 batch 전체 user_seq 범위 식별 후 마킹 정책 결정 (`is_migrated_user` 컬럼 신설 vs `user_test_group` 일괄 추가)
- [ ] **카테고리 E 18명 — 2021-01~ 초기 "기존 하트" 단독**: description 단서 부족. `created_at < '2022-12-31' AND description = '기존 하트' AND log_type='chargeByAdmin'` 범위로 batch 식별. 베타·이전 시스템 이관 잔액 가설을 BQ 로 검증 (당시 가입 패턴·서비스 출시일 등)
- [ ] **모니터링 쿼리 정기화** — admin-dominant + description 키워드 신규 매칭을 주기적 탐지하는 SQL 작성 (운영진 신규 가입·QA 신규 충전 등 대응)

### 구현 단계 — R2

- [ ] SQL: `scripts/hellobot/report/report_avg_heart_balance_daily.sql` (R1 마트 → 일자별 평균·분위수 집계)
- [ ] queries.py 또는 pre_report_func.py 에 함수 추가
- [ ] DAG: `hellobot_datamart_pre_report_pipeline.py` 또는 `report_pipeline.py` 에 task 추가
- [ ] 백필: R1 백필 완료 후 R1 → R2 일괄 계산
- [ ] 1주 모니터링 (R1 모니터링과 병행)

### 후속 (별도 과업)

- [ ] `hellobot_user_transformed_table_func.py` 의 `analytics_164027297.server_rdb_*` → `server_rdb.*` 마이그레이션 ([ISS-017](../../common-data-airflow/docs/hellobot-data/catalog/issues.md))
- [ ] 옛 위치 (`analytics_164027297.server_rdb_*`) 의 적재 출처 식별 + 사용 중단 ([external-tasks B-1](../../common-data-airflow/docs/hellobot-data/catalog/external-tasks.md))
- [ ] Looker 대시보드 작성 (별도 작업, 본 마트 완성 후)

## 출처 (검증 일자·쿼리·스캔)

| 항목 | 출처 |
|---|---|
| `server_rdb.heart_log` 14 컬럼 / 76.3M / 17.1 GB | `bq show --schema` 2026-05-13 |
| `server_rdb.heart_log_detail` 5 컬럼 / 87.4M / 5.49 GB | 동일 |
| self-ref 분포 80/20 | `bq query` 2026-05-13, 1.4 GB 스캔 |
| 1일치 풀 recompute 10.16 GB | `bq dry-run` 2026-05-13 |
| 옛 위치 stale 확인 | `bq show` 비교 2026-05-13 |
