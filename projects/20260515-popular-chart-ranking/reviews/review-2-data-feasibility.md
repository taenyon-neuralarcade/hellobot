# 데이터·기술 실현성 리뷰 — 인기스킬 섹션 노출 자동화 설계 전 문서

> 리뷰어: 실현성 렌즈 (적대적 데이터·기술 검토) · 작성: 2026-06-05
> 대상: `projects/20260515-popular-chart-ranking/{readme,requirements,data-measurement-plan,tasks,status}.md`
> 근거 대조: `planning/{s1-current-state,s3-ranking-definition,s4-filtering-tagging}.md` + 코드/카탈로그 타겟 확인
> 제약: BQ 라이브 인증 만료 → 직접 쿼리 불가. 컬럼 실재·freshness·distinct 는 카탈로그 SQL/문서 + planning 일관성으로만 판정.

---

## 판정 (한 줄)

**S5 진입 가능하나 "데이터 실현성 ✅(확정)"이라는 status/s3 의 자기평가는 과장이다** — 점수 산식이 **결정 가능(deterministic)** 상태가 아니고(`norm()`·신규스킬 일수보정 미정의), 핵심 시그널 2종(매출·긍정평가비율)의 **정의가 소스 실태와 어긋나며**, 근거로 인용한 카탈로그 문서 5종이 전부 **DEPRECATED**다. 🔴 2건 / 🟠 6건 / 🟡 5건.

---

## 🔴 Blocker

### B1 · `norm()` 미정의로 B 랭커 점수가 비결정적 — "데이터 실현성 ✅"는 성립 불가
- **위치**: data-measurement-plan §5 (`norm() = 0~1 정규화(방식은 min-max/percentile 중 S5/구현에서 확정)`), readme §5, requirements FR-R3, s3 결론.
- **문제**: 6개 시그널 중 4개(구매·조회·전환·매출)가 `norm()`을 거친다. min-max 정규화와 percentile-rank 정규화는 **같은 입력에 다른 순위를 낸다** — min-max 는 소수 고매출 스킬이 분포를 지배해 나머지를 0 근처로 깔아뭉개고(롱테일 압살), percentile 은 등간격화로 상위권 격차를 소거한다. 즉 **랭킹 결과 자체가 norm 선택에 종속**인데, 그 선택을 "구현에서 확정"으로 미뤘다. 이 상태에서 적절성 합격기준(T1~T4)·A/B 비교를 논하는 것은 측정 대상이 미정인 채 측정 계획을 세우는 것.
- **근거**: 산식에 `norm()`이 4회 등장하나 정의는 한 줄도 없음. 정규화 기준 모집단(전체 스킬 풀? 섹션 후보 풀?)도 미정 — **섹션마다 풀이 다르면 같은 스킬이 섹션마다 다른 norm 값**을 갖는다(섹션 간 점수 비교 불능).
- **다음 단계 영향**: /architect 가 "사전계산 후 적재"(NFR-1)를 설계할 때 *무엇을* 계산할지가 비어 있음. percentile 이면 윈도우·모집단 스냅샷이 배치 입력에 추가로 필요 → 마트 스키마가 달라진다. 미정인 채 S5 들어가면 마트 재설계 리스크.
- **제안**: S5 진입 전 기획/데이터가 (1) norm 방식, (2) 정규화 모집단(권장: 전체 노출가능 풀 1회 산출 후 섹션은 그 점수를 재사용), (3) 결측·0 처리(조회=0 스킬의 전환율 분모)를 **확정**해 measurement-plan §5 에 박아야 한다. canonical 이라 적어 둔 산식이 사실상 미완성임을 status "확정 사항"에서 내려야 한다.

