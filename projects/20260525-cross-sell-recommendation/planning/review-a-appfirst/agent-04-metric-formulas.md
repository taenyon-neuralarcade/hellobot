# Agent-04 — Metric Formulas & Repurchase SQL Logic Review

**Scope**: A app-first analysis (baseline.md, Revision 2). Adversarial recomputation of every headline repurchase rate from `data/master_users.csv` (98,392 rows + header) against `data/master_export.sql` and the report's claims. No BigQuery executed — all figures recomputed locally with python3.

---

## 1) Verdict

**The SQL repurchase logic is sound and the column semantics are exact** — the `c_any90 = c_rev90 + c_sameday` partition holds row-by-row with **zero violations**, all 30/60/90 monotonicity holds, and every headline *rate* (rev90 38.4%, sameday 50.0%, any90 67.9%, ever 73.5%) reproduces to ±0.05%p. The content_type (R2-3) and topic (R2-4) tables reproduce exactly.

**BUT there is one serious metric-conflation defect that propagates through the analytic spine (§R2-2) and the entire transition layer (§R2-6, §U-1):** the report uses **two different "revisit" definitions** under the same word and never discloses the switch. The headline **rev90 = 38.4% (37,735 users)** is the share with a later-day purchase within 90 days. The §R2-2 "재방문 리텐션 = 23.4% (23,049명)" — declared "the analytic spine," the lever recommendations are sized against, and the base for all R2-6/U-1 transitions — is a **completely different population**: users whose *global 2nd purchase* lands on a later day, with **no 90-day cap**. The two populations differ by **14,686 users (14.9%p of N)**. This is not a rounding issue; it is a definitional substitution that makes the report's own headline (38.4%) and its "actionable revisit pool" (23%) silently incompatible.

Verdict: **logic correct, metric labeling materially misleading.** Must fix the §R2-2 framing and explicitly reconcile the 38.4% vs 23.4% figures before this drives experiment sizing.

---

## 2) Findings

### F1 · [HIGH] · §R2-2 (lines 469–478), propagating to §R2-6/§U-1 · "재방문 리텐션 23.4% (23,049명)" conflated with headline rev90 38.4%

**Claim.** §R2-2 splits the cohort into 당일 업셀 50.0% (49,235) / **재방문 리텐션 23.4% (23,049)** / 2회차 없음 26.6%, and narrates "추천이 키울 영역은 **재방문(현 23%)**." Yet R2-1/R2-3/R2-4 headline the revisit metric as **rev90 = 38.4%**.

**Why wrong + recomputed numbers.** These are two distinct metrics on the same cohort:

| Metric | CSV definition | Count | Rate | Cap |
|---|---|---:|---:|---|
| Headline **rev90** | `c_rev90 > 0` (≥1 later-day buy within 90d) | **37,735** | **38.35%** | 90d |
| §R2-2 **재방문** | `days_to_2nd > 0` (= `has_2nd=1 AND second_sameday=0`) | **23,049** | **23.43%** | **none** |

Cross-tab of the two populations:
- both: 17,557
- `rev90>0` but `days_to_2nd≤0`: **20,178** — bought *same-day* as 2nd purchase but *also* a later-day buy within 90d (3rd+). These ARE revisit-active but are excluded from the 23,049.
- `rev90=0` but `days_to_2nd>0`: **5,492** — 2nd purchase on a later day but **beyond 90 days**, so not in rev90.
- neither: 55,165.

Net: **rev90 counts 14,686 more "revisit" users than the §R2-2 figure (14.9%p of N).** The report presents 38.4% as the revisit rate everywhere (R2-1, R2-3, R2-4 column header "rev90 (재방문, 다른날)") but then tells the reader the revisit lever is "현 23%" and sizes recommendations against 23,049. A reader cannot tell which number is "the revisit population."

**Root cause.** `days_to_2nd` describes only the **global 2nd** purchase. A user whose 2nd buy was same-day but who returned later (within 90d) for a 3rd buy is a genuine revisitor (counted in rev90) but is bucketed into "당일 업셀" by §R2-2 and excluded from "재방문." Conversely, a user whose 2nd buy was 120 days out is "재방문" in §R2-2 but absent from rev90.

