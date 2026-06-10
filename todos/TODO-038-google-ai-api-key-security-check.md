# TODO-038 Google AI API 키 보안 점검

**유형**: 액션
**상태**: 진행 중
**등록**: 2026-05-27
**시작**: -
**완료**: -
**마감**: -
**담당**: 사용자 직접 (GCP Console) + 코디네이터 (점검 지원)
**관련**: [projects/20260518-gcp-ai-project-migration/](projects/20260518-gcp-ai-project-migration/migration-audit.md)

## 컨텍스트

2026-05-27 GCP AI 프로젝트 마이그레이션 (TODO-018) 완료 후 도출된 후속 보안 과업.

마이그레이션한 8개 프로젝트 중 일부 API 키에 도메인/IP/HTTP 레퍼러 제한이 없어 외부 오용 위험이 있음. `ai-rule-auto-gen-test-hshan`은 4/29 이상비용 이력이 있으며 이미 IP 제한 적용 완료. 나머지 키들의 보안 상태를 점검하고 필요한 제한을 추가한다.

### 마이그레이션 대상 프로젝트 API 키 현황 (2026-05-27 기준)

| 프로젝트 | API Key | 현재 제한 | 추가 필요 |
|---------|---------|---------|---------|
| `ai-project-454009` (studio AI) | "Generative Language API Key" 1개 | API target만 (`generativelanguage.googleapis.com`) | ⚠ **HTTP 레퍼러 제한 추가 필요** (studio-web 도메인) |
| `gen-lang-client-0403158203` (llm-prod) | "base-key" 1개 | API target만 | ⚠ 점검 필요 (hellobot-server IP 또는 대안) |
| `gen-lang-client-0170471706` (llm-dev) | 1개 | 확인 필요 | 점검 |
| `gen-lang-client-0465592155` (compatibility-ai) | 1개 | 확인 필요 | 점검 |
| `gen-lang-client-0605251657` (compatibility-api) | 1개 | 확인 필요 | 점검 |
| `ai-rule-auto-gen-test-hshan` | 2개 | ✅ IP 제한 (`1.234.131.174/32`) + APP_RESTR | 완료 |
| `gen-lang-client-0627053898` | 1개 | Billing OFF, 미사용 | - |
| `automation-466602` | 없음 | - | - |

## 현재 상태

TODO-018 완료와 동시에 등록. 아직 시작 전.

`ai-project-454009` API key는 studio-web 프론트엔드에서 `contentGenGeminiApiKey`로 직접 사용하므로 HTTP 레퍼러 제한이 적합하다 (브라우저 호출 → referrer 고정). 운영 도메인 목록은 `hellobot-studio-web/src/environments/` 환경 파일에서 확인 가능.

`gen-lang-client-0403158203` (llm-prod)은 hellobot-server 서버 측에서 호출하므로 HTTP 레퍼러 방식은 부적합 → 서버 IP 제한 또는 서버 측 인증(SA key 방식 전환) 검토 필요.

## 다음 단계

- [ ] **T-1. ai-project-454009 API key HTTP 레퍼러 제한 추가**
  - 대상 도메인 확인: hellobot-studio-web 운영/스테이징 도메인 목록 (`hellobotstudio.com`, `jp.hellobotstudio.com` 등)
  - GCP Console > AI-project > API Keys > Generative Language API Key > HTTP 레퍼러(웹사이트) 제한 추가
  - 적용 후 studio-web AI 텍스트 생성 기능 정상 확인

- [ ] **T-2. gen-lang-client-0403158203 (llm-prod) API key 보안 방식 결정**
  - 서버 호출이므로 HTTP 레퍼러 부적합
  - 옵션 A: hellobot-server 운영 서버 고정 IP 제한 (IP 화이트리스트)
  - 옵션 B: SA key 방식으로 전환 (코드 변경 필요)
  - 옵션 C: 현재 API target 제한만 유지 (Gemini 외 다른 API 호출 불가 — 최소 보호)
  - 사용자/개발팀 결정 후 적용

- [ ] **T-3. 나머지 3개 프로젝트 API 키 현황 점검**
  - `gen-lang-client-0170471706` (llm-dev), `gen-lang-client-0465592155` (compatibility-ai), `gen-lang-client-0605251657` (compatibility-api)
  - 각 키의 현재 제한 확인 후 필요시 추가

## 진행 로그

- **2026-05-27**: TODO-018 (GCP AI 마이그레이션) 완료 후 후속 보안 과업으로 등록. 사용자 요청으로 TODO-018의 잔여 항목 `ai-project-454009 API key 도메인/HTTP 레퍼러 제한 추가`를 본 TODO의 T-1 태스크로 등록.
