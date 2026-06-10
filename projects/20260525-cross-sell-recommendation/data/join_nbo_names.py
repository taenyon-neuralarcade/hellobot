#!/usr/bin/env python3
"""
NBO 테이블에 스킬명 조인 — TODO-028 cross-sell (a 단계).
이름 소스: coop-integration 스킬 카탈로그(로컬) — BQ 불필요.
출력: nbo_table_a_appfirst_named.csv · nbo_fallback_popularity_a_named.csv
"""
import pandas as pd

CAT = '../../20260324-coop-integration/planning/kakao_product_skills/data'

# 이름 룩업: skills-by-segment(전량) + sku-by-age(보완) 결합, menu_seq 유일화
def load_lookup():
    a = pd.read_csv(f'{CAT}/skills-by-segment-12m.csv')[['menu_seq','menu_name','price_amount']]
    b = pd.read_csv(f'{CAT}/sku-by-age-12m.csv')[['menu_seq','menu_name','price_amount']]
    lk = pd.concat([a, b]).dropna(subset=['menu_seq']).drop_duplicates('menu_seq')
    lk['menu_seq'] = lk['menu_seq'].astype(int)
    return lk.set_index('menu_seq')

lk = load_lookup()
name = lk['menu_name'].to_dict()
price = lk['price_amount'].to_dict()

def nm(s):   return name.get(int(s), f'(미상:{int(s)})')
def pr(s):   return price.get(int(s), None)

# 1) 본체
t = pd.read_csv('nbo_table_a_appfirst.csv')
t['f_name']    = t.f_menu.map(nm)
t['rec_name']  = t.rec_menu.map(nm)
t['rec_price'] = t.rec_menu.map(pr)
t = t[['f_menu','f_name','f_topic','f_ctype','f_buyers','anchor_n2',
       'rank','rec_menu','rec_name','rec_topic','rec_ctype','rec_price',
       'conf_pct','lift','pair_n','same_menu']]
t.to_csv('nbo_table_a_appfirst_named.csv', index=False)

# 2) fallback
f = pd.read_csv('nbo_fallback_popularity_a.csv')
f['rec_name'] = f.rec_menu.map(nm)
f = f[['rank','rec_menu','rec_name','s_topic','s_ctype','share_pct']]
f.to_csv('nbo_fallback_popularity_a_named.csv', index=False)

# 커버리지
miss = t[t.rec_name.str.startswith('(미상')].rec_menu.nunique()
tot  = pd.concat([t.f_menu, t.rec_menu]).nunique()
print(f"이름 룩업 {len(lk):,}개 · NBO 등장 스킬 {tot}개 중 미매칭 {miss}개")
print(f"→ nbo_table_a_appfirst_named.csv ({len(t):,} rows)")
print(f"→ nbo_fallback_popularity_a_named.csv ({len(f)} rows)")
print("\n[미리보기] 상위 앵커 추천 (이름):")
prev = t.head(10)[['f_name','f_buyers','rank','rec_name','rec_topic','rec_ctype','conf_pct','lift','pair_n']]
print(prev.to_string(index=False))
print("\n[fallback 인기순 top8]:")
print(f.head(8).to_string(index=False))
