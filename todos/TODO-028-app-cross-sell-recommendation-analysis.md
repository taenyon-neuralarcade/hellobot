# TODO-028 앱 내 1회 구매자 추가 구매 유도 — 데이터 분석

**유형**: 액션 (분석) → **프로젝트 승격됨**
**상태**: ✅ **완료** (분석 단계, 2026-06-10) — 추천세트 v2 확정(앱·웹 Excel) + 6/9 데이터 미팅 공유 완료. 후속 = [[TODO-044]] (적용 액션 아이템 기획·리뷰) + holdout 실험(cross-sell-recommendation 프로젝트 잔여)
**등록**: 2026-05-21
**시작**: 2026-05-25 (스코프 합의 + 프로젝트 승격)
**완료**: 2026-06-10 (분석 단계 — 추천세트 v2 확정·6/9 미팅 공유). 적용 액션 아이템 기획·리뷰는 [[TODO-044]] 로 분리
**마감**: 2026-06-09 (화) 17:00 데이터 미팅 — ✅ 추천세트 v2 공유 완료
**담당**: 코디네이터 → `/dev-data` 위임 (Phase 0 완료 후)
**관련**: [프로젝트 readme](../projects/20260525-cross-sell-recommendation/readme.md) · [분석 가이드](../projects/20260525-cross-sell-recommendation/analysis-guide.md) · [실행 체크리스트](../projects/20260525-cross-sell-recommendation/tasks.md) · [TODO-044 (후속 — 적용 액션 아이템 기획·리뷰)](TODO-044-personalization-action-item-planning.md) · [TODO-024 (앱 개인화 분석)](TODO-024-app-personalization-analysis.md) · [TODO-021 (YoY 하락 분석)](TODO-021-yoy-decline-segment-analysis.md)

## 컨텍스트

사용자 요청 (2026-05-21):
> 앱 내 1회 구매자 스킬 추천. 앱에서 사용자가 하나 더 사게 하는 방법 도출을 위한 데이터 분석.

1회 결제 경험이 있는 사용자가 두 번째 구매로 이어지지 않는 갭을 분석하여 cross-sell·추천·노출 개선의 데이터 근거를 도출. 분석 결과는 추천 로직·홈탭·푸시·프로모션 등 여러 적용 위치로 연결 가능.

### 인접 작업과의 관계

| 항목 | 관계 |
|---|---|
| TODO-024 (앱 개인화 분석) | 개인화의 한 갈래 — 본 분석은 "두 번째 구매" 라는 구체적 KPI 로 좁힘. 결과·시그널 일부 재활용 가능 |
| TODO-021 (YoY 하락 5세×플랫폼) | 결제 동향 진단 — 1회 구매자 비중·재구매율 변화가 YoY 하락 요인일 수 있음 (연결 분석 가능성) |
| coop-integration planning/kakao_product_skills/ | segment-top3·skills-by-segment-12m·sku-by-age-12m — 세그먼트별 스킬 fit 분석 자산 |
| TODO-012 홈탭 Phase #2 | 도출 결과가 노출 랭킹·사전 태깅 입력값으로 연결 가능 |

## 합의 필요 사항 (분석 착수 전)

| 항목 | 옵션 | 비고 |
|---|---|---|
| **분석 대상 정의** | A. "1회 결제만 한 사용자" (재구매 0건) / B. "최근 N개월 1회 결제 사용자" / C. 첫 결제 후 시간 윈도우별 코호트 | C 가 가장 일반적 |
| **두 번째 구매 정의** | A. 임의 스킬 추가 구매 / B. 첫 스킬과 다른 카테고리 / C. 첫 스킬과 동일 카테고리 추가 | A 부터 정의, B/C 는 세분화 |
| **분석 깊이** | A. 코호트 정의 + 재구매율 기본 통계 / B. + 세그먼트별(연령·플랫폼·콘텐츠) 패턴 / C. + 추천 가설 (어떤 스킬을 추천하면 fit 가능성 높은가) | B+C 권장 |
| **시그널 범위** | A. 결제 이력만 / B. + 콘텐츠 소비 이벤트 / C. + 사용자 속성 (생년월일·성별·관심 토픽) | C 권장 |
| **산출물 형태** | A. 노션 1-pager / B. 슬라이드 / C. 워크스페이스 프로젝트 readme + planning 산출물 | C 가 후속 실행으로 연결 자연스러움 |
| **마감 일정** | 사용자 결정 — 마감 있는 분석 vs 누적 진행 | TODO-024 (5/26) 와의 부하 분산 고려 |

