# Agent-02 Review — Cohort Definition, Observation Window & Maturity

> Independent adversarial review of the "A app-first cross-sell analysis (Revision 2)".
> Lens: temporal design — left-censoring/survivorship, maturity, 90-day window consistency, 2-year pooling, and the 101,465↔98,392 gap.
> Method: recompute against local `data/master_users.csv` (98,392 rows) + SQL `data/master_export.sql` + `data/phase1_2_baseline_a*.{sql,csv}`. **No BigQuery run.** All numbers below are reproduced locally.

---

## 1) Verdict

**Conditionally sound on headline counts, but the revisit/transition base is mis-specified and the maturity/censoring caveats present in rev1 were silently dropped in rev2.**

The headline cohort sizing and rate metrics (N=98,392; rev90=38.4%; sameday=50.0%; any90=67.9%; ever 2nd=73.5%; topic match 99.7%) all reproduce **exactly** from the CSV — the arithmetic is trustworthy. The cohort window logic (t=0=f_d, DATE_DIFF≤90, APP-first, `pay_for_%` & revenue>0) is correctly and consistently implemented in SQL, and there is no evidence of catastrophic ETL lag (table appears loaded to ~late-May 2026).

**But three temporal-design problems undermine the analysis as written:**
1. The "재방문 리텐션 = 23,049 (23.4%)" headline and the R2-6 transition base of n=23,049 are **NOT the 90-day revisit pool** (which is 37,735 / 38.4%). The 23,049 figure (a) has **no 90-day bound** — 23.8% of it sits beyond the window — and (b) **drops 20,178 genuine 90-day revisitors** who upsold sameday then revisited at purchase #3+. So the transition analysis runs on only ~61% of actual revisitors plus out-of-window noise.
2. The rev2 baseline **removed the per-year cohort breakdown** that rev1 carried, thereby hiding a clear right-censoring/cohort-decline signal: rev90 falls 2024=41.3% → 2025=35.8% → 2026=28.3%. The 2026 cohort is still labeled nowhere in rev2.
3. The 2-year pooled headline (38.4%) masks a **5.5pp year-over-year rev90 decline between two supposedly-mature cohorts (2024 vs 2025)** that the 90-day window cannot explain by censoring — i.e., a real comparability problem the report does not flag.

None of these overturn the *relative* conclusions (taro>saju, love dominance, etc.), but they materially affect the *absolute* "how big is the revisit opportunity" framing, which is the analysis's stated spine ("R2-2. 분석의 척추").

---

## 2) Findings

### F1 · [HIGH] · R2-2 headline + R2-6 transition base · "재방문 리텐션 23.4% (23,049명)" / transition "n=23,049"
**Claim/code:** R2-2 presents "재방문 리텐션 = 50.0% 당일 / 23.4% (23,049명) 재방문 / 26.6% 없음" as the analysis spine, and R2-6 recomputes all transitions on "REVISIT 2회차 기준, n=23,049." The contract states rev90 (revisit within 90 days) = 38.4% is the revisit headline.

**Why wrong + recomputed numbers:**
- `23,049` = users with `has_2nd=1 AND second_sameday=0` (their **2nd purchase**, i.e. `rn=2`, is on a different day). Recomputed: **23,049 (23.43%)** ✓ the number is reproducible, but it is the **wrong population** for a 90-day revisit metric.
- The true 90-day revisit pool is `c_rev90>0` = **37,735 (38.35%)** — i.e. anyone with *any* later-day purchase within 90 days.
- The 23,049 base is wrong in **two directions simultaneously**:
  - **No 90-day bound.** Of the 23,049, `days_to_2nd` distribution: 1–7d 41.0%, 8–30d 19.7%, 31–90d 15.4%, **>90d 23.8% (5,492 users)**. So **5,492 "revisitors" have their 2nd purchase outside the 90-day window** the cohort is supposedly observed over.
  - **Drops genuine in-window revisitors.** 20,178 users upsold same-day at purchase #2 but then revisited (3rd+ purchase) within 90 days — they are `c_rev90>0` but `second_sameday=1`, so they are **excluded** from the 23,049 base. The transition base therefore captures only **23,049 / 37,735 = 61%** of actual 90-day revisitors.
