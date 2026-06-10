# 과제2 — 신호 정의 교정: affinity를 '관심'으로 되돌리기

**작성**: 2026-06-09 (코디네이터) · **근거**: [`improvement-proposal.md`](improvement-proposal.md) 과제2 + 로컬 검증 [`../data/task2_signal_validation.py`](../data/task2_signal_validation.py)
**상태**: 단기(표면분리) = **검증 완료**(P0 반영분의 근거 확보) · 근본(노출로그 lift) = **스펙 확정, /dev-data 핸드오프 대기**

---

## TL;DR

| 구분 | 결론 | 근거(검증 수치) |
|---|---|---|
| **단기 — 표면분리** | ✅ 정당. 단일 엔진 폐기 확정 | 결제직후(s)·재방문(r) top5가 **46%만 겹침**, 앵커 **32%는 1순위가 바뀜** |
| **s_menu의 성격** | 인세션(같은 세션) 신호 — 결제직후 슬롯엔 적합, 재방문엔 부적합 | 2번째 결제의 **68.1%가 당일** |
| **정정 ⚠** | 당일 ≠ '업셀/할인 SKU 편향'. 오염의 본질은 SKU 종류가 아니라 **노출 결합** | 당일/비당일 판매불가·업셀 비중 **23.2% vs 22.1%**(거의 동일) |
| **근본 — 노출로그 lift** | 노출 분모 없이는 '관심 vs 노출'·자기강화를 못 가름 → impression lift 필요 | 현 lift는 구매자만 보고 노출을 안 봄 (closed loop) |

---

## 1. 문제 재정의

추천의 학습 신호인 co-purchase는 두 가지를 **섞어서** 측정한다:
1. **관심** — A를 산 사람이 진짜 B에 관심이 있어서 B를 산다 (우리가 원하는 신호)
2. **노출 결합** — A 직후 화면/세션에 B가 노출·끼워팔려서 B를 산다 (편향)

이 둘을 못 가르면 추천이 "다음 관심"이 아니라 "**과거에 같이 노출된 것**"을 학습한다 →
- **결제직후 슬롯**: 과거 배치를 그대로 재현 → **자기강화(closed loop)**. 한 번 B를 A 뒤에 깔면 co-purchase가 올라가고, 그게 다시 B를 추천하게 만든다.
- **재방문 푸시**: 인세션 신호를 다른 표면에 적용 → 미스매치.

---

## 2. 단기 — 표면분리 (검증 완료)

### 2-1. 컬럼 의미 (검증됨)
- **`s_menu`** = 2번째 결제(시간순, **당일 포함**). `second_sameday=1`이면 당일.
- **`r_menu`** = **다른 날** 첫 재방문 결제(`days_to_rev>0`). 순수 재방문.
- 정합성 체크: 비당일(`second_sameday=0`)에서 `s_menu==r_menu` **100%** ✓ / 당일에서 4.4% → 컬럼 해석 정확.

### 2-2. 검증 수치 (A 앱퍼스트 첫구매자 98,392명, 2번째 도달 73.5%)

| 지표 | 값 | 의미 |
|---|---|---|
| 2번째 결제 중 **당일** 비중 | **68.1%** | s_menu 신호 = 대부분 인세션 |
| days_to_2nd 분포 | 당일 68.1% · 1~7일 13.1% · 8일+ 18.8% | 재방문(8일+)은 19%뿐 |
| 다른날 재방문(r_menu) 존재 | 52.0% | 2번째 사도 절반은 다른날 재방문 없음 |
| **s top5 ∩ r top5** | **2.32/5 (46%)**, Jaccard 0.51 | 두 표면 추천이 절반만 겹침 |
| **1순위가 표면 따라 바뀜** | **32%** (50/74 동일) | 단일 엔진이면 1/3 앵커에서 틀림 |
| 겹침 ≤1개(거의 다른 추천) | 38% 앵커 | 표면 무시는 위험 |

