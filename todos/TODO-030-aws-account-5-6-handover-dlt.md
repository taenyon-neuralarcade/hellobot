# TODO-030 AWS 5·6번 계정 dlt-partners 인계

**유형**: 액션
**상태**: ✅ 완료 (2026-05-28) — 5·6번 담당자 MFA 인계 완료. ⚠ 잔여 보안 격리 단계(비밀번호 변경·사용자 MFA 제거·Alternate contacts·신뢰 Role 정리)는 PMI 종료 후 재개 (필요 시 신규 TODO 또는 TODO-033 연계)
**등록**: 2026-05-22
**시작**: 2026-05-28
**완료**: 2026-05-28
**마감**: PMI 종료 후 (미정) — 5/28 담당자 MFA 인계로 본 TODO 종료 처리
**작업 예정**: 5/28 (목) MFA 추가 등록 완료 ✅ / 잔여 단계 = PMI 종료 후 (별도 추적)
**중요도**: ⭐⭐⭐ 최상 (사용자 지정 2026-05-22)
**담당**: 사용자 직접 + dlt-partners 인계 담당자
**관련**: [[TODO-031-aws-account-1-4-migration-neuralarcade]] (후속 작업, 본 인계 완료 후 진행)

---

## 작업 절차 및 순서 (요약)

### 전체 흐름

```
[Phase 0 — 5/26 작업 전 사전 점검]
1. 5·6번 root 이메일 주소 확인 (담당자 전달용)
2. 5·6번 IAM Users 목록 확인 — 본인(taenyon 등) 존재 여부
3. 5·6번 IAM Roles 중 1번 계정 ARN 신뢰 Role 식별 (Administrator role 등)
4. 인계 담당자 정보 패키지 채널 확정 (1Password 공유 또는 안전 메신저)

[Phase 1 — 5/26 인계 실행: 사용자 측]
5. 5·6번 각각 정보 패키지 작성·담당자에게 전달
   - 계정 ID, 별칭, root 이메일, 현 root 비밀번호, MFA OTP 받는 방법

[Phase 2 — 5/26 인계 실행: 담당자 측 (5·6번 각각 수행)]
6. 담당자가 root 로그인 (사용자 비밀번호 + 사용자 MFA OTP 1회)
7. 담당자가 root 비밀번호 변경 (담당자만 알게 됨)
8. 담당자가 본인 MFA 디바이스 추가 등록
9. (검증 후) 사용자 MFA 디바이스 해제
10. Account → Alternate contacts (Billing/Operations/Security) dlt-partners 측 정보로 갱신
11. (선택) 담당자 명의 IAM user 신설 + MFA — 향후 root 직접 사용 회피
12. (선택) Account name 갱신

[Phase 3 — 5/26 격리: 사용자 측 (Phase 2 검증 완료 후)]
13. 5·6번 각각: IAM → Roles → 1번 계정 ARN 신뢰 Role 정리 (삭제 또는 trust principal 제거)
14. 브라우저 역할 전환 즐겨찾기에서 5·6번 항목 제거
15. ~/.aws/config 없음(CLI 미사용) — 해당 없음

[Phase 4 — 5/27~5/29 사후 검증]
16. CloudTrail 에서 1번 → 5·6번 AssumeRole 이벤트 0건 확인 (12시간 STS 토큰 만료 이후)
17. (선택) IAM Access Analyzer 로 외부 계정 신뢰 관계 잔존 점검
18. 최종 인계 완료 → TODO-031 (1~4번 이전) 진행 가능 상태
```

### 작업 시점 권장
- **5/28 (목) 오전 또는 오후**: Phase 1~3 (인계 실행·격리) — 담당자 가용 시간대 합의 완료 (2026-05-27 사용자 갱신)
- **5/29 (금) 정오 이후**: Phase 4 (CloudTrail 모니터링, STS 12시간 만료 후)
- **5/29 (금)**: 인계 완료 판정 + 잔여 정리 ⚠ 작업 익일이 곧 마감 — 검증 윈도우 1일로 압축됨

> 5/26 (월) 작업 예정이었으나 담당자 가용성으로 5/28 (목) 로 변경. 마감 5/29 (금) 는 유지하되 검증 시간이 빠듯 — 슬립 발생 시 6/1 (월) 까지 1영업일 연장 검토.

---

## 컨텍스트

