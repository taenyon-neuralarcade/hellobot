# 진행 상태

## 파트별 현황

| 파트 | 상태 | 비고 |
|---|---|---|
| 데이터 | **R1 운영 안정 (모니터링 완료 2026-06-12)** / R2 구현 대기 | PR #185 머지 (2026-05-20) → 일배치 운영 진입 (2026-05-21) → 1주+ 모니터링 완료 — 사용자 확인 (2026-06-12): BQ 파이프라인 정상 동작. 이상치 후속 처리는 [TODO-046](../../todos/TODO-046-heart-balance-outlier-cleanup.md) 으로 분리 |
| 서버 | 해당 없음 | 잔액 산출은 BQ 측 (server-side 변경 불필요) |
| 클라이언트 | 해당 없음 | 대시보드 소비만 |

## 결정 로그

| 날짜 | 결정 | 이유 |
|---|---|---|
| 2026-05-13 | 원천 SSOT = `server_rdb.heart_log[_detail]` 확정. `analytics_164027297.server_rdb_heart_log[_detail]` 사용 금지 | BQ 실측 결과 옛 위치는 컬럼 6종 누락 + 1일 stale ([ISS-017](../../common-data-airflow/docs/hellobot-data/catalog/issues.md)) |
| 2026-05-13 | 백필 전략 = 1안 풀 recompute | dry-run 10.16 GB / $0.05 — 매우 저렴, 정합성 ★★★ |
| 2026-05-13 | 환불·만료 처리 = D 시점 기준 자연 반영 (정책 별도 컬럼 없음) | 서버 `getUsableHeart` 와 의미 동등 |
| 2026-05-13 | SQL alias 컨벤션: `det` / `chg` / `target_d` | DECLARE 변수와 case-insensitive 충돌 회피 |
| 2026-05-15 | 스코프 확정 = R1(사용자별 일자별 잔고·증감) + R2(전체 평균 잔고 추이) | Customer Job 두 가지(소진율·평균 잔고)에 직접 대응 |
| 2026-05-15 | **제외**: 하트 사용 취소 이벤트 추적 | 측정 대상 아님. 환불·만료는 R1 잔고 산식에 자연 반영되므로 별도 이벤트 불요 |
| 2026-05-15 | **제외**: Hackle·GA 이벤트 발화·연동 | 본 프로젝트는 BQ 마트 산출만 다룸. 클라/서버 SDK 발화는 별도 검토 대상 |
| 2026-05-15 | R2 구현체 = `hlb_report.report_avg_heart_balance_daily` (별도 마트) | R1 마트를 dim 으로 집계. report 레이어 적합 — DAG 체인상 pre_report_pipeline 후속 |
| 2026-05-15 | R1 구현 완료 — worktree + SQL + queries.py + mart_func.py + DAG + 카탈로그 | dry-run: balance 11.3 GB, flow 5.1 GB. 모두 BQ 컬럼 스캔 1회로 1일·1년 동일 비용 |
| 2026-05-15 | sparse row 정책 = balance > 0 또는 활동 있는 (D, user, kind) 만 row | 76M charges × 365d 인플레이션 회피. 분석 시 모집단 LEFT JOIN 으로 0 보강 |
| 2026-05-15 | CREATE TABLE IF NOT EXISTS 를 queries.py 에 포함 (idempotent) | 별도 DDL 스크립트 불필요. DAG 첫 실행 시 테이블 자동 생성, 이후엔 no-op |
| 2026-05-20 | 백필 범위 = 전체 history (2021-01-21 ~ 2026-05-19) | 비용 동일 ($0.08), 분석 유연성 ↑. 향후 코호트·YoY 분석 가능. balance 917M, flow 63M rows |
| 2026-05-21 | 일배치 자동화 운영 모드 진입 — 옵션 A (`hellobot_datamart_mart_pipeline` 전체 수동 트리거) 로 첫 사이클 검증 | Airflow develop sync 후 14:27 KST 완료. 5/20·5/21 파티션 신규 적재 (balance +1.35M / flow +10.8K), avg balance 214.6~214.8. D-2~D 부분 갱신 동작 정상. 5/22~ 11 KST 자동 흡수 |
| 2026-05-21 | High-balance outlier 정리 방안 = 기존 데이터파이프라인 규칙(`user_test_group` 필터) 재사용 | `staging_key_events_*` / `pay_for_contents_*` / `mart_user_heart_*` 등 헬로우봇 모든 마트가 `server_rdb.user_test_group` 을 표준 필터로 사용 중 — 신규 컬럼 없이 추가만으로 자동 제외. 카탈로그 ISS 등록은 보류 |
| 2026-05-21 | balance ≥ 1000 outlier 5개 카테고리(A·B·C·D·E) 분류 후 처리 우선순위 결정 | A(입력실수 2명) + B(명백한 테스터·QA 24명) = 즉시 `user_test_group` 추가 (INSERT SQL 작성). A 잔여 하트는 운영팀 회수 요청. C·D·E (32명, 직원·이관 batch·초기) 는 데이터로 batch 식별·검증하는 후속 과업으로 |
| 2026-06-12 | R1 모니터링 종료 + 이상치 후속을 [TODO-046](../../todos/TODO-046-heart-balance-outlier-cleanup.md) 으로 분리 | 사용자 확인 — BQ 파이프라인 정상 동작. 이상치 정리(A·B INSERT, C·D·E 추적, 음수 잔액)는 프로젝트 본류(R2)와 분리해 백로그로 보존 — 나중에라도 수행 가능하게 |

## 갭·이슈

- [ISS-017](../../common-data-airflow/docs/hellobot-data/catalog/issues.md) — 옛 위치 stale + prior art 마이그레이션 (본 프로젝트 산출 후 별도 과업)
- [external-tasks B-1](../../common-data-airflow/docs/hellobot-data/catalog/external-tasks.md) — 옛 위치 적재 출처 식별
- R2 모집단·분포 컬럼 정의 미확정 → architecture.md 에 다음 액션으로 추가

## 다음 액션

1. **R2 구현** (`report_avg_heart_balance_daily` SQL/queries/DAG, 별도 PR) — 모집단·분포 컬럼 정의부터
2. Looker 대시보드 (별도 작업)

> ✅ 1주 모니터링 완료 (2026-06-12 사용자 확인 — BQ 파이프라인 정상 동작)
> ↗ 이상치 후속 (A·B 26명 `user_test_group` 추가 / C·D·E 추적 / 음수 잔액 조사 / 모니터링 쿼리 정기화) → [TODO-046](../../todos/TODO-046-heart-balance-outlier-cleanup.md) 백로그로 분리
