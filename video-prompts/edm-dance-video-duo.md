# EDM ダンス動画 2 人同時出演プリセット (2girls)

[星の魔女っ子](edm-dance-video-character.md) と [紅ドレスのツインテール](edm-dance-video-character-2.md) を同じ動画に出すための結合プロンプト。

2 人は元の頭身が異なる (チビ体型 / 通常頭身) ため、混在させると生成が不安定になりやすい。このプリセットでは**通常頭身に統一**する: 魔女っ子側の chibi を外し、2 人とも通常頭身で踊らせ、衣装・髪型の描き分けで区別する。

## 結合プロンプト全文 (コピペ用)

```
2girls, side by side dancing, both with blonde hair, red eyes, smug smile, first girl is a witch with very long wavy messy hair, black witch hat with cat ears, crimson hat brim, gold star ornaments, star-shaped dangling hat charms, black hooded coat with crimson lining and gold trim, tattered cape hem, dark red pleated dress, gold star brooch, black fingerless gloves, black thighhighs, second girl has very long wavy twintails, black capelet with gold trim, white stand collar, dark red long-sleeved dress with white hem, black belt with gold ring, black gloves, black pantyhose, unchanging style, perfect visual consistency, edm, limited animation, handheld camera, feeling the music, techhouse, party, bouncing, shaky camera, dynamic, windy, foreshortening, hand dancing, non verbal, camera rocks side to side, unstable camera, fisheye lens camera moves up and down and in regularly, djing, mostly dancing, shimmying, hands go up, camera orbits back and forth, fisheye lens, fluid graceful and elegant flowing motion, momentary gesture at the viewer, flickering jittering line art, flickering jittery hatch shading, flickering jittering art medium, flickering jittering paint stroke texture, traditional art medium, semi sketchy style.
```

## 単独版からの変更点

| 変更 | 理由 |
| --- | --- |
| 1girl, solo → 2girls, side by side dancing | 2 人並びの構図指定 |
| chibi (魔女っ子) を除外 | 通常頭身に統一するため |
| 共通要素 (blonde hair, red eyes, smug smile) を both with にまとめた | タグ重複による片方への偏りを防ぐ |
| first girl is / second girl has で衣装を区切った | 衣装・髪型の混ざり (特徴のブリード) を抑える |
| fingers trace body camera follows her hands を除外 | 単独の踊り手を前提としたカメラ指定のため。片方に寄るカットを作る場合のみ戻す |
| pointy ears (魔女っ子) を除外 | 帽子で見えない上、もう片方へ混ざりやすいため |

## メモ

- 2 人の描き分けが混ざる場合は、まず片方ずつ単独版 ([1 人目](edm-dance-video-character.md) / [2 人目](edm-dance-video-character-2.md)) で生成し、参照画像として与え直すのが確実。
- 帽子 (魔女っ子) とツインテール (2 人目) が最も強い識別子。混ざる時はこの 2 つを文頭に寄せる。
