# TODO-031 AWS 1~4번 계정 neuralarcade.ai 이전

**유형**: 액션
**상태**: ✅ 완료 (2026-05-28) — 1~4번 root 이메일 전환(5/25) + 부가 정보(Tax/Contact)·리소스(Route53/SES 등) 갱신 완료
**등록**: 2026-05-22
**시작**: 2026-05-24
**완료**: 2026-05-28
**마감**: 2026-05-29 (금) — 5/28 조기 완료 (30일 메일함 모니터링은 장기 추적, 완료와 별개)
**작업 예정**: 완료
**중요도**: ⭐⭐⭐ 최상 (사용자 지정 2026-05-22)
**담당**: 사용자 직접 (전 단계 단독 수행)
**관련**: [[TODO-030-aws-account-5-6-handover-dlt]] (선행), [[reference_gcp_billing_permission]]

---

## 작업 절차 및 순서 (요약)

### 전체 흐름

```
[Phase 0 — 5/26 작업 전 사전 점검]
1. 1~4번 root 비밀번호·MFA 보유 확인
2. 1~4번 신 이메일 주소 4개 준비 (@neuralarcade.ai)
   - 계정별로 고유한 이메일 (예: aws-master@neuralarcade.ai, aws-common@..., 또는 alias)
3. 신 도메인 메일함 작동 확인 (verification 메일 수신 가능)
4. neuralarcade.ai 법인 세금정보·주소·연락처 준비
5. 1번에 있는 공통 리소스 중 5·6번에서 참조하던 것 식별 (TODO-030 정리 대상)
6. 1번 IAM users 목록 확인 — taenyon 외 다른 사용자 있는지

[Phase 1 — 5/26 이메일 이전 실행 (TODO-030 완료 후)]
7. 2번 root 이메일 변경 (dlt-partners.com → neuralarcade.ai) + 검증
8. 3번 동일
9. 4번 동일
10. 1번 마지막 (다른 계정 검증 작업의 IAM user 기반이므로 마지막에 변경)

[Phase 2 — 5/26~5/27 부가 정보 갱신 (계정별)]
11. Alternate contacts (Billing/Operations/Security) → neuralarcade.ai 측 정보
12. Tax settings → neuralarcade.ai 법인 사업자등록번호
13. (선택) Account name → neuralarcade.ai 측 명칭
14. Account → Contact information (회사명·주소·전화) 갱신

[Phase 3 — 5/27~5/28 부가 리소스 정리]
15. Route 53 도메인 등록 연락처 갱신 (dlt-partners.com → neuralarcade.ai)
16. SES verified identity 점검 (구 도메인 발신 identity 가 있는지)
17. AWS Marketplace 구독 알림 수신자 변경
18. CloudWatch Alarms SNS 구독 이메일 변경
19. Cost Anomaly Detection 알림 수신자 변경
20. AWS Support 케이스 알림 수신자 변경
21. ACM 인증서 검증 이메일 (도메인 검증용 이메일이 구 도메인이면 갱신)

[Phase 4 — 5/28~5/29 사후 검증]
22. 신 이메일로 AWS 발신 메일 정상 수신 검증 (다음 결제 주기 인보이스, alert 등)
23. 1~4번 모두 신 이메일로 root 로그인 검증
24. 30일 모니터링 계획 — 구 dlt-partners.com 메일함에 AWS 발신 메일 추가 잔존 여부 추적 (Phase 3 누락 식별)
```

### 작업 시점 권장
- **5/26 (월)**: TODO-030 완료 직후 → Phase 1 (이메일 변경) + Phase 2 (부가 정보 갱신) 본격 시작
- **5/27~5/28**: Phase 3 (부가 리소스 정리)
- **5/29 (금)**: 1차 마감 — 핵심 이전 완료 판정
- **5/29 이후 30일**: Phase 4 후속 모니터링 (구 메일함 추적)

### 변경 순서 이유
**2번 → 3번 → 4번 → 1번** 순서:
- 1번에 사용자 IAM user (taenyon) 가 있어 cross-account 검증 작업의 베이스
- 1번을 먼저 바꾸면 검증 도중 발생하는 문제 대응이 어려워짐
- 마지막에 1번 바꾸면 만약 1번에서 트러블 발생해도 2·3·4번에서 들여다볼 수 있음 (cross-account role 통해)

