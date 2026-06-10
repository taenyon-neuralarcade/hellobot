#!/usr/bin/env python3
"""활성화 기획 — '쉬운 버전' HTML (비전문가용). 전문용어를 일상어로 풀고 비유·한눈에·결정 박스 중심.
실행: python3 build_easy_html.py  (planning/activation/ 에서)
"""
import re, markdown, pathlib
HERE = pathlib.Path(__file__).parent

def mdi(t):
    h = markdown.markdown(t, extensions=['sane_lists', 'tables'])
    def cls(m):
        head = m.group(1)[:90]
        c = 'warn' if '⚠' in head else 'ok' if '✅' in head else 'info'
        return f'<blockquote class="cal {c}">{m.group(1)}</blockquote>'
    return re.sub(r'<blockquote>(.*?)</blockquote>', cls, h, flags=re.S)

PUSH = dict(
 slug='01-kakao-push-recommendation-easy.html', detailed='01-kakao-push-recommendation.html', nav='① 카플친 푸시',
 accent='#0E7490', dark='#155E75', wash='#E2F3FA',
 title='카플친 푸시 추천 — 쉽게 보기',
 one='어제·오늘 처음 결제한 분에게, 카카오톡으로 "이런 운세도 보세요" 하고 딱 맞는 운세 하나를 알림으로 보내는 기획이에요.',
 glance=['<b>누구에게</b> — 어제·오늘 앱에서 <b>처음</b> 결제했고 아직 두 번째 결제를 안 한 분',
         '<b>어떻게</b> — 카카오톡 채널(카플친)로 그 사람에게 맞는 운세 1개를 콕 집어 알림',
         '<b>왜 먼저</b> — 앱을 안 고쳐도 되니 <b>가장 싸고 빠르게</b> 효과를 시험할 수 있어요'],
 sections=[
  ('🎯','왜 하나요?',
   "- 헬로우봇은 한 번 산 사람 **열에 아홉이 다시 안 옵니다**.\n"
   "- 그런데 **두 번째 구매만 넘기면**, 그다음부터는 절반 가까이 단골이 돼요.\n"
   "- 그래서 *한 번 사고 떠나려는 사람*을 **며칠 안에 다시 불러오는 것**이 가장 효과가 큰 한 방입니다. 이 푸시가 바로 그 역할이에요."),
  ('👥','누구에게 보내나요?',
   "- 어제(D-1)·오늘(D-0) **첫 결제** + 아직 두 번째 구매 없음\n"
   "- 단, 카카오톡 채널을 **친구 추가**했고 **알림 동의**한 분에게만 갈 수 있어요.\n"
   "> ⚠ 그래서 실제로 보낼 수 있는 사람 수는 이 조건만큼 줄어듭니다. **몇 명에게 보낼 수 있는지 먼저 세어보는 것**이 필요해요."),
  ('💡','어떤 운세를 추천하나요?',
   "- **그 운세를 산 사람들이 그다음에 많이 본 운세**를 보여줍니다.\n"
   "  - 예: ‘다시 만날 수 있을까’를 본 분 → ‘재회 확률 높이는 법’\n"
   "> ⚠ 한 가지 중요한 점: 푸시는 **다른 날 다시 부르는 것**이에요. 그래서 \"그 자리에서 바로 같이 산 것\"이 아니라 **\"며칠 뒤 다시 찾아와서 산 것\"** 목록을 써야 맞습니다. 이 목록은 아직 깔끔하게 안 다듬어져 있어서, **보내기 전에 한 번 정리하는 작업이 먼저** 필요해요."),
  ('🛡️','꼭 지킬 안전장치',
   "- 지금 **안 파는 / 품절** 운세는 추천 금지 *(푸시는 한번 보내면 못 거둬요)*\n"
   "- **이미 산 운세**, 그리고 충전권·질문권 같은 건 추천에서 빼기"),
  ('📏','효과는 이렇게 확인해요',
   "- 대상자를 **반반**으로 나눠 한쪽엔 보내고 한쪽엔 안 보냅니다.\n"
   "- **보낸 쪽이 두 번째 구매를 더 했는지** 비교 → 이게 진짜 효과예요.\n"
   "> ⚠ 헷갈리기 쉬운 점: 추천을 *잘 맞히는 것*과 *매출이 느는 것*은 달라요. 어차피 살 사람한테 맞힌 거면 매출은 안 늘 수도 있어요. 그래서 **반반 비교로만** 진짜 효과를 판단합니다."),
 ],
 analogy="단골 식당이 “저번에 김치찌개 드셨죠? 오늘 된장찌개도 잘 나와요 🙂” 하고 문자 한 통 보내는 것과 같아요. 단 ① 아무 메뉴나 말고 그 손님이 좋아할 만한 걸로, ② 오늘 파는 메뉴만, ③ 문자 받은 손님이 정말 더 오는지 안 받은 손님과 비교해서 확인하는 거죠.",
 decisions=['언제 보낼까요? — <b>권장: 결제 몇 시간 뒤</b> (관심이 식기 전)',
            '카카오 친구가 아닌 분껜 앱 푸시도 같이 보낼까요? — <b>권장: 처음엔 카카오만</b>',
            '추천 목록을 <b>먼저 정리한 뒤</b> 보낼까요? — <b>권장: 예, 정리 먼저</b>'])

