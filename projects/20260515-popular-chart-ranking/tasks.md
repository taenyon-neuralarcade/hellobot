# 과업 목록 — 인기스킬 섹션 노출 자동화

> 상위: [readme.md](readme.md) · [requirements.md](requirements.md) · [data-measurement-plan.md](data-measurement-plan.md)
> 설계: **[architecture.md](architecture.md) · [api-spec.md](api-spec.md)** (2026-06-10 v1)
> 상태: **설계 완료(2026-06-10)** — 개발 과업 착수 가능. 선행 확인 5건은 [architecture §9](architecture.md) (구현 비블로킹·실행 전 필요)

## 기획 (planning/)

- [x] 현황 파악 (S1) — [s1](planning/s1-current-state.md)
- [x] 개념 구조 확정 (S2) — [s2](planning/s2-concept-model.md)
- [x] 랭킹 정의 (S3) — [s3](planning/s3-ranking-definition.md)
- [x] 필터링/태깅 정의 (S4) — [s4](planning/s4-filtering-tagging.md)
- [x] PRD·요구사항·측정계획 산출 (readme/requirements/data-measurement-plan)
- [x] 기획 피드백 반영(C-1·C-2·D-1~7, 1차 5섹션) — readme/requirements/dmp 갱신
- [x] MWAA 현황 파악(TODO-042) → 배치 위치(D-7) 결정 — ✅ 확정 2026-06-10 (architecture §1.3)
- [x] /architect 기술 설계 (S5: architecture.md, api-spec.md) — ✅ 2026-06-10 v1
- [ ] 기획 확인: Phase A(β 원문 재확인)
- [ ] 잔여 실험 결정 확정 — 1차 지표 승인·dmp 2건·무유의 정책·비열등 마진·C-M 큐레이션 정책·셀 배분·측정 이원화·기간 ([po §6](planning/ab-test-po-review.md)·[analysis §14](planning/ab-test-analysis-design.md))
- [ ] 선행 운영 확인 — 운영 칩 구성 실값·키18 현 단계·신규 Hackle 키 발급 (architecture §9-1·2)
- [ ] **리뷰 후속 결정(06-11)** — ISS-002 computed_date 기준(권고: 문서 개정+guard=어제)·ISS-006 웹 C-A visibility 정책·ISS-011 질의 7건 ([issues.md](issues.md)·[리뷰](reviews/code-review-5lens-20260611.md))
- [ ] 계약 문서 일괄 개정(ISS-002 정의·ISS-008 CronJob 추출 계약·ISS-009 드리프트 9건) — architecture·api-spec Changelog 필수
- [ ] 범위·일정 확정 + 착수 지시 (S6)

## 서버 (/dev-server) — [architecture §1·§3·§4](architecture.md) / [api-spec](api-spec.md)

