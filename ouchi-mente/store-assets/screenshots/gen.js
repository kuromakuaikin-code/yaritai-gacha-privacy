/**
 * App Store用スクリーンショット生成（1290×2796 = 6.7インチ）。
 * アプリの theme.ts と同じ配色・実際の画面構成を再現する。
 */
const fs = require("fs");
const path = require("path");
const { chromium } = require(path.join(__dirname, "../icons/node_modules/playwright-core"));

const C = {
  primary: "#2E8B84", primarySoft: "#E4F2F1", bg: "#F7F9F8", surface: "#FFFFFF",
  border: "#E3E8E6", text: "#26332F", text2: "#5F6E69", muted: "#8A9691",
  overdue: "#C05621", overdueSoft: "#FBEDE3", soon: "#B7791F", soonSoft: "#FAF3E0",
};

const BASE_CSS = `
*{margin:0;padding:0;box-sizing:border-box;-webkit-font-smoothing:antialiased}
html,body{width:1290px;height:2796px;overflow:hidden;
  font-family:"Noto Sans CJK JP","Noto Color Emoji",sans-serif}
body{background:linear-gradient(180deg,#EAF4F3 0%,#F7F9F8 45%,#DDEBE9 100%);
  display:flex;flex-direction:column;align-items:center}
.headline{margin-top:150px;text-align:center;color:${C.text};
  font-size:96px;font-weight:900;line-height:1.32;letter-spacing:2px}
.sub{margin-top:36px;text-align:center;color:${C.text2};font-size:44px;line-height:1.5}
.accent{color:${C.primary}}
.phone{margin-top:96px;width:1010px;height:2130px;background:#111C1A;border-radius:132px;
  padding:26px;box-shadow:0 60px 120px rgba(20,50,46,.28)}
.screen{position:relative;width:100%;height:100%;background:${C.bg};border-radius:108px;
  overflow:hidden}
.island{position:absolute;top:28px;left:50%;transform:translateX(-50%);
  width:240px;height:70px;background:#111C1A;border-radius:40px;z-index:10}
.appheader{padding:120px 48px 24px;background:${C.surface};
  border-bottom:1px solid ${C.border};display:flex;justify-content:space-between;align-items:flex-end}
.apptitle{font-size:42px;font-weight:800;color:${C.text}}
.gear{font-size:34px;color:${C.text2}}
.content{padding:36px 40px}
.card{background:${C.surface};border:2px solid ${C.border};border-radius:34px;
  padding:34px;margin-bottom:26px}
.badge{display:inline-block;border-radius:999px;padding:8px 24px;font-size:26px;font-weight:700}
.btn{border-radius:26px;padding:24px;text-align:center;font-size:34px;font-weight:700}
.btn-primary{background:${C.primary};color:#fff}
.btn-outline{border:3px solid ${C.primary};color:${C.primary};background:${C.surface}}
.note{background:${C.primarySoft};border-radius:26px;padding:26px;
  font-size:26px;line-height:1.55;color:${C.text2}}
`;

// ---- 部品 ----
const itemCard = (name, meta, due, badgeText, badgeFg, badgeBg, highlight) => `
  <div class="card" style="display:flex;align-items:center;gap:26px;
    ${highlight ? `border-color:${C.overdue};border-width:3px;` : ""}">
    <div style="flex:1">
      <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:16px">
        <div style="font-size:36px;font-weight:700;color:${C.text}">${name}</div>
        <div class="badge" style="color:${badgeFg};background:${badgeBg}">${badgeText}</div>
      </div>
      <div style="font-size:27px;color:${C.text2};margin-top:10px">${meta}</div>
      <div style="font-size:30px;color:${C.text};margin-top:12px">${due}</div>
    </div>
    <div style="border:3px solid ${C.primary};border-radius:24px;background:${C.primarySoft};
      color:${C.primary};font-size:26px;font-weight:700;padding:16px 24px;text-align:center;
      line-height:1.3">完了を<br>記録</div>
  </div>`;

const summaryChip = (num, label, hl) => `
  <div style="flex:1;background:${hl ? C.overdueSoft : C.surface};border:2px solid ${hl ? C.overdue : C.border};
    border-radius:26px;text-align:center;padding:26px 0">
    <div style="font-size:48px;font-weight:800;color:${hl ? C.overdue : C.text}">${num}</div>
    <div style="font-size:26px;color:${C.text2};margin-top:4px">${label}</div>
  </div>`;

const sectionLabel = (t) => `<div style="font-size:30px;font-weight:700;color:${C.text2};
  margin:26px 4px 18px">${t}</div>`;

const field = (label, value, required) => `
  <div style="margin-bottom:28px">
    <div style="font-size:29px;font-weight:700;color:${C.text};margin-bottom:12px">${label}
      ${required ? `<span style="color:${C.overdue};font-size:24px;font-weight:400">（必須）</span>` : ""}</div>
    <div style="background:${C.bg};border:2px solid ${C.border};border-radius:24px;
      padding:26px;font-size:32px;color:${C.text}">${value}</div>
  </div>`;

