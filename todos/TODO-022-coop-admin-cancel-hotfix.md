# TODO-022 운영 어드민 사용취소 hotfix — L2 8005 idempotent + recovered_at 가드 (ISS-056, P0)

**유형**: 액션
**상태**: ✅ **운영 배포 완료 (2026-05-21 11:30)** — 운영 정합화 잔여 (별도 단계)
**등록**: 2026-05-20
**시작**: 2026-05-20
**완료**: - (운영 정합화 완료 시점에 종료 처리)
**마감**: -
**담당**: /dev-server
**관련**: [coop-integration ISS-056](../projects/20260324-coop-integration/issues.md), [TODO-013 (카카오 핫픽스 잔여 umbrella)](TODO-013-kakao-hotfix-residual.md)

## 컨텍스트

운영 환경 어드민(AdminJS) 에서 카카오 쿠폰 사용 취소 클릭 시 성공 노티는 표시되나 `coop_marketing_coupon_usage.canceled_at` 이 NULL 로 유지되어 DB 가 `status='used'` 그대로 남는 결함. 운영자가 동일 증상으로 4회 연타 → 동일 결과. 2026-05-06 사용자 보고로 발견, 사용자 협의로 해결 방향 확정 후 패치 미착수 상태.

**근본 원인 3종 복합** (`issues.md` ISS-056):

1. **L2 8005 사일런트 스킵** — `cancelCoupon` 이 ResultCode `0000` 만 success 로 보고 DB 갱신, `8005`(이미 사용취소된 쿠폰) 는 throw 없이 스킵 → 운영자 인지 불가
2. **회수 가드가 회수 완료 여부 미점검** — step 1 가드가 `usage.heartLogSeq`(=L1 충전 로그) 만 확인 → 클릭마다 `heart_log` 의 `use_by_gift_coupon_recovery` 적재 + 잔액에 따라 중복 차감 (919758897939 케이스 4×360=1440 하트까지 가능)
3. **어드민 동시 클릭 보호 없음** — `isAccessible` 가드는 클라이언트 캐시 기반, 서버 측 직렬화 부재

**영향**:
- 운영 데이터 불일치 — 쿠프마케팅 canceled vs 헬로우봇 DB used → BigQuery 인입(`coop_kakao_first_used_date` 등) 정확도 저하
- 사용자 하트 중복 차감 (실제 차감 수량 검증 필요)
- 운영자가 "성공" 노티만 보고 동일 동작 반복 → 차감 누적

## 현재 상태

