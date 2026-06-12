# 요구사항 정의서 — 인기스킬 섹션 노출 자동화

> 작성: 2026-06-05 (코디네이터) · 갱신: 2026-06-12 (06-10 S5 + 06-11 리뷰 결정 확정 마커 동기) · 상태: **v3 (기획 피드백 + 현황조사 반영)** · 설계: [architecture.md](architecture.md) · [api-spec.md](api-spec.md)
> 상위: [readme.md](readme.md) · 측정: [data-measurement-plan.md](data-measurement-plan.md) · 리뷰: [reviews/00-meta-review-and-checklist.md](reviews/00-meta-review-and-checklist.md)
> 표기: **MUST**(필수) / **SHOULD**(권장) / **MAY**(선택) / **MUST(구조)**=구조는 필수이나 값/내용은 실측·결정 종속.
> ⚠️ **CL-23(가설↔확정 분리)**: 2026-06-06 결정으로 신규 기준(open_date≤6개월)·실시간 윈도우(공통7일)·1:1상담·targets(최종단계)·base(오리지널∧750원)는 **확정**. ✅ 잔여 실측 종속분도 **06-11 실측으로 해소** — base 단위(하트, 750원=5하트)·`eval_emoji` distinct(5종)·섹션 태그 값 바인딩([architecture §2.5](architecture.md)). 남은 바인딩 = **운영 칩 구성 확인 → 복합키 4곳**뿐. 나머지 FR은 확정 계약.

---

## A. 필터링 요구사항 (FR-F)

| ID | 요구사항 | 등급 | 근거 |
|----|----------|------|------|
| **FR-F0** | **기본 풀 조건(base)** = **오리지널(`original_type='original'`) ∧ 유료 ≥750원** (✅ 확정 2026-06-06). 전 섹션 공통 선결 필터. ⚠️ 현행 '지금 인기'는 minPrice 60(하트)이라 **별도 임계**. ✅ **D-5 단위 바인딩 해소(06-11 실측)**: `menu_price` 단위=하트, **750원=5하트**. | MUST | 기획 확정 |
| **FR-F1** | 섹션은 **기본 풀 조건(base) ∧ 메타축 조건식**으로 후보 스킬 풀을 결정해야 한다: `section_filter(skill) = base ∧ Π match(axis_i, values_i)` (축 간 AND, 한 축 내부 OR). | MUST | s4 §3 |
| **FR-F2** | 지원 메타축: **topic · intents(다중) · chatbot_content_type**(1차 사용) + **targets(솔로/커플) · temporal**(구조 보유, **1차 섹션 필터식 미사용** — 태그 부재·CL-20). | MUST | s4 §1 |
| **FR-F3** | **1차 5개 섹션**(실시간 인기·신규 인기·사주·타로·재회) 각각에 필터 규칙을 정의한다. 나머지 7섹션(커플 궁합·커플 결혼 궁합·솔로 애정운·솔로 결혼운·짝사랑/썸·재물운·1:1 상담)은 **적합 태깅 부재로 최종단계 보류**(D-1·D-3). | MUST | 기획 피드백 |
| **FR-F4** | 커플/솔로 **대상 섹션은 전부 최종단계 보류**(커플 궁합·커플 결혼 궁합·솔로 애정운·솔로 결혼운) — `intents`(궁합·결혼)가 있어도 **커플/솔로 대상 구분 태깅 부재**로 1차 제외(D-1, 사용자 2026-06-06). | 후속 | 기획 피드백 |
| **FR-F5** | 1차 태그 메타 원천은 **임시 태그 테이블**(`taenyon_temp_skill_tag_info_v2`)을 그대로 사용한다. 정식 메타 승격은 후속(하이브리드). | MUST | DF-S4-1 |
| **FR-F6** | 필터 규칙(섹션→조건식)은 **코드 변경 없이 조건 추가·수정 가능한 확장 구조**를 우선한다. 1차 저장 위치(코드 상수/설정/DB seed, API단 하드코딩 가능성 포함)는 S5 확정, 어드민 편집 UI는 후속(CL-16). ✅ **S5 확정(06-10)**: 1차=마트 내 선언적 바인딩 블록 + 운영 편집 승격 seam — [architecture.md §2.5](architecture.md). | SHOULD | DF-S4-3·기획 피드백 |
| **FR-F7** | 각 섹션 필터의 실제 태그 **값 바인딩**(예: '애정운'/'재회')은 /dev-data 실측(distinct 값)으로 확정한 뒤 적용한다. ✅ **확정(06-11 실측)**: 사주/타로=`chatbot_content_type`(temp topic에 값 부재)·재회=`intents ∋ '재회'`·신규=`open_date ≤ 6개월` — [architecture §2.5](architecture.md). 잔여 = 운영 칩 구성 확인 후 복합키 4곳. | MUST | s4 §6 |
| **FR-F8** | 섹션 간 **중복 노출 허용**(섹션 독립, 1차) — 한 스킬이 여러 섹션 조건에 맞으면 각 섹션에 노출(CL-13). 전역 dedup은 후속 검토. | MUST | CL-13 |

