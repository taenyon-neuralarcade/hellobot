#!/usr/bin/env python3
"""
과제2 단기 검증 — '신호 정의' 교정의 근거 정량화.
질문: 결제직후(s_menu)와 재방문(r_menu)은 실제로 다른 신호인가? 당일 오염은 얼마나 큰가?

컬럼 의미(검증됨):
  s_menu = 2번째 결제(시간순, 당일 포함). second_sameday=1 이면 당일.
  r_menu = '다른 날' 첫 재방문 결제(days_to_rev>0). 순수 재방문.
  => s_menu vs r_menu 차이 = 당일 오염. second_sameday=0 이면 s_menu==r_menu 여야 정상.
출력: task2_signal_divergence.csv (앵커별 s/r top5 겹침) + 콘솔 리포트
"""
import pandas as pd, numpy as np, math, re

CAT='../../20260324-coop-integration/planning/kakao_product_skills/data'
seg=pd.read_csv(f'{CAT}/skills-by-segment-12m.csv')[['menu_seq','menu_name','topic','chatbot_content_type','is_open','is_stop_selling','buyers_30d']].rename(columns={'chatbot_content_type':'ctype'})
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
def tp(s):
    try: s=int(s)
    except: return '?'
    return seg.loc[s,'topic'] if s in seg.index else '?'

A=pd.read_csv('master_users.csv')
N=len(A); h2=A[A.has_2nd==1].copy()
print(f"=== 모집단: A 앱퍼스트 첫구매자 {N:,}명 ===")
print(f"2번째 결제 도달(has_2nd=1): {len(h2):,} ({len(h2)/N*100:.1f}%)")

# ---- 1. 당일 오염 정량화 (s_menu 신호의 몇 %가 당일인가) ----
print("\n--- [1] 당일 오염: s_menu(2번째 결제) 신호의 same-day 비중 ---")
sd=h2.second_sameday.mean()
print(f"  2번째 결제 중 당일(second_sameday=1): {h2.second_sameday.sum():,} / {len(h2):,} = {sd*100:.1f}%")
print(f"  days_to_2nd 분포: 0일 {(h2.days_to_2nd==0).mean()*100:.1f}% · 1~7일 {h2.days_to_2nd.between(1,7).mean()*100:.1f}% · 8일+ {(h2.days_to_2nd>7).mean()*100:.1f}%")
# r_menu(재방문) 존재율
hasrev=h2.r_menu.notna()
print(f"  재방문(r_menu, 다른날 결제) 존재: {hasrev.sum():,} / {len(h2):,} = {hasrev.mean()*100:.1f}%  ← s_menu 있어도 다른날 재방문 없는 경우 존재")

# ---- 2. s_menu == r_menu 정합 (당일이면 갈라짐) ----
print("\n--- [2] s_menu vs r_menu 동일성 (신호가 같은가 다른가) ---")
both=h2[h2.r_menu.notna()].copy()
both['s']=pd.to_numeric(both.s_menu,errors='coerce'); both['r']=pd.to_numeric(both.r_menu,errors='coerce')
both=both.dropna(subset=['s','r'])
agree=(both.s.astype(int)==both.r.astype(int))
print(f"  r_menu 존재 유저 {len(both):,}명 중 s_menu==r_menu: {agree.sum():,} ({agree.mean()*100:.1f}%)")
print(f"    └ 당일(second_sameday=1)에서 일치: {agree[both.second_sameday==1].mean()*100:.1f}%  (당일이면 s≠r 이어야 정상)")
print(f"    └ 비당일(second_sameday=0)에서 일치: {agree[both.second_sameday==0].mean()*100:.1f}%  (비당일이면 s==r 이어야 정상)")

