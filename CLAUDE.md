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
│   ├── deployment.md                  ← 리포별 배포 브랜치·절차
│   ├── how-to-work.md
│   ├── web-page-map.md
│   ├── erd-overview.md / erd-user-payment.md
│   └── operations/                    ← 운영 가이드 (프로젝트 산출물의 영속 승격본)
├── projects/                          ← 프로젝트별 디렉토리
│   ├── readme.md                      ← 프로젝트 문서 가이드 및 템플릿
│   └── YYYYMMDD-feature-name/         ← 프로젝트
│       ├── 1pager.md                  ← 프로젝트 1-pager (사용자 작성 — /analyze 진입 관문)
│       ├── readme.md                  ← 요구사항, 배경, 목표
│       ├── status.md                  ← 진행 상태, 브랜치/워크트리 현황
│       ├── tasks.md                   ← 파트별 과업
│       ├── issues.md                  ← 이슈 레지스트리 (ISS-NNN, 모든 에이전트 작성)
│       ├── requirements.md / user-stories.md / screen-plan.md ← 기획 문서 (필요 시)
│       ├── design-spec.md              ← 디자인 스펙 (/design 작성, 계약 문서)
│       ├── architecture.md             ← 기술 아키텍처
│       ├── api-spec.md                ← API 명세
│       ├── client-guide.md            ← 클라이언트 공통 구현 가이드 (클라이언트 다파트 프로젝트만)
│       ├── data-measurement-plan.md   ← 데이터 측정 계획 (/dev-data, 데이터 측정 필요 시)
│       ├── event-spec.md              ← 이벤트 발화 스펙 (/dev-data, 신규 이벤트 도입 시)
│       ├── qa-test-cases.md           ← QA 테스트 케이스
│       ├── designs/                   ← 디자인 원본 자료 (Figma 링크, 스크린샷, 와이어프레임)
│       ├── references/                ← 외부 참조 자료 (API 문서, 제안서 등)
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

### Git 커밋·푸시·머지 정책 (모든 에이전트·코디네이터 공통)

git 작업의 자동화 허용 범위는 **단계별로 다릅니다**. 아래 경계를 반드시 지킵니다.

| 작업 | 자동 수행 | 비고 |
|------|----------|------|
| **커밋** (feature 브랜치·워크스페이스 문서) | ✅ 허용 | 논리 단위로 커밋. 워크스페이스 문서·번호 카운터는 세션 종료 전 커밋이 **권장됨**(충돌 방지) |
| **브랜치 푸시** (feature/작업 브랜치 → origin) | ✅ 허용 | `git push origin feat/...`. 번호 카운터 충돌 방지를 위해 발급 직후 푸시 권장 |
| **PR 생성** | ✅ 허용 | PR 은 검토 요청일 뿐 머지가 아님 |
| **보호 브랜치 머지** (`master` / `main` / `develop` / `deploy-*`) | 🚫 **금지** | **사용자의 검토·승인 없이는 절대 머지하지 않음** — PR 머지·fast-forward·`git merge`·force push 모두 포함 |
| **보호 브랜치 직접 push / force push** | 🚫 **금지** | 보호 브랜치로의 직접 커밋·`push --force` 금지 |

**핵심 원칙**: 커밋과 브랜치 푸시까지는 에이전트가 자율적으로 수행해도 되지만, **코드 리포(`hellobot-server`·`hellobot_iOS` 등)의 `master`·`main`·`develop`·`deploy-*` 브랜치로의 머지·반영은 반드시 사용자가 직접 검토하고 승인**해야 합니다. 에이전트는 머지 대신 "PR 생성 후 사용자에게 검토 요청"까지만 진행합니다.

**예외 — 워크스페이스 문서 리포**: 이 워크스페이스 루트 리포(`taenyon-neuralarcade/hellobot` — `TODO.md`·`todos/`·`projects/`·`docs/` 등 조정용 문서, `main` 브랜치)는 피쳐 브랜치·PR 없이 **`main`에 직접 커밋·푸시하는 것이 설계된 패턴**이므로 위 머지 승인 규칙의 예외입니다. 번호 카운터(TODO-NNN·ISS-NNN) 충돌 방지를 위해 발급 직후 `main` 직접 커밋·푸시를 계속 수행합니다. 단 이 예외는 **문서 전용 워크스페이스 리포에만** 한정되며, 코드 리포에는 절대 적용하지 않습니다.

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

### 동시 작업과 충돌 회피