### 배경
- 사용자 소속이 dlt-partners.com → neuralarcade.ai 로 이전 진행 중 (계약·결제 계좌 변경 완료)
- 보유 AWS 계정 6개:
  - 1~4번: neuralarcade.ai 측으로 함께 이전 (별도 TODO-031)
  - **5·6번: dlt-partners 측에 잔류 → 본 TODO 대상**
- 6계정 모두 사용자가 root + MFA 통제권 보유 (단일 MFA 디바이스로 관리 중)
- 결제: 파트너사(MSP)가 회사별 구분 처리 — 이미 통보 완료, 별도 작업 없음

### 5·6번 접근 구조 (현재)
- 5·6번에 사용자 IAM user 직접 등록 없음
- 1번 IAM user (taenyon) → 5·6번 IAM Role (Administrator 등) cross-account assume role 방식
- root 자격(이메일·비밀번호·MFA)은 사용자가 보유

### 인계 후 목표 상태
- 5·6번 root 자격 = dlt-partners 담당자만 보유
- 1번 → 5·6번 cross-account 신뢰 관계 = 끊김
- 사용자(neuralarcade.ai)는 5·6번에 일절 접근 권한 없음 (보안 격리)
- 결제는 파트너사가 회사별 분리 처리 (별도 작업 불필요)

### 외부 의존
- dlt-partners 측 인계 담당자 (정해짐, 5/26 작업일 동시 가용 필요)
- 파트너사(MSP, 메가존소프트 추정) — 결제 처리 측 (별도 작업 없음, 통보 완료)

### 관련 메모
- [[reference_gcp_billing_permission]] (메가존 결제 권한, GCP)
- AWS도 같은 파트너 가능성 — 결제 구조는 [[reference_gcp_billing_permission]] 참고

---

## 현재 상태

**2026-05-28 (목) — 5·6번 담당자 MFA 추가 등록 완료, 잔여 단계 PMI 종료 후로 연기 (대기 전환)**.

5/28 완료:
- 5번 root: 담당자 디바이스 MFA 추가 등록 ✅
- 6번 root: 담당자 디바이스 MFA 추가 등록 ✅
- 현재 양 계정 모두 **사용자 MFA + 담당자 MFA 이중 등록 상태** (AWS root 최대 8개 허용)

⚠ 사용자 결정 (5/28): **나머지 인계 단계는 전체 PMI 종료 후 진행**. 따라서:
- 사용자 root 자격(비밀번호 + 본인 MFA)은 **아직 유지** — 보안 격리 미성립 상태 (의도된 중간 상태)
- 비밀번호 변경 / 사용자 MFA 제거 / Alternate contacts / Phase 3 신뢰 Role 정리 / Phase 4 CloudTrail 검증 = **전부 PMI 종료 후**
- 5/29 마감 + 검증 윈도우는 더 이상 적용 안 됨 — 블로커가 "PMI 종료"로 전환

**재개 트리거**: PMI 종료 시점 (TODO-007 비트윈 분리 umbrella + 조직 이전 완료와 연동 추정). 트리거 도달 시 아래 "PMI 종료 후" 단계부터 실행.

---

**2026-05-25 (월) — 메가존 회신 수신, 단독 진행 전제 부분적 재검토 필요**.

확인 완료 사항:
- 6계정 root + MFA 모두 사용자 통제
- 5·6번 IAM user 직접 등록 없음 (cross-account role 방식)
- 5·6번 이메일은 변경하지 않을 예정
- 파트너사(MSP, 메가존) 통보 완료

⚠ **메가존 회신 (5/25) 새 정보**:
- **VPN · Bastion · AD/ADFS 서버가 thingsflowmaster (1번 계정)에 구성**되어 있음 (안성진 SA 안내) → 5·6번이 1번 인프라를 인증·접속 경로로 의존할 가능성. **단순 IAM Role Trust 정리로 끝나지 않을 수 있음**
- 비트윈 측 IAM Role Trust Policy 의 Principal `thingsflowmaster(982154780443)` 제거 필요 — Role 단순 삭제가 아니라 **존속하되 Principal 만 제거** 옵션도 있음
- **Cross Account 공유 리소스 인벤토리 필요**: S3 Bucket Policy / KMS Key Policy / Secret Manager / ECR 등 상대 계정 ARN 참조
- CLI/SDK, CI/CD Pipeline 에서 Assume 흐름 점검 필요 (파이프라인 없으면 패스)
- 딜라이트룸과 별도 논의 권장 항목 식별됨 (AD/ADFS 내용 메가존도 정확히 모름)
- Bastion 대안: EC2 Session Manager 또는 별도 Client VPN 구성 권장 (장기 옵션)