## 사전 가설 (분석으로 검증)

- H1. **재구매 전환의 시간 임계점** — 첫 결제 후 X일 이내 재구매가 발생하지 않으면 long-term churn 가능성 급증
- H2. **카테고리 fit** — 첫 결제 스킬과 동일·인접 카테고리 추천 fit > 무관 카테고리 추천 fit
- H3. **연령·성별별 차이** — 5세 연령 버킷 × 첫 결제 카테고리 조합별로 두 번째 구매 패턴이 상이 (TODO-021 5세×플랫폼 분석과 결합 가능)
- H4. **첫 결제 가격대 영향** — 저단가 첫 결제(하트 충전권 등) vs 고단가 첫 결제(스킬 이용권) 사용자의 재구매 행태 차이

## 영향 범위

| 파트 | 영향 | 설명 |
|---|---|---|
| 데이터 | O (1차) | `/dev-data` — 결제·이벤트·사용자 속성 cross-sell 분석 |
| 기획 | O (2차) | 추천 로직·노출 위치 결정 |
| 서버·웹·앱 | △ (후속) | 도출된 방안이 추천·노출 변경을 요구하면 후속 프로젝트로 분리 |

## 현재 상태

**✅ 완료 (2026-06-10) — 분석 단계 종료**. cross-sell 분석(Segmentation → Profiling → Next-Best-Offer) → 추천세트 v2 확정(앱 1,045앵커·웹 12스킬) → **6/9 (화) 데이터 미팅 공유 완료**. 적용 액션 아이템 기획·리뷰는 후속 [[TODO-044]] 로 분리, 효과검증(holdout 실험)은 cross-sell-recommendation 프로젝트 잔여로 추적. SSOT 는 [`projects/20260525-cross-sell-recommendation/`](../projects/20260525-cross-sell-recommendation/).

> ✅ [[TODO-024]] (앱 개인화) 관계 정리 완료 (2026-06-07): **분리 유지**. 6/9 미팅은 cross-sell 만 공유. 단 "demographic 개인화 효과 작음" 발견은 TODO-024 로 cross-reference 전달.
> ✅ 6/9 미팅 1순위 리드 확정 (2026-06-07): **결제 직후 인세션 NBO 슬롯 + 노출 우선**. 적용안 SSOT = [`planning/action-priorities.md`](../projects/20260525-cross-sell-recommendation/planning/action-priorities.md).
> ✅ **추천세트 v2 확정 (2026-06-09)**: 앱(1,045앵커·직접 83% 커버)·웹(12스킬) 공유용 Excel 산출 = 6/9 미팅 deliverable. 노출정규화 POC는 비판검증 반증으로 보류, 효과는 holdout 실험으로 후속 검증. 상세 = [프로젝트 readme 확정 산출물](../projects/20260525-cross-sell-recommendation/readme.md).
> ✅ **활성화 기획 3종 (2026-06-09)**: 확정 NBO 세트를 노출 표면에 얹는 PO 기획(에이전트 위임) — ① 카플친 푸시(P1·holdout 진입) ② 웹 아웃트로(쿠폰 웹투앱) ③ 홈 개인화 섹션. 횡단 선결(재방문 정제세트·C 풀빌드) + 오픈결정 D1~D6. 인덱스 = [`planning/activation/readme.md`](../projects/20260525-cross-sell-recommendation/planning/activation/readme.md).

## 다음 단계

### 🎯 6/9 (화) 17:00 데이터 미팅 — 개인화 적용 아이디어 공유·리뷰

