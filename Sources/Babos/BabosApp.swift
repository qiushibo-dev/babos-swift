import SwiftUI

@main
struct BabosApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup("Babos") {
            ContentView(store: store)
                .onAppear { Typo.report() }
                .frame(minWidth: 1080, minHeight: 640)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
    }
}

struct ContentView: View {
    @Bindable var store: Store
    @State private var settingsOpen = false
    @State private var idle = IdleWatcher()

    var body: some View {
        Group {
            if idle.saverOn {
                ScreenSaver(store: store)
            } else {
                main
            }
        }
        .background(Color.midnightInk)
        // Color は observable ではないので、主題を変えたら木ごと作り直す
        .id(store.theme)
        .onAppear {
            store.load()

            store.watchTermination()
            idle.limit = store.saverMinutes
            idle.start()
        }
        .onChange(of: store.saverMinutes) { _, m in idle.limit = m }
        .sheet(isPresented: $settingsOpen) { SettingsSheet(store: store) }
        .sheet(item: $store.detailModal) { c in CaseDetailSheet(store: store, caseID: c.id) }
        .sheet(item: $store.addLinkSheet) { c in AddLinkSheet(store: store, caseID: c.id) }
        // 確認・通知はすべて自前のダイアログで出す（OS の .alert は使わない）。
        // 理由は AskDialog.swift の頭に書いた
        .overlay {
            if let req = store.ask {
                AskDialog(request: req, t: store.t) { store.ask = nil }
            }
        }
        .animation(.easeOut(duration: 0.12), value: store.ask?.id)

        // 削除は唯一の不可逆操作。必ず一度訊く
        .onChange(of: store.pendingDelete?.id) { _, _ in
            guard let c = store.pendingDelete else { return }
            store.pendingDelete = nil
            store.confirm(store.t.confirmDelete(c.name), ok: store.t.deleteCase) {
                store.delete(c.id)
            }
        }

        // 10 に到達しても即完了にはしない。必ず一度訊く
        .onChange(of: store.pendingFinish?.id) { _, _ in
            guard let c = store.pendingFinish else { return }
            // **先に nil へ戻してから訊く。** 順番も、対象を渡すことも、
            // 上の削除・下のレポートと必ず揃える
            store.pendingFinish = nil
            store.confirm(store.t.confirmFinish(c.name), ok: store.t.done) {
                store.confirmFinish(c)
            }
        }

        // 一巡（20 件）が満了したとき。**書き出しに成功した時だけ、その 20 件を消す。**
        // 「あとで」を押した場合は案件も一巡の記録も残る
        .onChange(of: store.pendingReport?.id) { _, _ in
            guard let c = store.pendingReport else { return }
            store.pendingReport = nil
            store.confirm(store.t.cycleFull(Cycle.size), ok: store.t.exportReport) {
                // ダイアログが閉じきってからパネルを出す。
                // 同じ拍で出すと、どちらも前面を取れずに固まることがある
                Task { @MainActor in
                    if store.exportReport(c) { store.purgeCycleCases(c) }
                }
            }
        }
    }

    private var main: some View {
        VStack(spacing: 0) {
            TopBar(store: store, settingsOpen: $settingsOpen)
            Divider().overlay(Color.hairline)

            // 上半：気泡区（可変）｜詳細（固定幅）
            HStack(spacing: 0) {
                BubbleField(store: store)
                    .frame(maxWidth: .infinity)

                Divider().overlay(Color.hairline)

                DetailPanel(store: store)
                    .frame(width: 470)
            }
            .frame(height: 520)

            Divider().overlay(Color.hairline)

            // 下半：サイドバー（固定幅）｜一覧
            HStack(spacing: 0) {
                Sidebar(store: store)
                    .frame(width: 220)

                Divider().overlay(Color.hairline)

                CaseList(store: store)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - 無操作の監視

/// 一定時間さわらなければスクリーンセーバーへ。
/// **アプリが前面に無いときは数えない**——裏で勝手に入っても意味がないし、
/// 戻ってきた瞬間に画面が変わっていて驚くだけ（HTML 版で入れた対策）。
@MainActor
@Observable
final class IdleWatcher {
    var saverOn = false
    /// 分。0 でオフ
    var limit = 5

    @ObservationIgnored private var seconds = 0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var monitor: Any?

    func start() {
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .keyDown, .scrollWheel, .leftMouseDown, .rightMouseDown]
        ) { [weak self] e in
            MainActor.assumeIsolated { self?.reset() }
            return e
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.limit > 0 else { return }
                guard NSApp.isActive else { self.seconds = 0; return }
                self.seconds += 1
                if self.seconds >= self.limit * 60 { self.saverOn = true }
            }
        }
    }

    func reset() {
        seconds = 0
        if saverOn { saverOn = false }
    }
}

// MARK: - 上部バー

struct TopBar: View {
    @Bindable var store: Store
    @Binding var settingsOpen: Bool

    var body: some View {
        HStack(spacing: 16) {
            Button { settingsOpen = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.mist)
            }
            .buttonStyle(.plain)

            TextField(store.t.searchPh, text: $store.query)
                .textFieldStyle(.plain)
                .font(Typo.body(13))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))
                .frame(width: 320)

            Spacer()

            Button {
                store.mode = .new
            } label: {
                Text(store.t.newCaseBtn)
                    .font(Typo.body(13))
                    .foregroundStyle(Color.onAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.signalBlue))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - デモデータは Persistence.swift の samples() に統合済み
