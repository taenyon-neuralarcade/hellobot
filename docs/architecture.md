# HelloBot 서비스 아키텍처

## 서비스 개요

HelloBot은 AI 챗봇 기반 운세/점술 서비스로, 사용자에게 사주, 타로, 궁합 등 다양한 스킬(점술 콘텐츠)을 제공합니다.

## 시스템 구성도

```
┌─────────────────────────────────────────────────────────┐
│                      클라이언트                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │ Android  │  │   iOS    │  │   Web    │  │ Studio  │ │
│  │ (Kotlin) │  │ (Swift)  │  │(Next.js) │  │(Angular)│ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬────┘ │
│       │              │             │              │      │
│  ┌────┴──────────────┴─────┐      │         ┌────┴────┐ │
│  │  WebView (Angular SSR)  │      │         │         │ │
│  │  Report WebView(Next.js)│      │         │         │ │
│  └────┬────────────────────┘      │         │         │ │
└───────┼───────────────────────────┼─────────┼─────────┘
        │                           │         │
        ▼                           ▼         ▼
┌───────────────────────────┐  ┌──────────────────────┐
│    hellobot-server        │  │ hellobot-studio-     │
│    (Node.js/Express)      │  │ server (Spring Boot) │
│                           │  │                      │
│  ┌─────┐ ┌─────┐ ┌─────┐ │  │  ┌───────┐ ┌──────┐ │
│  │ PG  │ │Redis│ │ S3  │ │  │  │MongoDB│ │Redis │ │
│  └─────┘ └─────┘ └─────┘ │  │  └───────┘ └──────┘ │
└───────────┬───────────────┘  └──────────────────────┘
            │
            ▼
┌───────────────────────────┐
│  common-data-airflow      │
│  (Python/Airflow)         │
│         │                 │
│         ▼                 │
│    ┌──────────┐           │
│    │ BigQuery │           │
│    └──────────┘           │
└───────────────────────────┘
```

## 주요 컴포넌트 상세

### 백엔드

#### hellobot-server (메인 API)
- **스택**: Node.js 14 / Express / TypeORM (Active Record) / TypeDI / routing-controllers
- **DB**: PostgreSQL (메인), Redis (캐싱/세션)
- **주요 기능**: 사용자 인증(JWT, OAuth2), 스킬 관리, 결제, 푸시 알림, 관리자 대시보드(AdminJS)
- **외부 연동**: AWS S3/CloudFront, Braze, BigQuery, Google Analytics
- **배포**: Docker → ArgoCD/Kubernetes

#### hellobot-studio-server (스튜디오 API)
- **스택**: Java / Spring Boot 2.1 / Spring Data MongoDB
- **DB**: MongoDB (챗봇 정의/스크립트), Redis, PostgreSQL (동기화용)
- **주요 기능**: 챗봇 생성/편집/배포, 팀/권한 관리, 엑셀 임포트(Apache POI)
- **외부 연동**: AWS S3/SES
- **배포**: ArgoCD/Kubernetes

### 프론트엔드 (웹)

헬로우봇 웹 프론트엔드는 3개 프로젝트가 하나의 도메인(`hellobot.co`)을 나눠 서빙합니다.
Nginx 프록시가 URL 경로에 따라 각 프로젝트로 라우팅합니다.

> 상세 페이지 매핑: [web-page-map.md](./web-page-map.md)

```
hellobot.co (Nginx)
  ├── /features, /skills-new, /daily-fortune, /saju,
  │   /chatrooms-new, /payment, /coupon
  │   → hellobot-web (Next.js, :4500)
  │
  ├── 그 외 대부분의 경로
  │   → hellobot-webview (Angular SSR, :4000)
  │
  └── (별도 도메인) report.hellobot.co
      → hellobot-report-webview (Next.js, :4400)
```

#### hellobot-webview (베이스 — Angular SSR)
- **스택**: Angular 13 / Angular Universal (SSR)
- **역할**: 웹 프론트엔드의 기본 베이스. 대부분의 페이지를 서빙
- **모바일 앱에 WebView로 임베딩**
- **점진적으로 hellobot-web(Next.js)으로 이관 중**
- **담당 영역**: 로그인/회원, 스토어(레거시), 설정, 이벤트, 공지/FAQ 등 80+개 라우트

#### hellobot-web (마이그레이션 대상 — Next.js)
- **스택**: Next.js 14 / React 18 / Tailwind / Redux Toolkit / SWR
- **역할**: hellobot-webview에서 이관된 신규 페이지 담당
- **담당 영역**: 스킬 탐색(/features), 스킬 목록(/skills-new), 일일운세(/daily-fortune), 사주(/saju), 채팅(/chatrooms-new), 결제/쿠폰
- **신규 웹 기능은 이 프로젝트에서 개발**

