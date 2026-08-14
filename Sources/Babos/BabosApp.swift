import SwiftUI

@main
struct BabosApp: App {
    var body: some Scene {
        WindowGroup("Babos") {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct ContentView: View {
    /// 第一階段用假資料，先驗證物理與質感。
    /// 讀寫 work-tracker.json 是下一步。
    @State private var cases: [Case] = [
        .init(id: "1",  name: "Acme LP リニューアル", type: "LP",       client: "Acme",   step: 6),
        .init(id: "2",  name: "採用パンフレット",     type: "Print",    client: "Acme",   step: 3),
        .init(id: "3",  name: "LinkedIn 広告 8月分",  type: "LinkedIn", client: "Bridge", step: 9),
        .init(id: "4",  name: "ブランドガイドライン", type: "Brand",    client: "Bridge", step: 5),
        .init(id: "5",  name: "展示会バナー",         type: "Banner",   client: "Corvus", step: 2),
        .init(id: "6",  name: "サービス紹介動画",     type: "Video",    client: "Corvus", step: 8),
        .init(id: "7",  name: "ロゴリファイン",       type: "Logo",     client: "Delta",  step: 4),
        .init(id: "8",  name: "パッケージ改訂",       type: "Package",  client: "Delta",  step: 7),
        .init(id: "9",  name: "メールテンプレート",   type: "Email",    client: "Acme",   step: 1),
        .init(id: "10", name: "月次レポート表紙",     type: "Print",    client: "Bridge", step: 10),
    ]
    @State private var selectedID: String?

    var body: some View {
        VStack(spacing: 0) {
            BubbleField(cases: cases, selectedID: $selectedID)

            // 進度節點。點下去左邊的氣泡要立刻改變大小與濃淡——
            // 這是操作不是顯示，本家 SPEC 特別強調過
            if let id = selectedID,
               let i = cases.firstIndex(where: { $0.id == id }) {
                stepper(for: i)
            }
        }
        .background(Color.midnightInk)
        .preferredColorScheme(.dark)
    }

    private func stepper(for i: Int) -> some View {
        HStack(spacing: 14) {
            Text(cases[i].name)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 6) {
                ForEach(1...10, id: \.self) { n in
                    Button {
                        // 再點一次目前的節點就退回上一格
                        cases[i].step = (cases[i].step == n) ? n - 1 : n
                    } label: {
                        Circle()
                            .fill(n <= cases[i].step ? Color.arcCyan.opacity(0.9)
                                                     : Color.white.opacity(0.12))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("\(cases[i].step) / 10")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color.black.opacity(0.25))
    }
}
