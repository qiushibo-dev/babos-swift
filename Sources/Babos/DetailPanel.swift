import SwiftUI

/// 右上的詳細卡片。未選取時顯示「最後更新的案件」，
/// 所以這個 View 幾乎不會是空的。
struct DetailPanel: View {
    @Bindable var store: Store
    @State private var logDraft = ""
    @FocusState private var logFocused: Bool

    var body: some View {
        if let c = store.current {
            VStack(alignment: .leading, spacing: 0) {
                header(c)
                Divider().overlay(Color.hairline)
                stepper(c)
                Divider().overlay(Color.hairline)
                logs(c)
                Divider().overlay(Color.hairline)
                links(c)
                Spacer(minLength: 0)
                footer(c)
            }
            .padding(24)
        } else {
            VStack {
                Spacer()
                Text("案件がまだありません。")
                    .metaStyle(12)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: 表頭

    private func header(_ c: Case) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(c.name)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(spacing: 8) {
                sub(c.type.isEmpty ? "＋ タイプ" : c.type)
                Text("／").metaStyle()
                sub(c.client.isEmpty ? "＋ クライアント" : c.client)
                Text("／").metaStyle()
                sub(c.created.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                Text("／").metaStyle()
                sub(c.updated.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute()))
            }
        }
        .padding(.bottom, 18)
    }

    private func sub(_ s: String) -> some View {
        Text(s).metaStyle()
    }

    // MARK: 進捗

    /// **これは表示ではなく操作。** 押した瞬間に左の気泡が大きさと濃さを変える。
    private func stepper(_ c: Case) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("進捗　\(c.step) / 10")
                .metaStyle()

            HStack(spacing: 0) {
                ForEach(1...10, id: \.self) { n in
                    Button {
                        store.setStep(c.id, n)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(n <= c.step ? Color.signalBlue : .clear)
                                .overlay(Circle().strokeBorder(
                                    n == c.step + 1 ? Color.white : Color.slateBody,
                                    lineWidth: 1))
                                .frame(width: 22, height: 22)
                            if n <= c.step {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(n)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.mist)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if n < 10 {
                        Rectangle()
                            .fill(n < c.step ? Color.signalBlue : Color.slateBody)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.vertical, 18)
    }

    // MARK: 作業ログ

    /// **常駐一行入力欄がこの画面でいちばん重要な部品。**
    /// 開く・打つ・Enter の3動作以外を要求しないこと。
    private func logs(_ c: Case) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("作業ログ").metaStyle()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if c.logs.isEmpty {
                        Text("まだログがありません。")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.fog)
                    } else {
                        ForEach(c.logs.sorted { $0.ts > $1.ts }) { l in
                            HStack(alignment: .top, spacing: 12) {
                                Text(l.ts.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute()))
                                    .metaStyle(10)
                                    .frame(width: 76, alignment: .leading)
                                Text(l.text)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    store.removeLog(c.id, l.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8))
                                        .foregroundStyle(Color.fog)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 90, maxHeight: 200)

            TextField("ログを追加…　Enter で確定", text: $logDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(.white)
                .focused($logFocused)
                .onSubmit {
                    store.addLog(c.id, logDraft)
                    logDraft = ""
                    logFocused = true          // 連続で書けるようにフォーカスを戻す
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Capsule().strokeBorder(Color.slateBody, lineWidth: 1)
                )
        }
        .padding(.vertical, 18)
    }

    // MARK: リンク

    private func links(_ c: Case) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("リンク").metaStyle()

            ForEach(c.links) { l in
                HStack(spacing: 10) {
                    Text(l.type.rawValue.uppercased())
                        .metaStyle(9)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))

                    Text(l.url)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mist)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        store.removeLink(c.id, l.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.fog)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                store.addLink(c.id, Link(type: .url, url: "https://"))
            } label: {
                Text("＋ リンクを追加")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mist)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 18)
    }

    private func footer(_ c: Case) -> some View {
        HStack {
            Spacer()
            Button {
                store.delete(c.id)
            } label: {
                Text("この案件を削除")
                    .metaStyle(10)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .overlay(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }
}
