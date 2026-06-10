# TODO-033 비트윈 인프라 의존성 인벤토리·정리 (딜라이트룸 협의)

**유형**: 액션
**상태**: 진행 중 (TODO-030 에서 분리, 딜라이트룸 협의 시작 단계)
**등록**: 2026-05-25
**시작**: 2026-05-25
**완료**: -
**마감**: 미정 (TODO-030 5/29 마감과 독립 운영, 6월 초~중순 목표)
**중요도**: ⭐⭐⭐ 최상 (TODO-030 의 핵심 차단 요소를 흡수했으므로 인프라 우선순위 그대로 승계)
**담당**: 사용자 직접 + 딜라이트룸 (비트윈) 측 인프라 담당자
**관련**: [[TODO-030-aws-account-5-6-handover-dlt]] (원천), [[TODO-031-aws-account-1-4-migration-neuralarcade]] (1번 메타데이터 변경은 영향 없음)

---

## 컨텍스트

### 분리 배경 (2026-05-25)
메가존 (안성진 SA) 회신에서 비트윈(AWS 5·6번) 인계 작업의 단독 진행을 어렵게 만드는 인프라 의존성이 식별됨:

> "이전에 딜라이트룸과 논의하였을 때, VPN 및 Bastion 그리고 AD/ADFS 서버가 thingsflowmaster 에 구성되어 있는 것으로 알고있습니다. AD/ADFS 에 어떤 내용이 담겨있는지 제가 정확하게 인지를 하고있지 못하여 사이드 이펙트를 안내드리기 제한적인 점 양해 부탁드리오며 담당자와 이부분은 별도로 논의해보셔도 좋을 것 같습니다."

- **thingsflowmaster** = 1번 계정 (neuralarcade.ai 측 이전 대상)
- 비트윈 5·6번이 1번 인프라 (VPN/Bastion/AD/ADFS) 를 인증·접속 경로로 의존할 가능성
- 잘못 끊으면 비트윈 측 운영자 접속 불가·서비스 영향 위험

### TODO-030 (원천) 과의 관계
- TODO-030 의 root 자격·MFA·이메일 영역은 **단독 진행 가능** (그대로 5/26 윈도우 내 진행)
- TODO-030 의 1번 → 5·6번 Trust 정리 + 인프라 의존성 정리 = **본 TODO 로 분리**
- TODO-030 마감 5/29 는 root 영역만 기준으로 판정. 인프라 정리는 본 TODO 가 흡수

### 사용자 입장
- 사용자(소속 이전 후 neuralarcade.ai 측)는 5·6번에 일절 접근 권한 없는 상태가 최종 목표
- 그러나 인프라 의존성을 끊지 않으면 비트윈 측이 운영 못 함 → 단계적 정리 필요
- 딜라이트룸 측 인프라 담당자 컨택 채널 보유 (사용자 확인 2026-05-25)

---

## 현재 상태

**2026-05-25 (월) — 인벤토리 시작 단계**.

선결 조건:
- ✅ 딜라이트룸 컨택 채널 확보 (사용자 확인)
- ⏳ 1번 콘솔에서 인프라 의존성 인벤토리 작성 미시작
- ⏳ 딜라이트룸 측에 인계 작업 일정·영향 사전 통보 미발신

차단 요소:
- AD/ADFS 내용 불명 (메가존도 정확히 모름) → 딜라이트룸 측 답변 필수
- VPN/Bastion 의 5·6번에서의 사용 패턴 (운영자 SSH 등) 확인 필요

---

## 다음 단계

### 1주차 (5/26~5/29) — 인벤토리 + 협의 시작

#### 단독 진행 (사용자, 1번 콘솔 조사)
- [ ] **VPN 인벤토리**: 1번에서 운영 중인 VPN 서버 식별 (EC2 인스턴스·Client VPN endpoint·Site-to-Site VPN)
  - 인스턴스 ID·역할·연결 대상 (5·6번 VPC 와 peering 여부)
- [ ] **Bastion 인벤토리**: 1번에서 운영 중인 Bastion 호스트
  - 인스턴스 ID·SG·접속 가능 IP·5·6번 운영자가 사용 중인지 확인 경로
