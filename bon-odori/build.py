#!/usr/bin/env python3
"""盆踊り・地域祭りナビ東海 - 個別イベントページ生成スクリプト

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
import re
import sys
from datetime import date

BASE_URL = "https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/bon-odori/"
SITE_NAME = "盆踊り・地域祭りナビ東海"
CONTACT_URL = "https://docs.google.com/forms/d/e/1FAIpQLSe79hdutpq0chrswO8KipS_5beNv3iJMLCICtOdo05RSqyLQA/viewform?usp=publish-editor"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "e")

WEEKDAYS = ["月", "火", "水", "木", "金", "土", "日"]

POSTER_TYPES = {
    "admin": ("admin", "公式情報あり", "自治体・主催者等の公式ページを情報元として掲載しています。開催を保証する表示ではないため、最新状況はリンク先をご確認ください。"),
    "organizer": ("organizer", "主催者からの情報", "主催者から提供された情報です。"),
    "resident": ("resident", "住民からの情報（未確認）", "地域住民からの情報で、公式情報は未確認です。開催の有無は現地の掲示等でご確認ください。"),
}

STATUS_INFO = {
    "cancelled": ("EventCancelled", "❌ このイベントは中止になりました"),
    "postponed": ("EventPostponed", "⏸ このイベントは延期になりました"),
    "scheduled": ("EventScheduled", ""),
}

SCALE_TYPES = {
    "major": ("major", "大きめ・有名", "広域から人が集まる大きめの夏まつり・有名イベントです。"),
    "regional": ("regional", "地域イベント", "市区町村や地域単位の夏まつり・盆踊りです。"),
    "neighborhood": ("neighborhood", "町内会・学区", "町内会・学区・神社・公園など、身近な小さめの盆踊りです。"),
}

CATEGORY_TYPES = {
    "bonodori": ("盆踊り", "盆踊り・盆おどりを含む催しです。"),
    "festival": ("地域の祭り", "地域に受け継がれる祭礼・季節の祭りです。"),
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


def feature_labels(ev):
    """独自要約に明記された内容だけを、一覧しやすい短いラベルにする。"""
    text = " ".join(str(ev.get(key, "")) for key in ("name", "desc", "venue", "address"))
    labels = []
    checks = [
        (("花火",), "🎆 花火"),
        (("屋台", "模擬店", "出店", "夜店"), "🍡 出店"),
        (("山車",), "山車"),
        (("子ども", "こども", "小学生"), "子ども企画"),
        (("駐車場",), "🅿 駐車場情報"),
    ]
    for words, label in checks:
        if any(word in text for word in words):
            labels.append(label)
    if ev.get("rain"):
        labels.append("☔ 雨天案内")
    return labels


def page_html(ev):
    pt_key = ev.get("posterType", "resident")
    pt_cls, pt_label, pt_desc = POSTER_TYPES.get(pt_key, POSTER_TYPES["resident"])
    scale_key = ev.get("scale", "regional")
    scale_cls, scale_label, scale_desc = SCALE_TYPES.get(scale_key, SCALE_TYPES["regional"])
    category_key = ev.get("category", "bonodori")
    category_label, category_desc = CATEGORY_TYPES.get(category_key, CATEGORY_TYPES["bonodori"])
    ev_status = ev.get("eventStatus", "scheduled")
    schema_status, status_banner = STATUS_INFO.get(ev_status, STATUS_INFO["scheduled"])

    dates = ev.get("dates", [])
    first = dates[0] if dates else {}
    date_label = jdate_short(first["date"]) if first.get("date") else "日程未定"
    if len(dates) > 1:
        date_label += f"〜{jdate_short(dates[-1]['date']).split('年')[1]}" if dates[-1]["date"][:4] == first["date"][:4] else "ほか"

    prefecture = ev.get("prefecture", "愛知県")
    title = f"{ev['name']}（{prefecture}{ev['city']}・{date_label}開催）｜{SITE_NAME}"
    desc_meta = (
        f"{prefecture}{ev['city']}の{ev.get('venue','')}で{date_label}に開催される{category_label}「{ev['name']}」。"
        f"日時・場所・規模・雨天時の扱い・情報元・最終確認日を掲載。"
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
            "address": {"@type": "PostalAddress", "addressRegion": prefecture, "addressLocality": ev["city"], "streetAddress": ev.get("address", "")},
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
    feature_items = feature_labels(ev)
    features_html = ('<div class="features">' + "".join(f'<span>{e(label)}</span>' for label in feature_items) + "</div>") if feature_items else ""

    addr = ev.get("address", "")
    if addr.startswith(ev["city"]):
        addr = addr[len(ev["city"]):].lstrip()
    place_disp = f"{e(ev.get('venue',''))}（{e(ev['city'])}" + (f" {e(addr)}" if addr and addr != ev.get("venue") else "") + "）"

    return re.sub(r"[ \t]+\n", "\n", f"""<!DOCTYPE html>
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
.scale{{display:inline-block;font-size:.78rem;font-weight:800;border-radius:7px;padding:2px 10px;margin-right:6px;background:var(--gray-soft);color:var(--sub)}}
.scale.major{{background:var(--accent-soft);color:var(--accent)}}
.scale.regional{{background:var(--blue-soft);color:var(--blue)}}
.scale.neighborhood{{background:var(--green-soft);color:var(--green)}}
.features{{display:flex;gap:6px;flex-wrap:wrap;margin:10px 0}}
.features span{{font-size:.76rem;font-weight:700;background:#fff;border:1px solid var(--line);border-radius:6px;padding:2px 8px}}
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
  <div class="city">{e(prefecture)}{e(ev['city'])}・{e(ev.get('venue',''))}</div>
  <span class="scale {scale_cls}">{scale_label}</span>
  <span class="scale">{e(category_label)}</span>
  <span class="ptype {pt_cls}">{pt_label}</span>
  {features_html}
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
    <div class="row"><span class="k">情報区分</span><span><span class="ptype {pt_cls}">{pt_label}</span><br><small>{pt_desc}</small></span></div>
    <div class="row"><span class="k">規模</span><span><span class="scale {scale_cls}">{scale_label}</span><br><small>{scale_desc}</small></span></div>
    <div class="row"><span class="k">種類</span><span><b>{e(category_label)}</b><br><small>{e(category_desc)}</small></span></div>
    <div class="row"><span class="k">情報元</span><span>{source_html}</span></div>
    <div class="row"><span class="k">最終確認日</span><span>{e(ev.get('lastVerified','—'))}</span></div>
    <div class="row"><span class="k">画像</span><span>{"掲載許可を確認済み" if ev.get('imageAllowed') else "掲載画像なし（権利確認済みの画像のみ掲載します）"}</span></div>
  </div>
  <a class="btn primary" href="../submit.html">この情報の修正・中止情報・新しい祭りを投稿する</a>
  <a class="btn" href="{CONTACT_URL}" target="_blank" rel="noopener">運営へ問い合わせる</a>
  <a class="btn" href="../index.html">一覧にもどる</a>
  <p class="note">※ 「公式情報あり」は、自治体・主催者等の公式ページを情報元としていることを示すもので、当サイトによる開催保証ではありません。掲載内容は変更・中止になることがあるため、お出かけ前に上記の情報元で最新情報をご確認ください。他サイト本文の転載やチラシ画像の無断掲載は行っていません。</p>
</div>
</body>
</html>
""")


def main():
    with open(os.path.join(HERE, "events.json"), encoding="utf-8") as f:
        data = json.load(f)
    events = [ev for ev in data.get("events", []) if ev.get("status") == "published"]
    pending_events = [ev for ev in data.get("events", []) if ev.get("status") == "pending"]
    with open(os.path.join(HERE, "coverage.json"), encoding="utf-8") as f:
        coverage_data = json.load(f)
    coverage = coverage_data.get("areas", [])
    with open(os.path.join(HERE, "candidates.json"), encoding="utf-8") as f:
        candidate_data = json.load(f)
    candidates = pending_events + candidate_data.get("candidates", [])

    # 公開データは、公式情報へのリンクと独自要約が揃ったものだけを許可する。
    for ev in events:
        for field in ("id", "name", "prefecture", "city", "dates", "posterType", "lastVerified"):
            if not ev.get(field):
                sys.exit(f"エラー: イベント {ev.get('id') or ev.get('name')} に必須フィールド '{field}' がありません")
        if not all(c.isalnum() or c == "-" for c in ev["id"]):
            sys.exit(f"エラー: id '{ev['id']}' は英数字とハイフンのみ使用できます")
        source = ev.get("source") or {}
        if not source.get("name") or not source.get("url", "").startswith(("https://", "http://")):
            sys.exit(f"エラー: 公開イベント {ev['id']} には公式情報元の名称とURLが必要です")
        if not ev.get("desc"):
            sys.exit(f"エラー: 公開イベント {ev['id']} には独自要約 desc が必要です")
        if ev.get("image") and not ev.get("imageAllowed"):
            sys.exit(f"エラー: 公開イベント {ev['id']} の画像は掲載許可が確認されていません")

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
    urls = [BASE_URL, BASE_URL + "submit.html", BASE_URL + "support.html", BASE_URL + "policy.html"] + [BASE_URL + f"e/{ev['id']}.html" for ev in events]
    sitemap = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    sitemap += "".join(f"  <url><loc>{html.escape(u)}</loc></url>\n" for u in urls)
    sitemap += "</urlset>\n"
    with open(os.path.join(HERE, "sitemap.xml"), "w", encoding="utf-8") as f:
        f.write(sitemap)
    print(f"生成: sitemap.xml（{len(urls)} URL）")

    # file:// で開く確認用ページにも公開データと地域確認状況を同期する。
    preview_path = os.path.join(HERE, "preview.html")
    if os.path.exists(preview_path):
        start_marker = "/* GENERATED_EVENTS_START */"
        end_marker = "/* GENERATED_EVENTS_END */"
        with open(preview_path, encoding="utf-8") as f:
            preview = f.read()
        if start_marker not in preview or end_marker not in preview:
            sys.exit("エラー: preview.html のイベント同期マーカーがありません")
        before, marked = preview.split(start_marker, 1)
        _, after = marked.split(end_marker, 1)
        payload = json.dumps(events, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
        generated = f"{start_marker}\nconst events={payload};\n{end_marker}"
        with open(preview_path, "w", encoding="utf-8") as f:
            f.write(before + generated + after)

        coverage_start = "/* GENERATED_COVERAGE_START */"
        coverage_end = "/* GENERATED_COVERAGE_END */"
        with open(preview_path, encoding="utf-8") as f:
            preview = f.read()
        if coverage_start not in preview or coverage_end not in preview:
            sys.exit("エラー: preview.html の地域確認状況同期マーカーがありません")
        before, marked = preview.split(coverage_start, 1)
        _, after = marked.split(coverage_end, 1)
        coverage_payload = json.dumps(coverage, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
        generated = f"{coverage_start}\nconst coverage={coverage_payload};\n{coverage_end}"
        with open(preview_path, "w", encoding="utf-8") as f:
            f.write(before + generated + after)

        candidate_start = "/* GENERATED_CANDIDATES_START */"
        candidate_end = "/* GENERATED_CANDIDATES_END */"
        with open(preview_path, encoding="utf-8") as f:
            preview = f.read()
        if candidate_start not in preview or candidate_end not in preview:
            sys.exit("エラー: preview.html の未確認候補同期マーカーがありません")
        before, marked = preview.split(candidate_start, 1)
        _, after = marked.split(candidate_end, 1)
        candidate_payload = json.dumps(candidates, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
        generated = f"{candidate_start}\nconst candidateEvents={candidate_payload};\n{candidate_end}"
        with open(preview_path, "w", encoding="utf-8") as f:
            f.write(before + generated + after)
        print(f"生成: preview.html（イベント{len(events)}件・未確認候補{len(candidates)}件・確認地域{len(coverage)}件）")

    print(f"完了: 公開イベント {len(events)} 件")


if __name__ == "__main__":
    main()