**예시 — 1순위가 갈리는 앵커**:
- `어떤 사람과 사귈 운명일까?` → 결제직후: *지금 날 좋아하는 사람은?* / 재방문: *그 사람의 속마음*
- `2026년 솔로 탈출 시기` → 결제직후: *지금 날 좋아하는 사람은?* / 재방문: *삼신할매가 점지한…*

### 2-3. 정정 ⚠ (리뷰 주장 일부 수정)
리뷰는 "당일 = 업셀/번들 SKU 편향"이라 했으나, **데이터는 이를 지지하지 않음**:
- 당일 2번째의 판매불가/업셀 비중 **23.2%** vs 비당일 **22.1%** — 거의 동일.
- 자기재구매(s==f) 당일 4.3% vs 비당일 4.3% — 동일.

→ **오염의 본질은 "SKU 종류"가 아니라 "행동 의미"**다. 당일 구매는 *같은 세션에 노출돼서* 산 것(노출 결합), 비당일은 *관심으로 다시 와서* 산 것(관심 표출). 제품 구성은 같아도 **신호의 의미가 다르다.** 이게 표면분리가 필요한 진짜 이유이고, 근본 해법이 노출로그여야 하는 이유다.

### 2-4. 결론 (단기)
- **결제직후 슬롯** = `s_menu` 사용이 **맞다**(인세션 동반구매 신호). 단, 자기강화 위험은 근본에서 해소.
- **재방문 푸시·홈탭** = `r_menu` 사용. 인세션 신호를 쓰면 1/3 앵커에서 1순위가 틀림.
- P0가 이미 두 표면을 분리 산출(`nbo_table_a_appfirst_p0.csv` / `nbo_table_a_revisit_p0.csv`) → **본 검증으로 그 분리의 근거 확보**. 추가 코드 변경 불필요.

---

## 3. 근본 — 노출(impression) 기반 lift  *(/dev-data 핸드오프)*

### 3-1. 현 정의의 한계
```
현재:  lift(B|A) = P(B를 2번째로 구매 | A 첫구매) / P(B를 2번째로 구매)
```
분자·분모 모두 **구매자만** 본다. "B가 노출됐는데 안 산 사람"이 식에 없다 → 노출 많은 SKU가 자동으로 높게 나오고, 자기강화를 못 끊는다.

### 3-2. 새 정의 (노출 정규화)
```
interest_lift(B|A) = P(B구매 | B노출, A이후) / P(B구매 | B노출)
                   = "A를 산 뒤 B가 노출됐을 때 전환율" ÷ "B가 노출됐을 때 평균 전환율"
```
- **노출을 분모로** 두면 "관심"만 남는다. A 이후 B 전환율이 평균 노출 전환율보다 높을 때만 진짜 affinity.
- 인세션에 무조건 깔려서 팔린 B(노출 결합)는 *노출 대비 전환율이 평균 수준* → lift≈1로 떨어져 걸러진다. **자기강화 차단.**

### 3-3. 노출 소스 — **검증 완료 (2026-06-09)**
노출 소스로 **`mart_v2_skill_funnel_fb`의 `open_skill_description`(스킬 상세페이지 조회)** 확정. BQ 메타데이터 + 표본 쿼리로 적절성 7기준 검증:

| 기준 | 결과 | 판정 |
|---|---|---|
| 스킬 식별자 | `menu_seq` 존재, null **0%**, 473 스킬/일 | ✅ |
| 이벤트 존재·볼륨 | 17.8k/일(최근)·54k/일(2024) | ✅ |
| 시간 커버리지 | 분석창 전체 2024-03~2026-03 | ✅ (⚠ 볼륨 54k→18k 하락) |
| 플랫폼 분리 | APP(IOS+AOS) 13.8k/일·WEB 3.9k/일 | ✅ |
| **구매 조인 커버리지** | APP 구매의 **68%**가 같은 스킬 상세조회 선행 (2026-02 표본) | ✅ 분모 채워짐 |
| 키 정합 | `menu_seq` STRING — 구매 테이블(`mart_use_skill_se`)과 동일 키, 조인 직결 | ✅ |
| 신호 품질 | 단순 임프레션 아닌 **'고려'(상세 조회)** + `related_skill_seq`/`recommend_seq` 추천맥락 보유 | ⭐ |