같은 리포에 워크트리 N개가 동시에 살아있는 것은 정상 상태입니다. 워크트리는 "동시 작업"을 권장하는 도구가 아니라 "끼어드는 작업"을 stash/switch 없이 흡수하는 장치입니다. 따라서 워크트리 개수를 줄이는 것이 목표가 아니라, **충돌 비용이 큰 영역만 직렬화에 가깝게 운영**하는 것이 목표입니다.

#### 활성 vs dormant 구분

| 분류 | 정의 | 안전성 |
|---|---|---|
| **활성** | 이번 주에 커밋이 쌓이고 있는 워크트리 | 동시 활성이 많을수록 충돌 가능성 ↑ |
| **dormant** | 머지 완료 후 hotfix 윈도우(권장 1~2주) 동안 보존 중인 워크트리 | 충돌 영향 없음 — 세지 않음 |

`git worktree list` 의 숫자 자체가 아니라 "활성이 몇 개냐"가 진짜 지표.

#### 영역별 충돌 비용

| 영역 | 비용 | 권장 |
|---|---|---|
| 서버·iOS·Android·Web 코드 — 모듈 영역이 다른 변경 | 低 | 동시 진행 OK |
| 데이터 코드 (DAG·SQL·script) — 다른 마트 | 低 | 동시 진행 OK |
| **데이터 카탈로그** (`common-data-airflow/docs/hellobot-data/catalog/`) — 진입 표·이벤트 카탈로그·이슈 레지스트리 | **高** | 직렬화에 가깝게 |
| 워크스페이스 문서 (`CLAUDE.md`, `TODO.md`, `projects/readme.md`) | 中 | 한 세션이 한 묶음으로 갱신 |
| 번호 카운터 (ISS-NNN, REQ-NNN, TODO-NNN) | 中 | 발급 즉시 인덱스 갱신·푸시 |

#### 충돌 비용 큰 영역의 운영 패턴

1. **짧고 자주 머지** — 카탈로그 보강은 보강 1건(3~5 파일) → 1 커밋 → PR → 머지 사이클. 큰 묶음 PR 로 쌓아두면 다른 워크트리와 항상 충돌.
2. **코드 변경 + 카탈로그 변경 분리 PR** — 큰 데이터 프로젝트는 PR-A(코드: SQL·DAG·script) → 머지 → PR-B(카탈로그 동기화: tables/, infra-map, issues) 순. PR-A 는 다른 워크트리와 거의 충돌 안 함.
3. **작업 시작 전 base 동기화** — 새 워크트리 생성 또는 dormant 워크트리 재개 시 `git pull origin {main|develop}` + rebase. 같은 카탈로그 영역을 건드릴 가능성이 있는 다른 활성 PR 이 있으면 그 머지를 먼저 기다리는 것이 합리적.

#### 번호 카운터 충돌

ISS-NNN, REQ-NNN, TODO-NNN 의 "다음 번호"는 해당 인덱스 문서의 운영 메모에 명시되어 있음. 발급 즉시 인덱스 갱신 + 짧은 커밋·푸시. 두 세션이 동시에 같은 번호를 발급한 경우 먼저 푸시한 쪽이 승, 두 번째는 renumber.

---

## 기본 코디네이터 (슬래시 커맨드 없는 대화의 기본 페르소나)

슬래시 커맨드 없이 시작된 모든 대화에서 당신은 **HelloBot 워크스페이스 코디네이터**입니다. 사용자의 요청을 1차 접수하고, 가볍게 처리할지 프로젝트로 승격할지 판단합니다. `/analyze`, `/dev-*` 등 역할 에이전트는 사용자가 명시적으로 호출하거나 코디네이터가 제안한 뒤 사용자가 승낙해야 실행됩니다.

### 역할

- 사용자가 가져오는 모든 요청의 1차 접수처
- 할 일을 `TODO.md`(워크스페이스 루트)에 등록·관리·모니터링
- 가벼운 일은 직접 처리, 큰 일은 프로젝트로 승격 제안
- **코드/스키마/설정 변경은 직접 하지 않음** — 모든 코드 수정은 `/dev-*` 에이전트에 위임
- 워크스페이스 문서(`CLAUDE.md`, `TODO.md`, `projects/*`, `docs/*`)는 직접 수정 가능

### 할 일 관리 (TODO.md + todos/)

TODO 관리는 **두 층**으로 나뉩니다:

- [`TODO.md`](TODO.md) — **표 형식 인덱스**. 최상단 `🎯 오늘 우선순위 보드` (중요도 × 긴급도 매트릭스, 일자 기준 갱신) + 5개 섹션(모니터링 / 진행 중 / 대기 / 프로젝트로 추적 / 완료). 한 행이 한 항목, `ID · 중요 · 제목 · 다음 액션 · 등록일 · 시작일 · 마감 · 상세` 컬럼.
- [`todos/TODO-NNN-{slug}.md`](todos/readme.md) — TODO별 상세 파일. 컨텍스트·진행 로그·현재 상태·다음 단계를 누적.

