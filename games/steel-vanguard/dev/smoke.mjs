// STEEL VANGUARD スモークテスト
// 使い方: npm install && npx playwright install chromium && node smoke.mjs
// 全画面遷移とボス戦を自動プレイし、shots/ にスクリーンショットを保存する。
// 合格条件: 終了コード 0 (最後に NO PAGE ERRORS と表示される)
import {chromium} from 'playwright';
import {fileURLToPath} from 'url';
import path from 'path';
import fs from 'fs';

const dir = path.dirname(fileURLToPath(import.meta.url));
const url = 'file://' + path.join(dir, '..', 'index.html');
const shotsDir = path.join(dir, 'shots');
fs.mkdirSync(shotsDir, {recursive: true});
const errors = [];
const fails = [];
function expect(label, cond) {
  console.log((cond ? 'ok  ' : 'NG  ') + label);
  if (!cond) fails.push(label);
}

let browser;
try {
  browser = await chromium.launch();
} catch (e) {
  browser = await chromium.launch({executablePath: '/opt/pw-browsers/chromium'});
}
const page = await browser.newPage({viewport: {width: 990, height: 580}});
page.on('console', m => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
page.on('pageerror', e => errors.push('pageerror: ' + e.message));

const st = () => page.evaluate(() => state);
const shot = n => page.locator('#cv').screenshot({path: path.join(shotsDir, n)});

await page.goto(url);
await page.waitForTimeout(600);
expect('起動直後は TITLE', await st() === 'TITLE');
await shot('s1-title.png');

await page.keyboard.press('z');
await page.waitForTimeout(400);
expect('Z で BRIEF へ', await st() === 'BRIEF');
await page.keyboard.press('z');            // タイプ送りスキップ
await page.waitForTimeout(250);
await shot('s2-brief.png');
await page.keyboard.press('z');            // 出撃
await page.waitForTimeout(300);
expect('Z で PLAY へ', await st() === 'PLAY');

// 序盤: 右移動 + 射撃 + ホバー + ミサイル
await page.keyboard.down('ArrowRight');
await page.keyboard.down('z');
await page.waitForTimeout(1500);
await page.keyboard.down('x');
await page.waitForTimeout(700);
await page.keyboard.up('x');
await page.waitForTimeout(900);
await page.keyboard.press('c');
await page.waitForTimeout(700);
await page.keyboard.up('z');
await page.keyboard.up('ArrowRight');
const p1 = await page.evaluate(() => ({x: P.x, ammo: P.ammo, score: run.score}));
expect('前進できている (x>300)', p1.x > 300);
expect('ミサイルを消費した', p1.ammo < 30);
await shot('s3-play.png');

// ボス戦へ
await page.evaluate(() => { P.x = 5700; P.y = 232; camX = 5300; P.hp = 100; });
await page.keyboard.down('ArrowRight');
await page.waitForTimeout(800);
await page.keyboard.up('ArrowRight');
expect('ボス戦域ロック', await page.evaluate(() => bossLock));
await page.waitForTimeout(900);
await shot('s4-warning.png');
await page.waitForTimeout(7000);
const b1 = await page.evaluate(() => B ? {st: B.st, screenX: B.x - camX} : null);
expect('ボスが視界内にいる', !!b1 && b1.screenX < 470);
expect('ボス戦域に雑魚が残っていない', await page.evaluate(() => enemies.filter(e => !e.boss).length) === 0);
await shot('s5-boss.png');

// 各攻撃パターンを回しつつ射撃 (被弾で死なないよう HP 維持)
const seen = new Set();
for (let i = 0; i < 6; i++) {
  await page.evaluate(() => { P.hp = 100; P.iframe = 0; });
  await page.keyboard.down('z');
  await page.waitForTimeout(900);
  await page.keyboard.up('z');
  seen.add(await page.evaluate(() => B.st));
}
expect('攻撃パターンが複数観測できた', seen.size >= 2);
expect('ボスにダメージが入った', await page.evaluate(() => B.hp < B.maxHp));
await shot('s6-fight.png');

// 撃破 → クリア
await page.evaluate(() => { P.hp = 100; hitEnemy(B, 99999); });
await page.waitForTimeout(4500);
expect('撃破後に CLEAR へ', await st() === 'CLEAR');
expect('ランクが算出された', await page.evaluate(() => 'SABC'.includes(run.rank)));
await shot('s7-clear.png');
await page.keyboard.press('z');
await page.waitForTimeout(400);
expect('CLEAR から TITLE へ', await st() === 'TITLE');

// ゲームオーバー経路
for (const _ of [1, 2, 3]) { await page.keyboard.press('z'); await page.waitForTimeout(250); }
expect('再出撃で PLAY へ', await st() === 'PLAY');
await page.evaluate(() => damagePlayer(999));
await page.waitForTimeout(2600);
expect('撃破されると OVER へ', await st() === 'OVER');
await shot('s8-over.png');
await page.keyboard.press('z');
await page.waitForTimeout(300);
expect('OVER から Z でリトライ', await st() === 'PLAY');

// ポーズ
await page.keyboard.press('p');
await page.waitForTimeout(200);
expect('P でポーズ', await page.evaluate(() => paused));
await page.keyboard.press('p');

await browser.close();
if (errors.length) console.log('PAGE ERRORS:\n' + errors.join('\n'));
else console.log('NO PAGE ERRORS');
if (fails.length) console.log('FAILED: ' + fails.length + ' 件');
process.exit(errors.length || fails.length ? 1 : 0);