## B. 랭킹 요구사항 (FR-R)

| ID | 요구사항 | 등급 | 근거 |
|----|----------|------|------|
| **FR-R1** | 랭커는 **교체 가능한 전략(strategy)** 으로 추상화되어야 한다(입력=후보 풀+컨텍스트, 출력=정렬 목록). | MUST | s2 §확장성 |
| **FR-R2** | 랭커 **2종**: `AsIsRanker`(A) = **현행 서버의 섹션 목록 산출 방식 전체를 그대로**(어드민 설정·pinned·우선순위 변경 없음), `PopularityScoreRanker v1`(B) = 신규 필터+점수 공식. | MUST | s2/s3·C-1 |
| **FR-R3** | B 랭커 점수는 다음 가중합이어야 한다: 구매수0.35 + 조회수0.1 + 전환율0.2 + 긍정평가비율0.15 + 매출0.15 + 신규부스트0.05 (**6항목 확정** — α 결정 2026-06-05). 매출 = `revenue_krw` (외부채널 포함 수용 — CL-07). ✅ **norm 확정(06-10, CL-04)**: percentile-rank × 전체 base 풀(신규부스트 0/1만 norm 제외) — [architecture §2.3](architecture.md). | MUST | s3 결론 |
| **FR-R4** | 점수는 **7일 윈도우**(최근 7일 합 ÷ 실데이터 일수)로 산출하며 **일배치**로 갱신한다. **'실시간 인기' 섹션도 공통 7일 점수를 사용**(별도 단기 윈도우 없음, 명칭은 라벨 — CL-09). | MUST | s3 |
| **FR-R8** | **신규 인기 섹션 = 출시일 `open_date` ≤ 6개월**(N 기본 6개월, 결과 보고 가변·C-2). 출시일 소스 = `mart_skill_open_date_se.event_date`(D-6). ✅ **cold-start 확정(06-10, CL-08)**: 별도 장치 없음 — 가용일수 분모(÷min(7,경과일)) + 30일 부스트가 겸함 — [architecture §2.2·§2.4](architecture.md). | MUST(N 가변) | C-2/D-6 |
| **FR-R9** | A·B는 **동일 후보 풀이 아니다**(A=현행 산출 전체, B=신규 필터+랭커·C-1). A/B 비교는 *같은 풀의 정렬 차이*가 아니라 **섹션 단위 행동 KPI**(노출→클릭→구매→총 매출)로 한다. ~~A(AsIs) 산출·캡처 방식은 S5 위임(CL-03, 권장=배치 스냅샷)~~ ✅ **CL-03 해소(06-08 정정·06-10 확정)**: A=현행 live(캡처 불요), B=후보 fetch 교체 — [architecture.md §3](architecture.md). | MUST | C-1/CL-03 |
| **FR-R10** | B 랭커도 **pinned 상위 고정을 유지**한 뒤 나머지를 점수 정렬한다(현행 운영 기능 보존·회귀 방지, CL-14). | MUST | CL-14 |
| **FR-R5** | 긍정평가비율 = **`1 − 💩비율`** = `AVG(CASE WHEN eval_emoji='💩' THEN 0 ELSE 1 END)` (0~1, 별점 부재로 재정의). ⚠️ line216(1~5 평균) 폐기. ✅ `eval_emoji` distinct **실측 완료(06-11, 5종 — CL-06 해소)**. **신규부스트 = 출시일 `open_date` 30일 이내 가산**(D-4, 소스 `mart_skill_open_date_se.event_date`·서버 등록일 폐기 — 경계는 출시 1~30일차, architecture §2.2). | MUST | s3·D-4/D-6 |
| **FR-R6** | A 랭커는 **현행 서버 산출 방식 전체**(태그 섹션=수동 큐레이션, recentPurchasedSkills=구매 반자동+pinned)를 재정렬·재필터 없이 보존한다. B 후보 풀에 없는 스킬도 A엔 포함될 수 있다(C-1). | MUST | s3·C-1 |
| **FR-R7** | 향후 목적·콘텐츠 특성별 **다중 랭커 공존**을 비파괴로 허용하되, 다중 랭커의 실제 운영은 이번 범위 밖이다. | SHOULD | s2 범위 |

