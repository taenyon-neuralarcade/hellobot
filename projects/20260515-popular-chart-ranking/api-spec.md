# API 명세 — 인기스킬 섹션 노출 자동화 (홈탭 Phase #2)

> 작성: 2026-06-10 (/architect 세부 패스) · 상태: **v1** · 동기: [architecture.md](architecture.md)
> ⚠️ **계약 문서** — 수정 시 하단 Changelog 필수.
> 표기: 경로·심볼 네이밍은 hellobot-server 리포 컨벤션 내에서 /dev-server가 조정 가능 — **계약 요소는 시맨틱(요청/응답 형상·트랜잭션·에러 규칙)**.

## 0. 변경 개요

| # | 항목 | 종류 |
|---|---|---|
| 1 | `PUT /api/home/skill-rankings` — 랭킹 적재 (리버스-ETL write) | **신규** |
| 2 | `GET /api/home/featured-skills-tab/:tabSeq` — 칩 lazy 데이터 | **외부 계약 무변경** (내부 분기 신설) |
| 3 | PG 테이블 `home_skill_ranking` + 마이그레이션 | 신규 |
| 4 | FeatureFlag 2종 + Hackle 신규 실험 키 + config | 신규 |

클라이언트(iOS/Android/웹) 대응 변경 **없음** (FR-API4). 홈 1차 응답(`getTabData`)·칩 메타 응답도 무변경.

---

## 1. 랭킹 적재 API (신규)

```
PUT /api/home/skill-rankings
인증: @Airflow() (src/common/decorator.ts — 기존 배치 엔드포인트 공통 가드)
호출자: K8s CronJob "load-home-skill-ranking" (일 1회 12:00 KST, architecture §1.3)
```

### 1.1 Request Body

```jsonc
{
  "rankerId": "popularity_v1",          // 필수. v1 고정값
  "computedDate": "2026-06-10",         // 필수. YYYY-MM-DD — 7일 시그널 윈도우 종료일(= 배치 실행일 전일, Airflow ds. ISS-002 A안, architecture §1.1)
  "rows": [                             // 필수. 1 ≤ N ≤ 1000 (1차 5섹션×K30=150)
    {
      "targetSection": "recentPurchasedSkills",  // 필수. 칩 복합키 1축
      "targetSectionTag": null,                  // null 허용. 칩 복합키 2축 (tagSkills 전용)
      "menuSeq": 1234,                           // 필수. fixed_menu.seq (int)
      "score": 0.8123,                           // 필수
      "rank": 1                                  // 필수. 복합키 그룹 내 1..K 유니크
    }
  ]
}
```

### 1.2 시맨틱 (architecture §1.3~1.4)

1. **그룹화**: rows를 `(targetSection, targetSectionTag)` 복합키로 그룹.
2. **검증·필터**: menuSeq를 유효·노출 가능 스킬과 INNER JOIN(visibility 축 = `visibleStatus='visible' OR visibleStatusWeb='visible'` 앱·웹 합집합 — ISS-006 A안, architecture §1.4) — 탈락 행은 drop 후 응답 보고. 그룹 단위 결격은 **그룹 skip(HTTP 200 + `skipped[]` 보고 — 4xx 아님, 용어 통일 v1.2)**: 사유는 아래 표.
3. **교체**: 유효 행 ≥1인 그룹만 `DELETE(rankerId+복합키) → INSERT` — **전 그룹 단일 트랜잭션**. 유효 행 0 그룹은 **skip(전일 유지) + 보고**.
4. **멱등**: 동일 페이로드 재호출 = 동일 최종 상태 (재시도 안전).
5. 페이로드에 없는 복합키의 기존 행은 **건드리지 않음** (전일 유지 시맨틱).

**skip reason** (전부 그룹 단위 skip — HTTP 200 + `skipped[]` 보고, 해당 그룹은 전일 유지):

