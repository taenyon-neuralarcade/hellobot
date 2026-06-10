# 데이터 측정 계획 (Data Measurement Plan) — 인기스킬 섹션 노출 자동화

> 작성: 2026-06-05 (코디네이터, /dev-data 검증 전 1차) · 상태: **v3 (기획 피드백 반영, 라이브 실측 대기)**
> 역할: 본 프로젝트의 **데이터 측정 SSOT** — 랭킹 스코어·시그널·KPI·적절성 지표
> 상위: [readme.md](readme.md) · [requirements.md](requirements.md) · 도출: [s3 랭킹](planning/s3-ranking-definition.md) · [s4 필터](planning/s4-filtering-tagging.md)
> ⚠️ BQ 라이브 인증 만료로 컬럼 실재·freshness·distinct 값은 **미검증** — §8 실측 항목은 /dev-data 인증 복구 후 확정

## 0. 문서 관계

| 문서 | 역할 |
|------|------|
| 본 문서 | 무엇을 측정·계산할지 (랭킹 스코어·시그널·KPI·적절성 지표) |
| event-spec.md | (필요 시) 신규 이벤트 발화 스펙 — 섹션 노출·클릭에 ranker variant가 필요하면 도입 |
| architecture.md | (S5) 배치·적재 파이프라인 기술 설계 |

## 1. 측정 목표

- **랭킹 산출**: 스킬별 일배치 `popularity_score` + rank 계산 → 섹션별 정렬 목록.
- **효과 측정**: 자동화(B) vs 현행(A) 의 Input/Output KPI 비교(A/B는 후속 단계).
- **적절성 검증**: "현재 태깅한 필터링이 적절한가"를 사전·사후 지표로 판정.
- 범위: **1차 5개 섹션**(실시간·신규·사주·타로·재회). **KR 전용**(jp 미적용·CL-11). 커플/솔로 등 7섹션 최종단계·개인화 제외.

## 2. 핵심 정의

| 용어 | 정의 | 비고 |
|------|------|------|
| 스킬 식별자 | `menu_seq`(BQ, STRING) ↔ `fixed_menu.seq`(서비스 DB, INT) | **SAFE_CAST** + 실패율 모니터 + 적재 전 PG 유효스킬 INNER JOIN (CL-22) |
| 7일 윈도우 | 최근 7일 합 ÷ 실데이터 일수(=7일 평균) | **실데이터 일수 정의·신규 스킬 분모 보정·소표본 평활 = CL-08 결정 종속** (현재 미확정) |
| 노출 슬롯(N) | **vertical 7 / horizontal 8** (`config.featuredSkillsTabs.limitByLayout`, 레이아웃 구동·전 섹션 공통, 서빙 시 cap) | ✅ 코드 확인(2026-06-05). T1 `슬롯×3`=**24** |
| 조회 | **`open_skill_description`(스킬 상세 진입) 확정** — 전 섹션 동일 적용 (CL-21 결정) | 전환율 분모 고정 |
| 긍정평가비율 | **1 − 💩비율** = `AVG(CASE WHEN eval_emoji='💩' THEN 0 ELSE 1 END)` (별점 부재로 재정의, 0~1) | ⚠️ **CL-06 교정**: 기존 인용 `…weekly.sql` line216은 1~5 평균(다른 식)이라 폐기. `eval_emoji` distinct 실측 필요 |
| 신규부스트 | **출시일 `open_date` 30일 이내** 가산(D-4) | 출시일 = `mart_skill_open_date_se.event_date`(D-6). 서버 등록일 기준 폐기(CL-25 반전) |
| 기본 풀 조건(base) | **오리지널 ∧ 유료 ≥750원**(✅ 확정) | 현행 지금인기는 minPrice 60(하트)·별도 임계. 750원→BQ 마트 가격 단위 바인딩(/dev-data·D-5) |
| 달력 | KST 기준 일배치 | 기존 마트 체인과 정합 |

## 3. KPI 인벤토리