## C. A/B · Variant 요구사항 (FR-AB)

| ID | 요구사항 | 등급 | 근거 |
|----|----------|------|------|
| **FR-AB1** | 시스템은 A(현행 산출 전체)·B(신규 필터+랭커) **2종 목록을 산출**할 수 있어야 한다(동일 후보 풀 전제 아님·C-1). | MUST | s2·C-1 |
| **FR-AB2** | "어느 목록을 서빙할지"를 외부 신호로 주입받는 **variant 주입점**이 깔끔히 분리되어야 한다. | MUST | s2 |
| **FR-AB3** | A/B **적용 단위는 유저 버킷·일괄**(한 유저는 인기스킬 섹션 전체를 A or B로 통일). | MUST | DF-S2-1 |
| **FR-AB4** | ~~키18 종료 후 별도·순차~~ → ~~2군 통합~~ → **재개정(✅ 2026-06-10, 피드백)**: 실험 구조 = **3군(L / C-M / C-A)** — ①기존(L) ②칩 UI+기존 수동 설정(C-M) ③칩 UI+랭킹(C-A). 구현 = **키18 게이트 유지·흡수 + 칩 수신군 내부 ②랭킹 신규 키 중첩**(variant 주입점 FR-AB2 실구현 — C-A만 랭킹 fetch, 분배 자체는 Hackle 위임. 기본 배분 L50/C-M25/C-A25, 최적화·기간은 분석 문서). 2단 롤백: ②키 off→전원 C-M / 키18 off→전원 L. | MUST | DF-S2-2 재개정 · [po-review §2.3](planning/ab-test-po-review.md) 권장안 채택 |

## D. 배치 · 파이프라인 요구사항 (FR-B)

| ID | 요구사항 | 등급 | 근거 |
|----|----------|------|------|
| **FR-B1** | 스킬별 일배치 지표(구매·조회·전환·평가·매출·신규) + 점수·필터→랭크는 **BigQuery 마트**로 산출한다. 실행 위치 = **common-data-airflow**(소스 마트가 거기 존재·조사 확인, TODO-042). | MUST | s3·D-7 |
| **FR-B2** | 섹션별 `필터 → 랭킹` 결과(`섹션 → [정렬된 menu_seq, rank, score]`)를 산출해 **서비스 DB에 적재**해야 한다(reverse-ETL 신규 구축). | MUST | s4 §S5함의 |
| **FR-B3** | 리버스-ETL 적재 주체 **제안(TODO-042 조사 후)**: **서버 소유 write**(rankings 테이블·트랜잭션을 서버가 소유) + **스케줄러 트리거**(K8s CronJob 권장=마이그레이션 정합 / 단기 mwaa cron 가능) — 기존 `update_collection_ranking`·`refresh_recent_purchased_skills` 컨벤션과 일관. common-data-airflow 직접 PG write는 비권장(역할 경계·운영DB 위험·psycopg2 부재). ~~확정=S5~~ ✅ **확정(06-10 D-7)**: 제안 그대로 — [architecture.md §1.3](architecture.md). | SHOULD | s3·D-7 |
| **FR-B4** | 배치는 **D+1 일배치**로 동작한다(기존 마트 체인 KST 11시 산출과 정합; 기획 '새벽4시'와의 타이밍은 S5에서 조정). ✅ **타이밍 확정(06-10)**: 체인 후행 12:00 KST 적재 + freshness guard — [architecture.md §1.3](architecture.md). ✅ **guard 시맨틱(ISS-002 A안, 06-11)**: computed_date = 7일 윈도우 종료일(=실행일 전일) → guard는 "**어제** 행 존재" 검사 (서빙일 D의 랭킹 = computed_date D-1). | MUST | s3 DF-S3-5 |
| **FR-B5** | menu_seq(STRING) ↔ fixed_menu.seq(INT) 키 정합은 **`SAFE_CAST`** 로 보장하고, 캐스팅 실패율을 모니터(NFR-5)하며 적재 전 PG 유효스킬과 INNER JOIN한다(CL-22). | MUST | s3 §키매핑 |

