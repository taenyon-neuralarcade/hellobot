# 기술 아키텍처 — 인기스킬 섹션 노출 자동화 (홈탭 Phase #2)

> 작성: 2026-06-10 (/architect 세부 패스) · 상태: **v1.1** (2026-06-11 5렌즈 리뷰 반영 개정 — Changelog 참조)
> 상위: [readme.md(PRD)](readme.md) · [requirements.md](requirements.md) · [status.md](status.md) · API 계약: **[api-spec.md](api-spec.md)** (이 문서와 동기)
> 선행(윤곽·현행): [s5-architecture-outline.md](planning/s5-architecture-outline.md) · [s5-asis-implementation-audit.md](planning/s5-asis-implementation-audit.md)(A 정의·seam) · [s5-asis-serving-analysis.md](planning/s5-asis-serving-analysis.md)
> 실험 설계(3군): [ab-test-po-review.md](planning/ab-test-po-review.md) · [ab-test-analysis-design.md](planning/ab-test-analysis-design.md)
> ⚠️ **계약 문서** — 수정 시 하단 Changelog 필수. 확정값(결정 로그 [reviews/00 §A-6](reviews/00-meta-review-and-checklist.md))을 입력으로 세부만 채운 문서이며, 확정값 자체의 번복은 결정 로그 경유.

---

## 0. 전체 구조

```
[BQ 시그널 마트]  mart_use_skill_se · mart_v2_skill_funnel_fb · mart_fixed_menu_evaluation_server
                 · mart_skill_open_date_se · mart_fixed_menu_server · google_sheet_sync.taenyon_temp_skill_tag_info_v2
      │
      ▼  ① 계산 (common-data-airflow, BQ) ······························· §2
  base 필터 → 점수 1회 산출(전체 base 풀, percentile norm) → 섹션 필터 → 섹션별 rank → 상위 K
      │   산출물 = BQ 랭킹 마트 (computed_date 파티션 = 이력 보존)
      ▼  ② 적재 (리버스-ETL, D-7 확정 토폴로지) ··························· §1
  K8s CronJob(추출+push, 12:00 KST) ──PUT──► hellobot-server @Airflow API ──► PG home_skill_ranking (트랜잭션 교체, 최신만)
      │
      ▼  ③ variant 판정 + 후보 fetch 교체 (hellobot-server) ··············· §3
  lazy 칩 요청 → ②랭킹 게이팅(신규 키, C-A만) → 랭킹 테이블 조회 → 기존 섹션 shape 어댑터
      │                                          └ 비대상/빈 랭킹 → AsIs fetch (현행 그대로)
      ▼  ④ 서빙 (계약 무변경) ············································ §4
  visibility 정형화 → cap+hasMore → 응답 {section,data,fixedMenus,chatbots,hasMore} → 앱 index 뱃지
      │
      ▼  ⑤ 측정 ·························································· §5
  서버 배정 로그(판정 훅) + Hackle 노출 + 클라 이벤트(CL-02, event-spec 별도 트랙)
```

**3군(L / C-M / C-A)과의 대응** — L·C-M은 **전부 현행 코드 그대로**(변경 0). 이 문서가 새로 만드는 것은 C-A 한 갈래뿐:

| 군 | 경로 | 이 설계에서 |
|---|---|---|
| **L** (기존) | legacy `recentPurchasedSkills` 단일 리스트 | 무변경 (키18 게이트가 기존처럼 분기) |
| **C-M** (칩+수동) | featuredSkillsTabs + AsIs fetch | 무변경 (②키 미당첨/실패/킬스위치의 기본값) |
| **C-A** (칩+랭킹) | featuredSkillsTabs + **랭킹 테이블 fetch** | §1~§4 신규 |

---

## 1. ② 랭킹 산출물 + 리버스-ETL (구조 척추)

### 1.1 PG 랭킹 테이블 — `home_skill_ranking` (서버 소유)

행 = "이 칩 복합키에서 이 스킬이 몇 위" (최신 1세대만, 이력은 BQ 마트):