**Fix.** Pick one revisit definition and use it consistently. Recommended: define the revisit-lever population as `c_rev90 > 0` (37,735; 38.4%) to match the headline, and relabel the §R2-2 23,049 bucket honestly as **"2nd purchase first occurs on a later day (uncapped)"** — it is the *complement-of-sameday-2nd within ever-buyers*, not "the 90-day revisit pool." If 23,049 is intentionally the lever base, then the headline "rev90 38.4%" must be footnoted as a *different, larger* population and the recommendation sizing reconciled.

---

### F2 · [MEDIUM] · §R2-6 (lines 513–524) · love→love revisit confidence 79.4% not reproducible (CSV gives 83.8%)

**Claim.** R2-6 TOPIC transition: "love→love **79.4%** (lift1.13)" on revisit base n=23,049.

**Why suspect + recomputed.** Reconstructing the same base (`days_to_2nd>0`, 1st topic = 연애, count 2nd topic = 연애 via `s_topic`):
- base = 16,876 love-1st revisitors → love-2nd = 14,143 → **83.8%**
- tagged-only base (16,815) → **84.1%**
- using `c_rev90>0` base instead → also **83.8%**

No reconstruction lands near 79.4% — a **~4.4%p gap**. The companion R2-6 content figures, by contrast, reproduce closely (사주→타로 **26.7%** vs claim 26.5%; base 2nd 타로 **36.4%** vs claim 38.5%, +2.1%p off). The small content deltas suggest the report's transition script applies a base filter not present in the CSV columns (e.g. restricting the 2nd-purchase topic to the *later-day* purchase via menu_seq lookup rather than the global `s_topic`, or excluding untagged 2nd buys). Because `master_users.csv` only carries **global** 2nd-purchase attributes (`s_topic`/`s_ctype` = 2nd purchase regardless of day), I cannot reproduce the exact transition base the report used.

**Fix.** Publish the transition script and its base filter. If the transition 2nd-SKU is taken from `s_topic` (global 2nd) while the *population* is `days_to_2nd>0`, that is internally consistent (2nd = later day by construction) and should yield 83.8%, so 79.4% needs an explained source. Re-derive or correct.

---

### F3 · [LOW] · §R2-3 (lines 481–486) · content_type table omits 진단/기타/손금 (751 rows) — "(미태깅) 7,507" undercounts the residual

**Claim/recomputed.** R2-3 lists 타로/사주/점성학/(미태깅 7,507) only. CSV `f_ctype` also has **진단 540, 기타 135, 손금 76** (751 rows) that are neither in the four listed buckets nor in "(미태깅)" (which is exactly the 7,507 empty-ctype rows). The four listed n's (30,601 + 58,707 + 826 + 7,507 = 97,641) miss 751 rows → the table is not a complete partition of N=98,392.

**Why minor.** All four listed rates reproduce **exactly** (타로 75.7/40.6/60.6, 사주 64.9/37.6/45.8, 점성학 41.2, 미태깅 34.7). The omitted 751 rows (0.76%) don't change any conclusion (진단 rev90 37.0, 손금 46.1 — small n). Just a completeness gap.

**Fix.** Add an "기타형식 (진단/손금/기타) n=751" row or fold into "(미태깅)" and relabel as "비주력 형식 합계."

---

### F4 · [INFO] · count-column outliers — max `total_pays` = 1,954

`total_pays` ranges up to 1,954 (likely bot/test/power accounts). **No impact on headline rates** because every published rate uses a binary `>0` threshold (`c_rev90>0`, `c_sameday>0`, `total_pays>1`), so outlier magnitudes are clipped to 1. Flag only if any future metric uses *mean counts per user*; those would be outlier-sensitive.

---

## 3) Verified correct (reproduced to ±0.05%p / exact)

