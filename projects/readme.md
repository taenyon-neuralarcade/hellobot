# 프로젝트 가이드

프로젝트별 문서와 개발 환경(워크트리)을 관리합니다.

> **프로젝트 vs 리포 레벨 문서**
> - **프로젝트** (`projects/`): 기획 문서, 전체 설계, 파트별 과업, API 계약 + 워크트리
> - **리포 레벨** (예: `hellobot-server/docs/features/`): 해당 파트의 구현 상세

---

## 디렉토리 구조

```
projects/
├── readme.md                              # 이 문서
└── YYYYMMDD-feature-name/                 # 프로젝트별 디렉토리
    │
    │  ── 입력 문서 (사용자 제공) ──
    ├── 1pager.md                          # 프로젝트 1-pager
    ├── designs/                           # 디자인 원본 자료 (Figma 링크, 스크린샷, 와이어프레임)
    │   └── designs.md                     # Figma 링크, 화면 목록, 반영 현황
    ├── references/                        # 외부 참조 자료 (API 문서, 제안서, 프로세스 등)
    │
    │  ── 기획 문서 (모든 파트 공통 참조) ──
    ├── requirements.md                    # 요구사항 정의서
    ├── user-stories.md                    # 사용자 스토리
    ├── screen-plan.md                     # 화면 기획서
    ├── planning/                          # 기획 과업 산출물 (리서치, 분석, 협의 결과)
    │
    │  ── 에이전트 생성 문서 ──
    ├── readme.md                          # 프로젝트 개요 (/analyze 작성)
    ├── status.md                          # 진행 상태 (경량 대시보드)
    ├── tasks.md                           # 파트별 과업 목록
    ├── issues.md                          # 이슈 레지스트리 (모든 에이전트 작성)
    ├── design-spec.md                     # 디자인 스펙 (/design 작성, 계약 문서)
    ├── architecture.md                     # 기술 아키텍처 (/architect 작성)
    ├── api-spec.md                        # 파트 간 API 명세
    ├── qa-test-cases.md                   # QA 테스트 케이스 (/qa 작성)
    │
    │  ── 개발 환경 ──
    └── worktrees/                         # 개발용 워크트리 (필요시 생성)
        ├── hellobot-server/               # git worktree (feat/feature-name)
        └── hellobot_iOS/                  # git worktree (feat/feature-name)
```

### 디렉토리 네이밍
- 형식: `YYYYMMDD-feature-name` (날짜-케밥케이스)
- 날짜는 프로젝트 분석 시작일 기준

---

## 워크플로우

```
프로젝트 생성
  │  프로젝트 디렉토리 생성, designs/ 디렉토리 생성
  │  사용자에게 1pager.md 작성 요청
  ▼
1pager.md 작성 (사용자)
  │  Problem, Customer Job, Solution, Success Metric 등
  ▼
/analyze 실행
  │  1pager.md를 기반으로 readme.md 작성
  │  tasks.md 작성 (파트별 과업 분류)
  │  status.md 생성 (초기 상태)
  ▼
디자인 입력 (사용자)
  │  디자이너가 Figma 작업 완료 후 designs/designs.md에 링크 입력
  ▼
/design 실행
  │  Figma에서 디자인 스펙 추출
  │  design-spec.md 작성 (계약 문서)
  ▼
/architect 실행
  │  architecture.md 작성 (기술 아키텍처, 데이터 흐름, 시퀀스)
  │  api-spec.md 작성 (파트 간 API 계약)
  ▼
/dev-* 실행 (파트별)
  │  워크트리에서 코드 구현
  │  과업 완료 시 tasks.md 체크
  ▼
/review 실행
  │  변경사항 검토
  │  이슈 발견 시 issues.md + tasks.md
  ▼
/qa 실행
  │  qa-test-cases.md 작성 (요구사항/설계 기반)
  │  이슈 발견 시 issues.md + tasks.md
  │
  ▼
이슈 발견 시 (어떤 단계에서든)
  │  issues.md 등록 + tasks.md 과업 추가
  │  설계 변경 필요 → 계약 문서 수정 + Changelog 기록
  │  해결 완료 → issues.md 상태 변경 + tasks.md 체크
  │
  ▼
/workspace 종료 {프로젝트명}
  │  사전 점검 → 미완 과업/이슈 정리 → PR 링크 수집
  │  영속 산출물 승격 (planning/, 카탈로그 등)
  │  status.md §종료 정보 추가 + projects/readme.md 상태 갱신
  │  (워크트리 정리는 hotfix 윈도우 후 별도 단계)
```