#### hellobot-report-webview (리포트 전용 — Next.js)
- **스택**: Next.js 14 / React 18 / Tailwind / Reactflow / Recharts
- **역할**: 리포트/분석 페이지 전용. 별도 도메인(`report.hellobot.co`)에서 서빙
- **담당 영역**: 구매 리포트(/report), 궁합 분석(/relationreport), 요약 리포트(/summary-reports), 전시(/exhibition)

#### hellobot-studio-web (스튜디오 프론트)
- **스택**: Angular 13 / Angular Material / ng-bootstrap
- **주요 기능**: 챗봇 빌더 UI, PWA 지원
- **별도 도메인**: hellobotstudio.com

### 모바일

#### hellobot_android
- **스택**: Kotlin / MVVM / Dagger Hilt / Jetpack Compose (부분)
- **네트워킹**: Retrofit / OkHttp
- **로컬 DB**: Room (현재), Realm (레거시)
- **빌드 변형**: dev / staging / prd
- **최소 SDK**: API 가변, Target SDK: API 34

#### hellobot_iOS
- **스택**: Swift / ReactorKit / RxSwift / Tuist (모듈화)
- **네트워킹**: Alamofire / RxAlamofire
- **UI**: UIKit + SnapKit + PinLayout/FlexLayout
- **모듈 구조**: Common / Feature / Service / Main App
- **최소 iOS**: 16.0

### 데이터

#### common-data-airflow
- **스택**: Python / Apache Airflow 2.x / CeleryExecutor
- **데이터 웨어하우스**: Google BigQuery
- **처리 단계**: staging → intermediate → mart → mart_integrated → report
- **대상 서비스**: HelloBot, StoryPlay, Between, ThingsFlow
- **알림**: Slack API, Notion API

## 리포지토리 개발 레퍼런스

프로젝트 진행 시 반복적으로 참조되는 리포별 필수 정보.
워크트리 생성, 의존성 설치, 로컬 실행 등에서 코드를 탐색하지 않고 이 테이블을 먼저 참조합니다.

### 브랜치 및 빌드

| 리포 | 메인 브랜치 | 패키지 매니저 | 의존성 설치 | 로컬 실행 | 로컬 포트 |
|------|-----------|-------------|-----------|----------|----------|
| hellobot-server | `master` | npm | `npm install` | `npm run dev` | 3000 |
| hellobot-studio-server | `master` | Gradle | `./gradlew build` | `./gradlew bootRun` | 8080 |
| hellobot-studio-web | `master` | yarn | `yarn install` | `yarn start` | 4300 |
| hellobot-web | `main` | yarn | `yarn install` | `yarn dev` | 4500 |
| hellobot-webview | `main` | yarn | `yarn install` | `yarn dev` | 4200 |
| hellobot-report-webview | `main` | yarn | `yarn install` | `yarn dev` | 4400 |
| hellobot_android | `master` | Gradle | `./gradlew sync` | Android Studio Run | — |
| hellobot_iOS | `develop` | Bundler + Tuist | `bundle install && tuist fetch && tuist generate` | Xcode Run | — |
| common-data-airflow | `develop` | pip | `pip install -r requirements.txt` | `airflow standalone` | 8080 |

> **메인 브랜치**: 피쳐 브랜치 분기 및 워크트리 생성의 기준점. `git worktree add ... -b feat/xxx` 시 이 브랜치에서 생성합니다.

### 빌드 변형 (모바일)

| 리포 | 개발 | 스테이징 | 운영 |
|------|------|---------|------|
| hellobot_android | `assembleDevRelease` | `assembleStagingRelease` | `bundlePrdRelease` |
| hellobot_iOS | Beta scheme | — | Release scheme |

---

## 배포

### 인프라 리포지토리

서비스 리포와 별도로, 배포 매니페스트·환경 설정을 관리하는 인프라 전용 리포가 있습니다. 변경은 `/dev-infra` 에이전트가 담당합니다.

| 리포 | 역할 | 메인 브랜치 |
|------|------|-----------|
| `common-infra-eks-deploy` | EKS 클러스터 kustomize 매니페스트. `base/` + `overlays/hlb/{env}/[apn1]/{service}/` (env: dev/stg/prod, apn1=도쿄, apn2(생략)=서울). ArgoCD는 `app-of-apps/` Helm chart로 관리. Secret은 secrets-store CSI + AWS Secrets Manager | `main` |
| `hellobot-mwaa` | Airflow DAG 리포. 현재 DAG들을 K8s CronJob으로 마이그레이션 진행 중이라 역할 축소 중. `dags/` 단일 디렉토리 | `master` |

- **서비스 리포 (예: hellobot-server)**: 애플리케이션 코드 + Dockerfile. 빌드 이미지를 ECR에 push하고 `common-infra-eks-deploy` 의 kustomize image tag를 자동 갱신(`kustomize edit set image`).
- **common-infra-eks-deploy**: ArgoCD가 이 리포를 바라보며 k8s 클러스터에 적용. env/region별 overlay에서 replicas·env·리소스 스펙 관리.
- **환경변수·시크릿 변경**: 서비스 리포가 아닌 `common-infra-eks-deploy` 에서 처리. `/dev-infra` 커맨드 참조.

