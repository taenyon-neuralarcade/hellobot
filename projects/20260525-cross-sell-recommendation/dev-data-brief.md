# /dev-data 위임 브리프 — Cross-Sell Recommendation 분석

> **이 문서는 `/dev-data` 에이전트의 작업 지시서입니다.**
> 착수 전 [`readme.md`](readme.md) · [`analysis-guide.md`](analysis-guide.md) · [`tasks.md`](tasks.md) 를 읽으세요.
> 데이터 인프라 진입: `common-data-airflow/docs/hellobot/catalog/infra-map.md` → 유형별 recipe/도메인 문서.

## 목표 (한 줄)

앱 1회 결제자가 두 번째 구매로 이어지지 않는 갭을 해부하고, **어떤 세그먼트에게 첫 결제 후 어떤 SKU 를 추천하면 재구매로 전환되는가**의 데이터 근거·가설을 도출.

## 분석 프레임

`Segmentation → Profiling → Next-Best-Offer`. 상세 방법론은 [`analysis-guide.md`](analysis-guide.md).

## 픽스된 정의 (반드시 준수)

| 항목 | 정의 |
|---|---|
| **첫구매 채널 분리** | **최상위 분리축**. `user_first_paid_date` (통합 첫구매일) vs `user_first_app_paid_date` (앱 첫구매일) 비교로 3그룹: **A 앱퍼스트** (두 날짜 동일) = **메인** / **B 웹→앱 이동자** (통합 < 앱) = **격리 분석** / **C 웹온리** (앱구매 없음) = **후속 트랙·본 분석 제외**. 채널 통합 집계 금지 |
| **분석 채널 (2회차·추천)** | **APP 한정** (두 번째 구매·추천은 인앱). 첫구매 채널만 A/B/C 로 분리 |
| **t=0 (첫 결제)** | **`user_first_app_paid_date`** (앱 첫 구매일) 기준. `user_first_paid_date` 는 채널 그룹 판별용. 분석기간 내 첫 결제를 재계산하지 말 것 |
| **재구매율 윈도우** | 첫 결제 후 **30 / 60 / 90 일** 병행 |
| **신규 vs 기존 결제자** | `user_first_app_paid_date` 가 분석 윈도우 내 = **신규**, 이전 = **기존**. **분리 측정** (합산 금지). 컷 경계는 Phase 1 분포 보고 확정 |
| **2회차 — 전체 SKU** | 카테고리 무관 전체 SKU 를 두 번째 구매로 간주 |
| **2회차 — 타이밍 2분기** | **동일일 2회차** (첫 결제와 같은 날 추가) vs **재방문 2회차** (익일 +1d 이후 재방문 구매). **각각 별도 산출**. (현행 운영은 일단위 구분) |
| **세그먼트** | 라벨을 기계적으로 붙이지 말 것. **후보 축(연령 5세·성별·첫 결제 토픽·가격대·페르소나)을 데이터로 검증 → 의미있는 축만 채택**. S1~S6 룰·기존 분포는 후보·비교 기준선으로만 |

## 즉시 착수 — Phase 1 (채널 크기 확인 → 코호트 → Baseline)

[`tasks.md`](tasks.md) Phase 1 체크리스트 수행:

0. **🔵 최우선 — 채널 3그룹 크기** — `user_first_paid_date` vs `user_first_app_paid_date` 비교로 A/B/C 인원수 + 매출 비중. **이 결과를 먼저 보고** → 스코프(A 집중·B 비중) 확정 후 1~7 진행
1. **코호트 SQL** — 채널 A(메인)·B(격리) 각각. `user_first_app_paid_date` 기준. 신규/기존 분리. 사용자 수 확정 (C 는 제외)
2. **신규 vs 기존 컷 확정** — 분석기간 정의(e.g., 2025-06-01~2026-05-31) + 윈도우 경계
3. **Baseline 재구매율** — 채널 A/B × 30/60/90 일 × 신규/기존 × (동일일 / 재방문) 매트릭스
4. **두 번째 결제까지 시간 분포** — median, p25/p75, 히스토그램 (재방문 중심)
5. **동일일 2회차 비중** — 인세션 업셀 규모
6. **첫 결제 카테고리별 raw 재구매율** — 카테고리 단독 변별력 1차 확인
7. **데이터 품질** — 생년월일·성별·관심 토픽 채움률, 이상치 정책

→ Phase 1.0 (채널 크기) 결과를 **먼저 보고**하여 스코프 확정. 이후 1~7 → Phase 2(세그먼트 축 검증) 진행 여부·마감 재확정.

## 활용 데이터·자산

| 자산 | 위치/이름 |
|---|---|
| 핵심 마트 | `union_mart_user_key_actions` (`age_group_5yr` 컬럼 포함) |
| 결제 데이터 | 결제 마트 (`first_paid_date` 포함) — infra-map 에서 Purchase 도메인 확인 |
| 콘텐츠 이벤트 | 콘텐츠 진입·이용·결제 이벤트 — catalog 진입 후 식별 |
| S1~S6 라벨 룰 | `projects/20260324-coop-integration/planning/kakao_product_skills/05-inapp-segment-mapping.md` |
| 기존 세그먼트 분포 | 같은 폴더 `data/segment-top3.md`, `skills-by-segment-12m.csv` (비교 기준선) |
| 연령×토픽 EDA | `projects/20260513-age-group-5yr/eda-by-age-group-5yr-app.md` |

## 산출물 위치

| 종류 | 경로 |
|---|---|
| SQL·CSV | `projects/20260525-cross-sell-recommendation/data/` |
| 분석 요약 (Phase별) | `projects/20260525-cross-sell-recommendation/planning/` (baseline.md, segment-profile.md, …) |
| 진행 체크 | `tasks.md` 체크박스 + 의사결정·이슈 로그 |

## 주의

- BigQuery 권한: 사용자 보유 확인됨 (2026-05-30)
- 인원수 50명 미만 셀은 lift 가 커도 결정 근거로 쓰지 않음 (가이드 부록)
- 분석 = 가설 도출까지. 효과 검증은 Phase 5 A/B 설계안으로 (운영 검증은 후속)
- BQ 스캔 비용 — 큰 풀스캔 전 파티션·기간 필터 확인
