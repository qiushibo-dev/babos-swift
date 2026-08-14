import SwiftUI

@main
struct BabosApp: App {
    @State private var store = Store.demo()

    var body: some Scene {
        WindowGroup("Babos") {
            ContentView(store: store)
                .frame(minWidth: 1080, minHeight: 640)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
    }
}

struct ContentView: View {
    @Bindable var store: Store
    @State private var newCaseSheet = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(store: store, newCaseSheet: $newCaseSheet)
            Divider().overlay(Color.hairline)

            // 上半：気泡区（可変）｜詳細（固定幅）
            HStack(spacing: 0) {
                BubbleField(cases: store.bubbleCases, selectedID: $store.selectedID)
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
        .background(Color.midnightInk)
        .sheet(isPresented: $newCaseSheet) {
            NewCaseSheet(store: store, presented: $newCaseSheet)
        }
    }
}

// MARK: - 上部バー

struct TopBar: View {
    @Bindable var store: Store
    @Binding var newCaseSheet: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "gearshape")
                .font(.system(size: 15))
                .foregroundStyle(Color.mist)

            TextField("案件を検索…", text: $store.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))
                .frame(width: 320)

            Spacer()

            Button {
                newCaseSheet = true
            } label: {
                Text("＋ 新規案件")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
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

// MARK: - 新規案件

struct NewCaseSheet: View {
    @Bindable var store: Store
    @Binding var presented: Bool

    @State private var name = ""
    @State private var type = ""
    @State private var client = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("新規案件")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white)

            field("案件名", "例：A社 LP", $name).focused($nameFocused)
            field("案件タイプ", "例：LinkedIn ／ 印刷物", $type)
            field("クライアント", "例：A社 ／ 社内", $client)

            HStack {
                Text("Enter で作成").metaStyle(10)
                Spacer()
                Button("キャンセル") { presented = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.mist)
                Button {
                    submit()
                } label: {
                    Text("作成")
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.signalBlue))
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 12))
        }
        .padding(28)
        .frame(width: 420)
        .background(Color.midnightInk)
        .onAppear { nameFocused = true }
    }

    private func field(_ label: String, _ ph: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).metaStyle(10)
            TextField(ph, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))
                .onSubmit { submit() }
        }
    }

    private func submit() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.create(name: name, type: type, client: client)
        presented = false
    }
}

// MARK: - デモデータ

extension Store {
    /// 保存はまだ実装していないので、起動ごとにこれが入る。
    /// work-tracker.json の読み書きは次の段階。
    static func demo() -> Store {
        let s = Store()
        let rows: [(String, String, String, Int, Int)] = [
            ("Acme LP リニューアル", "LP", "Acme", 6, 4),
            ("採用パンフレット", "Print", "Acme", 3, 3),
            ("LinkedIn 広告 8月分", "LinkedIn", "Bridge", 9, 2),
            ("ブランドガイドライン", "Brand", "Bridge", 5, 5),
            ("展示会バナー", "Banner", "Corvus", 2, 1),
            ("サービス紹介動画", "Video", "Corvus", 8, 3),
            ("ロゴリファイン", "Logo", "Delta", 4, 4),
            ("パッケージ改訂", "Package", "Delta", 7, 2),
            ("メールテンプレート", "Email", "Acme", 1, 1),
            ("月次レポート表紙", "Print", "Bridge", 10, 0),
        ]
        s.cases = rows.enumerated().map { i, r in
            var c = Case(name: r.0, type: r.1, client: r.2, step: r.3)
            c.priority = r.4
            c.created = .now.addingTimeInterval(Double(-(i + 3) * 86_400))
            c.updated = .now.addingTimeInterval(Double(-i * 5_400))
            c.waiting = (i == 8)
            if i < 4 {
                c.logs = [LogEntry(ts: .now.addingTimeInterval(Double(-i * 7_200)),
                                   text: "初稿を共有、フィードバック待ち")]
            }
            if i < 3 {
                c.links = [Link(type: .figma, url: "https://figma.com/file/demo")]
            }
            return c
        }
        return s
    }
}
