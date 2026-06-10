# TODO-029 카카오 선물하기 운영 가이드 문서 작성

**유형**: 액션
**상태**: 🟢 **진행 중** (2026-06-02 문서 구조 확정 단계 착수 — 사용자 요청) · 초안 완료 목표 6/15
**등록**: 2026-05-22
**시작**: 2026-06-02
**완료**: -
**마감**: **2026-06-15 (월)**
**담당**: 사용자 (코디네이터 보조 — 문서 구조·드래프트 지원)
**관련**:
- [TODO-004](TODO-004-kakao-gift-launch.md) — 카카오 1차 출시 (5/22 D-Day)
- [TODO-013](TODO-013-kakao-hotfix-residual.md) — 카카오 핫픽스 잔여 (umbrella)
- [TODO-016](TODO-016-kakao-gift-slack-notification.md) — 카카오 슬랙 알림 (운영 모니터링 도구)
- [TODO-022](TODO-022-coop-admin-cancel-hotfix.md) — 운영 어드민 사용취소 (운영 시나리오 입력)
- [TODO-026](TODO-026-skill-coupon-product-sync-hotfix.md) — 스킬 교환권 상품 ↔ 쿠폰 정합성 (운영 SOP 입력)
- [TODO-027](TODO-027-kakao-skill-coupon-2nd-launch-spec.md) — 2차 출시 스펙
- [projects/20260324-coop-integration/](../projects/20260324-coop-integration/) — coop-integration 프로젝트

## 컨텍스트

카카오 선물하기 1차 출시(5/22) + 핫픽스(TODO-022 운영 배포 5/21 완료) + 후속 운영 작업(TODO-013 잔여 / TODO-026 P0 / TODO-027 2차 출시) 까지 **다수의 운영 시나리오와 결함 대응 패턴이 누적**된 상태. 더 이상 코드·SQL·결함 레지스트리만으로는 운영 인계가 어려운 시점.

사용자 요청 (2026-05-22): **카카오 선물하기 운영 가이드 문서 작성, 5/29 마감**.

### 확정 사항 (2026-05-22 사용자 답변)

- **독자**: 내부 운영팀 인계용
- **범위**: **전체 라이프사이클** (출시 → 일상 운영 → 핫픽스/결함 대응 → 2차 출시·확장)
- **형식**: 워크스페이스 Markdown
- **마감 정의**: **초안 완료** (작성자 셀프 종료, 리뷰는 5/29 이후도 가능)
- **언어**: 한국어 only (내부 운영팀 인계용 → 일본어 동시 불필요로 가정. 추후 일본 운영 인계 시점에 별도 작업)

### 보관 위치 결정

내부 운영팀 인계 + 전체 라이프사이클 = **상시 운영 문서** 성격 → 프로젝트 종속이 아니라 서비스 자체에 종속.

→ **`docs/kakao-gift-operations-guide.md`** 후보 1순위.
→ 대안: `docs/operations/kakao-gift.md` (operations 하위 디렉토리 신설, 향후 다른 외부 채널 운영 가이드도 같은 자리에 누적할 여지)

작성 시작 시 두 옵션 중 사용자에게 한 번 더 확인.

### 1차 입력 후보 (이미 워크스페이스에 있음)

- `projects/20260324-coop-integration/` — 전체 프로젝트 문서 (architecture, api-spec, status, issues)
- `projects/20260521-skill-coupon-product-sync-hotfix/` — 핫픽스 분석 결과
- `todos/TODO-004-kakao-gift-launch.md` — 1차 출시 진행 기록
- `todos/TODO-022-coop-admin-cancel-hotfix.md` — 어드민 사용취소 결함 + 운영 정합화 SQL
- `todos/TODO-026-skill-coupon-product-sync-hotfix.md` — fixedMenuSeq 변경 retroactive + UNIQUE 등 9건
- `hellobot-server/docs/features/` (관련 폴더들) — 서버측 구현 가이드
- ISS-055 / ISS-056 / ISS-071 등 issues.md 누적 항목

## 현재 상태

- 2026-05-22 스코프 확정 (독자=내부 운영팀, 범위=전체 라이프사이클, 형식=Markdown, 마감=초안 완료).
- **2026-06-02 사용자 요청으로 보류 해제 → 문서 구조 확정 단계 착수.** 사용자가 운영자 대상 상품 운영 가이드를 명시적으로 요청 + 3종 문서 초안 목록 제시 (① 상품 등록 ② 결제 취소 ③ 상품 운영) + 추가 문서 제안 요청.
- **방향 전환**: 기존 "단일 파일 6섹션" 안 → **운영자 대상 문서 SET(디렉토리)** 으로 전환. 보관 위치 `docs/operations/kakao-gift/` 잠정 결정 (다문서 SET 에 적합 + 향후 타 외부 채널 운영 가이드 누적 여지). **작성 착수 전 사용자 1회 확인.**
- 코디네이터가 입력 자료 1차 그라운딩 완료 (coop-integration architecture/issues, skill-coupon sync hotfix, TODO-022/026/013/027 → 핵심 엔티티·정산·취소·정합성·이슈 레지스트리 팩트시트 확보).
- **다음 액션**: 아래 문서 SET 구조 사용자 합의 → 합의 후 문서별 드래프트. 단, 본격 초안은 2차 출시(6/8·6/15) 입력 반영 위해 일부 섹션은 6/15 까지 누적.

