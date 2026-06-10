# S5 — 아키텍처 설계 (윤곽)

> 스텝: S5 (아키텍처 설계) · 작성: 2026-06-08 · 상태: **진행중 — 윤곽 단계** (세부 미착수)
> 상위: [execution-steps.md](execution-steps.md) · 선행: [s2](s2-concept-model.md) · [s3](s3-ranking-definition.md) · [s4](s4-filtering-tagging.md)
> 계약 문서(SSOT): [readme.md(PRD)](../readme.md) · [requirements.md](../requirements.md) · [data-measurement-plan.md](../data-measurement-plan.md) · [status.md](../status.md)
> 현행 분석(dev-server, 2026-06-08): [s5-asis-serving-analysis.md](s5-asis-serving-analysis.md) — 칩별 도출·서빙 경로 + CL-03 함의
>
> **이 문서의 위치** — 세부 설계(`architecture.md`·`api-spec.md`)로 바로 들어가기 전, **"어떤 부분을 어떻게 접근할지"의 윤곽**만 먼저 잡는다. 본 문서에서 영역·순서·핵심 갈림길을 합의한 뒤, `/architect`가 영역별 세부 스펙(스키마·시그니처·Changelog)을 채운다.

---

## 한 줄

설계 대상은 **5개 레이어**(①계산 ②적재 ③랭커추상화 ④서빙 ⑤측정)다. 이 중 ②~④를 가르는 **최상위 갈림길은 "A(현행)를 비교군으로 어떻게 둘 것인가"(CL-03)** 하나이며, 이것만 방향을 정하면 나머지는 권장 가설대로 세부 진행할 수 있다.

---

## 0. 한 장 스파인 (end-to-end)

```
[BQ 시그널 마트]              mart_use_skill_se / skill_funnel_fb
   구매·조회·전환·매출·평가     / fixed_menu_evaluation_server / skill_open_date_se
        │
        ▼  ── ① 계산 레이어 (common-data-airflow, BQ)
   base 필터(오리지널∧750↑) → 섹션별 후보풀(메타축) → 6시그널 정규화·가중합 → score → 섹션별 rank
        │
        ▼  ── ② 랭킹 산출물 + 리버스-ETL  (D-7: 컴퓨트=airflow / write=서버 소유 + 스케줄러)
   BQ 랭킹 마트  ───────────►  서비스 PG 랭킹 테이블  (복합키 적재)
        │
        ▼  ── ③ 서빙 (hellobot-server API)
   복합키(targetSection,targetSectionTag) 조회 → variant(A/B) 분기 → 슬롯 N 상위 → 홈탭
        │
        ▼  ── ④ 측정/판정
   노출·클릭·구매 이벤트(variant 태깅) → CTR·전환율·신규진입·구매수 → 총매출 가드레일
```

위 5개 박스가 설계 단위다. 세부는 박스별로 따로 파고든다.

---

## 1. 설계 영역 맵 — "어떤 부분을 어떻게"

| # | 영역 | 정해야 할 것 | 접근 방향(권장 가설) | 상태 |
|---|------|------------|---------------------|------|
| ① | **계산 레이어 (BQ)** | base+섹션 필터를 마트에 어떻게 인코딩 · 6시그널 산식 · `norm` 방식 · 신규 섹션 cold-start | common-data-airflow에 신규 랭킹 마트 1개. norm=전체풀 percentile(CL-04 권장). cold-start=신규 섹션 짧은 윈도우/부스트 보정(CL-08) | 가설→S5 확정 |
| ② | **랭킹 산출물 + 리버스-ETL** | 마트 row 형상 · BQ→PG 적재 토폴로지(D-7) · 복합키 | row=(menu_seq, section_key, variant, score, rank, computed_date). 컴퓨트=airflow / write=서버 소유 + 스케줄러(K8s CronJob) | 토폴로지 제안됨. **A 캡처 불요(현행 live), B=정렬 주입(§2)** |
| ③ | **랭커 추상화 + variant seam** | 랭커 인터페이스 시그니처 · 섹션→랭커 바인딩(showRanking→ranker_id) · variant 주입점 위치 | 인터페이스 1개(입력=후보풀+컨텍스트, 출력=정렬목록). 바인딩 데이터화. **주입점만** 분리(버킷팅 자체는 범위 밖) | S2 확정 골격 → 시그니처만 S5 |
| ④ | **서빙 API** | 복합키 조회 · variant 분기 · 슬롯 N(7/8) · 빈섹션 숨김·pinned 유지·중복 허용 | 기존 featuredSkillsTabs 경로 확장. 복합키로 PG 랭킹 조회 후 layout 슬롯 컷 | 규칙 확정(CL-01/05/10/13/14) → 엔드포인트 형상만 |
| ⑤ | **측정/판정** | 노출+variant 이벤트(CL-02) · KPI 산식(총매출 가드레일) | event-spec 신규(소급불가), B 출시와 동시 배포. 판정=전환율 우위 AND 매출 비열위 | MUST 확정 → event-spec 별도 |

---

## 2. ⭐ 핵심 — A 비교군은 "캡처" 문제가 아니다 (CL-03 정정)

