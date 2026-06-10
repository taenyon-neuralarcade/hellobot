# REVIEW-4: 위험·실패 시나리오 비판 리뷰

**리뷰어 렌즈**: 위험·실패 시나리오 (동시성·트랜잭션·마이그레이션·롤백·새 결함 가능성)
**검토 대상**: requirements.md / user-stories.md / 1pager.md (2026-05-21 작성)
**작성일**: 2026-05-21
**전체 평가**: **위험도 H (High)** — 동기화 정책 자체는 옳은 방향이지만 트랜잭션 경계·동시성·롤백 전략이 요구사항 수준에서 거의 비어 있어, 핫픽스가 새 결함(특히 "옛 spec 동결 안 됨 + 새 spec 만 만들어진 좀비") 을 만들 가능성이 매우 높음.

## 요약

본 핫픽스의 핵심 동작 — "옛 spec 동결 + 새 spec 생성 + product.couponSpecSeq 교체" — 는 **3 개 row 의 원자적 상태 전이**를 요구하지만, 요구사항은 이를 "단일 트랜잭션으로 묶는다(FR-2.3)" 한 줄로만 다룬다. AdminJS `afterEdit` 훅은 본질적으로 상품 INSERT/UPDATE **이후**에 실행되므로 단일 트랜잭션 구성이 자명하지 않음에도, FR-2.3 은 "가능하면" 이라는 모호한 표현으로 미루고 있다. 동시성 (운영자 수정 ↔ kakao 결제 응답으로 인한 발급) · 마이그레이션 race · 롤백 비대칭성 (옛 spec 의 issueEndDate 를 되돌릴 수 있는가) 도 다루지 않는다. 5~10 개 이상의 위험 시나리오가 식별되며, 그 중 4~5 개는 핫픽스가 안 만들었던 **새 결함**.

## 발견한 문제

### F-1: afterEdit 의 "옛 spec 동결 + 새 spec 생성" 사이 race — 결제 응답 발급이 옛 spec 으로 진입

- **현상/위반 지점**: FR-1.1, FR-2.3 ("가능하면 단일 트랜잭션")
- **실패 시나리오**:
  1. T0: 활성 spec #1 (skillSeqs=[A]), product.couponSpecSeq=#1
  2. T1: 운영자가 fixedMenuSeq A→B 로 수정 저장 → AdminJS 가 상품 row 를 update commit
  3. T2: `afterEdit` 가 spec #1 에 issueEndDate=now() 적용 SQL 실행 직전, **카카오 결제 응답이 도착**해 `CoopMarketingService` 가 productCode 로 product 를 조회 → couponSpecSeq=#1 을 읽고 `Coupon.create({couponSpec: #1})` 발급
  4. T3: afterEdit 가 spec #1 동결, 새 spec #2 (skillSeqs=[B]) 생성, product.couponSpecSeq=#2 로 교체
  5. T2 에서 발급된 쿠폰은 **이미 동결된 spec #1 에 묶임** — 사용 자체는 가능하나, 운영자의 변경 의도(B 적용)와 어긋남
- **영향 범위**: 정산·CS — 운영자가 "B 로 바꿨다" 인지하는 동안 짧은 윈도우의 발급분이 A 적용으로 남음. 발급분 보호(FR-4.1) 와 운영자 의도가 충돌. 1차 출시 직후 결제 트래픽이 몰리는 시점에 발생 확률 비무시
- **권장 액션**: FR-1.1 acceptance criteria 에 "결제 발급 경로와 본 동기화 경로의 직렬화 메커니즘 (advisory lock 또는 product row 의 SELECT FOR UPDATE) 명시" 추가. 또는 productCode → couponSpecSeq 조회를 발급 트랜잭션 내부에서 다시 잠금 조회. /architect 단계에서 직렬화 전략 확정 필요

### F-2: 단일 트랜잭션 구성이 AdminJS 아키텍처 상 불가능 — 부분 실패 새 케이스

