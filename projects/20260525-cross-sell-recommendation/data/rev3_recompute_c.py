#!/usr/bin/env python3
# REVISION 3 recompute — 모든 표를 새 master_users.csv(30컬럼, r_* 재방문 SKU 포함)로 재산출.
# 지표 프레임: rev90 primary / sameday 별도 / NBO=ever-2nd 풀링 topic-lift / 형식·rate=재방문(r_*).
import csv, math
from collections import Counter, defaultdict

CSV="/Users/taenyon/Development/neuralarcade/hellobot/projects/20260525-cross-sell-recommendation/data/c_users.csv"
rows=list(csv.reader(open(CSV))); H=rows[0]; D=rows[1:]
I={c:i for i,c in enumerate(H)}
N=len(D)
def g(r,c): return r[I[c]]
def gi(r,c,d=0):
    try: return int(r[I[c]])
    except: return d
def present(v): return v not in ('','NULL',None)

def wilson(k,n,z=1.96):
    if n==0: return (float('nan'),float('nan'))
    p=k/n; den=1+z*z/n
    c=(p+z*z/(2*n))/den
    h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den
    return (100*(c-h),100*(c+h))
def pct(k,n): return 100*k/n if n else float('nan')

# helpers
def ctype_b(v):
    if v in ('타로','사주','점성학'): return v
    if v in ('진단','손금','기타'): return '기타형식'
    return '(미태깅)'
def topic_b(v): return v if present(v) else '(미태깅)'
def age_clean(r):
    a=gi(r,'age',-999999)
    return a if 14<=a<=90 else None
def age_bucket(r):
    a=age_clean(r)
    if a is None: return None
    return '<25' if a<25 else '25-34' if a<35 else '35-44' if a<45 else '45+'
def gf(r,c,d=0.0):
    try: return float(r[I[c]])
    except: return d
def tier(r):
    p=gf(r,'f_rev',0.0)
    return 'T1≤4k' if p<=4000 else 'T2 4-8k' if p<=8000 else 'T3 8-12k' if p<=12000 else 'T4>12k'

print("="*70); print("N =",N); print("="*70)

print("\n##### A. 헤드라인 rate + Wilson 95% CI #####")
for col,lab in [('c_rev90','rev90(재방문 90일내)'),('c_sameday','sameday(당일)'),
                ('c_any90','any90'),('c_rev30','rev30'),('c_rev60','rev60')]:
    k=sum(1 for r in D if gi(r,col)>0); lo,hi=wilson(k,N)
    print(f"  {lab:<22} {k:>6}  {pct(k,N):5.2f}%  CI[{lo:.2f},{hi:.2f}]")
ever=sum(1 for r in D if gi(r,'total_pays')>1); lo,hi=wilson(ever,N)
print(f"  {'ever(total_pays>1)':<22} {ever:>6}  {pct(ever,N):5.2f}%  CI[{lo:.2f},{hi:.2f}]")

print("\n##### B. 연도 코호트 (rev90 + 성숙도) #####")
by_y=defaultdict(list)
for r in D: by_y[g(r,'f_year')].append(r)
for y in sorted(by_y):
    grp=by_y[y]; n=len(grp)
    rv=sum(1 for r in grp if gi(r,'c_rev90')>0); a9=sum(1 for r in grp if gi(r,'c_any90')>0)
    flag='  ← 경계(부분성숙 가능)' if y=='2026' else ''
    print(f"  {y}: n={n:>6}  any90={pct(a9,n):5.1f}%  rev90={pct(rv,n):5.1f}%{flag}")

print("\n##### C. content_type 표 (N에 foot) #####")
cc=defaultdict(list)
for r in D: cc[ctype_b(g(r,'f_ctype'))].append(r)
tot=0
for ct in ['타로','사주','점성학','기타형식','(미태깅)']:
    grp=cc.get(ct,[]); n=len(grp); tot+=n
    if not n: continue
    rv=pct(sum(1 for r in grp if gi(r,'c_rev90')>0),n)
    sd=pct(sum(1 for r in grp if gi(r,'c_sameday')>0),n)
    a9=pct(sum(1 for r in grp if gi(r,'c_any90')>0),n)
    print(f"  {ct:<8} n={n:>6}  any90={a9:5.1f}  rev90={rv:5.1f}  sameday={sd:5.1f}")
