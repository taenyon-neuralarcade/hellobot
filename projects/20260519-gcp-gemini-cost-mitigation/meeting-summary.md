# 4/29 GCP Gemini 사건 — 회의용 요약

> **2026-05-20 협의용** | 작성: 2026-05-19 Tony | 상세: [audit-tier1-report.md](audit-tier1-report.md)

---

## 🔍 사건의 정체 (Cloud Monitoring 추적 결과)

```
2026-04-24 ET 13:00 → abuser 가 점심시간에 stolen key 작동 확인 (28K 시도)
       4일 침묵 (자동화 도구 준비)
2026-04-29 ET 18:00 → 자동화 cron 첫 가동 (2시간, 102K 성공 호출) ★ 메인 사건
2026-05-02 ~ 5/11   → 작은 probe + 재시도
2026-05-12 ET 18:00 → 자동화 cron 재가동 (31K 시도, GCP 가 93% 자동 차단)
2026-05-12 KST 13:33 → 혁수님이 key 2 IP 제한 추가
2026-05-15           → 혁수님이 key 1 도 IP 제한 → 완전 차단
2026-05-18           → 혁수님이 Tony 에게 리포트
```

### 핵심 단서

| 단서 | 내용 |
|---|---|
| **abuser 정체** | 자동화된 봇 (사람 아님) — 14 calls/sec 지속 |
| **abuser 시간대** | 미국 동부(UTC-4 DST) 거의 확실 — ET 18:00 cron 가동 |
| **유출 키** | 두 키 모두 abuser 손에 — 한 키 막히니 다른 키로 전환 |
| **GCP throttling** | 5/12 시도의 93% 차단해서 추가 피해 막음 |
| **결제된 호출** | 122K (이 중 102K가 4/29) |
| **추정 비용** | $40 ~ $2,000 (모델·토큰에 따라. 정확한 건 Billing 확인) |
| **IP 제한 설정자** | 혁수님 본인 (확인 완료) |

---

## 🚨 더 큰 발견 — 다른 프로젝트에 더 위험한 키들

audit 결과 **위험 키 10개** 발견:

```
🚨 CRITICAL  ai-product-417102 의 두 키          (LEGACY + 완전 무제한 — 4/29 키보다 위험)
🟠 HIGH      hellobot-llm-prod 키                 (운영 LLM)
🟠 HIGH      hellobot-llm-dev 키
🟠 HIGH      compatibility-ai 키
🟠 HIGH      compatibility-api 키
🟠 HIGH      AI-project 키
🟠 HIGH      Gemini API (gen-lang-client-0627) 키
🟠 HIGH      ai-rule-auto-gen-test-hshan 두 키    (4/29 사건 키, IP 제한 완료)
```

**공통 패턴**: 모두 APP_RESTR=NONE (IP/referrer 제한 없음). 키 값만 알면 어디서나 호출 가능.

**거버넌스 신호**: 5개 키가 `gen-lang-client-*` 패턴 = AI Studio 에서 즉석 발급 흔적. 정식 거버넌스 우회.

---

## 🗓 내일 결정해야 할 4가지

### 1. `ai-rule-auto-gen-test-hshan` 두 키 처리 (혁수님 합의)

```
A. 즉시 삭제 (권장)    — abuser 키 값 보유, 재시도 차단
B. 한 키만 삭제
C. 둘 다 유지 + ADC 전환 (시간 더 걸림)
```

### 2. 다른 위험 키 8개 사용처 파악 분담

```
누가 ai-product-417102 (CRITICAL) 확인?
누가 hellobot-llm-prod·dev 확인?
누가 compatibility-ai·api 확인?
누가 AI-project·Gemini API 확인?
```

### 3. 메가존 요청 사항 확정

```
- 4/29 기간 일별 SKU 비용 명세 요청
- 청구 보정 가능성 협의 (abuse 명확)
- 6개 위험 프로젝트 예산 알림 $50 설정
- Data Access Logs 활성화 (선택)
```

### 4. 거버넌스 방향

```
- AI Studio 즉석 키 발급 금지?
- 신규 키 발급 시 APP_RESTR 필수 절차?
- 정기 audit 자동화?
- ADC/Secret Manager 단계적 전환?
```

---

## 📊 한 페이지 숫자 요약

```
245   organization 의 GCP 프로젝트 수
  8   Tier 1 점검 대상 (AI/Gemini 관련)
 10   발견된 위험 키 (CRITICAL 2 + HIGH 8)

4/29 사건 (단일 일자):
  102K 성공 Gemini 호출
   17K GCP 가 자동 차단
   ~2h  공격 지속 시간
  ~14   sec 당 호출 (자동화 봇 증거)

전체 abuse 기간 (4/24 ~ 5/14):
  122K 총 성공 호출 (4/29 가 83%)
   72K GCP 자동 차단 (37%)
$40~$2K 추정 비용 (정확한 건 Billing 필수)
```
