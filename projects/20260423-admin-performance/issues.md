# 이슈 레지스트리

| ID | 분류 | 상태 | 제목 |
|---|---|---|---|
| ISS-001 | edge-case | 미해결 | dev pod 의 `NODE_ENV=test` 설정 |
| ISS-002 | enhancement | 해결 (2026-04-24) | `preBundleAdminJsComponents` 가 운영에서 `admin.initialize()` 와 중복 실행됨 |

---

## ISS-001 — dev pod 의 `NODE_ENV=test` 설정

**분류**: edge-case (설계에서 고려하지 못한 예외 · 환경 위생)
**상태**: 미해결
**발견일**: 2026-04-23
**발견자**: `/dev-infra` (사용자 확인으로 드러남)

### 현상

hellobot-server dev 파드의 `process.env.NODE_ENV` 값이 **`test`** 로 설정되어 있음.
- 주입 경로: AWS Secrets Manager `hlb/dev/api-*` JSON → CSI 마운트 → `/app/conf/.env.json` → `src/common/dotenv-json.ts`
- 운영 pod 의 값은 `production` 으로 확인됨

### 원인 추정

- 과거에 어떤 이유로 dev Secret 을 작성할 때 `test` 로 넣은 뒤 그대로 방치된 것으로 보임. 명시적 설계 근거는 미확인
- Jest·Mocha 가 실행 중 자동으로 `NODE_ENV=test` 를 세팅하는 관습에서 복사된 값일 가능성

### 영향

- **확인된 영향**: AdminJS 가 development 번들(32MB)을 서빙 → dev 어드민 초기 로드 3.6분 (이 프로젝트의 본 과제)
- **잠재적 영향**: Node.js 생태계에서 `test` 는 테스트 러너 전용 관습 값이라, dev 가 운영처럼 관측되지 않는 숨은 분기가 있을 가능성
  - elastic-apm-node: 일부 transaction 무시 가능
  - winston/morgan: 로깅 수준·transport 생략 가능
  - 분석·메시징 클라이언트: production 이 아니면 no-op 처리 가능
  - 아직 dev 전체 소스에서 실제 `NODE_ENV === 'test'` 분기를 스캔하지는 않음 — 조사 필요

### 권장 조치 (사용자 협의 후 진행)

1. **조사**: hellobot-server + 주요 dependency 에서 `NODE_ENV` 가 어떻게 쓰이는지 전수 검토
   ```bash
   grep -rn "NODE_ENV" hellobot-server/src
   # 의존 라이브러리에서 NODE_ENV=test 분기를 가진 것이 있는지 스팟 체크
   ```
2. **가설 A (권장)**: dev Secrets Manager 에서 `NODE_ENV` 키를 **제거** → `process.env.NODE_ENV` 가 undefined → 대부분 라이브러리의 기본값(대체로 development 동등) 동작
   - 장점: dev 가 실제로 "개발 환경"으로 동작, 운영과 가장 가깝되 dev 전용 관측성·경고 유지
   - 단점: undefined 를 가정하지 않은 코드가 있을 수 있음 (조사로 확인)
3. **가설 B**: `NODE_ENV=development` 로 명시 변경 — Node.js 표준 관습
   - 장점: 명시적, 가설 A 보다 예측 가능
   - 단점: 만약 어떤 코드가 `NODE_ENV === 'development'` 를 조건으로 쓰면 추가 동작이 생길 수 있음
4. **가설 C (비권장)**: 그대로 `test` 유지. 단 본 프로젝트의 AdminJS 해결은 `/dev-server` bootstrap 패턴으로 진행

### 해결 절차 (가설 A 또는 B 선택 시)

`/dev-infra` 과업:
- AWS Console → Secrets Manager → `hlb/dev/api-*` 편집 → `NODE_ENV` 키 제거(A) 또는 값 `development` 로 변경(B)
- dev hlb-api Deployment 롤링 재시작 (사용자 승인 후)
- 변경 전/후 `process.env.NODE_ENV` 값이 예상대로 바뀌었는지 검증 (서버 로그나 `/api/health-check` 응답에 반영하는 방법은 `/dev-server` 상의)

### 참고

- `.claude/commands/dev-infra.md` §알려진 사실 "hellobot-server env 주입의 진실"
- 본 프로젝트 `planning/analysis.md`

---