- [x] cross-sell 분석 결과 → **개인화 적용 아이디어 기획** → [`planning/action-priorities.md`](../projects/20260525-cross-sell-recommendation/planning/action-priorities.md) (적용 지도: 표면 4 + 횡단 2)
- [x] (선결) TODO-024 와 관계 정리 — **분리 유지** 확정 (2026-06-07)
- [x] 1순위 리드 확정 — **결제 직후 인세션 NBO 슬롯 + 노출 우선**
- [x] 6/9 미팅 공유 자료 = **추천세트 v2 Excel(앱 1,045앵커·웹 12스킬)** + 재설계 종합(`planning/redesign/`). 비판검증 2회(5·3 에이전트)로 노출정규화 POC 반증 → co-purchase 2층 세트로 확정
- [x] **활성화 기획 3종 작성** (PO 에이전트 3명 병렬 위임, 2026-06-09) — 카플친 푸시·웹 아웃트로·홈 개인화 섹션. 인덱스 = [`planning/activation/readme.md`](../projects/20260525-cross-sell-recommendation/planning/activation/readme.md)
- [x] 6/9 미팅 공유 완료 → 후속은 [[TODO-044]] (적용 액션 아이템 기획·리뷰) + holdout 실험으로 분리. 미결 결정(활성화 D1~D6 / holdout 설계 / 서빙·제품화 후속 프로젝트 / 관심사그룹 c 조정)은 TODO-044 에서 다룸

## 다음 단계 (분석 단계 — 완료)

프로젝트 [`tasks.md`](../projects/20260525-cross-sell-recommendation/tasks.md) Phase 0~5 (Baseline → Segment Profiling → Repurchase Pattern → Recommendation Matrix → Actions). 분석 일단락.

## 진행 로그

