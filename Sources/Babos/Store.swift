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

    // MARK: 設定（すべて data.json に入る）

    var tags = Tags()
    var lang: Lang = .ja
    var theme: Theme = .ameba
    /// 0 でオフ。既定は 5 分
    var saverMinutes = 5

    /// 表示文字列。画面側は必ずこれを経由する
    var t: L { L.of(lang) }

    // MARK: 保存

    var fileState: FileState = .unknown
    @ObservationIgnored var saveTask: Task<Void, Never>?

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
        func label(_ t: L) -> String {
            switch self {
            case .name:    t.colCase
            case .step:    t.progress
            case .status:  t.colStatus
            case .updated: t.colUpdated
            case .links:   t.links
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
        let sorted = base.sorted { a, b in
            let asc = sortAscending
            switch sortKey {
            case .name:    return asc ? a.name < b.name : a.name > b.name
            case .step:    return asc ? a.step < b.step : a.step > b.step
            case .status:  return asc ? a.status.order < b.status.order : a.status.order > b.status.order
            case .links:   return asc ? a.links.count < b.links.count : a.links.count > b.links.count
            case .updated: return asc ? a.updated < b.updated : a.updated > b.updated
            }
        }

        // **直近に書き換えたものは、どの並び順でも先頭に出す。**
        // 並び替えは「探すため」、先頭固定は「今さわったものを見失わないため」で
        // 目的が違うので、並びの規則には混ぜずに後から引き上げる。
        guard let id = lastTouched,
              let i = sorted.firstIndex(where: { $0.id == id }) else { return sorted }
        var r = sorted
        r.insert(r.remove(at: i), at: 0)
        return r
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
        // **単に開いて見ただけは「更新」ではない。** 書き換えたときだけ動く。
        // 何を変えても（進捗・ログ・リンク・重要度・名前・タグ）先頭へ来る。
        lastTouched = id
        flashID = id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if flashID == id { flashID = nil }
        }
        scheduleSave()
    }

    func setType(_ id: String, _ v: String) {
        mutate(id) { $0.type = v }
        if !v.isEmpty { addTag(true, v) }
    }

    func setClient(_ id: String, _ v: String) {
        mutate(id) { $0.client = v }
        if !v.isEmpty { addTag(false, v) }
    }

    // MARK: タグ登記簿

    /// 候補＝登録済みタグ ∪ 実際に使われている値
    func pool(_ key: KeyPath<Case, String>) -> [String] {
        let inUse = Set(cases.map { $0[keyPath: key] }.filter { !$0.isEmpty })
        let registered = Set(key == \Case.type ? tags.type : tags.client)
        return registered.union(inUse).sorted()
    }

    func addTag(_ isType: Bool, _ value: String) {
        let v = value.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        if isType { if !tags.type.contains(v) { tags.type.append(v) } }
        else      { if !tags.client.contains(v) { tags.client.append(v) } }
        scheduleSave()
    }

    /// タグを消すときは、それを使っている案件からも外す
    func removeTag(_ isType: Bool, _ value: String) {
        if isType {
            tags.type.removeAll { $0 == value }
            for i in cases.indices where cases[i].type == value { cases[i].type = "" }
            if typeFilter == value { typeFilter = nil }
        } else {
            tags.client.removeAll { $0 == value }
            for i in cases.indices where cases[i].client == value { cases[i].client = "" }
            if clientFilter == value { clientFilter = nil }
        }
        scheduleSave()
    }

    func usage(_ isType: Bool, _ value: String) -> Int {
        cases.filter { (isType ? $0.type : $0.client) == value }.count
    }

    /// 一覧の「詳細」から開く完全表示。sheet(item:) 用
    var detailModal: Case?
    /// リンク追加のシート
    var addLinkSheet: Case?

    /// 直近に書き換えた案件。**どの並び順でも一覧の先頭に固定する。**
    /// 次に別の案件を書き換えるまで居座る（＝すぐ元の位置へ戻らない）。
    var lastTouched: String?
    /// 更新確認の状態
    var updateState: UpdateState = .idle

    /// 光らせる対象。こちらは 1.5 秒で消える。
    /// 固定と別にしないと、光が消えた瞬間に行が元の位置へ跳ぶ。
    var flashID: String?

    /// 完成確認待ち。10 に到達したら即完了にはせず、必ず一度訊く
    var pendingFinish: Case?
    /// 削除確認待ち。**唯一の不可逆操作なので必ず一度訊く**
    var pendingDelete: Case?
    /// 完了アニメーション中。物理は位置を凍結し、画面のキーフレームに任せる
    var finishing: Set<String> = []

    // MARK: 一巡

    /// 進行中の一巡。ランプはこれを数えて点く
    var cycle = OpenCycle()
    /// 封をした一巡。**消さない**（理由は Cycle の説明）
    var cycles: [SealedCycle] = []

    /// 満了したら true
    @discardableResult
    private func cycleAdd(_ id: String) -> Bool {
        guard !cycle.caseIds.contains(id) else { return false }
        cycle.caseIds.append(id)
        return cycle.caseIds.count >= Cycle.size
    }

    /// 完了を取り消したら消灯し、この一巡からも外す。
    /// 残したままだと点の数と実際の完了数が合わなくなる。
    private func cycleRemove(_ id: String) {
        cycle.caseIds.removeAll { $0 == id }
    }

    /// **先に封をしてから訊く。** 順番を逆にすると、
    /// ダイアログを閉じ損ねただけでその一巡が消える。
    private func cycleComplete() {
        let sealed = SealedCycle(start: cycle.start, end: .now, caseIds: cycle.caseIds)
        cycles.append(sealed)
        cycle = OpenCycle()
        scheduleSave()
        pendingReport = sealed
    }

    /// 満了して「レポートを書き出すか」を訊いている一巡
    var pendingReport: SealedCycle?
    /// 書き出したあとの一言（保存先／失敗）。nil で何も出さない
    var reportResult: String?

    func setStep(_ id: String, _ n: Int) {
        guard let c = cases.first(where: { $0.id == id }) else { return }
        let next = (c.step == n) ? n - 1 : n

        // **10 に届いたら完了フロー。** ここがこの app で唯一の儀式的な瞬間
        if next >= 10 {
            pendingFinish = c
            return
        }
        let was = c.done
        mutate(id) { c in
            c.step = max(0, next)
            c.done = false
        }
        if was { cycleRemove(id) }
    }

    /// 確認後：気泡をランプの位置まで飛ばし、着いてから完了にする。
    /// 待ち時間は `Cycle.flyDuration` ＝ BubbleField のキーフレームと同じ長さ。
    func confirmFinish() {
        guard let target = pendingFinish else { return }
        pendingFinish = nil
        mutate(target.id) { $0.step = 10 }
        finishing.insert(target.id)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Cycle.flyDuration))
            if let i = cases.firstIndex(where: { $0.id == target.id }) {
                cases[i].done = true
            }
            finishing.remove(target.id)

            // **点が点くのは飛び終わってから。**
            // 先に点けると、気泡がまだ空中にいるのに着地点が埋まっていて、
            // 行き先が一つぶん左へずれる。
            let full = cycleAdd(target.id)
            scheduleSave()
            if full { cycleComplete() }
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

    func setMemo(_ id: String, _ text: String) {
        mutate(id) { $0.memo = text }
    }

    func delete(_ id: String) {
        cases.removeAll { $0.id == id }
        if selectedID == id { selectedID = nil }
        // 消したものを指したままにしない
        if lastTouched == id { lastTouched = nil }
        if flashID == id { flashID = nil }
        finishing.remove(id)
        scheduleSave()
    }

    @discardableResult
    func create(name: String, type: String, client: String) -> Case {
        let c = Case(name: name, type: type, client: client)
        cases.append(c)
        // 新しく入力されたタグは登記簿にも入れておく
        if !c.type.isEmpty { addTag(true, c.type) }
        if !c.client.isEmpty { addTag(false, c.client) }
        selectedID = c.id
        mode = .detail
        // **新規も「更新」として扱う。** これが無いと、並び順が
        // 最終更新以外のときに作った案件が一覧の途中に紛れて見失う
        lastTouched = c.id
        flashID = c.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if flashID == c.id { flashID = nil }
        }
        scheduleSave()
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