**기각**: 사용자가 처음 짚은 `mart_v2_metrics_lv1_fb`(및 lv2)는 **스킬키 없음(26필드 집계 테이블)** → 부적합. 퍼널 테이블이 정답.

**신호 의미 주의**: `open_skill_description`은 *노출*보다 *고려*(상세 직접 열람)에 가깝다 → "스쳐본" 패시브 임프레션은 배제됨. 분모가 "고려했는데 안 산 사람"이 되어 **관심 신호로는 오히려 정밀**하나, 패시브 노출 편향(배너에 떠서 산 것)은 일부만 통제. 미커버 32%(딥링크·마케팅 직구매·이력 재구매 우회)는 사각지대 → pair별 커버리지 낮으면 플래그.

### 3-4. BQ SQL 스켈레톤 (검증된 소스 반영)
> ⚠ 타임스탬프 타입 상이: funnel `event_timestamp`=INTEGER(µs, GA4식) vs `mart_use_skill_se`=TIMESTAMP → `UNIX_MICROS()`로 통일. `platform IN ('IOS','ANDROID')`로 APP 한정.
```sql
WITH imp AS (   -- 노출=상세페이지 조회(고려 신호)
  SELECT user_id, menu_seq, event_timestamp AS imp_ts            -- INTEGER µs
  FROM `hellobot-f445c.hlb_mart.mart_v2_skill_funnel_fb`
  WHERE event_name = 'open_skill_description' AND platform IN ('IOS','ANDROID')
),
buy AS (        -- 구매
  SELECT user_id, menu_seq, UNIX_MICROS(event_timestamp) AS buy_ts  -- µs로 통일
  FROM `hellobot-f445c.hlb_mart.mart_use_skill_se`
  WHERE event_name LIKE 'pay_for_%' AND revenue_krw > 0 AND platform IN ('IOS','ANDROID')
),
first_buy AS (  -- 앵커 A (rn=1)
  SELECT user_id, menu_seq AS A, event_timestamp AS f_ts
  FROM ( SELECT *, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_timestamp) rn FROM buy )
  WHERE rn = 1
),
exposed_after_A AS (   -- A 구매 이후 B 상세조회한 케이스
  SELECT fa.A, i.menu_seq AS B, i.user_id, i.imp_ts
  FROM imp i JOIN first_buy fa ON i.user_id = fa.user_id
       AND i.imp_ts > UNIX_MICROS(fa.f_ts)
),
conv AS (              -- 조회 후 window(예 14일) 내 B 구매 여부
  SELECT e.A, e.B,
    COUNT(DISTINCT e.user_id) AS viewers,
    COUNT(DISTINCT IF(b.buy_ts IS NOT NULL, e.user_id, NULL)) AS buyers
  FROM exposed_after_A e
  LEFT JOIN buy b ON b.user_id = e.user_id AND b.menu_seq = e.B
       AND b.buy_ts BETWEEN e.imp_ts AND e.imp_ts + 14*86400*1000000  -- +14d in µs
  GROUP BY 1,2
),
base AS (              -- B의 전체 조회 대비 전환율(분모)
  SELECT menu_seq AS B,
    SAFE_DIVIDE(COUNT(DISTINCT b.user_id), COUNT(DISTINCT i.user_id)) AS base_cvr
  FROM imp i LEFT JOIN buy b USING(user_id, menu_seq) GROUP BY 1
)
SELECT c.A, c.B, c.viewers, c.buyers,
  SAFE_DIVIDE(c.buyers, c.viewers)                      AS cvr_from_A,
  SAFE_DIVIDE(SAFE_DIVIDE(c.buyers, c.viewers), b.base_cvr) AS interest_lift
FROM conv c JOIN base b ON b.B = c.B
WHERE c.viewers >= 30                                   -- 표본 게이트
ORDER BY c.A, interest_lift DESC;
```
> **표면(screen) 분해**: `open_skill_description` 자체엔 진입 화면 컬럼이 없음. 대신 funnel 테이블의 `recommend_seq`(추천경유)·`related_skill_seq`(연관스킬경유)·`category_seq`(카테고리경유)로 *유입 경로* 근사 분해 가능 → 결제직후 슬롯 노출은 `recommend_seq`로 식별.

