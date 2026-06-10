#!/usr/bin/env python3
"""
NBO v2 — 결제직후 인세션 슬롯용 A→B 추천 세트 (사용자 합의 2026-06-09).
설계:
  결과신호 = s_menu(2번째 결제, 당일/인세션 포함)  ← 인세션이 곧 타깃 표면
  2층 구조:
    1층 직접   : A 첫구매자가 실제 2번째로 산 B (Wilson 정렬, anchor≥50·pair≥10)
    2층 관심사 : 직접이 부족하면 A의 관심사그룹(주제|의도)에서 2번째 선호 스킬을 전환율 순으로 채움
  위생: VALID(판매중·유료·콘텐츠)만 추천, 자기자신 제외. (보유스킬 제외는 서빙시점)
출력: nbo_v2_combined.csv  (anchor,anchor_name,anchor_topic,anchor_n,rank,rec_menu,rec_name,source,score_pct,pair_n)
"""
import pandas as pd, numpy as np, math, re

CAT='../../20260324-coop-integration/planning/kakao_product_skills/data'
seg=pd.read_csv(f'{CAT}/skills-by-segment-12m.csv')[['menu_seq','menu_name','is_open','is_stop_selling','buyers_30d','topic','chatbot_content_type']].rename(columns={'chatbot_content_type':'ctype'})
seg['menu_seq']=pd.to_numeric(seg['menu_seq'],errors='coerce')
seg=seg.dropna(subset=['menu_seq']).drop_duplicates('menu_seq'); seg['menu_seq']=seg['menu_seq'].astype(int); seg=seg.set_index('menu_seq')
def truthy(s): return s.astype(str).str.strip().str.lower().isin(['true','1','1.0','y','yes'])
seg['_sellable']=truthy(seg['is_open']) & ~truthy(seg['is_stop_selling']) & (pd.to_numeric(seg['buyers_30d'],errors='coerce').fillna(0)>0)
BLOCK=re.compile(r'추천할인|추가구매|충전|질문권|하트|패키지|프리패스|이용권|구독|업셀|연속구매|코칭')
seg['_blocked']=seg['menu_name'].fillna('').str.contains(BLOCK) | seg['topic'].astype(str).eq('기타') | seg['ctype'].isna()
VALID=set(seg.index[seg['_sellable'] & ~seg['_blocked']])
def nm(s):
    try: s=int(s)
    except: return '?'
    return seg.loc[s,'menu_name'] if s in seg.index else f'(미상:{s})'
def wilson_lb(p,n,z=1.96):
    if n==0: return 0.0
    d=1+z*z/n; c=p+z*z/(2*n); m=z*math.sqrt((p*(1-p)+z*z/(4*n))/n); return max(0.0,(c-m)/d)

A=pd.read_csv('master_users.csv')
A['f_menu']=pd.to_numeric(A['f_menu'],errors='coerce'); A=A.dropna(subset=['f_menu']); A['f_menu']=A['f_menu'].astype(int)
A['grp']=A['f_topic'].fillna('?').astype(str)+'|'+A['f_intents'].fillna('').astype(str).replace('','*')
TOPN=5; MIN_ANCHOR=50; MIN_PAIR=10
print(f"카탈로그 {len(seg):,} · VALID(판매중·유료·콘텐츠) {len(VALID):,} · 첫구매자 {len(A):,}")

anch=A.groupby('f_menu').agg(n=('f_menu','size'), grp=('grp',lambda x: x.mode().iat[0] if len(x.mode()) else x.iat[0])).reset_index()

# 1층: 직접 A->s_menu
p=A[['f_menu','s_menu']].copy(); p['s_menu']=pd.to_numeric(p['s_menu'],errors='coerce'); p=p.dropna(); p['s_menu']=p['s_menu'].astype(int); p.columns=['a','b']
direct={}
for X,sub in p.groupby('a'):
    nX=len(sub)
    if nX<MIN_ANCHOR: continue
    cand=sub[(sub.b!=X)&sub.b.isin(VALID)].b.value_counts()
    recs=[(b,c,c/nX,wilson_lb(c/nX,nX)) for b,c in cand.items() if c>=MIN_PAIR]
    recs.sort(key=lambda r:r[3],reverse=True); direct[X]=recs

