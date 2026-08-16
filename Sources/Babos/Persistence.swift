import Foundation
import AppKit

/// 檔案上的樣子。欄位名跟 HTML 版的 work-tracker.json 對齊，
/// 之後要互相讀取的話不用轉換。
struct Snapshot: Codable {
    var cases: [Case] = []
    var tags: Tags = .init()
    var lang: String = "ja"
    var theme: String = "ameba"
    var saverMinutes: Int = 5
    var sortKey: String = "updated"
    var sortAscending: Bool = false
    /// 進行中の一巡と、封をした過去の一巡
    var cycle: OpenCycle = .init()
    var cycles: [SealedCycle] = []

    init() {}

    /// **手書きの理由：既定値は「鍵が無いとき」の受け皿にならない。**
    ///
    /// 合成された `init(from:)` は `var x = 1` の 1 を使ってくれない。
    /// 鍵が無ければ `keyNotFound` を投げる。つまり項目を1つ足しただけで、
    /// それ以前に書かれた data.json は**まるごと**読めなくなる。
    ///
    /// そして `load()` は失敗しても cases を空のまま先へ進むので、
    /// 次の保存がその空を本物の上に書く。**症状は「全部消えた」。**
    /// cycle / cycles を足したこの版が、まさにその1回目だった。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cases         = try c.decodeIfPresent([Case].self, forKey: .cases) ?? []
        tags          = try c.decodeIfPresent(Tags.self, forKey: .tags) ?? .init()
        lang          = try c.decodeIfPresent(String.self, forKey: .lang) ?? "ja"
        theme         = try c.decodeIfPresent(String.self, forKey: .theme) ?? "ameba"
        saverMinutes  = try c.decodeIfPresent(Int.self, forKey: .saverMinutes) ?? 5
        sortKey       = try c.decodeIfPresent(String.self, forKey: .sortKey) ?? "updated"
        sortAscending = try c.decodeIfPresent(Bool.self, forKey: .sortAscending) ?? false
        cycle         = try c.decodeIfPresent(OpenCycle.self, forKey: .cycle) ?? .init()
        cycles        = try c.decodeIfPresent([SealedCycle].self, forKey: .cycles) ?? []
    }
}

/// 標籤登記簿。案件輸入時會自動補進來，也可以先登記好。
struct Tags: Codable {
    var type: [String] = []
    var client: [String] = []

    init() {}

    /// 理由は Snapshot.init(from:) と同じ
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type   = try c.decodeIfPresent([String].self, forKey: .type) ?? []
        client = try c.decodeIfPresent([String].self, forKey: .client) ?? []
    }
}

/// 儲存狀態。**一定要看得見。**
///
/// HTML 版最痛的一次是寫入連續失敗數十次卻完全無聲——錯誤只送到
/// `console.warn`，而 release build 沒有 devtools。localStorage 在頂著，
/// 表面上什麼問題都沒有。發現時已經過了好幾版。
enum FileState: Equatable {
    case unknown
    case ok(path: String)
    case failed(String)
}

extension Store {

    // MARK: 初回のサンプル

    /// 初回起動時に入る5件。HTML 版と同じ内容。
    ///
    /// **全て step 0（＝最小サイズ・最も淡い状態）にしてある。**
    /// 進捗をばらけさせると開いた瞬間は綺麗だが、その大きさが
    /// どこから来たのかユーザーには分からない。全部同じなら、
    /// 最初の進捗ノードを押した瞬間に「気泡が育って濃くなる」のを
    /// 自分の操作で目撃できる。ルールの説明が要らなくなる。
    static func samples() -> [Case] {
        let base = Date.now
        return ["A", "B", "C", "D", "E"].enumerated().map { i, k in
            var c = Case(name: "Project \(k)")
            c.id = "sample-\(k)"
            c.created = base.addingTimeInterval(Double(-i * 60))
            c.updated = c.created
            return c
        }
    }

    // MARK: 位置

    /// `~/Library/Application Support/com.shihbo.babos-swift/data.json`
    ///
    /// **父目錄要自己建。** HTML 版就是漏了這步（`writeTextFile` 不會建），
    /// 每次寫入都 ENOENT。
    static func dataURL() throws -> URL {
        let dir = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask,
                 appropriateFor: nil, create: true)
            .appendingPathComponent("com.shihbo.babos-swift", isDirectory: true)

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }

    // MARK: 讀

    func load() {
        do {
            let url = try Self.dataURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                // 初回起動。サンプルを入れてから一度書く。
                //
                // **書くのは「書けるか」をここで確かめたいから。**
                // 「何か変更するまで書き込みを試さない」と、権限やパスの問題が
                // ずっと後になって発覚する（HTML 版がまさにそれだった）。
                cases = Self.samples()
                saveNow()
                return
            }
            let data = try Data(contentsOf: url)
            let snap = try JSONDecoder.babos.decode(Snapshot.self, from: data)
            apply(snap)
            fileState = .ok(path: url.path)
        } catch {
            fileState = .failed(error.localizedDescription)
        }
    }

    private func apply(_ s: Snapshot) {
        cases = s.cases
        tags = s.tags
        lang = Lang(rawValue: s.lang) ?? .ja
        theme = Theme(rawValue: s.theme) ?? .ameba
        saverMinutes = s.saverMinutes
        sortKey = SortKey(rawValue: s.sortKey) ?? .updated
        sortAscending = s.sortAscending
        cycle = s.cycle
        cycles = s.cycles

        // 既存のデータには cycle が無い。**すでに done の案件を遡って点けない**——
        // 一巡は「これから完了させる 20 件」の単位であって、過去の集計ではない。
        // 遡って点けると、初回起動でいきなり満了ダイアログが出ることもある。

        // **色を実際に切り替えているのはこの全域フラグ。**
        // store.theme に入れただけでは何も変わらない。
        // ここを忘れていたので、再起動すると常に既定の配色に戻っていた。
        currentTheme = theme
    }

    private var snapshot: Snapshot {
        // init(from:) を手書きした時点で memberwise init は消えるので、
        // ここは1項目ずつ埋める。**足したら必ずここも足すこと。**
        var s = Snapshot()
        s.cases = cases
        s.tags = tags
        s.lang = lang.rawValue
        s.theme = theme.rawValue
        s.saverMinutes = saverMinutes
        s.sortKey = sortKey.rawValue
        s.sortAscending = sortAscending
        s.cycle = cycle
        s.cycles = cycles
        return s
    }

    // MARK: 寫

    /// 400ms 的 debounce。連續打字時不要每個字都寫檔。
    ///
    /// **待機中に終了されると、その分の変更は消える。**
    /// 対策として `watchTermination()` で終了通知を捕まえ、最後に一度書く。
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    /// 終了時に取りこぼしを防ぐ。
    /// 「変更してから 400ms 以内に Cmd+Q」で1回ぶん消えるのは実害があるので、
    /// 終了通知で強制的に書き切る。
    func watchTermination() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                self.saveTask?.cancel()
                self.saveNow()
            }
        }
    }

    func saveNow() {
        do {
            let url = try Self.dataURL()
            let data = try JSONEncoder.babos.encode(snapshot)
            // .atomic：書き込み途中で落ちても既存ファイルを壊さない
            try data.write(to: url, options: .atomic)
            fileState = .ok(path: url.path)
        } catch {
            fileState = .failed(error.localizedDescription)
        }
    }
}

// MARK: - 日付は ISO8601 で持つ（HTML 版と揃える）

extension JSONEncoder {
    static let babos: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }()
}

extension JSONDecoder {
    static let babos: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
