# 과업 목록 — YoY 하락 세그먼트 분석

> 📌 **1차 EDA 완료 (2026-05-16~)** — 산출물은 인접 프로젝트 [`projects/20260513-age-group-5yr/`](../20260513-age-group-5yr/) 에 위치 (cmux 워크트리 → main PR #1 머지).
> - `eda-by-age-group-5yr.md` — 6차원 × 신규/기존 × 4개년 YoY 분해
> - `eda-by-age-group-5yr-app.md` — APP-only, APP 매출 -58% + 채널 전환(APP→WEB)
> - `app-decline-decomposition.md` — 매출 분해 방정식 + 8개 결론 (TL;DR)
>
> 본 프로젝트 Phase 0~5 는 1차 EDA 로 갈음되며, 후속 분석 A·B·E (Phase 6~8) 가 다음 작업 단위입니다.

## 데이터 (/dev-data) — 분석 전용

### Phase 0~5 (1차 EDA 로 완료)

- [x] Phase 0 — 스코프 합의 (5세 × 플랫폼 × 신규/기존, 30일 윈도우)
- [x] Phase 1 — 카탈로그 진입 (infra-map · recipes · metric-dictionary · tables 매핑)
- [x] Phase 2 — 측정 계획 (1차 EDA 산출물에 통합 기록)
- [x] Phase 3~4 — 1차 분석 쿼리 + 가설 검증 (H1~H4 결과는 1차 EDA TL;DR 참조)
- [x] Phase 5 — 보고 산출 (.md + .pptx)

### Phase 0 (원본) — 스코프 합의 (이력 보존)

- [x] YoY 비교 기간 결정 (동월 30일 윈도우: 4-16~5-15, 4개년 비교)
- [x] 매출 정의 결정 (총 결제액 KRW, `revenue_krw` 표준)
- [x] 구매자수 정의 결정 (결제 trx 발생 unique user + 신규/기존 분리)
- [x] 플랫폼 분류 기준 결정 (`platform IN ('IOS','ANDROID','WEB')`)
- [x] 산출 형태 결정 (1차: .md + .pptx, 2차: Looker 화는 별도 의사결정)

### Phase 1 — 카탈로그 진입 (스코프 픽스 후)

- [ ] `common-data-airflow/docs/hellobot-data/catalog/infra-map.md` 1차 읽기 (3분, 핵심 테이블 10선·이벤트 그룹·지표 도메인)
- [ ] `recipes/feature-performance-measurement.md` — Purchase 카테고리 템플릿 진입 (4 하위 타입 중 IAP 위주)
- [ ] `metric-dictionary.md §1 도메인별 인벤토리` — 구매자수·매출 기존 지표 매칭
- [ ] `mart-catalog.md` Purchase 도메인 — 구매자/매출 그레인 마트 식별
- [ ] `recipes/age-cohort-trend-analysis.md` — 월 단위 추이 패턴 참고
- [ ] `tables/{식별된 마트}.md` — 컬럼·lineage·dbt 매핑 확인 (특히 `age_group_5yr` · 플랫폼 필드 보유 여부)

### Phase 2 — 측정 계획 작성

- [ ] `data-measurement-plan.md` 작성
  - [ ] 지표 정의 (구매자수·매출 — 합의된 정의)
  - [ ] 산식 (매출 환산 규칙 `KRW_PER_HEART = 150` 적용 여부 포함)
  - [ ] 소스 매핑 (어떤 마트 어떤 컬럼)
  - [ ] 세그먼트 차원 정의 (`age_group_5yr` 버킷 13개 + 플랫폼 분류)
  - [ ] 시계열 cohort 설계 (event 시점 분류 vs cohort 시점 재계산)

### Phase 3 — 1차 분석 쿼리

- [ ] BQ dry-run 으로 스캔 비용 측정 (`--maximum_bytes_billed=10737418240`)
- [ ] 쿼리 1: 월별 구매자수·매출 (`age_group_5yr` × 플랫폼)
- [ ] 쿼리 2: YoY 동기 대비 변동률 매트릭스
- [ ] 쿼리 3: 셀별 기여도 (절대 감소 × 셀 비중)
- [ ] 쿼리 4 (확장 — 신규/재결제 분해 스코프이면): 신규 vs 기존 분해

### Phase 4 — 가설 검증

- [ ] H1 (특정 연령 버킷 집중) 확인 — 하락 기여도 상위 5개 셀
- [ ] H2 (플랫폼별 차등) 확인 — 플랫폼별 마진 비교
- [ ] H3 (신규 유입 감소) 확인 — 신규 vs 재결제 분해
- [ ] H4 (카카오 출시의 자사 IAP 상쇄 여부) 확인 — 2026-04 전후 비교

### Phase 5 — 산출 (스코프 결정 후)

- [ ] (선택) Looker 대시보드: 매트릭스 뷰 + 시계열 드릴다운
- [ ] (선택) 노션 리포트: 진단 결과 + 권고 액션 카드
- [ ] 카탈로그 갱신 — 신규로 발견한 사실/이슈가 있으면 SSOT 반영 (CLAUDE.md §카탈로그 갱신 프로토콜)

### 후속 (발견 시 별도 과업)

- [ ] 분석 결과 신규 이벤트·마트 필요성이 도출되면 별도 프로젝트로 분리
- [ ] 정기 모니터링이 필요해지면 KPI 리포트/알림 DAG 화

---

## 추가 분석 — 1차 EDA 후속 (2026-05-20 결정)

1차 EDA TL;DR 8개 결론이 답을 *유입(50~80%)* 과 *결제력(20~30%)* 두 축으로 좁혔으나, **"왜 신규가 -70% 감소했는가"** 와 **"Android 2023→2024 -42% 폭락의 정체"** 가 미해결. 다음 3개 분석을 각각 디테일하게 진행.

### Phase 6 (A) — Activation Funnel 분해

**핵심 질문**:
- Q-A1. 신규 -70% 손실이 *유입(install/first_open) 자체 감소* 인지 *activation 단계 conversion 감소* 인지
- Q-A2. 단계별 drop-off rate 가 5세 × 플랫폼별로 다른가
- Q-A3. 가입 코호트 시점(2023~2026 월별) 의 *7일 retention curve* 가 약화되는가

**과업**:
- [ ] A-1. 카탈로그 진입 점검 — `mart_user_daily_info.is_new_user` 정의 (전체 생애 첫 일자 vs 윈도우 첫 일자) 확인
- [ ] A-2. funnel 단계 매핑 확정 — first_open → view_home_main(D+1) → enter_skill(D+7) → pay_for_*(D+30)
- [ ] A-3. BQ dry-run — 4년 동일 30일 코호트 × 5세 × 플랫폼 (예상 5~8 GB)
- [ ] A-4. 쿼리 실행 — 단계별 conversion 매트릭스 + 7-day retention curve
- [ ] A-5. caveat 검증 — `first_open` 의 재설치 reset 영향 (동일 user_pseudo_id 의 first_open 횟수 분포)
- [ ] A-6. 산출 — funnel chart 4년 overlay + drop-off rate 매트릭스 + retention curve

### Phase 7 (B) — Android 2023→2024 -42% 폭락 원인 좁히기

**핵심 질문**:
- Q-B1. 모든 app_version 에서 일어났나, 특정 신버전 출시 이후인가 (= 내부 product 회귀 신호)
- Q-B2. Android 14 출시(2023-10) 와 시점이 겹치는가, OS 버전 분포 이동은
- Q-B3. install_source (organic / play_store / other) 비중이 무너졌나
- Q-B4. 같은 시기 crash rate / ANR 이 튀었나
- Q-B5. Target SDK 33 강제(2023-08) 의 영향이 본질인지 노이즈인지

**과업**:
- [ ] B-1. 선처리: `infra_android_crash` / `infra_android_os_version` DAG 산출 BQ 테이블 위치 확인 (DAG 소스 직접 확인 + 카탈로그 보강 후보)
- [ ] B-2. 월별 Android 신규/active × `app_info.version` (top 5 + 기타) 쿼리 — 변곡점 식별
- [ ] B-3. 월별 Android 신규/active × `device.operating_system_version` major (Android 13/14/15)
- [ ] B-4. 월별 crash rate / ANR 시계열 (B-1 산출물 활용)
- [ ] B-5. install_source 분포 (`traffic_source.*`) 4년 추이
- [ ] B-6. 첫 세션 이탈률 (first_open → 익일 return) 시계열
- [ ] B-7. 자사 앱 변경 이벤트 매핑 — `hellobot_android` 리포 2023~2024 git tag/CHANGELOG 와 변곡점 정렬
- [ ] B-8. 외부 확인 필요 항목 정리 → `external-tasks.md` 등록 (Play Console install/uninstall, Play 정책 캘린더)
- [ ] B-9. 산출 — 변곡점 정렬표 + 다층 시계열 차트 (사용자 + app_version stack + OS stack + crash line)

### Phase 8 (E) — 콘텐츠 fit drift

**핵심 질문**:
- Q-E1. 5세 연령대별 *top-10 결제 스킬* 이 4년간 얼마나 바뀌었나 (drift 정량화)
- Q-E2. 신규 스킬(첫 등장일 < 1년) 매출·이용자 점유율이 줄고 있나
- Q-E3. 카테고리 mix (사주/타로/MBTI/심리/기타) 가 연령대별로 어떻게 이동했나
- Q-E4. 동일 코호트의 N차 결제가 신규 스킬로 흐르는가, 같은 스킬 재결제인가 (saturation 신호)

**과업**:
- [ ] E-1. 카탈로그 진입 점검 — `mart_fixed_menu_server.category` 분류 정형화 여부 (`tables/mart/mart_fixed_menu_server.md`), 무료 텍스트면 carrier mapping 정의
- [ ] E-2. `union_mart_user_key_actions` 의 pay 액션 필터 정확 정의 (pay_for_contents / pay_for_package / 구독 / 외부쿠폰 합산 규칙)
- [ ] E-3. AI 챗봇 / 일반 스킬 / 패키지 / 구독 구분 컬럼 매핑
- [ ] E-4. BQ dry-run — 4년 동일 30일 × 5세 × 카테고리 매출 mix (예상 4~6 GB)
- [ ] E-5. Drift 매트릭스 — 5세 × 카테고리 매출 점유율 4년 overlay (ΔP 산출)
- [ ] E-6. 신규 스킬(< 1년) 매출·이용자 점유율 시계열
- [ ] E-7. 연령대별 top-10 스킬 4년 비교표 (Rank stability index)
- [ ] E-8. 동일 코호트 N차 결제 mix (1차→2차→3차 결제가 동일 스킬 vs 신규 스킬)
- [ ] E-9. 산출 — drift 매트릭스 + 신규 스킬 점유율 시계열 + saturation 신호 표

## 의존 관계

- Phase 0~5 (1차 EDA) → 후속 분석 분기 결정 (완료)
- Phase 6 (A) · Phase 7 (B) · Phase 8 (E) — **독립 진행 가능** (서로 다른 마트·이벤트 사용)
- Phase 7 (B) B-1 (`infra_android_crash` 위치 확인) → B-4 (crash 시계열) 선후 의존
- Phase 8 (E) E-1·E-2·E-3 (카탈로그 확인) → E-4 이후 쿼리 선후 의존
- 세 분석 결과 → 신규 이벤트·마트 필요성 도출 시 별도 프로젝트 분리 (후속 섹션)

## 우선 추천 순서

1. **Phase 6 (A)** — 가장 답의 밀도가 높음. 유입 vs activation 분리가 D(채널) E(콘텐츠) 우선순위를 재정렬
2. **Phase 7 (B)** — 미해결 핵심 질문 + 외부 확인 필요 항목 빠르게 분리
3. **Phase 8 (E)** — whale 결론 보완 + 콘텐츠 의사결정 근거