> **피드백 루프**: 위 워크플로우는 순방향이지만, 개발·리뷰·QA 중 이슈가 발견되면
> 설계 문서를 수정하고 과업을 추가하는 역방향 흐름이 발생합니다.
> 이슈 관리 절차는 CLAUDE.md의 "이슈 관리" 섹션을 참조하세요.

---

## 문서 분류 규칙

프로젝트 문서는 **모든 파트가 공통으로 참조하는 문서**입니다. 특정 파트의 구현 상세는 해당 리포에 둡니다.

### 프로젝트 레벨 (projects/해당프로젝트/)

| 문서 | 작성자 | 설명 |
|------|--------|------|
| `1pager.md` | 사용자 | 프로젝트 목표, 솔루션, 지표 |
| `designs/` | 사용자 | 디자인 원본 자료 (Figma 링크, 스크린샷, 와이어프레임) |
| `designs/designs.md` | 사용자 | Figma 링크, 화면 목록, 반영 현황 (/design 에이전트의 입력) |
| `requirements.md` | /analyze 또는 사용자 | 요구사항 정의서 — 전체 기능 요구사항 |
| `user-stories.md` | /analyze 또는 사용자 | 사용자 스토리 — UX 흐름, 예외 시나리오 |
| `screen-plan.md` | /analyze 또는 사용자 | 화면 기획서 — 화면 구성, 분기 조건 |
| `references/` | 사용자 또는 에이전트 | 외부 참조 (API 문서, 제안서, 연동 가이드) |
| `planning/` | 사용자 또는 에이전트 | 기획 과업 산출물 (리서치, 데이터 분석, 상품 정의, 협의 결과, 기존 시스템 검토) |
| `readme.md` | /analyze | 프로젝트 개요, 영향 범위 |
| `status.md` | 모든 에이전트 | 진행 상태, 브랜치/워크트리 현황 |
| `tasks.md` | /analyze | 파트별 과업 목록 |
| `issues.md` | 모든 에이전트 | 이슈 추적 (QA/리뷰/개발 중 발견된 버그, 예외, 개선사항) |
| `design-spec.md` | /design | 디자인 스펙 (계약 문서 — 화면 스펙, 에셋, 파트별 가이드) |
| `architecture.md` | /architect | 기술 아키텍처 (데이터 모델, 처리 로직) |
| `api-spec.md` | /architect | 서버↔클라이언트 API 계약 |
| `qa-test-cases.md` | /qa | QA 테스트 케이스 및 검수 결과 |

### 리포 레벨 ({리포}/docs/features/해당피쳐/)

각 `/dev-*` 에이전트는 자기 리포에 피쳐 문서를 생성하여 구현 상세와 작업 로그를 기록합니다.

| 리포 | 문서 예시 | 작성자 |
|------|----------|--------|
| hellobot-server | `backend-design.md`, `backend-guide.md`, `testing/`, `deployment/`, `status.md` | /dev-server |
| hellobot-web | `web-guide.md`, `status.md` | /dev-web |
| hellobot_iOS | `ios-guide.md`, `status.md` | /dev-ios |
| hellobot_android | `android-guide.md`, `status.md` | /dev-android |
| hellobot-studio-* | `studio-guide.md`, `status.md` | /dev-studio |
| common-data-airflow | `data-guide.md`, `status.md` | /dev-data |

**필수 파일**: `status.md` — 해당 파트의 과업 체크리스트와 작업 로그
**선택 파일**: `{파트}-guide.md` — 구현 가이드 (수정 대상 파일, 컴포넌트 구조 등)