- [x] `HomeSkillRanking` 엔티티 + 마이그레이션 (api-spec §3 — 유니크 2종·tag `''` 정규화) — ✅ 06-11 `7dc5b7bd`
- [x] 적재 API `PUT /api/home/skill-rankings` @Airflow — 유효성(visible JOIN)·섹션 그룹별 단일 tx 교체·0건 skip 보고·멱등 (api-spec §1) — ✅ 06-11
- [x] ②랭킹 게이팅 — 플래그 2종 + Hackle 키(placeholder 0), 판정 5단, 키18 패턴 복제 (architecture §3.2) — ✅ 06-11
- [x] 랭킹 fetch(limit×2) + shape 어댑터(tagSkills 단일 그룹 / recentPurchased pinned 선두) + 빈 랭킹 AsIs 폴백·마킹 (architecture §3.3~3.4) — ✅ 06-11
- [x] 서버 배정 로그 훅(variant·fallback 포함 — winston 1차 seam, 고도화는 측정 이원화 결정 종속) — ✅ 06-11
- [x] config·플래그 상수 (api-spec §4) — ✅ 06-11
- [x] 구버전 폴백(recentPurchasedSkills) 무회귀 확인 (NFR-4 — getTabData·키18 분기 무수정) — ✅ 06-11
- [ ] **코드 리뷰 수정 라운드(머지 전)** — ISS-001(chatbotSeq 변환, 블로커)·ISS-003(그룹 키)·ISS-004(menuSeq 중복 skip)·ISS-005(400 계약) + ISS-006(정책 확정 후) + L1-09 서빙 태그 정규화(06-11 결정 — 태그 비계열 섹션은 칩 태그 무시하고 `''` 로 랭킹 조회, AsIs "다른 섹션에서는 무시" 시맨틱 동기화. 적재 거절·어드민 입력 가드는 보류) — [리뷰](reviews/code-review-5lens-20260611.md)
- [ ] 적재 에러 Slack 알림 훅 (06-11 결정) — `replaceRankings` try/catch에서 `notifyToSlack` 1회(redisKey dedup), 채널 = 신규 env `SLACK_SKILL_RANKING_ALERT_CHANNEL`(값은 사용자가 환경변수 목록 등록), SMS 제외
- [ ] PR 리뷰·머지 — [hellobot-server#2444](https://github.com/thingsflow/hellobot-server/pull/2444) (✅ 생성 06-11, **5렌즈 리뷰 06-11 — 수정 라운드 후 머지**) + 핵클 키 발급 후 config 교체 커밋

## 데이터 (/dev-data) — [architecture §1.2·§2](architecture.md)

- [ ] **실측 13항목** — ✅ 06-11 부분 완료: D-5 단위(menu_price=하트, 750원=5하트)·eval distinct(5종)·topic/intents distinct·T1 후보 수. 잔여: 교차표(T3)·시그널 SQL 대조·운영DB 덤프·SAFE_CAST 실패율 등 — data-measurement-plan §8
- [x] 랭킹 마트 `mart_home_skill_ranking` SQL + 마트 체인 등록 — 시그널·norm 분해 컬럼·computed_date 파티션 (architecture §1.2·§2) — ✅ 06-11 `e5ec4a3` (dry-run+스냅샷 프리뷰 검증, 카탈로그 동기 포함)
- [x] 섹션 바인딩 블록(5섹션 필터식) + **값 바인딩 확정** — ✅ 06-11: 사주/타로=`chatbot_content_type`(temp topic에 해당 값 부재 실측), 재회=`intents ∋ '재회'`(`|` 구분), 신규=open_date≤6개월, D-5·D-6 해소
- [ ] **칩 복합키 바인딩 4곳 기입** — 운영 칩 구성 확인 후 (SQL `section_pool` TODO — realtime=`recentPurchasedSkills`만 바인딩 완료. ⚠️ server_rdb에 칩 테이블 미수집 → BQ로 확인 불가, 어드민/운영 DB 경로 필요)
- [ ] **코드 리뷰 수정 라운드(머지 전)** — ISS-007(menu_seq dedup 방어)·ISS-002(computed_date 결정 반영)·rejoin TRIM(ISS-010) — [리뷰](reviews/code-review-5lens-20260611.md)
- [ ] PR 리뷰·머지 — [common-data-airflow#188](https://github.com/thingsflow/common-data-airflow/pull/188) (✅ 생성 06-11, **5렌즈 리뷰 06-11 — 수정 라운드 후 머지**)
- [ ] CronJob 추출+push 스크립트 — freshness guard 포함 (/dev-infra 협업, architecture §1.3)
- [ ] event-spec 작성(노출 이벤트 + section/variant 차원, CL-02) — 측정 이원화 결정 후
- [ ] 적절성 검증 쿼리 T1~T3(+T4 사전 로그) — ✅ T1 완료 06-11: base 442·사주 172·타로 182·재회 39·**신규 9⚠️**(6개월 기준 — N 조정은 기획 가변 C-2). T2·T3 후속(CL-15)
- [ ] (후속 태스크 등록) CL-04 norm 데이터 검증·알고리즘 보완 — 최종단계 (architecture §2.3)

## 인프라 (/dev-infra) — [architecture §1.3](architecture.md)

- [ ] CronJob `load-home-skill-ranking` 매니페스트(`base/hlb/cronjobs/` 선례, 12:00 KST·Slack 알림) + BQ SA 시크릿

## 웹 (/dev-web) · iOS (/dev-ios) · Android (/dev-android)

- [ ] **(필수, CL-02)** 측정 이벤트 신규 발화 — 노출(impression) 신규 + `(targetSection, targetSectionTag)` 식별자 + variant 차원. 소급 불가 → C-A 노출과 동시 배포. **event-spec·측정 이원화 결정 선행** (api-spec §2.3)
- [ ] 1차는 기존 featuredSkillsTabs 컨테이너 소비 유지(FR-API4) — 서버 응답 계약 무변경

## 스튜디오 (/dev-studio)

해당없음

## QA (/qa)

- [ ] 테스트 케이스 작성 (qa-test-cases.md) — variant 분기 5단·폴백/킬스위치(architecture §3.4)·shape 정합·뱃지·hasMore·구버전 폴백
- [ ] 테스트 수행 및 결과 기록

## 의존 관계

- 서버 테이블+적재 API ∥ 데이터 마트 → 인프라 CronJob → 서버 서빙 분기 → 측정(event-spec) — architecture §7 착수 순서
- 값 바인딩 실측(FR-F7) + 운영 칩 구성 확인 → 마트 섹션 바인딩 블록 확정
- **variant 판정(②신규 키)·배정 로그 = 이번 구현 범위**(FR-AB4 재개정 06-10 — 구 "버킷팅 범위 밖" 폐기). 실험 *시작*은 잔여 실험 결정 + 신규 키 발급 후
- 클라이언트 이벤트는 event-spec + 측정 이원화 결정 후에만
