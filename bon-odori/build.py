#!/usr/bin/env python3
"""盆踊りナビ愛知 - 個別イベントページ生成スクリプト

使い方:
    cd bon-odori
    python3 build.py

events.json を読み、status が published のイベントごとに e/<id>.html を生成し、
sitemap.xml を更新する。events.json を編集したら必ず実行すること。
標準ライブラリのみ使用（追加インストール不要）。
"""
import json
import html
import os
import sys
from datetime import date

BASE_URL = "https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/bon-odori/"
SITE_NAME = "盆踊りナビ愛知"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "e")

WEEKDAYS = ["月", "火", "水", "木", "金", "土", "日"]

POSTER_TYPES = {
    "admin": ("admin", "運営確認済み", "運営者が情報元を確認したうえで掲載しています。"),
    "organizer": ("organizer", "主催者投稿", "主催者からの投稿情報です。"),
    "resident": ("resident", "住民投稿・未確認", "地域住民からの投稿で、公式情報は未確認です。開催の有無は現地の掲示等でご確認ください。"),
}

STATUS_INFO = {
    "cancelled": ("EventCancelled", "❌ このイベントは中止になりました"),
    "postponed": ("EventPostponed", "⏸ このイベントは延期になりました"),
    "scheduled": ("EventScheduled", ""),
}


def e(s):
    return html.escape(str(s or ""))


def jdate(iso):
    y, m, d = (int(x) for x in iso.split("-"))
    wd = WEEKDAYS[date(y, m, d).weekday()]
    return f"{y}年{m}月{d}日({wd})"


def jdate_short(iso):
    y, m, d = (int(x) for x in iso.split("-"))
    return f"{y}年{m}月{d}日"


def page_html(ev):
    pt_key = ev.get("posterType", "resident")
    pt_cls, pt_label, pt_desc = POSTER_TYPES.get(pt_key, POSTER_TYPES["resident"])
    ev_status = ev.get("eventStatus", "scheduled")
    schema_status, status_banner = STATUS_INFO.get(ev_status, STATUS_INFO["scheduled"])

    dates = ev.get("dates", [])
    first = dates[0] if dates else {}
    date_label = jdate_short(first["date"]) if first.get("date") else "日程未定"
    if len(dates) > 1:
        date_label += f"〜{jdate_short(dates[-1]['date']).split('年')[1]}" if dates[-1]["date"][:4] == first["date"][:4] else "ほか"

    title = f"{ev['name']}（{ev['city']}・{date_label}開催）｜{SITE_NAME}"
    desc_meta = (
        f"{ev['city']}の{ev.get('venue','')}で{date_label}に開催される盆踊り「{ev['name']}」。"
        f"日時・場所・雨天時の扱い・情報元・最終確認日を掲載。"
    )

    date_rows = "".join(
        f"<li><b>{e(jdate(x['date']))}</b>"
        + (f" {e(x['start'])}" + (f"〜{e(x['end'])}" if x.get("end") else "") if x.get("start") else "")
        + "</li>"
        for x in dates
    )

    maps_q = f"{ev['city']} {ev.get('address') or ev.get('venue','')}"
    maps_url = "https://www.google.com/maps/search/" + maps_q.replace(" ", "+")

    source = ev.get("source") or {}
    source_name = source.get("name", "")
    source_url = source.get("url", "")
    source_html = (
        f'<a href="{e(source_url)}" target="_blank" rel="noopener">{e(source_name or "公式情報")}</a>'
        if source_url else e(source_name or "—")
    )

    img_html = ""
    if ev.get("imageAllowed") and ev.get("image"):
        img_html = f'<img src="../{e(ev["image"])}" alt="{e(ev["name"])}のチラシ" style="max-width:100%;border-radius:10px;margin:12px 0">'

    sample_banner = (
        '<div class="banner sample-b">⚠️ これは表示確認用の仮データです。実際のイベントではありません。</div>'
        if ev.get("sample") else ""
    )
    status_html = f'<div class="banner status-b">{status_banner}' + (
        f"<br><small>{e(ev.get('statusNote'))}</small>" if ev.get("statusNote") else "") + "</div>" if status_banner else ""

    # schema.org Event 構造化データ（Google検索対策）
    offers_free = {"@type": "Offer", "price": "0", "priceCurrency": "JPY", "availability": "https://schema.org/InStock", "url": BASE_URL + f"e/{ev['id']}.html"}
    ld = {
        "@context": "https://schema.org",
        "@type": "Event",
        "name": ev["name"],
        "eventStatus": f"https://schema.org/{schema_status}",
        "eventAttendanceMode": "https://schema.org/OfflineEventAttendanceMode",
        "location": {
            "@type": "Place",
            "name": ev.get("venue", ""),
            "address": {"@type": "PostalAddress", "addressRegion": "愛知県", "addressLocality": ev["city"], "streetAddress": ev.get("address", "")},
        },
        "offers": offers_free,
        "description": desc_meta,
        "organizer": {"@type": "Organization", "name": source_name or "主催者"},
    }
    if first.get("date"):
        ld["startDate"] = first["date"] + (f"T{first['start']}:00+09:00" if first.get("start") else "")
        last = dates[-1]
        ld["endDate"] = last["date"] + (f"T{last['end']}:00+09:00" if last.get("end") else "")
    if ev.get("lat") is not None:
        ld["location"]["geo"] = {"@type": "GeoCoordinates", "latitude": ev["lat"], "longitude": ev["lng"]}

    rain = f'<dt>雨天時</dt><dd>☔ {e(ev["rain"])}</dd>' if ev.get("rain") else ""
    desc_block = f'<div class="desc">{e(ev["desc"])}</div>' if ev.get("desc") else ""

    addr = ev.get("address", "")
    if addr.startswith(ev["city"]):
        addr = addr[len(ev["city"]):].lstrip()
    place_disp = f"{e(ev.get('venue',''))}（{e(ev['city'])}" + (f" {e(addr)}" if addr and addr != ev.get("venue") else "") + "）"

    return f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{e(title)}</title>