### 3-5. 검증 계획
1. **랭킹 churn**: 앵커별 `interest_lift` 순위 vs 현 구매전용(`s_menu`) 순위 비교 — 얼마나 바뀌나.
2. **자기강화 검출**: s_menu에서 상위였던 pair가 노출 정규화 후 떨어지면 = 노출 결합이었다는 증거. (가설: 인세션 고노출 pair가 lift≈1로 수렴)
3. **표면 분해**: screen별(결제직후/홈/푸시) 따로 산출 → 표면분리(단기)와 정합 확인.
4. **커버리지**: impressions≥100 만족하는 (A,B) pair 수 — 산출 가능 앵커 범위.

### 3-6. /dev-data 핸드오프 체크리스트
- [x] **노출 소스 확정** — `mart_v2_skill_funnel_fb.open_skill_description` (스킬키·시간·플랫폼·68% 커버리지 검증 완료, §3-3)
- [x] 빌링 프로젝트 = `--project_id=hellobot-f445c` (기본 `anonymous-logs-between-for-dev`는 권한 없음)
- [ ] 타임스탬프 단위 통일(funnel µs vs 구매 TIMESTAMP) + first_buy 코호트(A 앱퍼스트) 정의 재확인
- [ ] 위 SQL로 `(A, B, viewers, buyers, interest_lift)` 테이블 생성 (분석창·lookback·전환 window 확정)
- [ ] 검증 1~4 수행(랭킹 churn·자기강화 검출·유입경로 분해·커버리지), 현 P0 NBO와 비교 리포트
- [ ] pair별 조회-커버리지 낮은(<50%) 항목 플래그 — 마케팅 직구매 사각 통제
- [ ] 노출정규화 NBO 산출 → **P1 정제본**으로 승격

### 3-7. 개념검증 결과 (POC, 2026-06-09) — ⚠ **3-에이전트 비판검증으로 반증됨 (헤드라인 철회)**
A 앱퍼스트 12개월 cohort로 `interest_lift` 실측 후(`data/task2_interest_lift_poc.sql` 5.57GB, `data/task2_lift_compare.py`) **3개 독립 비판 분석가**가 검증. **초기 헤드라인("노출정규화가 추천을 재배열, Spearman −0.23")은 통계 artifact로 판명 — 철회.** (검증 상세 readme 로그 2026-06-09, /tmp 재계산)

| 초기 주장 | 검증 결과 | 정체 |
|---|---|---|
| "구매빈도≠관심, −0.23 재배열" | ❌ **Partial Spearman(conf,lift\|base_cvr) = −0.002** (인기 통제 시 소멸). 분자 자체는 conf와 **+0.25 양상관** | base_cvr(인기)로 나눈 **산술 부작용** — 인기 스킬 일괄 강등일 뿐 |
| "median 1.78 = 변별력/priming" | ❌ mean cvr 0.38 vs base 0.22 = **+73% intent floor**. lift<1이 **4%뿐**(공정하면 ~50%). 교차도메인이 동일도메인보다 lift 높음 | null=1.0 아님(~1.74). 구매전환자 모집단 선택효과 |
| "자기강화 강등 사례(lift 0.70)" | ❌ **SQL 버그**: `viewers=COUNT(*)`가 LEFT JOIN buys 뒤라 재구매 유저만큼 중복. 수정 시 lift 0.70→**2.27**, 0.76→1.49 (부호 역전) | 깃발 사례가 실은 고전환 pair |
| "숨은 관심 167건" | △ 숫자는 재현되나 viewers 버그·free스킬·base 비대칭에 오염 | 재산출 전 신뢰 불가 |
| "구매 −0.23" 비교 자체 | ❌ P0(2년·s_menu) vs POC(12m·조회후구매) **모집단/신호 불일치**. 동일 12m·구매전용 conf로 맞추면 **−0.06~+0.19**(양/무상관) | 코호트·정의 차이의 합성물 |

