# 세션 시작 컨텍스트 — YoY 하락 세그먼트 분석 후속 (`/dev-data` 용)

다른 세션에서 본 프로젝트(TODO-021 / yoy-decline-segment-analysis)의 후속 질문을 `/dev-data` 에이전트에 요청할 때 **세션 첫 메시지로 붙여넣을 컨텍스트 프롬프트**입니다. 아래 블록을 그대로 복사한 뒤 마지막 `## 이번 세션 요청` 부분에 실제 질문을 채워 넣으세요.

---

```
[배경] YoY 구매자수·매출 하락 원인 세그먼트 진단 — 1차 EDA 완료 후속 분석

## 완료된 작업 (회수 완료)

`union_mart_user_key_actions.age_group_5yr` 컬럼(2026-05-16 적용)을 활용해 4년치 YoY 매출·구매자 하락을 분해한 1차 EDA를 cmux 워크트리에서 수행 후 main 머지 완료 (PR #1).

산출물 위치 (워크스페이스 루트 기준):
- `projects/20260513-age-group-5yr/eda-by-age-group-5yr.md` (517줄) — 메인 EDA, 매출·이벤트·콘텐츠·유입·RFM·whale 6차원 + 신규/기존 + 4개년 YoY
- `projects/20260513-age-group-5yr/eda-by-age-group-5yr-app.md` (388줄) — APP-only, APP 매출 -58% 절벽, 채널 전환(APP→WEB)
- `projects/20260513-age-group-5yr/app-decline-decomposition.md` (465줄) — 매출 분해 방정식(사용자수 × 전환율 × ARPPU) + 8개 결론
- 각 .md 에 동명 .pptx 슬라이드 첨부

## 핵심 결론 (app-decline-decomposition.md TL;DR)

1. **매출 하락의 본질은 사용자 유입 감소** — 유입 50~80% 기여, 결제력 20~30%
2. Android 가 iOS 보다 1.5배 빠르게 감소 (4년 Android 사용자 -71% vs iOS -49%)
3. **Android 폭락은 2023→2024 시기 이미 시작** (사용자 -42%) — OR-FGEMF-20(2026) 보다 훨씬 이전, **다른 원인 추정**
4. 결제 전환율 단조 감소 (26-30 iOS 35% → 26%)
5. 인당 결제 횟수 단조 감소 (26-30 iOS 3.34 → 2.52)
6. **신규 구매자 감소가 기존보다 큰 폭** (26-30 신규 -70% vs 기존 -60%)
7. **whale(323K+) 비중은 오히려 증가** — 고액 결제자 견고, 일반·비결제층 더 빠르게 이탈
8. iOS·Android 하락 시점 시계열 (월별)

## 분석 베이스

- **소스 마트**: `hellobot-f445c.hlb_mart_integrated.union_mart_user_key_actions`
- **분석 기간**: 2023·2024·2025·2026 동일 30일(4-16 ~ 5-15) + 2024-01 ~ 2026-05 월별 시계열
- **누적 스캔**: ~3.5 GB
- **연령 차원**: `age_group_5yr` (13-15 / 16-20 / 21-25 / 26-30 / 31-35 / ... / 61-65 / 66+ / 정보없음, event_date 시점 기준)
- **플랫폼**: `platform IN ('IOS','ANDROID','WEB')`

## 추적 위치

- **TODO**: TODO-021 (워크스페이스 루트 `TODO.md` / 상세 `todos/TODO-021-yoy-decline-segment-analysis.md`)
- **프로젝트(추적)**: `projects/20260520-yoy-decline-segment-analysis/` (readme·status·tasks)
- **EDA 산출물 실제 위치**: `projects/20260513-age-group-5yr/` (cmux 작업 시점의 원위치 유지)

## 카탈로그 진입점 (`common-data-airflow/docs/hellobot-data/catalog/`)

- `infra-map.md` — 항상 먼저 (3분)
- `recipes/age-cohort-trend-analysis.md` — age_group_5yr 활용 패턴 (월 단위 추이·drift·decomposition)
- `recipes/feature-performance-measurement.md` — Purchase 카테고리 템플릿
- `metric-dictionary.md §1` — 구매자수·매출 기존 지표
- `tables/mart_integrated/union_mart_user_key_actions.md` — 마트 스키마 (5세 버킷 컬럼 포함)

## 합의 보류 / 추가 분석 방향 후보

본 1차 EDA 는 4년 YoY 매출·구매자 분해까지 완료. 다음 방향은 미픽스:

1. **2023→2024 Android 사용자 -42% 폭락의 원인 탐색** — 본 EDA 의 미해결 핵심 질문
2. **신규 유입 감소 세부 분해** — 유입 채널·획득 비용·앱 스토어 ASO·마케팅 캠페인 효과 등 외부 데이터 필요할 수도
3. **결제 전환율 하락 funnel 단계 분해** — 진입→상품 노출→결제 시도→완료
4. **연령 × 플랫폼 매트릭스 정밀화** — 현재 EDA 는 주요 셀 중심, 미주목 셀 보강
5. **카카오 선물하기 출시(2026-04) 가 자사 IAP 에 미친 상쇄·잠식 효과** — 외부 채널 vs 자사 결제
6. **whale 행동 변화** — 비중은 증가했지만 절대수·결제액·구성은 어떻게 변했나
7. **Looker 대시보드화** — 정기 모니터링 필요성
8. **YoY 다른 정의로 재검증** — 현재 30일 윈도우, 누적·분기 비교 시 결론 안정성

## 작업 방식 (재확인)

- **유형 A (분석 계획·이벤트 설계)**: 코드 변경 없이 설계·문서 산출
- **유형 B (파이프라인 개발)**: 신규 마트·view 필요 시 워크트리 생성
- **유형 C (데이터 조회)**: BQ dry-run → 파티션 필터 → `--maximum_bytes_billed=10737418240` 필수
- **카탈로그 갱신 프로토콜** — 새 사실·기존 표현 오류 발견 시 인지 즉시 사용자 제안

## 이번 세션 요청

{여기에 후속 질문/요청 작성. 예시:}
- "결론 3(2023→2024 Android 사용자 -42% 폭락)의 원인을 단서로 잡을 만한 데이터를 BQ에서 추가로 찾아봐줘"
- "신규 유입 감소를 channel/유입 경로별로 분해할 수 있는 마트가 있는지 확인하고, 없으면 어디서 가져와야 하는지 알려줘"
- "본 EDA 결과를 정기 모니터링 가능한 Looker 대시보드로 만들기 위한 측정 계획서를 작성해줘"
- "8번 합의 보류 항목(YoY 다른 정의로 재검증) 을 누적·분기 윈도우로 재계산해서 결론 안정성 확인해줘"
```

---

## 사용 안내

1. 새 Claude Code 세션에서 `/dev-data` 호출
2. 첫 메시지로 위 블록(```...```) 안의 내용 전체를 붙여넣기
3. 맨 아래 `## 이번 세션 요청` 의 예시 자리에 실제 질문 작성
4. `/dev-data` 가 카탈로그·EDA 산출물·TODO-021 컨텍스트 위에서 작업 시작

## 갱신 가이드

- EDA 산출물(파일 경로·줄수·결론) 이 바뀌면 본 문서의 "완료된 작업" / "핵심 결론" 섹션 갱신
- 새 분석 방향이 결정되어 "합의 보류" 항목이 픽스되면 해당 줄을 "완료된 작업" 또는 "분석 베이스" 로 이동
- 본 파일은 TODO-021 / 본 프로젝트 status 갱신과 함께 동기화 (재개 시 첫 컨텍스트 위치)