#### 2레벨 추적 원칙

```
프로젝트 레벨 (projects/.../status.md)
  → 파트별 상태 요약, 블로커, 마일스톤
  → /workspace가 관리

리포 레벨 ({리포}/docs/features/.../status.md)
  → 해당 파트 구현 상세, 과업 체크리스트, 작업 로그
  → /dev-* 가 관리
```

- `/dev-*` 에이전트는 자기 리포의 status.md를 업데이트
- `/workspace`는 각 리포 status를 모아서 프로젝트 status.md에 요약 반영
- 프로젝트 status.md에서 리포 status.md로 링크

> **원칙**: "iOS 개발자가 이 문서를 참고해야 하는가?" → Yes면 프로젝트 레벨, No면 리포 레벨.

---

## 입력 문서

### 1pager.md (프로젝트 1-pager)

프로젝트 시작 시 사용자가 작성하는 문서입니다. 에이전트가 작성하지 않습니다.
`/analyze`는 이 문서를 기반으로 요구사항을 구체화합니다.

```markdown
## **Problem**
{해결하려는 문제와 root cause}

## **Customer Job**
{고객/회사가 달성하고 싶은 것}

## **Solution / Feature**
{제안된 솔루션과 주요 기능}

## **Success Metric**
input metric
{투입 지표}

output metric
{성과 지표}

## **Benchmark**
{참고 사례, 시장 상황}

## **Trade off**
{필요한 리소스, 트레이드오프}

## **Unhappy Path**
{실패 시나리오, 리스크}

## **Feedback loop**
{성과 측정 및 피드백 방법}
```

### designs/ (디자인 파일)

기획 완료 후 외부에서 작성된 디자인 파일을 넣는 디렉토리입니다.
- Figma 링크를 담은 markdown 파일
- 스크린샷, 목업 이미지
- 디자인 스펙 문서

`/architect` 에이전트가 기술 설계 시 이 디렉토리의 파일을 참고합니다.

### planning/ (기획 과업 산출물)

개발 외적인 기획 과업의 산출물을 모아두는 디렉토리입니다.
필요할 때마다 문서를 추가하며, 프로젝트에 따라 없을 수도 있습니다.

**대상 작업 예시**:
- 상품/가격 정의 (예: 하트 상품 구성, 스킬 이용권 라인업)
- 데이터 분석 (예: 사용자 소비 패턴, 전환율 분석)
- 시장 리서치 (예: 경쟁사 벤치마크, 규제 검토)
- 이해관계자 협의 결과 (예: 파트너사 회의록, 내부 의사결정)

**운영 원칙**:
- 문서는 주제별로 자유롭게 추가 (파일명은 내용을 알 수 있도록)
- `/dev-*` 에이전트는 `planning/`을 직접 참조하지 않음 — 컨텍스트 효율성 유지
- 기획 결과 중 개발에 필요한 사항은 프로젝트 문서로 승격:
  - 요구사항에 영향 → `readme.md` 또는 `requirements.md`에 반영
  - 설계에 영향 → `architecture.md`에 반영
  - 데이터/설정에 영향 → `tasks.md`에 과업으로 추가
- `tasks.md`의 "기획" 섹션에서 과업 진행을 추적

---

## 워크트리 운영

### 생성 시점
- 프로젝트 시작 시 자동 생성하지 않음
- `/dev-*` 에이전트가 코드 수정이 필요할 때 사용자에게 확인 후 생성
- 작업 도중 추가 리포 수정이 필요해지면 그때 워크트리 추가

### 생성 방법

```bash
# 예: hellobot-server 워크트리 생성
cd hellobot-server
git checkout master && git pull          # 메인 브랜치 최신화
git branch feat/{프로젝트명}              # 피쳐 브랜치 생성
git worktree add ../projects/YYYYMMDD-feature-name/worktrees/hellobot-server feat/{프로젝트명}
```

