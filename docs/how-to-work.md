# HelloBot 워크스페이스 작업 가이드

이 문서는 HelloBot 워크스페이스에서 Claude Code를 사용하여 피쳐를 개발하는 방법을 설명합니다.

---

## 목차

1. [사전 준비](#1-사전-준비)
2. [워크스페이스 구조 이해](#2-워크스페이스-구조-이해)
3. [에이전트 커맨드 소개](#3-에이전트-커맨드-소개)
4. [피쳐 개발 워크플로우](#4-피쳐-개발-워크플로우)
5. [실전 예시: 전체 흐름](#5-실전-예시-전체-흐름)
6. [상황별 사용 패턴](#6-상황별-사용-패턴)
7. [프로젝트 문서 이해하기](#7-프로젝트-문서-이해하기)
8. [워크트리 운영](#8-워크트리-운영)
9. [주의사항 및 팁](#9-주의사항-및-팁)

---

## 1. 사전 준비

### Claude Code 실행

이 워크스페이스의 루트 디렉토리에서 Claude Code를 실행합니다.

```bash
cd ~/Development/neuralarcade/hellobot
claude
```

> **중요**: 반드시 워크스페이스 루트(`hellobot/`)에서 실행하세요.
> 개별 리포 디렉토리(예: `hellobot-server/`)에서 실행하면 워크스페이스 레벨 커맨드와 프로젝트 문서를 사용할 수 없습니다.

### 전체 리포 최신화

작업 전 모든 리포지토리를 최신 상태로 동기화합니다.

```bash
./scripts/setup.sh pull     # 전체 리포 git pull
./scripts/setup.sh status   # 전체 리포 상태 확인
```

---

## 2. 워크스페이스 구조 이해

```
hellobot/                              ← 워크스페이스 루트 (여기서 claude 실행)
├── CLAUDE.md                          ← Claude Code 전체 규칙 (자동 로드됨)
├── docs/                              ← 프로젝트와 무관한 상시 문서
│   ├── architecture.md                ← 서비스 전체 아키텍처
│   └── how-to-work.md                 ← 이 문서
├── projects/                          ← 프로젝트별 디렉토리
│   ├── readme.md                      ← 프로젝트 문서 가이드 및 템플릿
│   └── 20260412-share-result/         ← 프로젝트 예시
│       ├── readme.md                  ← 요구사항
│       ├── status.md                  ← 진행 상태 + 워크트리/브랜치 현황
│       ├── tasks.md                   ← 파트별 과업
│       ├── architecture.md                  ← 기술 아키텍처
│       ├── api-spec.md                ← API 명세
│       └── worktrees/                 ← 개발용 워크트리
│           ├── hellobot-server/       ← git worktree (feat/share-result)
│           └── hellobot_iOS/          ← git worktree (feat/share-result)
├── scripts/
│   └── setup.sh                       ← 전체 리포 관리 스크립트
├── .claude/
│   └── commands/                      ← 에이전트 커맨드 정의 (10개)
│
├── hellobot-server/                   ← 원본 리포 (메인 브랜치 고정, 수정 금지)
├── hellobot-studio-server/
├── hellobot-studio-web/
├── hellobot-web/
├── hellobot-webview/
├── hellobot-report-webview/
├── hellobot_android/
├── hellobot_iOS/
└── common-data-airflow/
```

### 핵심 개념: 원본 vs 워크트리

| 구분 | 위치 | 용도 |
|------|------|------|
| **원본 리포** | `hellobot-server/` 등 | 메인 브랜치 고정. 코드 참조/검색용. 수정하지 않음. |
| **워크트리** | `projects/해당프로젝트/worktrees/hellobot-server/` | 피쳐 브랜치. 실제 코드 수정은 여기서. |

### 문서의 두 가지 레벨

| 레벨 | 위치 | 내용 |
|------|------|------|
| **프로젝트** | `projects/해당프로젝트/` | 요구사항, 전체 설계, API 계약, 파트별 과업 |
| **리포** | 예: `hellobot-server/docs/features/` | 해당 파트의 구현 상세 (Entity, Service 코드 골격 등) |

---

## 3. 에이전트 커맨드 소개

이 워크스페이스에서는 `/커맨드명`으로 역할별 에이전트를 호출할 수 있습니다.

### 커맨드 목록

| 커맨드 | 역할 | 하는 일 | 담당 리포 |
|--------|------|---------|-----------|
| `/analyze` | PM/기획자 | 요구사항 분석, 영향 범위 파악, 과업 분류 | 전체 (읽기만) |
| `/design` | 디자이너 | Figma 디자인 스펙 추출, 디자인 가이드 정리 | 프로젝트 문서 |
| `/architect` | 기술 설계자 | API 설계, 데이터 모델, 시퀀스 다이어그램 | 관련 리포 (읽기만) |
| `/dev-server` | 서버 개발자 | 백엔드 API 구현 | hellobot-server |
| `/dev-ios` | iOS 개발자 | iOS 앱 기능 구현 | hellobot_iOS |
| `/dev-android` | Android 개발자 | Android 앱 기능 구현 | hellobot_android |
| `/dev-web` | 웹 개발자 | 웹 프론트엔드 구현 | hellobot-web 등 |
| `/dev-studio` | 스튜디오 개발자 | 챗봇 빌더 기능 구현 | studio-server/web |
| `/dev-data` | 데이터 엔지니어 | ETL 파이프라인, BigQuery 마트 | common-data-airflow |
| `/dev-infra` | 인프라 담당 | k8s 매니페스트·환경변수·시크릿·MWAA | common-infra-eks-deploy, hellobot-mwaa |
| `/review` | 코드 리뷰어 | 코드 품질, 파트 간 정합성 검증 | 변경된 리포 전체 |
| `/workspace` | 워크스페이스 관리자 | 문서 정합성 점검, 상태 최신화 | 워크스페이스 문서 |

### 커맨드 사용법

```
/커맨드명 [인자]
```

인자에는 요구사항, 프로젝트명, 작업 지시 등을 자유롭게 입력합니다.

---

## 4. 피쳐 개발 워크플로우

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌───────────────┐   ┌──────────┐
│ 1. 분석   │──→│ 2. 디자인 │──→│ 3. 설계   │──→│ 4. 구현        │──→│ 5. 검토   │
│ /analyze │   │ /design  │   │/architect│   │/dev-* (워크트리)│   │ /review  │
└──────────┘   └──────────┘   └──────────┘   └───────────────┘   └──────────┘
 readme.md      design-spec   architecture    코드 구현            코드 리뷰
 tasks.md       .md           .md             tasks.md 체크        최종 검증
                              api-spec.md
```

### 단계 1: 분석 (`/analyze`)

```
/analyze 사주 결과 페이지에서 카카오톡으로 결과를 공유하는 기능 추가
```

→ `projects/20260412-share-result/` 디렉토리에 readme.md, tasks.md, status.md 생성

### 단계 2: 디자인 (`/design`)

디자이너가 Figma 작업을 완료하고 `designs/designs.md`에 링크를 입력한 후:

```
/design 20260412-share-result
```

→ Figma에서 스펙을 추출하여 design-spec.md 생성 (계약 문서)

### 단계 3: 설계 (`/architect`)

```
/architect 20260412-share-result
```

→ architecture.md, api-spec.md 생성 (design-spec.md 참조)

### 단계 4: 구현 (`/dev-*`)

```
/dev-server 20260412-share-result
```

→ 워크트리 생성 확인 → `projects/20260412-share-result/worktrees/hellobot-server/`에서 구현

서버 완료 후 클라이언트:

```
/dev-ios 20260412-share-result
/dev-android 20260412-share-result
```

### 단계 5: 검토 (`/review`)

```
/review 20260412-share-result
```

---

## 5. 실전 예시: 전체 흐름

### 예시: "스킬 결과 페이지에 공유 기능 추가"

#### Step 1 — 요구사항 분석

```
/analyze 스킬 결과 페이지에서 카카오톡으로 결과 이미지를 공유하는 기능을 추가하고 싶어.
사용자가 결과를 받은 후 "공유하기" 버튼을 누르면 카카오톡으로 결과 이미지와 링크가 전송되어야 해.
공유받은 사람이 링크를 클릭하면 해당 스킬의 소개 페이지로 이동해야 해.
```

Claude가 `projects/20260412-share-result/`에 문서를 생성합니다.

#### Step 2 — 기술 아키텍처

```
/architect 20260412-share-result
```

Claude가 architecture.md와 api-spec.md를 작성합니다. api-spec.md는 서버↔클라이언트 간 **계약서** 역할을 합니다.

#### Step 3 — 서버 구현

```
/dev-server 20260412-share-result
```

Claude가 워크트리 생성을 제안합니다:

```
hellobot-server에 워크트리를 생성할까요?
  브랜치: feat/share-result
  경로: projects/20260412-share-result/worktrees/hellobot-server/
```

승인하면 워크트리가 생성되고, 그 안에서 코드를 구현합니다.

#### Step 4 — 클라이언트 구현

```
/dev-ios 20260412-share-result
```

마찬가지로 워크트리를 생성하고 구현합니다. 서버 코드를 읽지 않고 api-spec.md 기준으로 연동합니다.

#### Step 5 — 코드 리뷰

```
/review 20260412-share-result
```

워크트리들의 변경사항을 프로젝트 문서와 대조 검토합니다.

#### 최종 프로젝트 구조

```
projects/20260412-share-result/
├── readme.md
├── status.md
├── tasks.md
├── architecture.md
├── api-spec.md
└── worktrees/
    ├── hellobot-server/       ← feat/share-result 브랜치
    ├── hellobot_iOS/          ← feat/share-result 브랜치
    ├── hellobot_android/      ← feat/share-result 브랜치
    └── hellobot-web/          ← feat/share-result 브랜치
```

---

## 6. 상황별 사용 패턴

### 패턴 A: 서버만 변경하는 간단한 API 추가

```
/analyze 관리자용 사용자 통계 조회 API 추가
/architect 20260412-admin-user-stats
/dev-server 20260412-admin-user-stats
```

### 패턴 B: 버그 수정 (프로젝트 문서 없이 바로 수정)

```
/dev-server 쿠폰 만료일 계산에서 타임존 버그가 있어. 
coupon.ts의 isExpired() 메서드 확인해줘.
```

→ 간단한 버그는 워크트리 없이 원본에서 직접 수정도 가능 (사용자 판단)

### 패턴 C: 기획만 필요한 경우

```
/analyze 구독 모델 도입 시 영향 범위 분석. 구현은 아직 안 할 거야.
```

### 패턴 D: 크로스 리포 변경이 있는 큰 피쳐

```
/analyze 인앱 결제를 네이티브 결제로 전환
/architect 20260412-native-iap
/dev-server 20260412-native-iap      # 1순위
/dev-ios 20260412-native-iap         # 2순위
/dev-android 20260412-native-iap     # 2순위
/dev-web 20260412-native-iap         # 3순위
/dev-data 20260412-native-iap        # 4순위
/review 20260412-native-iap          # 최종 검토
```

### 패턴 E: 에이전트 없이 자유롭게 질문

```
hellobot-server에서 결제 관련 Entity들을 알려줘
projects/ 에서 현재 개발중인 프로젝트 목록 보여줘
```

---

## 7. 프로젝트 문서 이해하기

프로젝트 문서는 에이전트 간의 **인수인계 문서**입니다.

### 문서별 역할

```
readme.md         "무엇을 만드는가"     → /analyze가 작성, 모든 에이전트가 참조
tasks.md          "누가 무엇을 하는가"   → /analyze가 작성, 과업 완료의 단일 소스
issues.md         "무엇이 발견되었나"   → 발견한 에이전트가 등록, 이슈 레지스트리
design-spec.md    "어떻게 보이는가"     → /design이 작성, 계약 문서 (Changelog 필수)
architecture.md   "어떻게 만드는가"     → /architect이 작성, 계약 문서 (Changelog 필수)
api-spec.md       "어떻게 통신하는가"   → /architect이 작성, 계약 문서 (Changelog 필수)
status.md         "지금 어디까지 됐는가" → 경량 대시보드 (~30줄), 파트별 현황만
```

### 프로젝트 vs 리포 문서

같은 피쳐라도 문서가 두 곳에 존재할 수 있습니다:

```
projects/20260412-share-result/                        ← 프로젝트 (전체 관점)
  ├── readme.md, architecture.md, api-spec.md, tasks.md, status.md
  └── worktrees/hellobot-server/                       ← 코드는 여기

hellobot-server/docs/features/20260412-share-result/   ← 리포 (서버 구현 관점)
  ├── backend-architecture.md, backend-guide.md              ← 구현 상세
```

---

## 8. 워크트리 운영

### 워크트리란?

Git worktree는 하나의 리포지토리에서 여러 브랜치를 동시에 체크아웃할 수 있는 기능입니다. 브랜치 전환 없이 여러 피쳐를 물리적으로 분리된 디렉토리에서 동시에 작업할 수 있습니다.

### 왜 워크트리를 쓰는가?

- **동시 피쳐 개발**: 피쳐 A, B를 같은 리포에서 동시 진행 가능
- **브랜치 전환 불필요**: stash/commit 없이 다른 피쳐로 전환
- **원본 보호**: 원본 리포는 메인 브랜치에 고정, 실수로 코드 섞임 방지
- **동료와 충돌 최소화**: 각자 피쳐 브랜치에서 독립 작업

### 생성 시점

- 프로젝트 시작 시 자동 생성하지 않습니다
- `/dev-*` 에이전트가 코드 수정이 필요할 때 사용자에게 확인 후 생성합니다
- 작업 도중 추가 리포 수정이 필요해지면 그때 워크트리를 추가합니다

### 생성 방법

```bash
cd hellobot-server
git checkout master && git pull
git branch feat/share-result
git worktree add ../projects/20260412-share-result/worktrees/hellobot-server feat/share-result
```

### 정리

프로젝트 완료 후 바로 삭제하지 않습니다 (후속 hotfix 가능). 별도 정리 단계에서 제거합니다:

```bash
cd hellobot-server
git worktree remove ../projects/20260412-share-result/worktrees/hellobot-server
git branch -d feat/share-result    # 필요시 브랜치도 삭제
```

### 동시 피쳐 작업 예시

피쳐 A와 피쳐 B를 같은 리포(hellobot-server)에서 동시 진행:

```
projects/
├── 20260412-share-result/
│   └── worktrees/
│       └── hellobot-server/    ← feat/share-result 브랜치
│
└── 20260415-subscription/
    └── worktrees/
        └── hellobot-server/    ← feat/subscription 브랜치
```

각 워크트리는 독립적이므로 서로 영향 없이 작업할 수 있습니다.

---

## 9. 주의사항 및 팁

### 컨텍스트 효율성

각 에이전트는 자기 담당 리포만 접근하며, 필요한 파일만 정확히 찾아서 읽습니다.

**사용자가 도와줄 수 있는 것:**
- 관련 파일 경로를 알고 있다면 미리 알려주기
- 어떤 리포가 관련되는지 힌트 주기
- 참고할 기존 프로젝트가 있다면 언급하기

### 중간에 끊겼을 때

각 에이전트는 작업 후 `status.md`에 진행 상황을 기록합니다. 새 세션에서:

```
projects/20260412-share-result/status.md 보여줘
```

현재 상태와 워크트리/브랜치 현황을 확인한 후, 이어서 진행할 에이전트를 호출합니다.

### 문서가 오래됐을 때 — `/workspace`

```
/workspace                          # 전체 문서 점검
/workspace 20260412-share-result    # 특정 프로젝트만 점검
```

### 커맨드 요약 치트시트

```
# 분석/설계
/analyze {요구사항 설명}
/architect {프로젝트명}

# 구현 (워크트리에서 작업)
/dev-server {프로젝트명 또는 작업 지시}
/dev-ios {프로젝트명 또는 작업 지시}
/dev-android {프로젝트명 또는 작업 지시}
/dev-web {프로젝트명 또는 작업 지시}
/dev-studio {프로젝트명 또는 작업 지시}
/dev-data {프로젝트명 또는 작업 지시}

# 검토
/review {프로젝트명 또는 리뷰 대상}

# 워크스페이스 관리
/workspace                  # 전체 문서 점검
/workspace {프로젝트명}      # 특정 프로젝트 점검
```
