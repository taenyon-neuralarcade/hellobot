---
name: todo-020-hellobot-duo-account-separation
description: "[비트윈 분리] 헬로우봇 Duo 계정 분리 — 뉴럴아케이드 Duo 신규 테넌트로 bastion 2대 이관, 5/22 마감"
metadata:
  type: action
---

# TODO-020 [비트윈 분리] 헬로우봇 Duo 계정 분리

**유형**: 액션 (인프라 작업)
**상태**: ✅ 완료 (2026-05-28) — bastion 2대 + OpenVPN 신규 테넌트 전환 + 멤버 접속 확인 + 구 Duo 정리 완료
**등록**: 2026-05-19
**시작**: 2026-05-22
**완료**: 2026-05-28
**마감**: **2026-05-26 (월)** — 5/28 전체 완료 (OpenVPN 스코프 정정분 포함)
**담당**: 사용자 (총괄) → `/dev-infra` 보조
**관련**: [[todo-007-bitwin-infra-separation]] (umbrella — DLT 비트윈 인프라 분리)

## 컨텍스트

5/19 DLT align 미팅 결정 사항. 현재 비트윈과 공유 중인 **Duo (2FA / Multi-Factor Authentication) 계정을 헬로우봇(뉴럴아케이드) 측으로 분리**.

### 작업 범위 (확정, 2026-05-22)

1. **Duo 신규 가입** — 뉴럴아케이드 명의 Duo 테넌트 신규 개설
2. **현재와 동일한 구성 세팅** — Unix Application 2개(bastion / db bastion) + 사용자/정책 복제
3. **헬로우봇 인프라 마이그레이션** — bastion 2대의 Duo 통합을 신규 테넌트로 전환

### 영향 범위 (조사 완료, 2026-05-22)

| 시스템 | 현재 Duo 사용 방식 | 신규 테넌트 이관 필요? |
|---|---|---|
| **AWS Console MFA** | **A3 — IAM User Virtual MFA (TOTP)**. Duo Mobile 앱을 단순 OTP authenticator로 사용. Duo 테넌트와 연동되지 않음 | ❌ 불필요 (Duo Mobile 앱은 그대로, IAM Virtual MFA 시크릿도 그대로 유지) |
| **일반 bastion (SSH)** | Duo Unix (`pam_duo.so`). `/etc/duo/pam_duo.conf` 에 `ikey`/`skey`/`host` | ✅ **완료 (5/26)** |
| **DB bastion (SSH)** | 동일 (Duo Unix) | ✅ **완료 (5/26)** |
| **OpenVPN** ⚠ | 🆕 **스코프 정정 (5/26 실행 중 발견)** — Duo Auth Proxy(RADIUS) 또는 Duo OpenVPN 플러그인. ikey/skey/host(api_host) 보유 | ✅ **필요 (진행 중)** |

> AWS Console은 Duo "서비스 연동"이 아니라 Duo Mobile을 TOTP 앱으로만 쓰는 케이스라 신규 테넌트 이관 대상이 아님.
> ⚠ **OpenVPN 은 5/22 초기 영향 범위 분석에서 누락**. 5/26 실행 단계에서 추가 식별. 신규 테넌트에 OpenVPN(또는 RADIUS)용 Application 별도 생성 필요 — bastion Unix Application 재사용 불가.

### 미파악 항목 (Phase 2 진입 전 확정 필요)

- [x] 신규 Duo 플랜 결정 — **Free 플랜** (사용자 ≤10명, bastion만 보호). 정책·감사 요구 생기면 후속 업그레이드
- [x] 헬로우봇 측에서 신규 테넌트에 등록할 사용자 명단 — 5/26 확정 및 등록 완료
- [ ] 각 bastion 의 정확한 통합 방식 (`pam_duo` vs `login_duo`) + 현재 `host` 값(테넌트 식별자) — conf 교체 시점에 백업과 함께 캡처
- [ ] 각 bastion 의 `failmode` 현 설정 (safe vs secure) — 동상
- [ ] **Administrator vs User 등록 확인** — Admin 으로만 추가했는지 별도 User 등록까지 했는지. bastion 인증은 User 등록 필수 (Linux username 매칭)