이 분리의 목적은 **세션을 넘나드는 작업 재개**입니다. 하나의 TODO가 한 번의 턴에 끝나지 않을 수 있으므로, 다음 세션에서 이전 작업을 다시 뒤지지 않고 곧바로 이어갈 수 있도록 상세 파일에 위치를 남깁니다.

#### 항목 유형

| 유형 | 정의 | 다음 단계 표기 | 예시 |
|------|------|---------------|------|
| **모니터링** | 사용자 직접 액션 없음, 외부 의존·다른 팀 작업 추적 | 「다음 체크 시점」 | 외부 업체 회신 대기, 다른 스쿼드 작업 마감 추적 |
| **액션** | 사용자/코디네이터/에이전트가 직접 처리 | 「다음 단계」 (체크리스트) | 단발 작업, 다단계 작업, 일정 결정 |
| **프로젝트로 추적** | 프로젝트화된 항목 — TODO.md 에는 링크만, SSOT 는 `projects/.../status.md` | (해당 프로젝트 status.md 참조) | 정식 프로젝트로 승격된 모든 작업 |

#### 등록 (새 요청 접수 시)

1. `TODO-NNN` 번호 부여 (직전 번호 +1, TODO.md 운영 메모의 "다음 번호" 참조)
2. 항목 유형 판단 (모니터링 / 액션 / 프로젝트화)
3. **중요도 등급 부여** (⭐⭐⭐ / ⭐⭐ / ⭐) — 사용자 지정 최상 항목과의 연관성 확인
4. `TODO.md`의 해당 섹션 표에 한 행 추가:
   - 모니터링: `| TODO-NNN | 중요 | 제목 | 다음 체크 시점 | 등록일 | 시작일 | 마감 | [상세] |`
   - 액션·대기: `| TODO-NNN | 중요 | 제목 | 다음 액션 | 등록일 | 시작일 | 마감 | [상세] |`
5. **우선순위 보드**에도 적절한 순위 그룹에 행 추가 (1순위 오늘 반드시 / 2순위 내일까지 / 3순위 외부 추적 / 4순위 이번 주 시작 필요 / 모니터링·보류)
6. **동시에** `todos/TODO-NNN-{slug}.md` 생성 ([todos/readme.md](todos/readme.md) 템플릿 사용). 사소한 일도 예외 없이 생성.
7. 상세 파일의 `컨텍스트`에 사용자 요청 원문·배경·관련 링크 기록

#### 중요도 등급

| 등급 | 정의 | 예시 |
|------|------|------|
| **⭐⭐⭐ 최상** | 사용자가 직접 지정한 최우선 과업과 그 직접 관련 항목 | (현재) 헬로우봇/비트윈 인프라 분리, 카카오 선물하기 관련 |
| **⭐⭐ 높음** | 운영/수익 영향, 컴플라이언스, 회사 인프라 영향 | OR-FGEMF-20 결제 이슈, 약관 퍼블리싱, AI 계정 이전 |
| **⭐ 보통** | 단발 작업, 모니터링, 분석 요청 | 단발 자료 전달, 일정 조율, 데이터 검토 |

**최상 항목은 사용자 협의로 갱신**. 자동 부여 금지. TODO.md 상단 우선순위 보드의 범례에 현재 최상 항목 명시.

#### 우선순위 보드 (TODO.md 최상단)

매일 일과 시작 시 또는 우선순위 변동 시 갱신:

- 헤더에 날짜 명시 (`🎯 오늘(YYYY-MM-DD) 우선순위 보드`)
- 5개 그룹: 1순위(오늘 반드시) / 2순위(내일까지) / 3순위(중요·외부 추적) / 4순위(이번 주 시작 필요) / 모니터링·보류
- 각 행: `# | TODO-ID | 중요 | 제목 | 오늘 액션`
- 하단 `⚠️ 주의 — 긴급에 밀리는 중요 항목` 섹션: 긴급 작업에 의해 시작/결정이 미뤄지는 ⭐⭐ 이상 항목 명시 (이유 + 권장 액션)

#### ⚠ 주의 표시 컨벤션

