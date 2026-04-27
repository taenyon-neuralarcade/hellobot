# 진행 상태

**프로젝트**: 20260423-admin-performance
**시작**: 2026-04-23
**상태**: 서버 구현 완료 · PR 대기

## 파트별 현황

| 파트 | 담당 | 상태 | 브랜치 | 워크트리 | 비고 |
|---|---|---|---|---|---|
| 서버 (assets 오버라이드·프리빌드·compression) | `/dev-server` | **구현 완료** | `feat/admin-performance` | `projects/20260423-admin-performance/worktrees/hellobot-server` | 빌드 통과, PR 대기 |
| 인프라 (진단·ISS-001) | `/dev-infra` | 조사 대기 | — | — | 본 프로젝트 AdminJS 해결엔 직접 변경 불필요. ISS-001 별도 |
| QA | `/qa` | 대기 | — | — | dev 배포 후 체감 테스트 |

## 블로커

- 없음

## 확정 사항

- **근본 원인**: dev Secrets Manager `hlb/dev/api-*` 에 `NODE_ENV=test` 로 설정되어 있어 AdminJS 가 development 번들(32MB) 을 서빙. `components.bundle.js` 도 매 요청 재빌드
- **주입 경로**: Secrets Manager → CSI → `/mnt/secrets-store/hellobot-api.json` → `/app/conf/.env.json` → `src/common/dotenv-json.ts` → `process.env.NODE_ENV`
- **해결 원칙 (최종)**: `process.env.NODE_ENV` 값은 **읽지도 쓰지도 않는다**. AdminJS 가 `NODE_ENV === 'production'` 일 때 하는 두 가지 동작을 직접 선언적으로 수행:
  1. `Router.assets` 배열에서 `.development.js` 로 끝나는 src 를 `.production.js` 로 치환 (production 번들 서빙)
  2. `userComponentsBundler(admin, { write: true })` 직접 호출 (components.bundle.js 프리빌드)
- **ALB 는 pass-through**: ingress 레벨 압축 불가 → 원서버 `compression` 미들웨어로 해결
- **별도 이슈 ISS-001**: `NODE_ENV=test` 설정 자체의 적절성 조사 — 본 프로젝트 내 조사 과업으로 포함

## 최근 업데이트

- 2026-04-23 (1차): 프로젝트 개설, 원인 분석 완료, 에이전트별 과업 분할
- 2026-04-23 (2차): NODE_ENV=test 확인 → 해결 방식을 "Secrets Manager 수정" 에서 "서버 bootstrap 파일(NODE_ENV 위장)" 로 전환. ISS-001 등록
- 2026-04-23 (3차): 서버 접근 재검토. **NODE_ENV 위장 폐기**. `Router.assets` 직접 오버라이드 + `userComponentsBundler` 직접 호출로 변경 → 더 명시적, import 순서 무관, 운영 회귀 리스크 낮음
- 2026-04-24: 서버 파트 구현 완료. 워크트리 생성, `src/admin/force-production-assets.ts` 신규, `src/server.ts`·`src/admin/build-router.ts` 수정, `compression` 의존성 추가, `npm run tsc` 통과. 리포 `docs/features/20260423-admin-performance/status.md` 기록
- 2026-04-24 (2차): `/review` 결과 반영. ISS-002 (운영 중복 호출) 해결 — `preBundleAdminJsComponents` 에 디스크 캐시 skip 가드 추가. 리포 `readme.md` 작성. 빌드 재검증 통과