## 현재 상태

- Phase 1 (현황 파악) — **완료**. 대상이 bastion 2대로 확정. AWS Console MFA는 A3 (이관 대상 아님).
- Phase 2 (신규 가입) — **완료** (2026-05-22). 뉴럴아케이드 명의 Duo 신규 테넌트 개설. **Free 플랜 선택**.
- Phase 3 (Application 생성) — **완료** (2026-05-22). 대상 Application 2개 생성.
- Phase 4 (실행) — **진행 중** (5/26).
  - (3) User 등록·Activation — **완료**. ⚠ Administrator 와 User 가 별개 entity 이므로 Duo Admin Panel → Users 메뉴에서 bastion 접속자가 모두 등록·Active 상태인지 conf 교체 직전 재확인 필요.
  - (4) 권한 그룹 추가 — User 등록·Application 정책 점검과 함께 진행됨 (Free 플랜은 그룹·정책 옵션 단순).
  - (5) bastion 인증 업데이트 — **다음 단계**. 일반 bastion → DB bastion 순.
  - (6) 정상 접속 확인 후 구 Duo 권한 제거 — 미진행.
- bastion 서버 내 `/etc/duo/` 관련 설정 사용자가 직접 확인 완료. 정확한 통합 방식(pam_duo/login_duo)·기존 host 값은 5/26 conf 교체 시점에 백업과 함께 캡처.

## 다음 단계

### Phase 1 — 현황 파악 (✅ 완료, 2026-05-22)

- [x] 현재 Duo 테넌트의 헬로우봇 측 사용자·연동 시스템 인벤토리 작성 — bastion 2대로 확정
- [x] AWS Console MFA 방식 식별 — A3 (Virtual MFA), 이관 대상 아님

### Phase 2 — 신규 Duo 테넌트 가입 (✅ 완료, 2026-05-22)

- [x] **duo.com 에서 뉴럴아케이드 명의 신규 가입** → Admin 계정·API hostname 발급
- [x] Admin 정책 기본 설정
- [x] 본인 User 등록 + Duo Mobile 디바이스 enrollment

### Phase 3 — Application 생성 (✅ 완료, 2026-05-22)

- [x] 대상 Application 2개 생성 (bastion 용 / DB bastion 용)
- [x] 각 Application 의 `Integration key` / `Secret key` / `API hostname` 안전 보관

### Phase 4 — 실행 (📅 **5/26 (월) 일괄 진행 예정**)

> 사용자 정리 6단계 흐름:
> 1·2 = Phase 2·3 에서 완료. 아래 3~6 을 5/26 일괄 실행.

#### (3) 이전 대상 멤버들 신규 테넌트 User 등록 — ✅ 완료 (5/26)

- [x] 이전 대상 멤버 명단 확정 (본인 외 bastion 사용자)
- [x] 각 멤버를 신규 Duo 테넌트에 User 로 등록
- [x] 각 멤버에게 enrollment 링크 발송 → Duo Mobile 디바이스 등록 완료 모니터링
- [x] **이 단계에서는 기존 Duo 권한 유지** — 병행 운영 (bastion 접속 끊김 없음)
- [x] ⚠ **conf 교체 직전 재확인**: 인증 필요한 사용자 전원 enrollment 완료 (5/26). Users 메뉴 Active·device 등록 확인 완료

#### (4) 이전 대상 멤버들 권한 그룹 추가 — ✅ 완료 (5/26)

- [x] 신규 테넌트에 그룹 부여 (Application 의 접근 정책에 맞춰) — Free 플랜 기본 정책 사용
- [x] 그룹 단위 정책 점검 (Push/TOTP 허용 등)

#### (5) bastion 서버 인증 업데이트 — 5/26

