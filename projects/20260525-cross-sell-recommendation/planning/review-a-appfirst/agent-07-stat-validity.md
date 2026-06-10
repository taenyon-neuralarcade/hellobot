# Agent-07 — Statistical Validity & Small-Sample Review

> Adversarial, independent review of **A 앱퍼스트 cross-sell analysis (REVISION 2)** in
> `planning/baseline.md`. Lens: small-sample overreach, missing uncertainty, multiple-comparison
> risk, overinterpreted point estimates. All numbers recomputed locally from
> `data/master_users.csv` (98,392 rows + header). Wilson 95% CIs computed by this reviewer.
> No BigQuery run. Scripts: `/tmp/stat_review.py`, `/tmp/matrix_23k.py`, `/tmp/stat_deep.py`,
> `/tmp/stat_trans.py`, `/tmp/stat_love.py`, `/tmp/final_check.py`.

---

## 1) Verdict

**Conditional pass on the headline numbers; FAIL on uncertainty discipline and on one load-bearing definitional inconsistency.**

The large-N headline figures (rev90 38.4%, sameday 50.0%, any90 67.9%, ever-2nd 73.5%, content-type
rev90 ranking) reproduce **exactly** from the CSV and are statistically tight (CI half-widths ±0.3–0.6pp).
The directional conclusions (타로>사주, 연애 dominance, 재물·가족 1회성, 사주→타로 under-represented) are
real and survive significance testing. **However**, three systemic problems undermine the report as a
decision document:

1. **The report reports zero confidence intervals, n-adjusted significance, or multiple-comparison
   correction anywhere** — every rate and lift is a bare point estimate, including cells with n<200 and
   CI half-widths of ±5–10pp. This is a Major systemic gap given that the recommendation matrix and the
   "lower-age→higher-lift" / "타로>사주 in every cell" stories rest on small cells.
2. **The "23,049 재방문 2회차" base used for the entire transition + recommendation matrix (R2-6, R2-8,
   U-1) is NOT the rev90=38.4% (37,735) population.** It is a *different, smaller, and biased* subset
   (`has_2nd & days_to_2nd>0`, no 90-day cap) that **drops 14,686 users who revisited within 90 days but
   whose 2nd-ever purchase was same-day**. The report conflates these two definitions and labels the
   narrower one "재방문 리텐션." This is a Critical internal inconsistency.
3. **Winner's-curse / multiple comparisons**: the "<25 타로 lift 2.01 = strongest cell" headline is the
   max of ~300 scanned matrix cells (4 ages × 2 ctypes × ~38 2nd-SKUs) plus 64 topic-transition cells +
   36 intent cells. Extremes from the smallest cells are expected to be extreme by chance; no correction
   or shrinkage is applied.

The relative-pattern conclusions are probably right, but several **specific ranked/monotonic claims are
not statistically distinguishable from noise**, and the matrix is built on a mislabeled base.

---

## 2) Findings

### F-1 · [CRITICAL] · §R2-2, §R2-6, §R2-8, §U-1 · "재방문 2회차 = 23,049" base ≠ rev90 population

**Claim.** R2-2: "재방문 리텐션 23.4% (23,049명)". R2-6/R2-8/U-1: all transition + matrix analysis is "★
REVISIT 2회차 기준으로 재계산, n=23,049." The headline (R2-1) separately states **rev90 = 38.4%**.

**Why wrong (recomputed).** These are two different populations:

| Definition | CSV predicate | count | % of N |
|---|---|---:|---:|
| **rev90 (headline 38.4%)** | `c_rev90 > 0` (≥1 revisit purchase within 90d) | **37,735** | 38.4% |
| **matrix base "23,049"** | `has_2nd=1 AND days_to_2nd>0` (rn=2 purchase on a different day, **no 90d cap**) | **23,049** | 23.4% |
| diff-day rn=2 within 90d | `has_2nd=1 AND 0<days_to_2nd≤90` | 17,557 | 17.8% |

The matrix cells reproduce **exactly** only under the 23,049 definition (verified: every U-1 A-channel
cell n, conf, lift matches to the decimal — `/tmp/matrix_23k.py`). So the matrix is genuinely built on
23,049, **not** on rev90's 37,735.