- [ ] **AD/ADFS 인벤토리**: 1번에서 운영 중인 AD/ADFS 서버
  - 인스턴스 ID·도메인·연동 서비스
- [ ] **Cross Account 공유 리소스 인벤토리** (메가존 회신 4번 항목):
  - S3 Bucket Policy 에 5·6번 계정 ARN 참조 (또는 5·6번에서 1번 버킷 참조)
  - KMS Key Policy 의 cross-account principal
  - Secret Manager 공유 시크릿
  - ECR 리포지토리 cross-account pull 권한
- [ ] **CLI/SDK · CI/CD Pipeline 점검**: 1번 → 5·6번 AssumeRole 흐름 (현재 사용 중 가능성 낮음, 확인만)

#### 딜라이트룸 협의 (사용자 → 딜라이트룸 인프라 담당자)
- [ ] 인계 작업 일정·영향 사전 통보 (1차 메일·메신저)
- [ ] AD/ADFS 운영 현황 질의:
  - 5·6번 운영자 사용자 인증을 1번 ADFS 가 처리하는지
  - 끊으면 영향받는 운영자·시스템 범위
  - 비트윈 측 자체 ADFS 이전 계획 유무
- [ ] VPN/Bastion 현재 사용 패턴 질의:
  - 비트윈 측 어떤 운영자가 어떤 경로로 사용 중인지
  - 비트윈 측 자체 Bastion·VPN 으로 대체 계획 유무
- [ ] **정리 일정 합의**: 단계별 끊기 일정 (인벤토리 후 합의)

### 2주차 이후 (6월) — 단계적 정리

비트윈 측 대체 인프라 준비 일정에 맞춰 진행:
- [ ] 비트윈 측 자체 VPN·Bastion·ADFS 준비 완료 통보 수신
- [ ] 1번 → 5·6번 IAM Role Trust Policy 의 Principal `thingsflowmaster(982154780443)` 제거
- [ ] Cross Account 공유 리소스 (S3/KMS/Secret/ECR) Policy 정리
- [ ] 1번 VPN/Bastion/ADFS 에서 5·6번 운영자 접근 차단
- [ ] CloudTrail 에서 1번 → 5·6번 AssumeRole 이벤트 0건 확인
- [ ] (선택) IAM Access Analyzer 로 외부 신뢰 잔존 점검
- [ ] 비트윈 측에 차단 완료 통보

---

## 작업 절차 상세

### Phase A — 인벤토리 (1번 콘솔)

#### VPN
```
1. VPC → Client VPN Endpoints → 1번 활성 endpoint 확인
2. VPC → Site-to-Site VPN Connections → 1번 활성 VPN connection 확인
3. EC2 → Instances → "vpn" 태그·이름 검색
4. VPC → VPC Peering Connections → 1번 ↔ 5·6번 VPC peering 확인
```

#### Bastion
```
1. EC2 → Instances → "bastion" 태그·이름 검색
2. SG 의 inbound rule 확인 (운영자 IP 대역)
3. CloudTrail → ConsoleLogin·SSH key 사용 패턴
```

#### AD/ADFS
```
1. EC2 → Instances → "ad", "adfs", "directory" 태그·이름
2. Directory Service → Directories
3. 연동된 서비스 (RDS·WorkSpaces·SSO 등) 확인
```

#### Cross Account 공유 리소스
```
- S3 → Bucket → Permissions → Bucket Policy 검색 ("982154780443" 또는 5·6번 ID)
- KMS → Keys → Key policy 의 Principal
- Secrets Manager → Secret → Resource policy
- ECR → Repository → Permissions
```

### Phase B — 딜라이트룸 협의 메일 템플릿 (1차 발신)