WEB = dict(
 slug='02-web-outro-recommendation-easy.html', detailed='02-web-outro-recommendation.html', nav='② 웹 아웃트로',
 accent='#C2410C', dark='#9A3412', wash='#FDEEE3',
 title='웹 아웃트로 추천 — 쉽게 보기',
 one='웹에서 처음 운세를 산 분에게 결과를 본 직후 "이것도 보세요"를 띄우되, ⓐ 웹에서 바로 하나 더 사게 하거나 ⓑ "앱에서 쓰는 할인쿠폰"을 줘서 앱으로 데려오는 기획이에요.',
 glance=['<b>누구에게</b> — <b>웹</b>에서 처음 결제한 새 손님',
         '<b>어디서</b> — 결과 확인/결제가 끝난 직후 화면(아웃트로)',
         '<b>두 갈래</b> — ⓐ 웹에서 바로 추가 구매 · ⓑ <b>앱 전용 할인쿠폰</b>으로 앱 유도'],
 sections=[
  ('🎯','왜 하나요?',
   "- 웹 손님은 광고 보고 들어와 운세 하나 딱 사고 떠나는 경우가 많아요 *(10명 중 7~8명이 한 번뿐)*.\n"
   "- 이런 분들은 웹에서 계속 붙잡기보다 **앱으로 옮겨오면** 다시 찾을 가능성이 훨씬 큽니다.\n"
   "- 그래서 **ⓑ 앱 쿠폰이 핵심 한 수**예요."),
  ('💡','어떤 운세를 추천하나요?',
   "- 웹에서 ‘함께 산 기록’은 광고·끼워팔기 영향을 받아서 진짜 관심을 잘 못 보여줘요.\n"
   "- 그래서 같은 운세를 산 **앱 사용자들이 관심 가진 운세**를 가져와 추천합니다 *(웹 인기 12개는 이미 준비됨)*.\n"
   "- 더 많은 운세로 넓히려면 웹 손님 데이터로 목록을 더 만드는 작업이 필요해요."),
  ('🔀','ⓐ 바로 구매 vs ⓑ 앱 쿠폰',
   "- **ⓐ 웹에서 바로 추가 구매** → <b>즉시 매출</b>\n"
   "- **ⓑ 앱 쿠폰으로 유도** → <b>앱으로 이사 + 단골화</b> *(길게 보면 더 큼)*\n"
   "- 권장: 먼저 ⓐ를 권하고, 안 사면 ⓑ 쿠폰을 주는 식 — 또는 둘 다 시험해 보기"),
  ('🛡️','꼭 지킬 안전장치',
   "- 안 파는 / 품절 운세 추천 금지, 충전권 같은 건 빼기\n"
   "> ⚠ 쿠폰은 공짜가 아니에요 → **할인해 준 만큼 빼고도 이득인지** 꼭 따져야 합니다. 손해면 멈춰요."),
  ('📏','효과는 이렇게 확인해요',
   "- 쿠폰 준 그룹 vs 안 준 그룹을 비교해서, **할인 비용을 빼고도** 더 벌었는지 확인합니다.\n"
   "- 추천을 잘 맞히는 것과 진짜 더 버는 것은 다르니, **비교 실험으로만** 판단해요."),
 ],
 analogy="웹은 “길거리 1회성 손님”이 많은 가게예요. 계산대에서 ⓐ “이것도 하나 더 어떠세요?” 하고 권하거나, ⓑ “우리 단골앱 깔면 이 쿠폰 드릴게요” 하며 단골로 만드는 것과 같아요.",
 decisions=['쿠폰 할인 얼마나? — <b>손익분기 기준</b>을 먼저 정하기',
            'ⓐ와 ⓑ 중 뭘 먼저? — <b>권장: ⓐ 먼저, 안 사면 ⓑ</b>',
            '앱 안 깐 사람은 어떻게? — 설치를 권할지, 그냥 웹에서 사게 둘지'])

