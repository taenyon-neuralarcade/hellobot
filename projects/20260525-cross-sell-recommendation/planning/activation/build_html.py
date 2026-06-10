#!/usr/bin/env python3
"""활성화 트랙 기획서(.md) → 공유용 HTML 리포트(.html).
자체 완결형(인라인 CSS·오프라인 동작), 앱/웹 색 테마 분리, 목차·콜아웃·인쇄(PDF) 스타일.
실행: python3 build_html.py  (planning/activation/ 에서)
"""
import re, markdown, pathlib

HERE = pathlib.Path(__file__).parent

DOCS = [
    dict(md='01-kakao-push-recommendation.md', html='01-kakao-push-recommendation.html',
         title='카플친 푸시 추천 — 1회차 구매자 재방문 유도',
         sub='전일·당일 1회차 구매자를 다른 날 다시 불러와 2번째 구매로 — 가장 싼 출시·holdout 첫 검증 차량',
         badges=['앱 · 재방문 푸시', 'P1 · CRM A/B (Tier 0)', '🔔 실행 전 (정합·정제 선결)'],
         accent='#0E7490', dark='#155E75', wash='#E2F3FA', nav='① 카플친 푸시'),
    dict(md='02-web-outro-recommendation.md', html='02-web-outro-recommendation.html',
         title='웹 신규 1회차 구매자 → 아웃트로 추천',
         sub='웹 결제/결과 직후 아웃트로 — ⓐ 웹 인세션 추가구매 + ⓑ 앱전용 할인쿠폰 웹투앱',
         badges=['웹 · 아웃트로', 'P3 · 웹/전환', '🌐 쿠폰 마진 가드레일'],
         accent='#C2410C', dark='#9A3412', wash='#FDEEE3', nav='② 웹 아웃트로'),
    dict(md='03-home-personalized-section.md', html='03-home-personalized-section.html',
         title='홈화면 개인화 추천 스킬 섹션',
         sub='앱 홈 상시 개인화 추천 카드 — 구매 이력 기반 NBO, 인세션 슬롯과 서빙 API 공유',
         badges=['앱 · 홈 상시', 'P2 · 인앱', '🏠 다중앵커 블렌드'],
         accent='#4F46E5', dark='#3730A3', wash='#EEF0FE', nav='③ 홈 개인화'),
]

