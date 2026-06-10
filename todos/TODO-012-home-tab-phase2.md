# TODO-012 홈탭 Phase #2 — 노출 스킬 랭킹 자동화 + 사전 스킬 태깅

**유형**: 액션 (명세화 시점에 프로젝트화 예정)
**상태**: 진행 중 — S5 윤곽(06-08) + 현행 구현 감사(06-10) + A/B 실험 설계 검토(06-10) 완료, **다음 = S5 세부(/architect) + A/B 구조 사용자 결정**
**등록**: 2026-05-13
**시작**: 2026-06-02
**완료**: -
**마감**: **2026-06-12 (금) — 개발 완료** (사용자 갱신 6/8, 6/5 기획·설계 → 6/12 개발 완료로 연장)
**담당**: 코디네이터 → /architect / /dev-* 위임 (기획·일정 픽스 후)
**관련**: [TODO-006](TODO-006-home-tab-phase1-watch.md) (Phase #1 모니터링)
**기획 문서**: <https://www.notion.so/dlt-partners/356eb34da6e6816abef3e1f0daf2f10d>
**선 진행 UI 작업 (A/B 테스트)**: <https://www.notion.so/dlt-partners/A-B-364eb34da6e6807c87eeff59937aa390> — Phase #2 와 별개로 이미 진행된 UI 작업. 기획 시 영향·중복·통합 가능 여부 점검 필요
**기획 문서 그룹**: [`projects/20260515-popular-chart-ranking/planning/`](../projects/20260515-popular-chart-ranking/planning/) — [execution-steps.md](../projects/20260515-popular-chart-ranking/planning/execution-steps.md) (스텝 골격) · [s1-current-state.md](../projects/20260515-popular-chart-ranking/planning/s1-current-state.md) (S1 현황) · [overview-notes.md](../projects/20260515-popular-chart-ranking/planning/overview-notes.md) (사용자 원본)

## 컨텍스트

홈탭 개선의 두 번째 단계. 스코어에 따른 스킬 목록 도출 자동화 (현재는 수동). 사전 작업으로 **스킬 태깅** 작업이 선행되어야 함.

사용자 결정 (2026-05-13): "TODO로 등록 후 명세화 시점에 프로젝트화" — 지금은 사전 작업 + 설계 명세화 단계, 본격 구현이 필요해지면 그 시점에 프로젝트로 승격.

**일정 (2026-05-15 갱신 v2)**:
- ~5/20 (수): **상세 분석 + 기획 + 일정 추정 완료** (스킬 태깅 체계 + 랭킹 스코어 정의 + 자동화 로직 명세 + 개발 일정 추정)
- 5/20 픽스 이후: 개발 착수 (이 시점에 프로젝트화)

> 5/15 1차 갱신은 ~5/22 기획 / 5/25 이후 개발이었으나, 같은 날 v2 갱신으로 **상세 분석·일정 추정까지 5/20 픽스**로 당겨짐.

## 현재 상태

설계 단계 — **S1~S4 + 계약 문서 + 결정 라운드(14건) + 기획 피드백 반영(06-06) + S5 윤곽(06-08) + 현행 재분석·구현 감사(06-08/06-10) 완료**. 1차 5섹션 확정(C-1·C-2·D-1~D-7 반영), 배치 토폴로지 제안 완료(D-7: 컴퓨트=airflow / write=서버+K8s CronJob, TODO-042 조사 종료). **`featuredSkillsTabs` 칩 컨테이너는 이미 LIVE**(서버 05-21 / iOS·Android 모두 05-26 머지) — CL-03(A 캡처) 해소, **B = `fetchSkillListBySectionType`(home.ts L540) 후보 fetch 교체**(lazy 경로 limit+1 선컷 때문에 "재정렬"은 불충분 — 동일 shape 반환, 앱 무변경). 피쳐 문서(`hellobot-server/docs/features/20260511-home-rank-skill-section/` 8종)↔코드 전수 대조 **전 항목 일치**. **다음 = S5 세부 패스(/architect): architecture.md·api-spec.md 작성(②→①③④→⑤), 잔여 위임 CL-04(norm)·CL-08(cold-start)**.
- 설계 전 계약 문서: [readme.md(PRD)](../projects/20260515-popular-chart-ranking/readme.md) · [requirements.md](../projects/20260515-popular-chart-ranking/requirements.md) · [data-measurement-plan.md](../projects/20260515-popular-chart-ranking/data-measurement-plan.md) · [tasks.md](../projects/20260515-popular-chart-ranking/tasks.md) · [status.md](../projects/20260515-popular-chart-ranking/status.md)
- S2 결과: 개념모델=섹션(필터+랭커). A/B=랭커선택(AsIs/v1), 유저버킷·일괄, 키18과 별도·순차. → [s2-concept-model.md](../projects/20260515-popular-chart-ranking/planning/s2-concept-model.md)
- S3 결과: 공식 확정(구매0.35/조회0.1/전환0.2/**평점=긍정비율0.15**/매출0.15/신규부스트0.05), A=서버 입력순서. 계산 common-data-airflow/적재 서버위임. 기획자 확인 잔존(가중치 6항목·조회 분모 정의·Phase A). → [s3-ranking-definition.md](../projects/20260515-popular-chart-ranking/planning/s3-ranking-definition.md)
- S4 결과: 필터=3축그룹(시간성/주제/의도+대상), 섹션 7/12=의도(+대상) 본체. 섹션→필터 규칙 **신규 설계**(12섹션 1차 필터식 가설, 값 바인딩은 /dev-data 실측). 적절성=사전3종(커버리지·정합·태그품질)+행동/AB. **DF-S4-1(임시태그 `taenyon_temp_skill_tag_info_v2` 승격 vs 공식 카테고리 `chatbot_content_type` 흡수) = S5 선결 결정.** → [s4-filtering-tagging.md](../projects/20260515-popular-chart-ranking/planning/s4-filtering-tagging.md)
- S5 진행: 윤곽(5레이어) → [s5-architecture-outline.md](../projects/20260515-popular-chart-ranking/planning/s5-architecture-outline.md) · 현행 서빙 분석(06-08 정정) → [s5-asis-serving-analysis.md](../projects/20260515-popular-chart-ranking/planning/s5-asis-serving-analysis.md) · **현행 구현 감사(06-10, A/B 설계 기준선)** → [s5-asis-implementation-audit.md](../projects/20260515-popular-chart-ranking/planning/s5-asis-implementation-audit.md)

S1 핵심 발견:
- PR #2414는 **랭킹 자동화가 아님** — `featuredSkillsTabs`(칩/탭 노출 컨테이너) + 점진공개(FeatureFlag·핵클 키18 A/B)를 만든 것. = 사용자가 말한 "선행 A/B UI 작업". Phase #2는 이 그릇 뒤에 필터링+랭킹 실체를 채우는 일.
- "인기스킬"=`recentPurchasedSkills`(구매량 반자동+pinned). 사주/타로/재물운 등은 **운영 DB `TodayTagSkillsTag`/`FixedMenuTag` 태그 큐레이션 수동**(코드 상수 아님).
- 스킬 메타: tag·category·targets/subjects/contentTypes 존재. **topic/intent 전용 메타는 부재** → S4 핵심 결정(기존 태그 재활용 vs 신규 메타축).
- 통합 필터 정의 레이어 부재(섹션별 하드코딩) → S5 과제. 랭킹 배치 적재 위치(server/airflow/mwaa) 미확인 → S3 선행.

## 다음 단계

> 5월의 Phase 1(상세 분석~일정 추정) 체크리스트는 S1~S4 + 계약 문서로 모두 소화됨 — 이력은 진행 로그 참조. 현재 기준:

1. **S5 세부 패스(/architect)** — [architecture.md]·[api-spec.md] 작성, 순서 ②→①③④→⑤: 랭킹 테이블 형상 + 리버스-ETL 토폴로지(D-7 제안 확정) → B 후보 fetch 교체 seam + ②랭킹 variant 신호(키 18과 별도) → CL-04(norm)·CL-08(cold-start) → 서빙·측정(event-spec은 CL-02로 별도 트랙)
2. **A/B 실험 구조 결정(사용자)** — 검토 산출물 2종([ab-test-po-review.md](../projects/20260515-popular-chart-ranking/planning/ab-test-po-review.md) §6 · [ab-test-analysis-design.md](../projects/20260515-popular-chart-ranking/planning/ab-test-analysis-design.md) §14) 기반: 구조(3군 중첩 권장 vs 순차 vs 2군 원안)·키18 처리·1차 지표(유저 레벨 net) 승인·dmp 정의 2건 → 결정 후 dmp·requirements(FR-AB)·event-spec 반영. **선행: 키18 현 운영 단계 확인**
3. 비블로킹 병행: base 단위 바인딩(D-5, /dev-data) · 운영 DB `home_section_featured_skills_tab` 칩 구성 조회(1차 5섹션 매핑 확정) · ①컨테이너 실험(키 18) 현 단계 확인 · β Phase A 기획 원문 재확인
4. S5 세부 완료 → /dev-* 착수 + **프로젝트화 결정** — 마감 **6/12 (금) 개발 완료** (A/B 실험 실행은 6/12 개발 마감과 별개 게이트 — 키18 정리·CL-02 이벤트 검증·앱 보급 충족 후)

## 진행 로그

- 2026-05-13 — TODO 등록. 사용자 결정: 명세화 시점에 프로젝트화. 우선 사전 작업(태깅) 부터 시작
- 2026-05-15 — **사용자 일정 갱신**: 기획 픽스 ~5/22 / 개발 착수 5/25 이후. 단일 5/22 마감 → 두 단계 분리 (기획 5/22 / 개발 5/25+). 다음 단계 Phase 1·Phase 2 로 재구성
- 2026-05-15 — **기획 문서 링크 추가**: Notion <https://www.notion.so/dlt-partners/356eb34da6e6816abef3e1f0daf2f10d>
- 2026-05-15 — **사용자 일정 v2 갱신**: 5/20 (수)까지 **상세 분석 + 기획 완료 + 일정 추정 완료** 필요. 1차 갱신(~5/22) 보다 2일 당겨짐. Phase 1 항목에 "상세 분석" + "개발 일정 추정" 명시 추가
- 2026-05-18 — **선 진행 UI 작업 (A/B 테스트) 링크 추가**: Notion `A/B 364eb34d` — Phase #2 와 별개로 이미 진행된 UI 작업. 기획 시 영향·중복·통합 가능 여부 점검 항목 Phase 1 에 추가
- 2026-06-02 — **마감 갱신 → 6/5 (금)** (사용자). 6/5 까지 **기획 구체화 완료 + 개발 설계 단계까지** 진행. 5/20 초과분 해소. 시작일 6/2. 개발 설계 진입 시 프로젝트화 검토.
- 2026-06-03 — **/analyze 실행 계획서 작성** ([TODO-012-analyze-execution-plan.md](TODO-012-analyze-execution-plan.md)). 분석 과업 7단계 + 결정 요소 D0~D6 분리 (확정 가능분 vs 정책 결정분). 선결 블로커 B1(Notion 문서 접근 불가)·B2(Phase #1 완료 미확정) 식별.
- 2026-06-03 — **B1 해소**: 사용자가 기획 문서 ①("인기차트 선정 로직", 356eb34d) 로컬 사본 제공. 문서 ②(A/B 364eb34d)는 "고려 안 해도 됨" 지시로 제외 → Step 2/D1 삭제. 문서가 KPI(Input CTR / Output 전환율·신규진입율·구매상품수)·스코어 공식(구매0.35/조회0.1/전환0.2/평점0.15/매출0.15/신규부스트0.05)·7일 윈도우·일1회 새벽4시 배치·BQ→서비스DB rankings 적재 아키텍처를 **확정**. 실행 계획서를 검증+갭 채우기로 재정렬. 잔여: C1~C5(데이터·파이프라인 실현 검증), D-A(카테고리 태깅 체계=사전 태깅 본체), D-B~E(개인화·국가·오버라이드·노출위치), 이슈 α(가중치 불일치)·β(Phase A 누락). D0 확정=`20260515-popular-chart-ranking` 스켈레톤 재사용.
- 2026-06-04 — **사용자 개괄 정리(temp.md) 반영**: 너무 디테일하다는 피드백 → 실행 계획서를 **개괄 6스텝(S1~S6)** 으로 재정리. 핵심 프레임 = **노출 자동화 = 필터링 + 랭킹**. 이번 대상 = **인기스킬 섹션**(여러 필터링된 스킬 목록 담는 노출 영역, PR #2414). 랭킹 1종(기획 문서) + 섹션별 필터링(메타: 카테고리·관심사·의도). **S4 필터링/태깅이 분석 무게중심**. 진행 방식 = 한 스텝씩 구체화, S1(현황 파악)부터. 이전 C/D/이슈 항목은 폐기 않고 S3~S5 구체화 시 재사용.
- 2026-06-04 — **문서 그룹 이관 + temp.md 정리**: 기획 산출물을 `projects/20260515-popular-chart-ranking/planning/`로 이동(execution-steps.md, s1-current-state.md, overview-notes.md). temp.md는 latin1 깨짐 → UTF-8로 overview-notes.md 재작성 후 원본 삭제. todos/TODO-012-analyze-execution-plan.md는 execution-steps.md로 대체 후 삭제.
- 2026-06-04 — **S1(현황 파악) 완료**: hellobot-server PR #2414 + 코드 조사. 발견 = ① PR #2414는 랭킹 자동화 아님, featuredSkillsTabs 노출 컨테이너(=선행 A/B UI 작업) ② 섹션 정의 소스는 운영 DB(TodayTagSkillsTag/FixedMenuTag) 수동 큐레이션 ③ recentPurchasedSkills만 구매량 반자동 ④ topic/intent 전용 메타 부재(tag/category/subjects는 존재) ⑤ 통합 필터 레이어 부재. 후속 조사 플래그: 랭킹 배치 위치, 섹션↔태그명 DB 매핑, 검색도메인 메타 재사용 가능성. 상세 → s1-current-state.md. **다음 = S2.**
- 2026-06-04 — **S3(랭킹 정의) 완료**: DF-S3-1 평점=**긍정평가 비율(비-💩)로 재정의**(사용자 결정). DF-S3-4 출시일=서버 등록일, DF-S3-5 타이밍=D+1 오전. 잔존 기획자 확인: 가중치 6항목 확정(α)·조회 분모 정의(기본 open_skill_description)·Phase A(β) — 블로커 아님, S4 병행. 적재 주체는 S5로. **다음 = S4.**
- 2026-06-04 — **S3(랭킹 정의) 조사**: 사용자 방향 — 시그널은 BQ/airflow 일배치로 스킬별 지표 생성, 배치 위치 common-data-airflow 유력(mwaa 가능), A(AsIs)=서버 입력 순서 그대로. 데이터 조사 결과: 6시그널 중 5개(구매·조회·전환·매출·신규) BQ에 menu_seq·일별 가용, **평점만 별점 아닌 이모지 이진(💩=1/else=5)** → 재정의 필요(DF-S3-1 ★). 스킬키 menu_seq(STRING)↔fixed_menu.seq(INT) 정합 OK. 배치 방향=계산 common-data-airflow 마트/적재 서버 위임(컨벤션, collection rank·recent-purchased 선례). reverse-ETL 신규 구축 필요. 타이밍 제약(체인 KST11시 vs 새벽4시). 문서이슈 α(가중치 6항목 canonical 제안)·β(Phase A 누락) 기획자 확인. 문서 → s3-ranking-definition.md. **결정 대기: DF-S3-1(평점)~DF-S3-6.**
- 2026-06-04 — **S2(개념 구조) 완료**: 사용자 신규 요구사항 — ① 랭킹 1종만 이번 적용 ② A/B(A=현재 그대로, B=자동 랭킹), API가 2종 목록 서빙 ③ 장기 다중 랭커 공존 비파괴 확장. 개념 모델 = **섹션 = 필터(후보 풀) + 랭커(교체 전략)**, A/B=랭커 선택(AsIs vs PopularityScore v1). 결정: DF-S2-1=유저 버킷·일괄 / DF-S2-2=기존 컨테이너 A/B(키18) 종료 후 **별도·순차 실험**, **A/B 구현·버킷팅은 알고리즘 적용 이후 단계로 이연**(이번 범위 밖). 구조 요구 = "2종 목록 산출 + variant 주입점 분리"까지만. 문서 → s2-concept-model.md. **다음 = S3(랭킹 정의).**
- 2026-06-05 — **S4(필터링/태깅 정의) 1차 설계**: 사용자 추가 정보 — 태그 메타 원천 = 임시 태그 `google_sheet_sync.taenyon_temp_skill_tag_info_v2`(topic·intents·temporal) + 공식 카테고리 `hlb_mart.mart_fixed_menu_server.chatbot_content_type`(chatbot·chatbot_category·chatbot_category_relation join). 섹션→필터 규칙은 **미존재 → 신규 설계**, 적절성 테스트 방향 도출 요청. 설계: 필터=축 조건식 `Π match(axis,values)`, 12섹션을 **3그룹**(G1 시간성: 실시간·신규 / G2 주제: 사주·타로·1:1상담 / G3 의도+대상: 7개)으로 분류 — **G3가 본체**(4개는 의도∩대상 복합). §3에 12섹션 1차 필터식 가설. 적절성=**T1 커버리지·T2 정합(골든셋 P/R)·T3 태그품질(temp topic×공식 category 교차충돌)·T4 행동정합(섹션-구매전환·태그선호상관·AB)**. 결정요소 DF-S4-1(태그소스 이원화 해소)★·DF-S4-2(대상축 출처)·DF-S4-3(필터 운영형식)·DF-S4-4(합격기준). BQ 인증 만료로 값·커버리지 실측은 **/dev-data 위임 5항목**으로 분리(병렬). 문서 → s4-filtering-tagging.md. **다음 = S5(아키텍처) — DF-S4-1 선결.**
- 2026-06-05 — **DF-S4-1 결정(사용자) = 하이브리드**: 1차는 임시 태그(topic/intents/temporal) **그대로** 사용해 빠르게 출시, 정식 승격/공식 카테고리(chatbot_content_type) 정합은 /dev-data 실측 후 **후속 단계**. S5 함의 = 필터 메타·랭킹 스코어 둘 다 BQ → **일배치가 BQ에서 섹션별 필터→랭킹 적용 후 `섹션→[정렬 menu_seq]` 결과를 서비스 DB 적재**(서비스 DB에 태그 메타 이동 불필요=빠른 1차), 승격 seam은 후속 서버측 필터 평가 전환. A=현행 서버순서, B만 배치 산출. → **S5 진입 가능.**
- 2026-06-05 — **결정 라운드 완료(3배치 14건)**. 배치1(제품/범위): CL-11 **KR 전용**·CL-09 **실시간=공통7일 라벨**·CL-07 **매출 외부채널 포함 수용**·CL-10 **빈섹션 숨김**. 배치2(랭킹): **α=6항목 확정**·CL-03 A캡처·CL-04 norm·CL-08 신규섹션 = **S5 위임**(권장안 문서화). 배치3(정책): CL-13 **중복 허용**·CL-14 **pinned 유지**·CL-16 **어드민 후속**·CL-15 **1차 T1만**. 기본값 처리: CL-21 조회=open_skill_description 확정·CL-12 주입점 기본 A·DF-S4-3 편집형·CL-20 temporal 미사용. β Phase A만 기획 원문 재확인 대기. 5개 계약 문서 전부 반영(결정로그 = reviews/00 §A-6). **다음 = S5(/architect): architecture 전면 + api-spec(복합키 확정), S5 위임 3건 설계.**
- 2026-06-05 — **사실 확인(3 조사 에이전트) + 🟢 문서 교정 반영**. CL-05 슬롯 N=**7/8**(config.featuredSkillsTabs.limitByLayout, 코드 확인)·CL-01 섹션매핑 **N:1 복합키(targetSection,targetSectionTag), 신규타입 불요**(popularTagSkills 어드민 enum 누락 🚩)·CL-02 **노출이벤트+variant 차원 부재 확정→신규 필수**(소급불가). 계약 문서 교정: data-measurement-plan v2(긍정평가비율 식·그레인·SQL 2단/7일·✅→🔶·매출 결정종속·실측 11항목), requirements v2(가설→MUST(구조) 강등·SAFE_CAST·FR-API5/6·FR-V6 이벤트·norm 비결정), readme(§6.1 섹션매핑·1:1상담 content_type·§11 결정표·클라 O(측정)), status(확정/잠정 분리), tasks(이벤트 필수). **다음 = Tier1·2 결정 라운드.**
- 2026-06-05 — **계약 문서 적대적 리뷰(5렌즈 병렬) + 메타 리뷰·체크리스트**. 5개 비판 에이전트(정합성/실현성/모호성/완전성/설계준비도) → reviews/review-1~5. 메타 재평가: R5(구조관점)=architecture 착수 가능(Blocker 0), 단 R3·R4 항목은 "구현 전 확정/측정 타당성"으로 실재 → 결정 의제 유효. R2가 코드/SQL 검증으로 **내 문서 사실오류 다수 적발**(긍정평가비율 line216=1~5평균 오인용, mart_use_skill_se 그레인, db.py 부재, 카탈로그 DEPRECATED, 매출 외부채널 오염). 영향도순 체크리스트 26항목(Tier1~4)으로 정리 → reviews/00-meta-review-and-checklist.md. Tier1(5): 섹션매핑·측정이벤트·A캡처·norm·슬롯N. **다음 = 결정 라운드(CL-01~12) + 🟢교정 즉시반영, 그 후 S5.**
- 2026-06-05 — **설계 전 계약 문서 산출**(사용자 요청: S5 전에 architect 참조 문서를 먼저 정의). S1~S4 결정을 프로젝트 루트 5문서로 종합: **readme.md(PRD)** — 배경·목표·KPI요약·핵심개념·섹션12·범위·영향범위·의존·일정·오픈결정 / **requirements.md** — FR(필터F·랭킹R·A/B·배치B·API·검증V)+NFR+제약+수용기준 / **data-measurement-plan.md** — 랭킹 스코어 canonical·시그널 소스·KPI·적절성 T1~T4·태그소스(하이브리드)·실측갭7 / **tasks.md** — 파트별 과업 / **status.md** — 대시보드. BQ 인증 만료로 라이브 실측은 /dev-data 후속. **다음 = S5(/architect) — 사용자 진행 지시 대기.**
- 2026-06-08 — **마감 갱신 6/5 → 6/12 (금) 개발 완료** (사용자). 기획·설계 단계(6/5)에서 **개발 완료(6/12)** 까지로 일정 연장·구체화. S5(/architect) → /dev-* 구현을 6/12 안에 마무리 목표. 개발 착수 시점에 프로젝트화 검토.
- 2026-06-06 — **기획 피드백 반영(계약 문서 6종)**. 사용자 피드백 → 충돌 2건·결정 명확 7건·결정필요 7건 분석 후 반영. **C-1**: A `AsIsRanker`=현행 산출 방식 전체 보존(정렬만 아님), B 후보풀과 비공유 → FR-R2/R6/R9·AB1 개정(동일 후보풀 제약 제거). **C-2**: 신규 기준=출시일 `open_date`(`hlb_mart.mart_skill_open_date_se.event_date`), 서버 등록일 폐기(CL-25 반전) — 신규 인기 섹션 ≤6개월(가변)·신규부스트 30일(D-4/D-6). **D-1·D-2·D-3**: 커플/솔로·1:1 상담 등 **7섹션 최종단계 보류**(적합 태깅 부재) → **1차 5섹션**(실시간·신규·사주·타로·재회) 확정. **공통 base 필터**(오리지널∧750↑·FR-F0 신설, 현행조건 D-5 확인). **성공지표**: 1차 전환율·최종 총 매출 가드레일. **D-7**: 배치 위치 airflow vs MWAA = MWAA 현황 파악 후 결정 → **TODO-042 신설**. 반영=readme/requirements/dmp(v3)/tasks/status + reviews/00 결정로그. **다음 = TODO-042(MWAA 파악) → S5(/architect).**
- 2026-06-08 — **S5 윤곽 + 현행 재분석(정정)**: S5를 "윤곽 먼저" 방식으로 진입 — 5레이어(①계산 ②적재 ③랭커추상화 ④서빙 ⑤측정) 구분 → [s5-architecture-outline.md](../projects/20260515-popular-chart-ranking/planning/s5-architecture-outline.md). dev-server 현행 분석 중 **로컬 stale 체크아웃(04-30) 오결론 발견** → master pull 후 재분석: **`featuredSkillsTabs` 칩 컨테이너 서버·앱 모두 이미 LIVE**(서버 05-21 / Android #1128·iOS #1418 모두 05-26 머지). CL-03(A 캡처) 해소 — A=매 요청 live라 캡처 불요. 두 A/B 축 정립: ①컨테이너(Hackle 키18, LIVE) / ②랭킹(이 프로젝트, 미착수). dev-android PR #1128 분석 포함 → [s5-asis-serving-analysis.md](../projects/20260515-popular-chart-ranking/planning/s5-asis-serving-analysis.md). reviews/00 CL-03 해소 행 추가, S5 위임 3건→2건(CL-04·08).
- 2026-06-10 — **A/B 실험 설계 검토(PO·데이터분석가 병렬 에이전트)**: 사용자 제안(phase1 UI 포함 — A=무칩 기존 상태 vs B=칩+자동랭킹, 목표①섹션 경유 진입·구매자 증가 ②자동랭킹>수동 큐레이션)을 양 관점에서 검토·설계. 핵심 판정 = **2군은 UI 효과·랭킹 효과 혼재로 목표② 식별 불가**, "기존 상태"도 빈 홈이 아니라 분 단위 갱신 legacy `recentPurchasedSkills`(약하지 않은 대조군). 구조 옵션 3종 비교(순차/3군 중첩/2군) → PO 권장=**3군 중첩**(키18 게이트 흡수+②랭킹 키 중첩, L/C-M/C-A — 2단 롤백 안전판). 1차 지표 재정의=**유저 레벨 net**(구매자 전환율 superiority + ARPU 비열위 5%), 섹션 CTR·경유 구매는 B군 내 진단 강등, 총매출 가드레일 유지. ✅BQ 실측 성공: 4주(5/11~6/7) KR 홈 90k 유저·p≈0.30·구매자당 ₩19,063·CV 2.49 → **4주 고정 권장**(전환율 MDE 2군 3.2%/3군 4.3%, CUPED ρ=0.5 시 ARPU 4.5%). 선결 = 키18 단계 확인·CL-02 이벤트 배포+검증·②variant 키+배정 로그 BQ 적재·M↔R 목록 중복도 측정·AA 드라이런. 산출물 → [ab-test-po-review.md](../projects/20260515-popular-chart-ranking/planning/ab-test-po-review.md) · [ab-test-analysis-design.md](../projects/20260515-popular-chart-ranking/planning/ab-test-analysis-design.md). **결정 대기 항목 = 각 문서 §6/§14** (구조·키18·지표 승인·dmp 정의 2건·기간·모집단 세부).
- 2026-06-10 — **현행 구현 감사 완료 (A/B 설계 기준선)**: 사용자 지정 소스 `hellobot-server/docs/features/20260511-home-rank-skill-section/`(8종)+iOS 피쳐 기록을 실코드와 전수 대조 — **기능 명세 전 항목 일치**(stale 3건뿐: 마이그레이션 파일명 표기·backend-guide 엔티티 골격·iOS 문서의 `?limit=7` — 전부 코드가 정답, iOS 실코드는 `?layout=vertical`+hasMore로 이미 정렬). ⭐ **seam 정밀화**: lazy 경로가 소스 fetch에 limit+1 선컷(vertical=8개/horizontal=9개만) → B는 "fetch 후 재정렬"이 아니라 **후보 fetch 교체**(랭킹 테이블 기반, 기존 섹션과 동일 shape 반환) — 하류(visibility 정형화·cap·hasMore·앱 계약) 전부 무변경 재사용. 신규 결정 항목 5건 도출(②variant 신호·shape 어댑터·visibility 여유분·빈 랭킹 fallback·실험 모집단) → [s5-asis-implementation-audit.md](../projects/20260515-popular-chart-ranking/planning/s5-asis-implementation-audit.md). 윤곽·현행분석·status·execution-steps에 정밀화 동기 반영. **다음 = /architect 세부 패스.**