The two sets differ by **14,686 users**. The dropped users had a within-90d revisit purchase (so they
ARE rev90 revisitors) but their *2nd-ever* purchase (rn=2) landed same-day, so the matrix excludes them.
These are precisely the high-value "same-day upsell **then** later revisit" users (20,178 users, 20.5%,
have both). The matrix therefore studies a subset that is **biased away from the most engaged buyers**
while being labeled as "the revisit retention population." 23,049 also has **no 90-day horizon** (a rn=2
purchase 400 days later counts), so it is not even a clean 90-day metric.

**Fix.** Pick one definition and state it. If the lever is "grow rev90 revisit," build the matrix on the
37,735 `c_rev90>0` set (and define the "2nd SKU" as the *first revisit purchase*, not rn=2). If keeping
rn=2, relabel 23,049 as "users whose 2nd-ever purchase was on a later day (any horizon)" and stop calling
the 50/23 split a clean same-day-vs-revisit partition (the two overlap by 20,178). Re-derive R2-6/R2-8/U-1.

---

### F-2 · [MAJOR] · entire REVISION 2 + U-section · Systematic absence of uncertainty (no n on rates, no CI, no significance)

**Claim.** Every table in R2-3, R2-4, R2-6, R2-7, R2-8, U-1 reports bare point rates/lifts. Conclusions
like "타로>사주", "사주→타로 lift 0.69 미개척", "저연령일수록 lift↑", "45+ 약함" are stated as facts.

**Why wrong.** Some of these are on cells with n=188–573 where the Wilson CI half-width is ±3–7pp — wide
enough to overturn the stated ranking. The report gives the reader no way to tell a ±0.3pp headline from a
±7pp small-cell estimate; they are typeset identically. For a document explicitly feeding A/B prioritization
(U-4) this is a material omission. Recomputed CIs below show several claims are inside the noise band.

**Fix.** Add n and 95% CI (Wilson) to every rate/lift cell, or at minimum flag and grey-out cells with
n<300 / CI half-width >3pp. Add a two-proportion test for each headline ranking claim.

---

### F-3 · [MAJOR] · §U-2, §U-3 · "저연령일수록 conf·lift 높음" monotonic story is not monotonic and CIs overlap

**Claim.** U-3: "저연령일수록 conf·lift 높음 — <25 A 타로 63%(2.01)가 최강 셀. 고연령(45+)·35-44 사주는 lift<1."

**Why wrong (recomputed lift + Wilson CI on conf, base treated fixed):**

1st = **타로**, top-2nd = 연애+타로:

| age | n | conf | lift | lift 95% CI | monotonic? |
|---|---:|---:|---:|---|---|
| <25 | 2,825 | 63.0% | 2.01 | [1.95, 2.06] | — |
| 25-34 | 2,075 | 51.3% | 1.63 | [1.57, 1.70] | drop ✓ |
| 35-44 | 479 | 50.3% | 1.60 | [1.46, 1.75] | **CI overlaps 25-34** |
| 45+ | 188 | 52.1% | 1.66 | [1.43, 1.88] | **non-monotonic (↑) + CI overlaps** |

The 타로 lift is **not monotonically decreasing** — 35-44 (1.60), 45+ (1.66) are statistically
indistinguishable from each other and from 25-34 (all CIs overlap). The clean monotone story holds only
for the <25→25-34 step. The "45+ 약함" claim is true for **사주** (45+ 사주 lift 0.61, CI [0.50,0.75], <1
with confidence) but the report's matrix actually shows 45+ **타로** at lift 1.66 — i.e. high-age tarot
entrants are NOT weak, contradicting the blanket "고연령 약함." The 45+ 타로 cell (n=188) is explicitly
suppressed in U-1 ("n<200") yet the directional 고연령-약함 narrative implicitly absorbs it.

**Fix.** Restate as "lift drops sharply <25→25-34, then flat within noise for 타로; only 사주 shows
continued decline (45+ <1)." Do not present 타로 lift as monotone in age.

---

### F-4 · [MAJOR] · §U-2, §U-3, §R2-8 · Multiple comparisons / winner's curse on "strongest cell" claims

**Claim.** U-3: "<25 A 타로 63%(2.01)가 최강 셀." Phase 3/R2-6: "money→money lift 8.5, family→family lift 31,
study 7.7" highlighted as the extreme diagonals.