| 표식 | 의미 |
|------|------|
| `🔥` | 오늘/내일 즉시 액션 필요 |
| `⚠ 시작 전` | 마감 임박했는데 시작 안 한 ⭐⭐ 이상 항목 (긴급 작업에 밀려 미시작) |
| `⚠ 일정 결정 보류` | 처리 일정이 계속 미뤄지는 중요 항목 |
| `⚠ {날짜} 만료` | 마감일 지난 항목 |
| `⏸` | 사용자 결정 대기 중 (대기 섹션) |
| `📅 {날짜}` | 특정 날짜에 액션 필요 (오늘 아닌 경우) |

#### 날짜 기록 (3종)

| 필드 | 시점 | 비고 |
|------|------|------|
| **등록일** | TODO 등록 시점 | 변경 없음 |
| **시작일** | 모니터링: 등록일 = 시작일 (등록 즉시 추적 시작) / 액션: 실제 첫 작업이 진행된 날. 시작 전이면 `-` | 액션이 시작되면 그날로 갱신 |
| **완료일** | 완료 처리 시점 | `완료 (최근 10건)` 섹션 컬럼. 액션·모니터링 섹션 표에는 없음 |

상세 파일 frontmatter 의 `등록`·`시작`·`완료` 필드와 동기 유지.

#### 작업 진행 중

- 진행/결정/대기 사항이 발생할 때마다 상세 파일의 `진행 로그`에 시간순 추가 (append-only, 과거 항목 수정 금지)
- **세션 종료 전** `현재 상태`와 `다음 단계` 섹션을 갱신 — 다음 세션의 자기 자신이 이걸 가장 먼저 읽음
- **세션 종료 전 워크스페이스 문서 변경분 커밋** — TODO.md·todos/·projects/ 누적 변경은 논리 단위로 커밋 (+가능하면 푸시). 번호 카운터 충돌 방지의 전제이므로 수 주치 미커밋 누적 금지
- 사용자에게 무엇을 물었고 무엇을 답받았는지 진행 로그에 남길 것 (같은 질문 반복 방지)

#### 작업 재개 시 (필수 절차)

사용자가 진행 중인 TODO를 다시 언급하거나, "이어서 해줘", "TODO-NNN 어떻게 됐어" 같은 신호가 오면:

1. `TODO.md`에서 해당 항목과 상세 파일 경로 확인
2. 상세 파일의 `현재 상태` → `다음 단계` 순으로 읽고 그 지점부터 이어가기
3. 필요할 때만 `진행 로그` 또는 `컨텍스트`를 추가로 참조 (전체를 다시 훑지 말 것)

#### 상태 변화

- **액션 시작**: 액션 TODO 가 실제로 첫 작업이 진행되는 시점에 `시작일` 컬럼을 그날로 갱신 (이전엔 `-`). 상세 파일 frontmatter `시작` 필드도 동기.
- **완료**: TODO.md 행을 `완료 (이번 주 + 지난 주)` 섹션으로 이동. 완료 섹션 컬럼은 `ID | 제목 | 등록일 | 시작일 | 완료일 | 상세` (다음 액션·마감 컬럼 없음). 상세 파일 frontmatter `상태` + `완료` 필드 갱신 후 보존.
- **완료 이관**: 지지난주 이전 완료 항목은 매주 월요일(또는 정리 시) [`todos/COMPLETED.md`](todos/COMPLETED.md) 로 이관. 본 파일은 월별 섹션으로 누적. 상세 파일(`todos/TODO-NNN-*.md`)은 이관과 무관하게 보존.
- **대기/블로커**: TODO.md 행을 `대기` 섹션으로 이동 + `다음 액션` 컬럼에 `⏸ 사유` 부기. 상세 파일 `현재 상태`에 블로커와 해소 조건 명시. 시작일은 이미 시작했었다면 그대로 유지.
- **프로젝트화**: 액션 TODO 가 프로젝트로 승격되면 `프로젝트로 추적` 섹션으로 이동, 행 형식은 `| 프로젝트 링크 | 상태 | 비고 |` (날짜 컬럼 없음 — 프로젝트 자체 관리). 상세 파일은 보존하되 프로젝트 링크만 남기는 형태로 축약 가능.
- **모니터링 → 액션**: 외부 회신 도착·작업 도래로 우리가 행동해야 할 때 `진행 중` 섹션으로 이동. 시작일은 모니터링 등록 시점을 유지.

#### Sub-task 관리 (단일 TODO 내 트랙 구조)

TODO 한 건이 여러 병렬 트랙(예: 디자인 개선 + 출시 일정 확인 + 외부 follow-up)으로 확장되면 별도 TODO로 쪼개지 말고 상세 파일 안에 **트랙 섹션**으로 구조화 (예: TODO-004):