---

## 컨텍스트

### 배경
- 사용자 소속이 dlt-partners.com → neuralarcade.ai 로 이전 진행 중
- 계약 진행 + 결제 계좌 변경 완료 (파트너사 MSP 처리)
- AWS 계정 6개 중:
  - **1~4번: neuralarcade.ai 측으로 이전 → 본 TODO 대상**
  - 5·6번: dlt-partners 측에 잔류 ([[TODO-030-aws-account-5-6-handover-dlt]])
- 6계정 모두 사용자가 root + MFA 통제

### 1~4번 구조 (현재)
- 1번: 공통 리소스 보유 + IAM 허브 (사용자 IAM user `taenyon`)
- 2·3·4번: 1번에서 cross-account role 전환으로 접근
- 결제: 파트너사가 회사 단위로 구분 처리 (1~4 = neuralarcade.ai 측 그룹)

### 이전 후 목표 상태
- 1~4번 root 이메일이 @neuralarcade.ai 도메인
- Alternate contacts·Tax·Account name 모두 neuralarcade.ai 법인 정보
- 사용자 MFA 디바이스는 그대로 유지 (디바이스 교체 불필요)
- 5·6번과 완전 격리 ([[TODO-030-aws-account-5-6-handover-dlt]] 에서 처리)
- 파트너사 결제 시스템에서 인보이스가 neuralarcade.ai 측 정보로 발행

### 외부 의존
- neuralarcade.ai 도메인 메일함 (Verification 메일 수신 가능해야 함)
- neuralarcade.ai 법인 등기 정보 (Tax settings 입력용)
- 파트너사(MSP) — 결제 분리는 이미 완료, 추가 작업 없음

---

## 현재 상태

**2026-05-25 (월) — 🎉 Phase 1 (4계정 이메일 변경) 완료. Phase 2 보류 (전파·검증 후 진행)**.

완료 사항:
- ✅ 신 root 이메일 4개 (@neuralarcade.ai) 발급 완료 (5/24)
- ✅ 사업자등록증 보유 (5/24)
- ✅ 메가존 회신 수신 (5/25)
- ✅ **Phase 1 완료**: 1~4번 root 이메일 모두 @neuralarcade.ai 로 전환 (5/25)
- ✅ 각 계정 신 이메일 root 로그인 검증 완료
- ✅ 1번 IAM user `taenyon` 로그인 정상 확인

진행 중 / 대기:
- ⏳ **4시간 전파 대기** (5/25 시작) — 모든 시스템 반영 시점까지 모니터링
- ⏳ **Phase 2 보류** (사용자 결정 5/25): 이메일 변경 검증 (인보이스 등) 후 진행
  - Tax settings (사업자등록증)
  - Contact information (회사명·주소·전화)
  - Account name (선택)
- ⏸ **Alternate Contacts 건너뛰기** (사용자 결정 5/25) — 향후 담당자 분리 결정 시 진행. 현재는 root 이메일로만 결제·보안 알림 수신
- ⏳ Phase 3 부가 리소스 (Route 53/SES/Marketplace/CloudWatch 등) — Phase 2 와 함께 또는 이후
- ⏳ Phase 4 검증 + 30일 모니터링

선행 조건:
- [[TODO-030-aws-account-5-6-handover-dlt]] — VPN/Bastion/AD/ADFS 영역 영향 식별됨, **단독 진행 어려움 — 딜라이트룸 협의 필요**. 본 TODO 의 1번 이메일 변경 자체는 영향 없음 (root 메타데이터 변경만)

---

## 다음 단계

### 5/22~5/25 (사전 준비) ✅ 완료
- [x] 1~4번 각각 신 root 이메일 주소 확정 (@neuralarcade.ai, 계정별 고유) — ✅ 2026-05-24
- [x] 신 도메인 메일함 작동 확인 — ✅ Phase 1 작업 중 verification 코드 정상 수신으로 검증됨 (5/25)
- [x] neuralarcade.ai 법인 정보 패키지 준비 — ✅ 사업자등록증 보유 (2026-05-24)
- [x] 1~4번 root 비밀번호·MFA 보유 재확인 — ✅ Phase 1 작업으로 모두 검증됨 (5/25)

