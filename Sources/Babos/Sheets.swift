import SwiftUI
import AppKit

// MARK: - 設定

struct SettingsSheet: View {
    @Bindable var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var newType = ""
    @State private var newClient = ""

    private var t: L { store.t }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t.settings)
                .font(Typo.body(22, .light))
                .foregroundStyle(Color.ink)
                .padding(.bottom, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    section(t.language) {
                        segmented(Lang.allCases, current: store.lang) { l in
                            store.lang = l
                            store.scheduleSave()
                        } label: { $0.label }
                    }

                    section(t.theme) {
                        segmented(Theme.allCases, current: store.theme) { th in
                            store.theme = th
                            currentTheme = th        // 色の切り替えはここ
                            store.scheduleSave()
                        } label: { $0 == .ameba ? t.themeAmeba : t.themeMono }
                    }

                    section(t.screensaver) { saverPicker }

                    section(t.tagManagement) {
                        Text(t.tagHint)
                            .font(Typo.body(11))
                            .foregroundStyle(Color.fog)
                            .padding(.bottom, 10)
                        tagGroup(isType: true,  title: t.typeGroup,   draft: $newType)
                        tagGroup(isType: false, title: t.clientGroup, draft: $newClient)
                    }

                    section(t.about) { about }
                }
            }

            HStack {
                Spacer()
                Button(t.close) { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.mist)
                    .padding(.top, 18)
            }
        }
        .padding(28)
        .frame(width: 520, height: 620)
        .background(Color.midnightInk)
    }

    // MARK: 部品

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).metaStyle()
            content()
        }
    }

    /// **各ボタンを等分に伸ばす。** 文字幅なりに置くと、
    /// 言語（3つ・長い）と配色（2つ・短い）で右端が揃わない。
    private func segmented<T: Hashable & Identifiable>(
        _ items: [T], current: T,
        _ tap: @escaping (T) -> Void,
        label: @escaping (T) -> String
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                Button { tap(item) } label: {
                    Text(label(item))
                        .font(Typo.body(12))
                        .foregroundStyle(item == current ? Color.onAccent : Color.mist)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(item == current ? Color.signalBlue : .clear))
                        .overlay(Capsule().strokeBorder(
                            item == current ? .clear : Color.slateBody, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 0〜15 分の連続値。固定の3択ではなく、好きな長さに置けるように。
    private var saverPicker: some View {
        HStack(spacing: 14) {
            MinuteSlider(minutes: Binding(
                get: { store.saverMinutes },
                set: { store.saverMinutes = $0; store.scheduleSave() }))

            Text(store.saverMinutes == 0 ? t.ssOff : "\(store.saverMinutes)\(t.minUnit)")
                .font(Typo.mono(11))
                .foregroundStyle(Color.mist)
                .frame(width: 56, alignment: .trailing)
        }
    }

    private func tagGroup(isType: Bool, title: String, draft: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).metaStyle(10)

            let pool = store.pool(isType ? \Case.type : \Case.client)
            if pool.isEmpty {
                Text(t.noTags).font(Typo.body(11)).foregroundStyle(Color.fog)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(pool, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Text(tag).font(Typo.body(11)).foregroundStyle(Color.ink)
                            Text("\(store.usage(isType, tag))")
                                .font(Typo.mono(10))
                                .foregroundStyle(Color.fog)
                            Button {
                                store.removeTag(isType, tag)
                            } label: {
                                Image(systemName: "xmark").font(.system(size: 7, weight: .medium))
                                    .foregroundStyle(Color.fog)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(t.phTag, text: draft)
                    .textFieldStyle(.plain)
                    .font(Typo.body(12))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))
                    .onSubmit { commitTag(isType, draft) }

                Button(t.tagAdd) { commitTag(isType, draft) }
                    .buttonStyle(.plain)
                    .font(Typo.body(12))
                    .foregroundStyle(Color.mist)
            }
        }
        .padding(.bottom, 12)
    }

    private func commitTag(_ isType: Bool, _ draft: Binding<String>) {
        store.addTag(isType, draft.wrappedValue)
        draft.wrappedValue = ""
    }

    /// **保存状態はここに必ず出す。**
    /// 見えないところで失敗させないこと（HTML 版の教訓）。
    private var about: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 版本の行に更新確認を並べる
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(t.version).metaStyle(10).frame(width: 110, alignment: .leading)
                Text(store.appVersion)
                    .font(Typo.body(12))
                    .foregroundStyle(Color.mist)

                Button { Task { await store.checkUpdate() } } label: {
                    Text(t.checkUpdate)
                        .metaStyle(9)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(store.updateState == .checking)

                updateResult
                Spacer(minLength: 0)
            }

            row(t.author, "Shih-Bo Chiu")

            HStack(alignment: .top) {
                Text(t.storage).metaStyle(10).frame(width: 110, alignment: .leading)
                switch store.fileState {
                case .ok(let path):
                    Text(path)
                        .font(Typo.mono(10))
                        .foregroundStyle(Color.mist)
                        .textSelection(.enabled)
                case .failed(let msg):
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.storageFailed)
                            .font(Typo.body(11))
                            .foregroundStyle(.red)
                        Text(msg).font(Typo.body(10)).foregroundStyle(Color.fog)
                    }
                case .unknown:
                    Text(t.storagePending)
                        .font(Typo.body(11))
                        .foregroundStyle(Color.fog)
                }
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).metaStyle(10).frame(width: 110, alignment: .leading)
            Text(v).font(Typo.body(12)).foregroundStyle(Color.mist)
        }
    }

    /// 確認の結果。**失敗も必ず出す**——黙って何も起きないのが一番困る
    @ViewBuilder
    private var updateResult: some View {
        switch store.updateState {
        case .idle:
            EmptyView()
        case .checking:
            Text(t.verChecking).font(Typo.body(11)).foregroundStyle(Color.fog)
        case .latest:
            Text(t.verLatest).font(Typo.body(11)).foregroundStyle(Color.fog)
        case .available(let tag):
            VStack(alignment: .leading, spacing: 2) {
                Text(t.verNew(tag)).font(Typo.body(11)).foregroundStyle(Color.arcCyan)
                // 押すと Releases を開く
                Button {
                    if let u = URL(string: Store.releasesURL) { NSWorkspace.shared.open(u) }
                } label: {
                    Text(Store.releasesURL).metaStyle(9)
                }
                .buttonStyle(.plain)
            }
        case .failed(let msg):
            VStack(alignment: .leading, spacing: 2) {
                Text(t.verFailed).font(Typo.body(11)).foregroundStyle(.red)
                Text(msg).metaStyle(9)
            }
        }
    }
}

