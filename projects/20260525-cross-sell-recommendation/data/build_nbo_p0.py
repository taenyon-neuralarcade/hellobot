#!/usr/bin/env python3
"""
P0 정제본 NBO — 리뷰 개선과제 반영본 (vs 정제 전 nbo_table_a_appfirst.csv).
반영:
  과제1 출력게이트  : 판매상태(is_open&!stop_selling&buyers_30d>0) + 비콘텐츠/업셀 blocklist + 동일스킬 제외 + 카탈로그부재 제외
  과제4 통계신뢰성  : 정방향만(f→second) + 표본게이트(anchor n>=50, pair_n>=10) + Wilson 하한 정렬 + lift 분모=P(Y as 2nd)
  과제3 채널정합    : 웹 인기 12스킬 NBO는 C(웹온리, c_users.csv)로 산출
  과제2 표면분리(단기): 결제직후=s_menu / 재방문=r_menu 별도 산출
출력: nbo_table_a_appfirst_p0.csv (결제직후) · nbo_table_a_revisit_p0.csv (재방문) · web_hero_c_nbo_p0.csv
"""
import pandas as pd, numpy as np, math, re

CAT='../../20260324-coop-integration/planning/kakao_product_skills/data'

# ---- 카탈로그(상태·이름·토픽) + 유효 후보 집합 ----
seg=pd.read_csv(f'{CAT}/skills-by-segment-12m.csv')[['menu_seq','menu_name','is_open','is_stop_selling','buyers_30d','topic','chatbot_content_type']].rename(columns={'chatbot_content_type':'ctype'})
seg['menu_seq']=pd.to_numeric(seg['menu_seq'],errors='coerce')
seg=seg.dropna(subset=['menu_seq']).drop_duplicates('menu_seq')
seg['menu_seq']=seg['menu_seq'].astype(int); seg=seg.set_index('menu_seq')
def truthy(s): return s.astype(str).str.strip().str.lower().isin(['true','1','1.0','y','yes'])
seg['_open']=truthy(seg['is_open']); seg['_stop']=truthy(seg['is_stop_selling'])
seg['_b30']=pd.to_numeric(seg['buyers_30d'],errors='coerce').fillna(0)
BLOCK=re.compile(r'추천할인|추가구매|충전|질문권|하트|패키지|프리패스|이용권|구독|업셀|연속구매|코칭')
seg['_blocked']=seg['menu_name'].fillna('').str.contains(BLOCK) | seg['topic'].astype(str).eq('기타') | seg['ctype'].isna()
seg['_sellable']=seg['_open'] & ~seg['_stop'] & (seg['_b30']>0)
VALID=set(seg.index[seg['_sellable'] & ~seg['_blocked']])
def nm(s): s=int(s); return seg.loc[s,'menu_name'] if s in seg.index else f'(미상:{s})'
def tc(s): s=int(s); return f"{seg.loc[s,'topic']}/{seg.loc[s,'ctype']}" if s in seg.index else '?'
print(f"카탈로그 {len(seg):,} · 유효(판매중&콘텐츠) 후보 {len(VALID):,}")

def wilson_lb(p,n,z=1.96):
    if n==0: return 0.0
    d=1+z*z/n; c=p+z*z/(2*n); m=z*math.sqrt((p*(1-p)+z*z/(4*n))/n); return max(0.0,(c-m)/d)

