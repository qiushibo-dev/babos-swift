import SwiftUI
import AppKit

/// 右上的詳細卡片。未選取時顯示「最後更新的案件」，
/// 所以這個 View 幾乎不會是空的。
struct DetailPanel: View {
    @Bindable var store: Store
    @State private var logDraft = ""
    @FocusState private var logFocused: Bool

    var body: some View {
        // 案件がゼロなら選びようがないので、常にフォームを出す
        if store.mode == .new || store.cases.isEmpty {
            NewCaseForm(store: store)
        } else if let c = store.current {
            // 見出しと削除ボタンは固定、中身だけスクロールさせる。
            // リンクが増えると縦に伸びるので、全体を固定高のまま積むと
            // 「この案件を削除」が枠外へ押し出される（実際そうなった）。
            // 余白は各ブロックの内側に持たせる。外側にまとめて掛けると、
            // スクロールバーがその余白の内側に出て文字の上に重なる。
            VStack(alignment: .leading, spacing: 0) {
                header(c).padding(.horizontal, 24)
                Divider().overlay(Color.hairline)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        stepper(c)
                        Divider().overlay(Color.hairline)
                        logs(c)
                        Divider().overlay(Color.hairline)
                        links(c)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollIndicators(.automatic)

                Divider().overlay(Color.hairline)
                footer(c).padding(.horizontal, 24)
            }
            .padding(.vertical, 24)
        }
    }

    // MARK: 表頭

    private func header(_ c: Case) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // 押すとその場で書き換わる
                InlineText(text: c.name,
                           font: Typo.body(26, .light),
                           color: .ink) { store.rename(c.id, $0) }

                Spacer()

                // 新規フォームへ。HTML 版と同じく × ひとつ
                Button {
                    store.mode = .new
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.mist)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(Color.slateBody, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // タイプとクライアントもその場で編集。既存のタグから候補を出す
            HStack(spacing: 8) {
                InlineText(text: c.type,
                           placeholder: "＋ \(store.t.fieldType)",
                           font: Typo.mono(11), color: .mist,
                           suggestions: store.pool(\.type)) {
                    store.setType(c.id, $0)
                }
                Text("／").metaStyle()

                InlineText(text: c.client,
                           placeholder: "＋ \(store.t.fieldClient)",
                           font: Typo.mono(11), color: .mist,
                           suggestions: store.pool(\.client)) {
                    store.setClient(c.id, $0)
                }
                Text("／").metaStyle()

                sub(c.created.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                Text("／").metaStyle()
                sub(c.updated.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute()))

                Spacer(minLength: 0)
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
                                    n == c.step + 1 ? Color.ink : Color.slateBody,
                                    lineWidth: 1))
                                .frame(width: 22, height: 22)
                            if n <= c.step {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color.onAccent)
                            } else {
                                Text("\(n)")
                                    .font(Typo.mono(10))
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
            Text(store.t.worklog).metaStyle()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if c.logs.isEmpty {
                        Text(store.t.noLogs)
                            .font(Typo.body(12))
                            .foregroundStyle(Color.fog)
                    } else {
                        ForEach(c.logs.sorted { $0.ts > $1.ts }) { l in
                            HStack(alignment: .top, spacing: 12) {
                                // fixedSize が無いと「08/14」と「18:53」が
                                // 泣き別れになる
                                Text(l.ts.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute()))
                                    .metaStyle(10)
                                    .fixedSize()
                                    .frame(width: 92, alignment: .leading)
                                Text(l.text)
                                    .font(Typo.body(12.5))
                                    .foregroundStyle(Color.ink.opacity(0.88))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    store.removeLog(c.id, l.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .medium))
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

            // ヒントは placeholder に混ぜず右端に置く。混ぜるとボタンに見える
            HStack(spacing: 12) {
                TextField(store.t.phLog, text: $logDraft)
                    .textFieldStyle(.plain)
                    .font(Typo.body(12.5))
                    .foregroundStyle(Color.ink)
                    .focused($logFocused)
                    .onSubmit {
                        store.addLog(c.id, logDraft)
                        logDraft = ""
                        logFocused = true      // 連続で書けるようにフォーカスを戻す
                    }

                Text(store.t.phLog.isEmpty ? "" : "Enter")
                    .metaStyle(9)
                    .fixedSize()
                    .opacity(logDraft.isEmpty ? 0.45 : 1)
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
            Text(store.t.links).metaStyle()

            ForEach(c.links) { l in
                HStack(spacing: 10) {
                    Text(l.type.rawValue.uppercased())
                        .metaStyle(9)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))

                    // 押したら開く。file:// もそのまま通る


                    Button {


                        if let u = URL(string: l.url) { NSWorkspace.shared.open(u) }


                    } label: {


                        Text(l.url)
                            .font(Typo.body(12))
                            .foregroundStyle(Color.mist)
                            .lineLimit(1)
                            .truncationMode(.middle)


                            .underline(false)


                    }


                    .buttonStyle(.plain)



                    Spacer()

                    Button {
                        store.removeLink(c.id, l.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Color.fog)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 空の https:// をいきなり足すのではなく、種類と URL を訊く
            Button {
                store.addLinkSheet = c
            } label: {
                Text(store.t.addLink)
                    .font(Typo.body(12))
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
                // 直接消さず一度訊く
                store.pendingDelete = c
            } label: {
                Text(store.t.deleteCase)
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

// MARK: - 新規案件フォーム

/// **別ウィンドウにしない。** 詳細カードと同じ場所に出す。
/// 作った案件がそのまま左に気泡として現れる、という繋がりが見えなくなるため。
struct NewCaseForm: View {
    @Bindable var store: Store

    @State private var name = ""
    @State private var type = ""
    @State private var client = ""
    @FocusState private var nameFocused: Bool

    private var canGoBack: Bool { !store.cases.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t.newCase)
                        .font(Typo.body(26, .light))
                        .foregroundStyle(Color.ink)
                    Text(canGoBack
                         ? "作成すると、この案件が左側に気泡として現れます。"
                         : "まずは1件目を登録してください。")
                        .metaStyle()
                }

                Spacer()

                if canGoBack {
                    Button {
                        store.mode = .detail
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.mist)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().strokeBorder(Color.slateBody, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 26)

            field(store.t.fieldName, store.t.phName, $name).focused($nameFocused)
            field(store.t.fieldType, store.t.phType, $type)
            field(store.t.fieldClient, store.t.phClient, $client)

            // 「Enter で作成」の一文は置かない。
            // 同じことをボタンが言っているうえ、Enter で送れるのは慣習として
            // 自明。HTML 版には両方あったが、そのまま持ってきたら重複が目立った。
            HStack {
                Spacer()
                Button(action: submit) {
                    Text(store.t.create)
                        .font(Typo.body(13))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.signalBlue))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .padding(24)
        .onAppear { nameFocused = true }
    }

    private func field(_ label: String, _ ph: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).metaStyle(10)
            TextField(ph, text: text)
                .textFieldStyle(.plain)
                .font(Typo.body(13))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))
                .onSubmit(submit)
        }
        .padding(.bottom, 18)
    }

    private func submit() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            nameFocused = true
            return
        }
        store.create(name: name, type: type, client: client)
        name = ""; type = ""; client = ""
    }
}