### B2 · 긍정평가비율 산식이 인용 근거(line 216)와 다른 집계 — 근거가 주장을 뒷받침하지 않음
- **위치**: data-measurement-plan §4·§2 (`긍정평가비율 = 비-💩 평가 비율(0~1)`, 근거로 `report_kpi_total_skill_weekly.sql` line 216 인용), s3 DF-S3-1, requirements FR-R5.
- **문제**: 인용된 line 216 의 실제 코드는 `CASE WHEN eval_emoji = '💩' THEN 1 ELSE 5 END AS score` → 이후 `AVG(score)`. 이건 **{1,5} 의 평균(1~5 스케일)** 이지 **0~1 비율이 아니다**. "비-💩 비율(0~1)"을 얻으려면 `AVG(CASE WHEN eval_emoji='💩' THEN 0 ELSE 1 END)` 라는 **다른 식**이 필요하다. 문서는 기존 reference 가 자기 정의를 지지하는 것처럼 인용했지만, reference 는 다른 메트릭을 구현한다. 게다가 산식에서 `eval` 만 유일하게 `norm()` 없이 곧장 들어가는데(§5: `+0.15*eval`), 이는 "이미 0~1"이라는 가정 — 그 가정의 근거가 깨졌다.
- **근거**: `dags/scripts/hellobot/report/report_kpi_total_skill_weekly.sql` L212-216 직접 확인. `WHERE eval_emoji IS NOT NULL` 로 무평가 제외만 함(분모 = 평가 존재 건).
- **다음 단계 영향**: 0.15 가중 항목이 통째로 잘못 스케일되면 가중합 전체가 왜곡. 또 "💩=1/else=5 이진"에서 5 는 "👍"뿐 아니라 **모든 비-💩(좋아요/보통 등 다중 이모지가 5로 뭉뚱그려졌을 가능성)** 을 포함 — 즉 원천이 진짜 이진인지(💩 vs 단일 긍정)인지, 아니면 다이얼이 접힌 것인지 **확인 안 된 채** "이진"으로 단정.
- **제안**: (1) 긍정평가비율 = `1 - 💩비율` 로 식 명시(현 인용식 폐기), (2) `eval_emoji` 의 실제 distinct 값 집합을 /dev-data 실측 항목(§8)에 **명시 추가**(현재 §8 에 없음), (3) 표본 편향 가드(아래 J 미검증 목록 참조) 추가.

---

## 🟠 Major

### M1 · 인용 카탈로그 문서 5종이 전부 DEPRECATED — "확정"의 근거가 무효 마크된 문서
- **위치**: data-measurement-plan §4 (시그널 BQ 원천 표, 전부 ✅), §7, s3 시그널 표, readme D2/D3.
- **문제**: §4 가 ✅ 로 단정한 소스 — `mart_use_skill_se`, `mart_v2_skill_funnel_fb`, `mart_fixed_menu_evaluation_server`, `mart_fixed_menu_server`, `mart_skill_open_date_se` — 의 **카탈로그 table 문서 5개 모두 상단에 `⚠️ DEPRECATED (2026-04-22) — 이 문서는 실제 SQL과 불일치가 있을 수 있어 참고하지 마세요. 실제 컬럼은 .sql 직접 조회`** 배너를 달고 있다. 즉 컬럼명(`revenue_krw`, `pay_for_%`, `pay_under_750`, `menu_create_at_date`, `chatbot_content_type` 등)을 **"참고하지 말라"고 명시된 문서에서 그대로 인용**해 ✅ 판정을 내렸다. measurement-plan §6 은 정직하게 "미검증"이라 했으나 §4 표의 판정 컬럼은 ✅(=가용 확정)로 적혀 모순.
- **근거**: 각 `docs/hellobot-data/tables/mart/*.md` head 3줄에 DEPRECATED 배너 확인(5/5). 권위 SQL(`dags/scripts/hellobot/mart/*.sql`)은 실재 → S5/실측에서 대조 가능.
- **다음 단계 영향**: /architect 가 ✅ 를 믿고 컬럼 존재를 전제한 마트 JOIN 을 설계하면, 실측 시 컬럼명 불일치로 재작업. 특히 평가마트 deprecated 문서는 `menu_seq` STRING·`evaluation_date` 파티션을 보여주나 배너상 신뢰 불가.
- **제안**: §4 판정 컬럼을 ✅ → 🔶(SQL 대조 필요)로 강등. §8 실측 6번 "BQ 컬럼 실재"를 **deprecated 문서가 아니라 `mart/*.sql` 대조**로 명문화. S5 는 컬럼 가정에 의존하지 않는 인터페이스로 설계.

