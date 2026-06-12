# 과업 목록 — 인기스킬 섹션 노출 자동화

> 상위: [readme.md](readme.md) · [requirements.md](requirements.md) · [data-measurement-plan.md](data-measurement-plan.md)
> 설계: **[architecture.md](architecture.md) · [api-spec.md](api-spec.md)** (2026-06-10 v1)
> 상태: **구현 + 리뷰 수정 라운드 완료(2026-06-11)** — 데이터 PR #188 머지 대기 · **서버 PR #2444 닫음(06-12, 재오픈/재생성 결정 대기)**. 선행 확인 5건은 [architecture §9](architecture.md) (구현 비블로킹·실행 전 필요)

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
- [x] **리뷰 후속 결정(06-11)** — ✅ 사용자 확정: ISS-002=**A안**(기준일=어제)·ISS-006=**A안**(웹 포함)·④~⑧ 전부 적용·ISS-009/010 진행·질의 6건 회신(L4-06 유지·L4-07 수용·L5-09 기보장·L1-09 정규화·L2-06 마커·L3-14 런북) ([issues.md](issues.md))
- [x] 계약 문서 일괄 개정(ISS-002 정의·ISS-008 CronJob 추출 계약·ISS-009 드리프트 9건·§3.4 알람 수단·L5-09 운영 수칙·L3-14 런북) — ✅ 06-11 architecture v1.1·api-spec v1.2·dmp v4 (Changelog 기입)
- [ ] **L5-10 배치 실패 파급 별도 논의** — ranking task 실패 → `send_success` 게이트 → 일일 리포트 체인 동반 중단(기존 컨벤션). 06-11 사용자 "별도 논의" 보류
- [ ] 범위·일정 확정 + 착수 지시 (S6)

## 서버 (/dev-server) — [architecture §1·§3·§4](architecture.md) / [api-spec](api-spec.md)