확인 필요:
- 5·6번 root 이메일 정확한 주소
- 5·6번 IAM Roles 중 1번 신뢰 Role 정확한 이름·개수
- **5·6번 인프라 (VPN/Bastion/AD/ADFS) 가 1번에 어떻게 의존하는지 인벤토리** — 끊으면 비트윈 측 운영자 접속 불가 위험
- **Cross Account 공유 리소스 (S3/KMS/Secret/ECR) 인벤토리**
- 딜라이트룸 (비트윈) 측 협의 채널 — 인프라 영향 사전 통보 필요

---

## 다음 단계

### 5/22~5/25 (사전 점검)
- [ ] 5번 root 로그인 → Account 페이지 → root 이메일 주소 메모
- [ ] 6번 root 로그인 → Account 페이지 → root 이메일 주소 메모
- [ ] 5·6번 각각 IAM → Users 에 본인 IAM user 존재 여부 확인 (있으면 Phase 3 에서 삭제 필요)
- [ ] 5·6번 각각 IAM → Roles → Trust policy 의 Principal 에 `thingsflowmaster (982154780443)` 있는 Role 목록화 (Role 이름 + 용도)
- [ ] **🆕 5·6번 인프라 의존성 인벤토리** (메가존 회신 반영, 5/25):
  - VPN 서버 위치·구성 (1번에 있다면 5·6번에서 접근 끊김 영향)
  - Bastion 서버 위치·구성
  - AD/ADFS 서버 — 5·6번 사용자 인증을 1번 ADFS 가 처리하는지
  - CLI/SDK · CI/CD Pipeline 의 AssumeRole 흐름 (1번 → 5·6번)
- [ ] **🆕 Cross Account 공유 리소스 인벤토리** (메가존 회신 반영, 5/25):
  - S3 Bucket Policy 에 1번 계정 ARN 참조
  - KMS Key Policy 에 1번 계정 ARN 참조
  - Secret Manager 공유 시크릿
  - ECR 리포지토리 공유 권한
- [ ] **🆕 딜라이트룸 (비트윈) 측 협의 채널 확보** — AD/ADFS 영향 별도 논의 필요 (메가존도 정확히 모름)
- [ ] (선택) 5·6번 Reserved Instances / Savings Plans / Marketplace 구독 사전 점검 — 인계 후 끊김 영향 미리 파악

### ✅ 5/28 (목) — 완료
- [x] 5번 담당자 MFA 추가 등록
- [x] 6번 담당자 MFA 추가 등록

### ⏸ PMI 종료 후 — 잔여 인계 단계 (재개 트리거: PMI 종료)

> 5·6번 각각 수행. 사용자 MFA 제거 전 반드시 담당자 MFA 단독 재로그인 검증 통과할 것 (Phase 2 step 5).

- [ ] (담당자) root 비밀번호 변경 — 담당자만 아는 값으로
- [ ] (검증) 신 비밀번호 + 담당자 MFA 로 재로그인 성공 확인 ← 통과 전 다음 단계 금지
- [ ] (담당자) 사용자 MFA 디바이스 제거 — 이 시점부터 사용자 root 접근 차단 (보안 격리 성립)
- [ ] 사용자 Authenticator 앱에서 5·6번 entry 삭제 (AWS 측 해제와 별개)
- [ ] Alternate contacts (Billing/Operations/Security) → dlt-partners 측 갱신
- [ ] (선택) Account name → dlt-partners 측 명칭
- [ ] Phase 3: 5·6번 각각 1번 신뢰 Role 정리 (삭제 또는 trust principal 제거)
- [ ] 브라우저 역할 전환 즐겨찾기에서 5·6번 항목 제거
- [ ] Phase 4: CloudTrail 에서 1번 → 5·6번 AssumeRole 0건 확인 (작업 후 12시간 STS 만료 후)
- [ ] (선택) 5·6번 IAM Access Analyzer 활성화 + 외부 계정 신뢰 관계 잔존 점검
- [ ] 인계 완료 판정 (검증 체크리스트 8항목 충족)