def build(df, second, anchors=None, min_anchor=50, min_pair=10, topn=5):
    p=df[['f_menu',second]].dropna().astype(int); p.columns=['a','b']
    base=p.b.value_counts(normalize=True)                 # P(Y as 2nd) — 정방향 prior
    out=[]; alist=anchors if anchors is not None else sorted(p.a.unique())
    for X in alist:
        sub=p[p.a==X]; nX=len(sub)
        if nX<min_anchor: continue
        cand=sub[(sub.b!=X) & sub.b.isin(VALID)]          # 동일·비유효 제외
        vc=cand.b.value_counts()
        recs=[]
        for b,c in vc.items():
            if c<min_pair: continue
            conf=c/nX
            recs.append((b,c,conf,conf/base.get(b,np.nan),wilson_lb(conf,nX)))
        recs.sort(key=lambda r:r[4],reverse=True)          # Wilson 하한 정렬
        for rank,(b,c,conf,lift,wlb) in enumerate(recs[:topn],1):
            out.append({'anchor':X,'anchor_name':nm(X),'anchor_n':nX,'rank':rank,
                        'rec_menu':b,'rec_name':nm(b),'rec_cat':tc(b),
                        'pair_n':c,'conf_pct':round(conf*100,1),'lift':round(lift,2),
                        'wilson_lb_pct':round(wlb*100,1)})
    return pd.DataFrame(out)

A=pd.read_csv('master_users.csv')
# 결제직후(s_menu) / 재방문(r_menu) 분리
p0_now=build(A,'s_menu'); p0_now.to_csv('nbo_table_a_appfirst_p0.csv',index=False)
p0_rev=build(A,'r_menu'); p0_rev.to_csv('nbo_table_a_revisit_p0.csv',index=False)

# 웹 인기 12 → C(웹온리)로 (과제3)
WEB=[59089,43117,49816,60706,55723,57670,21964,27376,47704,60013,2141,60244]
C=pd.read_csv('c_users.csv')
web_c=build(C,'s_menu',anchors=WEB,min_anchor=50,min_pair=10,topn=10); web_c.to_csv('web_hero_c_nbo_p0.csv',index=False)

# ---- 정제 전후 비교 (원본 A NBO rank-1 do-not-ship 분류) ----
orig=pd.read_csv('nbo_table_a_appfirst.csv'); r1=orig[orig['rank']==1].copy()
def klass(row):
    m=int(row['rec_menu'])
    if m==int(row['f_menu']): return 'same(자기추천)'
    if m not in seg.index: return 'catalog부재'
    if not seg.loc[m,'_sellable']: return 'unsellable(판매불가)'
    if seg.loc[m,'_blocked']: return 'blocked(비콘텐츠/업셀)'
    return 'ok'
r1['k']=r1.apply(klass,axis=1); n=len(r1)
print(f"\n[정제 전 — 원본 NBO rank-1 {n}개 분류]")
for k,c in r1.k.value_counts().items(): print(f"  {k:<22} {c:>3} ({c/n*100:4.1f}%)")
bad=(r1.k!='ok').sum(); print(f"  → do-not-ship 합계 {bad} ({bad/n*100:.1f}%)")

print(f"\n[정제 후 — P0]")
print(f"  결제직후(s_menu) : 앵커 {p0_now.anchor.nunique()}개 · 추천행 {len(p0_now)}  → nbo_table_a_appfirst_p0.csv")
print(f"  재방문(r_menu)   : 앵커 {p0_rev.anchor.nunique()}개 · 추천행 {len(p0_rev)}  → nbo_table_a_revisit_p0.csv")
print(f"  웹12→C(웹온리)   : 앵커 {web_c.anchor.nunique()}개 · 추천행 {len(web_c)}  → web_hero_c_nbo_p0.csv")

# 예시: 원본 vs P0 rank-1 (자기추천·비콘텐츠가 갈린 앵커)
print("\n[예시] 동일 앵커 rank-1: 정제 전 → 정제 후(결제직후)")
ex=[2141,400,55723,57670,27376]
o1=orig[orig['rank']==1].set_index('f_menu'); n1=p0_now[p0_now['rank']==1].set_index('anchor')
for a in ex:
    ob=o1.loc[a,'rec_menu'] if a in o1.index else None
    nb=n1.loc[a,'rec_menu'] if a in n1.index else None
    tag='  (정제 전 동일/비콘텐츠 → 교체됨)' if ob is not None and nb is not None and int(ob)!=int(nb) else ''
    print(f"  {nm(a)[:22]:<24}: {nm(ob)[:24] if ob is not None else '-':<26} → {nm(nb)[:24] if nb is not None else '(앵커 탈락)'}{tag}")