| reason | 조건 |
|---|---|
| `UNSUPPORTED_SECTION` | 어댑터 미지원 targetSection — 허용 = tagSkills 3종(R/F/P)+`recentPurchasedSkills` (v1.1) |
| `DUPLICATE_RANK` | 그룹 내 rank 중복 |
| `DUPLICATE_MENU` | 그룹 내 menuSeq 중복 (v1.2 신설 — 유니크 위반의 전 그룹 롤백+500 방지, ISS-004) |
| `STALE_PAYLOAD` | 기존 적재분보다 과거 computedDate (v1.2 신설 — 지연 재시도의 역행 덮어쓰기 방지, L3-06) |
| `TOO_MANY_ROWS` | 그룹 행수 > K=30 (`config.featuredSkillsRanking.loadTopK` 강제, v1.2 신설 — L3-13) |
| `EMPTY_ROWS` | 검증·drop 후 유효 행 0 |

### 1.3 Response

```jsonc
// 200 OK — skip·drop이 있어도 200 (호출자가 summary로 알람 판단)
// ResWrapper envelope (리포 신규 API 공통 — v1.2, ISS-008): 호출자(CronJob)는 `.data.skipped` 로 판독
{
  "data": {
    "computedDate": "2026-06-10",
    "applied": [ { "targetSection": "…", "targetSectionTag": "…", "loaded": 30, "dropped": 1 } ],
    "skipped": [ { "targetSection": "…", "targetSectionTag": "…", "reason": "EMPTY_ROWS" } ]
  }
}
```

| 에러 | 조건 |
|---|---|
| 400 `PARAMETER_ERROR` | 형식·시맨틱 검증은 **서비스(`assertValidRows`)로 일원화** (ISS-005) — rows 0개/1000 초과·필수 필드 누락·row null/비객체·rankerId 불일치·computedDate 비실재 날짜(예: `2026-99-99`)·menuSeq/rank int4 범위 초과·score 비유한(NaN/Infinity) 전부 400 |
| 401 | @Airflow 가드 실패 — basicAuth는 항상 401 (403 케이스 없음, ISS-009 정정) |
| 500 | 트랜잭션 실패 (전일 상태 보존 — 부분 적용 없음) |

---

## 2. 칩 lazy 데이터 API (외부 계약 무변경)

```
GET /api/home/featured-skills-tab/:tabSeq?layout={vertical|horizontal}
```

**요청·응답·에러 계약은 현행 그대로** (`{section, data, fixedMenus, chatbots, hasMore}`, 400 `USER_NOT_FOUND` / 404 `PARAMETER_ERROR`, layout `@IsIn`). 앱은 응답 순서로 index+1 뱃지 — 이 계약이 곧 "랭킹"의 전달 수단.

### 2.1 내부 분기 (신규 — architecture §3)

| 순서 | 판정 | 결과 |
|---|---|---|
| 1 | 국가 ≠ KR (또는 빈 슬롯 칩) | 현행 fetch (판정·노출 없음) |
| 2 | flag `featured-skills-ranking` off | 현행 fetch (= 전원 C-M, 1단 킬스위치 — off 시 DB 조회 0) |
| 3 | 칩 복합키가 랭킹 비대상 (`hasAnyRanking`=false) | 현행 fetch (핵클 호출 전 선행 — 노출 희석 방지) |
| 4 | flag `featured-skills-ranking-public-enabled` off | `UserTestGroup`만 랭킹 fetch |
| 5 | Hackle 신규 키 = "B" | **랭킹 fetch** (C-A) |
| 6 | "A" · SDK 실패 | 현행 fetch (C-M) |

평가 순서 = **KR → master flag → 대상칩 → public flag → Hackle** (architecture §3.2 동기 — ISS-009 정정 2026-06-11).

랭킹 fetch: `home_skill_ranking` rank순 `LIMIT limit×2` → 0건이면 현행 fetch 폴백+마킹 → shape 어댑터(architecture §3.3) → 이후 정형화·cap·응답 현행 동일.

### 2.2 응답 불변 항목 (회귀 기준)

- `hasMore` 의미 동일: 정형화 후 개수 > limit. (C-A는 over-fetch ×2라 limit+1 전제보다 버퍼 큼 — cap 함수 무수정.)
- 노출 개수 7/8 미보장(visibility 탈락 시 감소)·`showRanking` 뱃지 토글·빈 슬롯 칩(`targetSection=null → data:null`) 전부 현행 동일.

### 2.3 (보류) 응답 additive 필드

