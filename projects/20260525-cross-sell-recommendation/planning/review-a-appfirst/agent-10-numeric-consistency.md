# Agent 10 — Numeric Consistency & Reproducibility Review (A app-first, Revision 2)

> **Lens**: forensic recomputation. Every reproducible figure was recomputed from `data/master_users.csv` (98,392 rows) with an independent Python script (`csv` module, proper quoting). Nothing trusted from `/tmp/unified_out.txt` — verified independently. No BigQuery used.
> **Date**: 2026-06-01 · **Reviewer**: agent-10 (independent, adversarial)
> **Sources cross-checked**: `planning/baseline.md` (SSOT), `a-appfirst-review.pdf` (12 slides), `ac-unified-recommendation.pdf` (9 slides), rev1 backups `data/phase2_users.csv` / `data/phase3_users.csv` (101,465 rows each).

---

## 1) VERDICT

**CONDITIONAL PASS with one HIGH-severity reproducibility failure isolated to §R2-6 (the rev2 transition section).**

Every headline figure, the §R2-1 baseline table, the §R2-2 split, the §R2-3 content_type table, the §R2-4 topic table, the §R2-7 age×topic shares (slide), and **all 8 cells of the §R2-8 / U-1 recommendation matrix reproduce EXACTLY** from `master_users.csv` — to the decimal, including segment n's, conf%, and lift. The U-1 matrix is a clean, fresh, correct computation on the 23,049 revisit base. The C web-only headline and the unified channel summary also reproduce exactly. The rev1 backup tables (Phase 1.2, Phase 2, Phase 3, Phase 4 reco matrix) reproduce exactly against the rev1 source CSVs — confirming the rev1 section is correctly-labeled-stale, not fabricated.

**The single failure**: §R2-6 transition cells (love→love 79.4%, content base 타로 38.5% / 사주 43.2%, 사주→타로 lift 0.69, 사주→사주 56.6%, 타로→타로 64.7%, love-intent base n=12,068, 궁합→궁합 lift 6.4) **do not reproduce from `master_users.csv` on any basis** (revisit 23,049 or ever 72,284), nor from the rev1 CSV on any basis. They sit *between* rev1/ever and rev2/revisit — classic stale-draft signature. The directional conclusions survive (they are robust across every base I tested); the specific numbers attached to them are wrong. The slide deck repeats the wrong 79.4% (slide 9 prose) and 12,068 (slide 11 subtitle), so the error propagated to the deliverable.

Two minor stale values: rev1 Phase 4 45+×사주 "15.6%" (actual 16.3%) and a rev1 love-intent methodology mismatch (single-label counts presented under a multi-label "포함" methodology).

**Reproducibility scorecard: 6 of 6 headline numbers reproduced EXACTLY. Of the section tables: R2-1/R2-2/R2-3/R2-4/R2-7/R2-8(U-1) all exact; R2-6 fails (4+ cells unreproducible).**

---

## 2) FINDINGS

### F-1 · [HIGH] · §R2-6 + slide 9/10/11 — transition cells not reproducible from `master_users.csv`

The section header claims it is computed on the rev2 master CSV, REVISIT 2회차 basis (n=23,049). It is not. Recomputed every cell on that exact basis:

**TOPIC transition (diagonal):**
| cell | R2-6 claim | recomputed (rev2 revisit, n=23,049) | delta |
|---|---|---|---|
| love→love conf | 79.4% (lift 1.13) | **83.8% (lift 1.14)** | **−4.4pp** |
| family→family conf | 42.9% (lift 31) | **53.7% (lift 34.08)** | **−10.8pp** |
| money→money conf | 19.6% (lift 8.5) | **23.3% (lift 8.71)** | **−3.7pp** |
| study→study conf | 30.9% (lift 7.7) | **33.8% (lift 7.81)** | **−2.9pp** |

