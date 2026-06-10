# Agent-08 — Selection / Survivorship / Channel-Definition Bias Review
## A app-first cross-sell analysis (Revision 2)

> Reviewer: independent adversarial data analyst. Scope: who is in the "A app-first" population, and whether the channel definition distorts it.
> Verified only against local CSV/SQL/report (NO BigQuery). Recompute basis: `data/master_users.csv` (98,392 rows + header), `data/master_export.sql`, `data/phase1_0_channel_sizing.sql`, `data/phase1_1_beta_channel.sql`, `data/phase1_*_result.csv`, `planning/baseline.md`.

---

## 1) Verdict

**Qualified PASS on arithmetic, FAIL on channel-definition soundness as worded.** Every downstream number I could recompute (N=98,392, has_2nd 73.5%, sameday 50.0%, rev90 38.4%, content_type/topic counts) matches the report exactly — the CSV→report pipeline is internally clean. **But the "A app-first" population is built on three definitional choices that the report does not adequately caveat, and one of them is an outright inconsistency:**

1. **The channel classifier (β, `pay_%`) and the A cohort (master, `pay_for_%`) use DIFFERENT purchase definitions.** The β sizing that produced A=458,291 *includes* `pay_under_750` micro-transactions (avg 83원) when picking the first-purchase platform; the master cohort *excludes* them. So the report's claim that "98,392 = a subset of β's 458K A" (line 133) chains two non-identical populations. The CLAIMED CONTRACT ("TRUE-first paid, rn=1 over all pays") is **not** what master_export.sql implements — its `rn=1` is over `pay_for_%` only.
2. **Channel = platform of the first *purchase event*, not where the user was acquired.** A web-acquired user whose first paid `pay_for_%` event happens to fire on APP is labeled "app-first." This is a proxy, not a fact, and it leaks B-type behavior into A.
3. **Left-censoring (table start) can manufacture fake app-first users**, and iOS/Android are pooled with no way to check heterogeneity in this CSV.

None of these invalidate the *relative* patterns (taro>saju, love-dominance, etc.), but they do undercut any statement that frames A as "app buyers" generally or feeds A's absolute baselines into the recommendation engine without a representativeness caveat.

---

## 2) Findings

### [HIGH] · F1 · `phase1_1_beta_channel.sql:38` vs `master_export.sql:7` + baseline.md:133 · Channel classifier and A cohort use different purchase definitions (denominator/identity mismatch)

**Claim/code.** baseline.md line 133: *"코호트… n=101,465 (β 전체 A 458K 중 최근 2년 신규 첫구매분)"* — i.e. the master A cohort is presented as a date-windowed subset of the β-classified A=458,291. R2 then restates A=98,392 under the same framing.

But the two are classified differently:
- `phase1_1_beta_channel.sql:38` → `WHERE event_name LIKE 'pay_%' AND revenue_krw > 0`. The `LIMIT 1` ordered ARRAY_AGG that sets `first_plat` (L43) therefore considers **`pay_under_750` micro-transactions** (avg 83원, R2-0) as candidate "first purchases."
- `master_export.sql:7` → `WHERE event_name LIKE 'pay_for_%' AND revenue_krw > 0`. Its `rn=1` first purchase (L11, L14) **excludes** those micro-transactions.

**Why wrong.** "First-purchase platform" is determined over different event sets. A user whose earliest `pay_%` row is a `pay_under_750` micro-txn on WEB, but whose earliest `pay_for_%` row is on APP, is:
- under β: first_plat = WEB → classified **B or C** (not A);
- under master: first event = APP → classified **A**.
So the master A cohort is **not** a clean subset of the β A=458,291. The "458K" denominator the report leans on belongs to a different population than the one the 98,392 cohort would scale to. R2 itself rebuilds channel sizing **only** in the deprecated-definition β; it never re-ran the β channel split under `pay_for_%`. So the *channel sizes* quoted everywhere downstream (A 37.2%, C 59.1%, B 3.7%) are still the `pay_%` numbers, while the *A analysis* is `pay_for_%`.