// ---- 画面ボディ ----
const homeScreen = `
  <div class="appheader"><div class="apptitle">家の手入れ記録</div><div class="gear">⚙ 設定</div></div>
  <div class="content">
    <div style="display:flex;gap:20px;margin-bottom:30px">
      ${summaryChip(1, "目安日超過", true)}${summaryChip(3, "30日以内", false)}${summaryChip(2, "それ以降", false)}
    </div>
    ${sectionLabel("目安日超過")}
    ${itemCard("換気扇フィルター", "キッチン・掃除", "次回目安：2026年7月9日（5日超過）", "⏰ 目安日超過", C.overdue, C.overdueSoft, true)}
    ${sectionLabel("7日以内")}
    ${itemCard("加湿器フィルター", "寝室・掃除", "次回目安：2026年7月18日（あと4日）", "🔔 もうすぐ", C.soon, C.soonSoft)}
    ${sectionLabel("30日以内")}
    ${itemCard("エアコンフィルター", "リビング・掃除", "次回目安：2026年7月26日（あと12日）", "📅 予定あり", C.text2, "#EEF1F0")}
    ${itemCard("洗濯槽", "洗面所・掃除", "次回目安：2026年8月3日（あと20日）", "📅 予定あり", C.text2, "#EEF1F0")}
    <div style="position:absolute;bottom:0;left:0;right:0;background:${C.surface};
      border-top:1px solid ${C.border};padding:34px 40px;display:flex;gap:22px">
      <div class="btn btn-outline" style="flex:1">テンプレートから追加</div>
      <div class="btn btn-primary" style="flex:1">自分で追加</div>
    </div>
  </div>`;

const completeScreen = `
  <div class="appheader"><div class="apptitle">完了として記録</div><div class="gear">✕</div></div>
  <div class="content">
    <div style="font-size:44px;font-weight:800;color:${C.text};line-height:1.45;margin:14px 4px 36px">
      リビングのエアコンフィルターの掃除を記録しますか？</div>
    <div class="card">
      ${field("実施日", "2026年7月14日", true)}
      ${field("次回目安", "2026年8月13日", false)}
      ${field("メモ（任意）", "フィルター2枚とも水洗い", false)}
    </div>
    <div class="note">表示される周期は一般的な目安です。実際のお手入れ・交換・点検時期は、製品の取扱説明書やメーカーの案内を優先してください。</div>
    <div style="position:absolute;bottom:0;left:0;right:0;background:${C.surface};
      border-top:1px solid ${C.border};padding:34px 40px">
      <div class="btn btn-primary">記録する</div>
      <div style="text-align:center;color:${C.text2};font-size:32px;padding-top:26px">キャンセル</div>
    </div>
  </div>`;

const tmplRow = (name, meta, caution) => `
  <div class="card" style="display:flex;align-items:center;gap:20px">
    <div style="flex:1">
      <div style="font-size:36px;font-weight:700;color:${C.text}">${name}</div>
      <div style="font-size:27px;color:${C.text2};margin-top:8px">${meta}</div>
      ${caution ? `<div style="font-size:25px;color:${C.soon};margin-top:8px">${caution}</div>` : ""}
    </div>
    <div style="font-size:44px;color:${C.muted}">›</div>
  </div>`;

const templateScreen = `
  <div class="appheader"><div class="apptitle">テンプレートから追加</div><div class="gear">‹ 戻る</div></div>
  <div class="content">
    <div style="font-size:29px;color:${C.text2};line-height:1.5;margin:6px 4px 22px">
      数か月に一度の掃除や交換など、忘れやすい項目から選べます。</div>
    ${sectionLabel("エアコン")}
    ${tmplRow("エアコンフィルター", "掃除・目安 30日ごと", "使用環境や製品によって異なります。")}
    ${sectionLabel("キッチン")}
    ${tmplRow("換気扇フィルター", "掃除・目安 3か月ごと")}
    ${tmplRow("浄水器カートリッジ", "交換・周期はご自身で設定")}
    ${sectionLabel("洗濯機")}
    ${tmplRow("洗濯槽", "掃除・目安 1か月ごと")}
    ${sectionLabel("防災設備")}
    ${tmplRow("火災警報器の作動確認", "点検・目安 6か月ごと")}
  </div>`;

