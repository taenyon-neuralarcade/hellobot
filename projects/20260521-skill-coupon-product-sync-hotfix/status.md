# 개발 상태

## 현재 상태: requirements v2 작성 완료 — D-1~D-9 협의 + 진단 SQL 실행 게이트

2026-05-21:
- (오전) 코드 심층 분석 완료. ISS-071 결함 매트릭스 9 건 도출 (P0 2 + P1 6 + P2 1)
- (오후) /analyze 산출 v1 — 1pager · user-stories · requirements 작성. 사용자 결정 보류 5 건(D-1~D-5) 노출
- (저녁) **비판적 리뷰 5 종 병렬 실행** — 전원 위험도 H 판정, 69 건 결함 + 27+ 신규 결정요청 발굴. 교차 결함 8 건(C-1~C-8) 식별. 통합 요약: [reviews/SUMMARY.md](./reviews/SUMMARY.md)
- (밤) **메타-리뷰 + requirements v2 작성** — 96 건 결함 비판적 분류 결과 33 건 본문화 / 15 건 /architect 위임 / 24 건 별건 분리 / 24 건 기각. 메타-비판 근거: [reviews/META-REVIEW.md](./reviews/META-REVIEW.md). requirements.md v2 §1~§11 (FR 14, NFR 7, C 6, D 9) 완성.

다음 (/architect 진입 게이트 — 9개 결정 압축):
1. 진단 SQL(T-1~T-4) + 정량 임팩트 추정(FR-5.3) 실행 — D-8 마감 결정
2. D-9 (CouponSpec.name 노출 경로) 1줄 grep — D-3 재결정 입력
3. D-7 (이해관계자 사인오프 채널) 합의 — CS·운영·재무·데이터 팀
4. D-1, D-2, D-3 (D-9 후 재기술), D-4, D-5 (2단계 옵션 (c)), D-6 (스냅샷 정책) 사용자 합의
5. §10 신규 산출물 (운영 SOP·CS 조회 쿼리·정량 추정) 책임자 확정
6. 위 1~5 완료 후 /architect 진입

## 파트별 현황

| 파트 | 상태 | 브랜치 | 워크트리 | 비고 |
|------|------|--------|---------|------|
| 기획 | **requirements v2 완료** | - | - | 1pager / user-stories(9) / requirements v2 (FR 14·NFR 7·C 6·D 9, 결함 매핑 검증·신규 산출물·Non-Goals 포함) / 리뷰 5 + 메타-리뷰 |
| 서버 | 분석완료 · 설계 대기 | - | - | D-1~D-5 합의 후 /architect → 워크트리 생성 → 구현 |
| iOS | 해당없음 | - | - | |
| Android | 해당없음 | - | - | |
| 웹 | 해당없음 | - | - | |
| 스튜디오 | 해당없음 | - | - | |
| 데이터 | 해당없음 | - | - | |
| QA | 대기 | - | - | 핫픽스 구현 단계에서 시나리오 검증 (재등록·삭제·skill 변경) |

## 블로커

- **D-1~D-9 결정 대기** (사용자 협의 — v2 에서 27+ → 9 개로 압축):
  - D-1 (delete cleanup) · D-2 (productType 전환) · D-3 (name UNIQUE — D-9 후 재결정) · D-4 (정합화) · D-5 (스코프 — 2단계 (c) 권장 변경) · D-6 (발급 스냅샷) · D-7 (사인오프 채널) · D-8 (진단 마감) · D-9 (name 노출 경로)
  - 상세: requirements.md §8 + reviews/META-REVIEW.md §5
- 핫픽스 착수 일정 미정 — D-8 결정 + 진단 SQL 결과로 D-4/D-5 확정 후 산출

## 잔여 과업