### 5/25 (월) — Phase 1 완료 ✅
- [x] 2번 계정 root 이메일 변경 + 검증
- [x] 3번 계정 root 이메일 변경 + 검증
- [x] 4번 계정 root 이메일 변경 + 검증
- [x] 1번 계정 root 이메일 변경 + 검증 (IAM user `taenyon` 정상 확인)

### 다음 세션 (5/25 저녁 ~ 5/26)
- [ ] 4시간 전파 후 신 이메일에 AWS 발신 메일 정상 수신 확인 (테스트: 결제 알림 수동 트리거 또는 단순 수신 대기)
- [ ] 1번 콘솔에서 cross-account 의존 인벤토리 (IAM Users · 외부 회사 ARN Trust)
- [ ] Phase 2 진행:
  - [ ] Tax settings (4계정, 사업자등록증 입력) — 인보이스 영향 큼 → 우선
  - [ ] Contact information (4계정, 회사명·주소·전화)
  - [ ] (선택) Account name (4계정)
  - [ ] Alternate Contacts — **건너뛰기 결정 (5/25)**, 향후 담당자 분리 시 재진행

### 5/27~5/29 (Phase 3 — 부가 리소스 정리)
- [ ] Route 53 → Registered domains → 각 도메인 Contact information 갱신
- [ ] SES → Verified identities → 발신 identity 점검 (구 도메인 잔존 여부)
- [ ] AWS Marketplace → 구독 목록 → 알림 수신자 변경
- [ ] CloudWatch → SNS Topics → Subscriptions 이메일 변경
- [ ] Billing → Cost Anomaly Detection → 알림 수신자 변경
- [ ] AWS Support → Case 알림 수신자 변경
- [ ] ACM → 인증서 검증 방식이 이메일이면 신 도메인 검증 가능 여부 점검

### 5/28~5/29 (Phase 4 — 검증 + 마감)
- [ ] 1~4번 모두 신 이메일로 root 로그인 + IAM user 로그인 검증 (재확인)
- [ ] 다음 결제 주기 (6월) 이전 — 파트너사에 인보이스 발행 주소·수신자 갱신 확인
- [ ] 5/29 (금) 마감 판정 — 핵심 이전 완료

### 5/26 (월) — Phase 1 + Phase 2 (TODO-030 완료 후 동일 일자)
- [ ] 2번 root 이메일 변경 + Alternate contacts + Tax + Account name → 신 정보로
- [ ] 3번 동일
- [ ] 4번 동일
- [ ] 1번 마지막에 동일 (모든 검증 완료 후)
- [ ] 각 계정 변경 직후 신 이메일로 root 로그인 테스트

### 5/27~5/28 (Phase 3 — 부가 리소스 정리)
- [ ] Route 53 → Registered domains → 각 도메인 Contact information 갱신
- [ ] SES → Verified identities → 발신 identity 점검 (구 도메인 잔존 여부)
- [ ] AWS Marketplace → 구독 목록 → 알림 수신자 변경
- [ ] CloudWatch Alarms → SNS Topics → Subscriptions 이메일 변경
- [ ] Billing → Cost Anomaly Detection → 알림 수신자 변경
- [ ] AWS Support → Case 알림 수신자 변경
- [ ] ACM → 인증서 검증 방식이 이메일이면 신 도메인 검증 가능 여부 점검

### 5/28~5/29 (Phase 4 — 검증 + 마감)
- [ ] 1~4번 모두 신 이메일로 root 로그인 + IAM user 로그인 검증
- [ ] 다음 결제 주기 이전 — 파트너사에 인보이스 발행 주소·수신자 갱신 확인
- [ ] 5/29 (금) 마감 판정 — 핵심 이전 완료

