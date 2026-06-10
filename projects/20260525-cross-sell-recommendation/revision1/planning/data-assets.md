# 데이터 자산 맵 — Cross-Sell 분석 (A 앱퍼스트)

> 출처: bq 스키마 + probe + baseline 쿼리, 2026-05-31 (계정 tony@dlt-partners.com)
> ⚠ 정정 이력: 초기 작성본에 셸 버퍼 글리치로 인한 유령 정보(33 topic·content_type/price 컬럼·타로/사주=chatbot_category 등)가 있었음. 본 문서는 실측 재확인본.

## 핵심 테이블

### 1) 결제·행동·인구통계: `hlb_mart.mart_use_skill_se` (일 파티션 `event_date`, 51컬럼)
| 용도 | 컬럼 | 비고 |
|---|---|---|
| 식별 | `user_id`, `menu_seq`(STRING), `event_date`(파티션), `event_timestamp` | menu_seq = 태그 조인키 |
| 콘텐츠 구매 | `event_name LIKE 'pay_%' AND revenue_krw > 0` | |
| 금액 | `revenue_krw`(FLOAT), `price`, `current_price`, `spent_*` | |
| 콘텐츠 분류 | `chatbot_category` = **hellobot / external** · `chatbot_original_type` = **original / nonOriginal** | ⚠ **타로/사주 아님** — 자체/파트너 구분. 타로·사주 위치 미확보 |
| 인구통계(내장) | `user_age`(INT, **채움 98%**), `user_gender`(**채움 3.3% → 폐기**), `user_birth_year/month/day`, `user_country`, `user_language` | age_group_5yr 별도 union 마트에 있을 수 있음 |
| 채널 | `platform` (IOS/ANDROID=APP, WEB) | A 판별 |

### 2) 관심사 태그: `google_sheet_sync.taenyon_temp_skill_tag_info_v2` (임시 시트, 비파티션)
- **6,117행**, `menu_seq`(STRING) 고유 = 조인키. 5컬럼: `menu_seq` · `menu_name` · `topic` · `intents` · `temporal`
- **채움률: topic ~100%(코호트 매칭 94.7%) · intents 25.5% · temporal 7.4%** → intents/temporal sparse
- 사용자 지시(2026-05-31): **topic 필드만 join 해서 사용, intents/temporal("tag 정보")는 사용 안 함**

## topic 택소노미 (9종 — 이미 정리됨, merge 불필요)
연애(2648) · 기타(2429) · 일반운세(416) · 총운(193) · 결혼(132) · 학업직업(115) · 재물금전(83) · 자기탐구(63) · 가족자녀(38)  ← 태그 테이블 skill 분포
> 코호트 사용자 분포는 baseline.md 참조 (연애가 사용자 68%로 압도적)

## 조인
```
mart_use_skill_se.menu_seq = taenyon_temp_skill_tag_info_v2.menu_seq → topic
미매칭 = '(미태깅)' (A 신규코호트 5.3%)
```

## 채널 정의 (β 확정)
A 앱퍼스트 = 최초 콘텐츠결제(pay_% & revenue>0) platform이 IOS/ANDROID.

## 코호트 정의 (Phase 1.2 확정)
첫구매일 ∈ [2024-03-02, 2026-03-02] (90일 성숙). 첫구매 = APP. → n=101,465 (전체 A 458K 중 최근 2년 신규분).

## 미해결 / 다음 확인
- [ ] **타로/사주 콘텐츠 형식 축 위치** — mart에 없음. 별도 마스터(챗봇/스킬) 테이블 또는 다른 컬럼? (사용자 질의)
- [ ] 연애 topic 세분화(이별/재회/솔로) — 9종으론 불가, menu_name 파싱 검토
- [ ] age_group_5yr 소스 (mart엔 user_age만; 버킷팅 또는 union 마트)
- [ ] sameday 다건이 연속결제/번들 아티팩트인지 검증

## 도메인 지식 (사용자, 미검증)
- 사주 = 고가·결과고정·1회성 / 타로 = 저가·반복 → topic vs 콘텐츠형식 교란 분리 대상 (단 형식축 컬럼 미확보로 보류)