const notifyScreen = `
  <div style="height:100%;background:linear-gradient(180deg,#37918A,#25746E);position:relative">
    <div style="text-align:center;color:#fff;padding-top:280px">
      <div style="font-size:120px;font-weight:300">9:00</div>
      <div style="font-size:38px;opacity:.85;margin-top:8px">7月26日 日曜日</div>
    </div>
    <div style="margin:120px 44px 0;background:rgba(255,255,255,.96);border-radius:40px;
      padding:36px 40px;box-shadow:0 20px 60px rgba(0,0,0,.18)">
      <div style="display:flex;align-items:center;gap:22px">
        <div style="width:76px;height:76px;border-radius:20px;background:${C.primary};
          display:flex;align-items:center;justify-content:center;font-size:44px">🏠</div>
        <div style="flex:1">
          <div style="display:flex;justify-content:space-between">
            <div style="font-size:30px;font-weight:700;color:${C.text}">家の手入れ記録</div>
            <div style="font-size:26px;color:${C.muted}">今</div>
          </div>
          <div style="font-size:31px;color:${C.text};margin-top:6px;line-height:1.45">
            「リビングのエアコンフィルター」のお手入れ目安日です。</div>
        </div>
      </div>
    </div>
    <div style="margin:340px 60px 0;background:rgba(255,255,255,.14);border-radius:36px;padding:44px">
      <div style="color:#fff;font-size:33px;font-weight:700;margin-bottom:24px">通知する時刻は選べます</div>
      <div style="display:flex;gap:16px;flex-wrap:wrap">
        ${["7時","8時","9時","12時","18時","20時","21時"].map((t,i) =>
          `<div style="border-radius:999px;padding:14px 30px;font-size:28px;font-weight:600;
            ${i===2 ? "background:#fff;color:"+C.primary : "background:rgba(255,255,255,.18);color:#fff"}">${t}</div>`).join("")}
      </div>
    </div>
  </div>`;

const privacyScreen = `
  <div class="appheader"><div class="apptitle">プライバシー</div><div class="gear"></div></div>
  <div class="content" style="padding-top:60px">
    <div style="text-align:center;font-size:150px;margin-bottom:40px">🔒</div>
    ${[
      ["✓", "アカウント登録は不要"],
      ["✓", "記録はぜんぶ端末の中だけ"],
      ["✓", "開発者のサーバーへ送信しない"],
      ["✓", "広告なし・解析ツールなし"],
      ["✓", "位置情報・連絡先に触れない"],
    ].map(([m, t]) => `
      <div class="card" style="display:flex;align-items:center;gap:28px;padding:40px">
        <div style="width:64px;height:64px;border-radius:50%;background:${C.primarySoft};
          color:${C.primary};font-size:38px;font-weight:800;display:flex;align-items:center;
          justify-content:center">${m}</div>
        <div style="font-size:38px;font-weight:700;color:${C.text}">${t}</div>
      </div>`).join("")}
    <div class="note" style="margin-top:20px">購入はApp Storeが処理し、開発者が支払い情報を扱うことはありません。</div>
  </div>`;

// ---- ページ全体 ----
const page = (headline, sub, screenBody, opts = {}) => `<!doctype html><html><head>
<meta charset="utf-8"><style>${BASE_CSS}</style></head><body>
  <div class="headline">${headline}</div>
  <div class="sub">${sub}</div>
  <div class="phone"><div class="screen" style="${opts.dark ? "background:#25746E" : ""}">
    <div class="island"></div>${screenBody}</div></div>
</body></html>`;

const SHOTS = [
  ["01-home", page(
    `家中の「そろそろ」を<br><span class="accent">ひと目で</span>`,
    "エアコン・換気扇・洗濯槽・警報器。<br>次にやる日が、期限順に並びます。",
    homeScreen)],
  ["02-complete", page(
    `記録は<span class="accent">ワンタップ</span>`,
    "完了を押すだけ。設定した周期から<br>次回の目安日を自動で計算します。",
    completeScreen)],
  ["03-templates", page(
    `よくあるお手入れは<br><span class="accent">テンプレートから</span>`,
    "周期は「一般的な目安」入り。<br>おうちに合わせて自由に変更できます。",
    templateScreen)],
  ["04-notify", page(
    `目安日が近づいたら<br><span class="accent">通知でお知らせ</span>`,
    "当日・1日前・7日前など、タイミングも<br>通知する時刻も選べます。",
    notifyScreen)],
  ["05-privacy", page(
    `アカウント不要。<br>データは<span class="accent">端末の中だけ</span>`,
    "サーバーなし・広告なし・解析なし。<br>安心して家の記録を残せます。",
    privacyScreen)],
];

(async () => {
  for (const [name, html] of SHOTS) {
    fs.writeFileSync(path.join(__dirname, `${name}.html`), html);
  }
  const browser = await chromium.launch({
    executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
    args: ["--no-sandbox", "--font-render-hinting=none"],
  });
  const pageObj = await browser.newPage({ viewport: { width: 1290, height: 2796 } });
  for (const [name] of SHOTS) {
    await pageObj.goto(`file://${path.join(__dirname, `${name}.html`)}`);
    await pageObj.waitForTimeout(300);
    await pageObj.screenshot({ path: path.join(__dirname, `${name}.png`) });
    console.log("shot:", name);
  }
  await browser.close();
})();
