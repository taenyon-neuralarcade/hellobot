# 홈탭 Phase #2 — 실행 스텝 (개괄)

> 대상: 인기스킬 섹션 노출 자동화 = **필터링 + 랭킹**
> 마감: **6/5 (금)** — 기획 구체화 + 개발 설계 단계까지
> 작성: 2026-06-03 · 갱신: 2026-06-04 (S1 완료 반영)
> TODO 추적: [TODO-012](../../../todos/TODO-012-home-tab-phase2.md)
> 기획 도출(planning): [overview-notes.md](overview-notes.md) · [s1](s1-current-state.md) · [s2](s2-concept-model.md) · [s3](s3-ranking-definition.md) · [s4](s4-filtering-tagging.md) · [s5(윤곽)](s5-architecture-outline.md) · [s5 현행분석](s5-asis-serving-analysis.md) · [s5 구현감사](s5-asis-implementation-audit.md)
> **설계 전 계약 문서(S4 후 종합, 프로젝트 루트)**: [readme.md(PRD)](../readme.md) · [requirements.md](../requirements.md) · [data-measurement-plan.md](../data-measurement-plan.md) · [tasks.md](../tasks.md) · [status.md](../status.md)
> **설계 계약 문서(S5 산출, 2026-06-10)**: [architecture.md](../architecture.md) · [api-spec.md](../api-spec.md)
> 진행 방식: **전체 스텝을 먼저 잡고, 한 스텝씩 구체화**

---

## 핵심 개념 (사용자 temp.md 기준)

- **노출 자동화 = 필터링 + 랭킹**
  - **랭킹** = 전 스킬에 점수를 매겨 순서를 만드는 로직 (현재 방향: **1종**). → "인기차트 선정 로직" 기획 문서가 이 파트
  - **필터링** = 콘텐츠 메타(카테고리·관심사 topic·의도 intents)로 섹션별 들어갈 스킬을 거름
- **이번 구현 대상 = 인기스킬 섹션** — 여러 필터링된 스킬 목록을 담는 노출 섹션. 참조: PR #2414
- 현 상태: 운영자 수작업 세팅 → 모든 유저 고정 노출. 이걸 매일 랭킹 계산 기반 자동화로 전환
- 섹션 예시: 실시간 인기 · 신규 인기 · 사주 · 타로 · 1:1 상담 · 솔로 애정운 · 짝사랑/썸 · 커플 궁합 · 재물운 · 커플 결혼 궁합 · 재회 · 솔로 결혼운

---

## 전체 스텝 (한 스텝씩 구체화)

| # | 스텝 | 상태 | 한 줄 정의 | 핵심 질문 (구체화 시) |
|---|------|------|-----------|----------------------|
| **S1** | 현황 파악 (As-Is) | ✅ 완료 ([s1-current-state.md](s1-current-state.md)) | 인기스킬 섹션이 지금 어떻게 채워지나 | (완료) PR #2414=노출 컨테이너 골격, 섹션은 수동 큐레이션, topic/intent 메타 부재 |
| **S2** | 개념 구조 확정 | ✅ 완료 ([s2-concept-model.md](s2-concept-model.md)) | "랭킹 1종 + 섹션별 필터링" 모델이 맞는가 | (완료) 섹션=필터+랭커(교체전략). A/B=랭커 선택(AsIs/v1), 유저버킷·일괄, 키18과 별도·순차(A/B 구현은 후속). 다중랭커 비파괴 추상화 |
| **S3** | 랭킹 정의 | ✅ 완료 ([s3-ranking-definition.md](s3-ranking-definition.md)) | 스킬 점수화·순서 로직 | (완료) 공식 확정(평점=긍정비율 재정의), A=서버순서, 계산 common-data-airflow/적재 서버위임. 기획자 확인 잔존(가중치·조회정의·PhaseA) |
| **S4** | 필터링/태깅 정의 | ✅ 1차 설계 ([s4-filtering-tagging.md](s4-filtering-tagging.md)) | 섹션을 채우는 메타 체계 | (1차) 필터=3축그룹(시간성/주제/의도+대상), 섹션 7/12=의도(+대상)가 본체. 섹션→필터 규칙 신규설계(값 바인딩은 /dev-data 실측). 적절성=사전3종(커버리지·정합·태그품질)+행동/AB. **DF-S4-1(임시태그 승격 vs 공식카테고리 흡수) 결정대기** |
| **S5** | 아키텍처 설계 | ✅ 완료 ([s5](s5-architecture-outline.md)·[감사](s5-asis-implementation-audit.md)·**[architecture](../architecture.md)·[api-spec](../api-spec.md)**) | 위 3가지를 어떻게 구현·관리 | (완료 06-10) 5레이어 세부 확정 — `home_skill_ranking`(K30)+적재 PUT+CronJob 12시, percentile×전체풀·가용일수 분모, 3군 ②게이팅 5단+fetch 교체 어댑터+폴백, 신규 설계 결정 8건(architecture §8). 선행 확인·잔여 실험 결정은 architecture §9 |
| **S6** | 범위·일정·프로젝트화 | ⬜ | 이번 스펙 범위 확정 + 착수 준비 | 영향 리포·일정, 프로젝트 승격(이 폴더) |

> 흐름: S1 → S2 위에서 **S3(랭킹)·S4(필터)** 병렬 → S5가 통합 → S6.
> **S4 필터링/태깅이 분석 무게중심** (S1에서 topic/intent 전용 메타 부재 확인됨).
> **S4 완료 후 (2026-06-05)**: S1~S4 결정을 **설계 전 계약 문서**(PRD·요구사항·측정계획·과업·상태, 프로젝트 루트)로 종합 — /architect(S5)가 planning/ 대신 이 문서들을 참조.

---

## 데이터 분석으로 검증할 가설 (S4 입력)

이전 분석상 "필터링 = 유저가 원하는 콘텐츠를 쉽게 찾게 거르는 것"
- 사주 유저 → 사주 콘텐츠 / 타로 유저 → 타로 콘텐츠
- 관심사 매핑: 연애→연애 · 결혼→결혼/연애 · 재물→재물 · 가족→가족
- **현재 태깅한 필터링이 적절한가?** (검증 대상)

---

## 진행 방식

1. 스텝 골격 합의 → **한 스텝씩 구체화**. 각 스텝 종료 시 전체 스텝 표 재확인 + 다음 단계 안내.
2. 결정/진행은 [TODO-012 상세](../../../todos/TODO-012-home-tab-phase2.md) 로그에 누적.

> 이전 검증항목(C1~C5)·결정요소(D-A~E)·문서이슈는 S3~S5 구체화 시 재사용:
> C(데이터·파이프라인)→S3·S5, D-A(태깅 체계)→S4, D-B~E(개인화·국가·오버라이드·노출위치)→S2·S5, 문서이슈(가중치·Phase A)→S3.
