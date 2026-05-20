# TODO-023 쿠프마케팅 compCode env 분리 (ISS-055, P1)

**유형**: 액션 (일정 결정 필요)
**상태**: 진행 중 — 해결 방향 확정, 패치 착수 일정 미정
**등록**: 2026-05-20
**시작**: -
**완료**: -
**마감**: - (TODO-013 umbrella 와 동일 사이클)
**담당**: 코디네이터 → /dev-server + /dev-infra 위임 (일정 도래 시)
**관련**: [coop-integration ISS-055](../projects/20260324-coop-integration/issues.md), [TODO-013 (카카오 핫픽스 잔여 umbrella)](TODO-013-kakao-hotfix-residual.md)

## 컨텍스트

`src/common/config.ts:594` 의 `coopMarketing.compCode` 가 `"A911"` 로 하드코딩되어 모든 환경(local/dev/testing/staging/prod) 에서 동일 값 송신. 같은 블록의 `authKey` 는 `process.env.COOP_MARKETING_AUTH_KEY` 로 환경변수화 완료 / `url` 은 `isProduction` 분기 적용 / `compCode` 만 누락된 비대칭 상태.

**확정 값**:
- 개발: `COOP_MARKETING_COMP_CODE=A911`
- 운영: `COOP_MARKETING_COMP_CODE=X259`

**참고**: 같은 어댑터 파일 `giftiel:574` 는 이미 `compCode: isProduction ? "A376" : "A294"` 로 환경 분리 완료 — `coopMarketing` 도 동일 정책 적용 가능.

**근본 원인**: 최초 구현 시 쿠프마케팅 측 단일 브랜드코드 안내(`A911`) 로 dev/prod 분리 필요성을 인지하지 못함. 이후 운영 브랜드코드(`X259`) 별도 발급으로 env 분리 필요.

## 현재 상태

해결 방향 확정 (env var 전환 + EKS 매니페스트 등록). 운영 영향: 현재는 dev/prod 모두 `A911` 송신 중이라 운영 브랜드코드 (`X259`) 가 정상 작동하지 않을 가능성. 운영 출시 후 카카오 측 인증/정산 정합 영향 검토 필요.

## 다음 단계

- [ ] 처리 일정 결정 (사용자 협의) — TODO-013 umbrella 와 함께 결정
- [ ] `/dev-server` 위임 — `src/common/config.ts:594`:
  - `compCode: process.env.COOP_MARKETING_COMP_CODE` (기본값 없음 — env 누락 시 빈 CompCode 로 쿠프마케팅 인증 실패하여 즉시 표면화)
- [ ] `/dev-infra` 위임 — EKS 매니페스트(`common-infra-eks-deploy/overlays/hlb/{dev,prod}/[apn1]/{service}/`) dev/prod 환경별 `COOP_MARKETING_COMP_CODE` 시크릿 등록
- [ ] 운영 배포 후 카카오 측 인증/정산 정합 확인 (브랜드코드 변경 영향)

## 진행 로그

- 2026-05-20 — TODO 등록. 사용자 요청으로 ISS-055 (P1) 가 status.md 잔여 표에 묻혀 있던 것을 우선순위 보드 가시 항목으로 격상.