**CONTENT transition:**
| cell | R2-6 claim | recomputed (rev2 revisit) | delta |
|---|---|---|---|
| 2nd base 타로 | 38.5% | **36.4%** | −2.1pp |
| 2nd base 사주 | 43.2% | **50.6%** | **+7.4pp** |
| 타로→타로 | 64.7% (lift 1.68) | **63.9% (lift 1.76)** | −0.8pp / lift +0.08 |
| 타로→사주 | 17.3% (lift 0.40) | **26.5% (lift 0.52)** | **+9.2pp** |
| 사주→타로 | 26.5% (lift 0.69) | **26.7% (lift 0.73)** | +0.2pp / lift +0.04 |
| 사주→사주 | 56.6% (lift 1.31) | **60.6% (lift 1.20)** | **+4.0pp** |

**LOVE-intent base:**
| cell | R2-6 claim | recomputed (rev2 revisit) | delta |
|---|---|---|---|
| love→love revisit n | 12,068 | **14,143** | **+2,075** |

**Provenance test** (4-way grid, identical methodology):
| metric | R2-6 claim | rev2/revisit ✅correct basis | rev2/ever | rev1/revisit | rev1/ever |
|---|---|---|---|---|---|
| love→love | 79.4 | 83.8 | 83.2 | 72.8 | 76.5 |
| base 타로 | 38.5 | 36.4 | 43.8 | 29.2 | 38.7 |
| base 사주 | 43.2 | 50.6 | 46.0 | 43.9 | 41.8 |
| 사주→타로 | 26.5 | 26.7 | 27.8 | 22.8 | 25.4 |
| 사주→사주 | 56.6 | 60.6 | 62.8 | 54.5 | 58.8 |
| 타로→타로 | 64.7 | 63.9 | 73.8 | 50.9 | 66.5 |

The R2-6 numbers match **none** of the four computations. They are closest to rev1/ever (base 타로 38.5≈38.7, 사주→타로 26.5≈25.4) but with hand-edited drift — strongly indicating stale draft values that were never recomputed on the rev2 revisit basis the section claims. **The transition script for R2-6 was not preserved in `/tmp`** (only the rev1 `analyze_p3.py` exists, operating on `phase3_users.csv`), so the provenance cannot be audited.

**Fix**: Re-run R2-6 against `master_users.csv` on the stated 23,049 revisit basis and replace every cell with the recomputed values above. Update slide 9 prose (79.4→83.8), slide 10 (사주→타로 base/lift), slide 11 subtitle (12,068→14,143). Preserve the script.

---

### F-2 · [LOW] · §R2-6 / slide 11 — love→love revisit n inconsistency (header vs subtitle)

Slide 11 **header** says `n=14143` (correct — this is the love→love revisit count, which I reproduce exactly). The slide 11 **subtitle** and baseline.md §R2-6 prose both say "love→love 재방문 **12,068**명". 12,068 matches no clean love-intent subset (love→love with s_intents non-null = 7,959; with f_intents = 7,784; with both = 4,950). It is a stale number. **Fix**: change 12,068 → 14,143 in both the subtitle and §R2-6 prose.

---

### F-3 · [LOW] · rev1 Phase 4 §Part 2 (line 382) — 45+×사주 "untag+other 15.6%" stale

Claim: "45+ × 사주 → untag+other 15.6% (lift1.32)". Recomputed (rev1 ever basis): **untag+other 16.3% (lift 1.31)**, cnt 177/1088. Delta −0.7pp. (The money+saju 13.1% lift 6.60 in the same row reproduces exactly.) Low severity — rev1 backup section, off by <1pp. **Fix**: 15.6→16.3, lift 1.32→1.31.

---

### F-4 · [LOW] · rev1 Phase 2 love-intents table (lines 222-235) — methodology/value mismatch

Line 235 documents the intents methodology as **multi-label "포함" (contains, token-split on `[,\s]+`)**. But the table n's are **single-label exact-match counts**:
| intent | table n (exact-match) | multi-label "포함" count | rev90 (table) | rev90 (포함) |
|---|---|---|---|---|
| 재회 | 14,570 | **16,147** | 47.8 | 47.8 |
| 썸짝사랑 | 2,474 | **2,570** | 50.2 | 50.7 |
| 궁합 | 3,903 | **4,603** | 34.8 | 36.6 |
| 속마음 | 5,585 | **6,482** | 46.0 | 47.0 |