| 구분 | KPI | 정의 | 정의 확정 필요(CL-26 / 넘겨짚지 않음) |
|------|-----|------|------|
| **Input** | 섹션 CTR | 섹션 노출 대비 클릭 | ⚠️ **노출(impression) 이벤트 부재**(CL-02 실측) → 신규 도입 전 CTR 산출 불가 |
| **Output** | 전환율 | 클릭 대비 구매 | 분모 조회 정의(CL-21) |
| **Output** | 신규 진입율 | 섹션 경유 신규 스킬 진입 비율 | **분자/분모 미정**: (A) 유저-신규(과거 N일 미진입) vs (B) 메타-신규(등록 30일 내) — **택1 결정** |
| **Output** | 구매 상품 수 | 섹션 경유 구매 상품 수 | **단위 미정**: 절대 카운트 vs 노출당/유저당 — **택1 결정** |
| **최종 판정** | **총 매출** | 섹션 경유 총 구매 매출(가드레일) | ⚠️ **전환율 우위라도 총 매출 열위면 불합격**. 저가 노출↑ 시 전환율↑·매출↓ 가능 |
| **A/B** | A/B Δ | 동일 섹션 A vs B 의 위 지표 차 | variant 차원 이벤트 필요(CL-02) |

> ⚠️ KPI 산식의 분자/분모·단위는 **본 문서(SSOT)에서 확정**해야 함 — "기획 문서 따름" 위임 금지(CL-26). 위 "정의 확정 필요" 항목은 결정 라운드 대상.

## 4. 데이터 소스 매핑 (랭킹 시그널)

> ⚠️ **판정 컬럼 강등(CL-19)**: 아래 ✅는 카탈로그 *table 문서* 기준이었으나 그 문서 5종이 **DEPRECATED(2026-04-22)** — 컬럼 실재는 **`dags/scripts/hellobot/mart/*.sql` 권위 SQL 대조 후** 확정. 따라서 🔶(SQL 대조 필요)로 강등.

| 시그널 | BQ 원천 | 입도 | 판정 |
|--------|---------|------|------|
| 구매수 | `hlb_mart.mart_use_skill_se` (`pay_for_%`, `pay_under_750`) | **이벤트 단위**(user×ts×menu_seq) — 일집계는 파이프라인 수행(CL-17) | 🔶 SQL 대조 |
| 조회수 | `hlb_mart.mart_v2_skill_funnel_fb` (`open_skill_description`/`enter_skill`) | menu_seq×일 | 🔶 (조회정의 CL-21) |
| 전환율 | 위 둘 조합 (구매÷조회) | menu_seq | 🔶 (조회정의 종속) |
| 긍정평가비율 | `hlb_mart.mart_fixed_menu_evaluation_server` ← `server_rdb.fixed_menu_evaluation` | menu_seq×user | 🔶 **CL-06**: `eval_emoji` distinct 실측·`1−💩비율` 식 적용 |
| 매출 | `hlb_mart.mart_use_skill_se.revenue_krw` | menu_seq | ✅ **CL-07 결정: 외부채널 포함 수용**(의도된 정책). revenue_krw 그대로 0.15 — 외부채널(카카오 쿠폰 등) 강세 스킬이 상위 점유 가능성 인지·수용 |
| 신규부스트 | **`hlb_mart.mart_skill_open_date_se.event_date`(출시일)** | menu_seq | 🟣 신규 — 커버리지(전 스킬 산출 여부)·grain 실측. 서버 등록일 폐기(CL-25 반전) |

> 재사용 reference: `report_kpi_total_skill_weekly.sql`. ⚠️ 단 line 216 평점 산식은 **1~5 평균**(0~1 비율 아님) — 긍정평가비율 식으로 직접 인용 불가(CL-06).

## 5. 랭킹 스코어 정의 (도메인 정책 — canonical)

```
popularity_score =
    norm(구매수_7일평균)      × 0.35
  + norm(조회수_7일평균)      × 0.1
  + norm(전환율)             × 0.2
  + norm(긍정평가비율)        × 0.15
  + norm(매출_7일평균)        × 0.15
  + 신규부스트(0|1)           × 0.05
```
- ⚠️ **`norm()` 미확정 = 점수 비결정(CL-04)**: min-max vs percentile, 모집단(전체 풀 vs 섹션 풀), 0/결측 처리가 미정 → **현 공식은 반제품**. 결정 라운드에서 (a)함수 (b)모집단 (c)결측처리 확정 전까지 "canonical"은 *골격*만.
- ⚠️ **긍정평가비율 norm 적용 여부 = CL-04에서 함께 결정** — 이미 0~1(1−💩비율)이라 norm 생략이 자연스러우나, 위 공식은 일괄 `norm()` 표기 → CL-04에서 예외 명시(공식↔§9 SQL 동기화 CL-25).
- ✅ **이슈-α(가중치) 확정(2026-06-05)**: 6항목(0.35/0.1/0.2/0.15/0.15/0.05=1.0) canonical. 튜닝가이드 5항목 폐기.
- 산출물 스키마(제안): **2테이블** — ① 전역 점수 마트 `(date, menu_seq, popularity_score, rank, signals_json)` ② 섹션별 적재 `(date, targetSection, targetSectionTag, menu_seq, rank, ranker_id)` (CL-01 복합키, NFR-1 사전계산 정합 / m8 분리).

