# Agent-06 — Confounding & Causal-Inference Review

> Adversarial independent review of "A 앱퍼스트 cross-sell analysis (Revision 2)".
> Lens: confounding, correlation-vs-causation, control adequacy.
> Method: full recompute from `data/master_users.csv` (98,392 rows + header) with python3. No BigQuery.
> Column map (1-indexed, naive comma-split safe — verified 0 quoted fields, all rows = 24 fields):
> `f_rev`=col4, `f_topic`=5, `f_ctype`=7, `total_pays`=8, `c_rev90`=14, `c_sameday`=15, `has_2nd`=21, `second_sameday`=22.
> Metric definitions (from `master_export.sql`): `rev90` = `c_rev90>0` (any strictly-later-date purchase ≤90d); `sameday` = `c_sameday>0` (any same-date purchase after first).

---

## 1) VERDICT

**FAIL on the headline causal claim as framed; the underlying stratification arithmetic is reproducible but the causal interpretation is not supported by the metric it rests on.**

The central claim — *"반복성 = 콘텐츠 특성 (타로>사주), 가격 특성 아님"* (R2-5, Phase 2 (2차) §★) — is built on the **`rev90` metric**, which I show is **53% contaminated by same-day upsell** and is **not** the "재방문 리텐션" behavior the report itself says recommendations should target (R2-2). When I isolate genuine return-visit retention (later-day purchase, no same-day component), the 타로>사주 advantage **collapses to noise within price tiers and REVERSES in aggregate (사주 wins +4.0pp)** via a Simpson's paradox driven by 사주's 88.6% concentration in the >12k tier. The "콘텐츠가 主, 가격이 副" hierarchy is **backwards on the retention metric**: the within-content price swing (~8pp) is 3–4× larger than the within-tier content gap (~2pp).

Two findings are genuinely robust and survive my adversarial recompute: (a) the within-tier *direction* 타로 ≥ 사주 holds in every adequately-sized cell on every metric; (b) the within-content price direction is monotone "higher price → more repeat" (rejecting naive "cheap→repeat"). But the report over-claims by (i) selecting the contaminated metric, (ii) labeling content the dominant lever, and (iii) resting the "same price" comparison on near-separated price distributions with thin tails.

---

## 2) FINDINGS

### F-1 · [CRITICAL] · R2-5 / Phase 2 (2차) §★ — "반복성 = 콘텐츠 특성" rests on a same-day-contaminated metric; reverses on clean retention

**Claim** (R2-2 vs R2-5 mismatch): R2-2 establishes the analysis "척추": 추천이 키울 영역은 **재방문(현 23%)** — i.e. return-visit retention, explicitly distinguished from same-day upsell (50%). But the content/price claim (R2-3, R2-5) is computed on `rev90` (38.4%), not on that retention metric.

**Why wrong** — `rev90` (`c_rev90>0`) is **not** clean retention. Recompute:

| cell | users | note |
|---|---:|---|
| sameday & rev90 (both) | 20,178 | **53% of rev90 users also did a same-day upsell** |
| rev90 only (no sameday) | 17,557 | genuine return-visit retention |
| sameday only | 29,057 | |
| neither | 31,600 | |

The 타로>사주 gap is almost entirely a **same-day** phenomenon, not retention:

| metric | 타로 | 사주 | gap (타로−사주) |
|---|---:|---:|---:|
| sameday (`c_sameday>0`) | 60.6 | 45.8 | **+14.8** |
| any90 | 75.7 | 64.9 | +10.7 |
| **rev90** (report's metric) | **40.6** | **37.6** | **+3.0** |
| **revisit-only** (rev90 & no sameday) | **15.1** | **19.1** | **−4.0 (사주 WINS)** |
| 2nd-purchase-is-revisit (`has_2nd & second_sameday=0`, = R2-2's "재방문" def) | 18.9 | 25.8 | **−6.9 (사주 WINS)** |

→ On the very metric R2-2 says recommendations should target (return-visit), **사주 out-retains 타로**. 타로's "반복" edge is a *same-day "여러 장 한자리" upsell* behavior (which R2-3 itself notes: sameday 60.6), **not** a repeat/loyalty trait. The report conflates two behaviors and presents the in-session-upsell metric as evidence of a "반복형 콘텐츠 특성."

**Fix** — Re-run R2-3/R2-5/Phase 2 content claims on the revisit-only metric (`c_rev90>0 AND c_sameday=0`). Re-title: 타로 = **same-day upsell** trait; 사주 = **return-retention** trait. Both the "타로=반복형" headline and the cross-sell recommendation "사주 진입자에게 타로 추천 → 재구매율↑" (R2 종합, U-3/U-4) must be revisited — they target the wrong metric.

---

### F-2 · [HIGH] · R2-5 결론 — Simpson's paradox: within-tier 타로≥사주 but aggregate 사주 wins retention

**Claim** (R2-5 / Phase 2 (2차) point 1): "같은 가격대에서 타로 > 사주 항상 +8~12%p … 싸서가 아니라 타로라는 콘텐츠 자체가 반복형."

**Why wrong (partial)** — The within-tier direction is true *on rev90*, but the report never reconciles it with the aggregate on the retention metric. On revisit-only retention:

| tier | 타로 revonly | 사주 revonly |
|---|---:|---:|
| T1 ≤4k | 13.3 (n19,955) | 10.7 (n3,364) |
| T2 4-8k | 13.0 (n1,610) | 10.8 (n491) |
| T3 8-12k | 17.8 (n4,068) | 15.4 (n2,834) |
| T4 >12k | 20.6 (n4,968) | 19.9 (n52,018) |
| **aggregate** | **15.1** | **19.1** |

Within every tier 타로 ≥ 사주 (+0.6 to +2.6pp), yet **aggregate 사주 (19.1) > 타로 (15.1)**. This is textbook Simpson's paradox: 사주 is 88.6% concentrated in T4 (where revonly ≈ 20%), 타로 is 65.2% in T1 (where revonly ≈ 13%). The aggregate "타로 retains more" intuition is false; the within-tier "타로 edges 사주" is real but tiny and metric-dependent (vanishes on revonly in love-only, see F-5).

**Fix** — Report aggregate AND stratified together; flag the Simpson reversal explicitly. State that 타로's aggregate appeal is its *price position* (cheap, high-volume, same-day), not superior retention.

---

### F-3 · [HIGH] · R2-5 point 2 / Phase 2 (2차) — price/content hierarchy is BACKWARDS on retention; "副(price)" effect > "主(content)" effect

**Claim**: "콘텐츠 특성이 主(主), 가격도 副(副)." Price is demoted to a secondary "셀렉션" factor.

**Why wrong** — On revisit-only retention the magnitudes invert the hierarchy:

- Within-content **price swing T1→T4**: 타로 13.3→20.6 = **+7.3pp**; 사주 10.7→19.9 = **+9.2pp** (monotone, clean).
- Within-tier **content gap**: **+0.6 to +2.6pp**.

→ The price-tier effect on genuine retention is **~3–4× larger** than the content effect. Calling content the dominant ("主") lever and price a minor ("副") factor is unsupported on the metric that matters for recommendations. (On the contaminated rev90 metric the content gap looks bigger — another reason F-1's metric choice drives the wrong conclusion.)

Note also: **marginal price↔rev90 correlation ≈ 0** (Pearson r = 0.0006 overall, ignoring content); within-content r is tiny (타로 0.059, 사주 0.017). So neither "price drives repeat" nor "price is irrelevant" — price's apparent effect is almost entirely *between* content types (collinear with content), confirming the two are too entangled to cleanly separate by stratification (median 타로 1,500 vs 사주 18,000, verified below). The report's confidence that it has "분리"(separated) them is overstated.

**Fix** — Demote the causal language. State: price and content are near-collinear (medians 1,500 vs 18,000); stratification can only weakly disentangle them; on retention the price-tier gradient dominates. Do not claim content is the primary repeat driver.

---

### F-4 · [HIGH] · R2-5 / Phase 2 (2차) §269 — "same price" comparison rests on near-separated distributions (thin-tail overlap)

**Claim**: "가격이 콘텐츠와 강하게 엉킴 → 층화 필수" then proceeds to compare at "같은 가격대."

**Why partly invalid** — The price distributions are **near-separated**, so "same price tier" cells lean on each type's thin tail:

| | T1 ≤4k | T2 4-8k | T3 8-12k | T4 >12k |
|---|---:|---:|---:|---:|
| 타로 (n=30,601) | 65.2% | 5.3% | 13.3% | **16.2%** |
| 사주 (n=58,707) | 5.7% | 0.8% | 4.8% | **88.6%** |

Verified medians: 타로 median 1,500 (p25 1,200 / p75 9,000), 사주 median 18,000 (p25 15,000 / p75 20,250). The T1 cell compares 19,955 타로 vs only **3,364 사주** (사주's 6% tail); the T4 cell compares only **4,968 타로** (타로's 16% tail) vs 52,018 사주. The report's flagship rhetorical line — "가장 비싼 타로(T4)가 가장 싼 사주(T1)보다 높음 = 가격으로 설명 불가" — compares two **off-distribution tails** (16% of 타로 vs 6% of 사주). Buyers who pick expensive 타로 or cheap 사주 are atypical and likely self-select on unobserved intent/engagement; the comparison does not represent the typical 타로/사주 buyer.

**Fix** — Add cell-count caveat; restrict strong claims to cells where both types have ≥1,000 and represent ≥10% of their own mass (only T3/T4 qualify for 사주; only T1 for 타로 — i.e. there is **no tier where both types are representative**). Acknowledge the "same price" comparison is structurally weak here.

---

### F-5 · [HIGH] · R2-5 point 3 / Phase 2 (2차) "교란 3중 통제" — love-only triple control does NOT survive on retention; cells are lopsided

**Claim**: "[연애 only] 교란 3중 통제 … topic까지 고정해도 패턴 동일 — 타로>사주 유지 … 콘텐츠 효과 견고."

**Why wrong** — Recompute love-only (`f_topic=연애`) price×content:

| tier | 타로 rev90 / revonly (n) | 사주 rev90 / revonly (n) |
|---|---|---|
| T1 | 38.4 / **13.2** (18,210) | 26.5 / **14.3** (294) |
| T2 | 43.9 / 13.3 (1,360) | 41.1 / 14.9 (141) |
| T3 | 47.6 / **18.1** (3,665) | 37.1 / **15.8** (1,769) |
| T4 | 49.1 / **21.2** (4,302) | 41.1 / **20.8** (34,697) |

On **rev90** the claim holds (타로>사주). But on **revisit-only retention** the content effect **vanishes or reverses**: T1 사주 14.3 > 타로 13.2; T4 essentially tied (21.2 vs 20.8); only T3 keeps a small 타로 edge. And the cells are lopsided: love-사주 in T1 (cheap) is only **294 users (0.8% of love-사주)**; love-타로 in T4 is **15.6% of love-타로**. So "3중 통제 후에도 견고" is true only on the contaminated metric and only at thin cells — it is **not** robust.

**Fix** — Show love-only on revisit-only; report the cells (n<300 on the 사주 side at T1/T2 should be flagged). Drop "콘텐츠 효과 견고" — on retention it is not.

---

### F-6 · [MEDIUM] · R2 종합 / U-2 / U-4 — uncontrolled selection confounders unaddressed; alternative explanation quantified

**Claim**: the content_type *causes* the repeat difference ("타로라는 콘텐츠 자체가 반복형," "콘텐츠 형식(타로=반복 소비 구조)이 본질"). Recommendation: push 타로 to 사주-entry users to *raise* repeat (U-4 #2).

**Why wrong (causal)** — The analysis controls (weakly) for price and (in love-only) topic, but does **not** control for *who self-selects* 타로 vs 사주. Confirmed selection confounders the analysis does not address:

- **Age**: 타로 buyers skew young (50% <25, 36% 25-34); 사주 buyers skew older (33% <25, 52% 25-34, 11% 35-44). Age is correlated with both content choice and repeat behavior. (To the report's partial credit, F-7 shows the content direction survives a joint age×tier control — but that does not establish *causation*, only that age+price don't fully explain it.)
- **Intent/engagement/recency** (unmeasured): A user who opens the app to draw a tarot card is in a different intent state (casual, browsing, low-commitment) than one who buys an 18,000원 saju reading (deliberate, high-commitment). The same-day "여러 장" behavior (타로 sameday 60.6) reflects a *browsing/sampling intent*, not a content property. This intent plausibly drives BOTH the choice of 타로 AND the same-day multi-purchase — fully confounded, and it is exactly the dimension R2 cannot observe.

**Strongest alternative explanation (quantified)**: 타로's headline advantage = a **same-day sampling/upsell artifact** (+14.8pp sameday gap) of a low-price, low-commitment SKU, NOT a retention/repeat trait (on which 사주 wins, F-1). Pushing 타로 to 사주-entry users (a deliberate, high-commitment, older cohort) assumes content is causal; if intent drives both, the recommendation moves a sampling-format SKU to a non-sampling audience and may not transfer. Phase 3/Phase 4's own finding (사주→타로 lift 0.66/0.69, "미발생") is consistent with this confounding read: 사주 users don't drift to 타로 because their *intent state* differs, not because of an untapped opportunity. The report correctly flags this needs A/B (U-4 #2) — good — but the surrounding causal language ("콘텐츠 효과로 재구매율 상승 기대") prejudges the experiment's result.

**Fix** — Reframe content_type findings as **associations** pending the A/B. Add an explicit "uncontrolled confounders" caveat (age — partially controlled; intent/engagement/recency — uncontrolled). State the A/B is the *only* causal test and the expected-direction language should be neutral.

---

### F-7 · [LOW / VERIFIED-ROBUST] · joint age×tier control — content *direction* survives (credit where due)

I stress-tested the content claim with a joint age×price-tier control (the report only did age and price separately). On **rev90**, 타로 ≥ 사주 in every cell with both n≥100:

| age | tier | 타로 rev90 (n) | 사주 rev90 (n) | diff |
|---|---|---:|---:|---:|
| <25 | T1 | 35.7 (10,649) | 25.8 (1,301) | +9.9 |
| <25 | T3 | 46.8 (1,857) | 29.4 (867) | +17.4 |
| <25 | T4 | 48.0 (1,995) | 38.8 (17,288) | +9.2 |
| 25-34 | T1 | 41.4 (6,529) | 27.9 (1,433) | +13.4 |
| 25-34 | T4 | 44.7 (2,216) | 39.1 (27,185) | +5.6 |
| 35-44 | T1 | 50.4 (1,252) | 31.0 (387) | +19.4 |
| 45+ | T1 | 50.8 (510) | 25.6 (195) | +25.1 |

→ The *direction* (타로 ≥ 사주 on rev90) is robust to age+price jointly. **This is the strongest evidence for the report's content claim and should be added** (the report omits the joint control). Caveat: this is still on the rev90 metric (F-1) and still does not control intent (F-6), so it strengthens "association is not fully explained by age+price" but does not establish causation or survive the metric switch to retention.

---

## 3) VERIFIED CORRECT

- **Overall baselines** match R2 exactly: rev90 38.35% (R2: 38.4), sameday 50.04% (50.0), any90 67.88% (67.9), ever-2nd 73.47% (73.5). ✅
- **content_type counts**: 타로 30,601, 사주 58,707, 점성학 826, untagged 7,507 — match R2-3 exactly. ✅
- **Price medians**: 타로 1,500 / 사주 18,000 — match R2-5 §269 claim exactly. ✅
- **R2-2 figures**: 당일 50.0% (49,235 ≈ my sameday 49,235) and 재방문 23.4% (23,049 = my `has_2nd & second_sameday=0`) both reproduce. ✅ (But note these are two different metric definitions — see F-1.)
- **Within-tier content direction** 타로 ≥ 사주 (on rev90): holds in every adequately-sized cell, robust to joint age control (F-7). ✅
- **Within-content price monotonicity** "higher price → more repeat": holds cleanly on revisit-only (타로 T1→T4 13.3→20.6; 사주 10.7→19.9). Naive "cheap→repeat" is correctly rejected. ✅
- **rev90 grid** approximately reproduces (my rev2: T1 타로 38.0 / 사주 27.1; T4 타로 45.7 / 사주 38.5). The rev1 grid (T1 44.2/32.0, T4 49.3/41.5) is higher because rev1 included pay_under_750; direction identical. ✅

---

## 4) COULD NOT VERIFY

- **Phase 3/Phase 4/R2-6 transition lifts** (사주→타로 0.66/0.69, intent clusters): `master_users.csv` has 2nd-purchase columns (`s_ctype`, `s_topic`, `s_intents`, `second_sameday`) so these are recomputable, but they are outside this lens (transition, not confounding) — deferred to the transition-focused reviewer. I did not recompute them.
- **R2-5 rendered grid** (`data/rev2_price_x_content.png`): R2-5 narrates the conclusion but does not print the numeric grid in baseline.md, so I compared against my own recompute and the rev1 printed grid. The PNG itself was not read.
- **C (web-only) parallel claims** (C-3, C-5): out of scope (different cohort `c_users.csv`, not provided as the primary CSV). The same metric-contamination critique (F-1) likely applies but is unverified here.
- **chatbot_content_type tagging accuracy** (12,288 rows untagged/non-타로사주 = 12.5% of cohort): I treated tags as ground truth. If 타로/사주 tagging is noisy, the content gap could be further attenuated — unverified.