// MARK: - 案件の完全表示

/// 一覧の「詳細」から開く。左＝自由記述のメモ、右＝ログ全件（表示のみ）。
struct CaseDetailSheet: View {
    @Bindable var store: Store
    let caseID: String
    @Environment(\.dismiss) private var dismiss

    @State private var memo = ""
    @State private var savedFlash = false

    private var t: L { store.t }
    private var item: Case? { store.cases.first { $0.id == caseID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let c = item {
                Text(c.name)
                    .font(Typo.body(20, .light))
                    .foregroundStyle(Color.ink)
                Text([c.type, c.client, "\(c.step)/10"].filter { !$0.isEmpty }.joined(separator: " ／ "))
                    .metaStyle(10)
                    .padding(.top, 6)
                    .padding(.bottom, 20)

                // **等分は VStack 側に掛ける。**
                // 中の TextEditor / ScrollView に maxWidth を付けても効かない——
                // HStack が幅を配るときに見るのは VStack の固有幅で、
                // 左は TextEditor（無限に伸びたがる）、右は「No entries yet.」の
                // 一行ぶんしか主張しないため、左に全部持っていかれる。
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t.notes).metaStyle(10)
                        TextEditor(text: $memo)
                            .font(Typo.body(12.5))
                            .foregroundStyle(Color.ink)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.slateBody, lineWidth: 1))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(t.fullLog).metaStyle(10)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                if c.logs.isEmpty {
                                    Text(t.noLogs).font(Typo.body(11))
                                        .foregroundStyle(Color.fog)
                                }
                                ForEach(c.logs.sorted { $0.ts > $1.ts }) { l in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(l.ts.formatted(.dateTime.month(.twoDigits)
                                            .day(.twoDigits).hour().minute()))
                                            .metaStyle(9)
                                        Text(l.text)
                                            .font(Typo.body(12))
                                            .foregroundStyle(Color.ink.opacity(0.88))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(10)
                        }
                        // **内側にも要る。** 外の VStack だけ広げても、
                        // ScrollView 自体は中身の幅しか主張しないので
                        // 枠線が左に縮こまったままになる。
                        .frame(maxWidth: .infinity)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.slateBody, lineWidth: 1))
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 300)

                HStack {
                    if savedFlash {
                        Text(t.saved).metaStyle(10)
                    }
                    Spacer()
                    Button(t.close) { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.mist)
                    Button {
                        store.setMemo(caseID, memo)
                        savedFlash = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.6))
                            savedFlash = false
                        }
                    } label: {
                        Text(t.save)
                            .foregroundStyle(Color.onAccent)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.signalBlue))
                    }
                    .buttonStyle(.plain)
                }
                .font(Typo.body(12))
                .padding(.top, 18)
            }
        }
        .padding(28)
        .frame(width: 760)
        .background(Color.midnightInk)
        .onAppear { memo = item?.memo ?? "" }
    }
}

// MARK: - 分のスライダー

/// 0〜15 分。macOS 純正の Slider は見た目が浮くので自前で描く。
/// 掴んで動かすほか、軌道のどこかを押せばそこへ飛ぶ。
struct MinuteSlider: View {
    @Binding var minutes: Int
    private let maxMinutes = 15

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let ratio = Double(minutes) / Double(maxMinutes)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.slateBody.opacity(0.45))
                    .frame(height: 4)

                Capsule()
                    .fill(Color.signalBlue)
                    .frame(width: max(0, w * ratio), height: 4)

                Circle()
                    .fill(Color.ink)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    // 端でつまみが軌道からはみ出さないよう半径ぶん内側に寄せる
                    .offset(x: (w - 14) * ratio)
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let r = max(0, min(1, g.location.x / w))
                        minutes = Int((r * Double(maxMinutes)).rounded())
                    }
            )
        }
        .frame(height: 20)
    }
}

// MARK: - タグを折り返して並べる

/// SwiftUI に既製の flow レイアウトが無いので最小限だけ自作。
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
