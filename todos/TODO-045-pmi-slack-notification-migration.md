# TODO-045 [PMI] Slack 알림 기능 이전

**유형**: 액션
**상태**: 진행 중 (실행 미착수 — 조사 완료)
**등록**: 2026-06-11
**시작**: -
**완료**: -
**마감**: -
**담당**: 코디네이터 (조사) → 사용자 (Slack 어드민 작업) + /dev-infra (시크릿) + /dev-server (코드)
**관련**: hellobot-server, common-infra-eks-deploy

## 컨텍스트

hellobot-server 의 Slack 운영 알림을 현 워크스페이스(A)에서 신규 워크스페이스(B)로 이전 (PMI).
2026-06-11 코드 조사 완료 — 아래는 그 결과 요약.

### 현재 구조

- **`SLACK_NOTIFICATION_URI`** = 레거시 incoming webhook URL. 유일한 소비처는 `notifyToSlack()` (`hellobot-server/src/common/util.ts:261`)
- **채널 라우팅은 URI가 아니라 웹훅 페이로드의 `channel` 필드**가 결정. 채널명 정의: `config.slack.channel` (`src/common/config.ts:657-668`) — `#chatops_hellobot_*` 등 **~10개 채널**:
  general / refund / ai_profile / subscription / studio_general / server / playground / skill_review / app_review / coupon
- 호출처 ~30곳: 환불(하트·구독·대화권), 쿠폰 발급 실패, 어뷰저 감지, 앱스토어·플레이스토어 리뷰, 스튜디오 예약 라챗반, 칫챗 타임아웃, AI 프로필, 트레이닝 프로젝트, cafe24 굿즈 등
- **별도 웹훅 1개 더**: `SLACK_AI_PROFILE_INSPECT_URL` (AI 프로필 검수용, `config.ts:654`)
- **멘션**: `<!subteam^S...>` 유저그룹 ID가 메시지 텍스트에 **하드코딩** (`training-project.ts:772,836,849` / `ai-profile.ts:359`). `config.slack.userGroupId` 객체는 어디서도 참조 안 함 (죽은 설정)
- **env 주입 위치 2곳 이상**:
  1. 메인 API 서버 — `/app/conf/.env.json` (시크릿 경유)
  2. K8s CronJob들 — AWS Secrets Manager `hlb/prod/cronjobs` (`common-infra-eks-deploy/overlays/hlb/prod/cronjobs/cronjobs-secrets-patch.yaml:27`). `COUPON_SLACK_NOTIFICATION_CHANNEL`(채널명 env)도 같은 시크릿에 있음

### 실패 모드 (조사 결과)

- `notifyToSlack` 전체가 try/catch — **어떤 실패도 장애로 이어지지 않음**. `winston.error("Slack notification failed...")` 로그만 남기고 **조용히 유실**
- 없는 채널로 발송 → Slack `channel_not_found` 404 → 알림 유실 (로그만)
- 없는 subteam ID 멘션 → 메시지는 정상 전송, 멘션만 미해석 (아무도 핑 안 받음)
- redisKey 디듀프는 **전송 전에** setex (`util.ts:286`) → 전송 실패해도 윈도우(기본 10분) 동안 같은 키 재시도 억제
- ⚠ **핵심 리스크**: B 웹훅을 요즘 표준인 Slack 앱 방식으로 만들면 페이로드 `channel` 필드가 무시됨 → 장애 없이 **모든 알림이 한 채널로 몰림** (채널 라우팅 무력화). 반드시 레거시 커스텀 인테그레이션("Incoming WebHooks" classic app)으로 생성해야 함 — deprecated 상태라 B 워크스페이스 관리 설정에서 허용 여부 선확인 필요

## 현재 상태

코드 조사 완료 (2026-06-11). 이전에 필요한 작업 목록 확정, 실행 미착수.
선행 결정 = B 워크스페이스에서 레거시 incoming webhook 생성 가능 여부 확인. 불가하면 채널별 웹훅 N개 발급 + 코드 구조 변경이 필요해 설계가 달라짐.

## 다음 단계

- [ ] **선행**: B 워크스페이스에서 레거시 incoming webhook(채널 override 지원) 생성 가능 여부 확인 — 불가 시 채널별 웹훅 매핑 구조로 코드 변경 필요 (/architect 검토)
- [ ] B에 공개 채널 ~10개 생성 (`config.ts:657-668` 목록 기준, 채널명 변경 시 config 수정 병행)
- [ ] B 웹훅 2개 발급: 메인 알림용(`SLACK_NOTIFICATION_URI`) + AI 프로필 검수용(`SLACK_AI_PROFILE_INSPECT_URL`)
- [ ] B에 유저 그룹 생성 (AI 프로필 검수 등) → 새 subteam ID 확보
- [ ] 시크릿 교체 (/dev-infra): ① 메인 API `.env.json` 시크릿 ② Secrets Manager `hlb/prod/cronjobs` (+dev 환경 동일 키 존재 여부 확인). `COUPON_SLACK_NOTIFICATION_CHANNEL` 함께 점검
- [ ] 코드 수정 (/dev-server): 하드코딩 subteam ID 교체 (`training-project.ts`, `ai-profile.ts`) — 이 기회에 config/env 승격 권장
- [ ] **이전 후 검증 (필수)**: 채널별 테스트 알림 1회씩 실발송 + 서버 로그 `Slack notification failed` 모니터링 — 실패가 조용히 유실되는 구조라 검증 없이는 누락을 알 수 없음
- [ ] (선택) 커스텀 이모지 이전 (`:hellobot-studio:` 등 — 없어도 동작엔 무관, 표시만 깨짐)

## 진행 로그

- 2026-06-11 — 등록. hellobot-server 코드 조사 완료: SLACK_NOTIFICATION_URI 소비 구조(notifyToSlack 단일 진입점), 채널 라우팅 방식(페이로드 channel 필드 — 레거시 웹훅 전제), 실패 모드(장애 없음·조용한 유실), env 주입 2곳(API 서버 + cronjobs 시크릿), subteam 멘션 하드코딩 4곳 확인. 다음 = B 워크스페이스 레거시 웹훅 생성 가능 여부 확인.