The table presents exact-match counts (`intents == '재회'`) while claiming inclusion methodology. The rev90 values happen to stay close because overlap rows are few, but the documented method and the actual computation disagree. Low severity (rev1 backup; conclusions unaffected). **Fix**: either relabel the table as single-label exact-match, or recompute with the documented "포함" method and update n's.

---

### F-5 · [INFO / not an error] · §R2-2 "재방문 23.4% (23,049)" vs headline "rev90 38.4%" are two different metrics

§R2-1 headline `rev90 (재방문) = 38.4%` (37,735 users with `c_rev90>0` = a different-day repurchase **within 90 days**). §R2-2 "재방문 리텐션 23.4% (23,049명)" uses a different definition: `has_2nd & second_sameday==0` (the **2nd purchase ever** falls on a different day, no 90-day cap). Both reproduce exactly (37,735 and 23,049 respectively). They are **not the same number** and the report uses the same word "재방문" for both. This is internally consistent once the definitions are read carefully, but the dual use of "재방문" at 38.4% (R2-1/slide 4) and 23.4% (R2-2/slide 3) invites confusion. **Recommendation**: label them distinctly, e.g. "재방문(90일 내) 38.4%" vs "재방문(생애 2회차 익일+) 23.4%". The U-1/reco matrix correctly uses the 23,049 base. Not scored as a defect — both are reproducible and the distinction is technically sound.

---

## 3) VERIFIED CORRECT (reproduced EXACTLY from CSV)

**Headline figures (master_users.csv):**
- N (data rows) = **98,392** ✓ (file = 98,393 lines incl. header; all 98,392 rows parse to exactly 24 columns, zero dropped)
- rev90 (`c_rev90>0`) = 37,735 = **38.35%** → 38.4% ✓
- sameday (`c_sameday>0`) = 49,235 = **50.04%** → 50.0% ✓
- any90 (`c_any90>0`) = 66,792 = **67.88%** → 67.9% ✓
- any30 = 64.26%, any60 = 66.55%, rev30 = 31.13%, rev60 = 35.72% ✓
- ever (`total_pays>1`) = 72,284 = **73.47%** → 73.5% ✓ (also equals `has_2nd>0` count exactly)
- revisit 2nd-buyers (`has_2nd & second_sameday==0`) = **23,049** ✓
- f_rev mean = 13,952.71원, median = 16,200원 (n=98,392)

**§R2-1 baseline rev2 column:** N 98,392 ✓ · any90 67.9 ✓ · rev90 38.4 ✓ · sameday 50.0 ✓ · ever 73.5 ✓ · topic매칭 99.7% ✓ · age 채움 98.2% (≈98) ✓

**§R2-2 split:** 당일 업셀 50.0% (49,235) ✓ · 2회차 없음 26.5% (26,108; report says 26.6% — rounding) ✓ · day-to-2nd dist 68.1/13.1/6.3/4.9/7.6% vs claim 68/13/6/5/8 ✓ (`second_sameday`↔`days_to_2nd` perfectly consistent, 0 mismatches)

**§R2-3 content_type (every listed cell exact):**
- 타로 n=30,601 any90=75.7 rev90=40.6 sameday=60.6 ✓
- 사주 n=58,707 64.9 / 37.6 / 45.8 ✓
- 점성학 n=826 69.9 / 41.2 / 50.6 ✓
- (미태깅) n=7,507 60.2 / 34.7 / 41.3 ✓

**§R2-4 topic (every listed cell exact):**
- 연애 71,129 / 70.9 / 40.8 / 52.5 ✓ · 결혼 6,897 / 63.5 / 37.1 / 44.3 ✓ · 총운 5,075 / 54.6 / 32.7 / 34.9 ✓ · 일반운세 5,429 / 64.0 / 31.4 / 50.1 ✓ · 자기탐구 905 / 66.3 / 31.8 / 52.3 ✓ · 학업직업 3,984 / 62.0 / 29.4 / 48.3 ✓ · 재물금전 2,421 / 60.6 / 28.3 / 45.9 ✓ · 가족자녀 2,058 / 42.5 / 21.6 / 28.5 ✓