HOME = dict(
 slug='03-home-personalized-section-easy.html', detailed='03-home-personalized-section.html', nav='③ 홈 개인화',
 accent='#4F46E5', dark='#3730A3', wash='#EEF0FE',
 title='홈 개인화 추천 섹션 — 쉽게 보기',
 one='앱 홈 화면에 그 사람이 산 운세에 맞춰 "다음에 볼 만한 운세"를 늘 보여주는 추천 칸을 만드는 기획이에요.',
 glance=['<b>어디에</b> — 앱 <b>홈 화면</b>에 항상 떠 있는 추천 카드 칸',
         '<b>무엇을</b> — 그 사람이 전에 산 운세를 기준으로 “다음에 많이 보는 운세” 추천',
         '<b>특징</b> — 푸시처럼 한 번이 아니라 <b>늘</b> 보이는 자리'],
 sections=[
  ('🎯','왜 하나요?',
   "- 앱을 다시 열었을 때 **“다음에 뭘 볼지”** 자연스럽게 보여주는 자리가 지금은 없어요.\n"
   "- 홈에 추천 칸이 있으면, 다시 들어온 사람을 **두 번째 구매로** 부드럽게 이어줄 수 있습니다."),
  ('💡','어떤 운세를 추천하나요?',
   "- **그 운세를 산 사람들이 다음에 많이 본 운세**를 보여줍니다 *(앱 추천 목록은 이미 준비 — 처음 산 분 10명 중 8명 이상 커버)*.\n"
   "- 기준이 되는 운세는 그 사람의 구매 이력에서 골라요 *(마지막에 산 것 / 여러 개를 섞어서 — 권장은 섞기)*."),
  ('🛡️','꼭 지킬 안전장치 (홈은 특히 중요)',
   "> ⚠ **이미 산 운세는 빼기** — 홈은 매번 보이니까 더 중요해요.\n"
   "- 안 파는 운세 금지, **같은 것만 반복**해서 보여주지 않게 가끔 새로운 것도 섞기"),
  ('📏','효과는 이렇게 확인해요',
   "- 추천 칸을 **본 사람 vs 안 본 사람**(기존 홈)을 비교해서, 두 번째 구매가 늘었는지 확인합니다."),
  ('🔗','다른 과제와의 관계',
   "- 앱 개인화(다른 과제)와 겹치지 않게, 이 칸은 **‘함께 본 운세 추천’만** 담당해요.\n"
   "- 나이·성별로 더 맞추는 건 효과가 작아서 **하지 않습니다**."),
 ],
 analogy="쇼핑앱 홈의 “회원님을 위한 추천” 칸과 같아요. 단 ① 이미 산 건 빼고, ② 늘 같은 것만 말고 가끔 새로운 것도 섞어 보여주는 거죠.",
 decisions=['어떤 운세를 기준으로 추천할까? — 마지막 구매 / 여러 개 섞기 *(<b>권장: 섞기</b>)*',
            '홈 <b>어디에, 몇 개나</b> 보여줄까?',
            '“그 자리에서” 목록을 쓸까, <b>홈 맞춤(다시 찾는) 목록을 따로</b> 만들까?'])

DOCS = [PUSH, WEB, HOME]

