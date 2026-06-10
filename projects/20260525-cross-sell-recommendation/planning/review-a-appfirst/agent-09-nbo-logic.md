# Agent-09 — NBO / Recommendation Logic Review (adversarial)

> Scope: Next-Best-Offer / recommendation conclusions in `planning/baseline.md` — Phase 3 종합, Phase 4 추천 매트릭스 v1, §R2-6/R2-8/R2-9, and the A·C 통합 §U-1~U-4.
> Verified against local `data/master_users.csv` (98,392 rows) + SQL only. No BigQuery. All numbers recomputed with python3.
> Reviewer stance: independent, adversarial. Findings are falsifiable and quantified.

---

## 1) VERDICT

**The recommendation matrix is, in its load-bearing conclusions, a base-rate artifact dressed as targeting, built on a biased and mislabeled subpopulation, and presented with no causal warrant.** The arithmetic is reproducible (I reproduced every U-1 cell exactly), but the *inferences drawn from it* do not follow:

1. **"연애 = universal default 2nd topic (every cell)"** is trivially true because (a) 연애 is 73.6% of ALL revisit 2nd-purchases regardless of segment, and (b) 79–93% of each cell *entered via* 연애. Strip the 연애-entrants and the 연애-2nd confidence collapses (80.9%→30.0% in 25-34×타로). The "recommendation" predicts the popularity prior and the entry topic; it carries no incremental targeting signal. **Lift of 연애-topic over its own base is ≤1.21 and is BELOW 1 in 3 of 8 cells.**
2. The matrix **optimizes confidence (popularity), not lift (incrementality)** — the wrong objective for cross-sell. Its top pick is almost always the item the user would buy anyway.
3. The "REVISIT 2nd" subset (n=23,049) that the whole rev2 matrix is built on **excludes 53.5% of users who actually have a revisit purchase**, and its `s_*` SKU is the rn=2 (mostly same-day-defined) record, not the SKU bought on return. The subset is a biased sample, not "what people buy when they return."
4. **"사주→타로 = unmet opportunity"** confuses lift<1 (genuine low affinity) with latent demand, with zero causal evidence.
5. None of the matrix is causal. Recommending the matrix output assumes *showing* an item *causes* purchase — unsupported. The deck's own caveat ("A/B로만 판별 가능") is correct but is then ignored in the U-4 priority "1. A 인앱 추천 (즉시)".

The report's relative patterns (타로>사주 retention, 연애 dominance, lifecycle by age) are real and reproducible. The **prescriptive matrix and the "universal default" / "unmet opportunity" framing are not warranted by the evidence.**

---

## 2) FINDINGS

### F1 — [CRITICAL] "연애 = universal default 2nd topic" is a base-rate artifact + entry-topic marginalization
**Location:** §U-2.1 ("연애가 보편 디폴트 — 모든 유효 셀의 1순위 주제가 연애. 채널·연령·형식 무관. 추천 엔진 baseline 룰"), §Phase4 Part2 해석 #3 ("연애는 전 세그먼트 공통 디폴트 … 안전빵 추천"), §R2-8.

**Claim:** Because 연애 is the top 2nd-SKU topic in every (age × ctype) cell, the engine should default to 연애.

**Why wrong (recomputed):**
- 연애's share of ALL revisit 2nd-purchases (the prior) = **73.6%** (16,958 / 23,049). Of all *ever* 2nd-purchases it is **72.4%**. When one topic is ~3/4 of the entire population, "most likely 2nd topic = 연애" is true *by construction* for any segment that isn't pathologically skewed. It is the popularity prior, not a learned segment signal.
- Lift of 연애-topic over its own 73.6% base, per cell:

  | cell | n | 연애-2nd conf | lift vs 73.6% | Δ vs base |
  |---|---:|---:|---:|---:|
  | <25 × 타로 | 2,825 | 88.9% | **1.21** | +15.3pp |
  | <25 × 사주 | 4,926 | 79.7% | 1.08 | +6.1pp |
  | 25-34 × 타로 | 2,075 | 80.9% | 1.10 | +7.3pp |
  | 25-34 × 사주 | 8,050 | 68.8% | **0.94** | −4.7pp |
  | 35-44 × 타로 | 479 | 74.1% | 1.01 | +0.5pp |
  | 35-44 × 사주 | 1,704 | 49.6% | **0.67** | −24.0pp |
  | 45+ × 사주 | 400 | 37.8% | **0.51** | −35.8pp |
  | 45+ × 타로 | 188 | 69.1% | 0.94 | −4.4pp |

  Max incremental lift is 1.21; **three cells are BELOW the prior**. For 사주-entrants 25+, recommending 연애 *underperforms* simply guessing the global prior.
