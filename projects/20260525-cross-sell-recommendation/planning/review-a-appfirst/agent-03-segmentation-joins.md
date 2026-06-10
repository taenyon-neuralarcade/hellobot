# Agent-03 Review — Segment Classification & Joins (A app-first, Revision 2)

Reviewer lens: how SKUs are tagged into topic / intents / content_type, how segments are formed, and whether the joins/partitions bias the headline conclusions. Verified against `data/master_users.csv` (98,392 rows) and `data/master_export.sql` only. No BigQuery run.

---

## 1) Verdict

**Conditional pass with two material defects.** The core descriptive distributions (topic §R2-4, content_type §R2-3, age fill, coverage rates, headline rev90/sameday/any90/ever) reproduce **exactly** from the CSV — the join keys are clean and `ANY_VALUE` did not manifest nondeterminism within this cohort. However:

- **The "spine of the analysis" (§R2-2) is a misleading partition.** The "재방문 리텐션 = 23.4% (23,049)" bucket is mutually exclusive with the "당일 업셀 50%" bucket, which **drops 20,178 users (20.5%) who did BOTH a same-day upsell and a later revisit-purchase**. The true revisit-buyer incidence is the headline **rev90 = 38.4% (37,735)** — the same document states both 38.4% and 23.4% for "revisit," a self-contradiction. The 23.4% understates the population the report says recommendations should target ("추천이 키울 영역은 재방문") by ~14,686 users / 14.9pp.
- **The §R2-6 transition tables are not reproducible** from the master CSV (the SSOT). No natural cohort subset reproduces the stated 2nd-content base (타로38.5/사주43.2) or `love→love revisit n=12,068`. The qualitative findings (사주→타로 lift<1, diagonal stickiness) replicate, but the published confidences/N's do not.

Two display omissions (R2-3/R2-4 silently drop ~6 SKU categories) and a methodology-doc error (intents delimiter) are lower severity but real.

---

## 2) Findings

### [HIGH] · §R2-2 "당일 업셀 vs 재방문 리텐션 분리 (분석의 척추)" · partition is non-exhaustive of revisit behavior
**Claim/code.** "당일 업셀 50.0% (49,235) / 재방문 리텐션 23.4% (23,049) / 2회차 없음 26.6%." The 23,049 = `has_2nd=1 AND second_sameday=0` (reproduced exactly). The partition keys on whether the **2nd** purchase was same-day.
**Why wrong + recomputed.** The partition is mutually exclusive, so any user whose 2nd purchase was same-day is locked into the "당일" bucket even if they later revisited and bought again. Recompute:
- users with a same-day upsell AND a different-day repurchase within 90d (`c_sameday>0 AND c_rev90>0`) = **20,178 (20.5%)**.
- true different-day revisit incidence = `c_rev90>0` = **37,735 = 38.4%** — identical to the headline rev90 the report prints in §R2-1.
- So the report simultaneously asserts revisit = 38.4% (R2-1) and revisit = 23.4% (R2-2). The 23.4% figure excludes the 20,178 "both" users → understates revisit population by **14,686 / 14.9pp**.
The report builds its strategy on this ("당일 50%는 자연발생 → 추천이 키울 영역은 재방문(현 23%)"). With the correct definition the addressable revisit population is 38.4%, and 20.5% of users are *both* same-day and revisit buyers (the most valuable segment), not an either/or.
**Fix.** Report revisit as the **incidence** rev90 = 38.4% (overlapping with same-day), and present the partition as a 4-way Venn: same-day-only 29,057 / revisit-only 23,049 / both 20,178 / none 26,108 — not a 3-way mutually-exclusive split that hides the "both" cell. Relabel "재방문 리텐션 23.4%" as "revisit-only (no same-day upsell)."