CSS = r"""
*{box-sizing:border-box}
:root{--ink:#222934;--muted:#6b7280;--line:#e8eaee;--bg:#f5f6f8;--card:#fff}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--ink);font-size:16.5px;line-height:1.85;-webkit-font-smoothing:antialiased;
 font-family:-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo','Pretendard','Malgun Gothic','Noto Sans KR',sans-serif}
a{color:var(--dark);font-weight:600;text-decoration:none}a:hover{text-decoration:underline}
.hero{background:linear-gradient(135deg,var(--accent),var(--dark));color:#fff;padding:40px 22px 34px}
.in{max-width:760px;margin:0 auto}
.eyebrow{font-size:13px;opacity:.9;font-weight:600;margin-bottom:11px}
.pill{display:inline-block;background:rgba(255,255,255,.18);border:1px solid rgba(255,255,255,.3);padding:4px 13px;border-radius:999px;font-size:13px;font-weight:700;margin-bottom:13px}
.hero h1{margin:.1em 0 .35em;font-size:28px;line-height:1.3;font-weight:800;letter-spacing:-.01em}
.hero .one{font-size:17px;opacity:.96;line-height:1.7}
.hero .more{display:inline-block;margin-top:16px;background:#fff;color:var(--dark);padding:8px 16px;border-radius:999px;font-size:13.5px;font-weight:700}
.hero .more:hover{text-decoration:none;opacity:.92}
.wrap{max-width:760px;margin:0 auto;padding:22px}
.glance{background:var(--wash);border:1.5px solid var(--accent);border-radius:16px;padding:20px 22px;margin:6px 0 22px}
.glance .gt{font-weight:800;font-size:16px;color:var(--dark);margin-bottom:10px}
.glance ul{list-style:none;margin:0;padding:0}
.glance li{position:relative;padding:6px 0 6px 30px;font-size:16px;border-top:1px dashed rgba(0,0,0,.08)}
.glance li:first-child{border-top:none}
.glance li::before{content:"✓";position:absolute;left:2px;top:6px;color:var(--accent);font-weight:900}
.card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:20px 24px 22px;margin:14px 0;box-shadow:0 1px 2px rgba(16,24,40,.04)}
.card h2{font-size:20px;font-weight:800;margin:0 0 8px;color:var(--ink);letter-spacing:-.01em}
.card h2 .ic{margin-right:8px}
.card p{margin:9px 0}
.card ul,.card ol{margin:9px 0;padding-left:24px}
.card li{margin:6px 0}
.card li>ul{margin:4px 0}
.card ul ul{padding-left:20px;color:var(--muted)}
strong,b{font-weight:800;color:#111827}
em{color:var(--muted);font-style:normal}
blockquote.cal{margin:12px 0;padding:12px 16px;border-radius:12px;border:1px solid var(--line);border-left-width:5px;background:#f9fafb;font-size:15.5px}
blockquote.cal p{margin:5px 0}blockquote.cal p:first-child{margin-top:0}blockquote.cal p:last-child{margin-bottom:0}
blockquote.warn{border-left-color:#e08600;background:#fff8ec}
blockquote.ok{border-left-color:#059669;background:#ecfdf5}
blockquote.info{border-left-color:#2563eb;background:#eff6ff}
.analogy{background:#fffaf0;border:1.5px dashed #eab308;border-radius:16px;padding:18px 22px;margin:16px 0;font-size:16.5px;line-height:1.8}
.analogy .at{font-weight:800;color:#a16207;margin-bottom:6px}
.decide{background:var(--wash);border:1.5px solid var(--accent);border-radius:16px;padding:18px 22px;margin:16px 0}
.decide .dt{font-weight:800;font-size:17px;color:var(--dark);margin-bottom:10px}
.decide ul{list-style:none;margin:0;padding:0}
.decide li{position:relative;padding:7px 0 7px 30px;border-top:1px solid rgba(0,0,0,.06)}
.decide li:first-child{border-top:none}
.decide li::before{content:"☑";position:absolute;left:2px;top:6px;color:var(--accent);font-weight:900}
footer{max-width:760px;margin:8px auto 70px;padding:0 22px}
.nav{display:flex;gap:9px;flex-wrap:wrap;align-items:center;background:var(--card);border:1px solid var(--line);border-radius:14px;padding:13px 16px;font-size:14px}
.nav .lab{color:var(--muted);font-weight:700;margin-right:2px}
.nav a{padding:6px 13px;border-radius:9px;border:1px solid var(--line);color:#374151}
.nav a.cur{background:var(--accent);color:#fff;border-color:var(--accent);font-weight:800}
.foot-meta{color:var(--muted);font-size:13px;margin-top:13px;text-align:center;line-height:1.7}
.print{position:fixed;right:18px;bottom:18px;background:var(--accent);color:#fff;border:none;padding:11px 17px;border-radius:999px;font-weight:800;font-size:13.5px;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,.18)}
@media (max-width:640px){.hero h1{font-size:23px}.card{padding:16px 17px}}
@media print{body{background:#fff}.print,.nav{display:none}.hero{-webkit-print-color-adjust:exact;print-color-adjust:exact}
 .glance,.analogy,.decide,blockquote.cal,.card{-webkit-print-color-adjust:exact;print-color-adjust:exact;break-inside:avoid}}
"""

