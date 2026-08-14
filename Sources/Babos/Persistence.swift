import Foundation

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
}

/// 標籤登記簿。案件輸入時會自動補進來，也可以先登記好。
struct Tags: Codable {
    var type: [String] = []
    var client: [String] = []
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
                // 初回起動。ファイルが無いのは異常ではないが、
                // **ここで一度書いておく**——書けるかどうかを起動時に確かめたい。
                // 「何か変更するまで書き込みを試さない」と、権限やパスの問題が
                // ずっと後になって発覚する（HTML 版がまさにそれだった）。
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

        // **色を実際に切り替えているのはこの全域フラグ。**
        // store.theme に入れただけでは何も変わらない。
        // ここを忘れていたので、再起動すると常に既定の配色に戻っていた。
        currentTheme = theme
    }

    private var snapshot: Snapshot {
        Snapshot(cases: cases, tags: tags,
                 lang: lang.rawValue, theme: theme.rawValue,
                 saverMinutes: saverMinutes,
                 sortKey: sortKey.rawValue, sortAscending: sortAscending)
    }

    // MARK: 寫

    /// 400ms 的 debounce。連續打字時不要每個字都寫檔。
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            saveNow()
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
