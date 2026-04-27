# AdminJS 성능 분석 요약

> 2026-04-23 조사 결과를 1회성 분석 문서로 보관. 구현 기록이 아닌 **원인 판정 근거**를 남기기 위한 용도.

## 1. 증상

- **개발 서버 admin**: `/admin/resources/{resource}` 직접 방문 시 초기 로드 **3.6분** (Chrome Network, Preserve log, Disable cache)
- **운영 서버 admin** (`api.hellobot.co/admin/...`): 동일 페이지 **약 2초**
- 로그인 직후, 각종 리소스 페이지 진입, 기프티엘 쿠폰 사용취소 후 리스트 리로드 등 **대부분의 전환**에서 체감 지연

## 2. 네트워크 타임라인 핵심 수치

| 리소스 | 개발 Content-Length | 개발 Time | 운영 Content-Length | 운영 Time |
|---|---|---|---|---|
| `design-system.bundle.js` | **32,794 kB** | **32.17 s** | **5,736 kB** | ~1-2 s |
| `global.bundle.js` | 5,378 kB | 21.89 s | — | — |
| `components.bundle.js` | 4,140 kB | 29.96 s | — | — |
| `app.bundle.js` | 1,869 kB | 1.71 s | — | — |
| `list` XHR (DB 쿼리) | 11.4 kB | **61 ms** | — | — |

**해석**: DB 쿼리·백엔드 API 지연 아님. **서버 응답이 정적 번들 다운로드 단계에서 지연**. 특히 `components.bundle.js` 는 서버 측에서 Rollup 재빌드 중.

## 3. 코드 근거

### (a) AdminJS 의 환경별 번들 분기

`node_modules/adminjs/lib/backend/bundler/bundler-env.js`:
```js
const env = process.env.NODE_ENV === 'production' ? 'production' : 'development';
```

`node_modules/adminjs/lib/backend/utils/router/router.js:52-59`:
```js
{ path: '/frontend/assets/app.bundle.js',           src: `scripts/app-bundle.${env}.js` }
{ path: '/frontend/assets/global.bundle.js',        src: `scripts/global-bundle.${env}.js` }
{ path: '/frontend/assets/design-system.bundle.js', src: `../bundle.${env}.js` }
```

`node_modules/@adminjs/design-system/` 에 두 번들 공존 확인:
- `bundle.development.js` = **32,757,245 bytes** (개발 Content-Length 와 정확히 일치)
- `bundle.production.js` = **5,736,382 bytes** (운영 Content-Length 와 정확히 일치)

### (b) `components.bundle.js` 온디맨드 빌드

`node_modules/adminjs/lib/adminjs.js:176-184`:
```js
async initialize() {
  if (process.env.NODE_ENV === 'production' && !(process.env.ADMIN_JS_SKIP_BUNDLE === 'true')) {
    await userComponentsBundler(this, { write: true });  // 디스크 캐시
  }
}
```

NODE_ENV !== 'production' 이면 프리빌드 안 함 → 매 요청마다 Rollup 재실행 (30초).

### (c) env 주입 경로

- `src/common/env.ts` + `src/common/dotenv-json.ts` 가 `/app/conf/.env.json` 을 읽어 `process.env[key] = process.env[key] || json[key]`
- Dockerfile 의 `COPY conf /app/conf` 로 이미지에 포함. 단, 레포 `conf/` 는 비어있음 → **운영 빌드 과정에서 별도 주입**

### (d) k8s 매니페스트에 NODE_ENV 없음

- `common-infra-eks-deploy/overlays/hlb/prod/api/hlb-api-deployment-patch.yaml` — `NODE_ENV` grep hit 없음
- `common-infra-eks-deploy/overlays/hlb/dev/apn2/api/hlb-api-deployment-patch.yaml` — 동일
- `base/hlb/api/`, `base/dev/hlb/api/` — 동일

### (e) AWS Secrets Manager 에서 주입 (사용자 확정)

- `hlb/prod/api-*` Secrets Manager JSON 에 `NODE_ENV=production` 포함 → CSI driver 로 `/mnt/secrets-store/hellobot-api.json` 에 마운트 → `/app/conf/.env.json` 경로로 제공되어 dotenv-json 이 주입
- `hlb/dev/api-*` Secrets Manager JSON 에는 `NODE_ENV` 가 **없음** → dev pod 에서 AdminJS development 번들 서빙

## 4. 배제된 가설

| 가설 | 판정 | 근거 |
|---|---|---|
| DB 쿼리 지연 (리소스 인덱스 부족 등) | 기각 | `list` XHR 61ms |
| 세션 / Redis I/O | 기각 | HTML shell TTFB 789ms로 정상 |
| AdminJS 초기 렌더링 느림 (107개 리소스) | 부분기각 | HTML 렌더는 빠름 (2MB, 1초 내) |
| 운영이 CloudFront 로 가려져서 빠른 것 | 기각 | 응답 헤더에 `X-Powered-By: Express`, `Via/CloudFront` 헤더 없음, Remote Address 가 오리진 IP |
| 개발 서버에만 APM 오버헤드 | 부분 유효 | dev APM 켜져 있지만 main bottleneck 아님 |

## 5. 해결 방향 (P0~P2)

| 순위 | 조치 | 담당 | 변경 범위 |
|---|---|---|---|
| P0 | `hlb/dev/api-*` Secrets Manager JSON 에 `NODE_ENV=production` 추가 → pod 재기동 | `/dev-infra` | AWS Console 1회, Git 변경 없음 |
| P1 | `runAdminPage()` 에서 `userComponentsBundler(adminJS, { write: true })` 부팅 프리빌드 호출 | `/dev-server` | `src/server.ts` |
| P1 | admin 라우터 상위에 `compression()` 미들웨어 적용 | `/dev-server` | `src/admin/build-router.ts`, `package.json` |
| P2 | admin 정적 asset 에 `Cache-Control` 헤더 부여 | `/dev-server` | `src/admin/build-router.ts` |

P0 만 해도 증상이 사라질 가능성이 높지만, P1 은 NODE_ENV 를 앞으로도 놓치지 않기 위한 방어. 두 가지 모두 반영을 권장.