> **2026-06-08 정정** — 현행 코드 분석([s5-asis-serving-analysis.md](s5-asis-serving-analysis.md))으로 초판의 (가/나/다) 스냅샷 갈림길은 **폐기**. 통합 칩 컨테이너 `featuredSkillsTabs`가 이미 LIVE이고, A는 매 요청 live 계산이라 캡처가 불필요함이 확인됨.

**현행(A) 구조** — `featuredSkillsTabs` 칩 컨테이너(LIVE)의 lazy 엔드포인트 `GET /api/home/featured-skills-tab/:tabSeq`가, 칩의 `(targetSection, targetSectionTag)`에 따라 **기존 섹션 추출을 그대로 호출**(`fetchSkillListBySectionType`, home.ts L540)해 순서를 만든다. 태그 칩=어드민 priority, recentPurchased 칩=recency. "1~N위"는 응답 순서에 입힌 **장식 뱃지**(서버 순위 필드 아님).

**B(인기점수) 주입 = 정렬 한 곳** — `fetchSkillListBySectionType` 직후(또는 하부 ORDER BY)에서 칩 후보 스킬을 **인기점수 랭킹 테이블 순서로 재정렬**만 하면 된다.

| 항목 | 결론 |
|---|---|
| A 캡처/스냅샷 | **불요** — A는 현행 live 경로 유지 |
| B 주입점 | `fetchSkillListBySectionType`(home.ts L540) 정렬 교체 (단일 seam) |
| 앱/계약 변경 | **불요** — 앱은 순서대로 받아 위치 뱃지만 부여 |
| A/B 성격 | "live AsIs 순서" vs "batch 인기점수 순서" |
| variant 신호 | featuredSkillsTabs **안에서** 정렬을 AsIs↔점수 토글 (①컨테이너 Hackle키18과 별개인 ②랭킹 축) |

→ CL-03은 "어떻게 캡처하나"가 아니라 **"②랭킹 variant를 어디서 주입·버킷팅하나"** 로 축소됨(세부는 ③ variant seam). 두 A/B 축(①컨테이너 LIVE / ②랭킹 미착수)은 분석 문서 §4 참조.

---

## 3. 접근 순서 (의존도)

```
B 정렬 seam(§2) ─┬─► ②테이블 형상 ──► ③랭커/주입점 ──► ④서빙 API
                 └─► ①계산(norm·cold-start) ─────────────┘
                                          ⑤측정(event-spec) — ④와 병행, B 출시와 동시
배치 토폴로지(D-7) ──► ② 적재 메커니즘 확정
```

- **먼저**: ② 산출물 형상(랭킹 테이블) + 토폴로지 확정 (구조 척추) — B는 `fetchSkillListBySectionType` 정렬 주입(§2)
- **그 다음**: ① 계산 세부(norm/cold-start) · ③ 랭커 시그니처 · ④ API 형상 (병렬 가능)
- **마지막/병행**: ⑤ event-spec (B 출시와 동시 배포라 별도 트랙)

---

## 4. 이번 설계에서 답 낼 결정점

| ID | 결정 | 권장 | 비고 |
|----|------|------|------|
| **CL-03** | A 비교군 산출 방식 | **캡처 불요 — A=현행 live**, B=정렬 주입(§2). ②랭킹 variant 주입점만 ③ | 정정 2026-06-08(featuredSkillsTabs LIVE) |
| **CL-04** | `norm` 방식·모집단 | 전체풀 percentile | 실측으로 검증 가능(비블로킹) |
| **CL-08** | 신규 섹션 cold-start | 짧은 윈도우 + 신규부스트 | 신규 인기 섹션 한정 |
| **DF-S4-1** | 태그 소스(임시 승격 vs 공식 흡수) | 1차=임시 태그 그대로, 정식 승격 후속(하이브리드) | 필터 레이어 운영 형식과 연동 |
| **D-7** | 배치 토폴로지 | 컴퓨트=airflow / write=서버+스케줄러(K8s) | 제안 확정만 |
| — | 복합키·랭킹 테이블 스키마 | (targetSection, targetSectionTag) | api-spec 동기 |

---

## 5. 경계 (이번 설계 in/out)

- **In**: 1차 5섹션(실시간·신규·사주·타로·재회) 파이프라인 골격, 랭커 2종 산출 구조, 복합키 적재·서빙, 측정 이벤트 정의
- **Out(확장 대비만)**: 다중 랭커 실운영, A/B 버킷팅 메커니즘, 커플/솔로 등 7섹션, targets·temporal 축
- **비블로킹 후속**: base 단위 바인딩(원 vs 하트, /dev-data), 실측 13항목

---

## 다음

B 정렬 주입 seam 확정(§2) → `/architect` 세부 패스로 진입, **②→①③④→⑤** 순서로 [architecture.md](../architecture.md)·[api-spec.md](../api-spec.md) 작성. ②랭킹 variant 주입점(③)·랭킹 테이블·base/open_date가 핵심. 세부 작성 시 본 윤곽의 영역 구분과 결정점(§4)을 그대로 이어받는다.