### M2 · `mart_use_skill_se` 는 이벤트 그레인 — "menu_seq×일" 주장과 산식 의사SQL이 오류
- **위치**: data-measurement-plan §4(입도 `menu_seq×일`), §9 의사SQL(`AVG(purchase_cnt) AS buy7 ... FROM mart_use_skill_se`), s3 시그널 표(`menu_seq×일`).
- **문제**: 카탈로그는 `mart_use_skill_se` 그레인을 **`user × event_timestamp × menu_seq` (이벤트 단위)** 로 명시한다. "menu_seq×일"이 아니다. 따라서 (1) §9 의 `AVG(purchase_cnt)` 는 **존재하지 않는 컬럼** 가정 — 이벤트 행에는 행당 1구매가 있을 뿐 `purchase_cnt` 일집계 컬럼이 없다. 7일평균을 구하려면 먼저 `GROUP BY menu_seq, event_date` 로 일별 집계를 만들고 그 위에서 평균해야 한다. (2) §2 "7일평균 = 7일합÷실데이터일수"의 "실데이터일수"는 이벤트 그레인에서 `COUNT(DISTINCT event_date)` 로 별도 산출해야 하는데 미정의.
- **근거**: `docs/hellobot-data/catalog/tables/mart/mart_use_skill_se.md` — "그레인: 이벤트 단위 (user × event_timestamp × menu_seq)", "스케줄: 매일 1회".
- **다음 단계 영향**: 마트 설계 분량이 문서 가정보다 한 단계 큼(이벤트→일집계→7일윈도우 2단). §9 를 "대표 쿼리"로 신뢰하면 /dev-data 가 잘못된 출발점을 잡는다.
- **제안**: §4 입도를 "이벤트 단위(일집계는 파이프라인이 수행)"로 정정, §9 의사SQL 을 2단(일집계 CTE → 7일평균)으로 교체, 신규 스킬 "실데이터일수" 산식을 명시.

### M3 · 매출 시그널이 외부채널 환산금으로 구조적 편향 — ISS-017 을 "캐비엇" 한 단어로 축소
- **위치**: data-measurement-plan §4(매출 행: "외부채널 환산금 합산 캐비엇 ISS-017"), s3 시그널 표(동일), 산식 매출 0.15.
- **문제**: ISS-017/카탈로그 실측 결과, `revenue_krw` = **유료하트 + 현금**이며 그 현금에 **카카오 쿠폰 등 외부 결제 채널의 쿠폰 판매가가 서버에서 인젝션**된다. "사용자가 직접 지불한 현금"만 분리하려면 별도 식별자(`used_coupon_seq` 등)가 필요한데 **"현재 마트 미추출"**. 즉 매출 항목은 **카카오 선물하기/쿠폰으로 팔린 스킬을 쿠폰 정가로 과대계상**해 popularity_score 를 부풀린다(15% 가중). 이건 단순 주석거리가 아니라 랭킹 공정성 문제 — 외부채널 강한 스킬이 인기 섹션 상위를 부당 점유할 수 있다. measurement-plan 은 이 편향의 **방향·크기·현재 분리불가** 사실을 본문에 드러내지 않고 괄호 한 줄로 처리.
- **근거**: `docs/hellobot-data/catalog/tables/mart/mart_use_skill_se.md` L73-77 + `issues.md` ISS-017(심각도 ★★, enhancement, 2026-04-27 coop 프로젝트 발). "현재 마트 미추출" 명시.
- **다음 단계 영향**: 인기 섹션이 카카오 쿠폰 매출 상위로 쏠리면, 본 프로젝트의 목표(노출 품질·전환)와 어긋난 결과가 "자동화 성과"로 오인될 수 있음. A/B 판정도 오염.
- **제안**: 산식 결정 전 택1을 기획에 올릴 것 — (a) 매출 시그널을 1차에서 **제외**(가중 0, 나머지 재정규화), (b) `spent_cash_amount` 대신 외부채널 제외 가능한 필드만 사용(현재 불가 → 마트 보강 선행), (c) 외부채널 포함을 **의도된 정책**으로 기획이 명시 수용. 어느 쪽이든 "캐비엇"이 아니라 **결정 항목**으로 승격.