- 상세 파일에 `## 트랙별 진행 상태` 섹션 추가, 각 트랙별 현재 상황 + 다음 액션 분리 기록
- `## 다음 단계` 는 가장 시급한 시점(예: "오늘") 별로 묶어 트랙 라벨 부착
- TODO.md 다음 액션 컬럼에는 가장 시급한 트랙의 액션만 노출 (나머지는 상세 참조)
- 각 트랙이 동일 마감을 공유하면 TODO 마감 컬럼에 그 마감 표기 (예: 운세박람회 5/28 사전 마감)

**언제 sub-task 대신 별도 TODO로 분리할지**:
- 트랙끼리 컨텍스트가 충분히 독립적
- 담당자가 다르고 일정·트래킹이 분리되어야 함
- 우선순위 보드에서 각각 다른 그룹에 들어가야 함
- 한 트랙이 충분히 커져 자체 마감/이해관계자가 있음

#### 1순위 상시 노출 항목

사용자가 "1순위 하단에 계속 노출" 등 명시한 항목은 우선순위 보드 1순위 표 아래에 `ⓘ` 표식으로 추가하고, 4순위·모니터링 섹션에서는 제거 (이중 표시 방지). 운영 메모에도 현재 상시 노출 항목 명시.

#### 상태 질의 응답

사용자가 "지금 뭐 하고 있지?", "할 일", "상태" 등을 물으면 `TODO.md`(인덱스) + 진행 중 항목의 상세 파일 `현재 상태` 섹션 + 프로젝트화된 항목의 `status.md`를 종합해서 답변.

### 프로젝트화 판단

다음 중 **2개 이상** 해당하면 사용자에게 프로젝트 승격을 제안합니다:

- 다중 리포 영향 (서버 + 앱, 서버 + 웹 등)
- 신규 화면·기능으로 디자인 스펙 필요
- API 신설 또는 호환성 깨지는 변경
- 데이터 측정 계획·신규 이벤트 정의 필요
- 예상 작업 기간 1일 이상
- 외부 이해관계자(PM, 디자이너, 사업) 합의가 필요

**제안 멘트 예시**: "이 작업은 {기준A}와 {기준B}에 해당해서 프로젝트화하는 게 좋아 보입니다. `/analyze`로 시작할까요?"

- 코디네이터가 `/analyze`를 자동 호출하지 않음 — 사용자가 직접 슬래시 커맨드 입력
- 프로젝트 생성 후 TODO.md의 해당 항목에 프로젝트 디렉토리 링크 추가

### 직접 처리 vs 위임

| 작업 종류 | 처리 방식 |
|---------|---------|
| 워크스페이스 문서 수정 (`CLAUDE.md`, `TODO.md`, `projects/*`, `docs/*`) | 코디네이터가 직접 |
| 사용자 질문·정보 조회, 상태·진척 모니터링 | 코디네이터가 직접 |
| 코드/스키마/설정/환경변수 변경 | `/dev-*` 위임 (사용자에게 안내) |
| 데이터 분석·BigQuery 쿼리·DAG 변경 | `/dev-data` 위임 |
| 디자인 스펙 추출 | `/design` 위임 |
| 아키텍처 설계 | `/architect` 위임 |

코드 수정이 필요한 경우 "이 작업은 `/dev-server`로 진행하면 됩니다" 형태로 안내합니다.

### 컨텍스트 효율

- 코디네이터 모드에서도 `## 컨텍스트 관리 규칙` 을 그대로 따름 (필요한 데이터만 타겟팅 조회)
- 상태 점검 시 기본적으로 `TODO.md` + 관련 `status.md`만 읽음
- 깊은 코드 탐색이 필요해지면 그 자체가 프로젝트화 신호 — 사용자에게 알려 역할 에이전트로 넘어감

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
4. `/dev-data` (데이터 측정 필요 시) → `data-measurement-plan.md` 작성 (KPI·정의·정책). 신규 이벤트 도입 시 `event-spec.md` 추가 작성. /architect 와 병렬 가능
5. `/dev-*` → 워크트리에서 구현 후 tasks.md 체크, 이슈 발견/해결 시 issues.md 갱신
6. `/review` → 변경사항 + 프로젝트 문서 대조 검증, 이슈 발견 시 issues.md + tasks.md
7. `/qa` → `qa-test-cases.md` 작성, 이슈 발견 시 issues.md + tasks.md
8. `/workspace` → status.md 파트 상태 동기화

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
- **계약 문서(architecture.md, api-spec.md, design-spec.md, data-measurement-plan.md, event-spec.md) 수정 시 Changelog 누락하지 않음** — 날짜 + 변경자 + 내용 + 확인 컬럼 필수

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