### 5/29 이후 (장기 모니터링)
- [ ] 30일간 구 dlt-partners.com 메일함 모니터링 — AWS 발신 메일 잔존 여부 추적
- [ ] 잔존 발견 시 해당 항목 신 도메인으로 갱신

---

## 작업 절차 상세

### Phase 1 — Root 이메일 변경 (계정마다 반복)

⚠ **루트 사용자로만 변경 가능** (IAM 사용자/역할 불가). **구 이메일 verification 없음** — 신 이메일 확인 코드만 처리.

> 공식 가이드: https://docs.aws.amazon.com/ko_kr/accounts/latest/reference/manage-acct-update-root-user-email.html
> AWS 공식 절차 반영 (2026-05-25 검증)

```
[2번 → 3번 → 4번 → 1번 순서]

1. 루트 이메일·암호로 콘솔 로그인 (https://console.aws.amazon.com/)
2. 우측 상단 계정명/번호 클릭 → "계정"
3. 계정 페이지 → "계정 세부 정보" 옆 "작업" 클릭
   → "이메일 주소 및 암호 업데이트" 선택
4. "계정 세부 정보" → "이메일 주소" 옆 "편집" 클릭
5. "계정 이메일 편집" 페이지 입력:
   - 새 이메일 주소 (@neuralarcade.ai)
   - 새 이메일 주소 확인 (재입력)
   - 현재 암호
   → "저장 후 계속" 클릭
6. 신 이메일함에서 확인 코드 수신
   - 발신자: no-reply@verify.signin.aws
   - 도착: 최대 5분
   - 안 오면 스팸/정크 폴더 확인
   - OTP 발송 후 24시간 이내 처리 필수
7. "확인 코드" 필드 입력 → "업데이트 확인"
8. 콘솔 표시 즉시 갱신, 전체 시스템 전파 최대 4시간
9. 로그아웃 → 신 이메일로 root 로그인 검증
   - 비밀번호·MFA 그대로 (변경 없음)
```

**주의**:
- 신 이메일 수신이 절대적으로 중요 — 사전에 테스트 메일로 수신 확인 필수
- 콘솔 작업 자체는 5~10분/계정, 4시간 전파 별도
- 변경 단계에서 MFA 요구 없음 (비밀번호만) — 신 이메일 로그인 검증 시에는 MFA 필요

### Phase 1 대안 — AWS Organizations 일괄 변경 (1번이 관리 계정인 경우)

> 공식 가이드: https://docs.aws.amazon.com/ko_kr/accounts/latest/reference/manage-acct-update-root-user-email.html

**1~4번이 같은 Organization 멤버이고 1번이 관리 계정이면** 1번 콘솔에서 CLI 로 2·3·4번 일괄 변경 가능:

사전 조건:
- Account Management 서비스 신뢰할 수 있는 액세스 활성화
- IAM 권한: `account:GetPrimaryEmail`, `account:StartPrimaryEmailUpdate`, `account:AcceptPrimaryEmailUpdate`

```bash
# 1) 현재 이메일 조회
aws account get-primary-email --account-id <ACCOUNT_ID>

# 2) 이메일 변경 시작 (신 이메일로 OTP 발송)
aws account start-primary-email-update \
  --account-id <ACCOUNT_ID> \
  --primary-email <NEW_EMAIL>

# 3) 신 이메일 수신한 OTP 로 변경 확정
aws account accept-primary-email-update \
  --account-id <ACCOUNT_ID> \
  --otp <CODE> \
  --primary-email <NEW_EMAIL>
```

5/26 작업 전 1번 콘솔 → AWS Organizations 메뉴에서 1번이 관리 계정인지 확인 후 결정.

### Phase 2 — 부가 정보 갱신 (이메일 변경 직후 같은 세션에서)