| 컬럼 | 타입 | 의미 |
|---|---|---|
| `seq` | PK | TypeORM 컨벤션 |
| `rankerId` | varchar, default `popularity_v1` | 랭커 식별 — **다중 랭커 확장 seam**(FR-R7/NFR-6). v1은 상수 |
| `targetSection` | varchar NOT NULL | 칩 복합키 1축 (FR-API6, 칩 테이블과 동일 도메인) |
| `targetSectionTag` | varchar NOT NULL DEFAULT `''` | 칩 복합키 2축 (tagSkills 전용, `''`=태그 없음/섹션 통째 — 외부 계약은 null, api-spec §3 v1.1 동기) |
| `menuSeq` | int NOT NULL | `fixed_menu.seq` (BQ menu_seq STRING → SAFE_CAST, FR-B5) |
| `score` | double | 디버그·관측용 (서빙은 rank만 사용) |
| `rank` | int NOT NULL | 섹션 내 순위 1..K |
| `computedDate` | date | **7일 시그널 윈도우 종료일(= 배치 실행일 전일, Airflow `ds`)** — ISS-002 A안. 신선도 관측용, 서빙은 검사 안 함 §1.3 |

- **유니크**: `(rankerId, targetSection, targetSectionTag, rank)` + `(rankerId, targetSection, targetSectionTag, menuSeq)` — tag는 `''` 정규화(NOT NULL)로 확정되어 표현식 인덱스 불요 (api-spec §3 v1.1).
- **조회 인덱스** = 유니크가 겸함: `WHERE rankerId+복합키 ORDER BY rank LIMIT limit×2` 단건 인덱스 스캔 (NFR-1).
- **K=30/섹션** 적재 (FR-API5 "K≥24" 충족, recentPurchased `LIMIT 30` 선례 정합). 1차 5섹션 × 30 = 최대 150행 — 사이즈 무시 가능.
- DDL·엔티티·마이그레이션 상세: [api-spec.md §3](api-spec.md).

### 1.2 BQ 랭킹 마트 (이력 = 여기)

`hlb_mart.mart_home_skill_ranking` (가칭 — 네이밍은 /dev-data 마트 컨벤션 확인 후 확정): PG와 동일 키 컬럼 + **시그널·norm 분해 컬럼**(구매·조회·전환·긍정비율·매출·부스트 원값/percentile) 동반, `computed_date` 파티션. 분해 컬럼이 있어야 튜닝(Phase C)·이상 탐지·CL-04 최종단계 알고리즘 검증 태스크가 가능하다.

### 1.3 적재 토폴로지 (D-7 확정: 컴퓨트 airflow / write 서버 / 트리거 K8s CronJob)

```
common-data-airflow 마트 체인 (KST ~11시 산출)
        │  mart_home_skill_ranking (computed_date=어제 — 7일 시그널 윈도우 종료일)
        ▼
K8s CronJob "load-home-skill-ranking" (12:00 KST = 0 3 * * * UTC, base/hlb/cronjobs/ 선례)
   1. freshness guard: 마트에 **computed_date=어제(실행일 전일)** 행 존재? 없으면 push 생략 + Slack 알람 → 종료(실패)
   2. BQ 추출(상위 K=30/섹션) → PUT /api/home/skill-rankings (@Airflow) 페이로드 구성
        ▼
hellobot-server 적재 API: 검증(§1.4) → 섹션 그룹별 DELETE+INSERT 단일 트랜잭션 교체 → 결과 요약 응답
```