| Claim (location) | Report | Recomputed (CSV) | Status |
|---|---:|---:|---|
| Cohort N (R2-1) | 98,392 | 98,392 data rows | ✅ exact |
| **rev90** = `c_rev90>0` (R2-1) | 38.4% | 37,735 = **38.35%** | ✅ |
| **sameday** = `c_sameday>0` (R2-1/R2-2) | 50.0% (49,235) | 49,235 = **50.04%** | ✅ exact count |
| **any90** = `c_any90>0` (R2-1) | 67.9% | 66,792 = **67.88%** | ✅ |
| **ever 2회차** = `total_pays>1` (R2-1) | 73.5% | 72,284 = **73.47%** | ✅ |
| Partition `c_any90 == c_rev90 + c_sameday` | (implied) | **0 violations / 98,392 rows** | ✅ exact, no gap/overlap |
| Monotonicity `c_rev30≤c_rev60≤c_rev90` | (implied) | **0 violations** | ✅ |
| Monotonicity `c_any30≤c_any60≤c_any90` | (implied) | **0 violations** | ✅ |
| rev30 / rev60 / rev90 | — / — / 38.4 | **31.1 / 35.7 / 38.4%** | ✅ nested correctly |
| any30 / any60 / any90 | — / — / 67.9 | **64.3 / 66.5 / 67.9%** | ✅ |
| `total_pays>1` == `has_2nd==1` | (implied) | **0 mismatch** | ✅ |
| `second_sameday==1` ⟹ `c_sameday>0` | (implied) | **0 violation** | ✅ |
| `has_2nd==0` ⟹ `c_any90==0` | (implied) | **0 violation** | ✅ |
| Contract `revenue_krw>0` | all rows | **0 rows with f_rev≤0** | ✅ |
| R2-2 three-way split sums to N | 50.0+23.4+26.6 | 49,235 + 23,049 + 26,108 = **98,392, 0 overlap** | ✅ valid partition (but mislabeled — see F1) |
| R2-2 buckets 당일68/1-7:13/8-30:6/31-90:5/90+:8 | — | 68.1 / 13.1 / 6.3 / 4.9 / 7.6% of 2nd-buyers | ✅ |
| R2-2 median days_to_2nd = 0 | 0 | **0** | ✅ |
| R2-3 content_type rates (타로/사주/점성학/미태깅) | see table | **all exact** | ✅ |
| R2-4 topic rates (all 8 topics) | see table | **all exact** | ✅ |
| R2-6 base n=23,049 | 23,049 | 23,049 (= days_to_2nd>0) | ✅ count |
| R2-6 사주→타로 26.5% | 26.5% | **26.7%** (Δ0.2%p) | ✅ ~ |

**SQL boundary semantics — confirmed exact:**
- `c_any90` (`x.ts>f_ts AND DATE_DIFF≤90`) = `c_rev90` (`x.d>f_d AND DATE_DIFF≤90`) + `c_sameday` (`x.ts>f_ts AND x.d=f_d`), with no gap and no overlap. A later-same-calendar-day purchase (ts>f_ts) correctly lands in `c_any90`+`c_sameday` but NOT `c_rev90` — verified by the exact identity holding for all 98,392 rows.
- `DATE_DIFF ≤ 90` boundary: days_to_2nd==90 rows (40 of them) are **included** in rev90; the `<=` is inclusive as the contract states ("within 90d"). 89/90/91-day rows = 41/40/46. No row with a 1–90d later-day 2nd buy has `c_rev90==0` (0 inconsistencies), confirming the window edge is implemented as claimed.

---

## 4) Could not verify

- **F2 love→love 79.4% (R2-6 TOPIC).** CSV reconstruction gives 83.8–84.1% under every plausible base; the report's exact transition base filter (which produces 79.4% and the slightly-off 38.5% tarot base) is not derivable from `master_users.csv` because that file carries only global 2nd-purchase attributes, not the later-day-specific 2nd-SKU. Needs the transition script.
- **R2-5 price×content grid (lines 504–508).** No price-tier column in the CSV (`f_rev` exists but the tier cut points T1≤4k/…/T4>12k and the per-cell rev90 were rendered to PNG only). Not recomputed here — out of this lens's primary scope (price tiers); flag for the data/SQL-logic agent.
- **R2-7 / R2-8 age×topic and reco matrix.** Chart-only outputs; age axis present (`age`) but the matrix conf/lift cells are in PNGs. Spot-checks of the U-1 segment counts were not exhaustively run (out of primary lens).
- **Phase 1.2 year-cohort table (lines 152–156: 2024=54,568 / 2025=41,670 / 2026=5,227).** These are the **rev1 (n=101,465)** numbers; rev2 CSV gives 2024=52,789 / 2025=40,488 / 2026=5,115 (sum 98,392). The report does not republish a rev2 year-cohort table, so this is not a rev2 error — but if any rev2 narrative cites those year n's, they are stale by ~3k.