### M4 · "실시간 인기" 섹션을 D+1 일배치로 산출 — 의미 모순이 미해소
- **위치**: readme §6(G1 "실시간 인기"), requirements FR-B4(`D+1 일배치`)/NFR-2, s4 §3(실시간 인기: "'실시간'은 랭커 윈도우 문제일 수 있음 → S3/S5"), s3 DF-S3-5.
- **문제**: 섹션명이 "실시간 인기"인데 산출은 하루 1회(D+1, 게다가 기존 체인 KST 11시). 어제까지의 7일평균을 오늘 11시에 한 번 갱신하는 것을 "실시간"이라 부를 수 없다. s4 가 "랭커 윈도우 문제일 수 있음"이라며 S3/S5 로 던졌지만 s3 도 일배치로 못박아 **누구도 해소하지 않은 채** 양쪽에서 상대에게 미뤘다. "실시간 인기" = 전체 풀(필터 없음) + 짧은 윈도우(s4 §3)라 했는데, 일배치라면 "짧은 윈도우"의 의미가 사라진다.
- **근거**: s4 §3 표 비고 vs s3 DF-S3-5 vs FR-B4 의 상호 미결.
- **다음 단계 영향**: 클라이언트/기획이 "실시간"을 글자대로 기대하면 수용 불가 판정 위험. 또 진짜 준실시간이 요구되면 일배치 마트 아키텍처 전체가 부적합(런타임 집계 필요 → NFR-1 "런타임 계산 금지"와 정면 충돌).
- **제안**: S5 전에 기획이 "실시간 인기"의 **운영 정의**를 확정 — (a) 명칭을 "인기 급상승/오늘의 인기" 류로 정렬해 일배치 수용, 또는 (b) 해당 섹션만 별도 신선도 SLA. 현재 `recentPurchasedSkills` 가 이미 반자동(매분 트리거, s1 §3 확인)이므로 그 경로 재사용 가능성도 비교.

### M5 · reverse-ETL "기존 경로 없음 + 빌딩블록 존재"가 불일치 — 인용한 `db.py` 가 리포에 부재
- **위치**: requirements C4/FR-B2(`BQ→서비스 PG reverse-ETL 기존 경로 없음 — 신규 구축`), s3 §배치(`빌딩블록(MWAA db.py 직결 / 서버 엔드포인트)은 존재`), FR-B3(컨벤션: `update_collection_ranking`=서버 PATCH, `refresh_recent_purchased_skills`=서버 계산+MWAA 트리거).
- **문제**: "신규 구축 필요"는 맞다(아래 근거). 그러나 s3 가 안심용으로 든 **"MWAA `db.py` 직결 빌딩블록 존재"는 확인 불가** — `common-data-airflow` 어디에도 `db.py` 가 없다. PG 로 쓰는 DAG 도 없다(검색된 두 파일은 S3→BQ 및 transform). 즉 "빌딩블록이 있어 쉽다"는 뉘앙스가 근거 없이 실현성을 낙관하게 만든다. 또 인용한 컨벤션 2종(`update_collection_ranking`, `refresh_recent_purchased_skills`)의 **DAG/스크립트 실체가 data 리포 검색에서 안 잡힘** — 서버측 엔드포인트만 있고 MWAA 측은 별 리포(`hellobot-mwaa`)에 있을 수 있어, "컨벤션과 일관"이라는 근거가 본 리포에서는 미확인.
- **근거**: `find db.py` → 없음. `grep psycopg2|postgres|to_sql|UPSERT|PostgresHook` (dags/) → BQ→PG write 없음. 단, 서버에 BQ **읽기** 클라이언트(`hellobot-server/src/common/bigquery.ts`, `getChatbotStatsFromBigQuery`)는 존재 — 방향이 반대(BQ→서버 read)라 reverse-ETL 근거는 아니나, 문서들이 이 사실을 언급 안 함.
- **다음 단계 영향**: reverse-ETL 은 본 프로젝트 **유일한 신규 인프라**이자 최대 리스크(적재 빈도·정합·실패복구·트랜잭션 경계). "빌딩블록 있음"으로 난이도가 낮게 잡히면 S5 추정·일정이 낙관 편향.
- **제안**: s3/requirements 에서 "빌딩블록 존재" 문구를 **근거(파일 경로)와 함께 재확인하거나 삭제**. 컨벤션 DAG 의 실제 위치(`hellobot-mwaa` vs `common-data-airflow`)를 명시. reverse-ETL 을 S5 의 **명시적 위험 항목 + 폴백(NFR-2)·멱등 적재 설계 필수**로 격상.