- **현상/위반 지점**: FR-2.3 "가능하면 단일 트랜잭션", US-07 acceptance "동일 트랜잭션으로 롤백되거나"
- **실패 시나리오**: AdminJS resource action 의 lifecycle 은 `before → DB 변경 → after`. **DB 변경(상품 update)은 after hook 진입 시점에 이미 commit** 된 상태. afterEdit 에서 추가로 트랜잭션을 열어 spec 작업을 하더라도, 실패 시 "상품 update 는 commit, spec 동기화는 rollback" 이라는 비대칭 상태가 그대로 남는다. **현재 코드와 동일한 결함** 을 요구사항이 인지하지 못함
  - 새 결함 시나리오: 핫픽스가 "옛 spec 동결 + 새 spec 생성 + product.couponSpecSeq 교체" 를 새 트랜잭션으로 묶었는데, 도중에 UNIQUE 충돌(`CouponSpec.name`) 로 rollback 되면 → product.fixedMenuSeq 는 이미 B 로 바뀐 채로 commit 된 상태 + spec 은 옛 #1 그대로 + couponSpecSeq=#1 → **신규 발급은 옛 spec #1 (skillSeqs=[A]) 로 이뤄지나 product 의 의도된 스킬은 B** 라는 정확히 ISS-071 P0-A 와 동일한 결함이 다른 메커니즘으로 재현
- **영향 범위**: 정합성 — 핫픽스가 자기 자신과 동일한 결함을 만들 수 있음
- **권장 액션**: FR-2.3 을 "가능하면" 이 아니라 **"필수"** 로 격상하되 구현 패턴 확정 필요:
  - 옵션 1: AdminJS hook 대신 service 메서드로 동기 호출을 옮기고, controller 에서 product+spec 을 단일 `getManager().transaction` 안에서 처리
  - 옵션 2: afterEdit 내에서 spec 동기화 실패 시 product row 의 fixedMenuSeq 를 **compensating update** 로 되돌리는 명시적 보상 로직 (이 자체도 실패 가능 — best-effort 임을 운영자에게 표시)
  - /architect 단계에서 둘 중 하나 명시. 요구사항 단계에서 "가능하면" 으로 유보 금지

### F-3: 새 spec 만 만들어지고 옛 spec 동결 실패하는 부분 실패

- **현상/위반 지점**: FR-1.1, FR-1.2 (단일 활성 spec 보장)
- **실패 시나리오**:
  1. afterEdit 에서 새 spec #2 생성 commit
  2. product.couponSpecSeq 를 #2 로 교체 commit
  3. 옛 spec #1 의 issueEndDate=now() update 시점에 DB connection drop / lock timeout / unrelated constraint
  4. 결과: spec #1, spec #2 모두 활성, 둘 다 skillSeqs=[A] (1단계 직후) 또는 [A]/[B] 매칭 — FR-1.2 단일 활성 spec 위반
- **영향 범위**: ISS-071 P0-B 와 동일 결함의 변종 — 핫픽스가 그것을 막으려는 동안 같은 결함을 만듦
- **권장 액션**: 동기화 순서를 "옛 spec 동결 → 새 spec 생성 → product.couponSpecSeq 교체" 로 명시 (현재 요구사항 문서는 순서 명시 없음). 동결을 먼저 commit 하지 않은 채로는 새 spec 을 만들지 않는다는 invariant 를 acceptance criteria 에 추가

### F-4: 운영 DB 정합화 SQL(D-4) 과 운영 중 발급 흐름의 race

- **현상/위반 지점**: FR-3.3, D-4 권장안 "일회성 SQL"
- **실패 시나리오**:
  1. 정합화 SQL 이 "skillSeqs=[A] 에 매칭되는 활성 spec 2 개 중 옛 것 동결" 시작
  2. 동시에 카카오 결제 응답이 도착해 발급 흐름이 옛 spec 으로 발급 중
  3. SQL 이 spec.issueEndDate=now() 를 적용하는 사이 발급 트랜잭션이 동일 spec 을 참조 → 발급 자체는 성공하나 issueQuantity 카운터·통계가 정합화 시점 이후로 늘어남
  4. 발급된 쿠폰이 동결된 spec 에 묶여 있어 "동결됐는데 발급이 추가됐다" 라는 운영 혼란
