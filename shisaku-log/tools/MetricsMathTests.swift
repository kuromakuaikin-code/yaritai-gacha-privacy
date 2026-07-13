import Foundation

// MetricsMath.swift（純粋ロジック部分）の検証スクリプト。
// アプリ本体をビルドしなくても、macOS のコマンドラインで実行できる:
//
//   cd shisaku-log
//   swiftc ShisakuLog/MetricsMath.swift tools/MetricsMathTests.swift -o /tmp/metrics-math-tests
//   /tmp/metrics-math-tests
//
// すべて成功すると "ALL PASSED" を表示して終了コード0、失敗があると1で終わる。

var failures = 0

func expect(_ condition: Bool, _ label: String) {
    if condition {
        print("  ok: \(label)")
    } else {
        failures += 1
        print("  FAILED: \(label)")
    }
}

func expectEqual(_ actual: Double?, _ expected: Double?, _ label: String, accuracy: Double = 0.0001) {
    switch (actual, expected) {
    case (nil, nil):
        print("  ok: \(label)")
    case let (a?, e?) where abs(a - e) <= accuracy:
        print("  ok: \(label)")
    default:
        failures += 1
        print("  FAILED: \(label) — actual=\(String(describing: actual)) expected=\(String(describing: expected))")
    }
}

let base = Day.today()

func day(_ offset: Int) -> Date { Day.add(base, offset) }

@main
struct MetricsMathTests {
    static func main() {
        // --- 1. 仕様書の例: 前7日平均 ¥320 → 後7日平均 ¥410（+28%） ---
        print("1. 基本の前後比較")
        do {
            var samples: [(date: Date, value: Double?)] = []
            for i in 1...7 { samples.append((day(-i), 320)) }   // 実施前7日
            for i in 1...7 { samples.append((day(i), 410)) }    // 実施後7日
            samples.append((day(0), 999))                       // 実施日当日は前後どちらにも入れない
            let ba = Comparison.beforeAfter(actionDate: base, samples: samples)
            expectEqual(ba.before.average, 320, "前7日平均 = 320")
            expectEqual(ba.after.average, 410, "後7日平均 = 410")
            expect(ba.before.sampleDays == 7 && ba.after.sampleDays == 7, "対象日数 7/7")
            expectEqual(ba.changePercent, (410.0 - 320.0) / 320.0 * 100, "変化率 ≒ +28%")
            expect(comparisonSummary(ba, unit: .yen) == "前7日平均 ¥320 → 後7日平均 ¥410（+28%）",
                   "表示文言: \(comparisonSummary(ba, unit: .yen))")
        }

        // --- 2. 欠損日は除外して平均（成功基準3） ---
        print("2. 欠損日の除外")
        do {
            var samples: [(date: Date, value: Double?)] = []
            samples.append((day(-3), 100))
            samples.append((day(-1), 200))          // 前は2日分だけ → 平均150
            samples.append((day(-2), nil))          // 値なしの日も除外される
            samples.append((day(2), 300))           // 後は1日分だけ → 平均300
            let ba = Comparison.beforeAfter(actionDate: base, samples: samples)
            expectEqual(ba.before.average, 150, "前平均 = (100+200)/2")
            expect(ba.before.sampleDays == 2, "前の対象日数 = 2")
            expectEqual(ba.after.average, 300, "後平均 = 300")
            expect(ba.after.sampleDays == 1, "後の対象日数 = 1")
        }

        // --- 3. 期間の端: 8日以上離れた日は含めない ---
        print("3. 前後7日の範囲外は含めない")
        do {
            let samples: [(date: Date, value: Double?)] = [
                (day(-8), 9999),   // 前8日 → 範囲外
                (day(-7), 100),    // 前7日 → 範囲内
                (day(7), 200),     // 後7日 → 範囲内
                (day(8), 9999),    // 後8日 → 範囲外
            ]
            let ba = Comparison.beforeAfter(actionDate: base, samples: samples)
            expectEqual(ba.before.average, 100, "前は7日前まで")
            expectEqual(ba.after.average, 200, "後は7日後まで")
        }

        // --- 4. 片側にデータがない場合 ---
        print("4. 片側欠損")
        do {
            let samples: [(date: Date, value: Double?)] = [(day(2), 500)]
            let ba = Comparison.beforeAfter(actionDate: base, samples: samples)
            expectEqual(ba.before.average, nil, "前平均 = nil")
            expect(ba.changePercent == nil, "変化率 = nil（比較不能）")
            expect(comparisonSummary(ba, unit: .yen) == "前7日平均 データなし → 後7日平均 ¥500",
                   "表示文言: \(comparisonSummary(ba, unit: .yen))")
        }

        // --- 5. 完全にデータがない場合 ---
        print("5. 前後ともデータなし")
        do {
            let ba = Comparison.beforeAfter(actionDate: base, samples: [])
            expect(comparisonSummary(ba, unit: .yen) == "前後7日のデータがありません",
                   "表示文言: \(comparisonSummary(ba, unit: .yen))")
        }

        // --- 6. マイナス方向の変化率 ---
        print("6. 減少時の表示")
        do {
            var samples: [(date: Date, value: Double?)] = []
            for i in 1...7 { samples.append((day(-i), 400)) }
            for i in 1...7 { samples.append((day(i), 300)) }
            let ba = Comparison.beforeAfter(actionDate: base, samples: samples)
            expectEqual(ba.changePercent, -25, "変化率 = -25%")
            expect(comparisonSummary(ba, unit: .yen).contains("（-25%）"),
                   "表示文言: \(comparisonSummary(ba, unit: .yen))")
        }

        // --- 7. 入力パース ---
        print("7. 入力パース")
        do {
            expectEqual(parseDouble("1,234"), 1234, "カンマ入り収益")
            expect(parseDouble("") == nil, "空文字 → nil")
            expect(parseInt(" 42 ") == 42, "空白付きDL数")
            expect(parseInt("abc") == nil, "数値以外 → nil")
            expect(plainNumber(12.0) == "12", "12.0 → \"12\"")
            expect(plainNumber(12.34) == "12.3", "12.34 → \"12.3\"")
        }

        // --- 8. テストデータ用乱数の再現性 ---
        print("8. 乱数の再現性と範囲")
        do {
            var a = SeededRandom(state: 1)
            var b = SeededRandom(state: 1)
            var inRange = true
            var same = true
            for _ in 0..<1000 {
                let x = a.next()
                let y = b.next()
                if x != y { same = false }
                if !(x >= 0 && x < 1) { inRange = false }
            }
            expect(same, "同じシードで同じ列")
            expect(inRange, "0.0 ..< 1.0 の範囲")
        }

        if failures == 0 {
            print("ALL PASSED")
            exit(0)
        } else {
            print("\(failures) FAILED")
            exit(1)
        }
    }
}