### [HIGH] · §R2-6 Transition tables · not reproducible from master_users.csv (SSOT)
**Claim/code.** R2-6 states it recomputes transitions on the "REVISIT 2회차 기준, n=23,049," with content base `2nd=타로38.5%/사주43.2%`, `love→love revisit n=12,068 (79.4%)`, `사주→타로 26.5% lift0.69`, `사주→사주 56.6% lift1.31`, `타로→사주 17.3% lift0.40`.
**Why wrong + recomputed.** Using the only 2nd-purchase columns in the CSV (`s_ctype`, `s_topic` = the rn=2 overall purchase) over the stated cohort `has_2nd=1 AND second_sameday=0` (n=23,049, reproduced exactly):
- base 2nd ctype = **타로 36.4% / 사주 50.6%** (claimed 38.5 / 43.2)
- 사주→사주 = **60.6%** (claimed 56.6%); 타로→사주 = **26.5%** (claimed 17.3%)
- love→love = **14,143 (83.8%)** (claimed n=12,068, 79.4%); family→family **53.7%** vs 42.9%; money→money **23.3%** vs 19.6%
The lifts roughly match (사주→타로 0.73 vs 0.69; money→money 8.7 vs 8.5; family 34 vs 31) but every confidence/N is consistently higher and no tested subset (lifetime 23,049 / different-day-within-90 17,557 / tagged-only 20,450) reproduces the published base or `n=12,068`. Conclusion: R2-6 was computed against some other artifact (likely a separate `phase3_users`-style export or a windowed "first-revisit" definition), and the SSOT CSV cannot regenerate it.
**Fix.** Either (a) republish R2-6 from the master CSV so the numbers reconcile, or (b) state explicitly which export R2-6 used and add a "first-revisit SKU" column to the master so it is auditable. Until then, treat R2-6 confidences as **unverified**. (Directional finding 사주→타로 lift<1 does replicate — that survives.)

### [MEDIUM] · §R2-3 content_type table · silently drops 3 SKU categories (751 rows)
**Claim/code.** R2-3 lists only 타로 / 사주 / 점성학 / (미태깅) (n sum = 97,641).
**Why wrong + recomputed.** `f_ctype` also contains **진단 (540), 손금 (76), 기타 (135)** = **751 rows** that appear in no displayed bucket — and §Phase2 already enumerated the full value set (타로/사주/점성학/손금/진단/기타/null), so the author knew they existed. 손금 has rev90 46.1% (highest of all ctypes), 진단 37.0%. Dropping them is a presentation gap, not a math error, but the table does not foot to N=98,392 and a reader cannot tell rows are missing.
**Fix.** Add a "기타형식(진단/손금/기타) n=751" row or a footnote so the table sums to N. The 타로/사주 headline numbers themselves are correct (verified exact).

### [MEDIUM] · §R2-4 topic table · silently drops 494 rows (299 blank + 195 "기타")
**Claim/code.** R2-4 lists 8 named topics (sum = 97,898); "topic매칭 99.7%."
**Why wrong + recomputed.** Two omissions: (1) the **299 blank `f_topic`** rows (the 0.30% untagged that 99.7% implies) are not shown as a "(미태깅)" row — unlike the Phase 1.2 rev1 table which did show "(미태깅) 5,426." (2) A distinct topic value **"기타" (n=195)** exists in the data and is shown nowhere. Total dropped = **494** (rev90 of the dropped = 40.9%, above overall 38.4 — non-random). All 8 named-topic numbers reproduce exactly (연애 71,129 rev90 40.8; 가족자녀 2,058 rev90 21.6; etc.).
**Fix.** Restore the "(미태깅) 299" row and add/merge "기타 195" so R2-4 foots to N.

### [LOW] · §Phase2 "연애 intents" / R2-9 · stated intents delimiter `[,\s]+` is wrong (actual = `|`)
**Claim/code.** "intents 멀티라벨 '포함' 방식 채택 (구분자 `[,\s]+` 정규화 후 토큰 분리)."
**Why wrong + recomputed.** The only multi-label delimiter in `f_intents` is the **pipe `|`** (2,975 rows; no commas, no spaces). Splitting on `[,\s]+` as documented would leave 11 compound labels intact (`재회|속마음` 845, `재회|궁합` 671, …; 1,698 rows total) as bogus single intents. The published love-intent numbers match a **correct pipe-split**, so the analysis code almost certainly split on `|` despite the doc — but the documented regex is reproducibly wrong and would mislead anyone re-running it.
**Fix.** Correct the doc to `[,\s|]+` (or just `|`). The double-counting note ("합≠전체(겹침 정상)") is correct: token sum within 연애 = 72,827 vs n=71,129, overlap 1,698 — multi-label users are intentionally counted in each label, which is fine for a "포함/contains" breakdown as long as it is not summed to a total.