- [x] `HomeSkillRanking` 엔티티 + 마이그레이션 (api-spec §3 — 유니크 2종·tag `''` 정규화) — ✅ 06-11 `7dc5b7bd`
- [x] 적재 API `PUT /api/home/skill-rankings` @Airflow — 유효성(visible JOIN)·섹션 그룹별 단일 tx 교체·0건 skip 보고·멱등 (api-spec §1) — ✅ 06-11
- [x] ②랭킹 게이팅 — 플래그 2종 + Hackle 키(placeholder 0), 판정 5단, 키18 패턴 복제 (architecture §3.2) — ✅ 06-11
- [x] 랭킹 fetch(limit×2) + shape 어댑터(tagSkills 단일 그룹 / recentPurchased pinned 선두) + 빈 랭킹 AsIs 폴백·마킹 (architecture §3.3~3.4) — ✅ 06-11
- [x] 서버 배정 로그 훅(variant·fallback 포함 — winston 1차 seam, 고도화는 측정 이원화 결정 종속) — ✅ 06-11
- [x] config·플래그 상수 (api-spec §4) — ✅ 06-11
- [x] 구버전 폴백(recentPurchasedSkills) 무회귀 확인 (NFR-4 — getTabData·키18 분기 무수정) — ✅ 06-11
- [x] **코드 리뷰 수정 라운드(머지 전)** — ✅ 06-11 커밋 4건(`022887d3`·`955bea18`·`db253761`·`24bf4350`, tsc 통과·푸시): ISS-001(chatbotSeq 변환)·ISS-003(JSON 그룹 키)·ISS-004(DUPLICATE_MENU)·ISS-005(서비스 일원화 400)·ISS-006 A안(적재 OR·서빙 디바이스 분기)·L1-09 태그 정규화·L2-06 hackleError 마커·L2-05 프리뷰 로그·L3-06 STALE_PAYLOAD·L3-13 TOO_MANY_ROWS·L3-08 Redis 쿼리 캐시(60s)·L1-08 version 실값·L2-03 null 가드·L3-11 isBigTag 공유 — [리뷰](reviews/code-review-5lens-20260611.md)
- [x] 적재 에러 Slack 알림 훅 (06-11 결정) — ✅ 06-11 tx try/catch `notifyToSlack` 1회 후 rethrow(redisKey `skill-ranking-load-error` dedup), 채널 env `SLACK_SKILL_RANKING_ALERT_CHANNEL`(미설정 시 웹훅 기본 채널 — **값 등록은 사용자**), SMS 제외
- [ ] PR 재오픈/재생성 후 머지 — [hellobot-server#2444](https://github.com/thingsflow/hellobot-server/pull/2444)는 **06-12 사용자 지시로 close(머지 안 됨)**. 브랜치 `feat/popular-chart-ranking`·커밋·워크트리 전부 보존 — 재오픈/재생성 시점은 사용자 결정 대기 (리뷰·수정 라운드는 06-11 반영 완료) + 핵클 키 발급 후 config 교체 커밋

## 데이터 (/dev-data) — [architecture §1.2·§2](architecture.md)

- [ ] **실측 13항목** — ✅ 06-11 부분 완료: D-5 단위(menu_price=하트, 750원=5하트)·eval distinct(5종)·topic/intents distinct·T1 후보 수. 잔여: 교차표(T3)·시그널 SQL 대조·운영DB 덤프·SAFE_CAST 실패율 등 — data-measurement-plan §8
- [x] 랭킹 마트 `mart_home_skill_ranking` SQL + 마트 체인 등록 — 시그널·norm 분해 컬럼·computed_date 파티션 (architecture §1.2·§2) — ✅ 06-11 `e5ec4a3` (dry-run+스냅샷 프리뷰 검증, 카탈로그 동기 포함)
- [x] 섹션 바인딩 블록(5섹션 필터식) + **값 바인딩 확정** — ✅ 06-11: 사주/타로=`chatbot_content_type`(temp topic에 해당 값 부재 실측), 재회=`intents ∋ '재회'`(`|` 구분), 신규=open_date≤6개월, D-5·D-6 해소
- [ ] **칩 복합키 바인딩 4곳 기입** — 운영 칩 구성 확인 후 (SQL `section_pool` TODO — realtime=`recentPurchasedSkills`만 바인딩 완료. ⚠️ server_rdb에 칩 테이블 미수집 → BQ로 확인 불가, 어드민/운영 DB 경로 필요)
- [x] **코드 리뷰 수정 라운드(머지 전)** — ✅ 06-11 커밋 `ba10745`(dry-run 0.73GB 통과·푸시): ISS-007(base QUALIFY+skill_tag GROUP BY dedup)·ISS-002 A안 주석 정리·L4-03 rejoin TRIM·L4-04 DELETE 단일 파티션·카탈로그 동기 — [리뷰](reviews/code-review-5lens-20260611.md)
- [ ] PR 리뷰·머지 — [common-data-airflow#188](https://github.com/thingsflow/common-data-airflow/pull/188) (✅ 생성·리뷰·수정 라운드 반영 06-11 — **사용자 검토 후 머지 대기**)
- [ ] CronJob 추출+push 스크립트 — freshness guard 포함 (/dev-infra 협업, architecture §1.3)
- [ ] event-spec 작성(노출 이벤트 + section/variant 차원, CL-02) — 측정 이원화 결정 후
- [ ] 적절성 검증 쿼리 T1~T3(+T4 사전 로그) — ✅ T1 완료 06-11: base 442·사주 172·타로 182·재회 39·**신규 9⚠️**(6개월 기준 — N 조정은 기획 가변 C-2). T2·T3 후속(CL-15)
- [ ] (후속 태스크 등록) CL-04 norm 데이터 검증·알고리즘 보완 — 최종단계 (architecture §2.3)

## 인프라 (/dev-infra) — [architecture §1.3](architecture.md)

- [ ] CronJob `load-home-skill-ranking` 매니페스트(`base/hlb/cronjobs/` 선례, 12:00 KST·Slack 알림) + BQ SA 시크릿 — **개정된 architecture §1.3 기준**(guard=어제·`target_section IS NOT NULL` 술어·envelope `.data.skipped` 판독·INT64 캐스팅·`concurrencyPolicy: Forbid` L3-04)
- [ ] 서버 env `SLACK_SKILL_RANKING_ALERT_CHANNEL` 주입(값은 사용자 등록) + @Airflow 크리덴셜 내부망 제한·로테이션 runbook (L3-12 후속)

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
