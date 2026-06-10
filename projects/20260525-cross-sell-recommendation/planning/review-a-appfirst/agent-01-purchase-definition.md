# Adversarial Review — A App-First Analysis (Revision 2)
## Lens: Purchase definition & event scope · Reviewer: agent-01 · 2026-06-01

## 1. Verdict

The `pay_for_%` + `revenue_krw>0` purchase filter is **correctly and consistently applied** across `master_export.sql` (A) and `master_export_c.sql` (C), and the headline metrics (N=98,392; rev90=38.35%; sameday=50.04%; any90=67.88%; ever=73.47%) **reproduce from the CSV within rounding**. The microtransaction exclusion appears genuine — no sub-100원 values exist in `f_rev`. **However, there is one Critical conflation**: the report's "재방문 리텐션 = 23.4% / 23,049명" is NOT the contract's `rev90` (38.4%) — it is the *immediate-second-purchase-on-a-different-day* count, a structurally different and smaller set, and the entire R2-6 transition analysis is built on it. Plus a data-quality issue in the `age` column that the age-axis claims rest on.

## 2. Findings

---

### Finding 1 — [Severity: Critical] · The "23,049 재방문" headline is a different metric than `rev90`, and the whole R2-6/R2-8 transition layer is built on it

- **Location**: `baseline.md` §R2-2 (lines 469–478), §R2-6 (lines 510–524), §R2-8 (line 529); deck slide 3 ("2회차는 두 개의 다른 문제다", 50.0/23.4/26.5) and slide 4 (재방문 = 38.4). Task brief's "CLAIMED CONTRACT" also lists both "rev90=revisit … within 90d" and "revisit 2nd-buyers=23,049" as if they were the same concept.
- **The claim**: R2-2 presents a clean 100% partition: 당일 업셀 50.0% (49,235) / **재방문 리텐션 23.4% (23,049)** / 2회차 없음 26.6%, and states "추천이 키울 영역은 재방문(현 23%)". §R2-6 then computes ALL transition matrices on "재방문 2회차만, n=23,049".
- **Why wrong (recomputed)**: The contract defines `rev90` = "next-day+ repurchase within 90d" = `c_rev90>0`. I recomputed:
  - `c_rev90>0` (the contract's revisit metric) = **37,735 users (38.35%)** — matches the headline rev90=38.4%.
  - The "23,049" = users whose **immediate 2nd purchase** (rn=2) was on a different day = `has_2nd=1 AND second_sameday=0`. This is a DIFFERENT set.
  - Cross-tab of the two definitions:
    | | rev90>0 | rev90=0 |
    |---|---:|---:|
    | 2nd-is-revisit (23,049) | 17,557 | **5,492** |
    | 2nd-is-sameday / no-2nd | **20,178** | 55,165 |
  - The 23,049 set **MISSES 20,178 users** who genuinely revisited within 90d (their immediate 2nd was same-day, so the revisit was a 3rd+ purchase) and **WRONGLY INCLUDES 5,492 users** whose immediate 2nd purchase was *beyond 90 days* (confirmed: §R2-2's own bucket "90일+ 8%" = 5,492 / 7.6% of has_2nd; recomputed exactly). So 23,049 ≠ 38.4% revisitors; it is neither a subset nor a superset cleanly — it is a 76% / 7.6%-error mismatch.
  - Therefore the partition "50% 당일 + 23.4% 재방문 + 26.6% 없음 = 100%" is a partition by **immediate-2nd timing**, not by the sameday/rev90 metrics that the rest of the report uses. The deck makes this worse: slide 3 labels the bucket "재방문 23.4%" while slide 4 says "추천은 재방문(38.4) 공략" — two different numbers under the same word "재방문" two slides apart.
  - Consequence: every R2-6/R2-8 transition lift (love→love 79.4%, 사주→타로 lift 0.69, intent clusters) is computed on a 23,049-user set that omits 20,178 within-90d revisitors and contains 5,492 non-revisitors. The transition matrices are NOT "what recommendation will actually target (the rev90 set)" as claimed.
- **Recommended fix**: Either (a) relabel 23,049 honestly as "users whose *immediate* 2nd purchase was a revisit (incl. >90d)" and stop equating it with rev90/38.4%, OR (b) recompute the transition layer on the true rev90 revisit set (the 2nd *next-day-within-90d* purchase per user, n≈37,735 revisit events). The cleanest within-90d revisit-transition denominator is the first next-day purchase with `0 < days ≤ 90`, which is 17,557 + the 20,178 whose first-revisit was 3rd+ — note the SQL does not currently expose "first revisit SKU", only the rn=2 SKU, so (b) requires a new export column.

---

### Finding 2 — [Severity: Major] · `age` column contains corrupt values; the entire age × topic lifecycle layer (R2-7 / slide 8) rests on it

- **Location**: `baseline.md` §R2-1 (line 465, "age 채움"), §R2-7 (line 526–527), deck slide 4 ("98% age 채움") and slide 8 (age × topic heatmap, 8 age bins).
- **The claim**: "age 채움 98%" → age axis usable; R2-7 builds 10–20대 연애 → 30대초 결혼 → 40대+ 재물 lifecycle.
- **Why wrong (recomputed)**: The `age` column min = **-20,048,780** and max = **2,010** (a birth year stored as age). 160 rows have age < 14; 6 have age > 90. Fill rate recomputes to **98.2%** (1,782 blank/NULL of 98,392) — the 98% headline is right — but "filled" ≠ "valid". A user binned at age 2,010 or −20M is silently dropped or mis-binned by whatever age-bucket logic the (local, not in-repo) script used. The age-bin column totals in rev1 Phase 2(2차) sum to ~97,416 (< 98,392), consistent with some age rows being discarded, but the magnitude of the garbage (−20M) means the binning logic's NULL/outlier handling was never validated in the report.
- **Recommended fix**: Add an explicit age sanity filter (e.g. `age BETWEEN 10 AND 99`) to the master export or the analysis scripts, report the post-filter N for the age axis, and state how many rows were dropped. Do not claim "age 98% 채움 → 연령축 가능" without a validity (not just non-null) check.

---

### Finding 3 — [Severity: Minor] · `c_*` counters are per-EVENT, not per-purchase; a single content purchase emitting multiple `pay_for_` events would inflate `total_pays`/`c_any`/`c_sameday` (not verifiable from CSV, but unhandled)

- **Location**: `master_export.sql` lines 3–20 (`pays` → `ordp` → `agg`); no event-level dedup. §R2-0 (line 447) notes pay_for_contents = 62,982 events / 28,622 users = **2.2 events/user in one month**.
- **The claim**: implicit — that each `pay_for_%` row = one purchase, so `total_pays`, `c_sameday`, `c_any*` count purchases.
- **Why questionable**: The SQL applies `ROW_NUMBER()` only to *order* events, and `COUNT(*)`/`COUNTIF` over the un-deduped event array. If the client fires `pay_for_contents` more than once per checkout (retry, confirmation echo, multi-SKU bundle splitting into N rows), `total_pays` and the same-day counters inflate. Evidence the CSV cannot refute: max `total_pays` = **1,954** and max `c_sameday` = **48** for single users; 602 users have ≥50 lifetime paid purchases. These are plausibly real cheap-tarot power-users (f_rev=1,500 repeated), but the report never tests the duplicate-event hypothesis. The report's own §Phase 1.2 (line 149) and Phase 5 backlog (line 406) flag "sameday 과대 가능 — 검증 필요" but it was never done.
- **Mitigating fact (recomputed)**: The *headline percentages* are **binary** (`c_*>0`), so event duplication does NOT distort rev90/sameday/any90/ever — a user is counted once regardless of how many duplicate events they have. Internal consistency also holds: any90 population (66,792) = exact union of rev90 (37,735) ∪ sameday (49,235), with 0 leakage. So this is Minor for the headline but Major for any count-based or revenue-based metric (e.g. "평균 1st 12,982원 → 2nd 9,769원" in rev1 Phase 3, transition row bases).
- **Recommended fix**: Dedup `pay_for_` events to one row per (user, transaction) — ideally on an order/transaction id if available, or at minimum collapse identical (user_id, event_timestamp, menu_seq, revenue_krw). Then re-confirm `total_pays` and verify the sameday counters. Close the long-open "sameday 과대" item before any count/revenue claim ships.

---

### Finding 4 — [Severity: Minor] · R2-3 content_type table silently drops 751 users (진단/기타/손금) without labeling them; they are not "(미태깅)"

- **Location**: `baseline.md` §R2-3 (lines 480–486).
- **The claim**: Table lists 타로 / 사주 / 점성학 / (미태깅), implying these are the content types.
- **Why wrong (recomputed)**: The `f_ctype` field also contains **진단 (540), 기타 (135), 손금 (76)** = 751 users with a real (non-blank) content_type that the R2-3 table omits entirely. They are NOT in "(미태깅) n=7,507" — that bucket is exactly the 7,507 blank-ctype users (recomputed). So 30,601 (타로) + 58,707 (사주) + 826 (점성학) + 7,507 (blank) = 97,641, leaving 751 users unaccounted for in the table. Cosmetic, but the table reads as exhaustive and isn't.
- **Recommended fix**: Add a "기타형식 (진단·손금·기타) n=751" row or fold explicitly into "(미태깅)" with a note, so the column sums to 98,392.

---

### Finding 5 — [Severity: Minor] · §R2-0 classification table is May-only and cannot establish that `pay_for_%` captures the full 2-year cohort universe; coupon/free/promo content unlocks are not addressed

- **Location**: `baseline.md` §R2-0 (lines 447–455), "→ 사실상 pay_for_contents 단일."
- **The claim**: The 4-row May table justifies that `pay_for_%` ≈ all content purchases and only those.
- **Why questionable**: (a) The R2-0 census is **one month (May 2026)**; the cohort window is **2024-03-02 .. 2026-03-02**. Event-name taxonomy can drift over 2 years (renamed events, deprecated prefixes, an old `pay_contents` without `_for_`). The claim that `pay_for_%` is complete for the whole window is asserted from a 1-month snapshot. (b) **Coupon/promo/heart-funded content unlocks**: if a user redeems a coupon or spends previously-purchased hearts/cash to unlock content, that may fire a *consume*/*unlock* event with `revenue_krw=0` (or a different prefix) rather than `pay_for_%`. Such genuine content consumption is invisible to this filter. The report's own rev1 Phase 1.1 (lines 80–82) lists "collection/coaching/subscription" and "pay_for_package" as content — R2-0 then shows pay_for_package = only 6 events and pay_for_coaching = 5, i.e. subscriptions/collections may be under-captured or renamed. The filter is defensible for *paid skill content* but the report overstates it as "사실상 단일 = all content."
- **Cannot fully verify** without BigQuery (out of scope). Flagging as a scoping gap, not a confirmed error.
- **Recommended fix**: Run the §R2-0 event census over the FULL cohort window (2024-03 .. 2026-03), not just May, and explicitly enumerate the excluded `pay_*`/`consume_*`/coupon events with counts so the reader can see what "content purchase" omits. State the scope as "paid skill-content checkout events" rather than "all content purchases."

---

## 3. Verified correct

- **Microtransaction exclusion is real**: `f_rev` min = 150, p1 = 450; **zero** values below 100원; all low values are multiples of 150 (150/300/450/.../1500), consistent with real content prices, NOT the 83원 `pay_under_750` set. The exclusion claimed in R2-0/R2-1 was actually applied.
- **Headline metrics reproduce** (N=98,392): rev90 = 37,735 = **38.35%** (claim 38.4 ✓); sameday = 49,235 = **50.04%** (50.0 ✓); any90 = 66,792 = **67.88%** (67.9 ✓); ever/has_2nd = 72,284 = **73.47%** (73.5 ✓); any30/any60 = 64.26/66.55 (claim 64.3/66.5 ✓).
- **§R2-3 and §R2-4 breakdowns reproduce exactly**: 타로 n=30,601 rev90=40.6 sameday=60.6 ✓; 사주 n=58,707 rev90=37.6 ✓; 점성학 n=826 ✓; 연애 n=71,129 rev90=40.8 ✓; 가족자녀 n=2,058 rev90=21.6 ✓; 재물금전 n=2,421 rev90=28.3 ✓. topic match = **99.70%** (R2-1 ✓).
- **§R2-2 days-to-2nd buckets reproduce exactly**: 당일 68.1% / 1–7일 13.1% / 8–30일 6.3% / 31–90일 4.9% / 90일+ 7.6%, median = 0.
- **Metric definitions are internally consistent**: any90 population = exact union of rev90 ∪ sameday (0 leakage); `second_sameday` ⟺ `days_to_2nd==0` (0 mismatches).
- **Filter applied identically in A and C exports** (`master_export.sql` L7 == `master_export_c.sql` L7); the C export correctly adds `app_rows=0` for web-only isolation.
- **Note**: `phase1_2_baseline_a.sql` (the *rev1* baseline) uses the broader `pay_%` filter (L17) — but this is the superseded revision; the rev2 master correctly uses `pay_for_%`. Not a rev2 error.

## 4. Could not verify / open questions

1. **Whether `pay_for_%` is complete over the full 2024–2026 window** — R2-0 census is May-only; needs a full-window event-name census (BQ, out of scope). (Finding 5)
2. **Whether a single checkout emits multiple `pay_for_` events** — cannot test from user-grain CSV; needs event-grain inspection or an order-id (BQ). The 1,954-purchase outlier user is the test case. (Finding 3)
3. **Whether coupon redemptions / heart-spend content unlocks fire `revenue_krw=0` or a non-`pay_for_` event** — would mean real content consumption is excluded; not checkable locally. (Finding 5)
4. **The age-bin denominators in R2-7/slide 8** — the per-bin column counts (13,150 / 26,682 / … in rev1) are not in this CSV's aggregated form and the binning script is at `/tmp` (not in repo); could not confirm how the −20M / 2010 age garbage was handled. (Finding 2)
5. **f_ts / f_d timestamp granularity** — the CSV exposes only f_year, not f_d/f_ts, so the cohort window (2024-03-02..2026-03-02) and the t=0 anchoring could only be verified via the SQL WHERE clause, not against data. f_year distribution (2024: 52,789 / 2025: 40,488 / 2026: 5,115) is consistent with the window.