### 정리
- 프로젝트 완료 후 바로 삭제하지 않음 (후속 hotfix 가능)
- 별도 정리 단계에서 제거:
  ```bash
  cd hellobot-server
  git worktree remove ../projects/YYYYMMDD-feature-name/worktrees/hellobot-server
  # 필요시 브랜치도 삭제
  git branch -d feat/{프로젝트명}
  ```

---

## 프로젝트 종료 절차

프로젝트의 모든 작업이 완료되면 `/workspace 종료 {프로젝트명}` 으로 종료 절차를 수행합니다. 핵심은 **나중에 "이 프로젝트가 어떤 변경을 만들어냈는지" 추적 가능하도록 PR 링크를 남기는 것** + **영속 산출물·미해결 이슈를 어디로 보냈는지 명확히 기록하는 것** 입니다.

### 종료 시 수행할 작업

| # | 작업 | 결과물 |
|---|------|--------|
| 1 | 모든 파트 status가 `완료` 인지 확인 | (검증) |
| 2 | tasks.md 미체크 항목 정리 (완료/이관/drop) | tasks.md |
| 3 | issues.md 미해결 항목 정리 (이관/SSOT 이전/drop) | issues.md |
| 4 | 머지된 PR 링크 수집 (`gh pr list --search "head:feat/<프로젝트명>" --state merged`) | status.md §종료 정보 |
| 5 | 영속 산출물 승격 (planning/, 카탈로그 등 → 리포 docs/ 또는 워크스페이스 docs/) | (이전) + status.md 기록 |
| 6 | status.md 를 `완료` 로 변경 + §종료 정보 섹션 추가 | status.md |
| 7 | 프로젝트 목록 테이블 (이 문서 §프로젝트 목록) 상태 갱신 | projects/readme.md |
| 8 | 워크트리/브랜치 정리는 hotfix 윈도우(1~2주) 후 별도 단계 | (정리 예정일만 기록) |

> **금지**: 사용자 확인 없는 워크트리·브랜치 삭제, 미해결 이슈 drop, 영속 산출물 이전. 머지되지 않은 PR이 있는데 종료 강행.

### status.md §종료 정보 템플릿

종료 시 status.md 하단에 추가합니다.

```markdown
---

## 종료 정보

**종료일**: YYYY-MM-DD
**종료 상태**: 완료 (정상 종료) | 취소 | 보류

### 머지된 PR

| 리포 | PR | 제목 | 머지일 |
|------|----|----|--------|
| common-data-airflow | [#176](https://github.com/thingsflow/common-data-airflow/pull/176) | docs: HelloBot 데이터 카탈로그 이전 + 동기화 규칙 | 2026-04-22 |
| hellobot-server | [#1234](https://github.com/...) | feat: 쿠팡 연동 API | 2026-04-20 |

### 승격된 영속 산출물

| 산출물 | 원위치 (프로젝트) | 승격 위치 |
|--------|------------------|----------|
| 데이터 카탈로그 | `planning/` | `common-data-airflow/docs/hellobot-data/catalog/` |

(없으면 "없음" 으로 표기)

### 미해결 이슈 처리

| ID | 처리 | 비고 |
|----|------|------|
| ISS-008 | 후속 프로젝트로 이관 | 후속 프로젝트명/링크 |
| ISS-011 | SSOT(`catalog/issues.md`)로 이전 | 데이터 인프라 영속 이슈 |
| ISS-099 | drop | 사유: 우선순위 낮음, 별도 추적 불필요 |

(없으면 "없음" 으로 표기)

### 워크트리/브랜치 정리

| 리포 | 브랜치 | 워크트리 | 정리 예정일 |
|------|--------|---------|------------|
| common-data-airflow | `Feat/data-infra-documentation` | `worktrees/common-data-airflow` | 2026-05-06 (hotfix 윈도우 종료 후) |

### 회고 (선택)

- 잘된 점:
- 개선할 점:
```

---

## 문서별 템플릿

### readme.md (요구사항)