**Recomputed numbers.** `pay_under_750` touches ~12,169 users/month (R2-0, May alone). Over the 2-year cohort window this is plausibly tens of thousands of users — material against A=98,392. I cannot count the exact flips locally (master CSV carries no `platform` or event-type column — see §4), but the *direction* is clear: any user whose micro-txn-first platform ≠ pay_for_first platform is misclassified between the two definitions. The contract's "rn=1 over all pays" is satisfied by neither file consistently.

**Fix.** Re-run the β channel split with `pay_for_%` (drop `pay_under_750`) so the classifier and the cohort share one purchase definition; report the corrected A/B/C sizes; then state 98,392 as a windowed subset of the *corrected* A, not the 458K. Alternatively, define A explicitly as "first `pay_for_%` event on APP" and retire the "subset of 458K" framing.

---

### [HIGH] · F2 · `master_export.sql:48` (`WHERE f.f_plat='APP'`) + CASE L5 · "App-first" = platform of first *purchase event*, not acquisition channel → B-type leakage into A

**Claim/code.** Contract: A = "app-first user." Code: A = `f_plat='APP'` where `f_plat` is the `platform` of the chronologically-first `pay_for_%` event (L11 ROW_NUMBER, L14 rn=1), with `IOS/ANDROID→APP, WEB→WEB` (L5).

**Why wrong.** `platform` is *where the paid event fired*, which is a weak proxy for "app-first user." The brief's own lens names the failure mode: a user can browse/convert on web, install the app, and have their first *paid* event fire on APP — they are web-acquired but get the APP label. The β classifier explicitly carves out exactly this population as **B (web→app)** when there is a *prior WEB pay*. But B is only detectable when the prior web touch is itself a **purchase**. A web user whose pre-app web activity was free (enter_skill/consume_skill) or a sub-750 micro-txn (see F1) leaves no `pay_for_%` WEB row → they collapse into A. So A is contaminated with an unknown count of "soft web→app movers" that B was supposed to isolate.

This matters because the report treats B as the high-intent, ultra-retention segment (재방문 94.6%, lines 96/118) and *excludes* it from A precisely because B is different. If a slice of true web→app movers is hiding in A, A's baselines (rev90 38.4%) are **upward-biased** by exactly the high-intent population the analysis claims to have removed.

**Recomputed numbers.** Not directly countable from the CSV (no platform/prior-web columns). Bound from the β table: B=45,526 was caught *only* via prior WEB `pay_%`. The under-750/free web touches that escape B detection are uncountable here but non-zero and one-directional (always inflate A).

**Fix.** State explicitly that A is "first *paid* event on app," not "app-acquired." For a tighter A, intersect with an acquisition/first-session-platform signal (install attribution or first `enter_skill` platform) if available, and report how many A users had any prior WEB session.

---

### [MEDIUM] · F3 · baseline.md "발견 2" (L31–42) + Phase 1.0 (α) vs 1.1 (β) reconciliation · α "C largest" reversal carried into β without re-deriving sizes under pay_for_%

**Claim/code.** 발견 2 correctly documents that the integrated column (`first_paid_date`, all pay types/all platforms) and the app column (`first_app_paid_date`, skill-pay only, iOS/Android) have non-nesting source definitions, producing 1.6% X_anomaly (α, `phase1_0_channel_sizing_result.csv`: X=19,789). β (`phase1_1_beta_channel.sql`) re-derives from a single source to kill X_anomaly. baseline.md L90: *"총계 1,230,978 은 Phase 1.0(α) 와 정확히 일치… 정합성 확인됨."*

**Why wrong / partially right.** The β internal re-derivation logic *is* internally consistent and the X_anomaly removal is sound (verified: β result has U_unknown=2, no X bucket). **But** the reconciliation is presented as proof the classification is "robust" (L113: *"분류 자체는 견고"*) when both α and β were computed under the **pre-R2 `pay_%` definition**. The whole point of R2 was that `pay_%` wrongly includes 83원 micro-txns. The "A 35→37%, C 59.8→59.1% nearly identical across methods" robustness claim therefore says nothing about whether the channel split survives the R2 purchase-definition change — which is the change that actually matters for the A cohort used downstream. The "C is largest" reversal (verified α C=736,395 59.8% / β C=727,159 59.1%) is real but is a `pay_%` artifact that was never re-confirmed under `pay_for_%`.