- **computed_date 시맨틱(ISS-002 A안 확정 2026-06-11)**: computed_date = **7일 시그널 윈도우 종료일(= 배치 실행일 전일, Airflow `ds`)** — "마트 산출일(오늘)" 아님. 마트 체인 루트 DAG가 02:00 UTC 스케줄(logical date=전일)이라 `{{ ds }}` = 실행일 D의 D-1. 따라서 guard는 "어제 행 존재" 검사. **분석 노트: 서빙일 D에 노출되는 랭킹의 computed_date는 D-1** (A/B 분석 조인 기준).
- **실패 시맨틱 = "전일 유지 자연 흡수"(R-5·R-7)**: guard 발동·push 실패·서버 거절 어느 경우든 PG에는 전일 랭킹이 그대로 남아 서빙 계속. 명시적 폴백 로직 불요, 알람만(NFR-2a·NFR-5).
- **부분 보호 — 0건 섹션 skip**: 페이로드에 행이 0개인 복합키 그룹은 **교체하지 않고 전일 유지 + 응답 `skipped` 보고 + 알람**. "빈 랭킹 서빙→AsIs 폴백"(R-7)은 한 번도 적재된 적 없는 키(신설 칩 등)에서만 발생하게 좁힌다.
- **멱등**: 같은 페이로드 재PUT = 같은 상태 (재시도 안전).
- **CronJob 추출 계약(ISS-008 명문화)**: 추출 술어 = `WHERE computed_date = <어제> AND target_section IS NOT NULL` — 미바인딩(target_section NULL) 섹션은 마트에 이력·검증용으로 존재하나 **push 제외**. CronJob 작성 노트 3종: ① NULL targetSection 행이 페이로드에 섞이면 서버가 **400 전체 거절**(그룹 skip 아님) ② 적재 API 응답은 ResWrapper envelope `{"data": {computedDate, applied[], skipped[]}}` — 알람 판단은 **`.data.skipped`** 기준 ③ BQ JSON 추출은 INT64를 문자열로 직렬화 → `menuSeq`·`rank` **숫자 캐스팅 필수**.
- **CronJob 매니페스트 요건**: `concurrencyPolicy: Forbid` — 동시 PUT 겹침 시 후행 유니크 위반 500 방지(L3-04). @Airflow 크리덴셜은 내부망 제한·로테이션 runbook 후속(L3-12).
- **시트 동기화 순서 보장(L5-09, 2026-06-11 확인)**: staging DAG가 구글시트 sync 트리거를 `wait_for_completion=True`로 게이트한 뒤 intermediate→mart 체인을 트리거 — 랭킹 계산은 항상 **당일 동기화된 태그**를 사용. 운영 수칙 2건: ① 마트 체인 시간대(KST 약 11~12시) **수동 시트 sync 금지**(테이블 replace 경합) ② 태그 반영 cutoff = 매일 KST 11시경 — 이후 수정분은 익일 랭킹부터 반영.
- CronJob 구현(인라인 `bq`+`curl` vs 소형 파이썬 이미지)·BQ SA 시크릿(`cronjobs-secrets.yaml` 선례)은 /dev-infra·/dev-data 재량. Slack 알림은 기존 cronjob 패턴(`#chatops_헬로우봇_운영알림`) 따름.
- **배치 타이밍 확정(FR-B4)**: 마트 체인(KST ~11시) 후행 12:00 KST 일배치. 기획 "새벽4시"는 미충족 — D+1 일배치 수용은 기결정(DF-S3-5).

### 1.4 적재 시 유효성 (R-6 보완 + CL-22)

서버 적재 API가 최종 권위로 검증: ① menuSeq를 PG 유효·**노출 가능** 스킬과 INNER JOIN — 미노출/미존재는 drop + 응답 보고. **visibility 축(ISS-006 A안 확정 2026-06-11)**: 적재 검증 = `visibleStatus='visible' OR visibleStatusWeb='visible'` (**앱·웹 합집합** — 칩 컨테이너는 웹도 지원하고 KR 게이트는 플랫폼 무관이라 **웹 KR 유저도 C-A 대상**, web-visible 스킬을 적재 단계에서 drop하지 않음) ② rank **유니크만** 검사 (연속성 검사 없음 — visible drop으로 생기는 rank gap과 양립). BQ 단계에서도 `mart_fixed_menu_server` 기준 사전 제외(이중 방어)하되, **서빙 visibility 필터는 최종 가드로 유지** — 서빙 pre-filter는 **디바이스별 축 분기**(`isMobile ? visibleStatus : visibleStatusWeb`, AsIs와 동형)로 일중 비노출 전환 흡수(over-fetch ×2가 이 간극의 보험, §4).

---

## 2. ① 계산 레이어 (BQ, common-data-airflow)

### 2.1 파이프라인 (일배치, 기존 마트 체인에 신규 마트 1개)

```
base 풀:   original_type='original' ∧ 유료 ≥750원(단위 바인딩 D-5)            (FR-F0)
   → 시그널 집계: 최근 7일, 스킬(menu_seq) 단위                              (§2.2)
   → 정규화: 시그널별 percentile-rank × 전체 base 풀                         (§2.3, CL-04✅)
   → score = Σ(가중 × norm) + 신규부스트                                     (FR-R3)
   → 섹션 필터(5종)로 부분집합 선택 → 섹션 내 score DESC rank (tie: menu_seq ASC)
   → 섹션별 상위 K=30 → mart_home_skill_ranking
```