```markdown
# {프로젝트명}

## 배경
{왜 이 기능이 필요한지}

## 목표
{달성하려는 목표}

## 범위
- 포함: {구현할 내용}
- 제외: {구현하지 않을 내용}

## 영향 범위
| 파트 | 영향 | 설명 |
|------|------|------|
| 서버 | O | {어떤 변경이 필요한지} |
| iOS | O | {어떤 변경이 필요한지} |
| Android | O | {어떤 변경이 필요한지} |
| 웹 | X | 해당없음 |
| 스튜디오 | X | 해당없음 |
| 데이터 | X | 해당없음 |

## 문서 목록
| 문서 | 설명 |
|------|------|
| [status.md](./status.md) | 전체 진행 상태 |
| [tasks.md](./tasks.md) | 파트별 과업 목록 |
| [issues.md](./issues.md) | 이슈 추적 |
| [architecture.md](./architecture.md) | 기술 아키텍처 |
| [api-spec.md](./api-spec.md) | API 명세 |
| [qa-test-cases.md](./qa-test-cases.md) | QA 테스트 케이스 |
```

---

### status.md (경량 대시보드)

현재 상태를 한눈에 파악하기 위한 대시보드. 작업 로그는 기록하지 않음 (git log, 리포 status.md 결정 로그 참조).

```markdown
# 개발 상태

## 현재 상태: {분석중|설계중|개발중|리뷰중|완료|보류}

## 파트별 현황

| 파트 | 상태 | 브랜치 | 워크트리 | 비고 |
|------|------|--------|---------|------|
| 기획 | - | - | - | |
| 서버 | 대기 | feat/xxx | worktrees/hellobot-server/ | |
| iOS | 대기 | - | - | 서버 API 완료 후 착수 |
| Android | 대기 | - | - | |
| 웹 | 해당없음 | - | - | |
| 스튜디오 | 해당없음 | - | - | |
| 데이터 | 해당없음 | - | - | |
| QA | 대기 | - | - | |

## 블로커

없음

## 확정 사항

| 항목 | 내용 |
|------|------|
```

**상태값 정의**:
| 상태 | 설명 |
|------|------|
| `분석중` | /analyze가 요구사항 분석 중 |
| `설계중` | /architect이 기술 설계 중 |
| `개발중` | /dev-* 가 구현 중 |
| `리뷰중` | /review가 검토 중 |
| `QA중` | /qa가 테스트 케이스 작성 또는 검수 중 |
| `완료` | 전체 완료 |
| `보류` | 일시 중단 |
| `대기` | 선행 작업 완료 대기 |
| `해당없음` | 이 프로젝트에서 작업 불필요 |

---

### tasks.md (과업 분류)

```markdown
# 과업 목록

## 기획 (planning/)
- [ ] {상품 정의, 데이터 분석, 리서치 등 개발 외 과업}
- [ ] {결과물은 planning/ 디렉토리에 기록}

## 서버 (/dev-server)
- [ ] {과업 1 설명}
- [ ] {과업 2 설명}

## iOS (/dev-ios)
- [ ] {과업 1 설명}

## Android (/dev-android)
- [ ] {과업 1 설명}

## 웹 (/dev-web)
해당없음

## 스튜디오 (/dev-studio)
해당없음

## 데이터 (/dev-data)
해당없음

## QA (/qa)
- [ ] 테스트 케이스 작성 (qa-test-cases.md)
- [ ] 테스트 수행 및 결과 기록

## 의존 관계
- iOS, Android는 서버 API 완료 후 착수
- 데이터 파이프라인은 서버 테이블 확정 후 착수
- {기획 과업 확정 → 개발 착수 등의 의존 관계}
```

---

### issues.md (이슈 레지스트리)

이슈를 수집/취합하는 레지스트리. 해결 상세는 기록하지 않음 (tasks.md 과업 + 커밋으로 추적).
프로젝트 시작 시 생성하지 않으며, 첫 이슈 발생 시 생성합니다.

