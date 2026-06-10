# S3 — 랭킹 정의

> 스텝: S3 (랭킹 정의) · 작성: 2026-06-04 · 상태: **완료** (2026-06-04, 일부 기획자 확인 항목 잔존)
> 상위: [execution-steps.md](execution-steps.md) · 선행: [s2-concept-model.md](s2-concept-model.md)
> 조사: BQ 라이브는 인증 만료로 미수행 — 카탈로그(`common-data-airflow/docs/hellobot-data/catalog/`) + 실제 mart SQL 기준 판정
>
> ⚠️ **2026-06-06 갱신 주의** — 본 문서는 derivation 기록. 이후 **신규부스트 소스가 서버 등록일→출시일 `open_date`(`mart_skill_open_date_se.event_date`)로 반전**(C-2/CL-25), 평점 `line216` 인용은 오류로 폐기(CL-06, `1−💩비율` 재정의). 현행 계약은 [requirements.md](../requirements.md)(FR-R3/R5/R8)·[data-measurement-plan.md](../data-measurement-plan.md) 참조.

---

## 한 줄

랭킹은 **랭커 2종**으로 정의: **A(`AsIsRanker`) = 서버에 입력된 순서 그대로**, **B(`PopularityScoreRanker v1`) = 기획 스코어 공식**. B의 6개 시그널 중 5개는 BQ에 스킬(menu_seq)·일별로 가용하나 **평점만 별점이 아닌 이모지 이진** → 재정의 필요. 배치는 **계산=common-data-airflow(BQ 마트) / 적재=서버 위임(기존 컨벤션)** 방향이 기존 패턴과 일관.

## A (AsIs 랭커) 정의 — 확정

**"현재 그대로" = 스킬 목록을 서버에 입력되어 있는 순서대로 노출** (재정렬 없음).
- 태그 섹션: 운영자 수동 큐레이션 등록 순서.
- recentPurchasedSkills: 현행 동작(구매 반자동 + pinned 상위 고정) 그대로.
- 즉 A = "정렬 전략 미적용, 기존 서버 순서 유지".

## B (PopularityScore v1) — 시그널 가용성

스코어 공식: `구매수×0.35 + 조회수×0.1 + 전환율×0.2 + 평점×0.15 + 매출×0.15 + 신규부스트×0.05` (각 0~1 정규화, 7일평균=7일합÷실데이터일수)

| 시그널 | BQ 원천 | 입도 | 판정 |
|--------|---------|------|------|
| 구매수 | `hlb_mart.mart_use_skill_se` (`pay_for_%`, `pay_under_750`) | menu_seq×일 | ✅ |
| 조회수 | `hlb_mart.mart_v2_skill_funnel_fb` (`open_skill_description`/`enter_skill`) | menu_seq×일 | ✅ (조회 정의 필요 → DF-S3-3) |
| 전환율 | 위 둘 조합 (구매÷조회) | menu_seq | ✅ (조회 정의 종속) |
| **평점** | `hlb_mart.mart_fixed_menu_evaluation_server` ← `server_rdb.fixed_menu_evaluation` | menu_seq×user | ⚠️ **별점 아님 — 이모지 이진(💩=1/else=5)** → DF-S3-1 |
| 매출 | `hlb_mart.mart_use_skill_se.revenue_krw` | menu_seq×일 | ✅ (외부채널 환산금 합산 캐비엇 ISS-017) |
| 신규부스트 | `mart_skill_open_date_se`(로그 첫등장) 또는 `mart_fixed_menu_server.menu_create_at_date`(서버 등록일) | menu_seq | ✅ (출시일 기준 택1 → DF-S3-4) |

> 재사용 가능한 reference 집계: `report_kpi_total_skill_weekly.sql` (스킬 단위 구매/조회/평점 주간 산식). 평점 이진 산식은 line 216.

## 스킬 식별자 매핑 — 정합 OK

BQ `menu_seq`(STRING) ↔ 서비스 DB `fixed_menu.seq`(INTEGER) = **동일 식별자**, `CAST` 정규화만 하면 JOIN/적재 정합. (coop-integration 프로젝트에서 검증된 컨벤션.) → 랭킹 결과(menu_seq+score+rank)를 서비스 DB rankings 테이블에 적재 시 키 문제 없음.

## 배치 아키텍처 방향 (상세는 S5)

| 역할 | 위치 | 근거 |
|------|------|------|
| BQ 집계 → popularity_score·rank 계산 | **common-data-airflow** 마트 (`hellobot_datamart_mart_pipeline.py`에 신규 마트 추가) | 스킬 마트·집계가 이미 여기. `update_mart_use_skill_se_table` 체인 자리 |
| 결과의 서비스 DB 적재 | **서버 위임**(MWAA cron이 서버 엔드포인트 트리거) 또는 MWAA 직결 | 기존 컨벤션: `update_collection_ranking`(서버 PATCH), `refresh_recent_purchased_skills`(서버가 계산·Redis 적재, MWAA는 트리거) |