**score는 전체 base 풀에서 1회 산출**(norm 모집단=전체 base 풀이므로 섹션별 재계산 없음), 섹션은 필터로 부분집합만 선택해 rank를 다시 매긴다. '실시간 인기' rank = 전체 score 순서와 동일(필터 ≈ 없음).

### 2.2 시그널 6종 (가중 합 = 1.0, FR-R3 확정)

| 시그널 | 가중 | 원천 | 집계 |
|---|---|---|---|
| 구매수 | 0.35 | `mart_use_skill_se` | 7일 합 ÷ **가용일수** = `GREATEST(1, LEAST(7, DATE_DIFF(END_DATE, open_date, DAY)+1))` |
| 조회수 | 0.10 | `mart_v2_skill_funnel_fb` (기본 `open_skill_description` — DF-S3-3, dmp 동기) | 〃 |
| 전환율 | 0.20 | 구매÷조회 (조회 0 → 0) | 7일 누적 기준 |
| 긍정평가비율 | 0.15 | `mart_fixed_menu_evaluation_server` — `1 − 💩비율` (FR-R5) | 7일 윈도우 |
| 매출 | 0.15 | `mart_use_skill_se.revenue_krw` (외부채널 포함 수용 CL-07) | 7일 합 ÷ 동일 분모 |
| 신규부스트 | 0.05 | `mart_skill_open_date_se.event_date` — `open_date >= END_DATE − 29일`(**출시 1~30일차**) → 1, else 0 (이진, D-4/D-6) | — |

**분모 = 가용일수(CL-08✅ R-3)**: "실데이터 일수"가 아니라 출시 후 경과일 기준 — 정확 표기는 **`GREATEST(1, LEAST(7, DATE_DIFF(END_DATE, open_date, DAY)+1))`** (출시일 포함 1일차, `open_date` 결측 시 7 — ISS-009 정정). 신규 스킬의 출시 당일 매출 피크가 자연 부스트로 작동(바닥 규칙 없음, 기획 의도 수용). 판매 0인 날도 분모에 포함.

### 2.3 정규화 (CL-04✅)

측정 5시그널은 **percentile-rank(예: `PERCENT_RANK()`), 모집단 = 전체 base 풀** (섹션별 아님 — 섹션 간 점수 비교 가능·소풀 왜곡 방지). 신규부스트는 이미 0/1이라 norm 제외. ⚠️ norm 방식 교체(예: log-minmax)는 **BQ 계산 레이어 한정 — 서버·앱·테이블 무변경**으로 가능(R-2 질의 회답). 최종단계 "데이터 검증·알고리즘 보완" 별도 태스크에서 분해 컬럼(§1.2)으로 검증.

### 2.4 신규 섹션 콜드스타트 (CL-08✅)

별도 장치 없음 — §2.2 분모 규칙(가용일수)이 콜드스타트 해소를 겸한다. 출시 ≤7일 스킬은 짧은 분모로 일평균이 정당하게 계산되고, ≤30일 부스트(0.05)가 가산. **신규 인기 섹션에만 적용되는 특칙이 아니라 전 스킬 공통 분모 규칙**이므로 구현 분기 없음.

### 2.5 섹션 필터 바인딩 (1차 5섹션)

| 논리 섹션 | 필터식 (base ∧ …) | 복합키 (targetSection, targetSectionTag) |
|---|---|---|
| 실시간 인기 | (없음 — 전체 base) | 운영 칩 구성 조회 후 바인딩 (§9-1) |
| 신규 인기 | `open_date ≤ 6개월` (C-2, N 가변) | 〃 |
| 사주 | `chatbot_content_type = '사주'` (ISS-009 정정 — 실측 2026-06-11: temp topic에 사주/타로 값 부재 → 공식 축 사용) | 〃 |
| 타로 | `chatbot_content_type = '타로'` 〃 | 〃 |
| 재회 | `intents ∋ '재회'` 〃 | 〃 |

- 태그 원천 = 임시 태그 `taenyon_temp_skill_tag_info_v2` 그대로 (DF-S4-1 하이브리드 확정).
- **저장 위치(DF-S4-3 — 이 문서로 확정)**: 1차 = **마트 파이프라인 내 선언적 바인딩 블록**(섹션→복합키+필터식을 단일 설정 CTE/구조로 모음 — 규칙이 SQL 본문에 흩어지지 않게). 운영자 편집(시트/테이블/어드민)은 **후속 승격 seam**(CL-16과 동일 궤) — 1차 5섹션 고정·값 실측 종속 상태에서 편집 표면을 먼저 여는 것은 과잉. 섹션 노출 자체의 운영 제어는 칩 어드민(추가/제거)으로 이미 가능(랭킹 없는 칩=AsIs 폴백으로 비파괴, §3.4).