> ⚠ 주의: 잔여 단계는 TODO-033 (비트윈 인프라 의존성 — VPN/Bastion/AD/ADFS, Cross Account 공유 리소스) 정리와 순서 조율 필요. 1번 신뢰 Role·인프라 의존성을 먼저 끊으면 비트윈 측 운영 접속 불가 위험.

---

## 작업 절차 상세

### Phase 0 — 사전 점검 상세

#### 5·6번 root 이메일 확인 (콘솔)
```
1. 해당 계정 root 로그인
2. 우측 상단 계정명 클릭 → "Account"
3. "Contact information" 섹션 상단 → Root user email 메모
```
이 주소가 회사 공용/별칭이면 그대로 인계 가능. 사용자 개인 이메일이면 인계 후 password reset 불가 위험 — 담당자에게 사실 공유하고 처리 방향 합의.

#### IAM Users 존재 여부 (콘솔)
```
해당 계정 root 로그인 → IAM → 좌측 "Users" → 본인 이름 검색
```

#### Trust Role 식별 (콘솔)
```
해당 계정 root 로그인 → IAM → 좌측 "Roles"
→ 각 Role 클릭 → "Trust relationships" 탭
→ "Principal" 에 "arn:aws:iam::{1번 계정 ID}:..." 가 있는 Role 표시
→ Role 이름·생성일·용도 메모
```
일반적으로 자동 생성된 `OrganizationAccountAccessRole` 또는 수동 생성한 `Administrator` 같은 이름.

### Phase 1 — 정보 패키지 (사용자 작성)

5·6번 각각에 대해 안전 채널로 담당자에게 전달:

```
[AWS 5번 계정 인계 정보 — 2026-05-26]

계정 ID: xxxxxxxxxxxx
계정 별칭: ...
Region 주 사용: ap-northeast-2 / ap-northeast-1
청구 처리: {파트너사명} (회사 구분: dlt-partners 측, 통보 완료)

Root 로그인 정보:
- 이메일: ...
- 비밀번호: ... (변경 즉시 폐기)
- MFA: 인계 시점 사용자에게 OTP 1회 요청 (Phase 2 step 6)

작업 일정: 2026-05-26 (월) {시간 합의}
사용자 측 입회: tony@dlt-partners.com (Phase 2 검증 + Phase 3 실행)

현재 운영 중 주요 리소스: (사전 확인 후 보강)
- VPC: ...
- EC2/RDS/S3: ...
- (인계자가 파악해야 할 외부 의존성 포함)

외부 의존성:
- 1번 계정에서 들어가던 cross-account role: 5/26 인계 직후 제거 예정
- 1번 계정 리소스를 참조하는 5·6번 리소스: ... (있다면)

갱신 필요 항목:
- Alternate contacts (Billing/Operations/Security) → dlt-partners 측
- (선택) Account name → dlt-partners 측 명칭
- (선택) Tax settings → 변경 없음 (회사 정보 유지)

비상 연락:
- 이전 운영자 (사용자): tony@dlt-partners.com (인계 후 N일까지 질의 응답)
```

### Phase 2 — 담당자 root 셋업 (담당자가 5·6번 각각 수행)

> 공식 가이드:
> - MFA 개요: https://docs.aws.amazon.com/IAM/latest/UserGuide/enable-mfa-for-root.html
> - Virtual MFA 등록: https://docs.aws.amazon.com/IAM/latest/UserGuide/enable-virt-mfa-for-root.html
> - MFA 비활성화: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_disable.html
> AWS 공식 절차 반영 (2026-05-25 검증)

**핵심 원칙**: 새 MFA **먼저 추가 + 검증** → 그 다음 구 MFA 제거 (다운타임 없음, 사용자→담당자 안전 인계)

