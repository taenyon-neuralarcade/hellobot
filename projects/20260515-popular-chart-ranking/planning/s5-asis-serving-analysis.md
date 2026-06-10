# S5 부록 — 현행(AsIs) 인기스킬 섹션 도출·서빙 분석

> 스텝: S5 입력 · 작성: 2026-06-08 · **정정: 2026-06-08 (dev-server, master 최신화 후 재분석)** · 대상 리포: hellobot-server (master)
> 상위: [s5-architecture-outline.md](s5-architecture-outline.md) · 교차: Android [PR #1128](https://github.com/thingsflow/hellobot_android/pull/1128) 분석
>
> ⚠️ **2026-06-08 정정 이력** — 본 문서 초판은 **stale 로컬 체크아웃**(2026-04-30, origin보다 3주 뒤짐) 기준이라 "통합 칩 컨테이너 미머지"로 잘못 결론냈음. `git pull` 후 재분석 결과 **`featuredSkillsTabs` 칩 컨테이너는 서버(origin/master 2026-05-21)·앱(2.43.0/05-26) 모두 이미 LIVE**. 아래는 실제 머지 코드 기준 정정본.

---

## 0. 결론 요약 (정정)

1. **통합 인기 칩 컨테이너 `featuredSkillsTabs`는 이미 LIVE** — 신규 엔티티(`HomeSectionFeaturedSkillsTab`) + 신규 lazy 엔드포인트(`GET /api/home/featured-skills-tab/:tabSeq`) + 칩 메타 필드(`showRanking`, `targetSection`, `targetSectionTag`). 프론트-온리 아님(풀스택). 단, **신규 랭킹 알고리즘은 없음** — 칩 데이터는 기존 섹션 추출을 그대로 재사용하고 "1~N위"는 응답 순서에 입힌 **장식 뱃지**.
2. **A/B 축이 둘** — ①컨테이너 A/B(legacy recentPurchasedSkills ↔ featuredSkillsTabs, **Hackle 키18, 이미 LIVE**) / ②랭킹 A/B(featuredSkillsTabs **안에서** AsIs 순서 ↔ 인기점수, **이 프로젝트, 미착수**).
3. **B(인기점수) 주입점 = `fetchSkillListBySectionType`(home.ts L540)의 정렬** — 칩 후보 스킬을 점수순으로 재정렬만 하면 됨. **앱/계약 무변경, A 캡처(스냅샷) 불요.** → 초판의 CL-03 "(다) 하이브리드 스냅샷" 논의는 **무효**.

---

## 1. featuredSkillsTabs 서버 구현 (실제 머지 코드)

칩 메타 테이블은 `home_section_rank_skill_tab` → **`home_section_featured_skills_tab`** 으로 rename + `showRanking` 추가 (마이그레이션 `1778600000000-RenameHomeSectionRankSkillTabToFeaturedSkillsTab`, `1778700000000-AddShowRankingToHomeSectionFeaturedSkillsTab`).

### ① 칩 저장 — `HomeSectionFeaturedSkillsTab` 엔티티
```
homeSectionSeq    부모 통합 섹션 (home_section.seq)
targetSection?    칩이 노출할 기존 섹션 키 (예: recentPurchasedSkills). null = 빈 슬롯(data:null)   [L20-25]
targetSectionTag? tagSkills 섹션의 태그명 (예: '타로'). null = 섹션 통째                          [L27-32] ★복합키 2번축
label             칩 표시 라벨 (예: 실시간)                                                         [L34]
order             칩 정렬 (asc, 첫 row가 활성 칩)                                                  [L37]
showRanking       1,2,3 인덱스 뱃지 노출 여부 (default true)                                       [L40]
```
어드민(AdminJS `src/admin/options/HomeSectionFeaturedSkillsTab.options.ts`)에서 칩 등록·정렬. country/lang은 부모 `HomeSection` 보유.

### ② 컨테이너 게이팅 (`services/home.ts` L188~232) — ①컨테이너 A/B
```
supportsClient = web | Android≥2.43.0 | iOS≥2.54.0                                  [L193-196]
 └ FeatureFlag "featured-skills-tabs" (마스터 킬스위치) ON?                          [L200]
    └ "featured-skills-tabs-public-enabled" ON?                                     [L202]
        OFF → UserTestGroup 등록자만 노출                                            [L207]
        ON  → Hackle 키 18 분배, variation "B"(treatment)만 노출                      [L212-222]
filteredSections: supports면 recentPurchasedSkills 제거 / 아니면 featuredSkillsTabs 제거 [L227-232]  ← 상호배타 1-슬롯 스왑
```

### ③ 칩 메타 조립 (`getFeaturedSkillsTabsMeta` L597)
`HomeSectionFeaturedSkillsTab.find({homeSectionSeq}, order ASC)` → `{ tabs:[{tabSeq,label,targetSection,showRanking}], activeTabSeq: 첫칩 }`. **targetSectionTag는 응답에서 제외**(서버 내부 키 — 앱 모델과 일치).

### ④ lazy 추출 (`getFeaturedSkillsTabData` L614, route `controllers/home.ts` L40)
```
GET /api/home/featured-skills-tab/:tabSeq?layout=
  tab = findOne(tabSeq) → section = tab.targetSection
  limit = config.featuredSkillsTabs.limitByLayout[layout]   (vertical=7 / horizontal=8, default horizontal)  [config L794-800]
  data = fetchSkillListBySectionType(section, tab.targetSectionTag, …, limit+1)    ← ★ SEAM
       → visibility 필터(filterTagSkills/filterFree/filterRecentPurchased, 홈섹션과 동일)  [L684-705]
       → capFeaturedSkillsTabData(cap + hasMore via limit+1)                            [L708, L723-775]
  return { section, data, fixedMenus, chatbots, hasMore }
```

### ⑤ 디스패처 = 정렬 seam (`fetchSkillListBySectionType` L540~594)
```
tagSkills(R/F/P) → todayTagSkillService.getSectionData(...)  → getFixedMenusByTagName, ORDER BY junction.priority ASC
                   if (targetSectionTag) → .filter(t => t.tag === targetSectionTag)   ← 칩=특정 태그 1개  [L569-571]
recentPurchasedSkills → getRecentPurchasedSkillsSectionData (Redis recency)            [L590-591]
appFree/todayFree/category/skillHistory/personalRecommended/… → 각 기존 섹션 메서드 그대로
```
→ **칩 데이터는 100% 기존 섹션 추출 재사용. lazy 엔드포인트는 thin 라우터.**

---

## 2. featuredSkillsTabs가 재사용하는 하부 추출 (= 현행 A의 실체)

칩 컨테이너가 새로 만든 게 아니라 그대로 호출하는 기존 추출 로직. **이 순서가 곧 현행 A(AsIs).**

### (A) 태그 스킬 섹션 — 칩이 `targetSectionTag`로 태그 1개 지정
- `todayTagSkillService.getSectionData()` (`today-tag-skills.ts` L11) → 태그별 `getFixedMenusByTagName(tag, 5)` (`fixed-menu.ts` L877).
- 쿼리: SnapshotFixedMenu ⋈ junction(FixedMenuFixedMenuTagsFixedMenuTag) ⋈ FixedMenuTag, `R2.name=태그`, `visibleStatus='visible'`, **`ORDER BY R1.priority ASC`** (어드민 큐레이션 순서) [L901].
- 즉 태그 칩의 현행 순서 = **어드민이 junction에 매긴 priority**. 정적.

### (B) recentPurchasedSkills 섹션 — 칩이 `targetSection=recentPurchasedSkills`
- 배치: mwaa/airflow ─(1분)─> `POST /api/fixed-menus/recent-purchased-skills/refresh` @Airflow → `refreshRecentPurchasedSkillsCache()` (`user-purchased-skill.ts` L77) → Redis 캐시.
- SQL: 유효가격≥minPrice(**60하트**) ∧ original_type='original' ∧ os∈(android,ios), GROUP BY skill, **ORDER BY MAX(created_at) DESC**(recency) LIMIT 30.
- 서빙: `getRecentPurchasedSkillsSectionData()` (`fixed-menu.ts` L2665) → Redis(miss→DB폴백) → pinned 선두 → visibility → limit.
- 즉 recentPurchased 칩의 현행 순서 = **최근 구매순(recency)**, 점수 아님. 분 단위 신선.

> base 단위 주의: 현행 minPrice=**60(하트)**, 프로젝트 base=**750(단위 미바인딩)** → 동일 임계 아님(D-5, /dev-data).

---

## 3. 복합키 / 플래그 (정정 — 모두 LIVE)

| 개념 | 현행 (LIVE) |
|---|---|
| 탭 키 | `HomeTab(id, platform, countryCode, languageCode)` 복합 유니크 |
| 통합 섹션 | `HomeSection.section = "featuredSkillsTabs"` (order) |
| 칩 키 | **`HomeSectionFeaturedSkillsTab` (targetSection, targetSectionTag)** ← 프로젝트 CL-01 복합키와 정확히 정합 |
| 랭킹 플래그 | **`showRanking`** (칩 단위, default true) — 1~8위 PNG 뱃지(앱) 토글 |

- `targetSectionTag` = tagSkills 섹션 내 **특정 태그 1개** 지정(예 '타로'). null이면 섹션 통째.
- 앱(PR #1128)엔 targetSectionTag 미노출 — 서버가 tabSeq로 내부 해석.

---

## 4. 두 개의 A/B 축 (혼동 주의)

| 축 | 무엇 | 메커니즘 | 상태 |
|---|---|---|---|
| **①컨테이너 A/B** | legacy `recentPurchasedSkills` ↔ 신규 `featuredSkillsTabs` 칩 컨테이너 | **Hackle 키18** + FeatureFlag 2단 + 버전 | **이미 LIVE** (서버 05-21 / 앱 2.43.0) |
| **②랭킹 A/B (이 프로젝트)** | featuredSkillsTabs **안에서** AsIs 순서 ↔ 인기점수 순서 | 미구현 | **미착수** |

→ 프로젝트 S2 "①종료 후 ②순차" 결정과 정합. 현재 칩의 "1~N위"는 AsIs 순서 위 **장식 뱃지**(앱이 응답 순서로 img_num_01~08 부여, `showRanking && rank≤8`).

---

## 5. ★ B(인기점수) 주입 seam — S5 핵심 (CL-03 정정)

- **주입점 = `fetchSkillListBySectionType`(home.ts L540) 직후 re-sort, 또는 하부 추출의 ORDER BY 교체.** 칩 후보 스킬을 **인기점수 랭킹 테이블 순서로 재정렬** 후 cap.
- **앱/계약 변경 불필요** — 앱은 응답 순서대로 받아 위치 뱃지만 부여. 서버에서 순서만 바꾸면 B 완성.
- **A 캡처(스냅샷) 불필요** — A는 오늘도 매 요청 live 계산. B는 batch 선계산(랭킹 테이블). **A/B = "live AsIs" vs "batch 인기점수"**.
  - → 초판 §5의 **CL-03 "(다) 하이브리드 스냅샷" 결론 무효화**. 잘못된 recentPurchasedSkills 중심 모델 기반이었음.
  - 정정: **A = 현행 live(featuredSkillsTabs/fetchSkillListBySectionType) 유지, B = 정렬 주입.** 스냅샷 논의 불필요.
- base 필터·신규부스트·점수공식은 **B 경로(랭킹 테이블 생성)** 에서 적용. lazy 엔드포인트는 그 순서를 읽기만.
- variant seam: 현행 컨테이너 게이팅(Hackle 키18)은 ①축. ②랭킹 A/B는 별도 신호 — featuredSkillsTabs 내부에서 "정렬을 AsIs로 둘지 점수로 둘지"를 주입할 지점이 S5 설계 대상.

---

## 코드 레퍼런스 (단일 출처)

| 관심사 | 위치 |
|---|---|
| 칩 엔티티 | `src/models/entities/HomeSectionFeaturedSkillsTab.ts` |
| 컨테이너 게이팅(①A/B) | `src/services/home.ts` L188~232 |
| 칩 메타 조립 | `src/services/home.ts` `getFeaturedSkillsTabsMeta` L597 |
| lazy 엔드포인트 서비스 | `src/services/home.ts` `getFeaturedSkillsTabData` L614 |
| **정렬 seam(=B 주입점)** | `src/services/home.ts` `fetchSkillListBySectionType` L540 (tagSkills+subKey L558~573, recentPurchased L590) |
| cap/hasMore | `src/services/home.ts` `capFeaturedSkillsTabData` L723~775 |
| lazy route | `src/controllers/home.ts` L40~46 (`GET /featured-skills-tab/:tabSeq`) |
| DTO | `src/dtos/home.dto.ts` (FeaturedSkillsTabMeta L37, 응답 L55) |
| config(슬롯 수) | `src/common/config.ts` L794~800 (vertical7/horizontal8, default horizontal) |
| 하부: 태그 칩 쿼리 | `src/services/fixed-menu.ts` `getFixedMenusByTagName` L877 (priority ASC L901) |
| 하부: 태그 섹션 조립 | `src/services/today-tag-skills.ts` L11 |
| 하부: recentPurchased 배치 | `src/services/user-purchased-skill.ts` L77 (@Airflow `POST /api/fixed-menus/recent-purchased-skills/refresh`) |
| 하부: recentPurchased 서빙 | `src/services/fixed-menu.ts` `getRecentPurchasedSkillsSectionData` L2665 |
| Android 측 계약 | PR #1128 (Retrofit `getFeaturedSkillsTabData`, `FeaturedSkillsTabMeta`, img_num 뱃지) |

---

## 검증 (정정)

- ✅ **칩 매핑은 더 이상 추정 아님** — 칩은 `HomeSectionFeaturedSkillsTab` 행으로 명시 저장(targetSection, targetSectionTag). 실제 운영 칩 구성(어떤 라벨/섹션/태그가 1차 5섹션에 매핑되는지)은 운영 DB `home_section_featured_skills_tab` 조회로 확정 가능(설계 비블로킹).
- 🟣 base 단위 바인딩(60하트 vs 750원) — D-5, /dev-data.
- 🟣 ②랭킹 A/B variant 주입 신호(별도 Hackle 키?)·featuredSkillsTabs 내 정렬 토글 위치 — S5 설계 대상.