---

## 3. ③ variant 판정 + 후보 fetch 교체 (hellobot-server)

### 3.1 3군 게이트 구조 (FR-AB4✅ — 키18 흡수 + ②신규 키 중첩)

```
홈 1차 응답 (getTabData, home.ts:188-232 — 무변경)
  키18 게이트: legacy(L) ↔ featuredSkillsTabs(칩 수신군)        ← ①축, 현행 그대로
        │
칩 lazy 요청 (getFeaturedSkillsTabData — 이번 수정 지점)
  ②랭킹 게이트(신규): AsIs fetch(C-M) ↔ 랭킹 fetch(C-A)         ← 이 프로젝트
```

- **판정 위치 = lazy 경로 안** — 도달 자체가 칩 수신군이므로 "키18 B군 내 중첩"이 구조적으로 보장된다. 홈 1차 응답·칩 메타는 무변경(C-M↔C-A 화면 동일 — variant 식별은 §5 측정으로).
- 기본 배분 L50 / C-M25 / C-A25 (키18 50/50 유지 시 ②키 50/50) — 셀 배분 최적화는 분석 문서 잔여 결정.

### 3.2 ②랭킹 게이팅 체인 (키18 패턴 `home.ts:198-225` 복제)

| 순서 | 검사 | 불통과 시 |
|---|---|---|
| 1 | 국가 = KR (NFR-7) | AsIs (판정·노출 이벤트 없음) |
| 2 | FeatureFlag `featured-skills-ranking` (마스터 킬스위치) | off → **전원 C-M** (flag off 시 DB 조회 0 — 신규 경로 비용 0) |
| 3 | **랭킹 대상 칩**인가 — 칩 복합키가 랭킹 적재 키에 존재(`hasAnyRanking`) | AsIs (판정·노출 없음 — 비대상 칩에서 Hackle 노출을 만들지 않아 희석 방지) |
| 4 | FeatureFlag `featured-skills-ranking-public-enabled` | off → `UserTestGroup` 등록자만 C-A (테스터 프리뷰 단계) |
| 5 | Hackle **신규 실험 키**(번호 발급 대기 §9-2) 분배 | "B"=C-A / "A"·SDK 실패=C-M (보수 폴백) |

평가 순서 = **KR → master flag → 대상칩 → public flag → Hackle** (ISS-009 정정 2026-06-11 — flag off 시 DB 조회 0이 되도록 flag가 대상칩 검사보다 선행. **핵클 호출 전 대상칩 검사** 불변식은 유지). 플래그 2종+단계 구조·네이밍은 키18 선례(`featured-skills-tabs`/`-public-enabled`) 동형 — 운영팀이 이미 아는 롤아웃 절차 재사용. 유저 버킷·일괄(FR-AB3)은 Hackle 유저 단위 분배가 보장.

- (06-11 결정, L2-06) **핵클 호출 실패 폴백(C-M)은 배정 로그에 `hackleError` 마커로 구분 기록** — 정상 "A" 배정과 SDK 실패 폴백을 분석 모수에서 분리.

### 3.3 후보 fetch 교체 + shape 어댑터 (⭐ 단일 seam)

variant=C-A이면 `fetchSkillListBySectionType` 호출을 **랭킹 fetch로 교체** (lazy 호출부 `home.ts:641` 분기 — limit+1 선컷 때문에 post-fetch 재정렬 불가, [감사 §4-1](planning/s5-asis-implementation-audit.md)):

```
rows = HomeSkillRanking WHERE (rankerId='popularity_v1', targetSection, targetSectionTag)
       ORDER BY rank LIMIT limit×2          ← over-fetch (R-5✅: vertical 14 / horizontal 16, K=30 내)
rows 0건 → AsIs 폴백 + 마킹 (§3.4)
menus = 스냅샷/캐시에서 menuSeq IN 조회 → rank순 정렬
data  = 기존 섹션과 동일 shape 포장:
   · tagSkills 계열  → [{ tag: targetSectionTag, skills: menus }] 단일 그룹 (현행 today-tag-skills 산출과 동일 필드)
   · recentPurchasedSkills → config.recentPurchasedSkills.pinnedSkillSeqs 선두 고정(중복 제거) + 나머지 rank순  ← FR-R10
   · 그 외 타입 → 랭킹 비대상(§3.2-2에서 차단)이므로 어댑터 미지원이 정상
```