## 6. 적절성 테스트 지표 (FR-V)

> ⚠️ 합격 기준은 전부 **잠정**(DF-S4-4·CL-15, 기획 합의 전) — 합의 책임자·기한 미정. 합의 전까지 수용기준의 판정 게이트로 쓰지 말 것.

| 테스트 | 지표 | 합격 기준(잠정) | 시점 / 의존 |
|--------|------|------------------|------|
| **T1 커버리지** | 섹션별 후보 스킬 수, 미태깅률 | 섹션당 후보 ≥ **24**(슬롯 8×3) · 미태깅률 ≤ 10% | 사전 (슬롯=8 확정) |
| **T2 정합** | 골든셋 대비 precision/recall, 섹션 간 중복도 | precision ≥ 0.8 (잠정) | **후속(1차 범위 밖, CL-15)** — 골든셋 부재 |
| **T3 태그품질** | temp topic × chatbot_content_type 교차 충돌율 | 충돌율 ≤ 15% (잠정) | **후속(1차 범위 밖, CL-15)** — 매핑표 부재 |
| **T4 행동정합** | 섹션→구매 전환율, 태그-선호 상관, A/B 섹션 CTR·구매 Δ | (사후 A/B 유의차) | 사전(로그)+사후(AB) — ⚠️ **CTR은 노출 이벤트 신규 필요(CL-02)** |

## 7. 태그 메타 소스 (1차 = 하이브리드)

| 메타축 | 원천 | 비고 |
|--------|------|------|
| topic / intents | `hellobot-f445c.google_sheet_sync.taenyon_temp_skill_tag_info_v2` | **임시 태깅** — 1차 그대로 사용, 정식 승격은 후속 |
| 카테고리(chatbot_content_type) | `hlb_mart.mart_fixed_menu_server` ← `chatbot`+`chatbot_category`+`chatbot_category_relation` join | 공식 카테고리 |
| 출시일(open_date) | `hellobot-f445c.hlb_mart.mart_skill_open_date_se.event_date` | 신규 판정(섹션 ≤6개월·부스트 30일) — 커버리지 실측(D-6) |
| 대상(targets) / temporal | 서비스 DB `FixedMenu.targets` (text[]) / temp 태그 | **1차 미사용**(태깅 부재·최종단계·D-1, CL-20) |

## 8. 측정 갭 · 보류 (/dev-data 실측 항목)

1. `taenyon_temp_skill_tag_info_v2` 스키마 + **distinct topic/intents/temporal 값** + 스킬 커버리지(태깅 스킬 수/전체).
2. `mart_fixed_menu_server.chatbot_content_type` **distinct 값** + 빈도.
3. **교차표**: temp topic × chatbot_content_type (T3 충돌율).
4. §3 섹션 가설 필터식별 **후보 스킬 수**(T1) + 섹션 간 중복(T2 예비).
5. `FixedMenu.targets` 값 분포(솔로/커플) — DF-S4-2.
6. BQ 컬럼 실재·freshness — **DEPRECATED 카탈로그가 아니라 `mart/*.sql` 권위 SQL 대조**(CL-19). `mart_use_skill_se` 그레인(이벤트 단위) 확인(CL-17).
7. 조회 정의(`open_skill_description` vs `enter_skill`) KPI 합의(CL-21).
8. **`eval_emoji` distinct 값** — 진짜 이진(💩 vs 단일 긍정)인지, `1−💩비율` 식 성립 확인(CL-06).
9. **매출 외부채널 분리 가능성** — `revenue_krw`에서 카카오 쿠폰 등 외부채널 환산금 제외 가능 필드 유무(CL-07).
10. **menu_seq SAFE_CAST 실패율** — 비숫자/NULL 행 비율(CL-22).
11. **운영 DB 덤프**(서비스 PG, BQ 무관): `HomeSectionFeaturedSkillsTab`·`TodayTagSkillsTag` row → 실제 등록 태그명(섹션 값 바인딩)·popular 섹션 운영현황(CL-01).
12. **출시일 `mart_skill_open_date_se` 커버리지·grain**(D-6) — `event_date`가 전 스킬 산출됐는지, menu_seq grain·중복 여부.
13. ✅ **현행 '지금 인기 스킬' 필터 조건**(D-5, 코드 확인 2026-06-06) — `recentPurchasedSkills`(`user-purchased-skill.ts`) = **오리지널(`chatbot.original_type='original'`) ∧ effective price ≥ minPrice(현행 60, 단위 하트 추정) ∧ 앱구매(os∈android/ios)**, pinned 선두·visibility 후필터, ORDER BY 최근구매. ✅ **base 결정 = 오리지널 ∧ 750원↑**(현행 60하트와 다른 임계) → 750원을 BQ 마트 가격 필드 단위로 바인딩(/dev-data). ※ **앱구매 한정**은 *구매수 신호*(웹 포함 여부)에도 영향 — /dev-data 확인.