클라 이벤트에 variant 차원(FR-V6)을 실으려면 응답에 추가 필드(예: `"rankerVariant": "C-A"`)가 필요 — additive라 기존 앱은 무시(비파괴). **채택 여부 = 측정 이원화 잔여 결정 종속** — 확정 전 구현 금지, 확정 시 본 문서 Changelog로 추가.

---

## 3. 데이터 모델 — `home_skill_ranking` (신규)

엔티티 `HomeSkillRanking` (TypeORM, 마이그레이션 `{timestamp}-CreateHomeSkillRanking.ts`):

| 컬럼 | 타입 | 제약 |
|---|---|---|
| seq | int PK | auto |
| ranker_id | varchar | NOT NULL default `'popularity_v1'` |
| target_section | varchar | NOT NULL |
| target_section_tag | varchar | NOT NULL default `''` (v1.1 — `''`=태그 없음 정규화) |
| menu_seq | int | NOT NULL |
| score | double precision | NOT NULL |
| rank | int | NOT NULL |
| computed_date | date | NOT NULL |
| created_at / updated_at | timestamptz | 리포 BaseEntity 컨벤션 |

- **유니크**: `(ranker_id, target_section, target_section_tag, rank)` · `(ranker_id, target_section, target_section_tag, menu_seq)` — NULL 동일성 처리는 **`''` 정규화로 확정(v1.1, /dev-server)**: 외부 계약(요청/응답)은 null 유지, service 경계에서 `null ↔ ''` 변환. 표현식 인덱스 불요(typeorm:generate 드리프트 회피).
- 조회 패턴: `WHERE ranker_id=? AND target_section=? AND target_section_tag=? ORDER BY rank LIMIT ?` — 유니크 인덱스로 커버.
- 이력 없음(최신 1세대) — 이력은 BQ `mart_home_skill_ranking`(architecture §1.2).

## 4. 플래그 · 실험 키 · config (신규 상수)

| 항목 | 값 | 위치 |
|---|---|---|
| FeatureFlag 마스터 | `featured-skills-ranking` | `services/feature-flag.ts` (키18 선례 동형) |
| FeatureFlag 단계 | `featured-skills-ranking-public-enabled` | 〃 |
| Hackle 실험 키 | **발급 대기** (architecture §9-2) — treatment `"B"`=C-A | `services/home.ts` 상수 (키18 패턴) |
| config | `featuredSkillsRanking: { rankerId: 'popularity_v1', overfetchMultiplier: 2, loadTopK: 30, hackleExperimentKey: 0(placeholder) }` — rows 상한 1000은 DTO 검증(v1.1) | `common/config.ts` |

---

## Changelog

| 날짜 | 변경자 | 내용 | 확인 |
|---|---|---|---|
| 2026-06-10 | 코디네이터(/architect 패스) | v1 신설 — 적재 PUT API·lazy 내부 분기·`home_skill_ranking` DDL·플래그/키/config. §2.3 variant 필드는 측정 이원화 결정 보류 | 사용자 검토 대기 |
| 2026-06-11 | /dev-server | v1.1 구현 확정 반영 — ①tag `''` 정규화(NOT NULL, 외부 계약 null 유지) ②`UNSUPPORTED_SECTION` 그룹 거절 신설 ③config 항목 확정(rows 상한은 DTO). 구현 커밋 `7dc5b7bd` (feat/popular-chart-ranking) | 사용자 검토 대기 |
| 2026-06-11 | 코디네이터(5렌즈 리뷰 반영) | v1.2 — ①§1 에러표 현실화: 403 행 제거(basicAuth 항상 401)·400 조건=서비스 일원화 검증(rankerId 불일치·row null/비객체·비실재 날짜·int4 초과·score 비유한, ISS-005 — malformed→500 구버전 기술 삭제) ②§1.2 skip reason 표 신설 + 신규 3종 `DUPLICATE_MENU`·`STALE_PAYLOAD`·`TOO_MANY_ROWS`·"그룹 거절"→"그룹 skip(200+`skipped[]`)" 용어 통일 ③§1.3 응답 예시 ResWrapper envelope(`.data.skipped` 판독 노트, ISS-008) ④§1.1 computedDate=7일 윈도우 종료일(실행일 전일, ISS-002 A안) ⑤§2.1 게이트 순서 정정(KR→master flag→대상칩→public→Hackle, ISS-009) | 사용자 확정(2026-06-11) 반영 |