- **하류 전부 무변경 재사용**: packageProduct → getAppFixedMenuCaches(visibility) → filter* 정형화 → cap+hasMore → 응답. 어댑터가 "동일 shape"만 지키면 앱·계약 무변경이 자동 성립.
- pinned는 recentPurchasedSkills에만 존재하는 현행 운영 기능이라 그 칩에서만 보존. 태그 칩의 수동 순서는 C-M의 정의 자체이므로 C-A에 pinned 개념 없음.
- (06-11 결정, L1-09) 랭킹 조회 시 **태그 비계열 섹션**(recentPurchasedSkills 등)은 칩의 `targetSectionTag`를 무시하고 `''`(태그 없음)로 조회 — AsIs의 "다른 섹션에서는 태그 무시" 시맨틱과 동기화, 어드민 태그 오입력을 무해화.
- 랭커 추상화(FR-R1): `AsIsRanker`(=기존 fetch 위임) / `PopularityRanker`(위 조회+어댑터) 2전략 + variant 리졸버(§3.2)가 선택 — 인터페이스 형상은 /dev-server 재량(강제 아님), **계약은 "단일 seam에서 분기 + 동일 shape 반환"**. `showRanking`은 뱃지 토글 bool 유지, `ranker_id` 일반화는 테이블 컬럼 seam으로 충족(FR-API2).

### 3.4 폴백·킬스위치 (R-7✅)

| 상황 | 동작 |
|---|---|
| 랭킹 0건 (한 번도 적재 안 된 키 등) | **AsIs 폴백** + 마킹(variant=C-A인데 AsIs 서빙 — 분석 희석 추적용. 수단은 아래 표 — **자동 알람 아님**) |
| 배치 실패·지연 | 전일 랭킹 유지 (§1.3 — 서빙 무감지, 알람만) |
| ②키(마스터 플래그) off | **전원 C-M** — 칩 UI 유지, 랭킹만 끔 (1단 롤백) |
| 키18 off | **전원 L** — 컨테이너까지 끔 (2단 롤백, 현행 그대로) |
| Hackle SDK 실패 | C-M (보수) |

서빙은 `computedDate` 신선도를 검사하지 않는다(전일 허용이 사양) — 신선도는 모니터링·알람 소관(NFR-5).

**알림·관측 수단(ISS-009 정정 — "마킹+알람" 문구의 실수단 명시)**:

| 실패 지점 | 수단 |
|---|---|
| 빈 랭킹 폴백 (서빙 — variant=C-A인데 AsIs 서빙) | winston 로그 + 배정 로그 `fallback` 마킹(§5) — **자동 알람 아님** (로그 모니터링 소관) |
| DB 적재 에러 (적재 API 트랜잭션 실패) | `notifyToSlack` 1회 — 채널 env `SLACK_SKILL_RANKING_ALERT_CHANNEL`, redisKey dedup(중복 발송 방지), 발송 후 rethrow(500 응답 유지) |
| 적재 도달 전 실패 (마트 산출·CronJob) | Airflow Slack(`on_failure`) · CronJob 자체 알림 (§1.3) |

---

## 4. ④ 서빙 동작 (lazy 경로 — 외부 계약 무변경)

| 단계 | C-M (현행=AsIs) | C-A (랭킹) |
|---|---|---|
| 후보 fetch | `fetchSkillListBySectionType` limit+1 (태그=priority / recent=Redis recency 분단위) | 랭킹 테이블 rank순 limit×2 (일배치) |
| visibility 정형화 | 동일 (filter*) | 동일 — 적재 시 선제 제외(§1.4)로 탈락률↓ |
| cap+hasMore | 동일 (`capFeaturedSkillsTabData`, 정형화 후 >limit → hasMore) | 동일 |
| 응답·앱 뱃지 | 동일 `{section,data,fixedMenus,chatbots,hasMore}` — rank 필드 없음, 앱이 index+1 뱃지 | 동일 |