# ---- 3. 당일 vs 재방문 2번째 결제의 토픽/타입 프로파일 (당일=업셀/번들 편향?) ----
print("\n--- [3] 당일 vs 재방문 2번째 결제의 성격 차이 (업셀/번들 vs 진짜관심) ---")
h2['s_int']=pd.to_numeric(h2.s_menu,errors='coerce')
sameday=h2[h2.second_sameday==1].s_int.dropna().astype(int)
diffday=h2[(h2.second_sameday==0)].s_int.dropna().astype(int)
def profile(series,label):
    vc=series.map(lambda x: '판매불가/업셀' if x not in VALID else '정상콘텐츠').value_counts(normalize=True)
    same=(series.values==h2.set_index(h2.index).loc[series.index,'f_menu'].values)
    print(f"  {label} (n={len(series):,}): 정상콘텐츠 {vc.get('정상콘텐츠',0)*100:.1f}% · 판매불가/업셀 {vc.get('판매불가/업셀',0)*100:.1f}%")
profile(sameday,'당일 2번째')
profile(diffday,'비당일 2번째')
# 자기재구매(같은 스킬) 비중
fmap=h2.set_index(h2.index)
sd_self=(h2[h2.second_sameday==1].s_int.values==h2[h2.second_sameday==1].f_menu.values)
dd_self=(h2[h2.second_sameday==0].s_int.values==h2[h2.second_sameday==0].f_menu.values)
print(f"  자기재구매(s==f): 당일 {np.nanmean(sd_self)*100:.1f}% vs 비당일 {np.nanmean(dd_self)*100:.1f}%")

# ---- 4. 앵커별 s top5 vs r top5 겹침 (단일엔진 폐기 근거) ----
print("\n--- [4] 앵커별 결제직후(s) top5 vs 재방문(r) top5 겹침 ---")
def topk(df, col, k=5, min_anchor=50, min_pair=10):
    p=df[['f_menu',col]].dropna().astype(int); p.columns=['a','b']
    res={}
    for X,sub in p.groupby('a'):
        if len(sub)<min_anchor: continue
        cand=sub[(sub.b!=X)&sub.b.isin(VALID)].b.value_counts()
        cand=cand[cand>=min_pair]
        if len(cand): res[X]=list(cand.head(k).index)
    return res
sT=topk(A,'s_menu'); rT=topk(A,'r_menu')
common=sorted(set(sT)&set(rT))
rows=[]
for X in common:
    ss,rr=set(sT[X]),set(rT[X])
    inter=len(ss&rr); jac=inter/len(ss|rr)
    top1_same=(sT[X][0]==rT[X][0])
    rows.append({'anchor':X,'anchor_name':nm(X),'s_top5':'|'.join(nm(x) for x in sT[X]),
                 'r_top5':'|'.join(nm(x) for x in rT[X]),'overlap_n':inter,'jaccard':round(jac,2),'top1_same':top1_same})
D=pd.DataFrame(rows).sort_values('jaccard')
D.to_csv('task2_signal_divergence.csv',index=False)
print(f"  두 표면 모두 산출된 앵커: {len(common)}개")
print(f"  top5 평균 겹침: {D.overlap_n.mean():.2f}/5 ({D.overlap_n.mean()/5*100:.0f}%) · 평균 Jaccard {D.jaccard.mean():.2f}")
print(f"  top1 동일 앵커: {D.top1_same.sum()}/{len(D)} ({D.top1_same.mean()*100:.0f}%)  ← 1순위가 표면 따라 바뀌는 비율 {100-D.top1_same.mean()*100:.0f}%")
print(f"  겹침 0~1개(거의 다른 추천): {(D.overlap_n<=1).sum()}개 ({(D.overlap_n<=1).mean()*100:.0f}%)")
print("\n  [예시] 표면별로 1순위가 갈리는 앵커 5개:")
for _,r in D[~D.top1_same].head(5).iterrows():
    print(f"   · {r.anchor_name[:18]:<20} 결제직후→{r.s_top5.split('|')[0][:16]:<18} | 재방문→{r.r_top5.split('|')[0][:16]}")
print("\n→ task2_signal_divergence.csv 저장")
