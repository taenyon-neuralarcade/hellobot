# TODO-002 cmux 새 워크스페이스 spawn 동작 검증

**상태**: 완료
**등록**: 2026-05-13
**시작**: 2026-05-13
**완료**: 2026-05-13
**마감**: -
**담당**: 코디네이터
**관련**: 직전 대화의 "별도 세션에서 작업 위임" 패턴 검토

## 컨텍스트

cmux 의 `new-workspace` 로 별도 Claude 세션을 spawn 하고 코디네이터가 다른 작업을 병렬로 수행하는 패턴을 검증. 실전 워커 spawn 전에 빈 워크스페이스로 핵심 능력 확인.

## 현재 상태

완료. 5단계 라운드트립(spawn → tree 확인 → send → read-screen → close) 모두 동작 확인. 발견된 함정 2건 문서화.

## 다음 단계

(완료)

## 진행 로그

- 2026-05-13 — TODO 등록, 검증 시작
- 2026-05-13 — `cmux tree` 로 spawn 전 상태 스냅샷: workspace:1 단일
- 2026-05-13 — `cmux new-workspace --name "spawn-test (TODO-002)" --cwd /tmp --focus false` 실행 → `OK workspace:2` 응답, tree 에 workspace:2 추가됨, 내 세션(workspace:1)은 그대로 selected/active 유지
- 2026-05-13 — `cmux send --workspace workspace:2 "pwd && echo HELLO_FROM_COORDINATOR"` + `send-key Enter` → 양쪽 모두 `OK surface:2 workspace:2` 응답
- 2026-05-13 — `cmux read-screen --workspace workspace:2 --surface surface:2 --lines 30` → 셸 출력 회수 성공: `/tmp` + `HELLO_FROM_COORDINATOR` 라인 확인
- 2026-05-13 — `cmux close-workspace --workspace workspace:2` → `OK workspace:2`, tree 에서 깨끗하게 제거
- 2026-05-13 — 함정 2건 발견 → 결론 §사용 가이드 정리

## 결론

### 라운드트립 동작 확인

| 단계 | 명령 | 결과 |
|------|------|------|
| spawn | `cmux new-workspace --name X --cwd Y --focus false` | ✅ workspace:N 생성, 현재 세션 영향 없음 |
| 식별 | `cmux tree --all` | ✅ 신규 워크스페이스 표시 |
| 명령 주입 | `cmux send --workspace <ref> "<text>"` + `send-key Enter` | ✅ 셸이 명령 수신 |
| 화면 회수 | `cmux read-screen --workspace <ref> --surface <ref> --lines N` | ✅ 출력 텍스트 수령 |
| 정리 | `cmux close-workspace --workspace <ref>` | ✅ 깨끗하게 제거 |

### 함정 1: ref 모호성 — `--workspace` + `--surface` 둘 다 명시 필요

`read-screen --surface surface:2` 단독으로는 "Surface is not a terminal" 에러. 워크스페이스가 여러 개일 때 짧은 ref(`surface:N`)는 모호함. 다음 중 하나 사용:

- `--workspace <ref> --surface <ref>` (양쪽 명시) — 가장 안전
- UUID 사용 (`--id-format uuids` 로 조회 후)
- 환경변수 `CMUX_WORKSPACE_ID` / `CMUX_SURFACE_ID` 자동 주입(자기 워크스페이스 한정)

`send` / `send-key` 는 `--workspace` 만 줘도 동작했음 (read-screen 만 양쪽 필요한 듯) — 안전을 위해 모든 다른-워크스페이스 명령에 양쪽 명시 권장.

### 함정 2: spawn 직후 surface 미준비 시간

`new-workspace` 직후 `cmux tree` 가 surface 를 보여주긴 하지만 `tty=` 가 비어 있는 상태. read-screen 이 "Terminal surface not found" 로 실패. 약 1초 대기 후 tty 가 attach 되며 read 가 가능해짐.

→ 실전 워커 spawn 시: spawn 직후 첫 read 전에 짧은 대기(`sleep 1` 정도) 또는 tree 에서 `tty=` 채워질 때까지 폴링.

### 다음 단계 (실전 워커 spawn 시 적용)

1. **자기완결 브리핑 패턴**: `--command "claude"` 로 spawn 후 `cmux send --workspace <ref> "<긴 브리핑>"` + `send-key Enter` 로 첫 메시지 주입. 브리핑에는 본 대화 컨텍스트 + 결정 권한 + 금지 사항 + 보고 형식 모두 포함 (워커는 본 세션 컨텍스트 모름).
2. **알림 의존**: 워커가 사용자 입력 필요할 때 cmux notification + 사이드바 깜빡임으로 알림. 코디네이터가 폴링할 필요 없음.
3. **상태 조회**: 코디네이터가 워커 진행을 보고 싶으면 `cmux read-screen --workspace <ref> --surface <ref> --lines 50` 으로 스냅샷.
4. **종료 처리**: 워커가 완료 보고하면 코디네이터가 `cmux close-workspace --workspace <ref>` 로 정리. 사용자가 직접 닫는 것도 가능.

### 워크플로우 정착 권장 위치

이 패턴은 [`workspace-evolution`](../projects/20260503-workspace-evolution/) 프로젝트의 "Claude Code 기능 활용" 섹션에 정식 운영 규칙으로 정착시키는 것이 적절. 본 검증 결과를 그 프로젝트 산출물의 입력으로 사용 가능.