- 노출 7/8개 미보장(visibility 탈락 시 감소)은 **현행 동작 보존** — 단 C-A는 over-fetch ×2로 미달 확률이 구조적으로 낮다.
- '실시간' 칩의 신선도는 C-A에서 분단위→일배치로 바뀐다 — CL-09 기결정("실시간"=라벨, 공통 7일 점수).
- NFR-2(b) "슬롯 미달/0 → 섹션 숨김"은 칩 컨테이너 맥락에서 **R-7 폴백으로 실현** — 칩에는 항상 C-M 수동 콘텐츠가 존재하므로 빈 노출·저품질 채움 없이 AsIs로 채워진다(숨김 불요).
- **랭킹 주입은 칩 lazy 경로만** — 홈 하단 단독 섹션·전체보기 페이지는 C-A에서도 수동 유지(po-review §1.2 확정). 칩↔하단 중복·순서 불일치는 인지된 사양(po-review §5.8).

## 5. ⑤ 측정 seam (계약은 dmp·event-spec 소관)

| 장치 | 내용 | 상태 |
|---|---|---|
| **서버 배정 로그** | §3.2-5 판정 직후 훅: user, 복합키, variant, **fallback 여부**(§3.4), 시각. C-M↔C-A 화면 동일 → variant 차원의 1차 원천 | 형태(구조적 로그→BQ vs 서버사이드 이벤트)는 **측정 이원화 잔여 결정** 종속 — 훅 위치만 이 문서로 고정 |
| Hackle 노출 | 키 판정 시 SDK 자동 — §3.2 순서 1·2 선행 검사로 비대상 노출 희석 방지 | 구조 확정 |
| 클라 이벤트 (CL-02) | 노출(impression) 신규 + `(targetSection, targetSectionTag)` 식별자 + variant 차원(FR-V6). 소급 불가 → C-A 출시와 동시 배포 | event-spec 별도 트랙(/dev-data) — variant를 클라가 알려면 응답 additive 필드 필요(무해 — 앱은 미지 필드 무시). **채택 여부 = 측정 이원화 결정** ([api-spec §2.3](api-spec.md)) |

## 6. 시퀀스 요약

```
[배치]  mart 체인(~11시) → CronJob(12시): guard→추출→PUT → 서버: 검증→tx 교체→요약응답 → (이상 시 Slack)
[서빙]  앱 칩 탭 → GET /featured-skills-tab/:tabSeq → ②게이팅(§3.2) ─C-M→ 기존 fetch ┐
                                                            └C-A→ 랭킹 조회→어댑터 ┴→ 정형화→cap→응답
```

## 7. 파트별 구현 매핑 (상세 과업 = [tasks.md](tasks.md))

| 파트 | 범위 | 핵심 산출 |
|---|---|---|
| /dev-server | §1.1·1.4·§3·§4 | 엔티티+마이그레이션, 적재 API, variant 리졸버+어댑터+폴백, 배정 로그 훅, config·플래그 상수 |
| /dev-data | §1.2·§2 (+§1.3 추출 스크립트 협업) | 랭킹 마트 SQL+체인 등록, 값 바인딩 실측(FR-F7·D-5), event-spec(CL-02) |
| /dev-infra | §1.3 | CronJob 매니페스트+BQ SA 시크릿+Slack 알림 |
| 클라 3종 | §5 | event-spec 확정 시에만 (컨테이너 소비 무변경 FR-API4) |
| /qa | §3.4·§4 | 폴백·킬스위치·shape 정합·뱃지 케이스 |

**착수 순서**: 서버(테이블+적재 API) ∥ 데이터(마트) → 인프라(CronJob) → 서버(서빙 분기) → 측정(event-spec) — §1이 척추, ②→①③④→⑤.

**운영 반영 순서(런북 고정 — L3-14, 06-11 확정)**: **서버 배포 → DB 마이그레이션(수동) → feature flag on** 순서 고정. 마이그레이션 전에 flag를 켜면 lazy 응답이 500(테이블 부재 — resolve 경로 try/catch 미보호) — **순서 위반 금지**.

## 8. 이 문서에서 확정한 설계 결정 (입력 확정값 외 신규)