### M6 · 신규 스킬 데이터 일수 보정 + 신규부스트가 미정의 — 신규 섹션 결과가 불안정
- **위치**: data-measurement-plan §2(`7일 윈도우 = 7일합÷실데이터일수, 신규 스킬은 데이터 일수 보정`), readme §6 G1 "신규 인기", s4 §3(신규 인기: 등록일≤N ∩ 인기, "N 정합 필요"), 신규부스트 0.05.
- **문제**: "신규 스킬은 데이터 일수 보정"이라고 적었으나 **보정 방식이 어디에도 정의되지 않음**. 등록 2일차 스킬은 분모(실데이터일수)가 2 라 7일평균이 과대(노이즈 큰 소표본이 상위로 튐) 또는 라플라스/사전평활 없이 0 분모 위험. 신규부스트(등록 30일 내 +1×0.05)와 "신규 인기" 섹션 필터(등록일≤N)의 **N 이 서로 다른 값(30 vs ?)** 이라 s4 도 "정합 필요"라 했으나 미해결. 결국 **신규 인기 섹션이 가장 데이터가 적은 스킬들로 채워지는데, 그 스킬들의 점수가 가장 불안정**한 역설.
- **근거**: §2 한 문장 외 산식 부재. s4 §3 비고 "N 정합 필요" 미결.
- **다음 단계 영향**: T1 커버리지(섹션당 후보≥슬롯×3)는 통과해도 점수 안정성은 별개 — 신규 섹션 상위가 매일 요동치면 사용자 신뢰·A/B 노이즈 증가. 보정 미정이면 마트 산식이 재작성됨.
- **제안**: (1) 최소 노출 임계(예: 실데이터일수≥k 또는 누적조회≥m 이어야 랭킹 대상), (2) 소표본 평활(전환율·평가비율에 베이지안 prior), (3) 신규부스트 N 과 "신규 인기" 필터 N 을 단일 상수로 통일 — 을 measurement-plan 에 추가. 미정 상태로 S5 진입 금지.

---

## 🟡 Minor

### m1 · 조회 정의 미확정이 전환율 분모를 비결정으로 — α 와 동급 블로커성인데 표기 약함
- **위치**: data-measurement-plan §2/§4(조회 = `open_skill_description` 기본, `enter_skill` 대안), readme §11(조회정의), s3 DF-S3-3.
- **문제**: 전환율(0.2) = 구매÷조회인데 분모 이벤트가 미확정. `open_skill_description`(상세 진입)과 `enter_skill`(스킬 진입)은 모수가 크게 달라 전환율이 배 단위로 바뀐다 — 즉 **두 번째 norm 종속 입력이 또 미정**. 문서는 이를 "확인 대기"로 가볍게 뒀으나 실제로는 점수 결정성에 직접 타격(B1 와 같은 급).
- **제안**: α·norm·조회정의를 "산식 결정성 3대 미정"으로 묶어 status 확정 사항에서 빼고 오픈 결정으로 승격.

### m2 · `menu_seq(STRING)↔seq(INT)` CAST 정합을 "OK"로 단정 — 비숫자/결측/스냅샷 불일치 미점검
- **위치**: readme D3/§2, requirements FR-B5, data-measurement-plan §2, s3 "정합 OK".
- **문제**: `fixed_menu.seq` 가 INT(코드 확인: `FixedMenu.ts` `seq: number`)인 건 맞다. 그러나 "CAST 만 하면 OK"는 BQ `menu_seq` 에 **비숫자/NULL/공백 행이 없음**을 전제 — 이벤트 그레인 마트는 폴백 파라미터(`menu_*` COALESCE, 카탈로그 명시)에서 비정형 값이 섞일 수 있다. `SAFE_CAST` 실패 시 NULL→적재 누락/조인 유실. 또 BQ 는 일배치 스냅샷, 서비스 PG 는 실시간 → **적재 시점 menu_seq 가 PG 에서 이미 삭제/비노출**일 수 있음(NFR-3 가 이를 요구하나 정합 검증 산식은 없음).
- **제안**: FR-B5 를 "`SAFE_CAST` + 캐스팅 실패율 모니터(NFR-5) + 적재 전 PG 유효 스킬 INNER JOIN"으로 구체화. "OK" → "SAFE_CAST 전제 + 실패행 관측".

