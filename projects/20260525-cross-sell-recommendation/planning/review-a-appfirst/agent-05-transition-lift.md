# Agent-05 Review — Transition Matrix, Confidence & Lift (A app-first, Revision 2)

**Reviewer**: Independent adversarial data analyst (agent-05)
**Scope**: baseline.md §Phase 3 (Transition Matrix), §Phase 4, §R2-6, plus cross-check of U-section. C / A·C blocks out of scope except cross-check.
**Method**: python3 recomputation against `data/master_users.csv` (98,392 rows + header) and `data/phase3_users.csv` (rev1, 101,465 rows). NO BigQuery. SQL read: `data/master_export.sql`, `data/phase3_export.sql`.
**Date**: 2026-06-01

---

## 1) VERDICT

**Conditional fail on the transition section — directional conclusions survive, but the stated methodology does not match the data, and the specific R2-6 cell numbers are not reproducible from the rev2 master CSV.**

Two structural problems and one numeric-reproducibility problem:

- **(STRUCTURAL, blocking)** The contract says transitions are computed on the "revisit within 90d 2nd-buyer base (n=23,049)". But the CSV `s_*` columns describe each user's **GLOBAL 2nd purchase (rn=2 by timestamp)**, not the "revisit within 90d" event. The 23,049 base (`has_2nd=1 AND second_sameday=0`) is "global 2nd purchase fell on a different day **at any horizon**" — **23.8% (5,492) of it has `days_to_2nd > 90`**, directly contradicting "within 90d". A clean within-90d base is **17,557**, not 23,049.
- **(STRUCTURAL, blocking)** The word "재방문/revisit" is used for two different populations: the headline **rev90 = 38.4% (37,735, `c_rev90>0`)** vs the transition/R2-2 base **23.4% (23,049, `second_sameday=0`)**. **53.5% of the rev90 population (20,178) is NOT in the transition base** because their global 2nd purchase was same-day — so for over half the "revisit" users the `s_*` SKU literally describes a same-day upsell, not the revisit purchase.
- **(NUMERIC, high)** The R2-6 cell numbers (love→love 79.4%, content 사주 base 43.2%, love-intent base n=12,068, 궁합→궁합 lift 6.4) **do not reconcile** with any base reconstructable from `master_users.csv`. By contrast, the **U-section matrix (U-1) reproduces EXACTLY** on the 23,049 base — proving the U-1 table is a fresh, correct computation while R2-6's cells are stale/from a different run.

The qualitative headlines (love self-completing, 사주→타로 under-represented lift<1, format stickiness, diagonal self-stickiness) are **robust across every base I tested** and survive. The numbers attached to them in R2-6 do not.

---

## 2) FINDINGS

### F-1 · [HIGH] · §R2-6 / R2-2 + `master_export.sql` L15,36,39 — "revisit 2nd" base uses the GLOBAL 2nd SKU, not the revisit-90d SKU

**Claim**: "rev2는 **재방문 2회차만** 으로 전이를 봄" / "재방문 리텐션 23.4% (23,049명)" / transitions recomputed "on the REVISIT 2회차 base n=23,049".

**Code**: `second_p` = `ord WHERE rn=2` (rn = `ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_timestamp ASC)`). So `s_menu/s_rev/s_topic/s_ctype` = the **chronologically 2nd purchase overall**, regardless of how far out it is or whether it was same-day. The base `has_2nd=1 AND second_sameday=0` = "global 2nd happened on a different calendar day".