## ISS-002 — `preBundleAdminJsComponents` 가 운영에서 `admin.initialize()` 와 중복 실행됨

**분류**: enhancement (구현 개선 — 회귀 아님)
**상태**: 해결 (2026-04-24)
**발견일**: 2026-04-24
**발견자**: `/review`
**해결자**: `/dev-server`

### 현상

`@adminjs/express/lib/buildRouter.js:17-19` 가 `admin.initialize().then(() => log.debug("AdminJS: bundle ready"))` 를 fire-and-forget 으로 자동 호출한다.

운영 환경에서는 `NODE_ENV === 'production'` 이므로 이 `initialize()` 가 내부적으로 `userComponentsBundler(admin, { write: true })` 를 호출해 사용자 컴포넌트를 프리빌드한다.

이번 변경에서 추가된 `runAdminPage()` 의 `preBundleAdminJsComponents(adminJS)` 도 동일한 함수를 호출 → **운영 부팅 시 같은 빌드가 두 번 트리거**될 수 있음.

### 영향

- **기능 영향 없음**: `userComponentsBundler` 가 idempotent 한 빌드라 결과 파일은 같음
- **부팅 비용**: 두 빌드가 거의 동시에 시작되어 CPU·메모리 spike 가능 (Rollup 컴파일은 30초 내외, 메모리 수백 MB 사용)
- **로그 noise**: "AdminJS: bundle ready" + "AdminJS: user components pre-bundled" 두 줄이 거의 동시에 찍힘
- dev 환경에서는 `admin.initialize()` 가 NODE_ENV 체크로 스킵되므로 우리 호출만 동작 → 의도대로 작동

### 권장 조치 (택 1)

**옵션 A (권장)**: `preBundleAdminJsComponents` 안에서 outPath 존재 시 skip 가드 추가
```ts
import { outPath as USER_COMPONENTS_OUT_PATH } from "adminjs/lib/backend/bundler/user-components-bundler";

export async function preBundleAdminJsComponents(admin: unknown): Promise<void> {
  // 다른 호출자(예: AdminJSExpress.buildRouter → admin.initialize)가 이미 빌드했다면 skip
  if (fs.existsSync(USER_COMPONENTS_OUT_PATH)) {
    return;
  }
  // ... 기존 require 호출
}
```
- 장점: race 자체를 회피, NODE_ENV 검사 없이 환경 무관하게 동작
- 단점: outPath 가 internal export라 adminjs 버전업 시 경로 변경 가능 (path.join('/tmp/adminjs', 'bundle.js') 로 직접 구성도 가능)

**옵션 B**: dev 환경 한정 호출 — `if (process.env.NODE_ENV !== "production") { void preBundle... }`
- 장점: 운영 중복 호출 완전 제거
- 단점: NODE_ENV 검사를 도입 — 본 프로젝트의 "NODE_ENV 안 건드림" 원칙과 모순

**옵션 C (수용)**: 그대로 둠. 부팅 시 30초 추가 비용·로그 noise 정도는 수용
- pod 부팅 빈도가 낮고 readiness probe 영향 없으므로 실용적 영향 없음

### 권장 결정

**옵션 A**. NODE_ENV 분기를 도입하지 않고도 race 를 회피. outPath internal export는 호환성 우려가 있지만 fallback (직접 path.join) 으로 가드 가능.

### 해결 내역 (2026-04-24)

옵션 A 채택. `src/admin/force-production-assets.ts` 에 다음 추가:

```ts
const USER_COMPONENTS_BUNDLE_PATH = path.join(process.cwd(), ".adminjs", "bundle.js");

export async function preBundleAdminJsComponents(admin: unknown): Promise<void> {
  if (fs.existsSync(USER_COMPONENTS_BUNDLE_PATH)) {
    winston.info(`AdminJS: components bundle already cached, skipping pre-build (...)`);
    return;
  }
  // ... 기존 require + 빌드 호출
}
```

- 경로는 adminjs 내부 상수 `ADMIN_JS_TMP_DIR='.adminjs'` 를 직접 가져오지 않고 path.join 으로 명시 (코드 가독성 + internal 모듈 의존성 최소화)
- 운영 환경: `admin.initialize()` 가 먼저 빌드 → 우리 호출은 skip 로그 후 즉시 반환
- 개발 환경: 캐시 없음 → 정상 빌드 진행