```
[같은 계정 콘솔 내]

1. Account → "Alternate Contacts"
   - Billing: 청구 담당자 이름·이메일·전화·직책 → neuralarcade.ai 측
   - Operations: 운영 담당자 → neuralarcade.ai 측
   - Security: 보안 담당자 → neuralarcade.ai 측
   ※ 결제 계좌는 이미 변경됐어도 Alternate contacts 누락 시 인보이스·보안 알림이 구 도메인으로 감

2. Billing and Cost Management → "Tax settings"
   - 사업자등록번호 → neuralarcade.ai 법인 번호
   - 법인명·주소 → 신 정보
   - 세금 면제 증명서 (해당 시)

3. (선택) Account → "Account Settings" → Account name
   - 계정 별칭을 neuralarcade.ai 측 명칭으로 (예: "neuralarcade-common-prod")

4. Account → Contact information
   - 회사명·주소·전화 → 신 정보 (Tax settings 와 일치 확인)
```

### Phase 3 — 부가 리소스 정리

#### Route 53
```
1. Route 53 → "Registered domains"
2. 각 도메인 → "Contact information" → Edit
3. Registrant / Admin / Tech 연락처 모두 neuralarcade.ai 측 정보로 갱신
4. WHOIS 반영까지 24~48시간 소요
```

#### SES verified identities
```
1. SES → "Verified identities"
2. 구 도메인(dlt-partners.com) 발신 identity 있는지 확인
3. 있으면: 운영 중인지 점검 → 사용 중이면 신 도메인 identity 추가 등록·전환 → 구 identity 삭제
```

#### Marketplace · CloudWatch Alarms · Cost Anomaly · Support · ACM
```
[각 항목 콘솔에서 알림 수신자·연락처 일괄 갱신]
- AWS Marketplace → Subscriptions → 알림 수신 이메일
- CloudWatch → SNS Topics → Subscriptions → Email endpoint 변경
- Billing → Cost Anomaly Detection → Recipient
- Support → Case 통보 이메일
- ACM → 인증서 검증 이메일 (DNS 검증 방식이면 영향 없음, 이메일 검증이면 도메인 admin@/postmaster@/등 점검)
```

### Phase 4 — 검증

#### 신 이메일 로그인 검증
```
1~4번 각각:
1. 로그아웃
2. 신 이메일로 root 로그인 시도
3. 비밀번호·MFA 정상 작동 확인
4. IAM user (taenyon) 로그인 정상 작동 확인 (URL 동일)
```

#### 결제·인보이스 검증
```
1. 파트너사(MSP) 다음 결제 주기(6월) 인보이스 발행 시:
   - 수신자가 neuralarcade.ai 측 담당자
   - 회사명·주소가 neuralarcade.ai 법인
   - 세금계산서·계산서 발행 정보 정확
2. 잔존 시 파트너사에 수동 갱신 요청
```

#### 30일 메일함 모니터링
```
구 tony@dlt-partners.com 메일함 (또는 alias) 에서:
- "AWS" 발신자 메일 자동 분류 폴더 생성
- 30일간 잔존 알림 수신 항목 추적
- 발견 시 해당 항목 신 도메인으로 갱신 (Phase 3 누락분)
```

---

## 함정·주의사항

### 신 이메일은 계정별 고유해야 함
- AWS 는 한 이메일로 여러 계정 못 만듬
- `aws-account-1@neuralarcade.ai`, `aws-account-2@...` 식으로 분리하거나 메일 alias 활용
- 메일링 그룹(예: `aws@neuralarcade.ai`)을 4개 계정에 공통으로 쓰는 건 불가

### Tax settings 변경의 백워드 영향
- 세금계산서 발행 정보가 분기 중간에 바뀌면 그 분기 인보이스가 회계상 복잡해질 수 있음
- 파트너사 결제 처리 시점과 Tax 정보 갱신 시점 정렬 필요 — 5/26 이전 결제분은 구 정보, 이후는 신 정보로 처리되도록

### MFA 디바이스
- 이메일만 변경, MFA 디바이스·비밀번호는 그대로 유지
- 단, 변경 과정에서 MFA OTP 입력 필요 — 디바이스 준비 필수

### Verification 메일 수신 실패
- 구·신 양쪽 다 verification 메일 받아야 함
- 신 도메인 메일함이 아직 셋업 안 됐거나, alias가 잘못 설정되면 verification 실패 → 변경 롤백
- 5/26 작업 전에 신 도메인 메일함 작동 확인 필수