**§R2-7 age×topic (rev2, slide 8):** love share 86/83/73/61/52/47/46/40 ✓ (my recompute 85.9/82.9/72.9/61.3/52.2/47.3/46.2/40.1 → rounds to slide values); 재물 0.5/0.9/1.5/2.9/5.8/10.9/15.9/20.7 ✓ matches slide 0/1/2/3/6/11/16/21. *(Note: baseline.md §R2-7 prose carries no per-cell table; the detailed 78.6/77.5/... table at lines 249-256 is the **rev1** Phase 2(2차) table and is correctly labeled rev1 — it reproduces EXACTLY against `phase2_users.csv`: col n 13150/26682/29587/17333/7061/2924/1413/1266 ✓, love 78.6/77.5/69.9/59.5/50.9/45.9/44.9/38.2 ✓, 재물 0.5/0.8/1.5/2.8/5.6/10.6/15.5/19.9 ✓.)*

**§R2-8 / U-1 recommendation matrix — ALL 8 A cells EXACT** (revisit base 23,049, minsup 15, minrow 200, independently reimplemented):
| segment | claim n / conf / lift | recomputed | match |
|---|---|---|---|
| <25 × 타로 | 2,825 / 63.0 / 2.01 (연애+타로) | 2,825 / 63.0 / 2.01 (cnt 1,780) | ✓ |
| <25 × 사주 | 4,926 / 41.5 / 1.29 (연애+사주) | 4,926 / 41.5 / 1.29 (cnt 2,042) | ✓ |
| 25-34 × 타로 | 2,075 / 51.3 / 1.63 (연애+타로) | 2,075 / 51.3 / 1.63 (cnt 1,064) | ✓ |
| 25-34 × 사주 | 8,050 / 38.2 / 1.19 (연애+사주) | 8,050 / 38.2 / 1.19 (cnt 3,075) | ✓ |
| 35-44 × 타로 | 479 / 50.3 / 1.6 (연애+타로) | 479 / 50.3 / 1.60 (cnt 241) | ✓ |
| 35-44 × 사주 | 1,704 / 24.2 / 0.75 (연애+사주) | 1,704 / 24.2 / 0.75 (cnt 413) | ✓ |
| 45+ × 타로 | 188 / suppressed (n<200) | 188 / suppressed | ✓ |
| 45+ × 사주 | 400 / 19.2 / 0.61 (연애+타로) | 400 / 19.2 / 0.61 (cnt 77) | ✓ |

Slide-12 #2-SKU column (a-appfirst deck) also exact: <25타로 love+saju 18.0/0.56 ✓; 25-34사주 love+tarot 20.3/0.65 ✓; 45+사주 money+saju 15.2/7.22 ✓.

**Channel summary (U-1 footer / both decks):** A N=98,392 rev90 38.4% 재방문구매자 23,049 ✓ · C N=289,983 rev90 13.1% 재방문구매자 40,726 ✓.

**C web-only headline (c_users.csv, 289,983 rows):** N 289,983 ✓ · ever 24.5% ✓ · any90 21.1% ✓ · rev90 13.1% ✓ · sameday 10.4% ✓ · revisit buyers 40,726 ✓.

