# S1 — 인기스킬 섹션 현황 (As-Is)

> 스텝: S1 (현황 파악) · 작성: 2026-06-04
> 대상: hellobot-server / PR [#2414](https://github.com/thingsflow/hellobot-server/pull/2414) (MERGED 2026-05-18)
> 상위: [execution-steps.md](execution-steps.md) · 소스: [overview-notes.md](overview-notes.md)
> 조사 방식: `gh pr view/diff` + 로컬 master 코드 추적 (로컬 master는 PR #2414 머지 전 stale — 산출 파일은 gh로 확인)

---

## 한 줄 요약

**PR #2414는 랭킹 자동화가 아니라, 기존 12종 스킬 리스트 섹션을 칩(탭) UI 하나로 묶는 노출 컨테이너 `featuredSkillsTabs` + 점진 공개(FeatureFlag·핵클 A/B)를 만들었다.** 칩이 가리키는 섹션들은 여전히 운영자 수동 큐레이션. → **Phase #2의 일은 이 그릇(칩/섹션) 뒤에 "필터링 + 랭킹"의 실체를 채우는 것.**

> PR 제목: `feat(home): featuredSkillsTabs 섹션 추가 (FeatureFlag + 핵클 A/B)`. 디렉토리명은 `home-rank-skill-section`(랭킹 의도)이나 구현 중 `RankSkillTab → featuredSkillsTabs`로 리네임 — **"랭킹"은 네이밍 흔적만 남고 실제 랭킹 계산 로직은 미포함.** 이 PR이 사용자가 언급한 "선행 A/B UI 작업"으로 추정.

---

## 1. 노출 컨테이너 구조

- **`featuredSkillsTabs`** = 새 섹션 타입. 칩(탭) 1개 = `HomeSectionFeaturedSkillsTab` 테이블 1 row.
  - 필드: `homeSectionSeq`(FK→HomeSection) / `targetSection`(어느 섹션 타입을 보여줄지) / `targetSectionTag`(태그 필터, nullable) / `label` / `order` / `showRanking`(bool, default true).
- 칩 클릭 시 lazy 로드: `GET /api/home/featured-skills-tab/:tabSeq` → `HomeService.getFeaturedSkillsTabData`.
- 통합 홈 데이터: `GET /api/home/?sections=…` → `HomeService.getTabData`.
- **노출 분기**(`getTabData`): `supportsClient`(Android≥2.43.0 / iOS≥2.54.0 / Web) → 마스터 FeatureFlag → public FeatureFlag → 핵클 키 18(treatment B) → `featuredSkillsTabs` ↔ 기존 `recentPurchasedSkills` **배타적** 응답.

## 2. 섹션이 채워지는 방식 (수동 큐레이션 경로)

| 경로 | 무엇 | 어디서 |
|------|------|--------|
| 어떤 탭에 어떤 섹션이 뜨나 | `HomeSection` 테이블 row (section 키 / order / homeTabSeq) | 어드민 "홈 → 홈 섹션 관리"에서 운영자 수동 등록 |
| 통합 섹션의 칩 목록 | `HomeSectionFeaturedSkillsTab` row | 어드민 "추천 스킬 탭 관리"(super 전용) 수동 등록 |
| 각 섹션의 스킬 콘텐츠 | 섹션 타입별 채움 로직 | 코드(섹션마다 제각각) |

→ **칩·섹션 구성 자체가 100% 수동.** 자동화 대상의 기준선.

## 3. "인기스킬" 섹션의 실체 = `recentPurchasedSkills` (반자동)

- 운영자가 스킬을 하나하나 고르는 게 아니라 **최근 구매 기준 자동 집계 + pinned 수동 상위 고정**의 하이브리드.
- 소스: Redis `recent-purchased-skills:data:latest`(배치 적재) → miss 시 DB 폴백 `getRecentPurchasedSkillSeqsFromDB` (`user_purchased_skill` × `snapshot_fixed_menu`, 유효가 ≥ minPrice 60, 최근 구매 DESC).
- `config.recentPurchasedSkills.pinnedSkillSeqs`(현재 `[]`)를 상위 고정.
- **함의**: "실시간 인기"는 이미 구매량 기반 반자동이지만, **사주/타로/재물운 등 다른 섹션은 태그 큐레이션 수동**. Phase #2가 노리는 자동 랭킹+메타 필터링은 후자에 아직 없음.

## 4. 필터링 현황

- **섹션 선택 필터**: 버전+flag+핵클 분기 (`getTabData`의 `filteredSections`).
- **섹션별 콘텐츠 필터**: 전부 **하드코딩** — 위치가 제각각.
  - `recentPurchasedSkills`: minPrice·original·os 조건이 SQL에.
  - 태그 섹션: 노출 태그가 `TodayTagSkillsTag` 테이블에, 태그→스킬 매칭이 `getFixedMenusByTagName`(`FixedMenuTag` 조인 + visible + priority ASC)에.
  - 칩 단위: `targetSectionTag`로 결과를 `tag === subKey` 1차 필터.
- **통합된 "필터 정의 레이어"는 없음** (config 상수 / SQL / 큐레이션 테이블에 분산) → S5 아키텍처의 핵심 과제.

## 5. 섹션 인벤토리 (기획 예시 ↔ As-Is)

> ⚠️ 사주/타로/재물운 등 "필터링된 섹션"의 진짜 정의 소스는 **코드 상수가 아니라 운영 DB `TodayTagSkillsTag`(노출 태그) + `FixedMenuTag`(스킬 태그)**.

| 기획 예시 | As-Is 대응 | 정의 위치 |
|-----------|-----------|-----------|
| 실시간 인기 | `recentPurchasedSkills` | Redis 배치 + SQL + pinned |
| 신규 인기 | 직접 키 없음 (`newSkillBanner`/`personalRecommendedSkill` 유사) — **불확실** | — |
| 사주·타로·솔로 애정운·짝사랑/썸·커플 궁합·재물운·재회·솔로 결혼운·커플 결혼 궁합 | 태그 섹션 `recommendedTagSkills`/`freeTagSkills`/`popularTagSkills` | `TodayTagSkillsTag`(섹션+태그+turn 수동 등록) → `getFixedMenusByTagName` |
| 1:1 상담 | 태그명 등록 가능성 — **불확실(DB 의존)** | `TodayTagSkillsTag` row 확인 필요 |

- 칩 `targetSection` 화이트리스트(12종): `recentPurchasedSkills`, `recommendedTagSkills`, `freeTagSkills`, `popularTagSkills`, `appFree`, `todayFree`, `tomorrowFree`, `categorySkills`, `personalRecommendedSkill`, `frequentlyUsedSkills`, `skillHistory`, `premiumSkillHistory`.

## 6. 스킬 메타데이터 현황 (필터링 가능성)

스킬 엔티티 = `FixedMenu` (스냅샷 `SnapshotFixedMenu`).

| 기획 필터축 | 존재 | 위치 |
|-------------|------|------|
| 태그(tag) | ✅ | `FixedMenuTag` ↔ `FixedMenu` (M:N, priority 보유). **현 큐레이션 주 메타축** |
| 카테고리(category) | ✅ (트리) | `SnapshotFixedMenuCategory` + join. `categorySkills` 섹션이 사용 |
| 세그먼트류 targets/subjects/contentTypes | ✅ (text[] 배열) | `FixedMenu.targets/subjects/contentTypes`. `getPersonalRecommendedSkill`이 `@> ARRAY[...]`로 사용 |
| **관심사(topic) 전용 필드** | ❌ | 없음 — `FixedMenuTag`/`subjects`가 의미상 대용 |
| **의도(intent) 전용 필드** | ❌ | 없음 — 검색 도메인(`SearchTag` 등)에 유사물 있으나 홈 섹션과 직접 연결 안 됨(불확실) |

→ **카테고리·태그·세그먼트는 존재. 기획이 말한 "topic/intent" 이름의 전용 메타는 없음.** S4에서 기존 tag/subject 재활용 vs 신규 메타축 추가를 결정해야 함.

## 7. 다음 스텝용 핵심 파일 레퍼런스

**노출 컨테이너/분기 (S5)**: `src/services/home.ts`(`getTabData`, `getFeaturedSkillsTabData`, `getFeaturedSkillsTabsMeta`, `fetchSkillListBySectionType`, `capFeaturedSkillsTabData`), `src/controllers/home.ts`, `src/dtos/home.dto.ts`, `src/models/entities/{HomeSectionFeaturedSkillsTab,HomeSection,HomeTab}.ts`, `src/services/feature-flag.ts`, `src/common/hackle`, `src/common/config.ts`(`today.sections`, `today.tagSkills`, `recentPurchasedSkills`, `featuredSkillsTabs`)
**랭킹 소스 (S3)**: `src/services/fixed-menu.ts`(`getRecentPurchasedSkillsSectionData`, `getPersonalRecommendedSkill`), `src/services/user-purchased-skill.ts`(`getRecentPurchasedSkillSeqsFromDB`)
**필터/태깅 (S4)**: `src/services/today-tag-skills.ts`, `src/services/fixed-menu.ts`(`getFixedMenusByTagName`, `getCategories`), `src/models/entities/{TodayTagSkillsTag,FixedMenuTag,FixedMenu,SnapshotFixedMenuCategory}.ts`, `src/common/enum.ts`(`FixedMenuCategorySubject`)
**어드민**: `src/admin/options/{HomeSection,HomeSectionFeaturedSkillsTab}.options.ts`, `src/admin/views/HomeSectionFeaturedSkillsTab/...`
**PR 산출 문서**: `docs/features/20260511-home-rank-skill-section/{backend-design,api-spec,admin-guide,client-guide}.md`

## 8. 각 후속 스텝에 주는 함의

- **S2 (개념 구조)**: 그릇(`featuredSkillsTabs` 칩)은 이미 있음. 각 칩 = `targetSection`(+태그). "랭킹 1종 + 섹션별 필터"가 이 구조에 자연스럽게 맞음 — 단 `showRanking` 플래그가 칩별로 있어 "랭킹 적용/미적용"을 칩 단위로 켤 수 있음. 랭킹 1개 vs 다수 논의의 입력.
- **S3 (랭킹)**: 이미 `recentPurchasedSkills`가 구매량 반자동. 랭킹 자동화는 **이걸 일반화**하는 방향. 단 **랭킹 배치(Redis 적재) 위치가 어디인지(server cron / airflow / mwaa) 미확인** — S3 선행 조사 필요.
- **S4 (필터/태깅)**: 섹션 정의가 코드가 아니라 **운영 DB(`TodayTagSkillsTag`/`FixedMenuTag`)**. topic/intent 전용 메타는 없음 → "기존 태그 체계 재활용 vs 신규 메타축"이 핵심 결정. + 현 태그 큐레이션이 적절한지 데이터 검증.
- **S5 (아키텍처)**: 통합 필터 정의 레이어 부재 + 섹션별 하드코딩이 가장 큰 기술 부채. "리스트+필터 조건을 어떻게 관리"가 여기서 풀려야 함.
- **S6 (범위/일정)**: 노출 컨테이너가 이미 머지됨 → Phase #2는 그 위 자동화. 영향 리포는 hellobot-server 중심 + 랭킹 배치 위치 따라 data/infra.

## 9. 불확실 · 추가 조사 필요 (후속 스텝에서)

1. 로컬 master가 PR #2414 머지 전 stale → S3~S5 진입 전 `git fetch` 후 실제 머지 SHA·후속 핫픽스 확인.
2. "신규 인기"·"1:1 상담" 섹션 정체 — `TodayTagSkillsTag` 실제 DB row + `newSkillBanner`/`personalRecommendedSkill` 동작 확인 필요(코드만으론 불확실).
3. 기획 예시 섹션(재물운/짝사랑/재회 등) ↔ 실제 태그명 매핑 — 운영 DB `TodayTagSkillsTag.tag`/`FixedMenuTag.name` 덤프 필요.
4. topic/intent 메타 부재 확정도 — 검색 도메인(`SearchTag`, `SearchHistoryTagMatching`)에 재사용 가능한 의도/관심사 데이터 있는지 미조사.
5. **랭킹 배치 출처** — `recent-purchased-skills:data:latest` Redis 키 적재 배치 위치(server cron / common-data-airflow / hellobot-mwaa) 미확인. S3 선행.
6. 핵클 키 18 운영 상태(현 flag 값·분배 비율) — 코드 밖(운영 DB·핵클 대시보드).
