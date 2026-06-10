# GCP Gemini 4/29 이상비용 — 조치 프로젝트

> 2026-04-29 자 GCP Gemini 관련 이상비용 발생 → 메가존소프트 조치 가이드라인 기반 대응 프로젝트.

## 배경

- **2026-04-29** — GCP 콘솔에서 Gemini 관련 이상비용 발생
- **2026-05-18** — 혁수님이 사용자에게 이슈 리포트
- **2026-05-18** — 파트너사 메가존소프트 김종현 대표님께 도움요청 + 관련 요청사항 전달
- **2026-05-19** — 메가존소프트로부터 **조치 가이드라인 수신** → 본 프로젝트로 승격, 가이드 기반 조치 실행

상위 추적: [TODO-017](../../todos/TODO-017-gcp-gemini-cost-anomaly.md) (프로젝트화 이후 본 readme 가 SSOT)

## 목표

1. 메가존소프트 가이드라인에 따라 **이상비용 원인 파악·차단** 조치 실행
2. **재발 방지 가드레일** 설정 (예산 알림·쿼터·결제 알람 등)
3. 청구 보정 가능 여부 협의·정산 (메가존 경로)

## 산출물 구조

```
projects/20260519-gcp-gemini-cost-mitigation/
├── readme.md                              ← 본 문서 (배경·목표·구조)
├── status.md                              ← 진행 상태
├── tasks.md                               ← 조치 과업 체크리스트 (가이드 기반)
└── planning/
    └── megazone-mitigation-guide/         ← 메가존 가이드 문서 + 스크립트
        ├── 0. 먼저 읽어 주세요.pdf
        ├── 1. Google API key checklist.pdf
        ├── 3. [점검이후] 보안강화를 위한 API 키 대체 인증 방식.pdf
        ├── 4. 강제 비활성화가 필요한 API 설명.pdf
        ├── 4. 사용하지 않는 firebase API 삭제.pdf
        ├── firebase_gemini_key_audit.sh
        └── 2026-05-21-api-key-security-checklist.md  ← 트랙 3 SSOT (메가존 추가 가이드)
```

## 미파악 항목 (가이드 수신 후 채울 것)

- 이상비용 정확한 금액·기간·발생 프로젝트
- 가이드라인의 구체적 조치 항목 갯수·난이도
- 스크립트 실행 환경 요구사항 (gcloud · BQ · 권한 등)
- 영향 범위 (운영 서비스 다운타임 / 데이터 손실 가능성)

## 관련 작업

- [TODO-017](../../todos/TODO-017-gcp-gemini-cost-anomaly.md) — 원천 이슈 (모니터링 → 본 프로젝트로 승격)
- [TODO-018](../../todos/TODO-018-gcp-ai-project-migration.md) — GCP AI 프로젝트 마이그레이션 (동일 GCP 흐름, 가드레일 통합 검토 가능)
- [TODO-005](../../todos/TODO-005-infra-contract-monitoring.md) — GCP 메가존 계약 (✅ 5/18 완료)

## 외부 채널

- **파트너사 메가존소프트 김종현 대표님** — 조치 가이드 제공·청구 보정 협의
- **혁수님** — 원천 이슈 리포터

## 담당 / 위임

- 사용자 (총괄·메가존 협업)
- 가이드 실행 단계에서 `/dev-infra` 또는 `/dev-server` 위임 가능