**추가 결함**: ① 코호트 좌측절단 — POC 앵커의 **40~48%가 진짜 첫구매자 아님**(창 이전 결제 이력 보유) → "1→2 전이" 목표 불일치. ② 분자의 **90~95%가 당일(in-session) 구매** → 과제2가 제거하려던 인세션 오염을 그대로 재측정(상세조회 게이트로 재세탁). ③ free/WEB결제 스킬이 base_cvr=0로 27% pair 탈락(생존편향). ④ 측정 universe = P0의 20%(고볼륨 tail)뿐.

**판정**: 노출 *소스*(`open_skill_description`, §3-3 검증)는 유효하나, **이 POC 구현은 근본 트랙을 입증하지 못했고 오히려 반례에 가깝다.** 현 데이터로는 인기 통제 후 잔존 관심 신호 = 0, 앵커내 상관은 오히려 +0.17(구매와 관심이 같은 방향). → "빌드 GO"는 **"정의 교정 후 재검증 필요"로 하향.**

**재산출 전 필수 수정 6종(에이전트 수렴)**:
1. `viewers/base = COUNT(DISTINCT user_id)` — SQL 버그 정정
2. 앵커 = 진짜 첫구매(분석창 이전 무결제 + master와 동일 좌측가드)
3. 분자에서 **당일/동일세션 제외**(다른-세션 전환만) — in-session 오염 분리
4. base 정규화를 **동일 구매전환자 코호트** 기준 + 분자유저 leave-out → null=1.0 복원, intent floor 제거
5. 후보 B = 판매중 유료 스킬(P0 VALID 집합 재사용) — free/WEB 오염 제거
6. 비교는 **동일 코호트·동일 윈도우**(P0 12m 재산출 또는 구매전용 conf 동시 산출)에서. 그 위에서 신호가 살아남는지 재확인
> 가능성: 위 교정 후에도 잔존 신호가 0이면 → **노출정규화는 인기 페널티만 추가할 뿐, P0(Wilson 정렬)로 충분**이라는 결론. 이 경우 근본 트랙은 투자 보류가 합리적(과잉투자 경계).

---

## 4. 액션 요약

| 트랙 | 상태 | 다음 |
|---|---|---|
| 단기 표면분리 | ✅ 완료(P0 반영 + 검증) — **본 POC 반증과 무관, 영향 없음** | 추가 작업 없음 — §2가 근거 |
| 노출 소스 검증 | ✅ 유효 (`open_skill_description`, 커버리지 68%, §3-3) | 재산출 시 그대로 사용 |
| 근본 노출로그 lift | ⚠ **POC 반증 — 빌드 보류** | §3-7 필수수정 6종 적용해 재산출 → 신호 잔존 여부 재확인 후 GO/중단 결정 |

**한 줄 결론**: 표면분리(46% 겹침·1순위 32% 변동)와 노출 소스 검증은 유효하다. 그러나 노출정규화 lift **POC는 비판검증으로 반증**됐다 — `−0.23`은 인기(base_cvr) 통제 시 −0.002로 소멸하는 산술 부작용이었고, 분자의 90%+가 당일 인세션, 앵커 40%+가 진짜 첫구매자 아님, 핵심 사례는 SQL 버그값이었다. **풀 빌드는 보류**, §3-7의 6종 교정 후 신호가 살아남는지부터 재확인한다. 살아남지 못하면 P0(Wilson 정렬)로 충분하다는 결론(과잉투자 경계).