**Recomputed numbers.** α C=736,395 (59.8%), β C=727,159 (59.1%); α A=430,524 (35.0%), β A=458,291 (37.2%) — all from the two result CSVs, all `pay_%`. No `pay_for_%` channel-size CSV exists in `data/`.

**Fix.** Add one β-equivalent run under `pay_for_%` and report whether C-largest survives; if it does, *then* the robustness claim is earned. Until then, caveat that channel sizes are `pay_%`-basis only.

---

### [MEDIUM] · F4 · baseline.md L133 + master_export.sql:48 (`f_d BETWEEN '2024-03-02' AND '2026-03-02'`) · Left-censoring (table start) can relabel web-era users as app-first

**Claim/code.** Cohort = first `pay_for_%` on APP within [2024-03-02, 2026-03-02], "90일 성숙" rationale. The β classifier had **no** date floor (lifetime, total 1,230,978).

**Why wrong (channel-specific).** If `mart_use_skill_se` coverage begins around/after the legacy web era, a user whose genuine first purchase was on WEB *before the table's earliest data* has that purchase invisible. Their first **observed** `pay_for_%` row — possibly a later APP purchase — becomes their "first," labeling them A app-first though they are truly web-first (B). This is survivorship distortion expressed as a *channel* relabel: pre-table web buyers get promoted into A. The 2024-03-02 floor on the cohort does not protect against this, because the floor is on the *observed* first APP purchase, not on the user's true first purchase. (Overlaps with the cohort-review agent's left-censoring concern; flagged here for the channel-leak consequence specifically.)

**Recomputed numbers.** CSV f_year ∈ {2024: 52,789; 2025: 40,488; 2026: 5,115} — no pre-2024 rows by window design, so the relabel is invisible in this CSV. Cannot bound the count without the table's coverage-start date (see §4).

**Fix.** Confirm `mart_use_skill_se` earliest `pay_for_%` date; if it post-dates known web-era purchasing, restrict the "true-first" claim or exclude users with platform activity predating table start.

---

### [MEDIUM] · F5 · Whole report (Phase 1.2→4, R2, U-sections) · iOS and Android collapsed to APP — pooled heterogeneity hidden, unverifiable in this CSV

**Claim/code.** `master_export.sql:5` and `phase1_1_beta_channel.sql:34`: `platform IN ('IOS','ANDROID') THEN 'APP'`. β platform check (baseline L83) showed IOS=316,616 vs ANDROID=203,754 — a ~1.55:1 split, materially different sizes. All A analysis treats them as one.

**Why wrong.** iOS and Android populations differ systematically (price sensitivity, IAP friction, demographics, store-policy-driven purchase flows). Pooling them under "A" can average over real repurchase-behavior differences, and any "A baseline rev90 38.4%" is a blend whose mix could shift if the iOS/Android ratio changes over the cohort window. The recommendation engine built on A would inherit this blended assumption.

**Recomputed numbers.** **Cannot verify from master CSV** — it carries no platform-split column (header has no `platform`/`f_plat`; the split happened pre-export at SQL `WHERE f.f_plat='APP'`). Only the β-level IOS/ANDROID counts (316,616 / 203,754) are available, and those are `pay_%`-basis lifetime, not the cohort.

**Fix.** Add `f_plat_raw` (IOS/ANDROID) to the export and report rev90/sameday/transition split by OS at least once to confirm pooling is safe; if behaviors diverge, treat OS as a stratum.

---

### [LOW] · F6 · baseline.md U-1/U-3/U-4 (lines 616–644), Phase 4 종합 · Generalizing A-subset findings toward "the recommendation engine" / "app buyers" without representativeness caveat

**Claim/code.** U-2/U-3: *"추천 엔진 baseline 룰"*, *"추천 엔진 = 공통 로직"*; U-4 #1 *"A 인앱 추천 (즉시…)"*. Phase 4 L387 *"연애는 전 세그먼트 공통 디폴트… 안전빵 추천."*

**Why this is an overreach.** A was *constructed* by excluding B (high-intent web→app, 94.6% revisit) and C (low-intent web-only, 13.1% rev90). A is therefore the *middle* slice, not "app buyers in general." Statements like "공통 로직 (A·C 동일)" (U-3) partly hedge this, and C does get its own section (good). But the engine-level framings (U-2/U-3/U-4) present A-derived rules as the baseline rule set without restating that (a) B-leakage may inflate A's retention (F2), and (b) A excludes the very segment with the strongest retention (B). The recommendation engine, if trained/tuned on A's absolute rates, will systematically under-model B users and over-state baseline retention for "all app buyers."

**Recomputed numbers.** A rev90 38.4% (verified) vs B 재방문 94.6% vs C 13.1% — the three are wildly different, confirming A is non-representative of app buyers as a class.

**Fix.** Add one sentence wherever A baselines feed the engine: "A excludes B (web→app, highest retention) and C; absolute rates are A-segment-specific and must not be read as all-app-buyer rates." Keep relative rules (love-default, taro-stickiness) — those are likely robust to the mix.

---

## 3) Verified correct

| Claim | Source | Recomputed | Match |
|---|---|---:|---|
| A cohort N = 98,392 | R2-1 / line 444 | 98,392 data rows | ✅ exact |
| has_2nd / ever 2회차 73.5% | R2-1 L464 | 72,284 / 98,392 = 73.5% | ✅ exact |
| sameday 50.0% (49,235) | R2-2 L473 | c_sameday>0 = 49,235 = 50.0% | ✅ exact |
| rev90 (revisit) 38.4% | R2-1 L462 | c_rev90>0 = 37,735 = 38.4% | ✅ exact |
| 2회차 없음 26.6% | R2-2 L476 | total_pays=1 → 26,108 = 26.5% | ✅ (rounding) |
| content_type 타로 30,601 / 사주 58,707 | R2-3 | 30,601 / 58,707 | ✅ exact |
| topic 연애 71,129 / 가족자녀 2,058 | R2-4 | 71,129 / 2,058 | ✅ exact |
| age fill ~98% | Phase 1.2 L146 | 98.19% | ✅ |
| β X_anomaly removed (single source) | Phase 1.1 | β result has only U=2, no X bucket | ✅ logic sound |
| β/α total reconcile = 1,230,978 | L90 | both result CSVs TOTAL=1,230,978 | ✅ (within pay_% basis) |
| α "C largest" reversal | Phase 1.0 | α C=736,395 (59.8%) is top row | ✅ |

The CSV→report numeric pipeline is clean. My findings are about *definition*, not arithmetic.

---

## 4) Could not verify (data limitations)

1. **Exact B-leakage / mislabel count (F1, F2, F4).** `master_users.csv` carries **no** `platform`/`f_plat`/event-type column — the channel filter (`WHERE f.f_plat='APP'`) and event-type filter were applied pre-export. Quantifying flips between `pay_%` and `pay_for_%` first-platform, or counting soft web→app movers inside A, requires event-grain data with platform + event_name. Direction is determinable (always inflates A); magnitude is not, locally.
2. **iOS vs Android split within A (F5).** No OS column in the cohort CSV. Only β-level lifetime counts (IOS 316,616 / ANDROID 203,754, `pay_%`) exist.
3. **Table coverage-start date (F4).** Cannot confirm whether `mart_use_skill_se` begins early enough to capture web-era first purchases; the cohort window hides pre-2024 rows.
4. **`pay_for_%`-basis channel sizes (F1, F3).** No result CSV re-runs the β split under `pay_for_%`; the only channel-size artifacts in `data/` are `pay_%`-basis.

> Note (out of lens): `age` column contains garbage extremes (min −20,048,780; max 2010) despite 98% fill. Flagged for the data-quality/cohort reviewer, not a channel-bias issue.
