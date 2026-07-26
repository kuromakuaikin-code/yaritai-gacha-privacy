# Claude Code — Opus 5 最適設定

Opus 5 の lean system prompt (書き方の規定なし・まず動けの自律方針) の下で、
対話を通じた検討を成立させるための設定一式。

根拠は次の 3 つ:

1. 実測した Opus 5 の system prompt (書き方の規定が無い / "act" 方針がある)
2. [Prompting Claude Opus 5 (公式)](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)
3. [Prompting Claude Fable 5 (公式)](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5)

## 構成

| ファイル | 置き先 | 役割 |
|---|---|---|
| `output-styles/kento.md` | `~/.claude/output-styles/kento.md` | 書き方の規定 (構造・評価軸・番号の維持)。prompt の空白を埋める |
| `hooks/respond-first.sh` | `~/.claude/hooks/respond-first.sh` (要 `chmod +x`) | 毎発話直後に「まず返答」を 1 行注入。進め方の癖はこの層でしか止まらなかった |
| `settings-example.json` | `~/.claude/settings.json` にマージ | hook 登録と output style の既定化 |

インストール:

```bash
mkdir -p ~/.claude/output-styles ~/.claude/hooks
cp output-styles/kento.md ~/.claude/output-styles/
cp hooks/respond-first.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/respond-first.sh
# settings-example.json の内容を ~/.claude/settings.json へマージ
```

## 層の使い分け (どの指示をどこに置くか)

- **書き方** (構造・評価軸・文書の長さ) → output style。
  毎ターン attachment として届き、書き方には効くことを確認済み。
- **進め方** (発話にまず返答してから作業) → UserPromptSubmit hook。
  行動の直前に短く毎回届ける。output style では止まらなかった癖がこの層で止まった。
  公式ガイドも「長い prompt では末尾に短い reminder を重ねる」を推奨しており同じ原理。
- **プロジェクト固有の事実** (ビルド手順・規約) → CLAUDE.md。
  行動規範はここに置かない (発火位置が遠く、効きが不安定)。

## 旧 rules から削除するもの (公式ガイドの明示的推奨)

Opus 5 では次の指示は逆効果 (トークン浪費・品質低下) と公式に明記されている:

- 「最後に検証ステップを入れろ」「subagent で verify しろ」等の検証指示
  — Opus 5 は指示なしで自己検証する。重ねると過剰検証になる
- 「double-check しろ」「返答前に再確認しろ」等の再確認指示 — 同上
- code review で「高 severity のみ報告」「保守的に」 — 文字通り従い報告が減る。
  全部報告させて後段でフィルタする
- 禁止形の羅列 — 「望ましい動きの肯定形 + 例」の方が効くと公式が明記
- IMPORTANT 等の強調の乱用 — セキュリティと承認ゲート系のみに絞る

## モデル実行設定

- **thinking は切らない。** コストは effort で調整する。thinking off は
  tool call のテキスト漏れ・内部 XML タグ漏れの既知の副作用がある (公式ガイド)
- **effort の使い分け**: 既定 `high`。壁打ち・軽作業は `medium`/`low` で十分
  (Opus 5 は低 effort でも品質が保たれると公式に明記)。難しい実装のみ `xhigh`
- **応答の長さは effort では制御できない** (effort は思考量の制御)。
  長さと形は output style 側で規定する — 本構成の kento.md がその役割

## 運用メモ

- モデルを更新したら、rules を足す前に本体 system prompt の変化を実測する
  (headless と interactive で注入が異なる可能性があるため、検討用途の検証は interactive で行う)
- 発火条件は観測可能な事実で書く (「interrupt を受けた」等)。
  自己分類頼みの条件 (「重要な変更のときは」) はモデルが変わると不発になる
- output style の名指し上書きは、引用した原文がそのモデルの prompt に無い場合、
  空白を埋める定義として働くだけで害はない