<meta name="description" content="{e(desc_meta)}">
<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🏮</text></svg>">
<link rel="canonical" href="{BASE_URL}e/{e(ev['id'])}.html">
<script type="application/ld+json">
{json.dumps(ld, ensure_ascii=False, indent=1)}
</script>
<style>
:root{{--bg:#faf7f2;--ink:#33291f;--sub:#7d7264;--line:#e7ddd0;--accent:#c0392b;
--green:#2e7d4f;--green-soft:#e6f2ea;--blue:#2c5282;--blue-soft:#e8eef7;--orange:#b45309;--orange-soft:#fdf0dd;--gray-soft:#efece7}}
*{{margin:0;padding:0;box-sizing:border-box}}
body{{font-family:"Hiragino Kaku Gothic ProN","Hiragino Sans","Noto Sans JP",Meiryo,sans-serif;background:var(--bg);color:var(--ink);line-height:1.75;font-size:15px}}
a{{color:var(--blue)}}
.wrap{{max-width:640px;margin:0 auto;padding:0 14px 40px}}
header{{background:#2c3e6b;color:#fff;padding:10px 0}}
header .wrap{{padding-bottom:0}}
header a{{color:#fff;text-decoration:none;font-weight:800;font-size:.95rem}}
h1{{font-size:1.3rem;line-height:1.5;margin:16px 0 4px}}
.city{{color:var(--sub);font-size:.9rem;margin-bottom:10px}}
.banner{{border-radius:10px;padding:10px 14px;font-size:.85rem;font-weight:700;margin:10px 0}}
.status-b{{background:#3c3c3c;color:#fff}}
.sample-b{{background:var(--orange-soft);color:var(--orange)}}
.ptype{{display:inline-block;font-size:.78rem;font-weight:800;border-radius:7px;padding:2px 10px;margin-right:6px}}
.ptype.admin{{background:var(--green-soft);color:var(--green)}}
.ptype.organizer{{background:var(--blue-soft);color:var(--blue)}}
.ptype.resident{{background:var(--orange-soft);color:var(--orange)}}
.box{{background:#fff;border:1px solid var(--line);border-radius:12px;padding:14px 16px;margin:12px 0}}
.box h2{{font-size:.85rem;color:var(--sub);margin-bottom:6px}}
dl dt{{font-size:.78rem;color:var(--sub);font-weight:700;margin-top:8px}}
dl dd{{font-size:.95rem}}
ul.dates{{list-style:none}}
ul.dates li{{font-size:1.05rem;padding:2px 0}}
.desc{{background:#fff;border:1px solid var(--line);border-radius:12px;padding:14px 16px;margin:12px 0;font-size:.93rem}}
.trustbox{{background:#fff;border:2px solid var(--green-soft);border-radius:12px;padding:14px 16px;margin:12px 0;font-size:.88rem}}
.trustbox .row{{display:flex;gap:8px;padding:3px 0}}
.trustbox .k{{flex:0 0 92px;color:var(--sub);font-size:.8rem;font-weight:700;padding-top:2px}}
.btn{{display:block;text-align:center;background:#fff;border:1px solid var(--line);border-radius:11px;padding:12px;margin:8px 0;text-decoration:none;font-weight:700;color:var(--ink)}}
.btn.primary{{background:var(--accent);border-color:var(--accent);color:#fff}}
.note{{font-size:.78rem;color:var(--sub);margin-top:14px}}
</style>
</head>
<body>
<header><div class="wrap"><a href="../index.html">← 🏮 {SITE_NAME}</a></div></header>
<div class="wrap">
  {sample_banner}
  {status_html}
  <h1>{e(ev['name'])}</h1>
  <div class="city">愛知県{e(ev['city'])}・{e(ev.get('venue',''))}</div>
  <span class="ptype {pt_cls}">{pt_label}</span>
  {img_html}
  <div class="box">
    <h2>📅 開催日時</h2>
    <ul class="dates">{date_rows or "<li>日程未定</li>"}</ul>
    <dl>
      {rain}
      <dt>場所</dt><dd>{place_disp}</dd>
    </dl>
    <a class="btn" href="{e(maps_url)}" target="_blank" rel="noopener">🗺 Googleマップで場所を確認</a>
  </div>
  {desc_block}
  <div class="trustbox">
    <div class="row"><span class="k">投稿者区分</span><span><span class="ptype {pt_cls}">{pt_label}</span><br><small>{pt_desc}</small></span></div>
    <div class="row"><span class="k">情報元</span><span>{source_html}</span></div>
    <div class="row"><span class="k">最終確認日</span><span>{e(ev.get('lastVerified','—'))}</span></div>
    <div class="row"><span class="k">画像</span><span>{"掲載許可を確認済み" if ev.get('imageAllowed') else "掲載画像なし（権利確認済みの画像のみ掲載します）"}</span></div>
  </div>
  <a class="btn primary" href="../submit.html">この情報の修正・中止情報・新しい盆踊りを投稿する</a>
  <a class="btn" href="../index.html">一覧にもどる</a>
  <p class="note">※ 掲載内容は変更・中止になることがあります。お出かけ前に上記の情報元で最新情報をご確認ください。当サイトは他のイベント情報サイトからの転載は行っていません。</p>
</div>
</body>
</html>
"""


def main():
    with open(os.path.join(HERE, "events.json"), encoding="utf-8") as f:
        data = json.load(f)
    events = [ev for ev in data.get("events", []) if ev.get("status") == "published"]

    # 必須フィールドの簡易チェック
    for ev in events:
        for field in ("id", "name", "city", "dates", "posterType", "lastVerified"):
            if not ev.get(field):
                sys.exit(f"エラー: イベント {ev.get('id') or ev.get('name')} に必須フィールド '{field}' がありません")
        if not all(c.isalnum() or c == "-" for c in ev["id"]):
            sys.exit(f"エラー: id '{ev['id']}' は英数字とハイフンのみ使用できます")

    os.makedirs(OUT_DIR, exist_ok=True)
    # 公開対象外になった古いページを削除
    keep = {f"{ev['id']}.html" for ev in events}
    for name in os.listdir(OUT_DIR):
        if name.endswith(".html") and name not in keep:
            os.remove(os.path.join(OUT_DIR, name))
            print(f"削除: e/{name}")

    for ev in events:
        path = os.path.join(OUT_DIR, f"{ev['id']}.html")
        with open(path, "w", encoding="utf-8") as f:
            f.write(page_html(ev))
        print(f"生成: e/{ev['id']}.html")

    # sitemap.xml
    urls = [BASE_URL, BASE_URL + "submit.html", BASE_URL + "support.html"] + [BASE_URL + f"e/{ev['id']}.html" for ev in events]
    sitemap = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    sitemap += "".join(f"  <url><loc>{html.escape(u)}</loc></url>\n" for u in urls)
    sitemap += "</urlset>\n"
    with open(os.path.join(HERE, "sitemap.xml"), "w", encoding="utf-8") as f:
        f.write(sitemap)
    print(f"生成: sitemap.xml（{len(urls)} URL）")
    print(f"完了: 公開イベント {len(events)} 件")


if __name__ == "__main__":
    main()
