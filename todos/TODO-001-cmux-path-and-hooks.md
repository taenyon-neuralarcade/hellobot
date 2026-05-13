# TODO-001 cmux PATH 심링크 + hooks 점검

**상태**: 완료
**등록**: 2026-05-13
**시작**: 2026-05-13
**완료**: 2026-05-13
**마감**: -
**담당**: 코디네이터
**관련**: 직전 대화의 cmux 활용 검토 결과

## 컨텍스트

cmux app(`/Applications/cmux.app/Contents/Resources/bin/cmux`)이 PATH에 없어 모든 자동화가 풀 경로로 무거움. 또한 `~/.claude/settings.json`에 cmux 후크가 어떻게 들어가 있는지 점검 필요.

## 현재 상태

완료. 심링크 생성 + 후크 메커니즘 확인. 추가 manual install 없음.

## 다음 단계

(완료)

## 진행 로그

- 2026-05-13 — TODO 등록, 환경 조사 시작
- 2026-05-13 — `/opt/homebrew/bin` 쓰기 권한 확인 (admin 그룹, sudo 불필요)
- 2026-05-13 — `~/.claude/settings.json` 조회: figma 플러그인 + autoCompactEnabled만 있음. cmux 관련 후크 없음 (예상대로)
- 2026-05-13 — cmux Claude wrapper(`/Applications/cmux.app/Contents/Resources/bin/claude`) 분석: bash 스크립트, `CMUX_SURFACE_ID` 감지 시 `claude --session-id ... --settings <inline JSON>` 형태로 실행. 후크는 settings.json 파일이 아닌 **CLI argument에 인라인 JSON으로 주입**.
- 2026-05-13 — 현재 세션(PID 28495)의 인자 확인: 7개 후크 이벤트가 모두 `cmux hooks <event>` 콜백으로 와이어링됨 (SessionStart / Stop / SessionEnd / Notification / UserPromptSubmit / PreToolUse / PermissionRequest)
- 2026-05-13 — `/bin/ln -s` 로 `/opt/homebrew/bin/cmux` 심링크 생성, `zsh -i -c 'cmux version'` 으로 인터랙티브 셸에서 동작 확인 (cmux 0.64.4)
- 2026-05-13 — `~/.config/cmux/cmux.json` 확인: 디폴트 템플릿(전부 주석 처리). 알림 관련 디폴트값(sound/dockBadge/unreadPaneRing/paneFlash 모두 활성)은 그대로 사용 중

## 결론

### 1. 심링크 — 완료

```
/opt/homebrew/bin/cmux -> /Applications/cmux.app/Contents/Resources/bin/cmux
```

이제 모든 셸/에이전트에서 `cmux ...` 로 호출 가능.

### 2. 후크 — 이미 완전히 동작 중, 추가 작업 불필요

cmux는 사용자의 `~/.claude/settings.json`을 건드리지 않음. 대신 자체 wrapper 스크립트(`Contents/Resources/bin/claude`)가 매 Claude 세션 launch 시 `--settings` 플래그로 인라인 JSON을 전달해서 후크를 주입함. 따라서:

- `cmux hooks setup`은 Claude 대상이 아님 (도움말의 agent 목록에 claude 없음 — codex/opencode/cursor 등만 해당)
- `~/.claude/settings.json`을 cmux용으로 손댈 필요 없음. 현재 깨끗함.
- 모든 후크 이벤트가 자동으로 와이어링되어 cmux UI(워크스페이스 자동 명명, 페인 알림 링, 사이드바 진행 표시)를 구동 중

주입되는 후크 이벤트:

| 이벤트 | 후크 호출 | 비고 |
|--------|---------|------|
| SessionStart | `cmux hooks session-start` | 세션 시작 시 |
| Stop | `cmux hooks stop` + `cmux hooks claude` (async) | 응답 종료 시 |
| SessionEnd | `cmux hooks session-end` | 세션 종료 시 |
| Notification | `cmux hooks notification` | Claude 알림 발생 시 |
| UserPromptSubmit | `cmux hooks prompt-submit` | 사용자 프롬프트 제출 시 |
| PreToolUse | `cmux hooks pre-tool-use` (async) | 도구 호출 직전 |
| PermissionRequest | `cmux hooks permission-request` | 권한 요청 시 |

### 3. 부가 발견 (사용자 결정 필요한 별건)

**(a) 인터랙티브 셸 PATH 버그 — 별도 처리 권장**

현재 `zsh -i` 의 `$PATH`에 리터럴 `${PATH}` 문자열이 들어 있고, rbenv-init이 `mkdir`/`mv` 를 못 찾는 경고를 띄움. `.zshrc` 어딘가에서 `export PATH="...:${PATH}:..."` 식으로 PATH를 합치는데 그 시점에 `$PATH`가 비어있어 리터럴이 그대로 박힌 것으로 추정.

영향: 일부 명령(예: `which`, `mkdir` 등)이 PATH에서 안 잡힐 수 있음. cmux 동작에는 직접 영향 없음.

조치 권장: 사용자 확인 후 `.zshrc` PATH 빌드 순서를 점검할지 결정.

**(b) 데스크탑 알림 배너**

cmux 디폴트는 **사운드 + Dock 배지 + 페인 링** 활성, 그러나 macOS 알림 센터 배너는 cmux GUI Settings에서 별도 토글하는 것으로 보임 (`~/.config/cmux/cmux.json`에는 명시 토글 없음). 다른 워크스페이스에서 작업 중일 때 현재 워크스페이스의 Claude 대기를 모르고 지나치는 패턴이 있다면 cmux 앱 설정에서 banner notification 켜는 것 추천.
