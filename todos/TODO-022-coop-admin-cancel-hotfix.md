# TODO-022 운영 어드민 사용취소 hotfix — L2 8005 idempotent + recovered_at 가드 (ISS-056, P0)

**유형**: 액션 (일정 결정 필요)
**상태**: 진행 중 — 해결 방향 확정, 패치 착수 일정 미정
**등록**: 2026-05-20
**시작**: -
**완료**: -
**마감**: - (P0지만 일정 결정 보류, TODO-013 umbrella 와 동일 사이클로 결정 예정)
**담당**: 코디네이터 → /dev-server 위임 (일정 도래 시)
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

해결 방향은 사용자 협의로 확정. 실 패치 착수 미정 — TODO-013 의 "일정 결정 보류" 상태와 동일 사이클로 처리 예정. **P0 이지만 사용자가 직접 새 추가 요청을 하기 전까지는 보류**.

## 다음 단계

- [ ] 처리 일정 결정 (사용자 협의) — TODO-013 umbrella 와 함께 일정 결정
- [ ] 일정 도래 시 `/dev-server` 위임 — 수정 범위 4 파일 / 실질 ~100줄:
  - `src/models/migrations/<NN>-AddRecoveredAtToCoopMarketingCouponUsage.ts` 신규 — `recovered_at` 컬럼 + 기존 `canceled` 행 `recovered_at = canceled_at` 백필
  - `src/models/entities/CoopMarketingCouponUsage.ts` — `recoveredAt` 컬럼 1줄
  - `src/services/coop-marketing.ts` — `cancelCoupon` 8005 idempotent + `adminCancelCoupon` 재구성 + `recoverProduct` 분리 + L2→회수 순서 재배치 + redLock 직렬화
  - `src/admin/options/CoopMarketingCouponUsage.options.ts` — `recoveredAt` 노출, `isAccessible` 가드 정밀화 (선택)
- [ ] 운영 정합화 (별도 hotfix 단계):
  - 919758897939 행 직접 UPDATE — `status='canceled', canceled_at='2026-05-06 04:02:00+00', recovered_at=<heart_log 첫 회수 시각>`
  - `heart_log` 의 14:18~14:24 회수 건수 검증 → 중복 차감분 ChargeByCs 환원
  - 13:02 시점 취소 주체 추적 — `coop_marketing_api_log` 동일 시각대 자동 L2/L3 + 운영자 admin 로그

## 해결 방향 (사용자 협의 완료)

1. **취소 상태 동기화** — `cancelCoupon` 이 L2 응답 `0000` OR `8005` 둘 다 idempotent canceled 마킹 (`COALESCE(canceled_at, NOW())`). 그 외 비-success 는 throw 로 어드민 표면화.
2. **상품 회수 상태 분리** — `recovered_at` 신규 컬럼. `adminCancelCoupon` 의 회수 가드를 `recovered_at IS NULL` 로 교체. 취소 응답과 회수 처리 독립 가드 — 어느 단계가 끊겨도 끊긴 단계만 재실행.
3. **동시 클릭 직렬화** — `redLock("coop:admin-cancel:${userSeq}:${couponCode}", 10000)` 로 연타 보호.
4. **L2 → 회수 순서 재배치** — 현행 회수→L2 → 신규 L2 동기화→회수.

**부분 회수 정책 (확정)**: 사용자 잔액 부족 시 `Math.min(heartQuantity, totalUsable)` 부분 차감 후 `recovered_at` 마킹 — 회수 시도 1회로 종료, 운영자가 잔액 보고 추가 조치 판단.

**자동 보상 경로 영향**: `cancelCoupon` 자동 호출 경로(`coop-marketing.ts:416, 487`) 는 "지급 실패 → L2 만 호출 (회수 불필요)" 컨텍스트로 회수 가드 변경 영향 없음. 8005 idempotent 처리는 자동 경로에도 동일 적용 — 이미 취소된 상태를 만나도 안전 종료.

## 진행 로그

- 2026-05-20 — TODO 등록. 사용자 요청으로 ISS-056 (P0) 가 status.md 잔여 표에 묻혀 있던 것을 우선순위 보드 가시 항목으로 격상. 해결 방향은 2026-05-06 사용자 협의로 이미 확정, 패치 일정만 미정.
