# 개발 상태

> 상위: [readme.md](readme.md) · 추적: [TODO-012](../../todos/TODO-012-home-tab-phase2.md)

## 현재 상태: 구현 1차 완료 + 5렌즈 코드 리뷰 완료(06-11) — 머지 보류, 수정 라운드 필요

S1~S4 + 계약 문서 → 적대적 리뷰·메타리뷰 → 결정 라운드(14건) → 기획 피드백 반영(2026-06-06, C-1·C-2·D-1~D-7, **1차 5섹션 확정**) → 정합성 점검(2026-06-06) → **S5 윤곽 작성(2026-06-08, [planning/s5-architecture-outline.md](planning/s5-architecture-outline.md))**: 5레이어(계산·적재·랭커추상화·서빙·측정) 구분. **현행 재분석(2026-06-08, dev-server+dev-android, PR #1128)**: 통합 칩 컨테이너 `featuredSkillsTabs` **이미 LIVE**(서버05-21/앱 둘 다 05-26 머지) — CL-03 캡처 불요, 앱 무변경. **현행 구현 감사(2026-06-10, [planning/s5-asis-implementation-audit.md](planning/s5-asis-implementation-audit.md))**: 피쳐 문서(`hellobot-server/docs/features/20260511-home-rank-skill-section/` 8종)↔코드 전수 대조 **전 항목 일치** + ⭐seam 정밀화 — lazy 경로 limit+1 선컷 때문에 **B = `fetchSkillListBySectionType`(home.ts L540) 후보 fetch 교체**(재정렬 아님, 동일 shape 반환). **결정 라운드 2(2026-06-10, R-1~R-8 + 피드백 재개정)**: 실험 구조=**3군 L/C-M/C-A**(키18 게이트 + ②랭킹 신규 키 중첩) + CL-04·CL-08·D-7·랭킹 테이블 정책 확정 — 설계 블로킹 결정 0. **S5 세부 패스 완료(2026-06-10)**: [architecture.md](architecture.md)·[api-spec.md](api-spec.md) v1 — `home_skill_ranking`(K30)+적재 PUT+CronJob 12시 KST, percentile×전체풀·가용일수 분모, ②게이팅 5단+fetch 교체 어댑터+폴백, 신규 설계 결정 8건(§8). **서버·데이터 1차 구현 + PR 2건 생성(06-11)**. **5렌즈 병렬 코드 리뷰(06-11, [reviews/code-review-5lens-20260611.md](reviews/code-review-5lens-20260611.md))**: 블로커 2(ISS-001 어댑터 chatbotSeq 도메인 / ISS-002 computed_date 계약 충돌)+메이저 6 — [issues.md](issues.md) ISS-001~011 등록. 배포 안전 주장("전 플래그 off=무변화")은 전 렌즈 입증. **다음 = 결정 2건(ISS-002 방향·ISS-006 웹 visibility) → /dev-server·/dev-data 수정 라운드 → 머지(서버 먼저) → /dev-infra**. 리뷰·결정로그: [reviews/](reviews/).

## 파트별 현황

| 파트 | 상태 | 브랜치 | 워크트리 | 비고 |
|------|------|--------|---------|------|
| 기획 | 설계 완료 | - | - | S1~S5 완료(architecture·api-spec v1). 잔존: β 재확인·잔여 실험 결정·선행 운영 확인 |
| 서버 | **리뷰 수정 대기** | `feat/popular-chart-ranking` (푸시됨) | `worktrees/hellobot-server` | ✅ 06-11 `7dc5b7bd` 구현·**PR [#2444](https://github.com/thingsflow/hellobot-server/pull/2444)**. ⚠️ 리뷰(06-11): **ISS-001 블로커**+ISS-003·004·005(·006 정책 후) 수정 후 머지. 핵클 키 교체 잔여. 피쳐 문서 `docs/features/20260611-home-skill-ranking/` |
| 데이터 | **리뷰 수정 대기** | `Feat/popular-chart-ranking` (푸시됨 — 리포 Feat/ 컨벤션) | `worktrees/common-data-airflow` | ✅ 06-11 `e5ec4a3` 구현·**PR [#188](https://github.com/thingsflow/common-data-airflow/pull/188)** (dry-run·프리뷰 검증, 실측 해소). ⚠️ 리뷰(06-11): **ISS-002 결정**+ISS-007 dedup 수정 후 머지. 칩 복합키 바인딩 4곳 잔여 |
| 인프라 | 착수 가능 | `feat/popular-chart-ranking` | `worktrees/common-infra-eks-deploy` (06-11 생성, main a31302fea) | CronJob `load-home-skill-ranking` + BQ SA 시크릿 (architecture §1.3). PR 머지=배포 — 서버 적재 API 운영 배포 후 머지 |
| 웹 | 조건부 | - | - | 측정 이벤트 필요 시만 |
| iOS | 조건부 | - | - | 측정 이벤트 필요 시만 |
| Android | 조건부 | - | - | 측정 이벤트 필요 시만 |
| 스튜디오 | 해당없음 | - | - | |
| QA | 대기 | - | - | 설계 확정 후 케이스 작성 |

## 미결 / 후속 (기획 피드백 반영 후 2026-06-06)

- 🟢 **A/B 실험 구조 확정(2026-06-10, 피드백 재개정)** — **3군(L / C-M / C-A)**: ①기존(legacy) ②칩 UI+기존 수동 설정 ③칩 UI+랭킹 = [po-review §2.3](planning/ab-test-po-review.md) **권장안 채택**(같은 날 2군 결정 번복). 구현=**키18 게이트 유지·흡수 + 칩 수신군 내 ②랭킹 신규 키 중첩**(기본 L50/C-M25/C-A25, 최적화=분석 문서). 목표2(수동vs자동) 이번 실험 식별, 2단 롤백(②키 off→C-M / 키18 off→L), 키18 재선언 불요(흡수). [analysis](planning/ab-test-analysis-design.md): 3군 MDE 4.3%/4주·Holm 보정. **잔여 결정**: 1차 지표(유저 net) 승인·dmp 2건·무유의 정책·**목표2 비열등 마진·C-M 큐레이션 정책·셀 배분**·측정 이원화·기간(po §6 #3~#10 / analysis §14 #2~#10). 선행=키18 현 단계 확인.
- ✅ **S5 설계 위임 — 해소(06-10)** — CL-03(캡처 불요·fetch 교체)·CL-04·CL-08 전부 [architecture.md](architecture.md)·[api-spec.md](api-spec.md) v1에 반영 종결. 신규 설계 결정 8건은 architecture §8.
- 🟣 **실측 후속**(BQ 인증 + 운영 DB 덤프) — 섹션 태그 값 바인딩·시그널 SQL 대조·eval distinct 등 11항목(dmp §8). architecture 골격은 비블로킹(R5).
- 📋 **β Phase A** — 기획 원문 재확인만 대기(골격 불변).
- 🔵 **CL-02 측정 이벤트** = MUST 확정(노출+variant 신규), event-spec로 B 출시와 동시 배포.
- ✅ **배치 위치(D-7) — 확정(06-10)** — 컴퓨트=common-data-airflow / 적재=서버 PUT API / 트리거=K8s CronJob 12:00 KST + freshness guard ([architecture §1.3](architecture.md)).
- 🟣 **base 단위 바인딩**(D-5) — base = 오리지널∧750원↑ **확정**, 750원을 BQ 마트 가격 필드 단위(원 vs 하트)로 환산만 /dev-data.
- 📋 **커플/솔로 등 7섹션 = 최종단계**(적합 태깅 부재).

## 확정 사항

| 항목 | 내용 |
|------|------|
| 개념 모델 | 섹션 = 필터(후보 풀) + 랭커(교체 전략) |
| 랭커 | 2종 — A(AsIs=현행 산출 전체·C-1), B(PopularityScore v1) |
| 필터 모델 | 기본 풀 조건(오리지널∧750↑ 확정) ∧ 메타축(content_type/intents), **1차 5섹션**(실시간·신규·사주·타로·재회) |
| 태그 소스 | 하이브리드 — 1차 임시 태그 그대로, 정식 승격 후속 (DF-S4-1) |
| A/B (06-10✅ 재개정) | **3군(L / C-M / C-A)** — ①기존 ②칩+수동 ③칩+랭킹. **키18 게이트 유지 + ②랭킹 신규 키 중첩**(칩 수신군 내 C-M↔C-A, 기본 L50/C-M25/C-A25), 유저 버킷·일괄 유지. 목표2(수동vs자동) 이번 실험 식별. 2단 롤백(②키→C-M / 키18→L) |
| **섹션 매핑** (CL-01✅) | N:1 복합키 `(targetSection, targetSectionTag)`, 신규타입 불요 |
| **노출 슬롯 N** (CL-05✅) | vertical 7 / horizontal 8 (layout 구동) |
| **A 랭커 정의** (C-1) | 현행 live = `featuredSkillsTabs`(LIVE)의 `fetchSkillListBySectionType` 순서(태그=priority/recent=recency). B는 별도 base∧섹션 풀을 점수순 — A와 후보풀 비공유 유지 |
| **현행 컨테이너** (2026-06-08✅·감사 06-10) | `featuredSkillsTabs` 칩 컨테이너 **이미 LIVE**(피쳐 문서↔코드 전수 일치 확인). ①컨테이너 A/B=Hackle키18(legacy↔featured — **3군의 게이트로 흡수**) / ②랭킹 A/B=**신규 키 중첩**(06-10 3군 재개정). B 주입=`fetchSkillListBySectionType` **후보 fetch 교체**(동일 shape), **앱 계약 무변경** |
| **S5 설계 결정** (06-10✅) | CL-04 norm=**percentile×전체 base 풀**(1차 — 최종단계 데이터 검증·알고리즘 보완 별도 태스크) · CL-08=**가용일수 일평균**(÷min(7,경과일))+30일 부스트(당일 피크=자연 부스트 수용) · D-7=**컴퓨트 airflow / 적재 서버 write / K8s CronJob** · 랭킹 테이블=**PG 최신만+트랜잭션 교체**·배치 시 미노출 제외·over-fetch ×2·빈 랭킹=AsIs 폴백+마킹·알람 |
| **신규 기준** (C-2) | 출시일 `open_date`(`mart_skill_open_date_se.event_date`) — 섹션 ≤6개월(가변)·부스트 30일 |
| **기본 풀 조건(base)** | **오리지널 ∧ 750원↑** 확정. 단위 바인딩(원 vs 하트)만 /dev-data(D-5) |
| **1차 섹션 범위** | 5섹션(실시간·신규·사주·타로·재회), 커플/솔로 등 7섹션 최종단계 |
| **S5 세부 설계** (06-10✅) | [architecture.md](architecture.md)·[api-spec.md](api-spec.md) v1 — `home_skill_ranking`(rankerId seam·K30·최신만), 적재 `PUT /api/home/skill-rankings`(@Airflow·섹션 그룹별 tx 교체·0건 skip), CronJob 12:00 KST+freshness guard, ②게이팅 5단(KR→대상 칩→flag 2종→Hackle), fetch 교체 어댑터(pinned 보존)·AsIs 폴백. 신규 결정 8건 = architecture §8 |

## 잠정 방향 (S5/구현 전 확정 — 확정 아님)

| 항목 | 잠정 | 확정 시점 |
|------|------|----------|
| 실험 잔여 결정 | 1차 지표(유저 net)·dmp 2건·무유의 정책·목표2 비열등 마진·C-M 큐레이션 정책·셀 배분·측정 이원화·기간(4주 제안) | 실험 설계 확정([po §6](planning/ab-test-po-review.md)·[analysis §14](planning/ab-test-analysis-design.md)) |

> norm(CL-04)·콜드스타트(CL-08)·배치 토폴로지(D-7)·적재 주체 + **배치 타이밍(12:00 KST)·필터 운영 형식(마트 내 바인딩 블록, DF-S4-3)**은 **2026-06-10 확정** → 확정 사항 표·architecture.md로 이동.