| # | 결정 | 근거 |
|---|---|---|
| 1 | 테이블 `home_skill_ranking` + `rankerId` 컬럼(확장 seam), `showRanking` bool 유지 | FR-R7/NFR-6/FR-API2 — 2랭커에 일반화 과잉 |
| 2 | 적재 K=30/섹션 | FR-API5(K≥24)·recentPurchased LIMIT 30 선례 |
| 3 | 적재 API = PUT 전체 교체·섹션 그룹별 스왑·**0건 그룹 skip+알람**·단일 tx·멱등 | R-5/R-7의 "빈 랭킹" 발생면 축소 |
| 4 | CronJob 12:00 KST + **freshness guard** | 마트 체인(~11시) 완료 레이스 해소, FR-B4 타이밍 확정 |
| 5 | ②게이팅 = 플래그 2종(`featured-skills-ranking`/`-public-enabled`) + 신규 Hackle 키, 판정 순서 KR→master flag→대상 칩→public flag→Hackle (순서 ISS-009 정정 2026-06-11) | 키18 선례 동형·노출 희석 방지·flag off 시 DB 조회 0 |
| 6 | DF-S4-3: 1차 = 마트 내 선언적 바인딩 블록, 운영 편집은 후속 승격 seam | §2.5 |
| 7 | pinned 보존 = recentPurchasedSkills 칩 한정(`config...pinnedSkillSeqs` 재사용) | FR-R10/CL-14의 현행 기능 범위 |
| 8 | 서빙 신선도 무검사(전일 허용), 관측은 알람 | R-5 "전일 유지 자연 흡수" |

## 9. 미해결·선행 확인 (설계 비블로킹, 구현·실행 전 필요)

1. **운영 칩 구성 실값** — `home_section_featured_skills_tab` 조회로 §2.5 복합키 바인딩 확정. 5섹션 칩이 없으면 어드민 신설(코드 불요 — 단 신설 칩의 C-M 수동 큐레이션 운영 필요 → po-review C-M 큐레이션 정책 결정과 연동).
2. **신규 Hackle 키 발급** + 키18 현 운영 단계(플래그 2종 값·분배 비율) 확인 — 셀 설계 입력.
3. 값 바인딩 실측(FR-F7: topic/intents distinct·T1 커버리지) · base 750원 단위(D-5) · 조회 정의 dmp 동기(DF-S3-3) — /dev-data.
4. event-spec(CL-02) + 측정 이원화·잔여 실험 결정(po §6 #3~#10 / analysis §14 #2~#10) — 실험 시작 전.
5. CL-04 최종단계 "norm 데이터 검증·알고리즘 보완" 별도 태스크 등록(R-2).

---

## Changelog

| 날짜 | 변경자 | 내용 | 확인 |
|---|---|---|---|
| 2026-06-10 | 코디네이터(/architect 패스) | v1 신설 — 5레이어 세부 설계(②→①③④→⑤), 3군(L/C-M/C-A)·결정 라운드 2 확정값 기반. 신규 설계 결정 §8 8건 | 사용자 검토 대기 |
| 2026-06-11 | 코디네이터(5렌즈 리뷰 반영) | v1.1 — ①ISS-002 A안: computed_date=7일 윈도우 종료일(실행일 전일)·guard "어제"·서빙일 D↔computed_date D-1 노트(§1.1·§1.3) ②ISS-008: CronJob 추출 술어(`target_section IS NOT NULL`)·작성 노트 3종(400 전체 거절/ResWrapper envelope/INT64 캐스팅)·매니페스트 `concurrencyPolicy: Forbid`(§1.3) ③L5-09: 시트 sync 순서 보장 근거+운영 수칙 2건(§1.3) ④ISS-006 A안: visibility 적재=앱·웹 합집합/서빙=디바이스 분기(§1.4) ⑤ISS-009 드리프트 정정: §2.5 `chatbot_content_type`·§3.2 게이트 순서(+§8-5)·§1.4 rank 유니크만·§2.2 분모 `GREATEST(1,LEAST(7,…))`/new_boost 1~30일차·§3.4 알림 수단 표·§1.1 tag NOT NULL `''` ⑥L1-09 태그 비계열 `''` 조회(§3.3)·L2-06 `hackleError` 마커(§3.2) ⑦L3-14 운영 반영 순서 런북(§7) | 사용자 확정(2026-06-11) 반영 |
| 2026-06-12 | 코디네이터(/workspace 정합 점검) | 표기 정정 — 헤더 상태 `v1` → `v1.1` 동기 (06-11 개정 시 누락분, **내용 무변경**) | - |