```
1. 사용자 비밀번호 + 사용자 MFA OTP 로 root 로그인

2. 우측 상단 계정명/번호 → "Security credentials"

3. (담당자 작업) 비밀번호 변경
   - "Password" 섹션 → "Change password"
   - 새 비밀번호 입력 (담당자만 알게 됨)

4. (담당자 작업) 새 MFA 디바이스 추가 (구 MFA 와 일시 공존)
   "Multi-factor authentication (MFA)" 섹션 → "Assign MFA device"
   a. Device name 입력 (예: "5-root-DLT-담당자명-2026")
   b. "Authenticator app" 선택 → "Next"
   c. QR 코드 표시 → 담당자 Authenticator 앱에서 스캔
      또는 "Show secret key" 로 시크릿 키 수동 입력
   d. 6자리 코드 연속 2개 입력:
      - "MFA code 1": 현재 표시 코드
      - 30초 대기 (앱이 새 코드 생성)
      - "MFA code 2": 새 코드
   e. "Add MFA" 클릭 → 등록 완료
   ※ root 당 최대 8개 등록 가능 — 사용자 + 담당자 디바이스 일시 공존

5. (검증) 로그아웃 → 신 비밀번호 + 담당자 MFA 로 root 로그인 테스트
   ※ 이 단계 통과 못하면 다음 단계 진행 금지 (구 MFA 제거하면 잠김)

6. (담당자 작업) 사용자 MFA 디바이스 제거
   Security credentials → "Multi-factor authentication (MFA)" 섹션
   → 사용자 디바이스 라디오 버튼 선택 → "Remove" → "Remove" 확인
   ※ AWS 측 등록 해제만 — 사용자 Authenticator 앱의 entry 는 별도 삭제 (사용자가 직접)
   ※ 제거 후 root 이메일로 확인 메일 발송 (`@amazon.com` 또는 `@aws.amazon.com`)

7. Account → Alternate contacts → Billing/Operations/Security 모두 dlt-partners 측 이메일·이름·전화로 갱신

8. (선택) Account → Account name 갱신

9. (선택) IAM → Users → 본인 명의 IAM user 신설 + AdministratorAccess + MFA 등록
   - 향후 root 직접 사용 회피, IAM user 로 일상 작업
```

⚠ **Step 6 (사용자 MFA 제거)** 이후 사용자는 5·6번 root 로그인 영구 불가. **Step 5 (신 MFA 검증) 통과 확인 후에만 Step 6 진행**.

### 단독 진행 시나리오 (2026-05-25 사용자 결정: "그냥 내가 다 하면 되")

사용자가 dlt-partners 측 운영자 역할을 흡수하는 경우 Phase 2 를 단순화:

```
1. 5·6번 root 로그인 (현 자격)
2. Security credentials → 비밀번호 변경 (선택: dlt-partners 운영용 신 비밀번호)
3. Alternate contacts → dlt-partners 측 정보로 갱신
4. (선택) Account name → dlt-partners 측 명칭
5. MFA 디바이스 = 사용자 본인 디바이스 그대로 유지 (별도 인계 담당자 없으므로)
   ※ 향후 dlt-partners 측 정식 담당자 정해지면 위 1~6 단계로 정식 인계
6. Phase 3 (1번 신뢰 Role 정리) 는 TODO-033 으로 분리
```

### Phase 3 — 1번 신뢰 끊기 (사용자가 5·6번 각각 수행)

```
[Phase 2 완료 직후, 사용자가 마지막으로 5·6번 들어가는 작업]

1. (가능하다면) 1번에서 5·6번 역할 전환으로 마지막 로그인
   ※ Phase 2 step 5 에서 MFA 해제됐다면 root 로그인 불가 — 1번 IAM user 의 cross-account assume role 만 가능
2. IAM → Roles → Phase 0 에서 메모한 Role 각각:
   (a) Role 자체 삭제: Role → "Delete" (담당자가 향후 이 Role 안 쓸 경우)
   (b) Trust policy 의 Principal 에서 1번 계정 ARN 만 제거: Role → "Trust relationships" → "Edit trust policy" → JSON 수정
   ※ 일반적으로 (a) 권장 — 담당자가 새로 만들어 쓰는 편이 깨끗
3. 5·6번에 사용자 IAM user (taenyon 등) 가 존재하면:
   - Access Key 비활성화 → CloudTrail 에서 사용 흔적 종료 확인 (24시간) → IAM user 삭제
   - 또는 즉시 AdministratorAccess detach → 일정 기간 모니터링 → 삭제
4. 브라우저:
   - AWS 콘솔 우측 상단 "Switch role" 이력에서 5·6번 항목 제거
   - 즐겨찾기 / 북마크 / 비밀번호 매니저에서 5·6번 항목 제거
```

### Phase 4 — 사후 검증

#### CloudTrail 모니터링
```
[5·6번 각각, 5/27 이후]
1. CloudTrail → Event history
2. 필터: Event name = "AssumeRole" OR "ConsoleLogin"
3. User identity 컬럼에서 "arn:aws:iam::{1번 ID}:user/taenyon" 또는 그 user 의 AssumeRole 이벤트가 0건인지 확인
4. (예외) 12시간 STS 토큰 만료 이전 = 5/26 발급 토큰이 5/27 새벽까지 남아있을 수 있음 — 5/27 정오 이후 점검 권장
```

