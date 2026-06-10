#!/usr/bin/env python3
"""
과제2 근본 개념검증: 노출정규화 interest_lift vs 구매 co-purchase(P0).
질문: interest_lift가 자기강화(노출결합) pair를 lift≈1로 강등하고, 진짜 관심을 분별하는가?
"""
import pandas as pd, numpy as np
class _R:  # spearman = pearson on ranks (scipy 없이)
    def __init__(s,c): s.correlation=c
def spearmanr(a,b):
    a=pd.Series(np.asarray(a,float)); b=pd.Series(np.asarray(b,float))
    if len(a)<2: return _R(np.nan)
    ra,rb=a.rank().values,b.rank().values
    if np.std(ra)==0 or np.std(rb)==0: return _R(np.nan)
    return _R(float(np.corrcoef(ra,rb)[0,1]))

poc=pd.read_csv('task2_interest_lift_poc.csv')   # A,B,viewers,buyers,cvr_from_A,base_cvr,interest_lift
p0=pd.read_csv('nbo_table_a_appfirst_p0.csv')    # anchor,anchor_name,rank,rec_menu,rec_name,conf_pct,lift,wilson_lb_pct...
for c in ['A','B']: poc[c]=poc[c].astype(int)
for c in ['anchor','rec_menu','rank']: p0[c]=p0[c].astype(int)

print(f"=== POC interest_lift universe (viewers>=30) ===")
print(f"  pairs {len(poc)} · anchors {poc.A.nunique()} · 후보 B {poc.B.nunique()}")
il=poc.interest_lift.replace([np.inf,-np.inf],np.nan).dropna()
print(f"  interest_lift 분포: min {il.min():.2f} · p25 {il.quantile(.25):.2f} · median {il.median():.2f} · p75 {il.quantile(.75):.2f} · max {il.max():.2f}")
print(f"  lift>=1.3(진짜관심) {100*(il>=1.3).mean():.0f}% · 0.9~1.1(노출결합·평범) {100*il.between(0.9,1.1).mean():.0f}% · <0.7(역신호) {100*(il<0.7).mean():.0f}%")
print(f"  → 스프레드 있음 = 신호가 변별력 있음" if il.std()>0.2 else "  → 변별력 약함")

# 이름 맵
nm=dict(zip(p0.rec_menu,p0.rec_name)); nm.update(dict(zip(p0.anchor,p0.anchor_name)))
def name(s): return nm.get(int(s),f'({int(s)})')

# P0(구매 co-purchase) ∩ POC(노출정규화) 조인
j=p0.merge(poc,left_on=['anchor','rec_menu'],right_on=['A','B'],how='inner')
print(f"\n=== P0 top-N 추천 ∩ POC 비교 ({len(j)} pairs, {j.anchor.nunique()} anchors) ===")
print(f"  P0가 추천한 pair 중 노출정규화 가능(viewers>=30): {len(j)}/{len(p0)} ({100*len(j)/len(p0):.0f}%)")

# 상관: 구매 conf vs interest_lift
r1=spearmanr(j.conf_pct,j.interest_lift).correlation
r2=spearmanr(j.conf_pct,j.cvr_from_A).correlation
print(f"  Spearman(구매 conf_pct, interest_lift) = {r1:.2f}  ← 낮을수록 '구매빈도≠관심강도'(노출 교란 존재)")
print(f"  Spearman(구매 conf_pct, cvr_from_A)     = {r2:.2f}")

# 자기강화 검출: P0 상위(rank<=3, 구매빈도 높음)인데 interest_lift<=1.1 → 노출결합
loop=j[(j['rank']<=3)&(j.interest_lift<=1.1)].sort_values('conf_pct',ascending=False)
keep=j[(j['rank']<=3)&(j.interest_lift>=1.3)].sort_values('interest_lift',ascending=False)
print(f"\n=== [자기강화 강등 후보] P0 상위(rank≤3)지만 interest_lift≤1.1 = 노출결합 의심 ===")
print(f"  {len(loop)}건 / P0 상위 {len(j[j['rank']<=3])}건 ({100*len(loop)/max(1,len(j[j['rank']<=3])):.0f}%)")
for _,r in loop.head(8).iterrows():
    print(f"   · {name(r.anchor)[:16]:<17}→ {name(r.rec_menu)[:18]:<19} P0 conf {r.conf_pct:>4.1f}%·rank{r['rank']} | interest_lift {r.interest_lift:.2f} (cvr {r.cvr_from_A:.2f} vs base {r.base_cvr:.2f})")
print(f"\n=== [관심 확정] P0 상위 & interest_lift≥1.3 = 진짜 관심(유지) ===")
for _,r in keep.head(8).iterrows():
    print(f"   · {name(r.anchor)[:16]:<17}→ {name(r.rec_menu)[:18]:<19} P0 conf {r.conf_pct:>4.1f}%·rank{r['rank']} | interest_lift {r.interest_lift:.2f}")

# 숨은 관심: interest_lift 높은데 P0에선 약하거나 없음
hidden=poc.merge(p0[['anchor','rec_menu','rank']],left_on=['A','B'],right_on=['anchor','rec_menu'],how='left')
hidden=hidden[(hidden.interest_lift>=1.5)&(hidden['rank'].isna())&(hidden.viewers>=50)].sort_values('interest_lift',ascending=False)
print(f"\n=== [숨은 관심] interest_lift≥1.5 인데 P0 추천엔 없음 (노출신호만 잡아냄) ===")
print(f"  {len(hidden)}건")
for _,r in hidden.head(8).iterrows():
    print(f"   · {name(r.A)[:16]:<17}→ {name(r.B)[:18]:<19} interest_lift {r.interest_lift:.2f} (viewers {int(r.viewers)}, cvr {r.cvr_from_A:.2f})")

# 앵커별 재랭킹 정도
print(f"\n=== 앵커별 재랭킹 (구매순위 vs interest_lift순위) ===")
churn=[]
for A,g in j.groupby('anchor'):
    if len(g)<3: continue
    rho=spearmanr(g.conf_pct,g.interest_lift).correlation
    if not np.isnan(rho): churn.append(rho)
print(f"  앵커 {len(churn)}개(pair≥3) 평균 Spearman {np.mean(churn):.2f} · 음/약상관(<0.3) 앵커 {100*np.mean(np.array(churn)<0.3):.0f}%")
print(f"  → 낮을수록 노출정규화가 추천 순서를 크게 바꿈")
