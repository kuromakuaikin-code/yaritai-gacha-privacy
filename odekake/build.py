#!/usr/bin/env python3
"""東海おでかけナビ - 個別スポットページ生成スクリプト

使い方:
    cd odekake
    python3 build.py

spots.json を読み、スポットごとに s/<id>.html を生成し、sitemap.xml を更新する。
spots.json を編集したら必ず実行すること。標準ライブラリのみ使用（追加インストール不要）。

盆踊りナビ(bon-odori/build.py)と同じ作法だが、扱う対象が違う:
  盆踊り = 毎年日付が変わる単発イベント
  紅葉・イルミ = 会場が固定で、変わるのは日程と料金だけ
そのため spots.json は「例年の見頃(seasonFrom/To)」と「実日付(dateFrom/To)」の
2系統を持つ。前者は年をまたいでも書き換え不要。
"""
import json
import html
import os
from datetime import date

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "s")

with open(os.path.join(HERE, "site-config.json"), encoding="utf-8") as f:
    CFG = json.load(f)
SITE_NAME = CFG["siteName"]
BASE_URL = CFG.get("publicBaseUrl", "").strip().rstrip("/")
if BASE_URL:
    BASE_URL += "/"
TOKEN = CFG.get("analyticsToken", "").strip()
ANALYTICS = (
    '<!-- Cloudflare Web Analytics -->\n'
    f'<script type="module" src="https://static.cloudflareinsights.com/beacon.min.js" '
    f'data-cf-beacon=\'{{"token":"{TOKEN}"}}\'></script>\n'
    '<!-- End Cloudflare Web Analytics -->'
) if TOKEN else ""

GENRE = {
    "sakura": ("桜", "🌸", "桜の名所"),
    "ajisai": ("あじさい", "💠", "あじさいの名所"),
    "koyo":   ("紅葉", "🍁", "紅葉スポット"),
    "illumi": ("イルミネーション", "✨", "イルミネーション会場"),
}
# 期間の見出し。花は「見頃」、イルミは点灯期間なので「期間」。
PERIOD_LABEL = {"sakura": "見頃", "ajisai": "見頃", "koyo": "見頃", "illumi": "期間"}
MONTHS = {
    "01": "1月", "02": "2月", "03": "3月", "04": "4月", "05": "5月", "06": "6月",
    "07": "7月", "08": "8月", "09": "9月", "10": "10月", "11": "11月", "12": "12月",
}


def e(s):
    return html.escape(str(s if s is not None else ""))


def safe_url(u):
    """spots.json の値をそのまま href に入れない。https 以外は落とす。"""
    u = str(u or "").strip()
    return u if u.startswith("https://") else ""


def jdate(iso):
    """2026-10-17 → 2026年10月17日"""
    y, m, d = iso.split("-")
    return f"{y}年{int(m)}月{int(d)}日"


def period_label(sp):
    if sp.get("dateFrom") and sp.get("dateTo"):
        return f"{jdate(sp['dateFrom'])}〜{jdate(sp['dateTo'])}"
    if sp.get("seasonNote"):
        return sp["seasonNote"]
    if sp.get("seasonFrom") and sp.get("seasonTo"):
        a, b = sp["seasonFrom"], sp["seasonTo"]
        return f"例年{MONTHS[a[:2]]}{int(a[3:])}日ごろ〜{MONTHS[b[:2]]}{int(b[3:])}日ごろ"
    return "時期未定"


def schema_json(sp):
    """紅葉スポットは TouristAttraction、日程の決まったイルミは Event。"""
    g, _, _ = GENRE.get(sp["genre"], GENRE["koyo"])
    place = {
        "@type": "Place",
        "name": sp.get("venue") or sp["name"],
        "address": {
            "@type": "PostalAddress",
            "addressRegion": sp.get("prefecture", ""),
            "addressLocality": sp.get("city", ""),
            "streetAddress": sp.get("address", ""),
            "addressCountry": "JP",
        },
    }
    if sp.get("lat") and sp.get("lng"):
        place["geo"] = {"@type": "GeoCoordinates",
                        "latitude": sp["lat"], "longitude": sp["lng"]}

    if sp.get("dateFrom") and sp.get("dateTo"):
        data = {
            "@context": "https://schema.org",
            "@type": "Event",
            "name": sp["name"],
            "startDate": sp["dateFrom"],
            "endDate": sp["dateTo"],
            "eventStatus": "https://schema.org/EventScheduled",
            "eventAttendanceMode": "https://schema.org/OfflineEventAttendanceMode",
            "location": place,
            "description": sp.get("desc", ""),
        }
    else:
        data = {
            "@context": "https://schema.org",
            "@type": "TouristAttraction",
            "name": sp["name"],
            "description": sp.get("desc", ""),
            "address": place["address"],
            "touristType": f"{g}を見に行く人",
        }
        if "geo" in place:
            data["geo"] = place["geo"]
    return json.dumps(data, ensure_ascii=False, indent=2)