CSS = r"""
*{box-sizing:border-box}
:root{--ink:#1f2430;--muted:#6b7280;--line:#e6e8ec;--bg:#f6f7f9;--card:#fff}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--ink);font-size:15px;line-height:1.72;-webkit-font-smoothing:antialiased;
 font-family:-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo','Pretendard','Malgun Gothic','Noto Sans KR',sans-serif}
a{color:var(--dark);text-decoration:none}
a:hover{text-decoration:underline}
.hero{background:linear-gradient(135deg,var(--accent),var(--dark));color:#fff;padding:40px 24px 32px}
.hero .in{max-width:1180px;margin:0 auto}
.eyebrow{font-size:12.5px;opacity:.85;font-weight:600;letter-spacing:.02em;margin-bottom:12px}
.badges{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:15px}
.badge{background:rgba(255,255,255,.16);border:1px solid rgba(255,255,255,.28);padding:4px 12px;border-radius:999px;font-size:12.5px;font-weight:600}
.hero h1{margin:.1em 0 .3em;font-size:27px;line-height:1.26;font-weight:800;letter-spacing:-.01em}
.hero .sub{font-size:15px;opacity:.93;max-width:780px}
.wrap{max-width:1180px;margin:26px auto 0;padding:0 24px;display:grid;grid-template-columns:222px minmax(0,1fr);gap:36px;align-items:start}
.toc{position:sticky;top:18px;font-size:13px;max-height:calc(100vh - 36px);overflow:auto;background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px}
.toc .t{font-weight:700;font-size:11.5px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em;margin-bottom:9px}
.toc ul{list-style:none;margin:0;padding:0}
.toc li{margin:1px 0}
.toc a{display:block;padding:4px 9px;border-radius:7px;color:#374151;border-left:2px solid transparent}
.toc a:hover{background:var(--wash);border-left-color:var(--accent);text-decoration:none}
.toc ul ul{margin:2px 0 4px 8px;border-left:1px solid var(--line);padding-left:5px}
.toc ul ul a{font-size:12.2px;color:var(--muted)}
.content{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px 42px 42px;box-shadow:0 1px 2px rgba(16,24,40,.04)}
.content h2{font-size:20px;font-weight:800;margin:34px 0 12px;padding-top:20px;border-top:1px solid var(--line);letter-spacing:-.01em;scroll-margin-top:14px}
.content h2:first-of-type{border-top:none;padding-top:8px;margin-top:8px}
.content h3{font-size:16px;font-weight:700;color:var(--dark);margin:24px 0 8px;scroll-margin-top:14px}
.content h4{font-size:14.5px;font-weight:700;margin:16px 0 6px}
.content p{margin:10px 0}
.content ul,.content ol{margin:10px 0;padding-left:22px}
.content li{margin:5px 0}
.content li>ul,.content li>ol{margin:4px 0}
.content hr{border:none;border-top:1px solid var(--line);margin:0;opacity:0;height:6px}
strong{font-weight:700;color:#111827}
code{font-family:'SF Mono',ui-monospace,Menlo,Consolas,monospace;font-size:12.5px;background:var(--wash);color:var(--dark);padding:1.5px 6px;border-radius:5px;word-break:break-word}
pre{background:#0f172a;color:#e2e8f0;border-radius:10px;padding:16px 18px;overflow:auto;font-size:12.5px;line-height:1.6}
pre code{background:none;color:inherit;padding:0}
.tw{overflow-x:auto;margin:14px 0;border:1px solid var(--line);border-radius:10px}
table{border-collapse:collapse;width:100%;font-size:13px}
thead th{background:var(--accent);color:#fff;font-weight:700;text-align:left;padding:9px 12px;white-space:nowrap}
tbody td{padding:8px 12px;border-top:1px solid var(--line);vertical-align:top}
tbody tr:nth-child(even){background:var(--wash)}
table strong{color:var(--dark)}
blockquote.cal{margin:15px 0;padding:12px 16px;border-radius:10px;border:1px solid var(--line);border-left-width:4px;background:#f9fafb;font-size:14px}
blockquote.cal p{margin:6px 0}
blockquote.cal p:first-child{margin-top:0}
blockquote.cal p:last-child{margin-bottom:0}
blockquote.warn{border-left-color:#d97706;background:#fffbeb}
blockquote.ok{border-left-color:#059669;background:#ecfdf5}
blockquote.goal{border-left-color:var(--accent);background:var(--wash)}
blockquote.info{border-left-color:#2563eb;background:#eff6ff}
footer{max-width:1180px;margin:30px auto 70px;padding:0 24px}
.nav{display:flex;gap:10px;flex-wrap:wrap;align-items:center;background:var(--card);border:1px solid var(--line);border-radius:12px;padding:13px 16px;font-size:13.5px}
.nav .lab{color:var(--muted);font-weight:600;margin-right:2px}
.nav a{padding:5px 12px;border-radius:8px;border:1px solid var(--line);color:#374151}
.nav a.cur{background:var(--accent);color:#fff;border-color:var(--accent);font-weight:700}
.foot-meta{color:var(--muted);font-size:12.5px;margin-top:13px;text-align:center}
.print{position:fixed;right:18px;bottom:18px;background:var(--accent);color:#fff;border:none;padding:10px 16px;border-radius:999px;font-weight:700;font-size:13px;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,.18)}
@media (max-width:980px){.wrap{grid-template-columns:1fr;gap:16px}.toc{position:static;max-height:none}.content{padding:14px 18px 28px}.hero h1{font-size:23px}}
@media print{
 body{background:#fff;font-size:11.4px}
 .toc,.print,.nav{display:none}
 .wrap{display:block;margin:0;padding:0}.content{border:none;box-shadow:none;border-radius:0;padding:0}
 .hero{-webkit-print-color-adjust:exact;print-color-adjust:exact;padding:24px}
 thead th,tbody tr:nth-child(even),blockquote.cal,code,pre{-webkit-print-color-adjust:exact;print-color-adjust:exact}
 .content h2{break-after:avoid}.tw,table,blockquote,pre{break-inside:avoid}
}
"""