> ⚠ **이 단계 완료 시점부터 기존 Duo 로는 접속 불가**. (3)·(4) 가 모든 대상 멤버에 대해 완료된 것을 확인 후 진행.

##### 5-1. 일반 bastion (`mst-p-apn2c-bastion`) — ✅ 완료 (5/26)

- [x] 기존 `/etc/duo/pam_duo.conf` **백업** (`pam_duo.conf.bak.20260526`)
- [x] `failmode` 이미 `safe` — 변경 불필요
- [x] `ikey` / `skey` / `host` 를 신규 테넌트(일반 bastion Application) 값으로 교체
- [x] **기존 SSH 세션 유지** + **새 SSH 세션으로 검증** — 신규 Duo Push 수신 확인
- [x] **거부 테스트** — Push Deny 시 로그인 거부 확인 (`auth sufficient pam_duo.so` 우회 없음 검증)

##### 5-2. DB bastion — ✅ 완료 (5/26)

- [x] 사전 확인 → 백업 → 신규 테넌트 DB bastion Application 값으로 교체 → 새 세션 검증 → 거부 테스트 통과

##### 5-3. OpenVPN ⚠ — 📅 진행 중 (5/26, 스코프 정정)

- [ ] 통합 방식 식별 — Duo Auth Proxy(RADIUS, `authproxy.cfg`) vs OpenVPN 플러그인(`/etc/openvpn/` 내 `plugin ... duo`)
- [ ] 신규 테넌트에 OpenVPN/RADIUS용 Application 생성 (bastion Unix Application 재사용 불가)
- [ ] 현재 설정 백업 (`authproxy.cfg.bak.20260526` 또는 server.conf)
- [ ] `ikey` / `skey` / `api_host`(host) 신규 값으로 교체
- [ ] 서비스 재시작 (Auth Proxy: `authproxyctl restart` / 플러그인: openvpn 재시작 — 연결 중 클라이언트 끊김 주의)
- [ ] 신규 VPN 연결 테스트 — 신규 테넌트 Push 수신 확인 + 거부 테스트
- [ ] 롤백 경로 확보 (백업 복원 + 재시작)

#### (6) 멤버 접속 확인 → 기존 Duo 정리 — ⚠ ①②(OpenVPN+멤버 확인) 완료 후

- [ ] 본인 + 대상 멤버 전원이 신규 Duo 로 **양 bastion + OpenVPN** 정상 접속 확인
- [ ] **기존 Duo 테넌트에서 헬로우봇 분 권한·Application 제거** (병행 운영 종료)
- [ ] (선택) 구 Duo Application 자체 삭제 — hotfix 윈도우 1~2주 후
- [ ] 본 TODO 완료 → TODO-007 진행 로그에 cross-link

### 잔여 (Phase 4 완료 후)

- [ ] AWS Console A3 사용자는 별도 액션 없음 (Duo Mobile TOTP 그대로)
- [ ] (선택) 기존 Duo 테넌트의 헬로우봇 Application 자체 삭제 — hotfix 윈도우 1~2주 후

---

## 마이그레이션 가이드

### 신규 Duo 플랜 비교 (2026 기준)

| 플랜 | 가격 | 사용자 한도 | 본 과업에 충분? |
|---|---|---|---|
| **Free** | $0 | 10명 | bastion만 보호하고 사용자 ≤10명이면 OK |
| **Essentials** | $3/user/월 | 무제한 | Policy(Geo/Device trust 등) 필요 시 |
| **Advantage** | $6/user/월 | 무제한 | Risk-Based, Trust Monitor 필요 시 |
| **Premier** | $9/user/월 | 무제한 | VPN-less, Remembered Devices 등 풀스택 |

> bastion 2대만 보호하고 사용자가 10명 이하면 **Free** 로 시작 가능. 정책·감사 요구가 생기면 후속 업그레이드.

### Duo Unix conf 파일 (참고)

`pam_duo` 방식이라면:

