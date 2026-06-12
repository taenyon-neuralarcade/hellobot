# Braze Cloud Data Ingestion (CDI) — 속성·이벤트 업로드 방법 조사

> **목적**: 6/12 데이터 백필 — 신규 Braze 계정에 user attributes(custom attributes)·custom events를 업로드하는 방법
> **조사일**: 2026-06-12 | **출처**: Braze 공식 문서 (하단 링크)
> ⚠ 표기 = 문서에서 직접 확인 못 한 가설/검증 필요 항목

## 1. CDI 개요 — 동작 방식

- 데이터 웨어하우스 ↔ Braze 워크스페이스 간 **스케줄 기반 정기 동기화**. Braze가 우리 웨어하우스에 접속해 테이블을 읽어감 (pull 방식)
- 지원 소스: **Google BigQuery**, Snowflake, Redshift, Databricks, Microsoft Fabric, S3
- 지원 데이터 타입: **사용자 속성**(중첩 custom attributes·구독 상태 포함), **custom events**, 구매 이벤트, 유저 삭제 요청, 카탈로그
- 최소 동기화 주기 **15분** — 더 빈번해야 하면 REST API 권장
- **우리 케이스**: 전 데이터가 BigQuery에 있으므로 (common-data-airflow) **BigQuery CDI가 백필의 자연스러운 경로** — `/users/track` REST 호출 배치를 직접 짜는 것보다 운영 부담 낮음

## 2. 공통 테이블 스키마 (소스 테이블/뷰)

모든 user-data 동기화에 필수 3요소:

| 컬럼 | 타입 | 설명 |
|---|---|---|
| `UPDATED_AT` | TIMESTAMP (UTC) | 마지막 동기화 이후 값보다 큰 행만 가져감. **단조 증가·고유 값 권장** (같은 timestamp 재동기화 위험) |
| 식별자 1개 | STRING | `EXTERNAL_ID` (권장) / `EMAIL` / `PHONE` / `ALIAS_NAME`+`ALIAS_LABEL` / `BRAZE_ID` 중 택1 (행마다 한 종류만) |
| `PAYLOAD` | JSON 문자열 | 동기화할 데이터 본문. **행당 최대 1MB** (초과 시 reject) |

- `BRAZE_ID`로는 신규 유저 생성 불가 → 백필은 **`EXTERNAL_ID` 사용** (구 계정과 동일 값 유지 — 6/11 조사 원칙과 일치)
- **신규 유저 생성**: 통합 설정의 **"Update existing users only" 토글을 OFF** 하면 존재하지 않는 external_id 도 신규 프로필 생성. ON이면 미존재 유저 행은 skip → **백필 시 반드시 OFF**

## 3. User Attributes (custom attributes) 업로드

PAYLOAD = 속성 key-value JSON. **부분 업데이트** 방식 — 보낸 필드만 추가/갱신되므로 전체 프로필을 매번 보낼 필요 없음. 중첩 객체 지원.

```sql
-- BigQuery 예시 (우리 속성 기준)
CREATE OR REPLACE TABLE braze_cdi.users_attributes_backfill AS
SELECT
  CURRENT_TIMESTAMP() AS UPDATED_AT,
  CAST(user_id AS STRING) AS EXTERNAL_ID,
  TO_JSON_STRING(STRUCT(
    잔여_하트_개수,
    주간_푸시_허용여부,
    오늘의_운세_푸시_허용여부,
    가입_여부,
    생년, 생월, 생일, 성별, 별자리, 이름
  )) AS PAYLOAD
FROM ...
```

```json
// PAYLOAD 예시
{"잔여 하트 개수": 35, "주간 푸시 허용여부": true, "가입 여부": true, "별자리": "물병자리"}
```

- 속성 값 제거: `null` 설정 시 프로필에서 생략, 완전 삭제는 keep-null 구성 필요 (Snowflake 예: `TO_JSON(OBJECT_CONSTRUCT_KEEP_NULL(...))`)
- ⚠ 한글 속성명 사용 가능 여부는 문서에 명시 없음 — 구 계정에서 한글 속성명을 쓰고 있으므로 동일하게 가능할 것으로 추정하나, 소량 테스트로 검증 필요

## 4. Custom Events 업로드

PAYLOAD = 이벤트 1건의 JSON. **행당 이벤트 1개**.

```json
{
  "app_id": "신규-앱-id (선택)",
  "name": "스킬 결제 완료",
  "time": "2026-06-10T19:20:45+09:00",
  "properties": {
    "menu_name": "내 팔자에 새겨진 천년배필",
    "current_price": 9900,
    "subject": "연애"
  }
}
```

| 필드 | 필수 | 비고 |
|---|---|---|
| `name` | ✅ | 이벤트명 |
| `time` | 선택 | ISO 8601. **생략 시 `UPDATED_AT` 값을 이벤트 시각으로 사용** — 과거 이력 백필 시 반드시 명시 |
| `properties` | 선택 | 이벤트 프로퍼티 (menu_name, price 등) |
| `app_id` | 선택 | |