### 1번 IAM user 의 자격 자체
- 1번 root 이메일이 neuralarcade.ai 로 바뀌면 1번 안에 있는 IAM user `taenyon` 도 새 법인 소속이 됨
- 사용자가 두 법인 양쪽에서 일하는 게 아니라면 1번 IAM user 는 그대로 유지 (이메일은 IAM user 와 무관)
- 다른 IAM user (전 동료 등) 가 1번에 있다면 인계·삭제 결정 필요 — Phase 0 에서 사전 점검

### 공통 리소스 의존성
- 1번에 공통 리소스(공유 ECR, Route 53 hosted zone, 공유 KMS 키 등) 가 있고 5·6번에서 참조하던 것 있으면 TODO-030 Phase 3 에서 함께 정리 필요
- 본 TODO 의 1번 이메일 변경 자체는 영향 없음 (리소스 ARN 은 그대로)

### 파트너사(MSP) 결제 처리 시점
- "결제 계좌 변경 완료" 의 실제 의미 = 파트너 시스템 등록 정보 갱신 완료
- AWS 콘솔의 Payment methods 는 파트너 카드 그대로일 가능성 (영향 없음)
- 다만 Tax settings 와 Alternate Billing contact 갱신은 인보이스 회사명·수신자 정확화에 필수

### CloudTrail 모니터링 잔존
- 1번 IAM user 가 1~4번 (및 5·6번) 에서 활동한 이력은 CloudTrail 에 그대로 남음 (정상)
- 신 도메인 이메일로 바뀐 이후의 활동만 갱신된 식별로 기록됨

### Route 53 / SES / ACM 잔존 영향
- 가장 자주 빠뜨리는 카테고리. Phase 3 에서 누락하면 30일 후 도메인 갱신 알림이 구 메일로 가서 못 받고 도메인 만료 위험

---

## 검증 체크리스트 (이전 완료 판정)

1~4번 각각에 대해 다음 모두 만족하면 이전 완료:

- [ ] Root 이메일이 @neuralarcade.ai 도메인
- [ ] 신 이메일로 root 로그인 검증 완료
- [ ] Alternate contacts (Billing/Operations/Security) 모두 neuralarcade.ai 측
- [ ] Tax settings → neuralarcade.ai 법인 사업자등록번호·주소
- [ ] Account name → (선택) neuralarcade.ai 측 명칭
- [ ] Route 53 도메인 등록 연락처 갱신 (해당 시)
- [ ] SES verified identity 점검 완료
- [ ] Marketplace·CloudWatch·Cost Anomaly·Support 알림 수신자 갱신
- [ ] 다음 결제 주기 인보이스가 neuralarcade.ai 측으로 정상 발행
- [ ] 30일 메일함 모니터링 시작

---

## 진행 로그

- 2026-05-22 — TODO 등록. 사용자와 5/22 1차 가이드 합의:
  - 1~4번 이메일 변경 대상 (5·6번은 [[TODO-030-aws-account-5-6-handover-dlt]] 별도)
  - 결제 계좌 변경 + 파트너사 통보 완료
  - 6계정 root + MFA 사용자 통제, 1~4번 MFA 디바이스 그대로 유지
  - 작업일 5/26 (TODO-030 완료 후 동일 일자), 마감 5/29
  - 변경 순서: 2 → 3 → 4 → 1 (1번을 마지막에)

- 2026-05-25 (월) — Phase 1 본 작업 시작:
  - ✅ **2번 계정 이메일 변경 완료** — Step 1~6 통과, 신 이메일 로그인 검증 성공
  - ✅ **3번 계정 이메일 변경 완료** — 검증 성공
  - ✅ **4번 계정 이메일 변경 완료** — 검증 성공
  - ✅ **1번 계정 이메일 변경 완료** — 검증 성공 (IAM user `taenyon` 로그인 정상)
  - 🎉 **Phase 1 전체 완료 (4/4)** — 1~4번 모두 @neuralarcade.ai root 이메일 전환
  - 사용자 결정 (5/25 진행 종료):
    - Alternate Contacts (Billing/Operations/Security) = **건너뛰기** (담당자 분리 미정, root 이메일로 알림 수신 가정)
    - Phase 2 나머지 (Tax/Contact/Account name) = **이메일 변경 검증 후 진행** (4시간 전파 + 6월 인보이스 정상 발행 확인)
  - **오늘 작업 종료**. 다음 세션 진입 시점:
    1. 4시간 전파 후 신 이메일에 AWS 발신 메일 정상 수신 확인 (5/25 저녁 또는 5/26)
    2. (이후) Phase 2 진행 — Tax settings 부터 우선 (인보이스 발행 정보)
    3. (이후) Phase 3 부가 리소스 (Route 53/SES/Marketplace/CloudWatch)
    4. 30일 메일함 모니터링 시작 (구 @dlt-partners.com)