### 배포 브랜치 및 파이프라인

| 리포 | 피쳐 기준 브랜치 | 개발 배포 브랜치 | 운영 배포 브랜치 | 파이프라인 | 배포 대상 |
|------|----------------|-----------------|-----------------|-----------|----------|
| hellobot-server | `master` | `deploy-dev` (push) | `master` (PR 머지) | GitHub Actions → Docker(ECR) → ArgoCD | Kubernetes |
| hellobot-studio-server | `master` | `deploy-dev` | `master` | GitHub Actions → Docker(ECR) → ArgoCD | Kubernetes |
| hellobot-studio-web | `master` | `deploy-dev` | `deploy` | GitHub Actions → S3 + CloudFront | CDN |
| hellobot-web | `main` | `deploy-dev` | `deploy-prod` | GitHub Actions → Docker(ECR) → ArgoCD | Kubernetes |
| hellobot-webview | `main` | `deploy-dev` | `main` | ArgoCD | Kubernetes |
| hellobot-report-webview | `main` | `dev-report-web-deploy` (피쳐 직접 머지) | `prod-report-web-deploy` (main 머지) | AWS Amplify (브랜치 push → 자동 빌드) | Amplify Hosting (CloudFront) |
| hellobot_android | `develop` | 피쳐 브랜치 (GH Actions 수동 dispatch, Dev 빌드) | 피쳐 브랜치 (GH Actions 수동 dispatch, Prd 빌드) | GitHub Actions → Firebase App Distribution | Firebase App Distribution |
| hellobot_iOS | `develop` | 피쳐 브랜치 (로컬 `testflight_beta_upload`) | 피쳐 브랜치 (로컬 `testflight_upload` / `submit`) | Fastlane → TestFlight / App Store | TestFlight / App Store |
| common-data-airflow | `develop` | — | 수동 (`git pull`) | Kubernetes (Airflow) |

### 일본어 배포 (별도 브랜치)

| 리포 | JP 개발 | JP 운영 |
|------|--------|--------|
| hellobot-studio-web | `ja-deploy-dev` | `ja-deploy` |
| hellobot-webview | `ja-deploy-dev` | `ja-deploy` |

### 배포 절차 요약

**서버/웹 (ArgoCD 계열)**:
1. 피쳐 기준 브랜치(`master`/`main`)에서 피쳐 브랜치 분기
2. **개발 배포**: 피쳐 브랜치 → 개발 배포 브랜치(`deploy-dev` 등)에 머지 후 푸시 → GitHub Actions 빌드 → ArgoCD 배포
3. **운영 배포 (hellobot-server)**: 피쳐 브랜치 푸시 → `master`에 PR 생성 → 담당자 머지 → GitHub Actions 빌드 → ArgoCD 배포
4. ArgoCD 대시보드: `https://argocd.thingsflow.com/applications/{앱명}`

**모바일 (Android)**:
1. `develop`에서 피쳐 브랜치 분기
2. **개발 배포**: 피쳐 브랜치 푸시 → GitHub UI에서 `upload-app-distribution-dev` 워크플로우 수동 dispatch (Dev 빌드 변형)
3. **운영 배포**: 피쳐 브랜치 푸시 → GitHub UI에서 `upload-app-distribution` 워크플로우 수동 dispatch (Prd 빌드 변형) — 모두 Firebase App Distribution 배포

**모바일 (iOS)**:
1. `develop`에서 피쳐 브랜치 분기
2. **개발 배포**: 피쳐 브랜치에서 로컬 `bundle exec fastlane testflight_beta_upload` → TestFlight Beta
3. **운영 배포**: 로컬 `bundle exec fastlane testflight_upload` → TestFlight 운영 / `bundle exec fastlane submit` → App Store 심사 제출

**스튜디오 웹 (S3)**:
1. 배포 브랜치 머지 → GitHub Actions가 `yarn build` → S3 업로드 → CloudFront 무효화

## 환경

| 환경 | 용도 |
|------|------|
| dev | 개발/테스트 |
| staging | QA/프리프로덕션 (모바일) |
| prod | 운영 |

## 도메인

| 서비스 | 개발 | 운영 |
|--------|------|------|
| 웹/웹뷰 | dev.hellobot.co | hellobot.co |
| 리포트 | report.dev.hellobot.co | report.hellobot.co |
| 스튜디오 | dev.hellobotstudio.com | hellobotstudio.com |
| 일본 웹 | dev-jp.hellobot.co | jp.hellobot.co |
| 일본 스튜디오 | dev-jp.hellobotstudio.com | jp.hellobotstudio.com |
