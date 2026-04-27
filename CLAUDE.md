# HelloBot Workspace

HelloBot은 AI 챗봇 기반 운세/점술 서비스입니다. 이 워크스페이스는 헬로우봇 서비스 전체를 구성하는 개별 리포지토리들의 상위 디렉토리입니다.

## 리포지토리 구성

| 리포지토리 | 메인 브랜치 | 스택 | 역할 | 배포 |
|-----------|-----------|------|------|------|
| `hellobot-server` | `master` | Node.js / Express / TypeORM / PostgreSQL | 메인 API 서버 | GitHub Actions → ArgoCD |
| `hellobot-studio-server` | `master` | Java / Spring Boot / MongoDB | 스튜디오(챗봇 빌더) 백엔드 | GitHub Actions → ArgoCD |
| `hellobot-studio-web` | `master` | Angular 13 / TypeScript | 스튜디오 프론트엔드 | GitHub Actions → S3/CloudFront |
| `hellobot-web` | `main` | Next.js 14 / React 18 / Tailwind | 메인 웹 (스킬스토어) | GitHub Actions → ArgoCD |
| `hellobot-webview` | `main` | Angular 13 SSR / TypeScript | 앱 내 웹뷰 (레거시, 점진적으로 hellobot-web으로 이관 중) | ArgoCD |
| `hellobot-report-webview` | `main` | Next.js 14 / React 18 / Tailwind | 리포트/분석 웹뷰 | GitHub Actions |
| `hellobot_android` | `master` | Kotlin / MVVM / Hilt / Jetpack Compose | Android 앱 | GitHub Actions → Firebase/Play Store |
| `hellobot_iOS` | `develop` | Swift / ReactorKit / RxSwift / Tuist | iOS 앱 | Fastlane → TestFlight/App Store |
| `common-data-airflow` | `develop` | Python / Apache Airflow / BigQuery | 데이터 파이프라인 (ETL) | 수동 배포 |
| `common-infra-eks-deploy` | `main` | Kustomize / k8s manifest / Helm(ArgoCD app-of-apps) | EKS 클러스터 배포 매니페스트 (`overlays/hlb/{env}/[apn1]/{service}/`) | PR 머지 → ArgoCD sync |
| `hellobot-mwaa` | `master` | Python / Airflow DAG | Airflow DAG 리포 (K8s CronJob으로 마이그레이션 진행 중) | 수동 배포 |

