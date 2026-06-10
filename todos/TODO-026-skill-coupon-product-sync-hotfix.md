# TODO-026 스킬 교환권 상품 CRUD ↔ 쿠폰 정합성 핫픽스

**유형**: 액션 (일정 결정 필요)
**상태**: ⚠ **재정렬 필요 (2026-05-21 사용자 피드백: 너무 복잡해지는 것 같음)** — 5/22 (금) 까지 **가벼운 처리 방향** 결정 완료 필수
**등록**: 2026-05-21
**시작**: 2026-05-21
**완료**: -
**마감**: **5/22 (금) — 처리 방향 결정 완료 (가벼운 방식)**
**담당**: 코디네이터 → /dev-server 위임 (착수 시)
**관련**: [projects/20260521-skill-coupon-product-sync-hotfix](../projects/20260521-skill-coupon-product-sync-hotfix/) · [부모 TODO-013](TODO-013-kakao-hotfix-residual.md) · [부모 프로젝트 coop-integration](../projects/20260324-coop-integration/) · [ISS-071](../projects/20260324-coop-integration/issues.md#iss-071-스킬-교환권-상품-crud-↔-couponspeccouponcondition-정합성-깨짐)

## 컨텍스트

사용자 발화 (2026-05-21): "스킬 교환권 상품 등록/수정을 하다보니 어떤 동작을 해도 잘 등록되어 있을 것이다 라는 신뢰가 가는 상태가 아닌 것 같아. 동일 스킬 쿠폰 재등록 시 기존 쿠폰스펙 잔존 → 재등록 동작에 충돌·중복·검증 실패 가능?"

/dev-server 가 `src/admin/options/CoopMarketingProduct.options.ts` + `src/services/coupon.ts` 코드 심층 분석 결과, **결함 매트릭스 9 건** (P0 2 / P1 6 / P2 1) 확인. ISS-071 로 정식 등록. 사용자가 별도 핫픽스 프로젝트(`projects/20260521-skill-coupon-product-sync-hotfix/`) 생성 요청.

핵심 결함:
- **P0-A**: fixedMenuSeq A→B 수정 시 `CouponCondition.skillSeqs` 가 in-place 갱신되어 **이미 발급된 쿠폰의 적용 대상까지 retroactively 변경**
- **P0-B**: 동일 스킬에 새 상품 재등록 시 옛 CouponSpec cleanup 없음 → 동일 skillSeqs 매칭 활성 spec 2 개 누적 → 유저가 두 쿠폰 보유·사용 가능. 동일 productName 이면 `CouponSpec.name` UNIQUE 충돌
- P1: delete cleanup 부재 (orphan), heart↔skill 전환 처리 부재, productName UNIQUE 충돌 catch silent, fixedMenuSeq 누락 silent skip, 부분 실패 가시화 부재

## 현재 상태

⚠ **재정렬 필요 (사용자 피드백 2026-05-21)**: "TODO-026 너무 복잡해지는 것 같음. 5/22까지 어떻게 할지 결정 완료 (최대한 가벼운 방식으로)". 9건 결함 → 1pager·user-stories(9)·requirements v2 (FR 14 / NFR 7 / C 6 / D 9) + 비판적 리뷰 5종 + 메타-리뷰까지 진행되며 스코프가 풀-스펙 핫픽스 프로젝트로 확장됨. **재범위 축소 결정 필요** — 가벼운 처리 방향으로 게이트 단순화.

- 분석 산출물: 1pager.md / user-stories.md / requirements.md (v2) / reviews/ — 보존 (참고 자료)
- 코드 미수정. 워크트리 미생성

## 다음 단계 — 🔥 5/22 (금) 까지 처리 방향 결정 (가벼운 방식)

**기본 방침**: 풀-스펙 D-1~D-9 합의 → /architect 게이트는 **보류**. 1차 출시(5/22) 직후 운영 영향 + 발생 가능성 + 가벼운 조치 비용으로 **결함 9건의 처리 방향만 결정**.

### 결함 9건 처리 방향 결정 (선택지)

각 결함마다 다음 중 하나로 결정:

| 옵션 | 설명 | 적합 |
|---|---|---|
| **(a) 즉시 최소 패치** | P0 retroactive 변경 차단·중복 발급 차단 등 최소 가드만 (D-합의 우회) | P0-A, P0-B — 운영 사고 직접 영향 |
| **(b) 운영 SOP·CS 가드레일** | 코드 수정 없이 운영자가 인지·회피하도록 SOP 문서화 + CS 조회 쿼리 | productName UNIQUE 충돌·delete cleanup 부재 등 운영 우회 가능 항목 |
| **(c) 다음 release 묶음 보류** | 1차 출시 안정화 + 더 큰 release 단위로 묶어서 처리 | 운영 영향 작은 P1·P2 항목 |
| **(d) 진단만, 결정 보류** | 진단 SQL T-1~T-4 만 5/22~5/25 실행, 결과 보고 정량 임팩트 확정 후 재결정 | 사용 빈도 미파악으로 우선순위 판단 어려운 항목 |

### 5/22 (금) 결정 산출물

- [ ] **결함 9건 매핑표** — 각 결함 → (a/b/c/d) 선택 + 1줄 사유 + 담당 + 데드라인
- [ ] **즉시 패치 (a)** 항목만 추려서 별도 hotfix 티켓화 → /dev-server 위임 일정만 잡기 (TODO-022 패턴)
- [ ] **운영 SOP (b)** 항목 책임자 결정 → 다음 주 운영팀 공유
- [ ] **묶음 보류 (c)** 항목 → 다음 release 백로그로 이관 (coop-integration tasks.md)
- [ ] **진단 (d)** 항목 → 진단 SQL 실행 일정만 잡기 (5/25 이전)

### 후속 (5/22 이후)

- [ ] 즉시 패치 (a) 항목 /dev-server 위임 → 워크트리 → 구현 → QA → 배포
- [ ] D-1~D-9 풀-스펙 합의는 진단 결과·운영 영향 확인 후 필요성 재판단 (default = 진행 안 함)

## 진행 로그

- 2026-05-21 — 사용자 보고로 /dev-server 코드 심층 분석 (`CoopMarketingProduct.options.ts`, `coupon.ts`). 결함 매트릭스 9 건 도출. ISS-071 등록. 핫픽스 프로젝트 `20260521-skill-coupon-product-sync-hotfix` 생성. TODO-013 umbrella 의 신규 검토 항목을 본 TODO 로 분리·승격
- 2026-05-21 (저녁) — /analyze 진행. 1pager / user-stories(9) / requirements 작성 완료. 사용자 결정 보류 5 건(D-1~D-5) 노출, 1차 권장안 포함. tasks.md 를 FR ID 매핑 + 기획 파트 추가로 재구성
- 2026-05-21 (밤) — 비판적 리뷰 5 종 병렬 실행 (운영 현실성·엔드유저·CS·명확성·위험실패·스코프비즈니스). 전원 위험도 H, 총 69 건 결함 + 27+ 신규 결정요청. 교차 결함 8 건(C-1~C-8) 식별. D-3 suffix 5/5 지적, D-5 스코프 2단계 권장 변경. 통합 요약 [reviews/SUMMARY.md](../projects/20260521-skill-coupon-product-sync-hotfix/reviews/SUMMARY.md).
- 2026-05-21 (심야) — **메타-리뷰 + requirements v2**. 96 건 결함 비판적 분류: 33 본문화 (34%) / 15 /architect 위임 / 24 별건 분리 / 24 기각. 메타-비판 근거 [reviews/META-REVIEW.md](../projects/20260521-skill-coupon-product-sync-hotfix/reviews/META-REVIEW.md). requirements v2 (FR 14 / NFR 7 / C 6 / D 9) — **27+ 결정요청을 9개(D-1~D-9)로 압축**. /architect 진입 게이트 = D-1~D-9 합의 + 진단 SQL 실행 결과.
- **2026-05-21 (사용자 피드백)** — "너무 복잡해지는 것 같음. 5/22까지 어떻게 할지 결정 완료 (최대한 가벼운 방식으로)". **재정렬**: 풀-스펙 D-1~D-9 합의 게이트 보류. 결함 9건 각각 (a) 즉시 최소 패치 / (b) 운영 SOP / (c) 다음 release 묶음 / (d) 진단만 으로 라벨링하여 5/22 까지 처리 방향만 픽스. 풀-스펙 진행은 진단·운영 영향 본 후 재판단
