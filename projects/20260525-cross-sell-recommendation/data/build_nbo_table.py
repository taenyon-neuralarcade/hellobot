#!/usr/bin/env python3
"""
NBO(Next Best Offer) 테이블 생성 — TODO-028 cross-sell.
입력 : master_users.csv (A 앱퍼스트 첫구매자, 1st→2nd 스킬 menu_seq 포함)
출력 :
  nbo_table_a_appfirst.csv      — 앵커(첫 스킬) → 다음 스킬 top-5 (conf/lift/n)
  nbo_fallback_popularity_a.csv — cold-start(데이터 적은 앵커·신규)용 인기순 fallback
기본값: ever-2nd(당일+재방문 풀링) · 최소표본 n>=30 · top-5 · 동일스킬 유지(플래그)
노브 : SECOND='r_menu'(+r_topic/r_ctype) 로 바꾸면 재방문 2회차만. 입력을 c_users.csv 로 바꾸면 C 웹온리.
"""
import pandas as pd, numpy as np

INPUT  = 'master_users.csv'
MIN_N2 = 30       # 앵커 채택 최소 2번째 구매 표본
TOPK   = 5        # 앵커당 추천 수
SECOND = 's_menu' # ever-2nd. 재방문만: 'r_menu'
S_TOPIC, S_CTYPE = 's_topic', 's_ctype'

df = pd.read_csv(INPUT)
N = len(df)

# 2번째 구매 보유자 (ever-2nd: 당일+재방문)
b2 = df[df.has_2nd == 1].dropna(subset=[SECOND]).copy()
b2[SECOND] = b2[SECOND].astype(int)

fbuyers  = df.f_menu.value_counts()
meta     = df.drop_duplicates('f_menu').set_index('f_menu')[['f_topic','f_ctype']]
tgt_meta = b2.drop_duplicates(SECOND).set_index(SECOND)[[S_TOPIC, S_CTYPE]]
s_all    = b2[SECOND].value_counts(normalize=True)   # lift 분모: 전체 2번째 분포

rows = []
for a, sub in b2.groupby('f_menu'):
    n2 = len(sub)
    if n2 < MIN_N2:
        continue
    for rank, (b, c) in enumerate(sub[SECOND].value_counts().head(TOPK).items(), 1):
        conf = c / n2
        rows.append({
            'f_menu'   : int(a),
            'f_topic'  : meta.loc[a, 'f_topic'],
            'f_ctype'  : meta.loc[a, 'f_ctype'],
            'f_buyers' : int(fbuyers[a]),
            'anchor_n2': n2,
            'rank'     : rank,
            'rec_menu' : int(b),
            'rec_topic': tgt_meta.loc[b, S_TOPIC],
            'rec_ctype': tgt_meta.loc[b, S_CTYPE],
            'conf_pct' : round(conf * 100, 1),
            'lift'     : round(conf / s_all.get(b, np.nan), 2),
            'pair_n'   : int(c),
            'same_menu': int(b == a),
        })

nbo = (pd.DataFrame(rows)
         .fillna({'f_topic':'?','f_ctype':'?','rec_topic':'?','rec_ctype':'?'})
         .sort_values(['f_buyers','rank'], ascending=[False, True]))
nbo.to_csv('nbo_table_a_appfirst.csv', index=False)

# cold-start fallback: 전체 2번째 인기순 top 25
fb = (s_all.head(25) * 100).round(2).rename('share_pct').reset_index()
fb.columns = ['rec_menu','share_pct']
fb['rec_menu'] = fb['rec_menu'].astype(int)
fb = fb.merge(tgt_meta, left_on='rec_menu', right_index=True, how='left')
fb.insert(0, 'rank', range(1, len(fb) + 1))
fb.to_csv('nbo_fallback_popularity_a.csv', index=False)

anchors = nbo.f_menu.nunique()
cov = df[df.f_menu.isin(nbo.f_menu.unique())].shape[0] / N * 100
print(f"입력 N={N:,} / ever-2nd={len(b2):,} ({len(b2)/N*100:.1f}%)")
print(f"채택 앵커(n>={MIN_N2}) = {anchors}개 · 첫구매 {cov:.1f}% 커버 · 추천행 {len(nbo):,}")
print(f"→ nbo_table_a_appfirst.csv      ({len(nbo):,} rows)")
print(f"→ nbo_fallback_popularity_a.csv ({len(fb)} rows)")
print("\n[미리보기] 상위 앵커 추천 12행:")
print(nbo.head(12).to_string(index=False))
