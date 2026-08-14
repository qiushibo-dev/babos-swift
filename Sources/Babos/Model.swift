import SwiftUI

// MARK: - 案件

/// 一筆工作日誌。`source` 保留給未來的自動記錄（檔案監看／Gmail 關鍵字）。
struct LogEntry: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var ts: Date = .now
    var text: String
    var source: String = "manual"
}

struct Link: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable { case drive = "Drive", figma = "Figma", local = "Local", url = "URL" }
    var id: String = UUID().uuidString
    var type: Kind = .url
    var url: String
}

/// 一個案子。欄位刻意跟 HTML 版的 work-tracker.json 對齊，
/// 之後要讀舊資料的話直接 Codable 就能吃進來。
struct Case: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var type: String = ""
    var client: String = ""
    /// 進度 0–10。這是唯一驅動氣泡外觀的數值
    var step: Int = 0
    var done: Bool = false
    var waiting: Bool = false
    var memo: String = ""
    /// 重要度 0–5。**只出現在列表的圓點上，不進氣泡的編碼**（本家已否決）
    var priority: Int = 0
    var created: Date = .now
    var updated: Date = .now
    var logs: [LogEntry] = []
    var links: [Link] = []

    var progress: Double { Double(step) / 10 }

    var status: Status {
        if done { return .done }
        if waiting { return .waiting }
        return progress > 0.85 ? .near : .active
    }
}

enum Status: String, CaseIterable, Identifiable {
    case active, waiting, near, done
    var id: String { rawValue }

    var label: String {
        switch self {
        case .active:  "進行中"
        case .waiting: "待機"
        case .near:    "完了間近"
        case .done:    "完了"
        }
    }
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
    static let signalBlue   = Color(red: 0.02, green: 0.16, blue: 0.80)  // #0428cb
    static let haloViolet   = Color(red: 0.69, green: 0.71, blue: 0.86)  // #afb4db
    static let arcCyan      = Color(red: 0.20, green: 0.99, blue: 1.00)  // #34fcff
    static let slateBody    = Color(red: 0.31, green: 0.32, blue: 0.40)  // #4f5166
    static let fog          = Color(red: 0.42, green: 0.42, blue: 0.51)  // #6b6b83
    static let mist         = Color(red: 0.51, green: 0.52, blue: 0.63)  // #8185a0

    static let hairline     = Color(red: 0.31, green: 0.32, blue: 0.40).opacity(0.45)
    static let rowHover     = Color(red: 0.02, green: 0.06, blue: 0.35).opacity(0.55)
    static let rowSelected  = Color(red: 0.02, green: 0.06, blue: 0.35).opacity(0.85)
}

// MARK: - 字級

/// `.meta` 相當於 HTML 版的等寬小標籤：11px、字距 0.085em、大寫。
extension View {
    func metaStyle(_ size: CGFloat = 11) -> some View {
        self.font(.system(size: size, design: .monospaced))
            .tracking(size * 0.085)
            .foregroundStyle(Color.fog)
    }
}
