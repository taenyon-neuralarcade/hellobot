# S5 — 현행 구현 감사 (feature docs ↔ 코드 엄밀 대조)

> 작성: 2026-06-10 · 스텝: S5 보강 (②랭킹 A/B 설계 기준선)
> **목적**: "현행 로직 그대로 = **A**, 인기점수 알고리즘 적용 목록 = **B**" 구도의 A/B 설계를 위해, A의 정확한 실체와 B가 바꿀 표면을 코드 수준에서 확정한다.
> **입력(사용자 지정 소스)**: hellobot-server [`docs/features/20260511-home-rank-skill-section/`](../../../hellobot-server/docs/features/20260511-home-rank-skill-section/readme.md) 8종 (readme · status · backend-design · backend-guide · api-spec · client-guide · admin-guide · review) + hellobot_iOS `docs/features/20260511-home-featured-skills-tabs/status.md` — 전 문서를 실코드와 항목별 대조.
> **코드 기준**: hellobot-server master = origin 동기 (관련 마지막 변경 2026-05-18 PR #2414, 이후 드리프트 없음) · iOS develop (PR #1418 머지 2026-05-26) · Android master (PR #1128 머지 2026-05-26)
> **선행 문서**: [s5-asis-serving-analysis.md](s5-asis-serving-analysis.md) — 서빙 경로·하부 추출(태그=priority / recent=recency) 상세는 그쪽 참조. 본 문서는 ①문서↔코드 대조 ②A의 정밀 정의 ③B 수정 표면을 얹는다.

---

## 0. 요약

1. **피쳐 문서와 master 코드는 기능 명세 전 항목 일치** — 문서를 설계 기준선으로 신뢰 가능. 불일치는 3건뿐이고 전부 "문서가 코드 변경 이전 상태로 남은 것"(§3) — 코드가 정답.
2. **A(현행)의 정의**: featuredSkillsTabs lazy 경로가 소스 service 자체 순서(태그 칩=어드민 priority / recent 칩=Redis recency)를 **`limit+1`로 선컷**해 받고 → visibility 정형화 → cap+hasMore. 서버 rank 필드 없음 — "1~N위"는 클라가 배열 index로 붙이는 뱃지.
3. ⭐ **B 주입의 정밀화 (이번 감사의 핵심 발견)**: 소스 fetch에 `limit+1` 선컷이 있어 "fetch 후 재정렬"은 **AsIs 상위 8~9개 안에서의 순열**에 불과 → B는 재정렬이 아니라 **variant B일 때 후보 fetch 자체를 랭킹 테이블 기반 조회로 교체**(기존 섹션과 동일 shape 반환)해야 한다. 하류 파이프라인(정형화→cap→hasMore→앱)은 전부 무변경 재사용.

---

## 1. 현행 구현 인벤토리 — 전 항목 코드 실재 확인 ✅

| 레이어 | 구현 | 위치 | 검증 |
|---|---|---|---|
| 엔티티 | `HomeSectionFeaturedSkillsTab` — homeSectionSeq(FK CASCADE) / **targetSection nullable**(null=빈 슬롯) / **targetSectionTag nullable**(tagSkills 전용, null=섹션 통째) / label / order(asc, 첫 row=활성 칩) / showRanking(default true) | `entities/HomeSectionFeaturedSkillsTab.ts` | ✅ 전문 확인 |
| 마이그레이션 | 4종 — Create(`1778508330886`) → Alter nullable+tag rename(`1778572595657`) → 테이블 rename rank_skill→featured_skills(`1778600000000`) → showRanking 추가(`1778700000000`) | `models/migrations/` | ✅ 4파일 실재 |
| 섹션 키 | `FEATURED_SKILLS_TABS = "featuredSkillsTabs"` | `config.ts:761` | ✅ |
| 슬롯 config | `limitByLayout {vertical:7, horizontal:8}` + `defaultLayout: "horizontal"` | `config.ts:794-800` | ✅ |
| FeatureFlag | `featured-skills-tabs`(마스터) / `featured-skills-tabs-public-enabled`(단계 전환) | `feature-flag.ts:11-12` | ✅ |
| 핵클 | 실험 키 **18**, treatment **"B"**, SDK 실패 시 보수적 "A" | `home.ts:44-45, 210-222` | ✅ |
| 게이팅 | 버전(And≥2.43.0/iOS≥2.54.0/Web) → master → public off=테스터(`UserTestGroup`)만 / on=전원 핵클 분배 → **상호배타 섹션 필터**(supports면 recentPurchased 제외, 아니면 featured 제외) | `home.ts:188-232` | ✅ |
| 칩 메타 | `getFeaturedSkillsTabsMeta` — order ASC 조회, `{tabSeq, label, targetSection, showRanking}` 배열 + `activeTabSeq`=첫 칩(없으면 0). **targetSectionTag는 응답 미노출** | `home.ts:597-612` | ✅ |
| lazy API | `GET /api/home/featured-skills-tab/:tabSeq?layout=` — `@Authorized`, 400 `USER_NOT_FOUND` / 404 `PARAMETER_ERROR`, layout `@IsIn` 검증(잘못된 값 400) | `controllers/home.ts:40-47` → `home.ts:614-717` | ✅ |
| 디스패처 | `fetchSkillListBySectionType(section, subKey, …, limit?)` — 12종 case, **태그 3종만** subKey(`tag === subKey`) 필터, 그 외 무시, 미지/null → null | `home.ts:540-595` | ✅ |
| cap+hasMore | `capFeaturedSkillsTabData` — `limit+1` 전제, freeMenus/recentPurchased=slice, tagSkills=**평탄화 누적 cap**(태그 그룹 가로질러 합산), category·객체 형태(이력/개인화 일부)=hasMore 항상 false, 배열 default=slice | `home.ts:723-776` | ✅ |
| 어드민 | targetSection 화이트리스트 **12종 + (미지정 "")**, 쓰기 super 전용, `TodayTagSkillsTag` 동적 드롭다운 | `admin/options/HomeSectionFeaturedSkillsTab.options.ts` | ✅ |
| iOS | `?layout=vertical` 상수 명시 전송(주석: 미명시 시 서버 default horizontal이므로 명시 필요) + **hasMore로 전체보기 판단** + `img_num_01~08` 뱃지(showRanking 분기) | `RankSkillTabRequestBuilder.swift:25-28`, `HomeSectionConverter.swift:491-493` | ✅ [#1418](https://github.com/thingsflow/hellobot_iOS/pull/1418) 머지 05-26 |
| Android | `layout=vertical`, hasMore→전체보기, 뱃지·skeleton 동일 패턴 | [#1128](https://github.com/thingsflow/hellobot_android/pull/1128) ([선행 분석](s5-asis-serving-analysis.md) 참조) | ✅ 머지 05-26 |

### ①컨테이너 게이팅 운영 시나리오 (코드 확정, `home.ts:193-232`)

| 단계 | master | public | 일반 유저 | 테스터(UserTestGroup) |
|---|---|---|---|---|
| 비활성/긴급 롤백 | off | - | recentPurchasedSkills | recentPurchasedSkills |
| 테스터 only | on | off | recentPurchasedSkills | featuredSkillsTabs (핵클 호출 없이 무조건) |
| 전체 A/B | on | on | 핵클 키 18 (B=신 / A·실패=기존) | 동일 (테스터 특례 없음) |
| 100% 공개 | on | on + 핵클 B 100% | featuredSkillsTabs | featuredSkillsTabs |
| 구버전 앱 | - | - | recentPurchasedSkills | recentPurchasedSkills |

> 주의(문서에 명시된 운영 리스크): 상호배타 필터는 클라의 `sections` 파라미터 인지 없이 적용 — supports=true인데 클라 UI가 featuredSkillsTabs를 요청하지 않으면 인기순 자리가 빈다. 코드 보호 없이 **운영 룰**(클라 배포 선행)로 처리 중 (admin-guide 4단계 ⚠️).

---

## 2. A 변형의 엄밀한 정의 — "이 상태 그대로 나가는 것"

A = featuredSkillsTabs lazy 경로의 현행 순서. 칩 클릭 시 파이프라인 (`getFeaturedSkillsTabData`, 코드 실행 순서 그대로):

```
① 칩 조회        HomeSectionFeaturedSkillsTab.findOne(tabSeq)            — 없으면 404
② 후보 fetch     fetchSkillListBySectionType(targetSection, targetSectionTag, …, effectiveLimit+1)
                 ★ limit+1 선컷: vertical=7 → 8개만, horizontal=8 → 9개만 소스에서 가져옴
                 ★ 순서의 소스 = 각 service 자체: 태그 칩=어드민 큐레이션 junction priority ASC /
                   recent 칩=Redis recency(배치 갱신) / 이력·개인화=각 service 로직
③ 캐시 풀 빌드    packageProduct → getAppFixedMenuCaches(유효=노출 가능 스킬만) → chatbotCaches
④ 썸네일 실험     getExperimentData로 name/banner override — 기존 "스킬 썸네일 A/B"(제3의 실험, 이번 프로젝트 무관)
⑤ 정형화 필터     filterFree / filterTagSkills / filterRecentPurchased — validFixedMenuSeqs 밖 스킬 제거
⑥ cap + hasMore  정형화 후 개수 > limit → hasMore=true, limit까지 자름
⑦ 응답           { section, data, fixedMenus, chatbots, hasMore } — rank 필드 없음
```

- **순위의 의미**: 서버는 순서만 보낸다. 클라가 배열 `index+1`로 1~N위 뱃지(`img_num_01~08`)를 입히고, `showRanking=false`면 뱃지 숨김. 즉 **"랭킹"은 전적으로 응답 순서의 함수** — B는 이 순서만 바꾸면 앱·계약 무변경으로 랭킹이 바뀐다.
- **노출 개수는 7/8 보장이 아님**: ②에서 limit+1개만 가져온 뒤 ③⑤ visibility 필터가 빼면 그만큼 적게 노출된다 (예: 9개 fetch → 2개 필터 아웃 → 7개 노출, hasMore=false). AsIs의 기존 동작이며 B 설계에서 개선 기회(§4-3).
- 홈 1차 응답(`getTabData`)의 12종 직접 노출 경로(구버전·①A그룹 유저용 legacy recentPurchasedSkills 포함)는 디스패처를 `subKey=null, limit=undefined`로 호출 — 서비스 내부 디폴트 개수. **②랭킹 B의 주입 대상은 lazy 경로만**이다.

---

## 3. 문서 ↔ 코드 대조 결과

**판정: 기능 명세(테이블·API·분기·에러·cap·어드민·게이팅)는 전부 코드와 일치.** 불일치 3건은 모두 문서가 후속 코드 변경 이전 상태로 남은 것:

| # | 문서 기록 (stale) | 실제 코드 (정답) | 영향 |
|---|---|---|---|
| 1 | status.md·backend-guide: Create 마이그레이션 파일명 `1778500000000-...TabTab.ts` | `1778508330886-CreateHomeSectionRankSkillTab.ts` (review.md는 정확) | 없음 — 표기뿐 |
| 2 | backend-guide 1단계 엔티티 골격: `targetSection` NOT NULL + 옛 인덱스명(`IDX_..rank_skill_tab..`) | nullable + `IDX_home_section_featured_skills_tab_section_order` (05-12/13 정정이 골격엔 미반영, status 로그·backend-design엔 반영됨) | 없음 — 골격 참고 시 주의 |
| 3 | iOS status.md: lazy 호출 `?limit=7` (05-11 결정 기록) | `?layout=vertical` 명시 전송 + hasMore 사용 — 서버의 05-18 limit→layout 교체에 머지(05-26) 전 정렬 완료 | 없음 — iOS 문서만 stale, 코드는 서버와 정합 |

부수 관찰: DTO `FeaturedSkillsTabMeta.targetSection` 타입이 `string`(non-null 표기)이나 실제로는 null이 직렬화됨 — api-spec.md가 `string | null`로 정확. 타입 표기 laxity일 뿐 동작 이슈 아님.

---

## 4. ⭐ B가 바꿀 표면 — 설계 핵심

### 4-1. seam 정밀화: "재정렬"이 아니라 "후보 fetch 교체"

선행 분석([s5-asis-serving-analysis.md](s5-asis-serving-analysis.md) §5)의 "`fetchSkillListBySectionType` 직후 재정렬" 표현을 정밀화한다 (2026-06-10):

- §2-②의 **`limit+1` 선컷** 때문에, fetch 후 재정렬은 "AsIs 순서 기준 상위 8~9개"의 순열일 뿐이다. 인기점수 기준 상위 N과 다르다 (점수 상위 스킬이 AsIs 상위 9개 밖이면 영원히 못 들어옴).
- 프로젝트 확정사항과도 이쪽이 정합: **"B는 별도 base∧섹션 풀을 점수순 — A와 후보풀 비공유"** (status.md 확정).
- 따라서 **B = variant 판정 시 후보 fetch 자체를 교체**: 칩의 `(targetSection, targetSectionTag)` 복합키로 PG 랭킹 테이블에서 score 순 상위 limit+1(+여유분)을 조회해, **기존 섹션과 동일 shape**(tagSkills / freeMenus / `{tag,version,skills}` …)로 반환.
- **seam 위치는 동일** — `home.ts` 디스패처(`fetchSkillListBySectionType` L540) 또는 그 lazy 호출부(L641) 단일점. 바뀌는 것은 동작의 정의("정렬 주입" → "fetch 분기")이지 위치가 아니다. 윤곽 문서 §2의 결론(캡처 불요·앱 무변경·단일 seam)은 그대로 유효.

### 4-2. B가 무변경으로 재사용하는 하류 (공짜로 얻는 것)

| 구간 | B에서 |
|---|---|
| 앱(iOS/Android)·응답 계약 | **무변경** — 순서대로 받아 index 뱃지. `showRanking`도 기존 칩 필드 그대로 |
| 칩 메타·어드민·엔티티·마이그레이션 | **무변경** — 칩 구성 동일, 순서(후보)만 교체 |
| visibility 정형화 (§2-③⑤) | 그대로 통과 — B 후보도 비노출 스킬 자동 제거 |
| cap+hasMore (§2-⑥) | 그대로 — 단 B fetch도 limit+1개 이상 반환해야 hasMore 의미 유지 |
| 썸네일 실험 (§2-④) | 그대로 (별개 실험, 간섭 없음) |
| 게이팅 코드 패턴 | ②랭킹 variant 판정 구현 시 `home.ts:198-225`(flag 2단+핵클+try/catch 폴백)를 템플릿으로 재사용 |

### 4-3. B가 새로 정해야 할 것 → S5 세부 패스(/architect) 위임

1. **②랭킹 variant 신호** — 키 18은 ①컨테이너 축 전용. 별도 신호(신규 핵클 키 또는 FeatureFlag 콤보) 필요. 판정 위치는 lazy 경로(`getFeaturedSkillsTabData`) 안.
2. **랭킹 테이블 → 섹션 shape 어댑터** — 복합키 조회 결과를 칩의 targetSection별 기존 shape로 포장하는 소형 변환기 (앱 무변경의 실현 수단).
3. **visibility 여유분** — limit+1보다 넉넉히(예: limit×2) 가져와 필터 후 슬롯 미달 방지. AsIs도 동일 리스크가 있으나(§2 주의) B에서 개선 기회.
4. **빈 랭킹 fallback** — 콜드스타트·적재 실패·복합키 미스 시 AsIs 순서로 폴백(보수적, 권장)할지 빈 응답일지.
5. **②실험 모집단** — featuredSkillsTabs 수신자(①의 B그룹, 또는 ① 100% 공개 후 전원). "① 종료 후 ② 착수"라는 S2 결정과 정합.

---

## 5. 미확인 — 코드 밖 운영 상태 (비블로킹)

- 운영 DB `home_section_featured_skills_tab` 칩 구성 실값(라벨·targetSection·tag) — 1차 5섹션(실시간·신규·사주·타로·재회) 매핑 확정용.
- 운영 FeatureFlag 2종 값 + 핵클 키 18 분배 현황 = **①컨테이너 실험의 현 단계** — ②랭킹 착수 시점 판단에 필요.

## 코드 레퍼런스 (단일 출처)

| 항목 | 위치 |
|---|---|
| 게이팅(①축)·핵클 상수 | `hellobot-server/src/services/home.ts:44-45, 188-232` |
| 1차 switch 디스패치·featured meta case | `home.ts:265-285, 312-314` (2차 통과 L421) |
| 디스패처(=B seam 영역) | `home.ts:540-595` (lazy 호출부 L641, limit+1 L648) |
| 칩 메타 / lazy / cap | `home.ts:597-612 / 614-717 / 723-776` |
| 컨트롤러·DTO | `controllers/home.ts:40-47`, `dtos/home.dto.ts` |
| config (키·슬롯) | `common/config.ts:761, 794-800` |
| FeatureFlag 키 | `services/feature-flag.ts:11-12` |
| 엔티티·마이그레이션 4종 | `models/entities/HomeSectionFeaturedSkillsTab.ts`, `models/migrations/17785~17787*` |
| 어드민 | `admin/options/HomeSectionFeaturedSkillsTab.options.ts`, `admin/views/HomeSectionFeaturedSkillsTab/` |
| iOS | `hellobot_iOS/.../RankSkillTabRequestBuilder.swift`, `HomeSectionConverter.swift` (PR #1418) |
| Android | PR #1128 — [선행 분석](s5-asis-serving-analysis.md) 코드 레퍼런스 표 |