- 2026-05-25 (월) — 메가존 회신 수신, TODO-031 본 작업 진행 가능:
  - **이메일 변경 자체**: 메가존 답변 = 간단, 예상 이슈 없음. 기존 절차와 일치
  - **신 정보 1**: 변경 적용 최대 4시간 소요 가능 → 5/26 작업 시간 여유 확보 필요
  - **신 정보 2**: 신 이메일 사전 수신 테스트 권장 (verification 메일 수신 확인)
  - **신 정보 3**: Alternate contacts 동시 갱신 권장 (기존 절차 이미 포함)
  - 메가존 회신은 5·6번(TODO-030) 측에 더 큰 영향 — VPN/Bastion/AD/ADFS 가 1번에 구성, 단독 진행 어려움 식별
  - TODO-031 자체는 1번 root 이메일 변경 = 리소스 ARN 영향 없음 (메타데이터 변경) → 5·6번 인프라 의존성과 무관하게 진행 가능
  - 참조 링크 추가 (현재 상태 섹션)

- 2026-05-25 (월) — AWS 측 점검사항 피드백 대기 진입:
  - 사용자가 AWS 담당자에게 계정 이메일 변경 건 점검사항 요청 발신
  - 실제 이메일 변경 작업 = AWS 피드백 수신 후 진행 (피드백 결과 반영 + 절차 보강 가능성)
  - 5/26 본 작업일 = 피드백 수신 시점에 따라 결정 (당일 도착 시 5/26 진행, 지연 시 5/27~5/29 윈도우 내 재배치)
  - 현재 상태 = AWS 회신 대기 (외부 의존)
  - 사용자가 잔여 할 일 정리 요청

- 2026-05-24 (일) — 사전 준비 점검 + 시작 마킹:
  - 사용자 답변:
    1. TODO-030 (5·6번 인계) 담당자 별도 두지 않음 — 본인 단독 진행 ("그냥 내가 다 하면 되")
    2. 신 root 이메일 4개 (@neuralarcade.ai) 발급 완료 ("만들어놨음")
    3. 사업자등록증 보유 — Tax settings·Contact information 입력 가능
    4. 5/26 본 작업일에 끝까지 단독 진행, 혼자 못하는 항목만 별도로 분리 ("할 수 있는 건 다 진행")
    5. 시작일 오늘(2026-05-24)부터 마킹
  - 갱신: frontmatter 시작일 → 2026-05-24, 담당 → "사용자 직접 (전 단계 단독 수행)"
  - 5/26 작업 절차 안내 (Phase 1 → Phase 2 → Phase 3 → Phase 4 단독 진행 가이드 + 단독 진행 불가 항목 식별 기준)
  - Phase 0 잔여 항목 (root 비밀번호·MFA 보유 재확인 / 1번 cross-account 인벤토리)는 5/26 작업 시작 직전·중에 처리 (사전 점검 추가 세션 불요)

- 2026-05-28 (목) — ✅ **완료** (사용자 5/29 확정). Phase 1 (1~4번 root 이메일 @neuralarcade.ai 전환, 5/25) 에 이어 Phase 2 (Tax/Contact/Account name) · Phase 3 (Route 53/SES/Marketplace/CloudWatch 등 부가 리소스) 갱신 완료. 30일 메일함 모니터링은 장기 추적(완료와 별개). TODO.md 완료 섹션 이동.