def page_html(sp):
    g_label, g_emoji, g_noun = GENRE.get(sp["genre"], GENRE["koyo"])
    pref = sp.get("prefecture", "")
    city = sp.get("city", "")
    period = period_label(sp)

    # スポット名にジャンル名が入っている場合（例:「なばなの里 イルミネーション」）は
    # 「〜のイルミネーション」と重複するので付けない。
    heading = sp["name"] if g_label in sp["name"] else f"{sp['name']}の{g_label}"
    title = f"{heading}（{pref}{city}・{period}）｜{SITE_NAME}"
    desc = (
        f"{pref}{city}の{g_noun}「{sp['name']}」。"
        f"見頃は{period}。ライトアップの有無・料金・場所・情報元・最終確認日を掲載しています。"
    )

    rows = [(PERIOD_LABEL.get(sp["genre"], "期間"), period),
            ("場所", f"{pref}{city}　{sp.get('venue','')}")]
    if sp.get("address"):
        rows.append(("住所", sp["address"]))
    if sp.get("fee"):
        rows.append(("料金", sp["fee"]))
    if sp.get("lightup"):
        rows.append(("ライトアップ", sp.get("lightupNote") or "あり"))
    rows_html = "".join(
        f"<tr><th>{e(k)}</th><td>{e(v)}</td></tr>" for k, v in rows
    )

    maps_q = html.escape(
        (sp["name"] + " " + (sp.get("address") or sp.get("venue") or "")).replace(" ", "+"),
        quote=True)
    maps_url = "https://www.google.com/maps/search/" + maps_q

    warn = ""
    if sp.get("verifyStatus") == "要確認":
        warn = ('<div class="warn">⚠️ ライトアップやイベントの日程は年ごとに変わります。'
                'おでかけ前に情報元・公式サイトで最新の日程をご確認ください。</div>')

    src_url = safe_url(sp.get("source"))
    src = (f'<a href="{e(src_url)}" target="_blank" rel="noopener">'
           f'{e(sp.get("sourceName") or "情報元")}</a>') if src_url else e(sp.get("sourceName") or "—")

    return f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="theme-color" content="#7b3f2e">
