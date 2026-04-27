# AdminJS 운영자 UI 성능 개선

## 배경

hellobot-server의 AdminJS 기반 운영자 웹(`/admin`)이 **개발 환경에서 초기 로드 3.6분**이 걸려 운영 업무가 사실상 불가능한 상태. 운영(api.hellobot.co)은 약 2초로 정상 동작.

## 근본 원인 (규명 완료)

1. **dev 환경의 `NODE_ENV` 누락** (주요): AdminJS는 `NODE_ENV === "production"` 일 때 미리 minify 된 production 번들(`bundle.production.js` 5.7MB)을 서빙, 아니면 development 번들(`bundle.development.js` 32MB)을 서빙.
   - 확인된 사실: k8s 매니페스트에는 NODE_ENV 설정이 없고, **AWS Secrets Manager `hlb/prod/api-*` JSON** 에 포함되어 이미지 `/app/conf/.env.json` 경로로 주입되어 process.env에 반영됨 (`src/common/dotenv-json.ts`)
   - dev 환경 Secrets Manager `hlb/dev/api-*` 에는 `NODE_ENV` 가 없음 → dev pod의 `process.env.NODE_ENV` 가 undefined → development 번들 서빙
2. **`components.bundle.js` 매 요청 재빌드**: NODE_ENV가 production이 아니면 AdminJS 가 부팅 시 번들을 프리빌드·캐시하지 않고 매 요청마다 Rollup 재빌드(약 30초)
3. **압축 미적용**: `compression` 미들웨어 부재로 대용량 번들이 그대로 전송. 운영에서는 번들이 작아서 드러나지 않지만, 번들이 커지면 운영도 동일 증상 발생 가능

## 목표

- dev AdminJS 초기 로드: 3.6분 → **5초 이내** (운영 수준)
- 운영 AdminJS는 현 상태 유지하되 인프라 변경 시에도 안정적으로 동작하도록 방어 코드 추가

## 솔루션 개요

| # | 조치 | 담당 | 필수 여부 |
|---|---|---|---|
| 1 | `hlb/dev/api-*` Secrets Manager JSON 에 `NODE_ENV=production` 추가 + pod 재기동 | `/dev-infra` | 필수 (P0) |
| 2 | `src/server.ts` 에서 `userComponentsBundler(adminJS, { write: true })` 부팅 시 호출 (NODE_ENV 미세팅 상황 방어) | `/dev-server` | 권장 (P1) |
| 3 | admin 라우터 상위에 `compression()` 미들웨어 추가 | `/dev-server` | 권장 (P1) |

## 측정·검증 기준

- dev admin `/admin/resources/Payment` 로드 시 `design-system.bundle.js` **Content-Length ≈ 5.7MB** 로 축소 확인
- Chrome DevTools Network 총 Load 시간 **10초 이내**
- `components.bundle.js` TTFB **1초 이내** (pod 재기동 후 첫 요청)
- 운영 admin은 기존 대비 회귀 없음

## 관련 문서

- 분석 근거: 이 프로젝트 `planning/analysis.md` (이 대화 분석 요약)
- `/dev-infra` 에이전트: `.claude/commands/dev-infra.md` §알려진 사실에 NODE_ENV 주입 메커니즘 확정
- 배포 구조: `docs/architecture.md` §배포 §인프라 리포지토리
