#!/usr/bin/env python3
"""웹 인기 12스킬 → 추천세트 (사용자 합의: 'X 구매자의 관심사를 앱 데이터로 추론').
방식:
  1층 직접(함께 관심): 앱 첫구매자 중 X를 1st 또는 2nd로 산 사람들이 '함께' 산 스킬 (양방향 co-occurrence, Wilson 정렬)
       → 웹 재구매=마케팅 바이어스 회피, 앱 행동으로 관심사 추정
  2층 관심사 백오프: 앱 신호 약한 웹획득형 스킬(60706·60013·60244)은 X의 주제 그룹 선호로 채움 (주제 미태깅은 이름으로 보정)
위생: VALID(판매중·유료·콘텐츠)만, 자기제외. top10.
출력: nbo_web12_named.csv
"""
import pandas as pd, numpy as np, math, re

CAT='../../20260324-coop-integration/planning/kakao_product_skills/data'
seg=pd.read_csv(f'{CAT}/skills-by-segment-12m.csv')[['menu_seq','menu_name','is_open','is_stop_selling','buyers_30d','topic','chatbot_content_type']].rename(columns={'chatbot_content_type':'ctype'})
seg['menu_seq']=pd.to_numeric(seg['menu_seq'],errors='coerce'); seg=seg.dropna(subset=['menu_seq']).drop_duplicates('menu_seq'); seg['menu_seq']=seg['menu_seq'].astype(int); seg=seg.set_index('menu_seq')
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
for c in ['f_menu','s_menu']: A[c]=pd.to_numeric(A[c],errors='coerce')
H=A[(A.has_2nd==1) & A.f_menu.notna() & A.s_menu.notna()].copy()
H['f_menu']=H.f_menu.astype(int); H['s_menu']=H.s_menu.astype(int)
Ntot=len(H)
member=pd.concat([H.f_menu,H.s_menu]).value_counts()      # 각 스킬이 {1st,2nd}에 등장한 유저수(근사)
base=(member/Ntot)                                        # P(partner ∈ {1st,2nd})

# 주제 그룹 선호 (앱 첫구매자: 주제별 2번째 선호) — 백오프용
A['f_menu_i']=A.f_menu;
g=A[['f_topic','s_menu']].copy(); g['s_menu']=pd.to_numeric(g['s_menu'],errors='coerce'); g=g.dropna(); g['s_menu']=g['s_menu'].astype(int)
topic_pref={}
for T,sub in g.groupby('f_topic'):
    denom=len(sub); cand=sub[sub.s_menu.isin(VALID)].s_menu.value_counts()
    topic_pref[str(T)]=(denom,[(b,c/denom) for b,c in cand.items()])

WEB=[59089,43117,49816,60706,55723,57670,21964,27376,47704,60013,2141,60244]
TOPIC_FIX={60706:'결혼',60013:'일반운세',60244:'연애'}   # 미태깅 웹획득형 이름기반 보정
MIN_X=50; TOPN=10

out=[]
for X in WEB:
    maskf=H.f_menu==X; masks=H.s_menu==X; NX=int((maskf|masks).sum())
    chosen=[]; seen=set()
    # 1층 직접(함께 관심)
    if NX>=MIN_X:
        partners=pd.concat([H.loc[maskf,'s_menu'], H.loc[masks,'f_menu']])
        vc=partners.value_counts()
        recs=[]
        for b,c in vc.items():
            if b==X or b not in VALID or c<5: continue
            conf=c/NX; recs.append((b,c,conf,conf/base.get(b,np.nan),wilson_lb(conf,NX)))
        recs.sort(key=lambda r:r[4],reverse=True)
        for b,c,conf,lift,wlb in recs:
            if b in seen: continue
            chosen.append((b,'직접',round(conf*100,1),round(lift,2),c)); seen.add(b)
            if len(chosen)>=TOPN: break
    # 2층 주제 백오프
    if len(chosen)<TOPN:
        T=TOPIC_FIX.get(X, str(seg.loc[X,'topic']) if X in seg.index else 'nan')
        denom,recs=topic_pref.get(T,(0,[]))
        for b,score in recs:
            if b==X or b in seen or b not in VALID: continue
            chosen.append((b,'관심사',round(score*100,1),np.nan,int(round(score*denom)))); seen.add(b)
            if len(chosen)>=TOPN: break
    for rank,(b,src,score,lift,c) in enumerate(chosen,1):
        out.append({'anchor':X,'anchor_name':nm(X),'anchor_topic':(TOPIC_FIX.get(X,str(seg.loc[X,'topic']) if X in seg.index else '?')),
                    'anchor_n_app':NX,'rank':rank,'rec_menu':b,'rec_name':nm(b),'source':src,'score_pct':score,'lift':lift,'co_n':c})
D=pd.DataFrame(out); D.to_csv('nbo_web12_named.csv',index=False)

print(f"앱 has_2nd 유저 {Ntot:,} · VALID {len(VALID):,}")
print(f"웹 12스킬 · 추천 {len(D)}행")
print(f"  출처: 직접 {(D.source=='직접').sum()} · 관심사백오프 {(D.source=='관심사').sum()}")
for X in WEB:
    sub=D[D.anchor==X]
    if not len(sub): print(f"  {nm(X)[:20]}: (없음)"); continue
    src='직접' if (sub.source=='직접').any() else '관심사'
    top3=' / '.join(sub.rec_name.head(3).tolist())
    print(f"  [{src}] {nm(X)[:22]:<24}(앱n={int(sub.anchor_n_app.iat[0])}) → {top3}")
