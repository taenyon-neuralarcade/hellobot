# 리포지토리별 배포 가이드

에이전트가 배포 요청 시 참조하는 문서. 각 리포의 개발/운영 배포 절차를 정리.

> 배포 브랜치 전체 현황은 [architecture.md](./architecture.md#배포)를 참조.

---

## hellobot-server

| 환경 | 배포 브랜치 | 트리거 | 비고 |
|------|-----------|--------|------|
| 피쳐 개발 기준 | `master` | - | 피쳐 브랜치를 `master`에서 분기 |
| 개발 | `deploy-dev` | push (자동) | 피쳐 브랜치를 머지 후 푸시 |
| 운영 | `master` | PR 머지 (담당자) | 피쳐 브랜치 푸시 → `master`에 PR 생성 → 담당자 머지 |

```bash
# 개발 배포
git checkout deploy-dev && git merge feat/xxx && git push
# → GitHub Actions 빌드 → ArgoCD 자동 배포

# 운영 배포
git push origin feat/xxx
gh pr create --base master --head feat/xxx
# → 담당자 PR 리뷰/머지 → GitHub Actions 빌드 → ArgoCD 자동 배포
```

**배포 후 필수**: DB 마이그레이션이 포함된 경우 `npm run typeorm:migration` 실행 필요.

파이프라인: GitHub Actions → Docker(ECR `hlb/api`) → ArgoCD/EKS

---

## hellobot-web

| 환경 | 브랜치 | 트리거 |
|------|--------|--------|
| 개발 | `deploy-dev` | push |
| 운영 | `deploy-prod` | push |

```bash
# 개발 배포
git checkout deploy-dev && git merge feat/xxx && git push

# 운영 배포
git checkout deploy-prod && git merge feat/xxx && git push
```

파이프라인: GitHub Actions → Docker(ECR `hlb/web`) → ArgoCD/EKS

---

## hellobot-webview

| 환경 | 브랜치 | 트리거 |
|------|--------|--------|
| 개발 (한국) | `deploy-dev` | push |
| 운영 (한국) | `main` | push |
| 개발 (일본) | `ja-deploy-dev` | push |
| 운영 (일본) | `ja-deploy` | push |

```bash
# 개발 배포
git checkout deploy-dev && git merge feat/xxx && git push

# 운영 배포
git checkout main && git merge feat/xxx && git push
```

파이프라인: GitHub Actions → Docker(ECR `hlb/webview`) → ArgoCD/EKS

---

## hellobot-report-webview

| 환경 | 브랜치 | 트리거 | 도메인 |
|------|--------|--------|--------|
| 개발 | `dev-report-web-deploy` | push | https://report.dev.hellobot.co/ |
| 운영 | `prod-report-web-deploy` | push | https://report.hellobot.co/ |

```bash
# 개발 배포 (피쳐 브랜치를 직접 머지 — 팀 표준 패턴)
git checkout dev-report-web-deploy && git merge --no-ff feat/xxx && git push

# 운영 배포 (PR feat/xxx → main 머지 후, main 을 prod 에 가져오기)
git checkout prod-report-web-deploy && git merge --no-ff main && git push
```

> **개발 흐름 주의**: 다른 웹 리포와 달리 `develop` 브랜치를 거치지 않습니다. 피쳐 브랜치를 `dev-report-web-deploy` 에 직접 머지해 dev 환경에서 QA 후, PR 을 `main` 에 머지하고 `main → prod-report-web-deploy` 머지로 운영 배포. 현재 `develop` 은 사실상 `main` 과 동기 상태로 유지됨 (2026-05 기준).

파이프라인: **AWS Amplify** (브랜치별 자동 빌드/배포)
- 워크플로우 파일은 2025-02 [c551ab7](https://github.com/thingsflow/hellobot-report-webview/commit/c551ab7) 로 제거됨 — 현재 GitHub Actions 사용하지 않음.
- `dev-report-web-deploy` / `prod-report-web-deploy` 브랜치 push → AWS Amplify 가 webhook 으로 감지 → Next.js 빌드 → CloudFront 배포.
- 빌드 상태/로그: AWS Amplify 콘솔(`ap-northeast-2`) 에서 `hellobot-report-webview` 앱의 해당 브랜치 항목.
- 배포 완료까지 ~2–5분 소요. CDN 캐시는 Amplify 가 빌드 완료 시 자동 무효화.

---

## hellobot-studio-server

| 환경 | 브랜치 | 트리거 |
|------|--------|--------|
| 개발 | `deploy-dev` | push |
| 운영 | `master` | push |

```bash
# 개발 배포
git checkout deploy-dev && git merge feat/xxx && git push

# 운영 배포
git checkout master && git merge feat/xxx && git push
```

파이프라인: GitHub Actions → Docker(ECR) → ArgoCD/EKS

---

## hellobot-studio-web

| 환경 | 브랜치 | 트리거 |
|------|--------|--------|
| 개발 (한국) | `deploy-dev` | push |
| 운영 (한국) | `deploy` | push |
| 개발 (일본) | `ja-deploy-dev` | push |
| 운영 (일본) | `ja-deploy` | push |

```bash
# 개발 배포
git checkout deploy-dev && git merge feat/xxx && git push

# 운영 배포 (릴리스 포함)
git checkout master && yarn release    # 버전 태그 + CHANGELOG 생성
git push && git push --tags
git checkout deploy && git merge master && git push
```

파이프라인: GitHub Actions → S3 + CloudFront 무효화

---

## hellobot_android

| 환경 | 방법 | 트리거 | 비고 |
|------|------|--------|------|
| 피쳐 개발 기준 | `develop` | - | 피쳐 브랜치를 `develop`에서 분기 |
| 개발 | Firebase App Distribution | GitHub Actions 수동 dispatch | 피쳐 브랜치 푸시 후 GitHub UI에서 수동 실행 |
| 운영 | Firebase App Distribution | GitHub Actions 수동 dispatch | 동일 파이프라인 (릴리스 빌드 변형 기반) |

```bash
# 피쳐 브랜치 생성
git checkout develop && git pull
git checkout -b feat/xxx

# 개발 / 운영 배포 모두 Firebase App Distribution
git push origin feat/xxx
# → GitHub UI에서 해당 워크플로우 수동 실행 (브랜치 선택)
#   - 개발: upload-app-distribution-dev (Dev 빌드 변형)
#   - 운영: upload-app-distribution (Prd 빌드 변형)
```

로컬 빌드:
```bash
./gradlew :app:assembleDevRelease      # 개발 APK
./gradlew :app:bundlePrdRelease        # 운영 AAB
```

---

## hellobot_iOS

> **fastlane 미사용** (2026-04-30 기준) — 현재 fastlane 세팅이 망가진 상태로 사용하지 않음. **Xcode 에서 수동 archive 방식으로 배포 진행**. 자동화 워크플로우(GitHub Actions release/hotfix 자동 머지) 도 비활성화. 향후 워크플로우 재구축 시 본 문서 갱신 예정.

### 브랜치 전략 (git-flow)

| 환경 | 브랜치 | 비고 |
|------|--------|------|
| 피쳐 개발 기준 | `develop` | 피쳐 브랜치를 `develop`에서 분기 (`feat/<기능>`) |
| 통합/QA | `release/<version>` | `develop`에서 분기 — 마케팅 버전 bump 후 운영환경 QA |
| QA 수정 | `fix/<버그>` | `release/<version>`에서 분기 → 다시 release/<version>으로 머지 |
| 운영 출시 | `main` | `release/<version>` PR 머지 → App Store 심사 제출 |

### 배포 절차 (Xcode 수동 archive)

```bash
# 1) 피쳐 브랜치 생성 (develop 기준)
git checkout develop && git pull
git checkout -b feat/xxx

# 2) feat → develop PR 머지 (다른 개발과 conflict 있으면 해소)
gh pr create --base develop --head feat/xxx

# 3) develop → release/<version> 분기
git checkout develop && git pull
git checkout -b release/2.52.0

# 4) 마케팅 버전 bump
#    Plugins/BaseSettingsPlugin/ProjectDescriptionHelpers/BaseSettings.swift:13
#    public let marketingVersion = "2.52.0"
#    (currentProjectVersion = "AUTO" 는 그대로 — Tuist build phase 가 빌드 시 자동 스탬프)
git commit -am "chore: 마케팅 버전 2.52.0으로 변경"
git push -u origin release/2.52.0

# 5) Xcode 에서 운영 빌드 archive
./get_started.sh                      # 인증서·Pods·Tuist generate 동기화
open HelloBot_iOS.xcworkspace
#  - Scheme: Hellobot (운영)  ← Hellobot-Beta 아님
#  - Destination: Any iOS Device (arm64)
#  - 메뉴: Product → Archive
#  - 완료 후 Organizer 자동 표시

# 6) App Store Connect 업로드 (Organizer)
#  - archive 선택 → "Distribute App"
#  - "App Store Connect" → Upload
#  - 서명: Automatically manage signing (또는 수동)

# 7) TestFlight 처리 + 운영환경 QA
#  - https://appstoreconnect.apple.com → TestFlight 탭
#  - 빌드 처리 완료 대기 (10~30분, "Processing" → "Ready to Test")
#  - 내부 테스터 그룹에 빌드 추가
#  - 운영환경 QA 진행

# 8) (수정 발생 시) fix 브랜치 사이클
git checkout release/2.52.0
git checkout -b fix/<bug-id>
# 수정 + commit
gh pr create --base release/2.52.0 --head fix/<bug-id>
# 머지 후 5~7 단계 재실행 (rebuild + re-upload + re-test)

# 9) 출시 — release → main PR 머지
gh pr create --base main --head release/2.52.0

# 10) App Store 심사 제출 (App Store Connect 웹 콘솔)
#  - My Apps → 헬로우봇 → "App Store" 탭
#  - "+ 버전 또는 플랫폼" → 신규 버전 만들기
#  - "빌드" 섹션에서 TestFlight 검증 끝난 빌드 선택
#  - 메타데이터 (변경사항·스크린샷·검토자 노트) 작성
#  - "심사를 위해 제출"

# 11) main → develop 백머지 (수동 conflict 해소)
git checkout develop && git pull
git merge main
# conflict 발생 시 직접 해소
git push origin develop
```

### 사전 준비

- `./get_started.sh` — 인증서·프로비저닝·CocoaPods·Tuist generate 일괄 실행
- `Hellobot.xcscheme` (운영) / `Hellobot-Beta.xcscheme` (개발) 두 스킴 분리
- 마케팅 버전: `Plugins/BaseSettingsPlugin/ProjectDescriptionHelpers/BaseSettings.swift:13` (`marketingVersion`)
- 빌드 번호: 동일 파일 line 14 `currentProjectVersion = "AUTO"` (Tuist 가 빌드 시점에 `yyMMddHHmm.사용자ID` 형식으로 자동 스탬프 — 손대지 말 것)

---

## common-data-airflow

| 환경 | 방법 |
|------|------|
| 운영 | 수동 (`git pull`) |

```bash
# Airflow 서버에서 직접 실행
git pull origin develop
```

---

## 공통 인프라

| 항목 | 값 |
|------|-----|
| 컨테이너 레지스트리 | Amazon ECR |
| 오케스트레이션 | AWS EKS |
| 배포 도구 | Kustomize (common-infra-eks-deploy) |
| CI/CD | GitHub Actions (self-hosted runners) |
| ArgoCD 대시보드 | `https://argocd.thingsflow.com/applications/{앱명}` |
| 정적 웹 호스팅 | CloudFront + S3 (대부분), AWS Amplify Hosting (hellobot-report-webview) |
| AWS Amplify | hellobot-report-webview 전용 — 브랜치 push 시 자동 빌드/배포 (콘솔 region: `ap-northeast-2`) |