print(f"  합계 n={tot} (=N? {tot==N})")

print("\n##### D. topic 표 (N에 foot) #####")
tt=defaultdict(list)
for r in D: tt[topic_b(g(r,'f_topic'))].append(r)
tot=0
for t,grp in sorted(tt.items(), key=lambda kv:-len(kv[1])):
    n=len(grp); tot+=n
    rv=pct(sum(1 for r in grp if gi(r,'c_rev90')>0),n)
    sd=pct(sum(1 for r in grp if gi(r,'c_sameday')>0),n)
    print(f"  {t:<10} n={n:>6}  rev90={rv:5.1f}  sameday={sd:5.1f}")
print(f"  합계 n={tot} (=N? {tot==N})")

print("\n##### E. ★ 당일 vs 재방문 분해 — 타로 vs 사주 (지적#2) #####")
print(f"  {'metric':<28}{'타로':>9}{'사주':>9}{'gap(타-사)':>11}")
taro=[r for r in D if g(r,'f_ctype')=='타로']; saju=[r for r in D if g(r,'f_ctype')=='사주']
def rt(grp,pred): return pct(sum(1 for r in grp if pred(r)),len(grp))
for lab,pred in [
    ('sameday(당일)', lambda r:gi(r,'c_sameday')>0),
    ('any90', lambda r:gi(r,'c_any90')>0),
    ('rev90(재방문)', lambda r:gi(r,'c_rev90')>0),
    ('revisit-only(재방문&당일0)', lambda r:gi(r,'c_rev90')>0 and gi(r,'c_sameday')==0),
]:
    a=rt(taro,pred); b=rt(saju,pred); print(f"  {lab:<28}{a:>8.1f}{b:>9.1f}{a-b:>+10.1f}")

print("\n##### F. 가격tier × content (rev90) — Simpson 점검 #####")
print(f"  {'tier':<10}{'타로 rev90(n)':>18}{'사주 rev90(n)':>18}")
for t in ['T1≤4k','T2 4-8k','T3 8-12k','T4>12k']:
    tg=[r for r in taro if tier(r)==t]; sg=[r for r in saju if tier(r)==t]
    print(f"  {t:<10}{rt(tg,lambda r:gi(r,'c_rev90')>0):>10.1f} (n={len(tg):>5}){rt(sg,lambda r:gi(r,'c_rev90')>0):>10.1f} (n={len(sg):>5})")
print(f"  [집계] 타로 rev90={rt(taro,lambda r:gi(r,'c_rev90')>0):.1f}(n={len(taro)})  사주 rev90={rt(saju,lambda r:gi(r,'c_rev90')>0):.1f}(n={len(saju)})")
# 사주 가격분포
from collections import Counter as C
print("  사주 tier분포:", dict(C(tier(r) for r in saju)))

print("\n##### G. ★ NBO topic 매트릭스 (ever-2nd 풀링, lift over topic prior) #####")
ev=[r for r in D if gi(r,'has_2nd')==1]
print(f"  ever-2nd n={len(ev)}")
prior=Counter(topic_b(g(r,'s_topic')) for r in ev); P=len(ev)
print(f"  topic prior: " + ", ".join(f"{k} {100*v/P:.1f}%" for k,v in prior.most_common(5)))
print(f"  {'1차topic':<10}{'n':>7}  최고lift 2nd(연애제외 후보 포함):")
for t in ['연애','결혼','총운','일반운세','학업직업','재물금전','가족자녀','자기탐구']:
    grp=[r for r in ev if g(r,'f_topic')==t]; n=len(grp)
    if n<200:
        print(f"  {t:<10}{n:>7}  (n<200 suppress)"); continue
    sc=Counter(topic_b(g(r,'s_topic')) for r in grp)
    cand=[]
    for y,c in sc.items():
        conf=100*c/n; base=100*prior[y]/P; lift=conf/base if base else 0
        cand.append((lift,y,conf,c,base))
    cand.sort(reverse=True)
    # 동일topic(self) + 최고lift non-self
    self_lift=next((x for x in cand if x[1]==t),None)
    top=cand[0]
    txt=f"self({t})→conf{self_lift[2]:.0f}%/lift{self_lift[0]:.2f}" if self_lift else ""
    # top non-self by lift with n>=30
    nonself=[x for x in cand if x[1]!=t and x[3]>=30]
    ns=nonself[0] if nonself else None
    nstxt=f" | 최고lift타: {ns[1]}→conf{ns[2]:.0f}%/lift{ns[0]:.2f}(n{ns[3]})" if ns else ""
    print(f"  {t:<10}{n:>7}  {txt}{nstxt}")