SHELL = """<!doctype html><html lang="ko"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{{TITLE}} · HelloBot</title>
<style>:root{--accent:{{ACCENT}};--dark:{{DARK}};--wash:{{WASH}}}
{{CSS}}</style></head><body>
<div class="hero"><div class="in">
<div class="eyebrow">HelloBot · Cross-Sell 추천 · 활성화 트랙</div>
<div class="pill">🟢 쉬운 버전 · 비전문가용</div>
<h1>{{TITLE}}</h1>
<div class="one">{{ONE}}</div>
<a class="more" href="{{DETAILED}}">🔍 자세한 기획서 보기 →</a>
</div></div>
<div class="wrap">
<div class="glance"><div class="gt">📌 한눈에</div><ul>{{GLANCE}}</ul></div>
{{CARDS}}
<div class="analogy"><div class="at">💡 쉽게 말하면</div>{{ANALOGY}}</div>
<div class="decide"><div class="dt">✅ 결정해 주세요</div><ul>{{DECIDE}}</ul></div>
</div>
<footer>
<div class="nav"><span class="lab">쉬운 버전</span>{{NAV}}<a href="{{DETAILED}}">🔍 자세한 버전</a></div>
<div class="foot-meta">생성 2026-06-09 · 더 자세한 근거·데이터는 ‘자세한 기획서’에 · 인덱스 <code>planning/activation/readme.md</code></div>
</footer>
<button class="print" onclick="window.print()">🖨 인쇄 / PDF</button>
</body></html>"""


def build():
    navset = [(d['slug'], d['nav']) for d in DOCS]
    for d in DOCS:
        glance = ''.join(f'<li>{g}</li>' for g in d['glance'])
        cards = ''.join(
            f'<section class="card"><h2><span class="ic">{ic}</span>{tt}</h2>{mdi(md)}</section>'
            for ic, tt, md in d['sections'])
        decide = ''.join(f'<li>{mdi(x)[3:-4] if mdi(x).startswith("<p>") else x}</li>' for x in d['decisions'])
        nav = ''.join(f'<a class="cur">{lab}</a>' if s == d['slug'] else f'<a href="{s}">{lab}</a>' for s, lab in navset)
        page = (SHELL.replace('{{CSS}}', CSS)
                .replace('{{ACCENT}}', d['accent']).replace('{{DARK}}', d['dark']).replace('{{WASH}}', d['wash'])
                .replace('{{TITLE}}', d['title']).replace('{{ONE}}', d['one']).replace('{{DETAILED}}', d['detailed'])
                .replace('{{GLANCE}}', glance).replace('{{CARDS}}', cards)
                .replace('{{ANALOGY}}', d['analogy']).replace('{{DECIDE}}', decide).replace('{{NAV}}', nav))
        (HERE / d['slug']).write_text(page, encoding='utf-8')
        print(f"  ✓ {d['slug']:<46} {len(page):>7,} bytes · 카드 {len(d['sections'])} · 결정 {len(d['decisions'])}")


if __name__ == '__main__':
    print("활성화 기획 → 쉬운 버전 HTML")
    build()
    print("done")