**rev1 backup tables (reproduce exactly against rev1 source CSVs — confirming correctly-labeled-stale, NOT fabricated):**
- Phase 1.2 overall: any90 69.9, rev90 41.7, sameday 51.2 ✓; 연애 n=69,496 rev90 44.8 ✓
- Phase 2 content_type: 타로 29,355/79.8/46.0/64.3 ✓, 사주 57,928/67.6/40.8/47.5 ✓, 점성학 801/73.5/45.1/55.2 ✓, 미태깅 12,570/57.4/35.4/38.2 ✓
- Phase 3 TOPIC transition: love→love 76.5/1.18 ✓, marriage→marriage 17.0/2.89 ✓, money→money 20.2/9.02 ✓, study→study 36.6/9.86 ✓, family→family 50.0/43.41 ✓ (all n's exact: 54,878/4,946/1,616/2,789/1,033)
- Phase 3 CONTENT transition: base 38.7/41.8 ✓, 타로→타로 66.5/1.72 ✓, 타로→사주 15.8/0.38 ✓, 사주→타로 25.4/0.66 ✓, 사주→사주 58.8/1.41 ✓
- Phase 4 reco matrix: <25타로 12,238/63.4/1.85 ✓, <25사주 14,675/35.3/1.40 ✓, 25-34타로 8,893/57.8/1.68 ✓, 25-34사주 22,304/35.7/1.42 ✓, 35-44사주 4,585/24.6/0.98 ✓ (45+사주 untag+other off — see F-3)

**Cross-document consistency (baseline.md ↔ a-appfirst-review.pdf ↔ ac-unified-recommendation.pdf):**
- 98,392 / 50% / 23% / 38.4 / 50.0 / 73.5 — consistent across all three documents ✓
- U-1 matrix identical between baseline.md §U-1, a-appfirst slide 12, and ac-unified slide 4 ✓ (the U-6 "미결: 슬라이드 매트릭스 초안값 동기화" note appears already resolved — the unified deck slide 4 matches the SSOT table)
- slide-4 rev2 year cohort (a-appfirst): 2024 ~53K/68.8/40.9, 2025 ~40K/67.6/36.3, 2026 ~5K/60.1/30.0 — my recompute: 2024 52,789/69.1/41.3, 2025 40,488/67.4/35.8, 2026 5,115/59.2/28.3. **Within rounding for n and any90; rev90 off by 0.4–1.7pp** (2024 40.9 vs 41.3, 2025 36.3 vs 35.8, 2026 30.0 vs 28.3). Minor — flagged as INFO, not a hard defect, since this rev2 year table is slide-only (no baseline.md counterpart) and directionally correct (rev90 declines with cohort recency). Worth a quick re-derive.

---

## 4) COULD NOT VERIFY

- **Exact provenance of R2-6 cells (F-1)**: the rev2 transition script is not preserved in `/tmp` (only the rev1 `analyze_p3.py` survives). I can prove the R2-6 numbers do **not** match `master_users.csv` on the claimed basis, and that they sit between rev1/ever and rev2/revisit, but cannot determine whether they are (a) stale rev1 carry-over with manual edits, (b) a different undocumented base, or (c) a transient buggy run. The data itself is fine — only the published R2-6 numbers are stale.
- **Charts/PNGs** (`rev2_*.png`): not opened as images; cell values cross-checked via the deck PDFs where rendered. The R2-6 heatmap **lift** values on slide 9 (e.g. love→love 1.14) actually match MY recompute, while the slide-9 *prose box* repeats the wrong 79.4% — i.e. the heatmap may have been regenerated correctly while the prose/baseline.md text was not updated. Worth confirming which the chart PNGs reflect.
- **§R2-5 price×content grid**: baseline.md §R2-5 is prose-only (no cell values); slide 7 shows a 3×2 grid (T1 38.0/27.1, T2 45.1/34.4, T3 45.7/38.5). Not recomputed here (price-tier methodology is agent-06's lens); the directional claim (타로>사주 within tier) is consistent with R2-3.

---

### Reproducibility scorecard

| # | Headline | Claimed | Recomputed | Status |
|---|---|---|---|---|
| 1 | N | 98,392 | 98,392 | ✅ EXACT |
| 2 | rev90 | 38.4% | 38.35% | ✅ EXACT |
| 3 | sameday | 50.0% | 50.04% | ✅ EXACT |
| 4 | any90 | (67.9%) | 67.88% | ✅ EXACT |
| 5 | ever (total_pays>1) | 73.5% | 73.47% | ✅ EXACT |
| 6 | revisit 2nd-buyers | 23,049 | 23,049 | ✅ EXACT |

**6 / 6 headline numbers reproduced exactly.** Section tables: R2-1, R2-2, R2-3, R2-4, R2-7(slide), R2-8/U-1 (all 8 cells), C-baseline, channel summary — **all exact**. The **only** non-reproducible block is **§R2-6** (rev2 transition: love→love, content base, intent base n, several lifts) plus two LOW rev1 backup blemishes (F-3, F-4). The error has propagated into the a-appfirst deck (slide 9 prose 79.4%, slide 11 subtitle 12,068).