```
제목: [협의 요청] 비트윈 AWS 인프라 의존성 인계 일정

안녕하세요, [딜라이트룸 담당자명]님

소속 이전 (dlt-partners.com → neuralarcade.ai) 일환으로 AWS 6개 계정 중
1~4번을 neuralarcade.ai 측으로 이전하고, 5·6번 (비트윈) 은 dlt-partners 측에
인계하는 작업을 진행 중입니다.

메가존 측 안내에서 다음 인프라가 1번 (thingsflowmaster) 에 구성되어
비트윈 측 운영에 영향이 있을 수 있다는 점이 식별되어 협의 드립니다:

- VPN
- Bastion
- AD/ADFS

질의 사항:
1. 비트윈 측 운영자 사용자 인증이 1번 ADFS 를 통하나요? 통한다면 영향 범위는?
2. 비트윈 측 VPN·Bastion 접속이 1번 인프라 경유인가요?
3. 비트윈 측 자체 인프라 대체 계획·일정이 있나요?
4. 인계 일정 합의 가능한 시점은?

저는 1번 콘솔에서 인벤토리 작성 중이며, 결과 공유 가능합니다.
회신 부탁드립니다.

감사합니다.
```

### Phase C — 단계적 정리 (협의 후)

비트윈 측 대체 인프라 준비 완료 후:
1. Cross Account 공유 리소스 Policy 부터 정리 (가장 안전)
2. IAM Role Trust Policy 의 Principal 제거 (1번 → 5·6번 AssumeRole 차단)
3. VPN·Bastion 의 5·6번 운영자 접근 차단
4. (마지막) AD/ADFS 영향 정리 — 비트윈 측 자체 인증 전환 후

---

## 함정·주의사항

### AD/ADFS 끊기 = 비트윈 운영자 로그인 불가 위험
- 비트윈 측이 AD/ADFS 로 SSO 받고 있으면 끊는 순간 전 운영자 로그인 불가
- 반드시 비트윈 측 대체 인증 전환 완료 통보 받고 차단

### VPN/Bastion 끊기 = 비트윈 측 운영 단절
- Bastion 경유로 5·6번 EC2·RDS 운영 중이면 끊으면 운영 못 함
- 비트윈 측 자체 Bastion·Session Manager 전환 완료 통보 받고 차단

### Cross Account 공유 리소스의 양방향
- 1번이 5·6번 ARN 을 참조: 1번 측에서 정리
- 5·6번이 1번 ARN 을 참조: 비트윈 측에서 정리
- 양쪽 다 인벤토리 + 협의 후 동시 정리

### TODO-030 마감과의 분리
- TODO-030 5/29 마감 = root 자격·MFA 영역만 판정
- 본 TODO 는 별도 마감으로 운영 (인프라 대체 일정에 따라 6월 초~중순 목표)

### 1번 이메일 변경 (TODO-031) 과의 무관성
- 1번 root 이메일 변경 = 메타데이터만 (Account → Email)
- 1번 리소스 ARN·VPC ID·인스턴스 ID 등 변경 없음 → 5·6번이 1번 리소스를 ARN 으로 참조하는 것에 영향 없음
- 따라서 TODO-031 (5/26 진행) 과 본 TODO 는 독립 운영 가능

---

## 검증 체크리스트 (정리 완료 판정)

- [ ] 5·6번에서 1번 VPN/Bastion 경유 접속 = 0건 (비트윈 측 대체 완료)
- [ ] 5·6번 운영자 사용자 인증 = 1번 AD/ADFS 비의존 (비트윈 측 자체 인증 전환 완료)
- [ ] 1번 → 5·6번 IAM Role Trust Policy Principal 모두 제거
- [ ] Cross Account 공유 리소스 Policy 양방향 정리
- [ ] CloudTrail 에서 1번 → 5·6번 AssumeRole 이벤트 0건 (정리 후 7일)
- [ ] IAM Access Analyzer 외부 신뢰 잔존 0건
- [ ] 비트윈 측에 차단 완료 공식 통보

---

## 진행 로그

- 2026-05-25 (월) — TODO 등록 (TODO-030 에서 분리):
  - 메가존 안성진 SA 회신 (5/25) 에서 비트윈 인프라 의존성 (VPN/Bastion/AD/ADFS) 식별
  - 사용자 결정 (5/25): TODO-030 본체는 root 영역만 단독 진행, 인프라 정리는 본 TODO 로 분리
  - 딜라이트룸 컨택 채널 사용자 보유 (사용자 확인 5/25)
  - 마감 미정 — 비트윈 측 대체 인프라 준비 일정에 종속, 6월 초~중순 목표