```ini
# /etc/duo/pam_duo.conf
[duo]
ikey = <신규 테넌트의 Integration Key>
skey = <신규 테넌트의 Secret Key>
host = api-XXXXXXXX.duosecurity.com   # 신규 테넌트 API hostname
failmode = safe                        # 마이그레이션 중 일시적으로
pushinfo = yes
```

`login_duo` 방식이라면 동일 키들이 `/etc/duo/login_duo.conf` 에 있음.

### 안전 패턴 (필수)

| 패턴 | 이유 |
|---|---|
| **기존 SSH 세션 유지 + 새 세션으로 검증** | conf 교체 후 잘못된 값이면 새 세션부터 잠김. 기존 세션이 살아있어야 롤백 가능 |
| **conf 파일 백업 필수** (`*.bak.YYYYMMDD`) | 한 줄 롤백 = `cp bak conf` |
| **failmode=safe 임시 적용** | Duo API 도달 실패 시 통과 — 잠금 방지. 검증 후 원복 |
| **한 대씩 점진 전환** | 일반 → DB. DB부터 하면 운영 사고 시 회복 경로 줄어듦 |
| **outbound HTTPS 가능 확인** | 신규 `host = api-XXXX.duosecurity.com` 으로 443 outbound. bastion SG/방화벽이 도달 가능해야 함 |
| **타팀원 전환 일정 조율** | conf 교체 순간부터 그 bastion 은 신규 테넌트만 인증. 신규 테넌트 미등록 사용자는 즉시 접속 불가 |

### 롤백 절차 (잠금 발생 시)

1. 기존 SSH 세션에서 `sudo cp /etc/duo/pam_duo.conf.bak.YYYYMMDD /etc/duo/pam_duo.conf`
2. (login_duo 방식만) `/etc/duo/login_duo.conf` 동일 복원
3. 즉시 새 세션으로 재검증
4. 원인 분석 후 재시도

### 사전 확인 명령 (양 bastion 각각)

```bash
# 정확한 통합 방식 식별 (pam_duo 또는 login_duo)
sudo ls -la /etc/duo/
sudo grep -E '^(host|ikey|failmode)' /etc/duo/pam_duo.conf /etc/duo/login_duo.conf 2>/dev/null

# PAM 호출 여부
sudo grep -n duo /etc/pam.d/sshd

# login_duo ForceCommand 여부
sudo grep -nE '^(ForceCommand|AuthenticationMethods)' /etc/ssh/sshd_config

# outbound 도달성(신규 host 결정 후)
curl -sI https://api-XXXXXXXX.duosecurity.com/ -o /dev/null -w '%{http_code}\n'
```

### AWS Console A3 — 별도 트랙 (액션 없음)

- 현재: IAM User → Security credentials → Virtual MFA (TOTP). Duo Mobile 앱이 TOTP 시크릿 보관 중
- 신규 Duo 테넌트와 무관 — Duo 서비스에 등록된 게 아님
- **이번 마이그레이션에서 건드리지 않음**. Duo Mobile 앱·IAM Virtual MFA 시크릿 모두 그대로 유지

## 진행 로그