- [ ] 운영 진단 SQL 작성 — 이미 발생한 정합성 깨진 데이터 식별 (동일 skillSeqs 활성 spec 2 개 이상 / couponSpecSeq=null skill 상품 / orphan CouponSpec)
- [ ] 동기화 정책 설계 — fixedMenuSeq 변경 시 옛 spec issueEndDate 처리 + 새 spec 생성, productName UNIQUE 회피(suffix), delete cleanup, productType 전환 처리
- [ ] AdminJS 훅 재구현 (`src/admin/options/CoopMarketingProduct.options.ts`)
- [ ] 부분 실패 가시화 — 트랜잭션 통합 또는 validation error 승격
- [ ] 일회성 정합화 (점검 결과로 잡힌 케이스가 있을 때)

## 결정 로그

- 2026-05-21 — 본 핫픽스를 부모 coop-integration 프로젝트의 자식으로 분리(별도 디렉토리). 일정·우선순위 협의 필요해서 TODO-013 umbrella 와는 별 트랙으로 가시화.
- 2026-05-21 — /analyze 진행. 요구사항 정리 완료 (1pager · user-stories · requirements). 사용자 결정 보류 5 건(D-1~D-5) 을 requirements.md §8 에 명시 — /architect 단계 전 합의 필요.
- 2026-05-21 (저녁) — 비판적 리뷰 5 종 병렬 실행 (운영 현실성 / 엔드유저·CS / 명확성 / 위험·실패 / 스코프·비즈니스). 전원 위험도 H, 총 69 건 결함 + 27+ 신규 결정요청. 교차 결함 8 건(C-1~C-8) 식별 — D-3 suffix 정책 5/5 지적, FR-2.3 트랜잭션 단일화 모호, 운영 SOP/CS 도구/이해관계자 통째 누락, 결함 E·H·I 매핑 약화, retroactive 보호가 적용 대상에만 한정, 동시성 침묵, 정량화 부재, 롤백 정책 부재.
- 2026-05-21 (밤) — **메타-리뷰 + requirements v2**. 96 건 결함을 비판적 분류: 33 본문화 (34%) / 15 /architect 위임 / 24 별건 분리 / 24 기각. 본문화 항목: FR-1.4 → 1.4-a/b 분리, FR-1.5 D-3 선결 조건, FR-2.3 P0 격상 + FR-2.4 신설, FR-4.3 신설 (스냅샷 정책), FR-5 신설 (산출물), §3.5 매핑 검증 표, NFR-6/7 신설, NFR-1 단언 완화, NFR-5 측정 기준, C-6 사인오프, §6 P0/P1 재평가 단서, §7 측정 도구·주기·책임자 + CS 문의 보조 지표 강등, §10 신규 산출물, §11 Non-Goals. **27+ 결정요청을 9개(D-1~D-9)로 압축** — D-5 권장 변경(풀 → 2단계 옵션 (c)). /architect 진입 게이트 = D-1~D-9 합의 + 진단 SQL 실행 결과.

## 주요 문서

| 문서 | 설명 |
|------|------|
| [readme.md](./readme.md) | 배경·목표·범위 |
| [1pager.md](./1pager.md) | Problem / Customer Job / Solution / Success Metric / Non-Goals |
| [user-stories.md](./user-stories.md) | 9 개 스토리 (P0 2 / P1 5 / 진단 2) + Acceptance Criteria |
| [requirements.md](./requirements.md) | FR·NFR·제약·의존 관계·검증 기준·D-1~D-5 |
| [reviews/SUMMARY.md](./reviews/SUMMARY.md) | 비판적 리뷰 5 종 통합 — 69 건 결함, 교차 결함 C-1~C-8 |
| [reviews/META-REVIEW.md](./reviews/META-REVIEW.md) | **메타-비판 + requirements v2 분류 근거** — 33 본문화 / 15 위임 / 24 분리 / 24 기각 |
| [reviews/REVIEW-1~5](./reviews/) | 5 명 비판적 리뷰 개별 문서 |
| [tasks.md](./tasks.md) | 파트별 과업 |
| [ISS-071](../20260324-coop-integration/issues.md#iss-071-스킬-교환권-상품-crud-↔-couponspeccouponcondition-정합성-깨짐) | 이슈 본문 (부모 프로젝트 issues.md) |
| [TODO-026](../../todos/TODO-026-skill-coupon-product-sync-hotfix.md) | 워크스페이스 TODO 상세 |