**Why wrong.** The matrix scan space is ~**304 candidate cells** (4 ages × 2 ctypes × ~38 distinct 2nd-SKUs),
plus an 8×8=64-cell topic-transition matrix and a 6×6=36-cell intent matrix. The report surfaces the
**maxima** of these scans ("강점 셀", "최강", "고lift 대각선") with no familywise correction or shrinkage.
By construction the most extreme lifts will come from the smallest-n cells (family 1st-n=395, money 1st-n=454),
where sampling variance is largest — classic winner's curse. The family→family "lift 31~43" is real
(recomputed 34.1, CI [30.9,37.2]) but mechanically inflated by a tiny base (1.57% of 2nd-SKUs are family);
a lift of 34 on n=395 is an extreme order statistic, not a reliable effect size to plan around.

**Fix.** Report the number of cells scanned; apply Benjamini-Hochberg or empirical-Bayes shrinkage to
lifts before ranking; or restrict "strongest cell" claims to pre-registered cells. Caveat that small-base
diagonal lifts (family/money/study) are inflated and not directly comparable to the large-n love lift.

---

### F-5 · [MODERATE] · §R2-7 / Phase 2(2차) · "연애는 고연령일수록 재구매↑" — thin high-age cells

**Claim.** Phase 2(2차): "연애는 고연령일수록 재구매↑ (45.→50+ 50~54%)."

**Why partly wrong / overstated (recomputed age×topic=연애 rev90):**

| age | n | rev90 | 95% CI |
|---|---:|---:|---|
| <25 | 31,924 | 38.9% | [38.3, 39.4] |
| 25-34 | 31,594 | 42.4% | [41.8, 42.9] |
| 35-44 | 5,003 | 47.2% | [45.8, 48.6] |
| 45+ | 1,142 | 48.5% | [45.6, 51.4] |