**Why wrong + recomputed**:
- Base count `has_2nd=1 AND second_sameday=0` = **23,049** ✓ (matches the claim's count exactly — so this IS the base used).
- But of those 23,049, **5,492 (23.8%) have `days_to_2nd > 90`**. Their "revisit" 2nd purchase is months/years later — **not "within 90d"**. The contract `rev90 = revisit within 90d` is violated for ~1 in 4 transition rows.
- A base that actually honors "revisit within 90d" (`has_2nd=1 AND 1 ≤ days_to_2nd ≤ 90`) = **17,557**, not 23,049 (delta −5,492, −23.8%).
- days_to_2nd distribution among the 72,284 ever-2nd users: 0d 68.1% / 1–7d 13.1% / 8–30d 6.3% / 31–90d 4.9% / **91d+ 7.6%**.

**Fix**: Either (a) rename the base to "global 2nd on a different day (any horizon)" and drop the "within 90d" claim, or (b) rebuild on `1 ≤ days_to_2nd ≤ 90` (n=17,557) to match the contract. The two differ by 23.8% of rows.

---

### F-2 · [HIGH] · Headline vs R2-2 — "재방문" labels two different populations (38.4% vs 23.4%)

**Claim**: Headline `rev90 = 38.4%`; R2-2 "재방문 리텐션 = 23.4% (49,235 sameday / 23,049 revisit / 26,108 none)".

**Why wrong + recomputed**:
- `rev90` (`c_rev90>0`, "≥1 purchase on days 1–90 after first") = **37,735 = 38.35%** ✓ matches 38.4% headline.
- R2-2 "재방문" (`second_sameday=0`) = **23,049 = 23.43%** ✓ matches.
- These are presented as the same concept ("재방문") but are **different denominators**:
  - 38.4% counts a user as revisit if ANY later purchase lands in days 1–90 — **even if their GLOBAL 2nd was same-day**.
  - 23.4% counts only users whose GLOBAL 2nd was a different day.
  - **20,178 users (53.5% of the rev90 population) are revisit-90 = yes but excluded from the 23,049 base** because their global 2nd was same-day. For these the `s_*` SKU describes the same-day upsell, so the transition matrix cannot represent their actual revisit SKU at all.

**Impact**: The transition matrix built on 23,049 systematically **drops the >50% of revisit-90 users whose revisit was their 3rd+ purchase**, and **includes 5,492 >90d users**. It is neither the 38.4% population nor a clean within-90d population.

**Fix**: Pick one definition of "revisit" and use it consistently. If the analytical intent is "what do 90-day revisiters buy on their revisit", the CSV cannot answer it — it only stored rn=1 and rn=2 attributes. A re-export capturing the *first different-day purchase within 90d* (not rn=2) would be required.

---

### F-3 · [HIGH] · §R2-6 cell numbers not reproducible from `master_users.csv` (TOPIC + CONTENT + intent)

Recomputed on the report's own base (`second_sameday=0`, n=23,049):

**TOPIC diagonal** (claim → recompute):
| cell | R2-6 conf / lift | recomputed conf / lift | row n / cnt |
|---|---|---|---|
| love→love | 79.4% / 1.13 | **83.8% / 1.14** | 16,876 / 14,143 |
| family→family | 42.9% / 31 | **53.7% / 34.1** | 395 / 212 |
| money→money | 19.6% / 8.5 | **23.3% / 8.71** | 454 / 106 |
| study→study | 30.9% / 7.7 | **33.8% / 7.81** | 797 / 269 |

**CONTENT** (claim → recompute), report base claim "타로 38.5% / 사주 43.2%":
| cell | R2-6 conf / lift | recomputed conf / lift |
|---|---|---|
| 2nd base 타로 | 38.5% | **36.4%** |
| 2nd base 사주 | 43.2% | **50.6%** |
| 타로→타로 | 64.7% / 1.68 | **63.9% / 1.76** |
| 타로→사주 | 17.3% / 0.40 | **26.5% / 0.52** |
| 사주→타로 | 26.5% / **0.69** | **26.7% / 0.73** |
| 사주→사주 | 56.6% / 1.31 | **60.6% / 1.20** |

**LOVE-intent diagonal** (claim → recompute), report base "love→love revisit n=12,068":
| cell | R2-6 conf / lift | recomputed conf / lift |
|---|---|---|
| love→love base n | 12,068 | **14,143** |
| 재회→재회 | 68.8% / 2.6 | **61.1% / 2.46** |
| 썸→썸 | 31.1% / 4.6 | **20.0% / 4.60** |
| 속마음→속마음 | 25.7% / 2.5 | **21.7% / 2.23** |
| 궁합→궁합 | 23.8% / **6.4** | **13.7% / 3.33** |

**Why wrong**: Reverse-engineering the implied 2nd base rate from R2-6's conf/lift pairs gives love base ≈70.3%, family ≈1.38%, money ≈2.31% — all **lower** than the rev2 CSV (love 73.6%, family 1.57%, money 2.68%). These implied rates are closer to the **rev1 `phase3_users.csv`** (love 2nd base 62.0% on its revisit base), but match neither cleanly. The R2-6 table appears to carry **stale numbers from a transient script run** (`/tmp/analyze_p3.py`, not preserved), not a clean recompute on the master CSV the section header claims (`data/master_users.csv`). The 궁합→궁합 lift (6.4 vs my 3.33) and 썸 conf (31.1% vs 20.0%) are off by nearly 2×.

**Fix**: Re-run all R2-6 cells against `master_users.csv` and replace the table; or preserve the actual analysis script so the base is auditable. Decide and state explicitly which base (23,049 vs 17,557) is canonical.

---

### F-4 · [MEDIUM] · §R2-6 CONTENT — "사주→타로 lift 0.69" rests on an understated 사주 2nd base

**Claim**: "사주→타로 26.5%(lift0.69) ... 미개척 기회".

**Why partially wrong + recomputed**: The *conclusion* (lift < 1, under-representation) is **robust** — I get lift 0.64–0.74 on every base (0.73 on the 23,049 base, 0.74 on within-90d, 0.64 on all-ever-2nd). But the specific **0.69** depends on the report's claimed 사주 base of 43.2%; the actual 사주 2nd base on the 23,049 set is **50.6%**, which moves lift to **0.73**. The headline survives; the decimal does not.

**Fix**: Use the recomputed base (사주 50.6% on the 23,049 set) → 사주→타로 lift 0.73, or 0.74 on the proper within-90d base. State the base.

---

### F-5 · [MEDIUM] · Small-cell instability — high lifts reported on tiny denominators

On the 23,049 base, transition-row denominators (`f_topic` group sizes), with diagonal cnt:

| f_topic | row n | diag cnt | note |
|---|---|---|---|
| 연애 | 16,876 | 14,143 | reliable |
| 결혼 | 1,832 | 277 | ok |
| 총운 | 1,377 | 208 | ok |
| 일반운세 | 1,041 | 188 | ok |
| 학업직업 | 797 | 269 | borderline |
| 재물금전 | **454** | 106 | **lift 8.71 on n=454** |
| 가족자녀 | **395** | 212 | **lift 34 on n=395** |
| 자기탐구 | **166** | 17 | unstable |
| (untagged) | 65 | 2 | noise |
| 기타 | 46 | 10 | noise |

**Why a concern**: family→family "lift 31" (R2-6) / "lift 43" (Phase 3) is computed from a **395-row** denominator against a 1.57% base — the lift magnitude is driven mechanically by the tiny base rate, not by a large/stable signal, and swings widely by base choice (34 on 23,049, 40 on within-90d, 52 on c_rev90). Phase 4 §Part 1 reports intent lifts (궁합→궁합 6.55, 썸→썸 4.74) off love-intent cells that are also small (썸 row ≈454, 궁합 row ≈818). These should carry CIs or be flagged as directional-only. Phase 4 §Part 2 already correctly suppresses n<300 cells; the topic/intent matrices do not apply the same guard.

**Fix**: Add denominator + n-guard (e.g. suppress lift display for row n<300, or show Wilson CIs) to the topic and love-intent matrices.

---

### F-6 · [LOW] · Self-transition NOT materially inflated by literal repeat-buys (concern checked, mostly clears)

**Concern**: does topic→same-topic count literal repeat-buys of the identical SKU (`same_menu=1`)?

**Recomputed** on the 23,049 base: `same_menu=1` overall = **983 (4.3%)**. Within diagonal cells:
- love→love: 769 of 14,143 = **5.4%** identical-SKU.
- 사주→사주: 347 of 9,181 = **3.8%**.
- **타로→타로: 587 of 3,698 = 15.9%** identical-SKU — notably higher.

**Verdict**: Topic self-transition is overwhelmingly genuine topic-level repeats, not identical-SKU re-buys, so the "love self-completing 76–79%" conclusion is not an artifact. **Exception: 타로→타로 has 15.9% literal identical-SKU repeats**, consistent with the "타로 = 여러 장 반복 소비" thesis — worth a footnote that ~1/6 of the 타로 stickiness is the same card-set repurchased, not cross-SKU exploration.

---

### F-7 · [INFO] · `pay_for_%` exclusion correctly implemented

`master_export.sql` filters `event_name LIKE 'pay_for_%' AND revenue_krw > 0`. The ₩750 prices seen in `s_rev` are `pay_for_contents` SKUs priced at ₩750 — **not** the excluded `pay_under_750` event (avg ₩83). Verified: `min(f_rev)=150`, **zero rows with f_rev<100**, lowest values {150, 300, 450}. R2-0 exclusion is sound. No micro-transaction leakage into the cohort.

---

## 3) VERIFIED CORRECT

- **Headlines**: N=98,392 ✓; rev90 38.35% ✓ (=38.4%); sameday 50.04% ✓ (=50.0%); ever-2nd 73.47% ✓ (=73.5%); any90 67.88% ✓ (=67.9%).
- **R2-2 counts**: sameday 49,235 ✓; revisit 23,049 ✓; no-2nd 26,108 (=26.5%, report says 26.6% — rounding) ✓.
- **U-1 unified matrix (A side) — EXACT match on the 23,049 base**: every cell reproduces to the decimal:
  - <25×타로 n=2,825 / 연애+타로 63.0% / lift 2.01 ✓
  - <25×사주 n=4,926 / 41.5% / 1.29 ✓
  - 25-34×타로 n=2,075 / 51.3% / 1.63 ✓
  - 25-34×사주 n=8,050 / 38.2% / 1.19 ✓
  - 35-44×타로 n=479 / 50.3% / 1.60 ✓
  - 35-44×사주 n=1,704 / 24.2% / 0.75 ✓
  - 45+×사주 n=400 / 연애+타로 / 19.2% / 0.61 ✓
  - 45+×타로 n=188 correctly suppressed as n<200 ✓
  This proves U-1 is a clean computation on `master_users.csv` and the 23,049 base is real — making F-3 (R2-6's non-matching cells, same claimed base) the more damning inconsistency.
- **Directional conclusions (robust across all bases tested)**: love self-completing (~80%, lift ~1.14); 사주→타로 under-represented (lift 0.64–0.74 < 1); 타로→타로 sticky (lift ~1.7); diagonal self-stickiness for niche topics; money→love weak (lift 0.34 on rev2, claim 0.28).
- **pay_for_ price filter**: correct (F-7).

---

## 4) COULD NOT VERIFY

- **Exact R2-6 cell provenance**: the script `/tmp/analyze_p3.py` is not preserved, so I cannot determine whether R2-6's numbers are (a) stale rev1 carry-over, (b) a different base, or (c) a transient buggy run. I can only state they do **not** match `master_users.csv` on the claimed 23,049 base (F-3), and the implied base rates sit between rev1 and rev2.
- **The "true revisit-90 2nd SKU"**: the CSV only stores rn=1 and rn=2 attributes. For the 20,178 rev90 users whose global 2nd was same-day, their actual first-different-day-within-90d purchase SKU is not in the data. Verifying what those users bought on revisit would require a re-export — out of scope (no BQ).
- **Charts** (`rev2_topic_transition_lift.png`, etc.): not machine-read; numbers assessed only via baseline.md text and CSV recompute.
- **Phase 4 §Part 1 love-intent full 6×6 lift matrix**: only diagonals spot-checked; off-diagonal cluster lifts (속마음↔썸 3.44/2.46) not exhaustively recomputed, though the diagonal mismatches (F-3) suggest the off-diagonals likely also drifted.

---

### Reproduction commands
All findings reproduced with `/usr/bin/python3` + `csv` on `data/master_users.csv`. Key bases:
`revisit-2nd (report) = has_2nd=1 AND second_sameday=0 → 23,049`;
`proper within-90d = has_2nd=1 AND 1≤days_to_2nd≤90 → 17,557`;
`rev90 headline = c_rev90>0 → 37,735`.