## 9. 분석 쿼리 템플릿 (대표 — 실측 후 검증)

```sql
-- (개념) 의사 SQL — 실측 후 검증. mart_use_skill_se는 이벤트 그레인이므로 2단(일집계 → 7일평균).
-- 윈도우 = 최근 7일(D-6 ~ D-0, BETWEEN 8일 아님). norm()·eval norm 적용여부·실데이터일수 = CL-04/CL-08 미확정.
WITH daily AS (                                   -- 1단: 이벤트 → menu_seq×일 집계
  SELECT menu_seq, event_date,
         COUNT(*) AS purchase_cnt, SUM(revenue_krw) AS revenue_krw
  FROM `hlb_mart.mart_use_skill_se`
  WHERE event_date >= DATE_SUB(CURRENT_DATE('Asia/Seoul'), INTERVAL 6 DAY)   -- 7일
  GROUP BY menu_seq, event_date
),
agg AS (                                          -- 2단: 7일 윈도우 (합 ÷ 실데이터 일수=CL-08 확정 필요)
  SELECT menu_seq,
         SUM(purchase_cnt) / NULLIF(COUNT(DISTINCT event_date),0) AS buy7,
         SUM(revenue_krw)  / NULLIF(COUNT(DISTINCT event_date),0) AS rev7
  FROM daily GROUP BY menu_seq
)
-- + 조회(mart_v2_skill_funnel_fb) 일집계, 전환율, 긍정평가비율(1−💩비율), 신규부스트 JOIN
SELECT menu_seq,
       0.35*norm(buy7)+0.1*norm(view7)+0.2*norm(cvr)
       +0.15*pos_ratio+0.15*norm(rev7)+0.05*is_new AS popularity_score   -- pos_ratio norm 여부 = CL-04
FROM agg /* JOIN ... */;
```

```sql
-- (T1) 섹션 가설 필터별 후보 수 (예: 재회 = intents ∋ '재회')
SELECT COUNT(DISTINCT t.menu_seq) AS candidate_cnt
FROM `google_sheet_sync.taenyon_temp_skill_tag_info_v2` t
WHERE '재회' IN UNNEST(t.intents);
```

## 10. Changelog

| 날짜 | 버전 | 변경자 | 내용 |
|------|------|--------|------|
| 2026-06-05 | v1 | 코디네이터 | S3·S4 결정 종합 초안. 랭킹 스코어 6항목·시그널 소스·KPI·적절성 T1~T4·태그 소스(하이브리드)·실측 갭 7항목 |
| 2026-06-05 | v2 | 코디네이터 | **적대적 리뷰 교정**: 긍정평가비율 식 교정(line216 폐기, `1−💩비율`)·`mart_use_skill_se` 이벤트 그레인·§9 SQL 2단/7일·시그널 ✅→🔶(카탈로그 DEPRECATED)·매출 외부채널(CL-07 결정 종속)·노출슬롯 N=7/8 확정·KPI 산식 검토표기·norm 비결정 명시(CL-04)·산출물 2테이블(CL-01 복합키)·실측 항목 8~11 추가·T2/T3 골든셋·매핑표 의존·CTR 노출이벤트 부재(CL-02) |
| 2026-06-06 | v3 | 코디네이터 | **기획 피드백 반영**: 범위 12→1차 5섹션+최종단계 7·신규부스트 소스 `open_date`(`mart_skill_open_date_se.event_date`)로 교체·서버등록일 폐기(CL-25 반전)·신규 인기 섹션=open_date≤6개월·공통 base 필터(오리지널∧750↑) 추가·총 매출 가드레일 KPI·targets/temporal 1차 미사용·실측 12·13 추가·배치 위치 MWAA 파악 후 결정(D-7) |