> 개발 레퍼런스 상세 (패키지 매니저, 로컬 실행, 포트 등): [docs/architecture.md](docs/architecture.md#리포지토리-개발-레퍼런스)
> 배포 상세 (브랜치, 절차): [docs/architecture.md](docs/architecture.md#배포)

## 의존 관계

```
hellobot-server (메인 API)
  ├── hellobot-web (Next.js 웹)
  ├── hellobot-webview (Angular 웹뷰)
  ├── hellobot-report-webview (리포트 웹뷰)
  ├── hellobot_android (Android 앱)
  ├── hellobot_iOS (iOS 앱)
  └── common-data-airflow (데이터 수집)

hellobot-studio-server (스튜디오 API)
  ├── hellobot-studio-web (스튜디오 프론트)
  └── 모바일 앱들 (챗봇 설정 데이터 제공)

hellobot-webview / hellobot-report-webview
  └── 모바일 앱들에 WebView로 임베딩
```

## 공유 인프라

- **DB**: PostgreSQL (메인), MongoDB (스튜디오), Redis (캐싱/세션)
- **클라우드**: AWS (S3, CloudFront, SES), Firebase, Google BigQuery
- **배포**: ArgoCD/Kubernetes (서버), Vercel (웹), Fastlane (iOS), GitHub Actions (CI/CD)
- **분석**: Braze, Amplitude, BigQuery

## 다국어

- 한국어 (기본): hellobot.co, hellobotstudio.com
- 일본어: jp.hellobot.co, jp.hellobotstudio.com

---

## 워크스페이스 구조

```
hellobot/                              ← 워크스페이스 루트
├── CLAUDE.md                          ← 이 파일 (전체 규칙)
├── docs/                              ← 프로젝트와 무관한 상시 문서
│   ├── architecture.md
│   ├── how-to-work.md
│   └── web-page-map.md
├── projects/                          ← 프로젝트별 디렉토리
│   ├── readme.md                      ← 프로젝트 문서 가이드 및 템플릿
│   └── YYYYMMDD-feature-name/         ← 프로젝트
│       ├── readme.md                  ← 요구사항, 배경, 목표
│       ├── status.md                  ← 진행 상태, 브랜치/워크트리 현황
│       ├── tasks.md                   ← 파트별 과업
│       ├── design-spec.md              ← 디자인 스펙 (/design 작성, 계약 문서)
│       ├── architecture.md             ← 기술 아키텍처
│       ├── api-spec.md                ← API 명세
│       ├── qa-test-cases.md           ← QA 테스트 케이스
│       ├── designs/                   ← 디자인 원본 자료 (Figma 링크, 스크린샷, 와이어프레임)
│       ├── planning/                  ← 기획 과업 산출물 (필요시 생성)
│       └── worktrees/                 ← 개발용 워크트리 (필요시 생성)
│           ├── hellobot-server/       ← git worktree (feat/feature-name)
│           └── hellobot_iOS/          ← git worktree (feat/feature-name)
├── scripts/
│   └── setup.sh
│
├── hellobot-server/                   ← 원본 리포 (메인 브랜치 고정)
├── hellobot-studio-server/
├── hellobot-studio-web/
├── hellobot-web/
├── hellobot-webview/
├── hellobot-report-webview/
├── hellobot_android/
├── hellobot_iOS/
├── common-data-airflow/
├── common-infra-eks-deploy/             ← EKS 매니페스트 (kustomize)
└── hellobot-mwaa/                       ← AWS MWAA 환경 설정
```

---

## 프로젝트 및 워크트리 운영 규칙

### 원본 리포지토리

- 원본 리포(`hellobot-server/`, `hellobot_iOS/` 등)는 **항상 메인 브랜치에 고정**
- 원본에서 직접 피쳐 개발하지 않음 — 참조/조사 용도로만 사용
- 코드 수정은 반드시 프로젝트의 워크트리에서 수행

### 피쳐 브랜치

- 네이밍: `feat/{프로젝트명}` (예: `feat/share-result`)
- 각 리포의 메인 브랜치에서 생성

### 워크트리 생성

- 프로젝트 시작 시 자동으로 만들지 않음 — 개발 단계에서 필요시 사용자에게 확인 후 생성
- 작업 진행 중 추가 리포 수정이 필요하면 그때 워크트리 추가
- 생성 명령:
  ```bash
  cd hellobot-server
  git worktree add ../projects/20260412-share-result/worktrees/hellobot-server feat/share-result
  ```

### 워크트리 정리

- 프로젝트 완료 후 바로 삭제하지 않음 (후속 hotfix 가능)
- 별도 정리 단계에서 제거:
  ```bash
  cd hellobot-server
  git worktree remove ../projects/20260412-share-result/worktrees/hellobot-server
  ```

### 개발 에이전트의 작업 디렉토리

`/dev-*` 에이전트는 **워크트리 경로**에서 작업합니다:
```
원본 참조:  hellobot-server/                              ← 읽기 전용 (기존 코드 참고)
코드 수정:  projects/20260412-share-result/worktrees/hellobot-server/  ← 여기서 개발
```

### 리포 레벨 피쳐 문서

`/dev-*` 에이전트는 워크트리에서 개발 시 `docs/features/YYYYMMDD-feature-name/`에 파트별 세부 개발 과정을 기록합니다. 각 리포의 `docs/features/readme.md`에 파트별 가이드와 템플릿이 있습니다.

**흐름**: 요구사항 수신 → 세부 과업 분해 → 개발 계획 수립 → 순서대로 실행 → 완수 기록

**필수 문서**: `status.md` — 세부 과업 체크리스트, 설계 결정, 결정 로그
**선택 문서**: `guide.md` — 수정 대상 파일, 컴포넌트/모듈 구조, 구현 가이드

> 이 문서는 프로젝트 레벨 문서(tasks.md, architecture.md 등)와 중복하지 않습니다.
> 프로젝트 tasks.md는 "서버 파트: 이것을 구현하라"는 고수준 과업이고,
> 리포 status.md는 "그 과업을 이렇게 세분화해서 이 순서로 구현했다"는 세부 기록입니다.

---

## 에이전트 워크플로우

이 워크스페이스에서는 역할별 에이전트 커맨드를 사용하여 피쳐를 개발합니다.

### 워크플로우 단계

```
요구사항 접수
    │
    ▼
/analyze (PM/기획)        → 요구사항 분석, 영향 범위, 과업 분류
    │
    ▼
/design (디자인)           → Figma 스펙 추출, 디자인 가이드 정리
    │
    ▼
/architect (기술 설계)      → API 계약, 데이터 모델, 시퀀스
    │
    ▼
/dev-server               ┐
/dev-ios                  │
/dev-android              ├ 병렬 구현 (워크트리에서 작업)
/dev-web                  │
/dev-studio               │
/dev-data                 │
/dev-infra                ┘ (k8s 매니페스트·MWAA 변경 필요 시)
    │
    ▼
/review (검토)             → 크로스 리포 정합성 검증
    │
    ▼
/qa (QA)                   → 테스트 케이스 작성, 검수 결과 관리
    │
    ▼
/workspace (관리)          → 문서 정합성 점검, 상태 최신화 (수시)

    ↺ 이슈 발견 시 (어떤 단계에서든):
      issues.md 기록 → 설계 문서 수정 → tasks.md 과업 추가 → 구현 → 검증
```

### 에이전트 역할

| 커맨드 | 역할 | 담당 리포 |
|--------|------|-----------|
| `/analyze` | PM/기획자 — 요구사항 분석, 과업 분류, 우선순위 | 전체 (읽기만) |
| `/design` | 디자이너 — Figma 스펙 추출, 디자인 가이드 정리 | 프로젝트 문서 |
| `/architect` | 아키텍트 — API 계약, 데이터 모델, 시퀀스 | 관련 리포 (읽기만) |
| `/dev-server` | 서버 개발자 | hellobot-server |
| `/dev-ios` | iOS 개발자 | hellobot_iOS |
| `/dev-android` | Android 개발자 | hellobot_android |
| `/dev-web` | 웹 개발자 | hellobot-web, hellobot-webview, hellobot-report-webview |
| `/dev-studio` | 스튜디오 개발자 | hellobot-studio-server, hellobot-studio-web |
| `/dev-data` | 데이터 엔지니어 | common-data-airflow |
| `/dev-infra` | 인프라 담당 — k8s 매니페스트·환경변수·시크릿·MWAA | common-infra-eks-deploy, hellobot-mwaa |
| `/review` | 코드 리뷰어 | 변경된 리포 전체 |
| `/qa` | QA 담당자 — 테스트 케이스 작성, 검수 결과 관리 | 프로젝트 문서 (읽기) + qa-test-cases.md (작성) |
| `/workspace` | 워크스페이스 관리자 — 문서 정합성, 상태 최신화 | 워크스페이스 문서 전체 |

### 에이전트 간 커뮤니케이션

에이전트들은 **프로젝트 문서**를 통해 소통합니다:

1. `/analyze` → `readme.md`, `tasks.md` 작성
2. `/design` → `design-spec.md` 작성 (Figma 스펙 추출, 계약 문서)
3. `/architect` → `architecture.md`, `api-spec.md` 작성
4. `/dev-*` → 워크트리에서 구현 후 tasks.md 체크, 이슈 발견/해결 시 issues.md 갱신
5. `/review` → 변경사항 + 프로젝트 문서 대조 검증, 이슈 발견 시 issues.md + tasks.md
6. `/qa` → `qa-test-cases.md` 작성, 이슈 발견 시 issues.md + tasks.md
7. `/workspace` → status.md 파트 상태 동기화

### 문서 업데이트 규칙 (모든 에이전트 필수)

#### 과업 완료 시 업데이트할 문서

| 상황 | 업데이트 대상 | 내용 |
|------|------------|------|
| 과업 완료 | tasks.md | 해당 과업 [x] 체크 |
| 이슈 발견 | issues.md + tasks.md | 이슈 등록 (상태: 미해결) + 과업 추가 |
| 이슈 해결 | issues.md + tasks.md | 상태 "해결 (날짜)" + 과업 [x] 체크 |
| 파트 상태 변경 | status.md | 파트별 현황 표의 상태/비고 변경 |
| 설계 결정 (파트 내) | 리포 status.md | 결정 로그에 1줄 추가 (결정 + 이유) |
| 설계 결정 (전체 영향) | architecture.md 또는 api-spec.md | 해당 섹션 수정 + Changelog 기록 |

#### 하지 않아야 할 것

- **status.md에 작업 로그를 쓰지 않음** — status.md는 경량 대시보드 (~30줄). 구현 내역은 git log로 추적
- **리포 status.md에 과업 체크박스를 쓰지 않음** — tasks.md가 과업의 단일 소스
- **리포 status.md에 구현 내역을 쓰지 않음** — "무엇을 수정했나"는 git log, "왜 그렇게 결정했나"만 결정 로그에 기록
- **issues.md에 해결 방안 상세를 쓰지 않음** — issues.md는 레지스트리 (현상+원인+상태만). 해결 내역은 tasks.md 과업 + 커밋
- **issues.md에서 이슈를 섹션 간 이동하지 않음** — 상태 필드만 변경 ("미해결" → "해결 (날짜)")
- **계약 문서(architecture.md, api-spec.md, design-spec.md) 수정 시 Changelog 누락하지 않음** — 날짜 + 변경자 + 내용 + 확인 컬럼 필수

### 이슈 관리 (모든 에이전트 공통)

QA, 리뷰, 개발 등 **어떤 단계에서든** 설계 시 고려하지 못한 예외 상황, 버그, 개선사항을 발견하면 아래 절차를 따릅니다.

#### 이슈 발견 시 판단 기준

| 상황 | 분류 | 예시 |
|------|------|------|
| 구현이 설계와 다름 | `bug` | API 응답 필드 누락 |
| 설계에서 고려하지 못한 예외 | `edge-case` | 쿠폰 취소 후 재사용 시 유니크 제약 위반 |
| 요구사항 범위 밖의 개선 | `enhancement` | 관리자 통계 필터 추가 |

#### 이슈 처리 절차

```
1. 이슈 등록 (발견 즉시)
   - issues.md에 등록 (분류, 현상, 원인, 심각도, 상태: 미해결)
   - ISS-NNN 번호 부여 (기존 issues.md의 마지막 번호 + 1)
   - tasks.md에 ISS-NNN 참조 과업 추가
   ※ 이 단계에서 해결 방안을 확정하지 않음 — 등록만

2. 해결 방안 논의 (사용자와 협의)
   - 이슈의 영향 범위와 해결 방향 논의

3. 설계 반영 (방안 확정 후, 필요시)
   - architecture.md / api-spec.md 수정 + 하단 Changelog에 기록
   - tasks.md의 과업을 구체적 구현 과업으로 갱신

4. 구현 및 검증
   - 해당 파트 에이전트가 구현

5. 완료 처리
   - issues.md: 상태 필드를 "해결 (날짜)"로 변경
   - tasks.md: 해당 과업 [x] 체크
```

#### 에이전트별 이슈 처리 범위

| 에이전트 | 발견 | 기록 | 설계 변경 | 과업 추가 | 구현 |
|---------|------|------|----------|----------|------|
| `/dev-*` | O | O | 담당 파트 내 | 담당 파트 내 | O |
| `/review` | O | O | 제안 (코멘트) | O | X |
| `/qa` | O | O | 제안 (코멘트) | O | X |
| `/architect` | O | O | O | O | X |
| `/analyze` | O | O | 요구사항 수정 | O | X |
| `/workspace` | O | O | X | X | X |

> **원칙**: 이슈를 발견한 에이전트가 issues.md에 기록하고, 자신의 역할 범위 내에서 처리 가능한 만큼 진행합니다. 설계 변경이 크면 `/architect`를 호출하도록 사용자에게 안내합니다.

상세 가이드 및 템플릿: [projects/readme.md](projects/readme.md)

### 프로젝트 문서 구조

프로젝트 문서는 `projects/` 디렉토리에 관리합니다.
각 리포 내 구현 상세(예: hellobot-server/docs/features/)는 해당 리포에서 관리합니다.

상세 가이드: [projects/readme.md](projects/readme.md)

---

## 컨텍스트 관리 규칙 (필수)

리포지토리 전체는 매우 거대합니다. **필요한 데이터만 정확히 참조**하세요.

### 컨텍스트 로딩 순서

```
1단계 (필수): 워크스페이스 CLAUDE.md (이 파일)
2단계 (필수): 프로젝트 문서 (projects/해당프로젝트/)
3단계 (역할별): 담당 리포의 CLAUDE.md 또는 README.md
4단계 (필요시): 담당 리포 내 관련 소스 파일 (Grep/Glob으로 타겟팅)
```

### 금지 사항

- **담당 외 리포의 소스코드 탐색 금지** — 필요한 정보는 프로젝트 문서나 API 스펙으로 전달
- **리포 전체를 훑는 광범위 탐색 금지** — 항상 파일명/키워드로 타겟팅 검색
- **불필요한 파일 읽기 금지** — 구현에 직접 관련된 파일만 읽기
- **`/dev-*` 에이전트는 `planning/` 디렉토리 탐색 금지** — 개발에 필요한 사항은 프로젝트 문서(readme, design, tasks 등)로 승격되어 있음
- **원본 리포에서 코드 수정 금지** — 반드시 프로젝트 워크트리에서 작업

### 탐색 전략

```
좋은 예:
  Grep("FeatureName", path="hellobot-server/src/services/")
  Glob("**/feature-name*.ts", path="hellobot-server/src/")

나쁜 예:
  Glob("**/*.ts")  ← 전체 탐색
  Read("hellobot-server/src/services/") ← 디렉토리 전체
```

### 크로스 리포 참조가 필요할 때

다른 파트의 정보가 필요하면:
1. 먼저 프로젝트 문서의 `architecture.md`, `api-spec.md`를 확인
2. 문서에 없으면 해당 리포의 CLAUDE.md만 확인
3. 그래도 부족하면 해당 리포에서 특정 파일만 타겟팅 검색

---

## 작업 가이드

- 각 리포지토리는 독립된 Git 저장소입니다. 원본은 메인 브랜치에 고정하고, 개발은 프로젝트 워크트리에서 수행합니다.
- 프로젝트 문서는 `projects/` 디렉토리에, 서비스 상시 문서는 `docs/` 디렉토리에 기록합니다.
- 각 리포지토리의 상세 개발 가이드는 해당 리포의 CLAUDE.md 또는 README.md를 참조하세요.
- **배포가 필요하면**: [docs/deployment.md](docs/deployment.md) — 리포별 개발/운영 배포 브랜치, 명령어, 파이프라인
- **처음 사용한다면**: [docs/how-to-work.md](docs/how-to-work.md) — 워크스페이스 사용법, 에이전트 커맨드, 실전 예시 포함