- 2026-05-19 — TODO 등록. 5/19 DLT align 미팅 결정 사항 기반. 마감 5/22 (금) — 압축 일정 (4영업일)
- 2026-05-22 — 영향 범위 조사 완료. AWS Console = A3 (Virtual MFA, 이관 대상 아님), 실제 대상은 bastion·DB bastion 2대 (Duo Unix). 사용자가 bastion 내 `/etc/duo/` 설정 직접 확인. TODO 문서를 마이그레이션 실행 가이드로 정비. Phase 1 완료, Phase 2(신규 가입) 진입.
- 2026-05-22 — Phase 2 (뉴럴아케이드 명의 Duo 신규 테넌트 가입) · Phase 3 (대상 Application 2개 생성) 완료. Phase 4 (User 등록 → 권한 그룹 부여 → bastion 인증 업데이트 → 정상 접속 확인 → 구 Duo 권한 제거) 는 사용자 결정에 따라 **5/26 (월) 일괄 진행**. 마감 컬럼 5/22 → 5/26 갱신. 단계 (3)·(4) 동안 기존 Duo 권한 유지 (병행 운영), (5) 시점부터 구 Duo 접속 불가, (6) 정상 확인 후 구 Duo 권한 제거.
- 2026-05-26 — Phase 4 진행 중. **Free 플랜으로 결정**. (3) User 등록·Activation 완료, (4) 권한 그룹 부여 완료 (Free 플랜 기본 정책). 사용자 질문: "Administrator 로만 추가했는데 User 도 따로 등록해야 하는지" → 답변: **별개 entity**. Administrator = Admin Panel 접근권, User = SSH 인증 대상 (Linux username 매칭 필수). conf 교체 전 Users 메뉴에서 bastion 접속자 전원 Active·device 등록 여부 재확인 필요. (5) bastion conf 교체 단계 진입.
- 2026-05-26 — 인증 필요한 사용자 전원 enrollment 완료. **Phase 5 (bastion conf 교체) 사전 확인 단계 진입**. 다음: 일반 bastion 에서 사전 확인 명령 5개 실행(통합 방식 pam_duo/login_duo·host·failmode·PAM·outbound 도달성) → 결과 기반으로 백업→교체→새 세션 검증 진행.
- 2026-05-26 — 일반 bastion(`mst-p-apn2c-bastion`) 사전 확인 완료. **활성 통합 = `pam_duo.so` (PAM 방식)**, 편집 대상 = `/etc/duo/pam_duo.conf` 단일 (`login_duo.conf` 는 공란·미사용). 현재 구 테넌트 host=`api-cd87513d.duosecurity.com`, `failmode=safe` (이미 safe — 변경 불필요), `auth sufficient pam_duo.so` + `AuthenticationMethods publickey,keyboard-interactive`. ⚠ `sufficient` 라 로그인 성공 ≠ Duo 통과 → 검증 시 신규 테넌트 Push 수신 + 거부 테스트 필수. outbound 는 placeholder 로 301 (열림 확인, 실제 신규 host 재확인 권장). 다음: 백업→ikey/skey/host 교체→새 세션 검증→DB bastion 반복.
- 2026-05-26 — **일반 bastion 교체·검증 완료**. 백업(`pam_duo.conf.bak.20260526`) → 신규 테넌트 값 교체 → 새 세션 Push 수신 확인 → **거부 테스트 통과** (Deny 시 로그인 차단 확인). 일반 bastion 은 신규 테넌트로 전환 완료. **DB bastion 단계 진입** — 사전 확인부터 동일 절차, 단 신규 테넌트의 **DB bastion 용 Application** ikey/skey/host 사용 (일반과 다른 Application).
- 2026-05-26 — **bastion 2대 모두 교체·검증(거부 테스트 포함) 완료**. ⚠ **OpenVPN 이 Duo 사용 항목으로 추가 발견 — 5/22 초기 영향 범위 분석 누락분 스코프 정정**. 남은 작업 3건 확정: ① OpenVPN Duo 업데이트 (신규 테넌트에 OpenVPN/RADIUS Application 별도 생성 + 통합 설정 교체) → ② 멤버 전원 신규 Duo 접속 확인 (bastion 2대 + OpenVPN) → ③ ①·② 완료 후 구 Duo 권한·Application 정리. 구 정리는 ①·② 완료 전에는 진행 금지 (병행 운영 유지).
- 2026-05-28 — ✅ **완료** (사용자 5/28 확정). 남은 3건(OpenVPN Duo 신규 테넌트 Application 생성·설정 교체 → 멤버 전원 bastion 2대 + OpenVPN 신규 Duo 접속 확인 → 구 Duo 권한·Application 정리) 모두 처리. 헬로우봇 Duo 계정 비트윈에서 완전 분리. TODO-007 umbrella sub 완료. TODO.md 완료 섹션 이동.