### m3 · `FixedMenu.targets` 재사용을 G3 4섹션의 전제로 깔았으나 값 분포 미실측 (DF-S4-2)
- **위치**: data-measurement-plan §7(대상 = `FixedMenu.targets` text[]), readme D2/§11, s4 §3·DF-S4-2.
- **문제**: 솔로/커플 4섹션이 `targets ∋ 솔로|커플` 에 의존하는데, `targets` 가 실제로 솔로/커플 값을 담는지·커버리지가 충분한지 **미확인**(s1 은 `targets/subjects/contentTypes` 존재만 확인, 값 분포는 아님). 값이 비거나 다른 의미(연령/성별)면 G3 4섹션이 통째로 빈다.
- **제안**: §8 실측 5번(현재 있음)을 **블로커 의존**으로 표시 — targets 가 솔로/커플을 안 담으면 intents 내장/신규 축으로 대체해야 하므로 필터 모델이 바뀜.

### m4 · "showRanking→ranker_id 일반화"는 SHOULD 인데 2종 목록 서빙(MUST)이 이를 사실상 요구 — 등급 모순
- **위치**: requirements FR-API2(SHOULD), FR-AB1/AB3(MUST: 2종 산출 + 유저 일괄 A/B), FR-R2(MUST: 랭커 2종).
- **문제**: 칩별 `showRanking`(bool)은 "랭킹 적용/미적용" 2값뿐(코드 확인: `HomeSectionFeaturedSkillsTab.showRanking: boolean`). 그런데 A/B 는 "유저 단위 일괄"(FR-AB3)이라 **칩 단위 bool 로는 유저 버킷을 표현 못 한다** — variant 주입점은 칩 속성이 아니라 요청 컨텍스트(유저 버킷)에서 와야 한다. FR-API2 가 SHOULD 로 "일반화 검토"라 했지만, 2종 서빙(MUST)을 충족하려면 주입점 설계가 필수라 SHOULD/MUST 가 엇갈림.
- **제안**: variant 주입을 "칩 bool 일반화"가 아니라 **요청 컨텍스트 차원**으로 S5 에 명시. FR-API2 와 FR-AB2 의 관계(칩 속성 vs 요청 컨텍스트)를 분리 기술.

### m5 · 적절성 합격 기준(T2 precision≥0.8, T3 충돌율≤15%)이 골든셋 없이 제시 — 측정 불가한 임계
- **위치**: data-measurement-plan §6(T2 precision≥0.8 초안, T3 충돌율≤15% 초안), requirements FR-V2/V3.
- **문제**: T2 precision/recall 은 **골든셋(사람 라벨)** 이 있어야 계산되는데, 골든셋 생성 과업·규모·라벨러가 어디에도 없다(tasks.md 데이터 파트에 골든셋 구축 항목 부재). 임계만 있고 측정 도구가 없음. T3 "충돌율"도 temp topic ↔ 공식 content_type **매핑 테이블**이 있어야 정의되는데 그 대응표가 미정(s4 DF-S4-1 은 하이브리드로 매핑을 후속으로 미룸) → 1차에 T3 산출 자체가 불가능할 수 있음.
- **제안**: T2 를 1차 SHOULD→후속으로 내리거나, 골든셋 구축을 tasks.md /dev-data 명시 과업으로 추가. T3 은 "매핑표 확정 후"를 전제로 명시.

---

## 미검증 가정 목록 (실측/확인 전 '확정'처럼 쓰인 것)

