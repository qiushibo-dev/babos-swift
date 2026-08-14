import SwiftUI

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
                .font(.system(size: 22, weight: .light))
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
                            .font(.system(size: 11))
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

    private func segmented<T: Hashable & Identifiable>(
        _ items: [T], current: T,
        _ tap: @escaping (T) -> Void,
        label: @escaping (T) -> String
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                Button { tap(item) } label: {
                    Text(label(item))
                        .font(.system(size: 12))
                        .foregroundStyle(item == current ? Color.onAccent : Color.mist)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(item == current ? Color.signalBlue : .clear))
                        .overlay(Capsule().strokeBorder(
                            item == current ? .clear : Color.slateBody, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var saverPicker: some View {
        HStack(spacing: 8) {
            ForEach([0, 5, 15], id: \.self) { m in
                Button {
                    store.saverMinutes = m
                    store.scheduleSave()
                } label: {
                    Text(m == 0 ? t.ssOff : "\(m)\(t.minUnit)")
                        .font(.system(size: 12))
                        .foregroundStyle(store.saverMinutes == m ? Color.onAccent : Color.mist)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(store.saverMinutes == m ? Color.signalBlue : .clear))
                        .overlay(Capsule().strokeBorder(
                            store.saverMinutes == m ? .clear : Color.slateBody, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tagGroup(isType: Bool, title: String, draft: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).metaStyle(10)

            let pool = store.pool(isType ? \Case.type : \Case.client)
            if pool.isEmpty {
                Text(t.noTags).font(.system(size: 11)).foregroundStyle(Color.fog)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(pool, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Text(tag).font(.system(size: 11)).foregroundStyle(Color.ink)
                            Text("\(store.usage(isType, tag))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color.fog)
                            Button {
                                store.removeTag(isType, tag)
                            } label: {
                                Image(systemName: "xmark").font(.system(size: 7))
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
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))
                    .onSubmit { commitTag(isType, draft) }

                Button(t.tagAdd) { commitTag(isType, draft) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
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
            row(t.version, "0.0.1")
            row(t.author, "Shih-Bo Chiu")

            HStack(alignment: .top) {
                Text(t.storage).metaStyle(10).frame(width: 110, alignment: .leading)
                switch store.fileState {
                case .ok(let path):
                    Text(path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.mist)
                        .textSelection(.enabled)
                case .failed(let msg):
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.storageFailed)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                        Text(msg).font(.system(size: 10)).foregroundStyle(Color.fog)
                    }
                case .unknown:
                    Text(t.storagePending)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.fog)
                }
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).metaStyle(10).frame(width: 110, alignment: .leading)
            Text(v).font(.system(size: 12)).foregroundStyle(Color.mist)
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
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color.ink)
                Text([c.type, c.client, "\(c.step)/10"].filter { !$0.isEmpty }.joined(separator: " ／ "))
                    .metaStyle(10)
                    .padding(.top, 6)
                    .padding(.bottom, 20)

                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t.notes).metaStyle(10)
                        TextEditor(text: $memo)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.ink)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.slateBody, lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(t.fullLog).metaStyle(10)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                if c.logs.isEmpty {
                                    Text(t.noLogs).font(.system(size: 11))
                                        .foregroundStyle(Color.fog)
                                }
                                ForEach(c.logs.sorted { $0.ts > $1.ts }) { l in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(l.ts.formatted(.dateTime.month(.twoDigits)
                                            .day(.twoDigits).hour().minute()))
                                            .metaStyle(9)
                                        Text(l.text)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.ink.opacity(0.88))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(10)
                        }
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.slateBody, lineWidth: 1))
                    }
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
                .font(.system(size: 12))
                .padding(.top, 18)
            }
        }
        .padding(28)
        .frame(width: 760)
        .background(Color.midnightInk)
        .onAppear { memo = item?.memo ?? "" }
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