## E. API · 서빙 요구사항 (FR-API)

| ID | 요구사항 | 등급 | 근거 |
|----|----------|------|------|
| **FR-API1** | 자동화 결과는 기존 `featuredSkillsTabs` 노출 컨테이너(PR #2414)와 결합해 서빙되어야 한다(신규 그릇 신설 금지). | MUST | s1 |
| **FR-API2** | 칩의 `showRanking`(bool)은 "랭킹 on/off"만 표현 — variant(A/B)는 칩 속성이 아니라 **요청 컨텍스트(유저 버킷)**에서 와야 한다(CL-12). `ranker_id` 일반화 여부는 S5 판단(2종이면 bool 유지 + 확장 seam만). | SHOULD | s1/s2 |
| **FR-API3** | API는 variant(A/B)에 따라 2종 목록을 **경우에 따라 다르게 서빙**할 수 있어야 한다(주입점 경유). 주입 기본값 = **A(현행)**, B는 명시 주입 시(자연 롤백·킬스위치 겸함, CL-12/GAP-12). | MUST | s2 |
| **FR-API4** | 클라이언트(iOS/Android/웹)는 1차에 기존 컨테이너 소비 동작을 유지한다(자동화는 서버·데이터 측 변경으로 흡수). | SHOULD | readme §8 |
| **FR-API5** | 섹션 노출 슬롯 수 N = `config.featuredSkillsTabs.limitByLayout`(**vertical 7 / horizontal 8**, 레이아웃 구동·전 섹션 공통). 적재는 여유분(상위 K≥24) 후 서빙 시 cap. | MUST | ✅ 코드 확인 2026-06-05 |
| **FR-API6** | 자동화 결과의 적재/조회 키 = **`(targetSection, targetSectionTag)` 복합키**(논리 섹션 N:1, 신규 섹션타입 불요). | MUST | ✅ CL-01 코드 확인 |

## F. 적절성 검증 요구사항 (FR-V)

| ID | 요구사항 | 등급 | 근거 |
|----|----------|------|------|
| **FR-V1** | **T1 커버리지** — 섹션별 후보 스킬 수, 미태깅률을 측정해 빈/과소 섹션을 사전 탐지한다. **1차 필수 검증**(CL-15). | MUST | s4 §4 |
| **FR-V2** | **T2 정합** — 골든셋 대비 precision/recall·섹션 간 중복 측정. **1차 범위 밖(후속)** — 골든셋 부재(CL-15). | 후속 | s4 §4 |
| **FR-V3** | **T3 태그품질** — temp topic × content_type 교차 충돌율. **1차 범위 밖(후속)** — 매핑표 부재(CL-15). | 후속 | s4 §4 |
| **FR-V4** | **T4 행동정합** — 섹션→구매 전환, 태그-선호 상관(과거 로그), A/B 섹션 CTR·구매 비교로 최종 판정한다(A/B는 후속). ⚠️ **CTR은 노출(impression) 이벤트 필요(현재 없음, CL-02)**. | MUST | s4 §4 |
| **FR-V5** | 합격 기준(정량 임계)은 data-measurement-plan.md에 정의하고 기획과 합의한다. ⚠️ 합의 전까지 **수용 게이트로 사용 금지**. T2 골든셋·T3 매핑표 부재(CL-15). | MUST | DF-S4-4 |
| **FR-V6** | A/B 효과 측정을 위해 **노출/클릭 이벤트에 `(targetSection, targetSectionTag)` 식별자 + `ranker_id(variant)` 차원**을 신규 도입한다(소급 불가 → 늦어도 B 적재·노출과 동시 배포). 노출(impression) 이벤트 신규 정의 필요. | MUST | ✅ CL-02 실측 |

## G. 비기능 요구사항 (NFR)

| ID | 요구사항 | 등급 |
|----|----------|------|
| **NFR-1 성능** | 홈탭 응답에 추가 지연을 주지 않도록, 자동화 목록은 **사전 계산·적재**되어 서빙 시 조회만 한다(런타임 점수 계산 금지). | MUST |
| **NFR-2 신선도/폴백** | 노출 목록은 일배치(D+1) 기준 최신. **(a) 배치 실패** → 직전 결과 폴백. **(b) 정상 배치·후보 슬롯 미달/0(CL-10)** → **해당 섹션 숨김**(저품질 채움·빈 노출 금지). *칩 lazy 서빙에선 R-7 확정(06-10)으로 (b)=AsIs 폴백 형태로 실현 — 칩은 C-M 수동 콘텐츠 보유, [architecture.md §4](architecture.md).* | MUST |
| **NFR-3 정합** | 적재 결과의 menu_seq는 서비스 DB의 유효·노출가능 스킬과 정합해야 한다(삭제·비노출 스킬 제외). ✅ **visibility 축 확정(ISS-006 A안, 06-11 — 웹 사용자 포함)**: 적재 검증 = `visibleStatus OR visibleStatusWeb`(앱·웹 합집합), 서빙 = 디바이스별 축 분기(AsIs 동형) — [architecture §1.4](architecture.md). | MUST |
| **NFR-4 호환** | featuredSkillsTabs 미지원 클라이언트(구버전)는 기존 `recentPurchasedSkills` 경로로 폴백한다(기존 분기 유지). | MUST |
| **NFR-5 관측성** | 배치 산출·적재 성공/실패와 섹션별 후보 수를 모니터링할 수 있어야 한다. | SHOULD |
| **NFR-6 확장성** | 랭커 추가·필터 규칙 추가가 기존 구조를 깨지 않아야 한다(FR-R7·FR-F6). | SHOULD |
| **NFR-7 적용범위(CL-11)** | 1차는 **KR 전용 · 5개 섹션**(적합 태깅 보유분). jp.hellobot·나머지 7섹션은 **현행 AsIs 유지**(자동화 미적용). 태그·마트·필터 값은 KR 기준. | MUST |

## H. 제약 · 가정

- **C1** 1차는 임시 태그(google sheet sync) 그대로 사용 — 정식 메타 파이프라인은 후속(하이브리드).
- **C2** ~~A/B 실험 메커니즘(버킷팅)은 이번 구현 범위 밖~~ → **재개정(06-10, FR-AB4)**: variant 판정(②신규 키)·배정 로그는 **이번 구현 범위**. 실험 *시작*만 잔여 실험 결정·신규 키 발급 후.
- **C3** 평점은 별점 데이터 부재 — 긍정평가비율로 대용.
- **C4** BQ→서비스 PG reverse-ETL 기존 경로 없음 — 신규 구축 필요.
- **C5** Phase A(β)는 기획 원문 재확인 전까지 가설값 (가중치 α는 06-05, 조회 정의는 CL-21로 확정됨).
- **C6** 출시일(신규 판정) 소스 = `hellobot-f445c.hlb_mart.mart_skill_open_date_se.event_date`(D-6). 서버 등록일(`menu_create_at_date`) 기준 폐기(C-2, CL-25 반전).
- **C7** 기본 풀 조건(base, 전 섹션 공통) = **오리지널 ∧ 유료 ≥750원**(✅ 확정 2026-06-06). 현행 '지금 인기'(minPrice 60하트)와는 다른 임계 — 750원을 BQ 마트 가격 필드 단위로 바인딩(/dev-data·D-5).

## I. 수용 기준 (Acceptance — 상위 레벨)

1. **1차 5개 섹션** 각각에 필터 규칙이 정의되고, /dev-data 실측으로 후보 풀이 비어있지 않음(FR-V1)이 확인된다.
2. B 랭커가 일배치로 `섹션 → 정렬된 스킬 목록`을 산출·적재하고, A(현행 산출 전체)와 **2종이 동시에 산출**된다(동일 후보 풀 전제 아님).
3. featuredSkillsTabs API가 variant 주입점을 경유해 A/B 목록을 서빙할 수 있다(버킷팅 미구현 상태에서 주입점만 동작).
4. 적절성 사전 검증(T1, 가능하면 T3) 결과가 합격 기준을 충족한다.
