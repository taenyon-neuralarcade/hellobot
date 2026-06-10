# TODO-023 쿠프마케팅 compCode env 분리 (ISS-055, P1)

**유형**: 액션
**상태**: 완료
**등록**: 2026-05-20
**시작**: 2026-05-05 (코드 작업, 5/20 가시화 등록)
**완료**: 2026-05-20 (가시화 등록 직후 완료 처리 — 코드/매니페스트/배포 모두 5/5 시점 완료된 사실 확인)
**마감**: -
**담당**: /dev-server (코드) + /dev-infra (매니페스트) — 모두 처리됨
**관련**: [coop-integration ISS-055](../projects/20260324-coop-integration/issues.md), [TODO-013 (카카오 핫픽스 잔여 umbrella)](TODO-013-kakao-hotfix-residual.md)

## 컨텍스트

`src/common/config.ts:594` 의 `coopMarketing.compCode` 가 `"A911"` 로 하드코딩되어 모든 환경(local/dev/testing/staging/prod) 에서 동일 값 송신. 같은 블록의 `authKey` 는 `process.env.COOP_MARKETING_AUTH_KEY` 로 환경변수화 완료 / `url` 은 `isProduction` 분기 적용 / `compCode` 만 누락된 비대칭 상태.

**확정 값**:
- 개발: `COOP_MARKETING_COMP_CODE=A911`
- 운영: `COOP_MARKETING_COMP_CODE=X259`

**참고**: 같은 어댑터 파일 `giftiel:574` 는 이미 `compCode: isProduction ? "A376" : "A294"` 로 환경 분리 완료 — `coopMarketing` 도 동일 정책 적용 가능.

**근본 원인**: 최초 구현 시 쿠프마케팅 측 단일 브랜드코드 안내(`A911`) 로 dev/prod 분리 필요성을 인지하지 못함. 이후 운영 브랜드코드(`X259`) 별도 발급으로 env 분리 필요.

## 현재 상태

✅ **완료** — 2026-05-05 코드 작업 + 인프라 매니페스트 등록 + 운영 배포까지 완료. 5/20 가시화 등록 시점에 사용자가 "이미 운영서버 배포까지 완료된 상태"라고 확인. 코드 브랜치(`hotfix/coop-marketing-comp-code-env`)는 master 머지 흔적 없이도 운영에 반영되어 있음 (별도 release 경로로 머지/배포된 것으로 추정).

## 진행 로그

- 2026-05-05 — 코드 작업 완료. 커밋 `64ac9081 fix(coop-marketing): CompCode 환경변수화 (ISS-055)`. `src/common/config.ts:594` 한 줄 변경 (`compCode: "A911"` → `process.env.COOP_MARKETING_COMP_CODE`). 브랜치 `hotfix/coop-marketing-comp-code-env` origin push.
- 2026-05-05 ~ 5/20 사이 — 인프라 매니페스트 dev/prod env 등록 + 운영 배포 진행됨 (별도 경로, /dev-infra).
- 2026-05-20 — TODO-023 신규 등록(우선순위 보드 가시화 목적). 직후 /dev-server 진입 점검 중 워크트리·커밋·푸시 흔적 확인 → 사용자에게 현황 보고 → "이미 운영서버 배포까지 완료"라는 답변 수령 → 완료 처리.

## 정리 작업 (별건)

- 워크트리 `worktrees/hellobot-server-hotfix-comp-code/` — 안정 기간 경과 후 `git worktree remove` (status.md "운영 핫픽스 워크트리 정리" 과업 #34 의 일부)
- coop-integration `issues.md` ISS-055 상태 "미해결" → "해결 (2026-05-05)" 정정 — 본 TODO 완료 처리 동시 진행