The trend is **real and monotone** here (CIs of <25, 25-34, 35-44 don't overlap), so direction is sound.
But the rev1 prose "50~54%" overshoots — recomputed 45+ is 48.5% [45.6,51.4], and the top of the band only
just touches 50%. The 50+ sub-band the report cites is even thinner. Minor overstatement; trend OK.

---

### F-6 · [MODERATE] · §Phase 2(1차) topic×content_type · Sub-100 cells presented alongside reliable ones

**Claim.** Phase 2(1차): table gives 결혼-타로 36.9 (n179), 총운-타로 42.9 (n140), 재물-타로 "n<100",
used to argue "재물=topic 효과" and "같은 연애라도 타로>사주."

**Why caution (recomputed rev2 CSV):**

| cell | n | rev90 | 95% CI half-width |
|---|---:|---:|---:|
| 연애-타로 | 27,537 | 41.6% | ±0.6pp |
| 연애-사주 | 36,901 | 40.8% | ±0.5pp |
| **재물금전-타로** | **98** | 36.7% | **±9.4pp** |
| 결혼-타로 | 192 | 32.8% | ±6.6pp |
| 총운-타로 | 146 | 34.2% | ±7.6pp |

The 연애 타로>사주 gap (41.6 vs 40.8) is **only 0.8pp** — far smaller than rev1's claimed "46.9 vs 43.9"
and well within a fraction of either CI; this specific "타로>사주 within 연애" claim is **not significant
in rev2** (overlapping CIs). The headline 타로>사주 holds at the *aggregate* content-type level (40.6 vs
37.6, z=8.7, p≪0.001 — F-V1), but the report's stronger "even within 연애, 타로>사주" sub-claim does not
survive at rev2 numbers. The tiny 재물-타로/결혼-타로/총운-타로 cells (±7–9pp) cannot support any ranking.

**Fix.** Drop or asterisk the within-연애 타로>사주 micro-gap; mark all n<200 topic×content cells as
indicative only.

---

### F-7 · [MODERATE] · §U-1 · 45+ cells (n=188, n=400/573) used for directional claims despite suppression

**Claim.** U-1 suppresses 45+ 타로 (n=188, "n<200") but keeps 45+ 사주 (n=400) at conf 19.2% lift 0.61,
and U-3 generalizes "고연령(45+) lift<1 추천 효과 약함."

**Why caution.** 45+ 사주 (n=400): conf CI ±3.9pp, lift CI [0.50, 0.75] — credibly <1, so that specific
cell is OK. But the suppressed 45+ 타로 (n=188) actually recomputes to lift **1.66** [1.43,1.88] — i.e.
>1, contradicting the blanket "45+ 약함." Suppressing the cell that contradicts the narrative while
keeping the one that confirms it is selective. The n=188/400 cells are too thin to anchor an age-tier
recommendation rule regardless.

**Fix.** Either show both 45+ cells with CIs or drop age-45+ recommendations entirely for thin n; don't
generalize "고연령 약함" from one suppressed and one retained cell.

---

## 3) Verified correct

- **rev90 = 38.4%** → recomputed `c_rev90>0` = 37,735 / 98,392 = **38.4%**, Wilson CI [38.0, 38.7], ±0.3pp. ✓
- **sameday = 50.0%** → `c_sameday>0` = 49,235 = **50.0%**, CI [49.7, 50.4]. ✓
- **any90 = 67.9%** → 66,792 = **67.9%**. ✓  **ever 2nd 73.5%** → has_2nd=1 = 72,284 = **73.5%**. ✓
- **N = 98,392** (rows match exactly); age fill 98.2% (R2-1 "age 채움" consistent). ✓
- **R2-3 content_type rev90**: 타로 40.6% (n30,601), 사주 37.6% (n58,707), 점성학 41.2% (n826), 미태깅
  34.7% (n7,507) — all reproduce to the decimal. 타로>사주 difference **z=8.7, p≪0.001 SIGNIFICANT**. ✓
  (counts 타로 30,601 / 사주 58,707 also match R2-3.) **[F-V1]**
- **U-1 matrix (A channel)**: every cell n, conf, lift reproduces **exactly** under the
  `has_2nd & days_to_2nd>0` (23,049) definition. The arithmetic is correct *given that base* — the problem
  is the base label/definition (F-1), not the computation.
- **R2-6 content transition direction**: 사주→타로 under-represented (lift <1) confirmed (recomputed
  ~0.73; report 0.69 — same conclusion, see CNV-1 for the small base discrepancy). 타로 self-stick lift >1
  confirmed (~1.76). Direction sound. ✓
- **R2-6 topic diagonal lifts**: family/money/study self-stick lifts are large and real (recomputed 34.1 /
  8.7 / 7.8 vs claimed ~31 / 8.5 / 7.7) — directionally correct, though small-base inflated (F-4).

---

## 4) Could not verify / discrepancies needing the author's exact script

- **CNV-1 · R2-6 content-transition base.** Report claims base 2nd=타로 38.5% / 사주 43.2%; my recompute on
  the 23,049 set gives 36.4% / 50.6% (and 사주→타로 lift 0.73 vs claimed 0.69). The *direction* (lift<1)
  matches, but the base shares differ ~2–7pp. Likely the report excludes untagged-2nd rows or uses a
  topic-restricted denominator for the content transition. The R2-6 base numbers could not be reproduced
  exactly; recommend the author publish the exact denominator filter.

- **CNV-2 · Love-intent transition (R2-6 / Phase 4).** Report claims love→love revisit **n=12,068**; my
  recompute (`f_topic=연애 & s_topic=연애` within the 23,049 set) gives **14,143**. Diagonal lifts are in
  the ballpark (재회 2.5 vs 2.6, 썸 4.6 vs 4.6) but conf% diverges materially (재회 61.1% vs claimed 68.8%,
  궁합 13.7% vs 23.8%). This is sensitive to the multilabel intent tokenization rule (the report describes
  `[,\s]+` normalization loosely) and to whether the 90-day cap is applied. Could not reproduce the intent
  matrix exactly; the self-stick *direction* holds but the specific conf/lift values are unverified and
  the n is off by ~17%.

- **CNV-3 · Phase-2 "price × content" stratification tables** (T1–T4 × 타로/사주) reference render PNGs and
  a tier definition (≤4k/4-8k/8-12k/>12k) computed in `/tmp/analyze_p2b.py`, which is not in the repo. The
  rev90-by-tier values were not independently reproduced here; the small tiers (사주 T2 n483, 타로 T2
  n1,573) carry wide CIs and the "비쌀수록 rev90↑ within 사주" claim should be CI-checked before relying on it.

- **CNV-4 · C-channel and A·C unified C-side numbers** depend on `data/c_users.csv` (289,983 rows), which
  was out of scope for this CSV-only review. Not verified.

---

### Reviewer's recomputation note
All A-channel figures above are from `data/master_users.csv` only (no BQ). Wilson 95% CI, two-proportion
z-tests, and lift CIs (base treated as fixed — conservative) computed by this agent. The headline numbers
are solid; the decision-grade weaknesses are (1) the 23,049-vs-37,735 base conflation, (2) zero published
uncertainty, and (3) extreme-cell selection without correction.
