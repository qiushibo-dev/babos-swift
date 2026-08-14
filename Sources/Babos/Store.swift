import SwiftUI
import Observation

/// 全部狀態集中在這裡。畫面只讀它、只透過它的方法改。
///
/// `@MainActor` は必須。完了アニメーションの待機に Task を使うため、
/// これが無いと Swift 6 の並行性チェックが data race として弾く。
/// UI の状態はそもそも主スレッドに置くべきもの。
@MainActor
@Observable
final class Store {
    var cases: [Case] = []
    var selectedID: String?

    /// 右上のカードが何を出しているか。**新規案件は別ウィンドウにしない**——
    /// 詳細カードの位置にそのままフォームを出す（HTML 版と同じ）。
    enum Mode { case detail, new }
    var mode: Mode = .detail

    // 篩選。三個條件同時作用於氣泡區與列表——
    // 兩邊永遠是同一批資料的兩種呈現，這是本家定下的規則
    var query = ""
    var statusFilter: Status?
    var typeFilter: String?
    var clientFilter: String?

    var sortKey: SortKey = .updated
    var sortAscending = false

    enum SortKey: String, CaseIterable {
        case name, step, status, updated, links
        var label: String {
            switch self {
            case .name:    "案件名"
            case .step:    "進捗"
            case .status:  "ステータス"
            case .updated: "最終更新"
            case .links:   "リンク"
            }
        }
    }

    // MARK: 篩選結果

    private func matches(_ c: Case) -> Bool {
        if !query.isEmpty {
            let q = query.lowercased()
            let hit = [c.name, c.client, c.type].contains { $0.lowercased().contains(q) }
            if !hit { return false }
        }
        if let t = typeFilter, c.type != t { return false }
        if let cl = clientFilter, c.client != cl { return false }
        if let s = statusFilter, c.status != s { return false }
        return true
    }

    /// 氣泡區只放還沒完成的
    var bubbleCases: [Case] {
        cases.filter { !$0.done && matches($0) }
    }

    var listCases: [Case] {
        let base = cases.filter { c in
            guard matches(c) else { return false }
            return statusFilter == nil ? !c.done : true
        }
        return base.sorted { a, b in
            let asc = sortAscending
            switch sortKey {
            case .name:    return asc ? a.name < b.name : a.name > b.name
            case .step:    return asc ? a.step < b.step : a.step > b.step
            case .status:  return asc ? a.status.order < b.status.order : a.status.order > b.status.order
            case .links:   return asc ? a.links.count < b.links.count : a.links.count > b.links.count
            case .updated: return asc ? a.updated < b.updated : a.updated > b.updated
            }
        }
    }

    /// 未選取時顯示「最後更新的案件」。
    /// **不做「請點擊氣泡」型的空狀態**——那種提示只有第一次有用（本家決策 3）。
    var current: Case? {
        if let id = selectedID, let c = cases.first(where: { $0.id == id }) { return c }
        let alive = cases.filter { !$0.done }
        return (alive.isEmpty ? cases : alive).max(by: { $0.updated < $1.updated })
    }

    var isFiltering: Bool {
        !query.isEmpty || statusFilter != nil || typeFilter != nil || clientFilter != nil
    }

    // MARK: 統計

    func count(_ s: Status) -> Int { cases.filter { $0.status == s }.count }
    var aliveCount: Int { cases.filter { !$0.done }.count }

    func tally(_ key: KeyPath<Case, String>) -> [(String, Int)] {
        var m: [String: Int] = [:]
        for c in cases where !c[keyPath: key].isEmpty {
            m[c[keyPath: key], default: 0] += 1
        }
        return m.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    // MARK: 變更

    /// 任何寫入都走這裡，確保 updated 會動。
    /// 單純點開看過不算更新，否則瀏覽一輪之後卡片會跟著滑鼠亂跳。
    private func mutate(_ id: String, _ body: (inout Case) -> Void) {
        guard let i = cases.firstIndex(where: { $0.id == id }) else { return }
        body(&cases[i])
        cases[i].updated = .now
    }

    /// 完成確認待ち。10 に到達したら即完了にはせず、必ず一度訊く
    var pendingFinish: Case?
    /// 完了アニメーション中。物理は位置を凍結し、画面のキーフレームに任せる
    var finishing: Set<String> = []

    func setStep(_ id: String, _ n: Int) {
        guard let c = cases.first(where: { $0.id == id }) else { return }
        let next = (c.step == n) ? n - 1 : n

        // **10 に届いたら完了フロー。** ここがこの app で唯一の儀式的な瞬間
        if next >= 10 {
            pendingFinish = c
            return
        }
        mutate(id) { c in
            c.step = max(0, next)
            c.done = false
        }
    }

    /// 確認後：気泡を膨らませて上へ抜けさせ、抜け終わってから完了にする。
    /// 2 秒は BubbleField のキーフレーム（2.1 秒）とほぼ同じ長さ。
    func confirmFinish() {
        guard let target = pendingFinish else { return }
        pendingFinish = nil
        mutate(target.id) { $0.step = 10 }
        finishing.insert(target.id)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if let i = cases.firstIndex(where: { $0.id == target.id }) {
                cases[i].done = true
            }
            finishing.remove(target.id)
        }
    }

    func addLog(_ id: String, _ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        mutate(id) { $0.logs.append(LogEntry(text: t)) }
    }

    func removeLog(_ id: String, _ logID: String) {
        mutate(id) { $0.logs.removeAll { $0.id == logID } }
    }

    func addLink(_ id: String, _ link: Link) {
        mutate(id) { $0.links.append(link) }
    }

    func removeLink(_ id: String, _ linkID: String) {
        mutate(id) { $0.links.removeAll { $0.id == linkID } }
    }

    func setPriority(_ id: String, _ n: Int) {
        mutate(id) { c in c.priority = (c.priority == n) ? 0 : n }
    }

    func toggleWaiting(_ id: String) {
        mutate(id) { c in if !c.done { c.waiting.toggle() } }
    }

    func rename(_ id: String, _ name: String) {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        mutate(id) { $0.name = t }
    }

    func delete(_ id: String) {
        cases.removeAll { $0.id == id }
        if selectedID == id { selectedID = nil }
    }

    @discardableResult
    func create(name: String, type: String, client: String) -> Case {
        let c = Case(name: name, type: type, client: client)
        cases.append(c)
        selectedID = c.id
        mode = .detail
        return c
    }
}

extension Status {
    var order: Int {
        switch self {
        case .active: 0
        case .near:   1
        case .waiting: 2
        case .done:   3
        }
    }
}