- **영향 범위**: 정산 통계·운영자 신뢰. C-3 (PR #2421 SSH 터널 패턴) 으로 운영 DB 직접 SQL 적용이 허용된 상태에서 매우 가능성 높음
- **권장 액션**: FR-3.3 에 "정합화 SQL 적용은 1차 출시 안정화 후 결제 트래픽이 낮은 시간대에 짧은 락 윈도우로" 라는 운영 제약 명시. 또는 정합화 자체를 어드민 액션으로 옮겨 동일 락 정책 공유 (D-4 결정 변경 제안)

### F-5: 핫픽스 롤백 곤란성 — DB 상태가 양립 불가

- **현상/위반 지점**: NFR-2 (배포 호환성), 전체 — 명시되지 않음
- **실패 시나리오**:
  1. 핫픽스 배포 후 일부 fixedMenuSeq 수정이 일어나 옛 spec 동결 + 새 spec 생성 + couponSpecSeq 교체가 누적
  2. 핫픽스에 critical 결함 발견 → 이전 코드로 롤백
  3. 이전 코드는 "in-place skillSeqs 갱신" 로직이므로 동결된 옛 spec 의 존재를 인식하지 못함
  4. 운영자가 다시 fixedMenuSeq B→C 로 바꾸면 **새 spec #2 의 skillSeqs 가 in-place 로 [C] 로 변경** → 이미 발급된 #2 의 쿠폰이 retroactively C 적용 (원 결함 P0-A 재발) + 동결된 #1 은 그대로
- **영향 범위**: 롤백 가능성이 사실상 비대칭 — 핫픽스 적용 데이터는 핫픽스 적용 후 상태에 의존, 롤백 시 일관성 위반
- **권장 액션**: NFR 에 "핫픽스 적용 데이터의 롤백 시나리오" 추가. /architect 단계에서 "옛 코드도 동결된 spec 의 존재를 검출하면 in-place 갱신 대신 새 spec 생성으로 동작" 하도록 양립 보장 또는 "롤백 시 핫픽스 적용 시점 이후 데이터의 manual 정정 필요" 명시. 1차 출시 직후 안정화 기간 동안의 롤백 가능성은 비무시

### F-6: FR-4.1 의 "retroactively 변경되지 않는다" 가 정책 선언만 — 실제 enforcement 없음

- **현상/위반 지점**: FR-4.1
- **실패 시나리오**: 요구사항이 "발급된 쿠폰의 적용 가능 대상이 운영자 측 CRUD 동작으로 인해 retroactively 변경되지 않는다" 라고 선언하나, 이는 어드민 정책일 뿐이고 실제 DB 수준의 강제력은 없음. AdminJS 의 CouponCondition resource 가 직접 노출되어 있으면(또는 superAdmin 이 DB 콘솔로 접근하면) skillSeqs 를 in-place 변경 가능. ISS-071 P2-I (어드민 직접 수정) 가 별건으로 처리되는 상황과 모순
- **영향 범위**: 핫픽스 후에도 운영자 실수로 동일 결함 재발 가능
- **권장 액션**: FR-4.1 에 "발급된 Coupon (couponSpec.issueQuantity > 0 또는 Coupon 행 존재) 이 있는 spec/condition 의 skillSeqs / 핵심 적용 조건은 변경 자체를 AdminJS validation 으로 reject" 추가. 또는 명시적으로 "본 핫픽스는 정책 선언이며 강제는 P2-I 별건에서 처리" 라고 명시해 운영 기대치 정렬

### F-7: CouponSpec.name UNIQUE 충돌 시점이 새 spec 생성과 옛 spec 동결 사이에 끼임

- **현상/위반 지점**: FR-1.5, D-3 (suffix 권장안)
- **실패 시나리오**:
  1. 운영자가 productName="별점 5점" 으로 변경 → suffix 정책상 새 spec name="별점 5점 이용권 #${productCode}"
  2. 옛 spec 동결은 성공, 새 spec INSERT 가 UNIQUE 충돌 (이미 같은 productCode 에 동일 이름의 freeze 된 spec 이 과거에 존재 — soft cleanup 표준이라 동결된 spec 이 영원히 누적)
  3. rollback 시 옛 spec 동결도 같이 rollback 되어야 정합성 유지인데 트랜잭션 경계가 명확하지 않음 (F-2 와 결합)
- **영향 범위**: suffix 정책이 collision-free 라는 D-3 권장안의 가정이 깨짐. soft cleanup (D-1) 와 결합되면 한 productCode 의 동일 name 변종이 시간순으로 누적되어 충돌이 결정론적으로 발생
- **권장 액션**: D-3 권장안 (productCode 만 suffix) 를 "${productCode}-${createdAt.timestamp}" 또는 spec.seq 후속 suffix 로 강화 (단, suffix 가 생성 전 결정 불가하므로 try/update 패턴 필요). /architect 단계에서 suffix 정책의 충돌-자유성을 증명해야 함

### F-8: CouponSpec 의 issueQuantity·usedCount 카운터의 동결 후 누적

- **현상/위반 지점**: 명시되지 않음 — 요구사항 누락
- **실패 시나리오**: 옛 spec 을 "issueEndDate=now() 동결" 만으로 처리 (D-1 soft 권장안). 동결 이후에도 발급된 쿠폰은 사용 가능 (FR-4.2). 쿠폰 사용 시점에 spec.usedCount 가 ++ 됨. 운영 통계 화면에서 동결된 spec 의 usedCount 가 지속 증가 → 운영자가 "이미 종료한 상품인데 왜 통계가 늘어나지?" 혼란. 또는 issueQuantityLimit 가 0(무제한)이 아니라 N이었다면 동결 후에도 발급 가능한 케이스가 남아있을 수 있음 — 동결의 의미가 불명확
- **영향 범위**: 운영 통계 신뢰성. 정산 보고서가 동결 spec 의 카운터를 어떻게 다룰지 미정의
- **권장 액션**: FR-1.1 acceptance criteria 에 "동결된 spec 은 신규 발급만 차단. 사용·통계 카운터는 발급분 만료까지 누적된다는 점을 운영 화면에 표기" 추가. 또는 "동결 spec 의 카운터 누적은 운영 통계 화면 separator 로 시각화" 라는 작업 추가

### F-9: AdminJS afterEdit 가 "변경 없는 update" 에도 호출되며 매번 새 spec 을 만들 위험

- **현상/위반 지점**: FR-1.1 의 발동 조건 명시 부재
- **실패 시나리오**: AdminJS UI 에서 운영자가 productName 만 수정 (fixedMenuSeq 는 그대로) 저장 → afterEdit 가 호출됨. 요구사항이 "fixedMenuSeq 가 변경될 때" 라고 했지만 코드 수준에서 변경 여부 비교 로직 (oldFixedMenuSeq vs newFixedMenuSeq) 가 필요. 비교 누락 시 매 수정마다 새 spec 생성 → 활성 spec 이 N 개씩 누적되며 단일 활성 spec 보장 (FR-1.2) 위반
  - 현재 코드 (line 197-201) 는 `JSON.stringify(currentSkillSeqs) !== JSON.stringify(newSkillSeqs)` 로 비교하나, 핫픽스 후 로직에서 이 비교를 옛 spec 의 condition 으로 할지, 새로 만들 spec 의 input 으로 할지 모호
- **영향 범위**: spec 누적으로 진단 SQL (FR-3.1 ①) 이 계속 위반 검출
- **권장 액션**: FR-1.1 에 "afterEdit 호출 시 product.fixedMenuSeq 의 변경 여부를 actual diff 로 판정 (request.payload 와 DB 의 직전 값 비교). diff 없으면 spec 작업 skip" 명시. AdminJS 의 request.payload 가 변경 전 값 접근 가능한지 /architect 가 확인

### F-10: response.record.params 의 시점 모호 — afterEdit 가 보는 값이 update 직전 vs 직후

- **현상/위반 지점**: 현재 코드 동작에 대한 요구사항 가정 누락
- **실패 시나리오**: AdminJS afterEdit 의 `response.record.params` 는 update **이후** 의 값을 반영 (현재 코드 line 158 가정). 이 가정이 깨지는 케이스가 있는지 — `errors` 가 일부 있는 부분 commit, 또는 AdminJS plugin 미들웨어가 params 를 변형하는 경우 — 요구사항 단계에서 의식되지 않음. 특히 핫픽스가 "params.fixedMenuSeq 의 직전 값" 을 알아내야 새 spec 생성 vs in-place 갱신을 판정 가능한데, AdminJS hook context 에서 직전 값 접근 자체가 보장되지 않음
- **영향 범위**: 핫픽스 구현 가능성 자체에 영향 — F-9 의 전제가 깨지면 핫픽스 동작 불가
- **권장 액션**: /architect 가 AdminJS context 의 "before/after value 접근" 을 코드 레벨로 검증 후 요구사항에 명시. 접근 불가하면 "afterEdit 진입 시점에 product row 를 DB 에서 다시 조회하여 직전 값을 별도 보관(beforeSave hook 에서 미리 캐싱)" 같은 우회 필요

### F-11: 테스트 환경 부재 — 운영 데이터 정합화 검증 불가능

- **현상/위반 지점**: NFR-1 (결정론적 동작), §7 검증 기준
- **실패 시나리오**: 핫픽스의 결정론적 동작을 검증하려면 운영 데이터의 다양한 위반 케이스가 재현된 테스트 환경 필요. 그러나 dev/staging DB 에 동일 위반 데이터가 있는지 알 수 없음 (진단 SQL FR-3.1 은 운영 DB 전용 가정). QA 시나리오 (T-10) 는 합성 데이터로 작성될 텐데, 합성 데이터로 검증한 핫픽스가 운영 데이터의 long tail 결함을 커버하리란 보장 없음
- **영향 범위**: §7 의 "QA 시나리오 검증" 합격 기준이 운영 정합성을 보장하지 못함
- **권장 액션**: NFR 에 "핫픽스 배포 전, 운영 DB 의 위반 데이터 카테고리 (FR-3.1 의 3 종) 별 sample row 를 dev DB 로 복제하여 회귀 테스트" 추가. 또는 "1차 출시 직후 운영 데이터로 진단 SQL 만 먼저 실행 → 위반 카테고리 분포 확인 → 핫픽스 구현 시 그 카테고리 우선 커버" 라는 단계적 접근 명시

### F-12: 점진 배포 시 중간 상태 — 진단만 적용한 단계의 정합성

- **현상/위반 지점**: §6 의존 관계, D-5 (풀 vs 최소)
- **실패 시나리오**: D-5 권장안이 "풀(P0+P1) 1회 배포" 인데, P0 만 먼저 배포되는 시나리오 (P1 코드 검토 늦어짐) 를 고려해보면:
  - P0 만 적용: fixedMenuSeq 변경은 처리되나 (P0-A) productType 전환·UNIQUE 충돌·필수값 검증 (P1-D~G) 는 여전히 결함
  - 운영자는 P0 적용 후 "이제 안전" 이라 인지하고 productType 전환을 시도 → 좀비 발생
- **영향 범위**: D-5 결정과 무관하게 부분 적용 시나리오의 안전성 보장 필요
- **권장 액션**: §6 또는 NFR 에 "P0 만 단독 배포 시 P1 결함 케이스가 운영자에게 visible 한 경고로 표시 (예: productType 전환 시도 시 UI 경고)" 추가. 또는 D-5 권장안에 "P0 만 단독 배포 옵션은 비권장 — P1 결함이 P0 처리 결과를 다시 깨뜨릴 수 있음" 라는 위험 명시

### F-13: FR-1.5 "atomic reject" 정책이 운영자의 정정 경로를 막을 가능성

- **현상/위반 지점**: FR-1.5, US-05, D-3
- **실패 시나리오**: 운영자가 의도적으로 잘못된 productName 을 정정하려는 경우 (예: 오타 수정). suffix 정책 (D-3 권장안) 이라면 통과되나, atomic reject 라면 다른 spec 의 name 과 충돌하는 모든 케이스에서 정정 자체가 불가. 또는 suffix 정책이라도 동일 productCode 의 두 번째 변경부터는 동일 suffix 가 충돌 → 정정 시도가 계속 실패하는 케이스 가능
- **영향 범위**: 운영자 UX — 정정 경로 차단
- **권장 액션**: FR-1.5 에 "정정 실패 시 운영자에게 충돌 spec 정보 (어떤 다른 spec 과 name 충돌인지) 를 명확히 표시. 운영자가 충돌 spec 을 먼저 정리할 수 있는 경로 제공" 추가

### F-14: 외부 시스템(kakao / coopmarketing 정산) 과의 정합성 누락

- **현상/위반 지점**: 명시되지 않음 — 본 핫픽스 영향 범위 매트릭스 (§2) 에서 외부 시스템 항목 자체 없음
- **실패 시나리오**: 카카오 측은 productCode 단위로 결제 완료 데이터를 송신. couponSpec 이 #1 에서 #2 로 바뀐 product 에 대해 카카오가 동일 productCode 로 결제 응답을 보내면, 본 서비스는 새 spec #2 로 발급. 그러나 결제·정산 데이터를 카카오 측이 reconcile 할 때, "이전에 발급되었던 #1 의 쿠폰" 과 "지금 발급된 #2 의 쿠폰" 이 동일 productCode 로 묶여 정산 차이가 발생할 가능성. 정산 보고서가 spec.seq 단위로 끊기면 한 productCode 의 매출이 두 spec 으로 split
- **영향 범위**: 정산 보고서. 부모 프로젝트 coop-integration 의 정산 흐름에 의존
- **권장 액션**: 영향 범위 매트릭스 (§2) 에 "외부 정산 reconciliation 영향 검토" 항목 추가. /architect 에서 coopmarketing 정산 데이터 모델 확인 후 spec.seq 가 정산 키인지 productCode 가 키인지 확정. 후자라면 영향 없음, 전자라면 핫픽스 적용 후 정산 분리가 발생

## 결정 요청

1. **D-A**: FR-2.3 의 "가능하면" 을 "필수" 로 격상하고 트랜잭션 패턴을 /architect 가 확정한 후에 구현 착수 — 동의 여부
2. **D-B**: 결제 발급 경로와 본 동기화의 직렬화 메커니즘 (advisory lock vs SELECT FOR UPDATE vs 운영 시간 제한) 중 선택 — /architect 가 옵션 비교 후 사용자 결정
3. **D-C**: 정합화 SQL (D-4) 적용 시점 운영 제약 — "1차 출시 안정화 후 결제 트래픽 낮은 시간대" 명문화 동의 여부
4. **D-D**: 핫픽스 롤백 시나리오 — 양립 보장 코드 추가 vs "롤백 시 manual 정정" 명시 중 선택
5. **D-E**: FR-4.1 의 강제 메커니즘 — 발급분 존재 시 spec/condition 의 핵심 필드 변경을 AdminJS 단계에서 reject 하는 validation 추가 여부 (P2-I 별건과의 경계)
6. **D-F**: P0 만 단독 배포 옵션의 안전성 — D-5 권장안 "풀 배포" 를 단순 권장이 아닌 **요구사항** 으로 격상 동의 여부

## 인정할 만한 부분

- 결함 매트릭스 (ISS-071 의 A~I 9 건) 와 user-stories 의 매핑이 명확하고 1:1 추적 가능
- FR-4.1 / FR-4.2 (발급분 보호) 라는 invariant 를 별도 카테고리로 추출한 것은 옳음 — 모든 FR-1 의 acceptance 가 이걸 만족해야 한다는 구조가 명시적
- 진단 SQL (FR-3.1) 을 코드 수정과 분리해 즉시 실행 가능한 항목으로 분류한 점은 1차 출시 직전 운영 안전망으로 적절
- D-1 ~ D-5 결정 보류를 /architect 진입 전에 합의해야 한다고 못 박은 점 (§8 운영 메모)