- Net: R2-6's "REVISIT 2회차" transition matrices are computed on a population that is neither "the 90-day revisit cohort" nor cleanly "the first revisit purchase." The 50%/23%/27% split in R2-2 also doesn't sum against rev90: sameday=50.0% (49,235) and rev90=38.4% (37,735) **overlap** (a user can be both), so they are not a clean partition — yet R2-2 presents 50/23/27 as a partition summing to 100%.

**Fix:** Pick one explicit revisit definition and apply it everywhere:
  (a) If "revisit = any different-day purchase within 90d," use **37,735 / 38.4%** as the headline *and* the transition base, and define the transition target as "first different-day purchase within 90d" (not necessarily `rn=2`).
  (b) If "revisit = the 2nd purchase, when different-day," then **bound it to ≤90d** → 17,557 / 17.8% (recomputed), not 23,049.
  Re-derive the R2-2 partition as a true 3-way split (sameday-only / different-day-within-90 / no-90d-2nd) with non-overlapping definitions.

---

### F2 · [HIGH] · R2-1 baseline (vs rev1 Phase 1.2 §"연도 코호트") · per-year cohort breakdown removed; censoring signal hidden
**Claim/code:** R2-1 reports only the pooled rev2 baseline (rev90 38.4%) and asserts "변화 작음. 방향·세그먼트 상대순위 전부 불변." It carries **no per-year cohort table**. Rev1 (Phase 1.2) *did* carry one and explicitly flagged "2026(부분·경계)."

**Why wrong + recomputed numbers:** Recomputed rev2 per-year (from `f_year` in CSV):

| f_year | N | any90 | rev90 | (rev1 N) | (rev1 rev90) |
|---|---:|---:|---:|---:|---:|
| 2024 | 52,789 | 69.1% | **41.3%** | 54,568 | 44.4% |
| 2025 | 40,488 | 67.4% | **35.8%** | 41,670 | 39.3% |
| 2026 (boundary) | 5,115 | 59.2% | **28.3%** | 5,227 | 32.1% |
| pooled | 98,392 | 67.9% | 38.4% | 101,465 | 41.7% |

- The 2026 boundary cohort (rev90 28.3%) is the textbook right-censoring signature, and rev2 **dropped the "부분·경계" label** that rev1 had. A reader of the rev2 section sees only "38.4%" with no warning that ~5% of N is under-observed.
- The rev1 per-year numbers I cite above reproduce **exactly** from `data/phase1_2_baseline_a_result.csv` (2024=54,568 rev90 44.4 / 2025=41,670 rev90 39.3 / 2026=5,227 rev90 32.1), so rev1's table is verified and rev2's omission is a regression, not a data change.

**Fix:** Restore a per-year cohort table in the rev2 section and re-flag 2026 as boundary/under-mature. State explicitly whether 2026 is included in the headline (it is) and what the headline becomes excluding it (rev90 38.9% on 2024+2025).

---

### F3 · [MEDIUM] · R2-1 "방향·세그먼트 상대순위 전부 불변" + 2-year pooling · 2024 vs 2025 rev90 gap not censoring
**Claim/code:** The 2-year window [2024-03-02, 2026-03-02] is pooled into one baseline; the report treats the cohort as homogeneous.

**Why wrong + recomputed numbers:** With a 90-day window, **both 2024 and 2025 cohorts are fully mature** (table reaches ~late-May 2026; see F5), so censoring cannot explain a gap between them. Yet rev90 drops **41.3% → 35.8% (−5.5pp)** from 2024 to 2025 — a real cohort-quality / seasonality / product-mix shift. Pooling them into "38.4%" hides this. The report nowhere tests whether early-2024 and 2025 cohorts are comparable (product changes, pricing, topic mix over 2 years), so the pooled baseline silently blends a declining trend.

