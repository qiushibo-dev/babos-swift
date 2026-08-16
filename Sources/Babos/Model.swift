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

    /// 画面に日本語を直書きしないための経由点
    func label(_ t: L) -> String {
        switch self {
        case .active:  t.active
        case .waiting: t.idle
        case .near:    t.near
        case .done:    t.done
        }
    }
}

// MARK: - 一巡

/// 完了した案件を 20 件ためて一区切り。溜まったらレポートを出せる。
///
/// **封をした一巡は捨てずに残す。** カウンタを 0 に戻すだけだと、
/// その場で書き出さなかった瞬間に「どの 20 件だったか」が永久に分からなくなる。
/// 「書き出さなくてもリセットでいい」は、書き出す機会が一度きりでいい
/// という意味ではない。
enum Cycle {
    static let size = 20

    /// ランプの寸法。HTML 版と同じ値。
    static let dot: Double = 8
    static let gap: Double = 10       // 横
    static let vgap: Double = 6       // 段間

    /// 気泡がランプへ飛ぶ時間。**BubbleField のキーフレームと必ず揃える。**
    /// ずれると点が先に現れるか、気泡が消えたあとに間が空く。
    static let flyDuration: Double = 1.4

    /// 一段に何個並べるか。**20 か 10 の二択にする。**
    /// 入るだけ詰める（15＋5 など）と段の長さが揃わず、
    /// 窓を動かすたびに割り方が変わって数えにくい。
    static func perRow(width: Double) -> Int {
        let need = Double(size) * dot + Double(size - 1) * gap
        return width >= need ? size : size / 2
    }

    /// 点が入る枠の大きさ。**空き枠は描かないが、枠自体は常にこの寸法。**
    /// 飛び先の座標をここから測るので、0 個のときも縮めてはいけない。
    static func innerSize(per: Int) -> CGSize {
        let segs = Double(size / per)
        return CGSize(width: Double(per) * dot + Double(per - 1) * gap,
                      height: segs * dot + (segs - 1) * vgap)
    }
}

/// 進行中の一巡。まだ封をしていない
struct OpenCycle: Codable, Hashable {
    var start: Date = .now
    var caseIds: [String] = []

    init() {}

    /// 理由は Snapshot.init(from:) と同じ
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start   = try c.decodeIfPresent(Date.self, forKey: .start) ?? .now
        caseIds = try c.decodeIfPresent([String].self, forKey: .caseIds) ?? []
    }
}

/// 封をした一巡。レポートの範囲になる
struct SealedCycle: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var start: Date
    var end: Date
    var caseIds: [String]
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

// MARK: - 配色

/// 現在の配色。**画面側は `Color.midnightInk` などの名前をそのまま使い続ける**——
/// ここを切り替えると全部の色が入れ替わる。
/// 切り替え時は ContentView に `.id(store.theme)` を付けて木ごと作り直す
/// （Color は observable ではないので、これが無いと再描画されない）。
/// `nonisolated(unsafe)` にしてある。
///
/// **`@MainActor` ＋ `MainActor.assumeIsolated` にしてはいけない。**
/// SwiftUI が色を評価するのは主スレッドとは限らず、そこで assumeIsolated を
/// 通すと動作は未定義。release ビルドではクラッシュせず、
/// **黙って壊れた値を返す**——気泡区と検索欄が真っ白になった。
///
/// 書き込むのは設定画面（主スレッド）だけ、読むのは色の判定だけなので、
/// データ競合が起きても最悪1フレーム古い色が出るだけ。
nonisolated(unsafe) var currentTheme: Theme = .ameba

private func pick(_ ameba: Color, _ mono: Color) -> Color {
    currentTheme == .ameba ? ameba : mono
}

private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
    Color(red: r, green: g, blue: b)
}

extension Color {
    /// ページ地
    static var midnightInk: Color { pick(rgb(0.00, 0.02, 0.18), rgb(1, 1, 1)) }
    /// 気泡区の背景グラデーションの内側
    static var violetWash: Color  { pick(rgb(0.02, 0.06, 0.35), rgb(0.96, 0.96, 0.97)) }
    /// 塗りアクション
    static var signalBlue: Color  { pick(rgb(0.02, 0.16, 0.80), rgb(0.13, 0.13, 0.13)) }
    /// 気泡の塗り
    static var haloViolet: Color  { pick(rgb(0.69, 0.71, 0.86), rgb(0.31, 0.32, 0.40)) }
    /// 気泡のラベル。mono では地が濃くなるので反転する
    static var bubbleText: Color  { pick(rgb(0.00, 0.02, 0.18), rgb(1, 1, 1)) }
    /// ホバーと選択の強調。全体で唯一の高彩度
    static var arcCyan: Color     { pick(rgb(0.20, 0.99, 1.00), rgb(0.13, 0.13, 0.13)) }
    /// 枠線
    static var slateBody: Color   { pick(rgb(0.31, 0.32, 0.40), rgb(0.86, 0.86, 0.87)) }
    /// 補助文字
    static var fog: Color         { pick(rgb(0.42, 0.42, 0.51), rgb(0.51, 0.52, 0.63)) }
    static var mist: Color        { pick(rgb(0.51, 0.52, 0.63), rgb(0.42, 0.42, 0.51)) }
    /// 主要文字。mono では黒に寄せる
    static var ink: Color         { pick(.white, rgb(0.13, 0.13, 0.13)) }
    /// **塗りの上に乗る文字は主題で反転させない。**
    /// accent はどちらの主題でも暗いので、常に白でないと読めなくなる
    static var onAccent: Color    { .white }

    static var hairline: Color    { pick(rgb(0.31, 0.32, 0.40).opacity(0.45),
                                         rgb(0.86, 0.86, 0.87)) }
    static var rowSelected: Color { pick(rgb(0.02, 0.06, 0.35).opacity(0.85),
                                         rgb(0.94, 0.94, 0.95)) }
}

