#!/usr/bin/env python3
"""
웹 인기 스킬 12개의 '관심사 affinity' — 앱(A 앱퍼스트) 데이터 기준.
affinity = 순서 무관 co-purchase: 앱 1·2번째 구매 페어에서 X와 함께 등장한 다른 스킬.
(웹 재구매는 마케팅 바이어스 큼 → 관심사 신호는 앱 데이터로. C 분석도 동일 결론)
출력: web_hero_app_affinity_top10.csv
"""
import pandas as pd, numpy as np

CAT='../../20260324-coop-integration/planning/kakao_product_skills/data'
cat=pd.concat([
  pd.read_csv(f'{CAT}/skills-by-segment-12m.csv')[['menu_seq','menu_name','topic','chatbot_content_type']].rename(columns={'chatbot_content_type':'ctype'}),
  pd.read_csv(f'{CAT}/sku-by-age-12m.csv')[['menu_seq','menu_name','topic','content_type']].rename(columns={'content_type':'ctype'}),
])
cat['menu_seq']=pd.to_numeric(cat['menu_seq'],errors='coerce')
cat=cat.dropna(subset=['menu_seq']).drop_duplicates('menu_seq')
cat['menu_seq']=cat['menu_seq'].astype(int)
cat=cat.set_index('menu_seq')
def nm(s):  s=int(s); return cat.loc[s,'menu_name'] if s in cat.index else f'(미상:{s})'
def tc(s):  s=int(s); return f"{cat.loc[s,'topic']}/{cat.loc[s,'ctype']}" if s in cat.index else '?'

ids=[59089,43117,49816,60706,55723,57670,21964,27376,47704,60013,2141,60244]

df=pd.read_csv('master_users.csv')                       # A 앱퍼스트
pairs=df[df.has_2nd==1][['f_menu','s_menu']].dropna().astype(int)
endp=pd.concat([pairs.f_menu,pairs.s_menu]); base=endp.value_counts()/len(endp)

rows=[]
for X in ids:
    co=pd.concat([pairs[pairs.f_menu==X].s_menu, pairs[pairs.s_menu==X].f_menu])
    nX=len(co); vc=co.value_counts(); vc=vc[vc.index!=X].head(10)
    for rank,(b,c) in enumerate(vc.items(),1):
        rows.append({'anchor':X,'anchor_name':nm(X),'anchor_nX':nX,'rank':rank,
                     'rec_menu':int(b),'rec_name':nm(b),'rec_cat':tc(b),
                     'co_n':int(c),'conf_pct':round(c/nX*100,1),
                     'lift':round((c/nX)/base.get(b,np.nan),2)})
out=pd.DataFrame(rows)
out.to_csv('web_hero_app_affinity_top10.csv',index=False)

print(f"A 앱퍼스트 1·2번째 페어 {len(pairs):,}개 기준\n")
for X in ids:
    sub=out[out.anchor==X]; nX=sub.anchor_nX.iloc[0] if len(sub) else 0
    flag='   ⚠표본 얇음(참고용)' if nX<50 else ''
    print(f"■ {X} {nm(X)}  (app nX={nX}){flag}")
    for _,r in sub.iterrows():
        print(f"   {r['rank']:>2}. {r['rec_name'][:30]:<32} {r['rec_cat']:<10} conf{r['conf_pct']:>5.1f}% lift{r['lift']:>6.1f} (n={r['co_n']})")
    print()