**Fix:** Report the rev90 trend by half-year (or quarter) cohort, and either (a) justify pooling with a stationarity check, or (b) headline the most recent fully-mature cohort. Acknowledge the −5.5pp YoY decline as a finding, not noise.

---

### F4 · [MEDIUM] · §R2-0/R2-1 · 101,465 → 98,392 gap is plausibly understated for left-re-dating risk
**Claim/code:** R2-1: "코호트 N 101,465 → 98,392 (−3,073)"; R2-0: `pay_under_750` had 35,527 events / 12,169 users in May alone (avg ₩83). Only the purchase filter changed (`pay_%`→`pay_for_%`); window logic identical (verified by diffing `phase1_2_baseline_a.sql` vs `master_export.sql`).

**Why this needs scrutiny:** Only **3,073 cohort members (−3.0%)** were lost, despite `pay_under_750` having ~12,169 *monthly* users. The small net change is consistent but masks a **silent re-dating hazard**: excluding `pay_under_750` doesn't only drop users — for any APP user whose **true-first paid event was a `pay_under_750` microtransaction**, rev2 promotes their *next* `pay_for_%` event to "first purchase," shifting `f_d` later and possibly across the 2024-03-02 boundary. Such users' "first SKU" attribution (the basis of all transition analysis) is then the wrong SKU, and their t=0 is artificially late (compressing their observable revisit window). The CSV cannot expose this (it has no pre-filter view), so the −3,073 net is the *visible* effect only; the *re-dated* (not dropped) population is invisible and uncounted.

**Fix:** Quantify, in BQ, how many APP users had a `pay_under_750` strictly before their first `pay_for_%` (i.e., users whose `f_menu`/`f_d` moved under rev2). If non-trivial, their first-SKU attribution in Phase 2–4 is suspect. At minimum, document the re-dating direction as a known limitation.

---

### F5 · [LOW] · Contract "upper bound = T-90 maturity cutoff" · maturity holds but is unverifiable from CSV (asserted, not proven)
**Claim/code:** Cohort upper bound 2026-03-02, "T-90 maturity cutoff," today 2026-06-01. A 2026-03-02 first-buyer needs data through 2026-05-31 for a full 90-day window.

**Why partially-verifiable:** 2026-03-02 → 2026-06-01 = exactly **91 days**, so the cutoff is mathematically ≥90 **only if the table is loaded to today**. From the CSV I can infer the table's coverage indirectly: `max(days_to_2nd) = 803` (1 user), 68 users >700d. An early-2024 first-buyer with an 803-day gap implies a 2nd purchase ~mid-May 2026, so the table contains events at least into **mid-to-late May 2026** — close enough that the 2026-03-02 boundary cohort *probably* has a near-full 90-day window. **But the exact table max `event_date` cannot be confirmed without BQ**, and any ETL lag of even ~3 weeks would leave the latest cohort members with <90 observable days, depressing their rev90 (consistent with the 2026 dip in F2). The report asserts maturity without showing `MAX(event_date)`.

**Fix:** Add a one-line provenance check: `SELECT MAX(event_date) FROM mart_use_skill_se` and confirm ≥ 2026-05-31. Document it in the rev2 section.

---

### F6 · [LOW] · §★발견 2 / Phase 1.1 (β) · "true-first" relies on single-source table with no audited start date (residual left-censoring risk)
**Claim/code:** `pays` CTE has no lower date bound; `rn=1` is taken as the user's true-first paid purchase, and channel = first-purchase platform. The β rationale (Phase 1.1) argues single-source `mart_use_skill_se` removes the X_anomaly.

**Why a residual risk remains:** "rn=1 = true first" is only valid if `mart_use_skill_se` contains the user's entire payment history. If the table's earliest loaded date is, say, exactly 2024-03-02 (suspiciously the same as the cohort lower bound), then any user whose real first purchase predates the table would be mislabeled "new cohort" with a fake first-purchase date piled at the boundary — inflating the apparent new-buyer pool and corrupting "first SKU" attribution and channel (a pre-table web buyer could look APP-first). **Indirect evidence consistent with (not proof of) boundary pile-up:** the 2024 cohort is the **largest single year (52,789, 53.6% of N)** for an ostensibly growing service, and its mean lifetime `total_pays` (5.85) far exceeds 2025 (4.25) and 2026 (2.90) — partly expected from longer observation, but also the shape a left-truncation pile-up would produce. `total_pays` itself is computed over **all-time** (the `agg` CTE has no window), so cross-year `total_pays` comparisons are confounded by unequal observation length and should not be read as engagement.

