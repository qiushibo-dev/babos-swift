import SwiftUI

// MARK: - 案件

/// 一個案子。欄位刻意跟 HTML 版的 work-tracker.json 對齊，
/// 之後要讀舊資料的話直接 Codable 就能吃進來。
struct Case: Identifiable, Codable {
    var id: String
    var name: String
    var type: String = ""
    var client: String = ""
    /// 進度 0–10。這是唯一驅動氣泡外觀的數值
    var step: Int = 0
    var done: Bool = false
    var waiting: Bool = false

    /// 進度的 0–1 表示
    var progress: Double { Double(step) / 10 }
}

// MARK: - 氣泡的兩個編碼

/// 這兩條公式是整個 app 的核心，直接沿用 HTML 版，數值不要動。
/// 詳細理由在本家的 SPEC.md 決策 1、2。
enum Encoding {
    /// 尺寸＝這件案子現在佔掉多少腦袋。
    /// 常態曲線：剛開始小 → 中段最大 → 收尾又變小。
    /// 因為設計最耗神的是中段，收尾剩下的多半是機械性動作。
    static func size(_ p: Double) -> Double {
        let base = 16.0, span = 144.0, floor = 0.18
        return base + span * (floor + (1 - floor) * sin(p * .pi))
    }

    /// 濃淡＝已經走了多遠。單調遞增。
    /// 不能跟尺寸同方向衰減，否則「剛開始」與「快結束」會長得一樣。
    static func opacity(_ p: Double) -> Double {
        0.18 + 0.82 * p
    }
}

// MARK: - 配色（Ameba）

extension Color {
    static let midnightInk  = Color(red: 0.00, green: 0.02, blue: 0.18)  // #00052e
    static let violetWash   = Color(red: 0.02, green: 0.06, blue: 0.35)  // #06105a
    static let haloViolet   = Color(red: 0.69, green: 0.71, blue: 0.86)  // #afb4db
    static let arcCyan      = Color(red: 0.20, green: 0.99, blue: 1.00)  // #34fcff
}