✅ **운영 배포 완료 (2026-05-21 11:30)** — PR [#2421](https://github.com/thingsflow/hellobot-server/pull/2421) master 머지 + ArgoCD 운영 sync 완료. 어드민 사용취소 회로의 idempotent 처리 + `recovered_at` 가드 + ResultCode 노출이 운영 환경에 적용됨.

**잔여 — 운영 정합화 (별도 단계, 일정 결정 필요)**: 5/6 919758897939 행 + heart_log 환원. 패치 자체는 운영에 안전 상태이지만 과거 발생 데이터 청소는 미처리.

## 다음 단계

- [x] ~~사용자 검토 + 커밋 단행~~ (commit `ca891cfc`)
- [x] ~~origin 푸시 + PR 생성~~ ([#2421](https://github.com/thingsflow/hellobot-server/pull/2421))
- [x] ~~PR 리뷰 + master 머지 + ArgoCD 운영 sync~~ (**2026-05-21 11:30 운영 배포 완료**)
- [ ] **배포 후 운영 정합화 (별도 단계 — 일정 결정 필요)**:
  - 919758897939 행 직접 UPDATE — `status='canceled', canceled_at='2026-05-06 04:02:00+00', recovered_at=<heart_log 첫 회수 시각>`
  - `heart_log` 의 14:18~14:24 회수 건수 검증 → 중복 차감분 ChargeByCs 환원
  - 13:02 시점 취소 주체 추적 — `coop_marketing_api_log` 동일 시각대 자동 L2/L3 + 운영자 admin 로그
- [ ] 정합화 완료 후 본 TODO 종료 처리

## 구현 사항 (2026-05-20)

| # | 파일 | 변경 |
|---|------|------|
| 1 | `src/models/migrations/1779000000000-AddRecoveredAtToCoopMarketingCouponUsage.ts` | **신규**. `recovered_at` timestamptz null 컬럼 + 기존 `status='canceled' AND canceled_at IS NOT NULL` 행 백필(`recovered_at = canceled_at`) |
| 2 | `src/models/entities/CoopMarketingCouponUsage.ts` | `recoveredAt: Date \| null` 컬럼 추가, comment 포함 |
| 3 | `src/services/coop-marketing.ts` — `cancelCoupon` | L2 응답 `0000` 또는 `8005` 모두 `COALESCE(canceled_at, NOW())` raw SQL 로 idempotent canceled 마킹. 그 외 비-success 는 winston 로그 + `new Error("쿠프마케팅 사용취소 실패 (ResultCode=..., ResultMsg=...)")` throw → 어드민 noticeMessage 에 ResultCode/ResultMsg 노출(기존 admin handler `options.ts:84` 의 `throw new Error(...)` 패턴과 정합). 자동 보상 경로(line 413/484)는 기존 catch 로 영향 없음 |
| 4 | `src/services/coop-marketing.ts` — `adminCancelCoupon` | L2 동기화 → 회수 순서 재배치. `recoveredAt` 가드(`if (usage.recoveredAt) return`). `recoverProduct` 별도 private 메서드로 분리. **redLock 미도입** (사용자 결정 — 어드민 페이지 연타 보호 불필요, 본 사고는 90초 간격이라 TTL 10s 차단 불가) |
| 5 | `src/services/coop-marketing.ts` — `recoverProduct` (신규 private) | heart(useHeart 차감) / skill(이용권 삭제) 회수 후 무조건 `recoveredAt = NOW()` 마킹. 부분/0 회수도 마킹(회수 시도 1회로 종료). 회수 단계 throw 시 마킹 안 됨 → 다음 클릭에 재시도 가능 |
| 6 | `src/admin/options/CoopMarketingCouponUsage.options.ts` | `listProperties`/`showProperties` 에 `recoveredAt` 추가 |

## 진행 로그

- 2026-05-20 — TODO 등록 (가시화)
- 2026-05-20 — /dev-server 진입. 신규 hotfix 브랜치 + 워크트리 생성(origin/master `2da9eda5` 기준). 기존 구현 점검(자동 보상 경로 영향 없음 확인). Entity + Migration 작성. cancelCoupon 8005 idempotent. adminCancelCoupon 재구성 (초안 redLock 포함). Admin options 갱신. tsc 검증(symlink 환경 차이의 hackle 2건만 잔존, 본 패치 0 에러). coop-integration status.md/issues.md 동기. 커밋 대기.
- 2026-05-20 — /review 거쳐 사용자 협의로 2건 조정: ① **redLock 제거** — 어드민 페이지 연타 보호 불필요 + 본 사고(90초 간격 클릭) 차단 불가 + hotfix 의도 본질에서 벗어남. `recovered_at IS NULL` 가드만으로 회수 중복 차단 충분. ② **HttpError → Error 교체** — HttpError 는 `super()` 만 호출하여 `err.message` 빈 문자열이라 어드민 noticeMessage 에 ResultCode 노출되지 않음. 기존 admin handler `options.ts:84` 의 `throw new Error(...)` 패턴과 정합화. 재검증 tsc 통과.
- 2026-05-20 — 커밋 (`ca891cfc`) + origin push + PR 생성 ([#2421](https://github.com/thingsflow/hellobot-server/pull/2421)). 본 PR 본문에 케이스별 어드민 동작·호환성 검토·Test plan 포함.
- **2026-05-21 11:30 — 운영 배포 완료** — PR #2421 master 머지 + ArgoCD 운영 sync. 어드민 사용취소 회로 idempotent 처리·`recovered_at` 가드·ResultCode 노출 운영 적용. 운영 정합화(919758897939 SQL + heart_log 환원)는 별도 단계로 일정 결정 잔여.

## 해결 방향 (사용자 협의 완료)

1. **취소 상태 동기화** — `cancelCoupon` 이 L2 응답 `0000` OR `8005` 둘 다 idempotent canceled 마킹 (`COALESCE(canceled_at, NOW())`). 그 외 비-success 는 throw 로 어드민 표면화.
2. **상품 회수 상태 분리** — `recovered_at` 신규 컬럼. `adminCancelCoupon` 의 회수 가드를 `recovered_at IS NULL` 로 교체. 취소 응답과 회수 처리 독립 가드 — 어느 단계가 끊겨도 끊긴 단계만 재실행.
3. **동시 클릭 직렬화** — `redLock("coop:admin-cancel:${userSeq}:${couponCode}", 10000)` 로 연타 보호.
4. **L2 → 회수 순서 재배치** — 현행 회수→L2 → 신규 L2 동기화→회수.

**부분 회수 정책 (확정)**: 사용자 잔액 부족 시 `Math.min(heartQuantity, totalUsable)` 부분 차감 후 `recovered_at` 마킹 — 회수 시도 1회로 종료, 운영자가 잔액 보고 추가 조치 판단.

**자동 보상 경로 영향**: `cancelCoupon` 자동 호출 경로(`coop-marketing.ts:416, 487`) 는 "지급 실패 → L2 만 호출 (회수 불필요)" 컨텍스트로 회수 가드 변경 영향 없음. 8005 idempotent 처리는 자동 경로에도 동일 적용 — 이미 취소된 상태를 만나도 안전 종료.

## 진행 로그

- 2026-05-20 — TODO 등록. 사용자 요청으로 ISS-056 (P0) 가 status.md 잔여 표에 묻혀 있던 것을 우선순위 보드 가시 항목으로 격상. 해결 방향은 2026-05-06 사용자 협의로 이미 확정, 패치 일정만 미정.