- The matrix segments by (age × content_type) but **omits the most predictive variable — the 1st topic.** 79–93% of each cell entered via 연애, so each cell is dominated by 연애-entrants who self-complete. Removing 연애-entrants collapses the "default":

  | cell | %entered-연애 | 2nd=연애 (ALL) | 2nd=연애 (NON-love entrants) |
  |---|---:|---:|---:|
  | <25 × 타로 | 92.8% | 88.9% | **54.5%** (n=202) |
  | 25-34 × 타로 | 85.9% | 80.9% | **30.0%** (n=293) |
  | 25-34 × 사주 | 65.2% | 68.8% | **50.2%** (n=2,800) |
  | 35-44 × 사주 | 44.4% | 49.6% | **29.9%** (n=947) |

**Fix:** Drop "연애 universal default" as a finding. The single dominant predictor of 2nd-topic is 1st-topic (연애→연애 83.8% lift 1.14; 재물→연애 25.3% lift 0.34; 가족→연애 12.2% lift 0.17). Re-segment by 1st topic. For cross-sell, report **lift over the 73.6% topic prior**, not raw confidence; a "recommendation" that beats the prior by <8pp in most cells is not actionable.

---

### F2 — [CRITICAL] Matrix optimizes CONFIDENCE (popularity), which is the wrong objective for cross-sell
**Location:** §Phase4 Part2 header ("세그먼트 = 연령 × 1st content_type → **가장 가능성 높은** 2번째 SKU"), §U-1 ("가장 많이 산 2번째 SKU"), §U-4.1.

**Claim:** Recommend the highest-confidence next SKU.

**Why wrong:** The highest-confidence next item is, by definition, the item the user is *already most likely to buy unaided*. Cross-sell value is **incremental** purchase the user would not otherwise make — i.e., high *lift*, not high confidence. The matrix's top pick is 연애+(entry format) in 7 of 8 cells, which:
- is what the entry-topic majority self-completes to anyway (F1), and
- the deck even notes "안전빵" — i.e., the recommendation is deliberately the safe, already-likely option.

Recommending the already-most-likely SKU cannot move behavior; at best it confirms it. The "lift" column that *is* shown (1.29–2.01) is computed against a **topic+ctype combined-SKU base** (e.g. 연애+타로 base = 31.4%), which mechanically inflates the number by splitting the denominator on format. Against the honest topic prior the same cell is lift **0.86**, not 2.01:

```
<25×타로 conf 63.0% → lift vs combined-SKU base (31.4%) = 2.01   [reported]
                    → lift vs 연애-topic base   (73.6%) = 0.86   [honest, <1]
```

**Fix:** State the objective explicitly. For incrementality, rank candidate 2nd-SKUs by lift over the appropriate marginal (topic prior for topic recs; format-conditional base for format recs) — NOT raw confidence. The current matrix would recommend, to a 연애-entrant, the thing they were going to buy regardless.

---

### F3 — [CRITICAL] The "REVISIT 2nd" subset that the whole rev2 matrix rests on is biased and mislabeled
**Location:** §R2-6 ("REVISIT 2회차 기준으로 재계산, n=23,049"), §R2-2 ("재방문 리텐션 23.4% (23,049명)"), §U-1 ("기준: 재방문(익일+) 2번째 구매").

**Claim:** The matrix is built on "the 2nd purchase made on a return visit (next day or later)," modeling what users buy when they come back.