# 2층: 관심사 그룹 선호 (그룹내 2번째구매 전환율)
g2=A[['grp','s_menu']].copy(); g2['s_menu']=pd.to_numeric(g2['s_menu'],errors='coerce'); g2=g2.dropna(); g2['s_menu']=g2['s_menu'].astype(int)
group_pref={}
for G,sub in g2.groupby('grp'):
    denom=len(sub); cand=sub[sub.s_menu.isin(VALID)].s_menu.value_counts()
    group_pref[G]=(denom,[(b,c,c/denom) for b,c in cand.items()])

# 결합
out=[]
for _,row in anch.iterrows():
    X=int(row.f_menu); G=row.grp; nX=int(row.n); chosen=[]; seen=set()
    for b,c,conf,wlb in direct.get(X,[]):
        if b==X or b in seen: continue
        chosen.append((b,'직접',round(conf*100,1),c)); seen.add(b)
        if len(chosen)>=TOPN: break
    if len(chosen)<TOPN:
        denom,recs=group_pref.get(G,(0,[]))
        for b,c,score in recs:
            if b==X or b in seen or b not in VALID: continue
            chosen.append((b,'관심사',round(score*100,1),c)); seen.add(b)
            if len(chosen)>=TOPN: break
    for rank,(b,src,score,c) in enumerate(chosen,1):
        out.append({'anchor':X,'anchor_name':nm(X),'anchor_topic':G,'anchor_n':nX,'rank':rank,
                    'rec_menu':b,'rec_name':nm(b),'source':src,'score_pct':score,'pair_n':c})
D=pd.DataFrame(out); D.to_csv('nbo_v2_combined.csv',index=False)

# 요약
cov_anchor=D.anchor.nunique(); tot_anchor=anch.f_menu.nunique()
cov_buyers=anch[anch.f_menu.isin(D.anchor)].n.sum(); tot_buyers=anch.n.sum()
r1=D[D['rank']==1]
print(f"\n[결과] 추천행 {len(D):,} · 커버 앵커 {cov_anchor:,}/{tot_anchor:,} (첫구매 {100*cov_buyers/tot_buyers:.1f}% 커버)")
print(f"  슬롯 출처: 직접 {100*(D.source=='직접').mean():.0f}% · 관심사 {100*(D.source=='관심사').mean():.0f}%")
print(f"  1순위 출처: 직접 {(r1.source=='직접').sum()}개 · 관심사 {(r1.source=='관심사').sum()}개")
print(f"  직접 데이터 보유 앵커: {len(direct):,} (anchor≥{MIN_ANCHOR}·pair≥{MIN_PAIR})")

def show(X):
    sub=D[D.anchor==X]
    if not len(sub): print(f"  (앵커 {X} 없음)"); return
    print(f"\n  ▶ {nm(X)[:26]} (n={int(sub.anchor_n.iat[0])}, {sub.anchor_topic.iat[0]})")
    for _,r in sub.iterrows():
        print(f"     {r['rank']}. [{r.source}] {r.rec_name[:30]:<32} {r.score_pct:>4.1f}%")
print("\n=== 예시 ===")
print("[직접 데이터 풍부한 앵커]"); show(2141); show(55723)
big=anch[anch.f_menu.isin(direct.keys())].sort_values('n',ascending=False).f_menu.head(1).iat[0]; show(int(big))
print("\n[직접 부족 → 관심사 백오프로 채운 앵커]")
small=[X for X in anch.f_menu if X not in direct][:1]
gonly=D[(D.anchor.isin(small))]
if len(gonly): show(int(gonly.anchor.iat[0]))
