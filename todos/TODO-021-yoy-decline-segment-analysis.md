---
id: TODO-021
title: 구매자수·매출 YoY 하락 원인 — 5세 연령 × 플랫폼 세그먼트 분석
유형: 프로젝트로 추적
상태: 진행 중
등록: 2026-05-20
시작: 2026-05-20
완료: -
마감: -
담당: /dev-data
관련: projects/20260520-yoy-decline-segment-analysis/
---

# TODO-021 구매자수·매출 YoY 하락 원인 — 5세 연령 × 플랫폼 세그먼트 분석

## 컨텍스트

**사용자 요청 (2026-05-20)**:
> 서비스 구매자수, 매출 지표 연간(YoY) 하락 원인을 세부 5세 연령별 세그먼트, 플랫폼 단위 세부 분석하는 TODO 하나 추가하고, 프로젝트 추가해줘.

**배경**:
- 서비스 핵심 지표(구매자수·매출)가 YoY 하락 추세로 의심됨 — 원인을 세그먼트 차원으로 분해해 진단 필요
- 5세 연령 버킷(`age_group_5yr`)이 [age-group-5yr 프로젝트](../projects/20260513-age-group-5yr/)에서 2026-05-16 적용 완료. 본 분석은 그 자산을 1차 활용처로 삼음
- 플랫폼 차원(iOS / Android / Web) 교차로 하락이 특정 (연령 × 플랫폼) 셀에 집중되어 있는지 확인

**연결 자산**:
- `union_mart_user_key_actions.age_group_5yr` (13-15 / 16-20 / 21-25 / 26-30 / 31-35 / 36-40 / 41-45 / 46-50 / 51-55 / 56-60 / 61-65 / 66+ / 정보없음) — event_date 시점 기준
- 매출/구매자 그레인의 마트(예: `mart_purchase_*`, `union_mart_*` IAP 계열) — 카탈로그 진입 시 식별
- 월간 추이 분석 recipe `age-cohort-trend-analysis.md` (age-group-5yr 프로젝트 산출물)

## 현재 상태

1차 EDA 완료 (산출물은 `projects/20260513-age-group-5yr/` — cmux 워크트리 → main PR #1 머지). 핵심 결론은 [프로젝트 status.md §1차 EDA 핵심 결론](../projects/20260520-yoy-decline-segment-analysis/status.md) 8개 항목.

후속 분석 방향 사용자와 합의 완료 (2026-05-20):
- **Phase 6 (A) Activation Funnel 분해** — 신규 -70% 가 유입 vs activation 어디서 새는지
- **Phase 7 (B) Android 2023→2024 -42% 폭락 원인** — 외부 OS/스토어 vs 내부 product 분리
- **Phase 8 (E) 콘텐츠 fit drift** — 5세 × 카테고리 매출 mix 변화, 신규 스킬 점유율, saturation

세 Phase 의 디테일 과업은 `projects/20260520-yoy-decline-segment-analysis/tasks.md §추가 분석` 에 기록. 우선 추천 순서 A → B → E.

## 다음 단계

- [ ] 다음 `/dev-data` 세션에서 Phase 6 (A) 착수
  - A-1 카탈로그 진입 점검 (`mart_user_daily_info.is_new_user` 정의 확인)
  - A-2 funnel 단계 매핑 확정
  - A-3 BQ dry-run (예상 5~8 GB)
  - A-4 쿼리 실행 + 5세 × 플랫폼 × 코호트 단계별 conversion 매트릭스
  - A-5 first_open 재설치 reset caveat 검증
  - A-6 산출 — funnel chart 4년 overlay + retention curve
- [ ] Phase 7 (B) 착수 전 선처리 — `infra_android_crash` / `infra_android_os_version` DAG 산출 BQ 테이블 위치 확인 (카탈로그 보강 후보)
- [ ] Phase 8 (E) 착수 전 선처리 — `mart_fixed_menu_server.category` 정형 분류 여부 확인

## 진행 로그

- 2026-05-20 — TODO-021 등록 + 프로젝트 `projects/20260520-yoy-decline-segment-analysis/` 스켈레톤 생성. 분석 스코프 합의 대기 상태.
- 2026-05-20 (오후) — 1차 EDA 완료 (`projects/20260513-age-group-5yr/` 에 산출물 3종 + .pptx, cmux PR #1 머지). 후속 분석 방향 협의 — 사용자와 A·B·E 3개 진행 합의. 카탈로그 갱신 필요 사항 없음 확인. 프로젝트 tasks.md 에 Phase 6·7·8 + 세부 과업 반영, status.md 에 1차 EDA 결론 8개 + 마일스톤 갱신. 시작일 2026-05-20 으로 갱신.
