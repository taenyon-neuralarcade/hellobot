# 개발 상태

> 상위: [readme.md](readme.md) · 추적: [TODO-012](../../todos/TODO-012-home-tab-phase2.md)

## 현재 상태: S5 아키텍처 — 윤곽 단계 (세부 설계 전)

S1~S4 + 계약 문서 → 적대적 리뷰·메타리뷰 → 결정 라운드(14건) → 기획 피드백 반영(2026-06-06, C-1·C-2·D-1~D-7, **1차 5섹션 확정**) → 정합성 점검(2026-06-06) → **S5 윤곽 작성(2026-06-08, [planning/s5-architecture-outline.md](planning/s5-architecture-outline.md))**: 5레이어(계산·적재·랭커추상화·서빙·측정) 구분. **현행 재분석(2026-06-08, dev-server+dev-android, PR #1128)**: 통합 칩 컨테이너 `featuredSkillsTabs` **이미 LIVE**(서버05-21/앱2.43.0) — CL-03 캡처 불요, **B = `fetchSkillListBySectionType`(home.ts L540) 정렬 주입, 앱 무변경**. **다음 = /architect 세부 패스(architecture.md·api-spec.md)**. 리뷰·결정로그: [reviews/](reviews/).

## 파트별 현황

| 파트 | 상태 | 브랜치 | 워크트리 | 비고 |
|------|------|--------|---------|------|
| 기획 | 진행중 | - | - | S1~S4 + 계약 문서 + 기획 피드백 반영(v2/v3) 완료. β 재확인·MWAA 파악 잔존 |
| 서버 | 대기 | - | - | S5 설계 후 착수 (필터 레이어·적재·랭커·API) |
| 데이터 | 대기 | - | - | 실측 5항목 선행 가능(인증 복구 시) + 마트·적재 |
| 인프라 | 대기 | - | - | 배치 위치 S5 확정 후 |
| 웹 | 조건부 | - | - | 측정 이벤트 필요 시만 |
| iOS | 조건부 | - | - | 측정 이벤트 필요 시만 |
| Android | 조건부 | - | - | 측정 이벤트 필요 시만 |
| 스튜디오 | 해당없음 | - | - | |
| QA | 대기 | - | - | 설계 확정 후 케이스 작성 |

## 미결 / 후속 (기획 피드백 반영 후 2026-06-06)

- ⚪ **S5 설계 위임** — CL-04(norm 방식·모집단)·CL-08(신규 섹션 랭킹). **CL-03 정정(2026-06-08)**: `featuredSkillsTabs` LIVE 확인 → A 캡처 불요, B=`fetchSkillListBySectionType`(home.ts L540) 정렬 주입(앱 무변경). 상세 [planning/s5-asis-serving-analysis.md](planning/s5-asis-serving-analysis.md).
- 🟣 **실측 후속**(BQ 인증 + 운영 DB 덤프) — 섹션 태그 값 바인딩·시그널 SQL 대조·eval distinct 등 11항목(dmp §8). architecture 골격은 비블로킹(R5).
- 📋 **β Phase A** — 기획 원문 재확인만 대기(골격 불변).
- 🔵 **CL-02 측정 이벤트** = MUST 확정(노출+variant 신규), event-spec로 B 출시와 동시 배포.
- 🔵 **배치 위치(D-7)** — 조사 완료(TODO-042). **제안: 컴퓨트=common-data-airflow / 리버스-ETL=서버 소유 write + 스케줄러 트리거(K8s CronJob 권장)**. 확정=S5.
- 🟣 **base 단위 바인딩**(D-5) — base = 오리지널∧750원↑ **확정**, 750원을 BQ 마트 가격 필드 단위(원 vs 하트)로 환산만 /dev-data.
- 📋 **커플/솔로 등 7섹션 = 최종단계**(적합 태깅 부재).

## 확정 사항

| 항목 | 내용 |
|------|------|
| 개념 모델 | 섹션 = 필터(후보 풀) + 랭커(교체 전략) |
| 랭커 | 2종 — A(AsIs=현행 산출 전체·C-1), B(PopularityScore v1) |
| 필터 모델 | 기본 풀 조건(오리지널∧750↑ 확정) ∧ 메타축(content_type/intents), **1차 5섹션**(실시간·신규·사주·타로·재회) |
| 태그 소스 | 하이브리드 — 1차 임시 태그 그대로, 정식 승격 후속 (DF-S4-1) |
| A/B | 유저 버킷·일괄, 버킷팅 구현은 이번 범위 밖(주입점만) |
| **섹션 매핑** (CL-01✅) | N:1 복합키 `(targetSection, targetSectionTag)`, 신규타입 불요 |
| **노출 슬롯 N** (CL-05✅) | vertical 7 / horizontal 8 (layout 구동) |
| **A 랭커 정의** (C-1) | 현행 live = `featuredSkillsTabs`(LIVE)의 `fetchSkillListBySectionType` 순서(태그=priority/recent=recency). B는 별도 base∧섹션 풀을 점수순 — A와 후보풀 비공유 유지 |
| **현행 컨테이너** (2026-06-08✅) | `featuredSkillsTabs` 칩 컨테이너 **이미 LIVE**. ①컨테이너 A/B=Hackle키18(legacy recent↔featured) / ②랭킹 A/B=이 프로젝트(미착수). B 주입=`fetchSkillListBySectionType` 정렬, **앱 계약 무변경** |
| **신규 기준** (C-2) | 출시일 `open_date`(`mart_skill_open_date_se.event_date`) — 섹션 ≤6개월(가변)·부스트 30일 |
| **기본 풀 조건(base)** | **오리지널 ∧ 750원↑** 확정. 단위 바인딩(원 vs 하트)만 /dev-data(D-5) |
| **1차 섹션 범위** | 5섹션(실시간·신규·사주·타로·재회), 커플/솔로 등 7섹션 최종단계 |

## 잠정 방향 (S5/구현 전 확정 — 확정 아님)

| 항목 | 잠정 | 확정 시점 |
|------|------|----------|
| 랭킹 공식 | **6항목 확정·α 확정·매출 포함 수용** — `norm` 방식·모집단만 S5 위임 | CL-04(S5) |
| 배치 적재 주체 | 서버 위임(컨벤션) 방향 | S5(FR-B3) |
| 배치 실행 위치 | **컴퓨트=common-data-airflow / 리버스-ETL=서버 소유 write + 스케줄러(K8s CronJob 권장)** (제안) | S5 토폴로지 확정(D-7) |
| 배치 타이밍 | D+1 일배치 | S5(FR-B4) |
| 필터 운영 형식 | 운영 편집형(데이터화) | S5(DF-S4-3) |