print("\n##### H. ★ 형식(content) 전이 — 당일(s_ctype) vs 진짜재방문(r_ctype) #####")
def ctrans(grp, col, name):
    print(f"  [{name}] n={len(grp)}")
    by1=defaultdict(Counter)
    for r in grp:
        f1=g(r,'f_ctype')
        if f1 not in('타로','사주'): continue
        by1[f1][ctype_b(g(r,col))]+=1
    # base
    base=Counter(ctype_b(g(r,col)) for r in grp if g(r,'f_ctype') in('타로','사주'))
    bt=base['타로']/sum(base.values()); bs=base['사주']/sum(base.values())
    print(f"    base 2nd: 타로 {100*bt:.1f}% / 사주 {100*bs:.1f}%")
    for f1 in('타로','사주'):
        tot=sum(by1[f1].values())
        if not tot: continue
        ct=by1[f1]['타로']/tot; cs=by1[f1]['사주']/tot
        print(f"    {f1}→타로 {100*ct:5.1f}%(lift{ct/bt:.2f})  {f1}→사주 {100*cs:5.1f}%(lift{cs/bs:.2f})  n={tot}")
ctrans([r for r in ev if gi(r,'second_sameday')==1],'s_ctype','당일 2번째 s_ctype')
ctrans([r for r in D if present(g(r,'r_ctype'))],'r_ctype','진짜 재방문 r_ctype (90일내 첫 다른날)')

print("\n##### I. 연령 × 연애 rev90 (age 클린 14-90) + CI #####")
for ab in ['<25','25-34','35-44','45+']:
    grp=[r for r in D if age_bucket(r)==ab and g(r,'f_topic')=='연애']
    n=len(grp); k=sum(1 for r in grp if gi(r,'c_rev90')>0); lo,hi=wilson(k,n)
    print(f"  {ab:<6} n={n:>6} rev90={pct(k,n):5.1f}% CI[{lo:.1f},{hi:.1f}]")

print("\n##### J. (age×ctype) NBO 매트릭스 — 재방문(r_*) 기준, lift over topic-prior + CI, n<300 suppress #####")
# prior over revisit r_topic
rev=[r for r in D if present(g(r,'r_topic'))]
rprior=Counter(g(r,'r_topic') for r in rev); RP=len(rev)
print(f"  재방문 모집단 n={RP}; r_topic prior 연애={100*rprior['연애']/RP:.1f}%")
for ab in ['<25','25-34','35-44','45+']:
    for ct in ['타로','사주']:
        grp=[r for r in rev if age_bucket(r)==ab and g(r,'f_ctype')==ct]
        n=len(grp)
        if n<300:
            print(f"  {ab:<6}×{ct} n={n:>5} → suppress(n<300)"); continue
        # top 2nd topic by conf, and its lift over r_topic prior
        sc=Counter(g(r,'r_topic') for r in grp)
        y,c=sc.most_common(1)[0]; conf=100*c/n; base=100*rprior[y]/RP; lift=conf/base
        lo,hi=wilson(c,n)
        # 최고 lift non-연애
        cand=sorted(((100*cc/n)/(100*rprior[t]/RP), t, 100*cc/n, cc) for t,cc in sc.items() if t!='연애' and cc>=15)
        ns=cand[-1] if cand else None
        nstxt=f" | 최고lift비연애: {ns[1]} lift{ns[0]:.2f}(conf{ns[2]:.0f}%,n{ns[3]})" if ns else ""
        print(f"  {ab:<6}×{ct} n={n:>5} top:{y} conf{conf:.1f}%[{lo:.0f},{hi:.0f}] lift{lift:.2f}{nstxt}")