### [LOW] · §Phase2b age buckets · `age` column contains corrupt values (not just nulls)
**Claim/code.** "age 채움 98%" → age axis usable.
**Why wrong + recomputed.** Fill rate is correct (96,610 / 98.19%). But the age **values** are partly garbage: range −20,048,780 … 2,010 (a birth year), 166 rows (0.17%) outside a plausible 14–90 band — 160 negative values bucket into "<25", and 4 year-like values (1941, 2007, 2009, 2010) bucket into "45+". Impact is small (0.17% of tagged) but the buckets are not cleaned; "<25" carries ~160 spurious members.
**Fix.** Clip/exclude implausible ages (`age<14 OR age>90`) before bucketing; note 166 excluded. Does not change any conclusion.

---

## 3) Verified correct (reproduced exactly from CSV)

- **N = 98,392** (98,393 lines − header). ✔
- **Headline metrics:** any90 = 67.9% (66,792), rev90 = 38.4% (37,735), sameday = 50.0% (49,235), ever-2nd = 73.5% (72,284). All match R2-1/R2-2 to the printed precision. ✔
- **Coverage rates:** f_topic coverage 99.70% (blank 299) = R2-1 "topic매칭 99.7%"; f_ctype coverage 92.37% (untagged 7,507) = R2-3 untagged; age fill 98.19% = "age 채움 98%". ✔
- **R2-4 topic** — all 8 named topics reproduce exactly (n, any90, rev90, sameday). ✔
- **R2-3 content_type** — 타로 30,601 / 사주 58,707 / 점성학 826 / 미태깅 7,507 reproduce exactly (subject to the dropped-rows finding above). ✔
- **days_to_2nd distribution** (R2-2): 0d 68.1% / 1–7d 13.1% / 8–30d 6.3% / 31–90d 4.9% / 90+ 7.6% — matches 68/13/6/5/8. ✔
- **ANY_VALUE nondeterminism risk did NOT materialize:** across all 1,047 distinct `f_menu` in the cohort, each maps to exactly one `f_topic`, one `f_ctype`, one `f_intents` (0 multi-mappings). So `ANY_VALUE(topic)` / `ANY_VALUE(chatbot_content_type)` picked a stable value here. ✔ (Risk note: still nondeterministic in principle for any menu_seq the sheet maps to >1 topic; not auditable for menus absent from this cohort.)
- **Internal consistency:** `has_2nd` ≡ `total_pays≥2` (0 mismatches); `second_sameday=1` ≡ `days_to_2nd=0` (0 mismatches); total_pays==1 (26,108) = "no-2nd" count. ✔
- **No null→연애일반 topic-coalescing in the CSV:** blank `f_topic` stays blank (299), is NOT flipped to 연애. The "null→연애일반" default is an **intents-within-연애** label (30,535 love rows with blank intents), not a topic default — so it cannot inflate the 연애 topic. The SQL (master_export.sql) does no `COALESCE`, consistent with the CSV. ✔
- **LEFT JOIN NULLs are bucketed, not dropped:** unmatched f_menu yields blank f_topic/f_ctype, which the tables route to "(미태깅)" — they are retained in N (no silent row loss at join time; the only losses are at the **display** layer, findings above).

## 4) Could not verify

- **R2-6 transition confidences/N's** — not reproducible from master_users.csv (see HIGH finding). Need the actual export R2-6 used.
- **`ANY_VALUE` nondeterminism for menus outside this cohort** — the source sheet `taenyon_temp_skill_tag_info_v2` and `mart_fixed_menu_server` are not in the repo; cannot confirm whether any menu_seq has >1 topic/ctype in the source (would require BQ, which is prohibited). Risk is real because the tag table is a hand-authored TEMP Google Sheet, but within the observed cohort it caused no conflict.
- **Cohort maturity for 2026 first-buyers (5,115 / 5.2%)** — the CSV has only `f_year`, no dates, so I cannot confirm all 2026 rows had a full T-90 observation window before export. Their rev90 (28.3%) is depressed vs overall (38.4%), consistent with right-censoring; if the export date < first-buy + 90d for some, the overall 38.4% is slightly understated. Cannot quantify without dates.
- **Whether the 49,235 "sameday" purchases are genuine upsells vs bundle/installment artifacts** — the report itself flags this as an open ISS; no SKU-level timestamp data in the CSV to adjudicate.