**Why wrong (recomputed):** The subset is defined as `has_2nd=1 AND second_sameday=0`. But `s_topic`/`s_ctype` is the **rn=2 (chronologically next) purchase** from `master_export.sql` (`ROW_NUMBER() … ORDER BY event_timestamp`), and `second_sameday=0` only means *that rn=2 row* fell on a different day.
- **Users with ANY revisit in 90d: 37,735. Subset captures only 23,049 → 53.5% of true revisiters are EXCLUDED.** Every user who bought an extra item on day-1 has `second_sameday=1` and is dropped — *even though many of them returned later and bought again*. Their first different-day repeat SKU is invisible to the matrix.
- Verified: **0 rows** have `second_sameday=0 AND c_sameday>0`. So the subset is exactly "users whose first repeat purchase was day-different," i.e. **low day-1-engagement users** — a non-random slice. The matrix therefore does NOT describe "what people buy on return"; it describes "the 2nd SKU of the subpopulation that bought nothing else on day 1."
- The headline "재방문 리텐션 23.4%" (23,049/98,392) likewise undercounts: the share with ≥1 revisit in 90d is 37,735/98,392 = **38.4%** (which, not coincidentally, equals the reported rev90). The 23.4% is "second_sameday=0," not "has a revisit."

**Fix:** To model the return purchase, define the 2nd-purchase SKU as *the first purchase on a later calendar day* (`days_to_2nd>0`'s SKU), not rn=2 filtered post-hoc. This requires a column the export does not provide (the SKU of the first different-day purchase), so the matrix **cannot currently be computed correctly** from this CSV — it needs a re-export. Flag that 23,049 is a biased 46.5% slice of revisiters, not the revisiter population.

---

### F4 — [HIGH] "사주→타로 lift 0.68 = 미개척 기회 (unmet opportunity)" is an interpretive leap
**Location:** §Phase3 CONTENT transition ("사주→타로 미발생 … 미개척 기회"), §Phase3 종합 #3 ("최대 미개척 기회"), §R2-6, §Phase4 ★, §U-4.2, §C-5.

**Claim:** 사주 buyers go to 타로 at lift 0.66–0.69 (below average); combined with 타로's retention edge, this is the "largest unmet opportunity" to push via recommendation.

**Why wrong:** A lift <1 is the data telling you 사주 buyers go to 타로 *LESS* than a random buyer — i.e., evidence of **low cross-format affinity / format stickiness**, which the report itself documents ("콘텐츠 선호는 topic보다 고착성이 더 강함"). Reading an under-represented transition as latent demand is exactly backwards: under-representation is equally (more) consistent with "사주 users don't want 타로." Recomputed content transition (revisit set):

```
overall base: 타로 36.4%  사주 50.6%
1st=타로 (n=5,786):  →타로 63.9% (lift 1.76) | →사주 26.5% (lift 0.52)
1st=사주 (n=15,144): →타로 26.7% (lift 0.73) | →사주 60.6% (lift 1.20)
```

Both formats are *strongly self-sticky*. The observational "engagement" signal the report leans on (사주→타로 buyers look more active) is **selection, not opportunity**: among 사주-entry revisiters, those who went to 타로 have mean c_rev90 = 2.80 vs 2.02 for 사주→사주 — but these are the already-heavier users who explored a second format, not proof that nudging 사주 users to 타로 raises retention. The report acknowledges "둘 중 무엇인지는 A/B로만 판별 가능" — which means **it is NOT yet an opportunity; it is an untested hypothesis.** Calling it "최대 미개척 기회" and listing it as U-4 priority #2 overstates it.

**Fix:** Demote from "opportunity" to "hypothesis pending experiment." State plainly that lift 0.69 is, on its face, evidence of *low affinity*; the opportunity framing rests entirely on an unproven causal assumption.

---

### F5 — [HIGH] None of the matrix is causal; recommending it assumes exposure causes purchase
**Location:** §Phase3 종합, §Phase4 종합 (rules A/B/C), §U-3, §U-4 ("1. A 인앱 추천 (즉시, 효과高·난이도低)").

**Claim:** Rules A (연애 후속), B (연령맞춤), C (사주→타로) are executable recommendations; A is "즉시, 효과高."

**Why wrong:** The entire matrix is built on **what 2nd-buyers DID** in observational logs. A recommendation engine acts by *showing* an item and assuming the show *causes* the purchase. The matrix has zero counterfactual: it cannot distinguish "users buy 연애 again because they'd buy it anyway" (true, per F1) from "showing 연애 increases 연애 purchase" (untested). Rule A in particular recommends the already-dominant self-completion path (F1/F2) — the most likely outcome of deploying it is **no measurable lift**, because you're recommending what already happens. The report is internally inconsistent: it correctly demands A/B for Rule C but exempts Rule A ("효과高·난이도低") despite Rule A having the *weakest* incremental case.

**Fix:** Every rule needs A/B validation with a holdout before any "효과高" claim. Rank experiments by *expected incrementality*: Rule A (recommend the already-likely item) has near-zero expected lift and should be the *control-like* baseline, not the #1 ship. The matrix is a *prior over behavior*, not evidence for an intervention.

---

### F6 — [MEDIUM] "format retention only for A young 타로, others converge to 사주 (카탈로그 다수 효과)" — the stated mechanism is FALSE
**Location:** §U-2.2 ("형식은 A 저연령 타로에서만 유지 … 그 외는 2번째가 사주로 수렴(**카탈로그 다수 효과**)"), §U-1 note ("사주가 카탈로그 다수라 재방문 시 사주로 회귀").

**Claim:** Non-(young-tarot) cells converge to 사주 as 2nd because 사주 has more catalog SKUs, raising the chance any 2nd purchase is 사주.

**Why wrong (recomputed):** 타로 has **more** distinct SKUs than 사주, not fewer:
```
distinct menu_seq purchased as 2nd:  타로 651 | 사주 346
distinct menu_seq as 1st purchase:   타로 575 | 사주 316
```
The convergence-to-사주 is real but the *cause* is the **opposite** of stated: 사주 is the entry majority (59.7% of first purchases) and formats are self-sticky (F4), so the marginal 2nd-purchase skews 사주 because most users *entered* 사주 — not because 사주 has a bigger catalog. The "catalog-size artifact" explanation is factually inverted.

**Fix:** Replace the mechanism with the correct one: 사주 dominance in 2nd-purchases = entry-format base rate (59.7%) × strong format self-stickiness (사주→사주 lift 1.20). Catalog size, if anything, favors 타로 and would push the *other* way. The "타로 retention only for young 타로" observation itself is fine (it just reflects 타로-entry + 타로 self-stickiness), but it is a base-rate/entry artifact, not a discovered retention property of "young 타로."

---

### F7 — [MEDIUM] Reported transition base rates are inconsistent across sections (which prior is the lift denominator?)
**Location:** §R2-6 ("base 2nd: 타로38.5%/사주43.2%"), §Phase3 ("base: 2nd=타로 38.7% · 사주 41.8%"), §C-5 ("base 24.3%→16.4%"), §U-1 lift column (combined-SKU base).

**Why wrong:** I cannot reproduce 타로38.5/사주43.2 from any clean subset:
```
full revisit set:        타로 36.4% / 사주 50.6%
valid-ctype revisit:     타로 41.4% / 사주 57.6%
tarot+saju-only revisit:  타로 41.8% / 사주 58.2%
EVER 2nd (incl sameday): 타로 43.8% / 사주 46.0%   ← closest to reported 38.5/43.2? no clean match
```
The reported pair sits between the "ever" and "revisit" definitions, suggesting the lift denominators mix the same-day-inclusive base with the revisit-restricted numerators (F3). When numerator and denominator come from different populations, the lift is uninterpretable. The U-1 matrix additionally uses a *third* base (combined topic+ctype SKU), so "lift" means three different things across the document.

**Fix:** Pin ONE base population per lift table and state it (n + definition) in the caption. Recompute all lifts against that single marginal. The cross-section inconsistency (±5pp in the base) is large enough to flip borderline lift<1/>1 calls (e.g. 35-44×사주, 45+×타로).

---

### F8 — [LOW] Contract/SQL mismatch: phase3_export uses `pay_%`, master uses `pay_for_%`
**Location:** `data/phase3_export.sql` L7 (`event_name LIKE 'pay_%'`) vs `data/master_export.sql` L7 (`event_name LIKE 'pay_for_%'`); rev2 claims pay_for_% only.

**Why it matters here:** The Phase 3/Phase 4 transition matrices (the rev1 numbers: love→love 76.5%, 사주→타로 0.66, etc.) were built from `phase3_users.csv` which by SQL includes `pay_under_750` (83원 micro-txns). The rev2 section re-derives from `master_users.csv` (pay_for_% only) and claims results are "사실상 동일." For NBO purposes this is minor (the relative patterns survive), but any rev1 transition number quoted as evidence (e.g. Phase4 Part1 love-intent lifts, which feed Rule A) is on the contaminated definition unless re-derived. The Phase 4 love-intent matrix is NOT recomputed in rev2 (R2-6 only spot-checks it: "rev1과 동일").

**Fix:** Note explicitly which matrices are pay_for_%-clean. The love-intent cluster (속마음↔썸, feeds Rule A) should be re-run on master_users to confirm before it's cited as actionable.

---

## 3) VERIFIED CORRECT

- **U-1 matrix arithmetic reproduces exactly.** Rebuilding (age-bucket × f_ctype → top s_topic+s_ctype) on the second_sameday=0 subset gives the identical conf/lift for all 8 A cells: <25×타로 63.0%/2.01, <25×사주 41.5%/1.29, 25-34×타로 51.3%/1.63, 25-34×사주 38.2%/1.19, 35-44×타로 50.3%/1.60, 35-44×사주 24.2%/0.75, 45+×사주 19.2%/0.61. The pipeline is internally consistent; the *interpretation* is the problem, not the math.
- **연애 dominance is real** (73.6% of revisit 2nd, 72.4% of ever 2nd) — but it's a prior, not a segment signal (F1).
- **Format self-stickiness is real and strong** (타로→타로 lift 1.76, 사주→사주 lift 1.20; both >1).
- **"Lower age → higher lift"** (U-2.3) is directionally correct in the combined-SKU lift column (<25×타로 2.01 is the max; 45+ cells <1). But the magnitude is an artifact of the combined-SKU denominator (F2) and of younger users being more 연애-concentrated; against the topic prior the age gradient mostly vanishes.
- **재물·가족 = 1회성 / same-family stickiness** (money→money lift 8.5, family→family lift 31; →연애 lifts 0.34/0.17) — reproduced, sound.
- Revisit subset count **23,049 matches** the report's R2-2 figure; the discrepancy is in what that number *means* (F3), not the count itself.

---

## 4) COULD NOT VERIFY

- **Reported transition base "타로38.5%/사주43.2%" (R2-6)** — does not match any clean recomputation (F7). Need the exact base population the report used.
- **rev1 Phase 3/4 transition numbers** (love→love 76.5%, marriage→marriage lift 2.9, money lift 9.0, love-intent cluster lifts 3.44/2.46/6.55) — these are from `phase3_users.csv` (not provided; built on `pay_%` incl. pay_under_750 per phase3_export.sql L7). Could not recompute from master_users.csv because the love-intent transition needs the intents field cross-tab on the love→love revisit subset, and rev2 did not re-export those cells. R2-6's "rev1과 동일" is asserted, not shown.
- **C (web-only) matrix (U-1 right half, §C-5 사주→타로 0.68)** — `c_users.csv` not in scope/not read; cannot independently verify the C cells or the A≈C parity claim. The structural critiques (F1–F5) apply equally to C by construction, but the C numbers themselves are unverified here.
- **Causal validity of any rule** — by definition cannot be verified from observational logs; requires the A/B the report defers (F5). This is the central unverifiable on which the entire prescriptive layer rests.
- **`sameday` over-count** (flagged as ISS candidate in Phase 1.2 — "연속결제/번들이 동일일 다건으로 과대 가능") is unresolved and directly contaminates F3: if same-day bundles inflate `second_sameday`, the revisit-subset exclusion bias is even worse than 53.5%.