| # | 가정 (문서 위치) | 실제 상태 | 위험 |
|---|---|---|---|
| J1 | 시그널 6종 BQ 가용 "✅"(data-plan §4, s3 표) | 근거 문서 5/5 DEPRECATED, 컬럼은 `.sql` 대조 필요 | M1 |
| J2 | `mart_use_skill_se` 입도 "menu_seq×일"(§4) | 실제 이벤트 그레인(user×ts×menu_seq) | M2 |
| J3 | 긍정평가비율 0~1 "비-💩 비율", line216 근거(§4) | line216 은 1~5 평균(다른 식), `eval_emoji` distinct 미확인 | B2 |
| J4 | `revenue_krw` 를 매출 시그널로 "✅"(§4) | 외부채널 환산금 포함·분리불가(ISS-017 "미추출") | M3 |
| J5 | `norm()` 0~1 정규화 "canonical 산식"(§5, status 확정) | 방식·모집단 미정 → 순위 비결정 | B1 |
| J6 | 신규 스킬 "데이터 일수 보정"(§2) | 보정식 부재 | M6 |
| J7 | reverse-ETL "빌딩블록(db.py 직결) 존재"(s3) | 리포에 `db.py`·PG-write DAG 없음 | M5 |
| J8 | `menu_seq↔seq` CAST "정합 OK"(D3/FR-B5) | INT 확인됨, 비숫자/NULL/스냅샷불일치 미점검(`SAFE_CAST` 미규정) | m2 |
| J9 | `FixedMenu.targets` 가 솔로/커플 담음(D2, §7) | 값 분포 미실측(DF-S4-2) | m3 |
| J10 | 배치 D+1·KST11시 freshness 정합(FR-B4) | 카탈로그 내부 모순(헤더 "파티션 미지정/CREATE OR REPLACE" vs dbt "incremental partition_by=event_date"), '새벽4시'와 타이밍 미조정 | M4·(g) |
| J11 | temporal 축 값("실시간/신규/상시")(s4 §1) | "값 정의 확인 필요"라 문서가 자인, distinct 미실측 | m3 계열 |

> 코드로 **검증된** 것(반례 아님): `showRanking`/`targetSection`/`targetSectionTag` 필드 실재(`HomeSectionFeaturedSkillsTab.ts`, `home.dto.ts`, `home.ts:606`), `recentPurchasedSkills` Redis(`recent-purchased-skills:data:latest`)+DB폴백(`getRecentPurchasedSkillSeqsFromDB`)+pinned 메커니즘(`fixed-menu.ts`, `user-purchased-skill.ts`), `fixed_menu.seq` INT(`FixedMenu.ts:19`), 5개 시그널 마트의 `.sql` 실재. PR #2414 머지 커밋 `7ad74765` 로컬 존재(단 working-tree master 는 stale — s1 caveat 정확).

---

## 종합

- **무엇이 튼튼한가**: 컨테이너(PR #2414) 결합 전제, recentPurchasedSkills 일반화 방향, 키 매핑 INT 사실, 시그널 마트 SQL 의 물리적 존재, "1차 임시 태그 그대로"의 하이브리드 결정 — 이들은 코드/카탈로그로 뒷받침된다. s4 의 필터 모델(3축 AND/OR)도 구현 가능한 형상이다.
- **무엇이 위태로운가(설계 전 반드시 닫을 것)**: (1) **점수가 아직 결정적이지 않다** — `norm()`·조회정의·신규보정·정규화 모집단이 비어 있어, 지금 "확정 공식"이라 부르는 것은 **반제품**이다(B1·B2·m1·M6). (2) **두 시그널의 정의가 소스 실태와 어긋난다** — 매출(외부채널 오염, M3)·긍정평가비율(인용식 불일치, B2). (3) **근거 신뢰성** — ✅ 판정의 출처가 전부 DEPRECATED 문서(M1)이고, 입도/그레인 주장이 틀렸다(M2). (4) **유일한 신규 인프라(reverse-ETL)** 의 난이도가 근거 없는 "빌딩블록 존재"로 낙관되어 있다(M5).
- **S5 권고**: status.md "확정 사항"의 "랭킹 공식"·"데이터 실현성 ✅"을 **"산식 골격 확정 / 결정성 미완(norm·조회·보정 미정)"** 으로 정정하고, B1·B2·M2·M3 를 **/architect 입력 전 닫아야 할 게이트**로 명시. measurement-plan §4 판정 ✅→🔶 강등, §8 실측 항목에 `eval_emoji distinct`·`SAFE_CAST 실패율`·`매출 외부채널 분리 가능성`을 추가. reverse-ETL 은 S5 의 1급 위험으로 멱등·폴백·정합검증과 함께 설계. — 이 게이트들을 닫으면 S5 진입은 합리적이다.