**Fix:** Confirm `MIN(event_date)` of `mart_use_skill_se` is well before 2024-03-02 (ideally ≥1 year prior) so the lower bound is a true cohort filter, not a table edge. If the table starts at/near 2024-03-02, the entire "new cohort" framing for early-2024 is contaminated.

---

## 3) Verified Correct

All reproduced from `data/master_users.csv` (no BQ):

| Claim (baseline.md) | Reported | Recomputed | Match |
|---|---|---|---|
| Cohort N | 98,392 | 98,392 (98,393 lines − header) | ✓ |
| any90 (당일포함) | 67.9% | 67.88% (66,792) | ✓ |
| rev90 (재방문) | 38.4% | 38.35% (37,735) | ✓ |
| sameday | 50.0% | 50.04% (49,235) | ✓ |
| ever 2nd (has_2nd) | 73.5% | 73.47% (72,284) | ✓ |
| topic match | 99.7% | 99.70% (98,093) | ✓ |
| R2-2 days-to-2nd dist | 당일68/1-7:13/8-30:6/31-90:5/90+:8, med 0 | 68.1/13.1/6.3/4.9/7.6, med 0 | ✓ |
| "재방문 리텐션" count | 23,049 | 23,049 (has_2nd & ¬sameday) | ✓ (number reproducible; population mis-specified — see F1) |
| rev1 per-year (Phase 1.2) | 2024 54,568 / 2025 41,670 / 2026 5,227 | identical from phase1_2 result CSV | ✓ |

- **SQL window logic correct & consistent:** t=0=f_d via `DATE_DIFF(x.d, f.f_d, DAY)<=90`; `c_any*` uses `ts>f_ts` (sameday-later allowed), `c_rev*` uses `d>f_d` (strictly later day). Monotonicity `c_rev90 ≤ c_any90` holds for all 98,392 rows (0 violations). `has_2nd=0 ⇒ total_pays=1` holds (0 violations).
- **rev2 vs rev1 cohort SQL differ only in the purchase filter** (`pay_%`→`pay_for_%`); window bounds, APP-first filter, and 90-day logic are byte-identical — so the −3,073 gap is attributable solely to the microtransaction exclusion (modulo the re-dating in F4).
- **APP-first / window filter** `WHERE f.f_plat='APP' AND f.f_d BETWEEN '2024-03-02' AND '2026-03-02'` is correctly applied at the outer query (after `rn=1` selection), so the cohort is correctly "users whose true-first paid event is APP and falls in-window."

---

## 4) Could Not Verify (requires BQ — not run per cost constraint)

1. **Table `MAX(event_date)`** — needed to confirm the 2026-03-02 cohort truly has ≥90 observable days (F5). Indirect CSV evidence (max days_to_2nd=803) suggests coverage into ~mid/late-May 2026 but is not conclusive.
2. **Table `MIN(event_date)`** — needed to rule out left-censoring/boundary pile-up at 2024-03-02 (F6). The 2024 cohort being the largest year + highest lifetime total_pays is *consistent with* but does not *prove* truncation.
3. **Re-dating population (F4)** — count of APP users whose true-first event was `pay_under_750` before their first `pay_for_%`. Their first-SKU attribution (basis of Phase 2–4) cannot be checked from the post-filter CSV.
4. **Whether `rn=1` dedup is per true user_id** across platforms (the β note mentions IOS+ANDROID+WEB cross-users); the CSV is already user-deduped so I cannot re-derive the channel assignment or confirm no double-counting at the source.
5. **The deck (`a-appfirst-review.pdf`)** was not opened in detail; baseline.md is the stated authority and was reviewed in full.
