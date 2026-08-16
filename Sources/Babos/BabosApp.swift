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
        // 削除は唯一の不可逆操作。必ず一度訊く

        .alert(store.pendingDelete.map { store.t.confirmDelete($0.name) } ?? "",

               isPresented: .init(get: { store.pendingDelete != nil },

                                  set: { if !$0 { store.pendingDelete = nil } })) {

            Button(store.t.cancel, role: .cancel) { store.pendingDelete = nil }

            Button(store.t.deleteCase, role: .destructive) {

                if let c = store.pendingDelete { store.delete(c.id) }

                store.pendingDelete = nil

            }

        }

        // 10 に到達しても即完了にはしない。必ず一度訊く
        .alert(store.pendingFinish.map { store.t.confirmFinish($0.name) } ?? "",
               isPresented: .init(get: { store.pendingFinish != nil },
                                  set: { if !$0 { store.pendingFinish = nil } })) {
            Button(store.t.cancel, role: .cancel) { store.pendingFinish = nil }
            Button(store.t.done) { store.confirmFinish() }
        }

        // 一巡（20 件）が満了したとき。**書き出さなくても一巡は封をして残る**ので、
        // ここで「あとで」を押しても記録は失われない
        .alert(store.t.cycleFull(Cycle.size),
               isPresented: .init(get: { store.pendingReport != nil },
                                  set: { if !$0 { store.pendingReport = nil } })) {
            Button(store.t.skipReport, role: .cancel) { store.pendingReport = nil }
            Button(store.t.exportReport) {
                let c = store.pendingReport
                store.pendingReport = nil
                // alert が閉じきってからパネルを出す。
                // 同じ拍で出すと、どちらも前面を取れずに固まることがある
                if let c { Task { @MainActor in store.exportReport(c) } }
            }
        }

        // 書き出しの結果。保存先を出さないと、どこへ行ったのか分からない
        .alert(store.reportResult ?? "",
               isPresented: .init(get: { store.reportResult != nil },
                                  set: { if !$0 { store.reportResult = nil } })) {
            Button(store.t.close) { store.reportResult = nil }
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