- **인기스킬(recentPurchasedSkills) 현행 = 서버 소유**. MWAA `refresh_recent_purchased_skills.py`(매분)는 서버 엔드포인트 트리거만. → 신규 랭킹도 "서버 계산·적재 + MWAA 트리거"가 가장 일관.
- **reverse-ETL(BQ→서비스 PG) 기존 경로 없음** → 신규 구축 필요. 빌딩블록(MWAA `db.py` 직결 / 서버 엔드포인트)은 존재.
- ⚠️ **타이밍 제약**: common-data-airflow 마트 체인은 KST 11시 산출 → 기획 "새벽4시"와 불일치 (DF-S3-5).

## 문서 이슈 정리 (기획자 확인 필요)

- **이슈-α 가중치 불일치**: Solution Design 공식은 6항목(0.35/0.1/0.2/0.15/0.15/0.05=1.0), 튜닝가이드는 5항목(0.4/0.1/0.2/0.15/0.15=1.0, 신규부스트 없음).
  - 분석: 튜닝가이드의 구매 0.4 = 6항목 공식의 구매 0.35 + 신규부스트 0.05 을 분리하기 전 값으로 보임. **6항목 공식(Solution Design)이 더 상세·최신 → canonical 채택 제안.** 튜닝가이드 5튜플은 stale.
- **이슈-β Phase A 누락**: 문서 "Phase A: 모든 스킬을" 에서 본문 잘림. Phase B(쿼리·테이블·API·UI)/C(부스트·대시보드·튜닝)는 정의됨. Phase A 의도 불명(Phase 0 파이프라인 구축? 전체 스킬 대상 정의?) → 기획자 확인.

## 결정 요소 (S3) — 결과

| ID | 결정 | 결과 |
|----|------|------|
| **DF-S3-1** ★ | 평점 시그널 처리 (별점 부재) | ✅ **긍정평가 비율(비-💩 비율)로 재정의** → 0~1 평점 대용, 가중치 0.15 유지. BQ 즉시 산출 |
| **DF-S3-2** | 가중치 확정 (이슈-α) | 🔶 **6항목 공식 채택**(0.35/0.1/0.2/0.15/0.15/0.05) — **기획자 확인 대기** |
| **DF-S3-3** | 조회 이벤트 정의 (전환율 분모) | 🔶 기본값 `open_skill_description`(상세 진입) — **KPI/기획자 확인 대기** |
| **DF-S3-4** | 신규부스트 출시일 기준 | ✅ 서버 등록일(`menu_create_at_date`) |
| **DF-S3-5** | 배치 타이밍 | ✅ D+1 오전(기존 체인 활용) — 일배치라 영향 작음 |
| **DF-S3-6** | Phase A 정의 (이슈-β) | 🔶 **기획자 확인 대기** |
| (S5로) | 적재 주체 (서버 위임 vs MWAA 직결) | S5 아키텍처에서 확정 |

## S3 결론 — 확정 공식 (B 랭커 v1)

```
popularity_score =
    7일평균구매수      × 0.35
  + 7일평균조회수      × 0.1
  + 전환율(구매/조회)  × 0.2
  + 긍정평가비율       × 0.15   ← 별점 대신 비-💩 비율 (재정의)
  + 7일평균매출        × 0.15
  + 신규부스트         × 0.05   ← 출시(서버 등록일) 30일 이내 가산
```
- 각 항목 0~1 정규화 후 가중합. 7일평균 = 최근7일 합 ÷ 실데이터 일수.
- A 랭커 = 서버 입력 순서 그대로(재정렬 없음).
- 데이터 실현성 ✅ (5시그널 BQ 가용 + 평점 재정의로 6번째 해소). 키 정합 ✅.
- 잔존 기획자 확인: 가중치 6항목 확정(α), 조회 분모 정의, Phase A 정의(β). → S4·S6 진행과 병행 가능(블로커 아님).

## 불확실 · 추가 조사 (후속)

1. **평점** — BQ만으론 별점형 산출 불가. 서버 DB 별점 데이터 유무 = 서버팀 확인 필요(DF-S3-1 종속).
2. BQ 라이브 미확인(`gcloud auth` 만료) — 컬럼 실재·freshness·`mart_fixed_menu_evaluation_server` 스키마 인증 복구 후 재확인.
3. MWAA→K8s CronJob 마이그레이션 완료 시점 미확인 — 배치 위치 mwaa 선택 시 충돌 가능.
4. rankings 서비스 DB 테이블 신설 스키마·적재 주체 (S5).