<title>{e(title)}</title>
<meta name="description" content="{e(desc)}">
<link rel="canonical" href="{e(BASE_URL + 's/' + sp['id'] + '.html') if BASE_URL else './' + e(sp['id']) + '.html'}">
<meta property="og:title" content="{e(title)}">
<meta property="og:description" content="{e(desc)}">
<meta property="og:type" content="article">
<script type="application/ld+json">
{schema_json(sp)}
</script>
{ANALYTICS}
<style>
:root{{--bg:#faf7f2;--ink:#33291f;--sub:#7d7264;--line:#e7ddd0;--accent:#c0392b;--head:#7b3f2e;--blue:#2c5282;--green:#2e7d4f;--green-soft:#e6f2ea}}
*{{margin:0;padding:0;box-sizing:border-box}}
body{{font-family:"Hiragino Kaku Gothic ProN","Hiragino Sans","Noto Sans JP",Meiryo,sans-serif;background:var(--bg);color:var(--ink);line-height:1.8;font-size:15px}}
a{{color:var(--blue)}}
.wrap{{max-width:680px;margin:0 auto;padding:0 14px 50px}}
header{{background:var(--head);color:#fff;padding:10px 0}}
header .wrap{{padding-bottom:0}}
header a{{color:#fff;text-decoration:none;font-weight:800;font-size:.95rem}}
h1{{font-size:1.32rem;margin:18px 0 4px;line-height:1.5}}
.kana{{font-size:.78rem;color:var(--sub);margin-bottom:10px}}
.badges{{display:flex;flex-wrap:wrap;gap:6px;margin:8px 0 14px}}
.b{{font-size:.76rem;font-weight:800;padding:4px 10px;border-radius:999px}}
.b.g{{background:var(--accent);color:#fff}}
.b.p{{background:var(--green-soft);color:var(--green)}}
.b.l{{background:#fff6da;color:#9a6b00;border:1px solid #f0dfae}}
table{{width:100%;border-collapse:collapse;background:#fff;border:1px solid var(--line);border-radius:12px;overflow:hidden;margin:12px 0}}
th,td{{padding:11px 13px;text-align:left;font-size:.9rem;border-bottom:1px solid var(--line);vertical-align:top}}
th{{background:#fbf8f4;color:var(--sub);font-size:.8rem;white-space:nowrap;width:7.5em}}
tr:last-child th,tr:last-child td{{border-bottom:none}}
p.desc{{font-size:.93rem;margin:14px 0}}
.warn{{background:#fdecef;color:#a32b44;border-radius:10px;padding:12px 14px;font-size:.85rem;font-weight:700;margin:14px 0}}
.btn{{display:block;text-align:center;background:var(--green);color:#fff;border-radius:12px;padding:14px;margin:14px 0 4px;text-decoration:none;font-weight:800}}
.src{{font-size:.8rem;color:var(--sub);margin-top:18px;padding-top:12px;border-top:1px dashed var(--line)}}
footer{{margin-top:28px;padding-top:14px;border-top:1px solid var(--line);font-size:.8rem;color:var(--sub)}}
footer a{{color:var(--sub)}}
</style>
</head>
<body>
<header><div class="wrap"><a href="../">← {g_emoji} {e(SITE_NAME)}</a></div></header>
<div class="wrap">

<h1>{e(heading)}</h1>
{f'<div class="kana">{e(sp["kana"])}</div>' if sp.get("kana") else ""}

<div class="badges">
  <span class="b g">{e(g_label)}</span>
  <span class="b p">{e(pref)}{e(city)}</span>
  {'<span class="b l">💡 ライトアップ</span>' if sp.get("lightup") else ""}
</div>

<table>{rows_html}</table>

{f'<p class="desc">{e(sp["desc"])}</p>' if sp.get("desc") else ""}
{warn}

<a class="btn" href="{maps_url}" target="_blank" rel="noopener">地図で場所を見る</a>

<p class="src">情報元：{src}　／　最終確認：{e(sp.get('lastVerified','—'))}</p>

<footer>
  <p>見頃は例年の目安です。実際の色づきはその年の気候で前後します。</p>
  <p style="margin-top:8px">
    <a href="../">{e(SITE_NAME)}のトップへ</a> ／
    <a href="../../bon-odori/">盆踊り・地域祭りナビ東海</a>
  </p>
</footer>

</div>
</body>
</html>
"""


def main():
    with open(os.path.join(HERE, "spots.json"), encoding="utf-8") as f:
        spots = json.load(f)["spots"]

    os.makedirs(OUT_DIR, exist_ok=True)

    seen = set()
    urls = []
    for sp in spots:
        sid = sp["id"]
        if sid in seen:
            raise SystemExit(f"エラー: id が重複しています: {sid}")
        seen.add(sid)
        if sp["genre"] not in GENRE:
            raise SystemExit(f"エラー: 未知の genre です: {sp['genre']}（{sid}）")

        path = os.path.join(OUT_DIR, f"{sid}.html")
        with open(path, "w", encoding="utf-8") as f:
            f.write(page_html(sp))
        if BASE_URL:
            urls.append(f"{BASE_URL}s/{sid}.html")

    print(f"生成: s/*.html（{len(spots)} ページ）")

    # 古いページの掃除（spots.json から消したスポットのページを残さない）
    for name in os.listdir(OUT_DIR):
        if name.endswith(".html") and name[:-5] not in seen:
            os.remove(os.path.join(OUT_DIR, name))
            print(f"削除: s/{name}（spots.json にありません）")

    # sitemap.xml は独自の公開URLを設定した場合だけ生成する。
    sitemap_path = os.path.join(HERE, "sitemap.xml")
    if BASE_URL:
        urls.insert(0, BASE_URL)
        xml = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        xml += "".join(f"  <url><loc>{html.escape(u)}</loc></url>\n" for u in urls)
        xml += "</urlset>\n"
        with open(sitemap_path, "w", encoding="utf-8") as f:
            f.write(xml)
        print(f"生成: sitemap.xml（{len(urls)} URL）")
    elif os.path.exists(sitemap_path):
        os.remove(sitemap_path)
        print("削除: sitemap.xml（site-config.json の publicBaseUrl 設定後に再生成します）")

    # 要確認のものを一覧で出す（シーズン前の確認作業のため）
    todo = [sp for sp in spots if sp.get("verifyStatus") == "要確認"]
    if todo:
        print(f"\n要確認 {len(todo)} 件（シーズン前に公式サイトで日程を確認すること）:")
        for sp in todo:
            print(f"  - {sp['name']}（{sp['prefecture']}{sp['city']}） {sp.get('source','')}")


if __name__ == "__main__":
    main()