```markdown
# 이슈 목록

## 이슈 분류
- **bug**: 구현이 설계와 다름
- **edge-case**: 설계에서 고려하지 못한 예외 상황
- **enhancement**: 기존 요구사항 범위 밖의 개선

---

### ISS-001: {이슈 제목}

| 분류 | {bug / edge-case / enhancement} |
| 발견일 | YYYY-MM-DD |
| 심각도 | {P1 / P2 / P3} |
| 영향 파트 | {서버, 웹, iOS 등} |
| 상태 | {미해결 / 해결 (YYYY-MM-DD)} |

**현상**: {무엇이 발생하는지 — 1~2줄}
**원인**: {왜 발생하는지 — 1~2줄}
```

> **이슈 처리 흐름**: 이슈 발견 → issues.md 등록 + tasks.md 과업 추가 → 구현 → issues.md 상태 변경 + tasks.md 체크

**심각도 정의**:
| 심각도 | 설명 | 대응 |
|--------|------|------|
| P1 | 데이터 무결성/보안, 핵심 기능 장애 | 즉시 대응 |
| P2 | 주요 기능 오류 | 릴리스 전 수정 |
| P3 | 사소한 이슈 | 후속 수정 가능 |

**상태 흐름**:
```
등록 → 분석중 → 설계수정 → 구현중 → 검증 → 완료
                    │                       ↑
                    └── (단순 버그) ─────────┘
```

---

### architecture.md (기술 아키텍처)

```markdown
# 기술 설계

## 1. 개요
{기능의 기술적 개요}

## 2. 데이터 흐름
{시스템 간 데이터 흐름 설명 또는 다이어그램}

## 3. API 계약
{서버-클라이언트 간 주요 API 요약}
상세 스펙: [api-spec.md](./api-spec.md)

## 4. 데이터 모델
{새로 추가되는 테이블/컬렉션 설계}

## 5. 처리 로직
{주요 비즈니스 로직 흐름}

## 6. 파트별 구현 포인트
### 서버
{서버에서 구현할 핵심 사항}

### iOS
{iOS에서 구현할 핵심 사항}

### Android
{Android에서 구현할 핵심 사항}

---

## Changelog

| 날짜 | 이슈 | 변경 내용 |
|------|------|----------|
```

> **Changelog 규칙**: 이슈로 인한 설계 변경 시 반드시 기록합니다.
> api-spec.md에도 동일한 Changelog 섹션을 둡니다.

---

## 프로젝트 목록

| 날짜 | 프로젝트명 | 상태 | 설명 |
|------|-----------|------|------|
| 2026-04-23 | [admin-performance](./20260423-admin-performance/) | 설계완료 · 구현대기 | AdminJS dev 환경 초기 로드 지연 해결 — dev Secrets Manager에 `NODE_ENV=production` 추가 + 서버 번들 프리빌드·compression 방어 |
| 2026-04-22 | [data-infra-documentation-v2](./20260422-data-infra-documentation-v2/) | 진행중 (장기) | 데이터 카탈로그 SSOT 점진적 보강 — 1차 인계 백로그 + 다른 프로젝트 진행 중 식별되는 카탈로그 확장 누적 |
| 2026-04-22 | [data-infra-documentation](./20260422-data-infra-documentation/) | 완료 (2026-04-22) | HelloBot 데이터 카탈로그를 `common-data-airflow/docs/hellobot-data/catalog/` 로 이전 + 동기화 규칙 신설 ([PR #176](https://github.com/thingsflow/common-data-airflow/pull/176)). ISS-001 해결, ISS-002~011 SSOT 이전. 후속: data-infra-documentation-v2 |
| 2026-04-15 | [workspace-ops-improvement](./20260415-workspace-ops-improvement/) | 완료 | 프로젝트 문서 구조 개선 — 중복 제거, 단일 소스 확립, design.md→architecture.md 명칭 변경 |
| 2026-04-11 | [workspace-setup](./20260411-workspace-setup/) | 시범운영 | 통합 개발 환경 구축 — 구조/문서/커맨드 완료, coop-integration으로 검증 중 |
| 2026-03-24 | [coop-integration](./20260324-coop-integration/) | 개발중 | 카카오 선물하기 상품권 연동 — Phase 1 아키텍처 개편 완료(서버/iOS/Android/웹 구현 완료), QA 검증 및 배포 대기 |
