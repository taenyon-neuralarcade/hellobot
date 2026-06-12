# 이슈 레지스트리 — 인기차트 랭킹 자동화

> 본 프로젝트의 이슈 레지스트리(ISS-NNN). 현상+원인+상태만 기록 — 해결 상세는 tasks.md 과업·커밋·[리뷰 문서](reviews/code-review-5lens-20260611.md) 참조.
> ⚠️ 데이터 카탈로그 레지스트리(`common-data-airflow/docs/hellobot-data/catalog/issues.md`)의 ISS-006(임시 태그) 등과 **별개 번호 체계**.
>
> **운영 메모**: 다음 번호 = **ISS-012**. 상태 변경은 필드만 갱신(섹션 이동 금지).

## 등록 이슈

ISS-001~011 전부 5렌즈 코드 리뷰(2026-06-11, PR [#2444](https://github.com/thingsflow/hellobot-server/pull/2444)·[#188](https://github.com/thingsflow/common-data-airflow/pull/188) 대상)에서 발견. 발견 ID(LN-NN)·상세 근거 = [reviews/code-review-5lens-20260611.md](reviews/code-review-5lens-20260611.md).

| ID | 분류 | 심각도 | 파트 | 현상 | 원인 | 상태 |
|---|---|---|---|---|---|---|
| ISS-001 | bug | **블로커** | 서버 | C-A 응답 `skills[].chatbotSeq`가 link 도메인 원값 — `chatbots` 맵 키(info.seq)와 불일치 → C-A on 시 앱 카드 조인 실패/오표기 (L2-01, 코드 재확인 완료) | 어댑터(`getRankedSkillPairs`)가 AsIs 경로의 `findChatbotCacheByLinkChatbotSeq(...)?.info.seq` 변환 누락 | 해결 (2026-06-11, 브랜치 반영 — 서버 PR 재생성 대기) |
| ISS-002 | edge-case | **블로커** | 계약/데이터 | architecture §1.3 freshness guard("computed_date=오늘")대로 CronJob 작성 시 매일 push 실패(C-A 영구 미서빙+거짓 알람) (L4-01=L5-01) | 마트 computed_date=Airflow ds(실행일 전일)인데 계약 문서·SQL 헤더·서버 코멘트가 각각 다른 시맨틱 기술 — 방향 결정 필요(권고: 문서 개정+guard=어제) | 해결 (2026-06-11, A안 확정 — computed_date=윈도우 종료일(어제)·guard=어제, 문서 개정+주석 동기, SQL 무변경) |
| ISS-003 | bug | 높음 | 서버 | 적재 그룹 키가 구분자 없는 `${section}${tag}` 연결 — 복합키 충돌 시 타 그룹 행 오염 적재/오스킵 (L1-03=L2-04=L3-01, 코드 재확인 완료) | 그룹화 키 설계 결함 + 그룹화가 화이트리스트 검사 선행 | 해결 (2026-06-11, JSON 그룹 키) |
| ISS-004 | edge-case | 높음 | 서버 | 그룹 내 menuSeq 중복 시 유니크 위반 → 단일 tx **전 그룹 롤백+500**(재시도 루프) — rank 중복(그룹만 skip)과 비대칭 (L1-02=L3-03, 코드 재확인 완료) | skip 판정에 menuSeq 중복 케이스 부재(api-spec에도 미정의) | 해결 (2026-06-11, DUPLICATE_MENU skip) |
| ISS-005 | bug | 높음 | 서버 | DTO 검증 실패가 400 아닌 **500 UNKNOWN**(api-spec §1 에러표 위반) + 비실재 날짜·null 행·int4 초과도 500 → CronJob 재시도 오분류 (L1-01=L3-02 등) | routing-controllers `BadRequestError.httpCode`를 전역 핸들러(`error.statusCode\|\|500`)가 못 읽음 + 서비스 검증 구멍 3종 | 해결 (2026-06-11, 서비스 일원화 400 — rows 비배열만 DTO 선차단 500 잔존·수용) |
| ISS-006 | edge-case | 높음 | 서버 | 적재·서빙 visibility가 모바일 축(`visibleStatus`)만 — web-visible·mobile-hidden 스킬 영구 drop → 웹 C-A 후보 왜곡(C-M 대비 confound)+알람 노이즈 (L2-02=L1-06=L3-10) | AsIs는 디바이스 분기인데 신규 경로 미분기 — 스펙(§1.4)이 visibility 축 미정의. 웹 C-A 포함 정책 결정 선행 | 해결 (2026-06-11, A안 — 웹 포함: 적재 OR 완화+서빙 디바이스 분기) |
| ISS-007 | edge-case | 높음 | 데이터 | 시트 원천 menu_seq 중복 시 조인 팬아웃 → top30 내 동일 스킬 중복 → 서버 유니크 위반으로 섹션 적재 거부 (L4-02) | base·skill_tag CTE에 dedup 부재(수기 GSheet 원천 무방어) | 해결 (2026-06-11, QUALIFY+GROUP BY dedup) |
| ISS-008 | edge-case | 높음 | 계약 | CronJob 추출 계약 미명문화 — ①NULL 미바인딩 제외 술어 부재(위반 시 400 **전체 거절**) ②응답 ResWrapper envelope 예시 누락 ③BQ INT64 문자열 직렬화 캐스팅 (L5-02=L5-05) | "미바인딩 push 제외"가 마트 SQL 주석에만 존재 — architecture §1.3·api-spec §1 보강 필요 | 해결 (2026-06-11, 추출 술어·envelope·캐스팅 노트 명문화) |
| ISS-009 | enhancement | 중간 | 문서 | 계약 문서-구현 드리프트 9건(사주/타로 필터 축, 게이트 순서, rank 연속성, §1.1 tag NULL, 분모 표기, new_boost 경계, 폴백 알람 수단, 401/403, "거절" 용어) — 코드가 맞고 문서가 구식 (L5-03 외) | 구현 확정·실측 피벗이 v1.1 Changelog에 부분 누락 | 해결 (2026-06-11, 9건 일괄 개정 — architecture v1.1·api-spec v1.2) |
| ISS-010 | enhancement | 낮음 | 서버/데이터 | 마이너 12건 묶음 — version:"latest" 캐시 미스, data:null 폴백 가드, 동시 PUT 경합, stale 날짜 역행, hasAnyRanking 캐시, isBig, loadTopK, 테스터 로그, rejoin TRIM, DELETE 범위, 비파티션 스캔, @Airflow 운영 보강 | [리뷰 문서](reviews/code-review-5lens-20260611.md) ISS-010 표 참조 | 해결 (2026-06-11, 코드 10건 반영 — L3-04·L3-12는 /dev-infra 과업 이관, L4-05는 dbt 이식 시) |
| ISS-011 | edge-case | 중간 | 기획/운영 | 설계 의도 확인 질의 7건 — 구매 시그널 범위(웹·패키지 귀속), FB 지연, 시트 sync 경합, send_success 게이트, 고아 키 허용, hackleAssigned 시맨틱, 마이그레이션→flag 순서 runbook | [리뷰 문서](reviews/code-review-5lens-20260611.md) ISS-011 표 참조 — 사용자/기획 회신 대기 | 부분 해결 (2026-06-11, 6/7 회신 — L4-06 유지·L4-07 수용·L5-09 기보장·L1-09 서빙 정규화·L2-06 마커·L3-14 런북. **L5-10만 별도 논의 보류**) |