- 2026-05-21 — TODO 등록. 사용자 요청 = 1회 구매자 추가 구매 유도 데이터 분석. TODO-024 (앱 개인화 분석) 와 시그널·의도 겹치므로 둘 사이 관계 결정 필요 (사용자 합의)
- 2026-05-25 — 사용자 의도 정리 (세그먼트 분류 → 프로파일링 → 추천 SKU 도출). 표준 분석 방법론 합의 → **프로젝트 [20260525-cross-sell-recommendation](../projects/20260525-cross-sell-recommendation/) 으로 승격**. 분석 가이드 (`analysis-guide.md`) + 단계별 체크리스트 (`tasks.md`) 작성. TODO-024 와의 관계 = 병렬 (TODO-024 = 개인화 전반·시그널 인벤토리, TODO-028 = cross-sell 추천 본 프로젝트). 마감 6/8 (월) 픽스
- 2026-05-25 — 스코프 세부 합의: `first_paid_date` 기준 코호트, 신규/기존 결제자 분리, 동일일/재방문 2회차 분리(전체 SKU), 데이터 기반 세그먼트 축 탐색 우선(S1~S6 구성 차원을 후보로), APP 한정. Phase 0 결정 8/10 완료. **잔여 결정 = BigQuery 권한 + 착수 시점**
- 2026-05-30 — **Phase 0 완료 (10/10)**. BigQuery 권한 확인 + 즉시 착수 결정. `/dev-data` 위임 브리프(`dev-data-brief.md`) 작성. Phase 1 위임 준비 완료
- 2026-05-31 — **첫구매 채널 분리축 추가** (사용자 제기). 웹/앱 유입 동기 차이로 통합 집계 시 채널 이동자 오분류 문제. `user_first_paid_date` vs `user_first_app_paid_date` 로 A 앱퍼스트(메인)/B 웹→앱(격리)/C 웹온리(후속 제외) 판별. Phase 1.0 (3그룹 크기 확인) 추가. C 는 마케팅 스킬 선정 별도 트랙. 4개 프로젝트 문서 동기화
- 2026-06-02 — **분석 일단락 → 적용 단계 전환** (사용자 보고). 다음 액션 = **개인화 적용 아이디어 기획 → 6/9 (화) 17:00 데이터 미팅 공유·리뷰**. 마감 6/8 → 6/9 미팅으로 갱신. ⚠ [[TODO-024]] (앱 개인화) 와 스코프 중복 가능 — 관계 정리 필요
- 2026-06-07 — **적용 아이디어 기획 (`reco_client_report.html` 합본 리뷰 기반)**. 분석 → 헬로우봇 적용 지도 도출(공통 엔진 co-purchase NBO + 표면 4: 결제직후/카카오푸시/홈탭/웹→앱전환 + 횡단 2: 상품 역할태깅·1→2 전환 KPI). Phase 5 산출물 `planning/action-priorities.md` 작성. **사용자 결정 2건**: ① 6/9 리드 = **결제 직후 인세션 NBO 슬롯 + 노출 우선** (리포트 "노출량이 모든 실험의 출발점" 근거) ② [[TODO-024]] **분리 유지** (⚠ 미결 해소) — demographic 개인화 효과 작음 발견만 cross-ref 전달. 잔여: 6/9 공유자료 정리 + 미팅 리뷰
- 2026-06-09 — **추천세트 v2 확정 (6/9 미팅 deliverable)**. 스킬단위 NBO(P0) → affinity → **5·3 에이전트 비판검증으로 노출정규화 interest_lift POC 반증**(−0.23은 인기 통제 시 −0.002로 소멸·분자 90% 인세션·코호트 40~48% 좌측절단·SQL버그). → **3-전문가 재설계 종합**(신호=의도/여정 추상화·게이트=인기통제·진실=holdout 증분). **사용자 스코프 교정**: 인세션 포함 OK(타깃=결제직후 슬롯)·출력은 A→B 스킬·관심사 백오프·현재 데이터 세트 우선. **확정**: 2층 co-purchase 세트 — 앱(`data/nbo_v2_recommendation_set.xlsx`, 1,045앵커, 직접 83% 커버) + 웹12(`data/nbo_web12_recommendation_set.xlsx`, 앱데이터 관심사추정, 9직접+3토픽). 효과검증(holdout)·노출정규화 lift는 후속 보류. 세션 BQ ~6.6GB(검증·POC). SSOT = 프로젝트 readme **확정 산출물** 섹션 + `planning/redesign/SYNTHESIS-recommended-approach.md`
- 2026-06-09 — **활성화 트랙 PO 기획 3종 작성** (사용자 요청, PO 에이전트 3명 병렬 위임 → `planning/activation/`). 확정 NBO 세트를 노출 표면에 얹는 기획: ① **카플친 푸시**(전일/당일 1회차 구매자 재방문 유도 = 형제 P1 CRM A/B 구체화, **holdout 효과검증 첫 진입 차량**, 재방문 r_menu 세트 정합·정제 선결) ② **웹 아웃트로**(ⓐ웹 인세션 추가구매 ⓑ앱전용 쿠폰 웹투앱, web12+C 백오프, 쿠폰 마진 가드레일) ③ **홈 개인화 섹션**(인앱 상시, v2 세트·다중앵커 블렌드·서빙 API 인세션 슬롯 공유). 각 에이전트 실제 CSV로 추천로직 검증+효과 caveat 준수. 정직성 발견: 현 C P0는 8앵커뿐·web12와 중복 → C 풀빌드가 웹 롱테일 선결. **횡단 선결(/dev-data) 2건**(재방문 정제세트·C 풀빌드), **오픈결정 D1~D6**. 코디네이터가 인덱스(`planning/activation/readme.md`)·readme·TODO 연결. 다음: 6/9 미팅 D1~D6 결정 → 표면별 후속 프로젝트 승격
- 2026-06-10 — **TODO-028 완료 처리** (사용자 지시). 분석 단계(추천세트 v2 확정·6/9 미팅 공유) 종료. 후속 액션 = [[TODO-044]] (개인화 추천 액션 아이템 기획 및 리뷰 — 트랙 A 리뷰 미팅 일정 수립 + 트랙 B 기획 구체화) 신설. 효과검증(holdout 실험)은 cross-sell-recommendation 프로젝트 잔여로 추적. 적용 표면 기획(`planning/activation/`)은 TODO-044 의 입력 자료
