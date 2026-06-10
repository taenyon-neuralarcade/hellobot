---
id: TODO-042
title: MWAA(hellobot-mwaa) 현재 운영 작업 파악
유형: 액션
중요도: ⭐⭐
상태: 진행 중
등록: 2026-06-06
시작: "-"
완료: "-"
관련: TODO-012 (홈탭 Phase #2 배치 위치 D-7) · CLAUDE.md (MWAA→K8s CronJob 마이그레이션)
---

# TODO-042 — MWAA(hellobot-mwaa) 현재 운영 작업 파악

## 컨텍스트

- **직접 계기**: TODO-012(홈탭 Phase #2 인기차트 자동화)의 **배치 실행 위치 결정(D-7)**. 인기차트 일배치(BQ 마트 산출 + reverse-ETL 적재)를 **common-data-airflow**(우선 가정)에 둘지, **hellobot-mwaa**가 인프라 구조상 더 맞으면 거기에 둘지 결정해야 함.
  - 사용자 결정(2026-06-06): "FR-B1 배치는 우선은 airflow로 생각, mwaa가 인프라 구조적으로 더 맞으면 mwaa에 넣을 수 있음. **mwaa의 현재 하고 있는 것들 파악을 추가 TODO로**."
- **배경**: CLAUDE.md 상 `hellobot-mwaa`는 "Airflow DAG 리포 (K8s CronJob으로 마이그레이션 진행 중)". 즉 ① 현재 MWAA가 무엇을 돌리는지 ② K8s CronJob 마이그레이션이 어디까지 왔는지가 불명확 → 새 배치를 어디 얹을지 판단 근거 부족.
- **두 리포 구분**:
  - `common-data-airflow` (Python/Airflow/BigQuery) — 데이터 파이프라인(ETL), 수동 배포
  - `hellobot-mwaa` (Python/Airflow DAG, AWS MWAA) — DAG 리포, K8s CronJob 마이그레이션 중
- **관련 기존 컨벤션**(요구사항 FR-B3): `update_collection_ranking`=서버 PATCH, `refresh_recent_purchased_skills`=서버 계산+MWAA 트리거. → 인기차트 배치도 이 컨벤션과 일관성 검토 필요.

## 진행 로그

- **2026-06-06** 등록. TODO-012 기획 피드백 반영 중 D-7(배치 위치)이 "MWAA 현황 파악 후 결정"으로 정리되어 별도 TODO로 분리(사용자 지시).
- **2026-06-06** 조사 완료(병렬 Explore 2종, D-5와 동시). 위 핵심 발견 정리. 결론: 컴퓨트=common-data-airflow 유력 / 리버스-ETL=mwaa(psycopg2 보유) 또는 신규 K8s CronJob(마이그레이션 정합) — **최종 배치 토폴로지는 S5 결정**. TODO-012 D-7에 반영.

## 현재 상태

- **조사 완료(2026-06-06, 병렬 Explore)**. hellobot-mwaa(42 DAG)·common-data-airflow 인벤토리 + 역할 분담 + 리버스-ETL 갭 파악 완료. 배치 위치 *결정*은 S5(/architect).
- **핵심 발견**:
  - **hellobot-mwaa** = 서비스 운영 DAG(푸시·Braze sync·유저 라이프사이클·collection ranking·recent-purchased refresh·RDS↔BQ 백업). **psycopg2 서비스 RDS 커넥션(`dags/scripts/db.py`) + BQ 접근 동시 보유** → BQ읽기+PG쓰기가 공존하는 유일 위치.
  - **common-data-airflow** = BQ 분석 ETL(staging→intermediate→mart→report, hlb_dags/). **PG 커넥션·리버스-ETL 전무**(psycopg2 없음, connections/에 postgres 모듈 없음).
  - **리버스-ETL(BQ→서비스 PG) 기존 경로 없음** — 어디에 두든 신규 구축(CL-18 확인). 단 mwaa엔 서비스 PG 쓰기 선례(dormant_user·delete_users) 존재.
  - 기존 랭킹 컨벤션: `update_collection_ranking`(mwaa cron `0 15 * * *` → 서버 PATCH `/api/collection/rank`) · `refresh_recent_purchased_skills`(mwaa 매분 cron → 서버 POST refresh). **둘 다 mwaa=스케줄러 / 서버=계산** 패턴(문서 기술과 정합).
  - **K8s CronJob 마이그레이션 진행 중** — 서비스 운영 DAG들이 MWAA→K8s 이전 중(set-today-free-skill·snapshot-reserved-chatbots·DnD sync 등 커밋 확인). 신규 서비스성 배치는 K8s가 미래 정합적.

## 다음 단계

1. ✅ hellobot-mwaa DAG 인벤토리 / ✅ 역할 분담 / ✅ K8s 마이그레이션 현황 — **조사 완료**.
2. **배치 토폴로지 결정 → S5(/architect)**: 산출(BQ mart) = common-data-airflow 적합 / **리버스-ETL(BQ→PG) = hellobot-mwaa(psycopg2·서비스성 선례) vs 신규 K8s CronJob(마이그레이션 정합)** 중 택. 컴퓨트가 BQ라 "서버계산+스케줄러" 컨벤션은 부분 적용.
3. (S5 위험) reverse-ETL은 신규 인프라 — 멱등·폴백·정합검증을 1급 위험으로(CL-18).
