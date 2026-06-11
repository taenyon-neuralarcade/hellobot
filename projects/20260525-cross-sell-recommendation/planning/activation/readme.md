# 활성화(Activation) 트랙 — 확정 NBO 세트를 노출 표면에 얹기

**작성**: 2026-06-09 (코디네이터, PO 기획 3종 위임 종합) · **상태**: 기획 초안 완료 · 6/9 = 데이터(추천세트 v2)만 공유, 기획·착수순서 **미결** → 기획 리뷰 미팅 대기

> 🟩 **리뷰 미팅용 통합 1장 = [`../review-packet.md`](../review-packet.md)** (TODO-044 트랙 B, 2026-06-10). 본 인덱스 + `action-priorities.md` + `action-plan-nbo-slot.md` 를 결정용으로 합본 — 착수순서 충돌·D1~D6 체크리스트. 미팅은 그 패킷을 안건으로.

확정된 추천 세트(앱 NBO v2 · 웹12 · 재방문 P0)를 **어느 노출 표면에 어떻게 얹을지**의 PO 기획 묶음. 분석·데이터(SSOT=[`../baseline.md`](../baseline.md), 확정 산출물=[프로젝트 readme](../../readme.md#-확정-산출물-2026-06-09--추천-세트-v2))는 끝났고, 이 트랙은 "그래서 무엇을 출시하나"를 다룬다.

> **공통 원칙(전 표면 적용)**: ① 표면 분리(인세션 s_menu ↔ 재방문 r_menu, top5 48%만 겹침) ② 채널 분리(앱=A / 웹=C) ③ 위생 게이트(판매상태·blocklist·보유제외 서빙시점) ④ **효과 caveat — 적중률은 상관 수치, 실제 증분은 노출군 vs 비노출(holdout) A/B로만 확정. 적중률은 보조지표 강등** ⑤ 가장 싼 채널로 증분 먼저 → 검증되면 제품화.

## 기획 3종 + 기존 리드

| # | 기획 | 표면 | 추천 소스(표면·채널 정합) | 롤아웃 단계 | 문서 |
|---|---|---|---|---|---|
| — | 결제직후 인세션 슬롯(리드) | 앱 인세션 | `nbo_v2_combined.csv` (직접 83%) | **P2** | [`../action-plan-nbo-slot.md`](../action-plan-nbo-slot.md) |
| 1 | **카플친 푸시** — 전일/당일 1회차 구매자 추천 알림 | 앱 재방문(다른 날) | **재방문 r_menu**(`nbo_table_a_revisit_p0.csv`, ⚠정제 선결) | **P1**(가장 쌈·holdout 진입) | [`01-kakao-push-recommendation.md`](01-kakao-push-recommendation.md) |
| 2 | **웹 아웃트로** — 웹 신규 1회차: ⓐ인세션 추가구매 ⓑ앱전용 쿠폰 웹투앱 | 웹 | **web12**(`nbo_web12_named.csv`) + C 백오프(`web_hero_c_nbo_p0.csv`, ⚠풀빌드 선결) | **P3** | [`02-web-outro-recommendation.md`](02-web-outro-recommendation.md) |
| 3 | **홈 개인화 섹션** — 인앱 상시 추천 카드 | 앱 홈(재방문 의미) | `nbo_v2_combined.csv` (재방문 정제세트로 후속 교체) · 서빙 API 인세션 슬롯과 공유 | **P2**(API 공유) | [`03-home-personalized-section.md`](03-home-personalized-section.md) |

> 📄 **공유용 HTML 리포트** (브라우저로 더블클릭 열람, 우하단 🖨 버튼으로 PDF 출력):
> - **자세한 버전** — 근거·데이터·표 전체: [`01-kakao-push-recommendation.html`](01-kakao-push-recommendation.html) · [`02-web-outro-recommendation.html`](02-web-outro-recommendation.html) · [`03-home-personalized-section.html`](03-home-personalized-section.html) · 빌더 [`build_html.py`](build_html.py)
> - 🟢 **쉬운 버전 (비전문가용)** — 용어 풀이·한눈에 요약·비유·결정 박스: [`01-kakao-push-recommendation-easy.html`](01-kakao-push-recommendation-easy.html) · [`02-web-outro-recommendation-easy.html`](02-web-outro-recommendation-easy.html) · [`03-home-personalized-section-easy.html`](03-home-personalized-section-easy.html) · 빌더 [`build_easy_html.py`](build_easy_html.py)

세 표면은 형제 문서 [`action-plan-nbo-slot.md`](../action-plan-nbo-slot.md)의 롤아웃(P0 정제 → P1 CRM → P2 인앱 → P3 웹/재방문)에 그대로 맵핑된다. **카플친 푸시(P1)가 앱·서버 개발 0으로 가장 싸고, 프로젝트가 보류해 둔 holdout 효과검증의 첫 진입 차량**이라 착수 1순위 후보.

## 표면별 북극성·핵심 지표

| 기획 | 북극성 | 핵심 표면지표 | 가드레일 |
|---|---|---|---|
| 1 푸시 | 재방문 1→2 전환 **증분**(holdout) | 발송→오픈→클릭→상세→2구매 퍼널 | 판매상태 하드게이트(푸시 회수불가), 옵트인·야간발송 |
| 2 웹 | 웹 신규 1→2 전환(A/B 증분) | ⓐ웹 인세션 2구매율 ⓑ웹→앱 전환율+앱 2구매 | **쿠폰 순효과(마진 차감 후)**, 음수면 중단 |
| 3 홈 | 1→2 전환(A/B 증분) | 섹션 도달·CTR·홈경유 2구매 | 홈 전체 전환 비잠식·보유추천 0·판매중지 0 |

## 횡단 선결 과업 (/dev-data)

활성화 전 공통으로 필요한 데이터 작업 — 현 확정 세트의 빈틈:

1. **v2급 정제 재방문(r_menu) 세트** — 푸시(1)·홈(3) 공용. 현 `nbo_table_a_revisit_p0.csv`는 위생 미정제·소표본(75%가 pair_n<30)·시즌물 잔존. 인세션 v2와 동일 위생·표본게이트·방향보존 + 2층 관심사 백오프 적용해 재산출.
2. **C(웹온리) 풀빌드 NBO** — 웹 아웃트로(2) 롱테일. 현 `web_hero_c_nbo_p0.csv`는 **8앵커뿐이고 전부 web12 직접 앵커와 중복** → 지금은 web12보다 넓지 않음. C 모집단(289,983명) 전체로 풀빌드해야 "넓은 커버리지" 잠재력이 실현됨.
3. **카플친·마케팅 옵트인/도달 실측** — 푸시(1) 타겟 규모 산정. 현재 미보유(`/dev-data`+CRM).

## 횡단 오픈 결정사항 (6/9 미팅 + 후속)

| # | 결정 | 옵션·권장 |
|---|---|---|
| D1 | **착수 순서** | 푸시(P1) 먼저 — 앱개발 0·holdout 진입. 홈(P2)·웹(P3) 후속 *(권장)* |
| D2 | **표면별 세트** | 푸시·홈은 재방문 정제세트가 정합 → **선결 1 착수 승인** 필요. 일정 압박 시 인세션 v2 임시 사용(표면 미스매치=하한 해석) |
| D3 | **/dev-data 선결** | 재방문 정제(선결1) + C 풀빌드(선결2) 착수 승인 |
| D4 | **쿠폰 정책(웹)** | 할인율·원가·순손익분기 기준선 / ⓐ인세션 vs ⓑ쿠폰 관계(권장: 인세션 미전환 시 쿠폰 분기) |
| D5 | **홈 anchor·배치** | anchor keying(마지막구매/최다관여/**다중블렌드 권장**) · 홈 내 배치·섹션 크기(top-N) — `/design`+A/B |
| D6 | **공통: A/B 증분 게이트** | 전 표면 출시 = 노출군 vs 비노출 증분 통과 필수, 적중률 강등 |

## 다음 단계

1. 6/9 미팅에서 D1~D6 결정 (특히 D1 푸시 우선 + D3 /dev-data 선결 착수)
2. 결정되면 각 기획을 **별도 후속 프로젝트로 승격**(표면별 서버·앱·웹·디자인 구현) 또는 본 프로젝트 내 구현 트랙으로 진행
3. 푸시(P1) holdout 결과가 전 표면 제품화의 1차 증분 근거 — 여기서 효과 입증 후 P2·P3 확대

> 이 트랙은 **PO 기획(무엇을·왜·어떻게 측정)** 까지다. 실제 구현(서빙 API·UI·쿠폰·이벤트 스펙)은 결정 후 `/dev-*`·`/design`·`/architect` 위임.
