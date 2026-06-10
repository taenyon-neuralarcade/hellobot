# 과업 목록 — 인기스킬 섹션 노출 자동화

> 상위: [readme.md](readme.md) · [requirements.md](requirements.md) · [data-measurement-plan.md](data-measurement-plan.md)
> 상태: **설계 전** — 기획(S1~S4) 완료, 아래 개발 과업은 /architect(S5) 설계 확정 후 착수

## 기획 (planning/) — 대체로 완료

- [x] 현황 파악 (S1) — [s1](planning/s1-current-state.md)
- [x] 개념 구조 확정 (S2) — [s2](planning/s2-concept-model.md)
- [x] 랭킹 정의 (S3) — [s3](planning/s3-ranking-definition.md)
- [x] 필터링/태깅 정의 (S4) — [s4](planning/s4-filtering-tagging.md)
- [x] PRD·요구사항·측정계획 산출 (readme/requirements/data-measurement-plan)
- [x] 기획 피드백 반영(C-1·C-2·D-1~7, 1차 5섹션) — readme/requirements/dmp 갱신
- [ ] MWAA 현황 파악(TODO-042) → 배치 위치(D-7) 결정
- [ ] 기획 확인: Phase A(β 원문 재확인)
- [ ] /architect 기술 설계 (S5: architecture.md, api-spec.md)
- [ ] 범위·일정 확정 + 프로젝트화 결정 (S6)

## 서버 (/dev-server)

- [ ] **통합 필터 정의 레이어** 설계·구현 — 기본 풀 조건(base, 미확정·D-5) ∧ 섹션 술어 + 랭커 바인딩(1차 5섹션, FR-F0/F1/F6)
- [ ] 랭킹 결과 **적재 대상 테이블**(`섹션→[menu_seq,rank,score]`) 신설 + 적재 경로(FR-B2)
- [ ] **랭커 추상화**(AsIs/PopularityScore v1) 인터페이스 + variant 주입점(FR-R1/R2, FR-AB1/AB2)
- [ ] `featuredSkillsTabs` 결합 — `showRanking`→`ranker_id` 일반화 검토, 2종 목록 서빙(FR-API1/2/3)
- [ ] 구버전 폴백(recentPurchasedSkills) 유지(NFR-4), 배치 실패 폴백(NFR-2)

## 데이터 (/dev-data)

- [ ] **실측 13항목**(distinct 값·커버리지·교차표·후보 수·SQL 대조·eval distinct·매출분리·SAFE_CAST·운영DB 덤프·**출시일 open_date 커버리지(D-6)·현행 지금인기 필터조건(D-5)**) — data-measurement-plan §8
- [ ] event-spec 작성(노출 이벤트 + section/ranker 차원, CL-02) — /dev-data
- [ ] 스킬별 일배치 지표 마트 + `popularity_score`·rank 산출(FR-B1, BQ)
- [ ] 섹션별 필터→랭킹 결과 산출 + 서비스 DB 적재(reverse-ETL, FR-B2)
- [ ] 적절성 검증 쿼리 T1~T3(+T4 사전 로그) (FR-V1~V4)
- [ ] 섹션 필터 **값 바인딩 확정**(1차 5섹션·FR-F7) + **출시일 `mart_skill_open_date_se` 적용**(D-6) + **기본 풀 조건 현행 확인**(D-5)

## 인프라 (/dev-infra)

- [ ] 배치 스케줄·트리거 위치(common-data-airflow vs MWAA vs K8s) — **MWAA 현황 파악(TODO-042) 후 S5 확정**(D-7)(FR-B3/B4)

## 웹 (/dev-web) · iOS (/dev-ios) · Android (/dev-android)

- [ ] **(필수, CL-02)** 측정 이벤트 신규 발화 — **노출(impression) 이벤트 신규 + `(targetSection, targetSectionTag)` 식별자 + `ranker_id(variant)` 차원**. 소급 불가 → 늦어도 B 적재·노출과 동시 배포. event-spec 선행.
- [ ] 1차는 기존 featuredSkillsTabs 컨테이너 소비 유지(FR-API4)

## 스튜디오 (/dev-studio)

해당없음

## QA (/qa)

- [ ] 테스트 케이스 작성 (qa-test-cases.md) — 자동화 목록 정합·폴백·적절성
- [ ] 테스트 수행 및 결과 기록

## 의존 관계

- 데이터 실측(§8) → 섹션 필터 값 바인딩 확정 → 후보 풀 검증(T1)
- /architect 설계(S5) → 서버·데이터 구현 착수
- 서버 적재 테이블 확정 → 데이터 reverse-ETL 착수
- A/B 버킷팅은 **이번 범위 밖**(알고리즘 적용 이후 별도 단계) — variant 주입점만 구현
- 클라이언트 이벤트는 event-spec 도입(측정 필요) 시에만
