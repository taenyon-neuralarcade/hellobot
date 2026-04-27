# 과업 목록

## 인프라 — `/dev-infra`

> 본 프로젝트의 **AdminJS 해결을 위한 인프라 변경은 없음**. dev Secrets Manager 의 `NODE_ENV` 를 직접 건드리는 것은 부적절(ISS-001 참조). 아래는 진단·후속 조사 과업.

- [ ] dev↔prod Secrets Manager 키 집합 diff 를 `planning/secrets-diff.md` 에 기록 (민감값 제외, 키 이름만)
- [ ] **ISS-001**: `NODE_ENV=test` 가 dev Secrets Manager 에 존재하는 이유 조사 및 사용자 협의 후 방침 결정 (유지 / 제거 / `development` 로 변경)
- [ ] 방침 확정 후 AWS Console 에서 Secrets Manager 수정 + Deployment 롤링 재시작 (사용자 승인 후)

## 서버 — `/dev-server`

> **접근 원칙**: `process.env.NODE_ENV` 값은 절대 수정하지 않는다. AdminJS 가 `NODE_ENV === 'production'` 일 때 하는 두 가지 동작(①`.production.js` 번들 서빙, ②사용자 컴포넌트 프리빌드) 을 NODE_ENV 와 무관하게 우리가 직접 선언적으로 수행하도록 유도한다. 이 접근은 `Router.assets` 배열과 `userComponentsBundler` 함수만 건드리므로 `NODE_ENV=test` 를 그대로 유지하면서 정확히 원하는 동작만 얻는다.

- [x] 워크트리 생성: `projects/20260423-admin-performance/worktrees/hellobot-server` (브랜치 `feat/admin-performance`)
- [x] **[A1]** `src/admin/force-production-assets.ts` 신규 생성 — `AdminJSRouter.assets` 배열 순회하며 `.development.js` 로 끝나는 src 를 `.production.js` 로 치환. fs.existsSync 로 파일 존재 검증·winston 로그
- [x] **[A2]** 같은 파일에 `preBundleAdminJsComponents(admin)` 함수 — `require("adminjs/lib/backend/bundler/user-components-bundler").default` 를 직접 호출해 `{ write: true }` 로 디스크 캐시
- [x] **[A3]** `src/server.ts` `runAdminPage()` 에서 `new AdminJS(...)` 직후 `forceAdminJsProductionAssets()` 호출 + `preBundleAdminJsComponents(adminJS)` fire-and-forget
- [x] **[F]** `src/admin/build-router.ts` 최상단에 `compression()` 적용. `package.json` 에 `compression` + `@types/compression` 의존성 추가
- [x] **[선택]** `src/admin/build-router.ts` 에 `/frontend/assets/*` 경로 `Cache-Control: public, max-age=3600` 미들웨어 추가
- [x] `npm run tsc` 로 타입체크 통과 확인
- [ ] PR 생성 후 CI 통과 확인
- [ ] dev 배포 후 `design-system.bundle.js` Content-Length 로 동작 검증 (5.7MB 기대)
- [ ] 서버 로그에 부팅 시 `AdminJS: forced N asset(s) to production bundle` + `AdminJS: user components pre-bundled` 출력 확인

## 검증 — `/qa` · 사용자

- [ ] dev admin `/admin/resources/Payment` 재방문 시 Chrome Network 총 Load < 10초
- [ ] `design-system.bundle.js` Content-Length ≈ 5.7MB (production 번들)
- [ ] `components.bundle.js` 2차 요청 TTFB < 1초
- [ ] 기프티엘 쿠폰 사용취소 액션 왕복 시간 측정 (외부 벤더 응답 제외한 서버 지연)
- [ ] 운영 admin 회귀 없음 확인 (배포 후 첫 사용 시)

## 이슈 기록

진행 중 발견되는 이슈는 `issues.md` 에 ISS-NNN 으로 등록.

### 후속 과업

- [x] **ISS-002**: `preBundleAdminJsComponents` 안에 outPath 존재 시 skip 가드 추가 (2026-04-24)
- [x] `docs/features/20260423-admin-performance/readme.md` 작성 (2026-04-24)