SHELL = """<!doctype html><html lang="ko"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{{TITLE}} · HelloBot</title>
<style>:root{--accent:{{ACCENT}};--dark:{{DARK}};--wash:{{WASH}}}
{{CSS}}</style></head><body>
<div class="hero"><div class="in">
<div class="eyebrow">HelloBot · Cross-Sell 추천 · 활성화 트랙</div>
<div class="badges">{{BADGES}}</div>
<h1>{{TITLE}}</h1><div class="sub">{{SUB}}</div>
</div></div>
<div class="wrap">
<nav class="toc"><div class="t">목차</div>{{TOC}}</nav>
<main class="content">{{BODY}}</main>
</div>
<footer>
<div class="nav"><span class="lab">활성화 기획</span>{{NAV}}</div>
<div class="foot-meta">생성 2026-06-09 · 원본 SSOT = 동명의 <code>.md</code> · 본 HTML 은 공유·리뷰용 렌더 · 인덱스 <code>planning/activation/readme.md</code></div>
</footer>
<button class="print" onclick="window.print()">🖨 인쇄 / PDF</button>
</body></html>"""


def md_to_html(text):
    md = markdown.Markdown(extensions=['tables', 'fenced_code', 'sane_lists', 'toc'],
                           extension_configs={'toc': {'toc_depth': '2-3'}})
    body = md.convert(text)
    m = re.search(r'<ul.*</ul>', md.toc, re.S)
    toc = m.group(0) if m else '<ul></ul>'
    # 표 가로 스크롤 래핑
    body = body.replace('<table>', '<div class="tw"><table>').replace('</table>', '</table></div>')

    # 인용블록 → 선두 이모지로 콜아웃 분류
    def cls(m):
        head = m.group(1)[:90]
        c = 'warn' if '⚠' in head else 'ok' if '✅' in head else 'goal' if ('🎯' in head or '🚀' in head) else 'info'
        return f'<blockquote class="cal {c}">{m.group(1)}</blockquote>'
    body = re.sub(r'<blockquote>(.*?)</blockquote>', cls, body, flags=re.S)
    return body, toc


def build():
    navset = [(d['html'], d['nav']) for d in DOCS]
    for d in DOCS:
        raw = (HERE / d['md']).read_text(encoding='utf-8')
        # 본문 중복 방지: 첫 H1 제거 (제목은 hero 로)
        lines = raw.split('\n')
        for i, ln in enumerate(lines):
            if ln.startswith('# '):
                del lines[i]
                break
        body, toc = md_to_html('\n'.join(lines))
        badges = ''.join(f'<span class="badge">{b}</span>' for b in d['badges'])
        nav = ''.join(
            f'<a class="cur">{lab}</a>' if href == d['html'] else f'<a href="{href}">{lab}</a>'
            for href, lab in navset)
        page = (SHELL
                .replace('{{CSS}}', CSS).replace('{{ACCENT}}', d['accent']).replace('{{DARK}}', d['dark']).replace('{{WASH}}', d['wash'])
                .replace('{{BADGES}}', badges).replace('{{TITLE}}', d['title']).replace('{{SUB}}', d['sub'])
                .replace('{{TOC}}', toc).replace('{{BODY}}', body).replace('{{NAV}}', nav))
        out = HERE / d['html']
        out.write_text(page, encoding='utf-8')
        print(f"  ✓ {d['html']:<40} {len(page):>7,} bytes · toc {toc.count('<li>')} 항목 · 표 {body.count('<table>')}개")


if __name__ == '__main__':
    print("활성화 기획서 → HTML 리포트")
    build()
    print("done · planning/activation/*.html")