#### IAM Access Analyzer (선택)
```
[5·6번 각각]
1. IAM → "Access analyzer" → "Create analyzer"
2. Type: Account analyzer
3. 결과에서 External access 항목 중 1번 계정 ARN 잔존 여부 확인
4. 잔존 시 Phase 3 step 2 누락 — 추가 정리
```

---

## 함정·주의사항

### MFA 디바이스 8개 한도 + entry 식별
- 사용자 단일 스마트폰 Authenticator 에 6계정 root + 1번 IAM user 등록되어 있을 가능성
- Authenticator entry 이름이 명확하지 않으면 해제 시 잘못된 entry 지울 위험 (특히 1~4번 root entry 보호 필수)
- **5/26 작업 전에 Authenticator 앱에서 6계정 entry 모두 이름 정리** (예: "AWS-acc1-root-2026", "AWS-acc5-root-DLT" 등 구분 가능하게)

### 12시간 STS 토큰 잔존
- AssumeRole 발급 토큰은 발급 시점부터 최대 12시간 유효
- Phase 3 에서 Trust policy 끊어도 이미 발급된 토큰은 만료까지 사용 가능
- 5/26 작업 후 12시간 + 여유 1시간 = 5/27 정오 이후 CloudTrail 점검

### Access Key 잔존
- 5·6번에 사용자 IAM user (taenyon 등) 가 있으면 그 user 의 Access Key 가 남아있을 가능성
- Key 자체 삭제 + CloudTrail 에서 사용 흔적 종료 확인 필수

### Reserved Instances / Savings Plans
- 5·6번 보유분은 5·6번에 남음 (계정 단위)
- 1~4번과 통합 결제로 공유받던 RI 가 있다면 인계 후 5·6번 RI 가용성 변동 — 파트너에게 확인

### AWS Marketplace 구독·SES verified identity·Route 53
- 5·6번 root 이메일로 알림 가는 항목들 — 이메일 변경 안 하므로 영향 없음
- 단, Marketplace 구독 시 사용자 개인 이메일이 연락처로 들어가 있으면 변경 필요

### 1번 → 5·6번 Trust 정리 시 자기 잠금 주의
- Phase 3 작업을 1번 IAM user 로 5·6번에 들어가서 진행하는 경우, Role 삭제·Trust 끊기 직후 본인이 즉시 5·6번에서 튕겨나감 (정상)
- 만약 추가 확인 작업 남아있으면 root 로 들어가야 함 — 그런데 Phase 2 에서 root 비밀번호 바뀜 → 들어갈 수 없음
- **Phase 3 시작 전에 5·6번에서 할 일을 모두 끝낸 상태**여야 함

### 파트너사(MSP) 결제 분리 시점
- "회사별 구분 처리" 가 파트너 시스템 레벨인지 AWS Organization 레벨인지 사용자 확정 필요
- 만약 같은 Organization 멤버였다면 인계 직후 결제 정산 영향 가능 — 파트너에게 5/26 인계 시점 통보

### 도큐 trail 누락
- 인계 사실을 dlt-partners 측에 공식 문서로 통보 (이메일·계약 문서)
- 향후 사용자가 5·6번에 일절 접근하지 않음을 양측 합의 (문서화)

---

## 검증 체크리스트 (인계 완료 판정)

5·6번 각각에 대해 다음 모두 만족하면 인계 완료:

- [ ] Root 비밀번호를 dlt-partners 담당자만 알고 있음 (사용자는 모름)
- [ ] Root MFA 디바이스가 dlt-partners 담당자 디바이스로 교체 완료, 사용자 디바이스 해제됨
- [ ] Alternate contacts (Billing/Operations/Security) 모두 dlt-partners 측
- [ ] 5·6번에 1번 계정 ARN을 신뢰하는 Role 모두 제거 또는 trust principal 변경
- [ ] (있었다면) 사용자 IAM user 삭제 + Access Key 비활성·삭제
- [ ] CloudTrail 에서 1번 → 5·6번 AssumeRole 이벤트 0건 (5/27 정오 이후 점검)
- [ ] 신 MFA 로 실제 root 로그인 검증 완료 (담당자가 1회 수행)
- [ ] 사용자 브라우저 역할 전환 이력·즐겨찾기에서 5·6번 항목 제거