## 문서 SET 구조 (2026-06-02 사용자 합의 완료)

> 위치: **`docs/operations/kakao-gift/` 확정** (사용자 OK). 문서 0·4 채택, 문서 5 별도 문서로 확정. ⚠ 일부 운영 기능 미구현(정산 통계 페이지·Slack 알림·CS 조회 쿼리) — 가이드는 "구현됨 / 미구현(수동 대안)" 을 함께 명시.
> 진행: **문서 0·1·2 초안 작성 완료 (2026-06-02)** — `README.md` / `01-product-registration.md` / `02-payment-cancellation.md`.

- **0. README (개요·인덱스)** — 서비스 구조(카카오→쿠프마케팅→서버→하트/스킬), 외부 파트너(쿠프마케팅 이정우·정산 조건), 상품 2종 비교표, 운영 도구(AdminJS), 용어집(compCode/authKey/CouponSpec/CouponCondition/fixedMenuSeq/prefix 90·91/L0~L3/사용취소·망취소·회수·정합화), 문서 인덱스, 이슈 레지스트리 매핑
- **1. 상품 등록·수정 가이드** (사용자 #1) — AdminJS CoopMarketingProduct CRUD. 하트(product_type=heart, heart_quantity) vs 스킬(product_type=skill, fixedMenuSeq → CouponSpec/CouponCondition 자동 생성·100% 할인). 수정 시 ⚠ 주의(ISS-071): fixedMenuSeq retroactive(결함 A)·productName UNIQUE 충돌(F)·type 전환(D/E)·중복 spec(B)·부분 실패 좀비(G/H). 비활성·삭제(orphan spec C, soft delete). 등록 후 검증 체크리스트. 2차 출시 대량 등록(TODO-027)
- **2. 결제·쿠폰 취소 가이드** (사용자 #2) — 취소 3종 구분(사용취소 L2·망취소 L3·회수). 운영자 사용취소 절차(CoopMarketingCouponUsage). L2 0000/8005 멱등 처리, canceled_at·recovered_at. 상품 회수(하트 차감/스킬 삭제, recovered_at 가드). ⚠ 연타 금지(ISS-056). 정합화 SQL(진단+보정). 재사용 UNIQUE 제약·L3 실패 대응
- **3. 상품 운영 가이드** (사용자 #3) — 정산(월단위 익월10일·8% 수수료·사용분 기준, ⚠정산통계 미구현→수동 집계). 상품별 특이사항(하트=즉시충전·결제이벤트 미발생 / 스킬=100%할인 경유·pay_for_contents spent_cash_amount 인젝션). 일상 운영·일별 통계. 모니터링(coop_marketing_api_log L0~L3·winston·Slack 미정). 정기 정합성 점검
- **4. CS·트러블슈팅 가이드** (채택) — CS 처리 절차·쿠폰 상태 조회 쿼리·L3 망취소 실패 수동 대응(ISS-052)·에스컬레이션. ※ **에러 메시지별 조치 사전은 문서 6 FAQ로 이관** — 중복 회피 위해 doc 4 는 CS 워크플로우 중심으로 축소(또는 6에 병합) 재검토.
- **5. 정합성 점검·인시던트 런북** (별도 문서 확정) — 진단 SQL 3종, Do/Don't 체크리스트, 과거 인시던트 사례(ISS-056).
- **6. 운영 FAQ** (사용자 추가 요청 2026-06-03) — **앱 에러 메시지별 운영자 조치**(CO012·CM001~CM010, 검증 i18n 문구 기준) 1순위 + 분류(사용자안내/일시오류/운영점검/시스템결함) + 에스컬레이션 + 기타 운영 Q&A. ✅ 초안 작성 완료.

## 다음 단계

- [x] 사용자 확인 답변 받기 (독자·범위·형식·마감 정의) — 2026-05-22 완료
- [x] 입력 자료 1차 그라운딩 (팩트시트) — 2026-06-02 완료
- [x] 문서 SET 구조 초안 작성 — 2026-06-02 완료 (위 섹션)
- [x] **문서 SET 구조 + 보관 위치 사용자 합의** — 2026-06-02 완료 (위치 OK · 0·4 채택 · 5 별도)
- [x] 문서 0(README) + 1(등록) + 2(취소) 우선 드래프트 — 2026-06-02 완료
- [x] 문서 6(운영 FAQ) 초안 — 2026-06-03 완료 (앱 에러 메시지별 조치)
- [ ] **doc 4(CS) ↔ doc 6(FAQ) 중복 정리** — 에러 사전은 FAQ 보유. doc 4 를 CS 워크플로우로 축소 vs FAQ에 병합, 사용자 확인
- [ ] 문서 3(운영)·4(CS)·5(런북) 드래프트 — 정산 1회 사이클·CS 문의 패턴 누적 반영
- [ ] 식별자 확인 항목 해소 — AdminJS 버튼 라벨, `coupon_condition` 컬럼명(`fk_coupon_spec`/`skill_seqs`/`issue_end_date`), 하트 부분 회수 정책, CS 단건 조회 쿼리(문서 6 §2 → 4)
- [ ] 2차 출시(6/8·6/15) 등록 절차 반영 → 문서 1 보강
- [ ] **초안 완료** (6/15 월 마감)
- [ ] (후속) 운영팀 인계 리뷰 — 6/15 이후 별도 일정

## 진행 로그

- 2026-05-22 — TODO 등록 (사용자 요청). 마감 5/29. 카카오 선물하기 운영 가이드 문서 작성. 카카오 = ⭐⭐⭐ 최상 항목군. 미확정 5건은 사용자 답변 대기.
- 2026-05-22 — 사용자 답변 수령: 독자=내부 운영팀 인계용 / 범위=전체 라이프사이클(출시→운영→핫픽스→2차) / 형식=워크스페이스 Markdown / 마감 정의=초안 완료(작성자 셀프 종료). 언어는 미질의 → 한국어 only 가정(내부 운영팀 인계용). 보관 위치는 `docs/` 직하 vs `docs/operations/` 두 옵션을 작성 시작 시 사용자에게 한 번 더 확인하기로.
- 2026-06-02 — **보류 (6/15 까지)**. 1차 출시(5/26 완료) 안정화 + 2차 출시([[TODO-027]] 6/8·6/15) 진행 중이라 운영 가이드 초안은 출시 안정화 후 착수. 마감 5/29 → 6/15 로 갱신.
- 2026-06-03 — **문서 6(운영 FAQ) 초안 작성 완료** (사용자 추가 요청). 1순위 = **앱 에러 메시지별 운영자 조치**(CO012·CM001~CM010, api-spec 검증 i18n 문구 기준): 빠른 조회표 + 코드별 상세(의미·조치·확인 위치) + 분류(🟦사용자안내/🟨일시오류/🟥운영점검·시스템결함) + 에스컬레이션 경로 + 기타 FAQ. `06-operations-faq.md`. README 인덱스 갱신. **doc 4(CS) 와 에러 사전 중복** → FAQ가 에러 사전 보유, doc 4 는 CS 워크플로우 중심으로 축소 또는 병합 — 사용자 확인 예정.
- 2026-06-02 — **문서 0·1·2 초안 작성 완료.** 사용자 합의(위치 `docs/operations/kakao-gift/` OK · 문서 0·4 채택 · 5 별도) 후 README + 01-product-registration + 02-payment-cancellation 작성. 식별자는 coop-integration architecture/api-spec + 서버 엔티티(`CoopMarketingProduct`/`CoopMarketingCouponUsage`/`CoopMarketingApiLog`/`CouponPrefixRule`)로 검증 — 실제 테이블명 `coop_marketing_*`(설계문서 `coupc_*`는 오기). 남은 확인: AdminJS 버튼 라벨, `coupon_condition` 컬럼명, 부분 회수 정책. 다음: 문서 3·4·5 드래프트(정산 사이클·CS 패턴 누적 후).
- 2026-06-02 — **보류 해제 (같은 날, 사용자 요청 "할일 추가하고 바로 진행").** 사용자가 운영자 대상 상품 운영 가이드 3종(① 상품 등록 ② 결제 취소 ③ 상품 운영) 제시 + 추가 문서 제안 요청. 코디네이터 처리: ① 본 TODO-029 가 동일 주제 → **중복 신규 TODO 미생성**, 본 TODO 활성화(보류→진행 중, 시작일 6/2). ② 입력 자료 그라운딩(팩트시트) 완료 — CoopMarketingProduct/CouponSpec/CouponCondition/coupc_marketing_coupon_usage 엔티티, 정산(월·익월10일·8%), 취소 L2/L3/회수·recovered_at, ISS-071 9결함, ISS-055/056 매핑. ③ 단일 파일 → **운영자 문서 SET(`docs/operations/kakao-gift/`) 6종** 구조 제안(README + 사용자 3종 + CS·트러블슈팅 + 정합성 런북). 사용자 합의 대기. 초안 완료 목표 6/15 유지. 본격 드래프트는 합의 후 + 2차 출시 입력 누적 반영.