## 5. 구독 상태 (수신동의) 업로드 — 백필 필수 항목

속성 sync 의 PAYLOAD 로 subscription group 상태도 동기화 가능:

```json
{
  "subscription_groups": [
    {"subscription_group_id": "마케팅_푸시_그룹_id", "subscription_state": "subscribed"}
  ]
}
```

## 6. BigQuery 통합 설정 절차

1. **소스 테이블/뷰 준비** — 위 스키마 (데이터셋 분리 권장, 예: `braze_cdi`)
2. **GCP 서비스 계정 생성** + 권한 4종: `BigQuery Connection User` / `BigQuery User` / `BigQuery Data Viewer` / `BigQuery Job User` → **JSON 키 발급**
3. **Braze 대시보드** → CDI → 통합 생성: 데이터 타입 선택(속성/이벤트/구매/삭제 — 통합별 1종), JSON 키 업로드, 테이블 지정, 동기화 스케줄 설정
4. 백필 통합은 **"Update existing users only" OFF** 확인
5. 동기화 결과는 **CDI > Sync Log** 에서 행 단위 오류 확인

## 7. 운영 규칙·주의사항

| 항목 | 내용 |
|---|---|
| **데이터 포인트 비용** | "CDI도 REST API·SDK와 동일하게 데이터 포인트 소비" — **변경/신규 행만 소스 테이블에 넣을 것**. UPDATED_AT 이 최신이면 동일 값이라도 재적재·재과금 |
| 재동기화 방지 | UPDATED_AT 을 고유·단조 증가로. 파이프라인 적재와 sync 동시 실행 회피 |
| 처리 순서 | **비보장** — 같은 sync 안에 동일 EXTERNAL_ID 여러 행이 있으면 최종 값 예측 불가 → 유저당 최신 1행으로 압축해서 적재 |
| 쿼리 시간 | 1시간 내 완료 권장 |
| 행 크기 | PAYLOAD 1MB/행 |

### ⚠ 백필 설계 시 핵심 판단 2가지 (검증/결정 필요)

1. **과거 이벤트 대량 백필은 비용·리스크 대비 효익 검토 필요** — 데이터 포인트가 그대로 과금되고, CDI로 들어온 이벤트가 action-based 캠페인 트리거를 발화시키는지 FAQ에 명시가 없음 (⚠ API 이벤트는 일반적으로 트리거 발화). 백필 이벤트가 결제완료 알림톡 등을 오발송할 위험 → **캠페인 활성화 전에 백필 완료** 또는 이벤트 백필 범위 최소화 권장
2. **세그먼트용 과거 행동 데이터는 백필 대신 CDI Segment Extensions 검토** (아래 8절)

## 8. (보너스) CDI Segment Extensions — 관심사 세그먼트 대체 후보

미해결 질문 ④(관심사별 segment extension 대체안)의 유력 해법:

- Braze가 **우리 BigQuery를 직접 SQL 쿼리해서 세그먼트 생성** (zero-copy — 데이터를 Braze로 복사하지 않음)
- **데이터 포인트 소비 없음**, SQL Segment 크레딧·Segment Extension 한도 미차감 (웨어하우스 쿼리 비용만 우리 부담)
- 쿼리 결과 컬럼은 `external_user_id` (STRING 캐스팅 필수), 최대 런타임 60분
- 신규 유저 생성은 안 함 (Braze에 없는 유저는 무시) → 속성 백필로 유저 생성 후 사용
- → **과거 이벤트를 백필하지 않고도** BQ의 기존 행동 이력(관심사·구매 카테고리 등)으로 온보딩 캔버스·임신 flow 등의 세그먼트 재현 가능

## 출처

- [Cloud Data Ingestion 개요 (ko)](https://www.braze.com/docs/ko/user_guide/data/unification/cloud_ingestion/)
- [Data Warehouse Integrations (BigQuery 설정·스키마)](https://www.braze.com/docs/user_guide/data/unification/cloud_ingestion/integrations/)
- [Table Setup (속성·이벤트·구매·구독 PAYLOAD 포맷)](https://www.braze.com/docs/user_guide/data/unification/cloud_ingestion/table_setup/)
- [Best Practices (1MB 제한·데이터 포인트·UPDATED_AT 전략)](https://www.braze.com/docs/user_guide/data/unification/cloud_ingestion/best_practices/)
- [FAQ (처리 순서·Sync Log)](https://www.braze.com/docs/user_guide/data/unification/cloud_ingestion/faqs)
- [CDI Segment Extensions](https://www.braze.com/docs/user_guide/engagement_tools/segments/segment_extension/cdi_segments)

## Changelog

| 날짜 | 변경자 | 내용 |
|------|--------|------|
| 2026-06-12 | 코디네이터 | 최초 작성 — CDI 속성·이벤트 업로드 방법 조사 |