---

## 진행 로그

- 2026-05-29 (금) — ✅ **완료 처리** (사용자 5/29 확정). 5/28 담당자 MFA 인계를 본 TODO 의 완료 시점으로 확정. ⚠ 잔여 보안 격리 단계(root 비밀번호 변경·사용자 MFA 제거·Alternate contacts·1번 신뢰 Role 정리·CloudTrail 검증)는 PMI 종료 후 재개 — 본 TODO 종료, 재개 필요 시 신규 TODO 또는 TODO-033(비트윈 인프라 의존성)과 연계. TODO.md 완료 섹션 이동.
- 2026-05-28 (목) — **인계 작업 실행. 담당자와 함께 MFA 추가 등록 완료** (Phase 2 step 4 핵심 단계). 담당자 디바이스 MFA 가 root 에 등록됨. ⚠ 후속 단계 (사용자 MFA 제거 / 비밀번호 변경 / Alternate contacts / Phase 3 신뢰 Role 정리 / Phase 4 CloudTrail 검증) 진행 여부 확인 필요 — 사용자 MFA 제거·신뢰 Role 정리까지 완료돼야 보안 격리 성립. 5번·6번 각각 적용 범위 확인 필요.

- 2026-05-27 (수) — **작업일 5/28 (목) 오전/오후로 확정** (담당자 가용 시간대 반영). 5/26 (월) 작업 예정에서 2일 연기. 마감 5/29 (금) 유지로 검증 윈도우가 1일로 압축됨 — 5/29 정오 이후 CloudTrail 점검 + 잔여 정리. 슬립 발생 시 6/1 (월) 까지 연장 옵션 보유. 사용자에게 **5/28 화상회의 시간 + 1Password Share 채널 + Authenticator entry 라벨 정리 (5/27 중)** 3가지 사전 준비 안내.

- 2026-05-25 (월) — 메가존 점검사항 회신 수신 (이시연 총괄 + 안성진 SA):
  - **이메일 변경 자체**: 간단, 예상 이슈 없음 (기존 가이드 일치). 변경 적용 최대 4시간 소요 가능, 신 이메일 사전 수신 테스트 권장
  - **Alternate contacts**: 결제·보안 안내 수신을 위해 동시 갱신 필요 (기존 절차에 이미 포함)
  - **비트윈 측 IAM Role Trust Policy**: Principal 에 `thingsflowmaster (982154780443)` 있으면 제거. Role 삭제 vs Principal 만 제거 옵션 존재
  - **CLI/SDK · CI/CD Pipeline**: AssumeRole 흐름 점검 필요 (별도 파이프라인 없으면 패스)
  - **⚠ VPN · Bastion · AD/ADFS 가 thingsflowmaster (1번) 에 구성**: 5·6번이 1번 인프라에 의존할 가능성 — 단순 IAM 정리로 끝나지 않음. AD/ADFS 내용 메가존도 모르므로 딜라이트룸 (비트윈) 측과 별도 논의 권장
  - **Bastion 대안**: EC2 Session Manager 또는 별도 Client VPN 구성 (장기 옵션)
  - **🆕 Cross Account 공유 리소스 인벤토리 신규 과업**: S3 Bucket Policy / KMS Key Policy / Secret Manager / ECR 등 상대 계정 ARN 참조 조사 필요
  - 단독 진행 전제 부분 재검토: 인프라 (VPN/Bastion/AD/ADFS) 영역은 단독 진행 어려움 — 딜라이트룸 협의 항목으로 분리 필요
  - 참조 링크:
    - 루트 사용자 이메일 업데이트: https://docs.aws.amazon.com/ko_kr/accounts/latest/reference/manage-acct-update-root-user-email.html
    - 대체 연락처 이메일 업데이트: https://docs.aws.amazon.com/ko_kr/accounts/latest/reference/manage-acct-update-contact-alternate.html

- 2026-05-22 — TODO 등록. 사용자와 5/22 1차 가이드 합의:
  - 5·6번 이메일 변경 안 함 (담당자에게 정보 전달)
  - 5·6번 IAM user 직접 등록 없음 (cross-account role 방식)
  - 인계 담당자 정해짐, 파트너사(MSP) 통보 완료
  - 작업일 5/26, 마감 5/29 합의
  - TODO-031 (1~4번 이전) 의 선행 조건으로 본 TODO 우선 진행
