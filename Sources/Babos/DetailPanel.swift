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

    /// どの欄に入っているか。候補はフォーカスのある欄にだけ出す。
    /// 三つ同時に開くと下の欄が隠れて、何を入力しているのか見えなくなる。
    private enum Field { case name, type, client }
    @FocusState private var focus: Field?

    /// 候補の選択位置。同時に開くのは一欄だけなので、状態も一つで足りる
    @State private var highlighted = -1

    private var canGoBack: Bool { !store.cases.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t.newCase)
                        .font(Typo.body(26, .light))
                        .foregroundStyle(Color.ink)
                    // **べた書きしないこと。** 三言語ぶん Strings.swift に用意してある。
                    // ここだけ日本語が固定で残っていて、中国語表示でも和文が出ていた
                    Text(canGoBack ? store.t.newCaseHint : store.t.newCaseHintFirst)
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

            // 種別と客先は登記簿から候補を出す。詳細パネルの InlineText と同じ pool
            field(store.t.fieldName, store.t.phName, $name, .name)
            field(store.t.fieldType, store.t.phType, $type, .type,
                  suggestions: store.pool(\.type))
            field(store.t.fieldClient, store.t.phClient, $client, .client,
                  suggestions: store.pool(\.client))

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
        .onAppear { focus = .name }
        // 欄を移ったら選択位置は捨てる。持ち越すと次の欄で違う項目が光る
        .onChange(of: focus) { _, _ in highlighted = -1 }
    }

    /// 候補＝入力中の文字を含むもの。完全一致は出さない（選んでも何も変わらないので）
    private func matches(_ text: String, _ pool: [String]) -> [String] {
        let q = text.trimmingCharacters(in: .whitespaces).lowercased()
        let hit = pool.filter { $0.lowercased().contains(q) && $0.lowercased() != q }
        // **前方一致を先に出す。** 一文字だけ打った時、頭で合うものが
        // 「含むだけ」のものより下に埋もれると、候補が出ていても見つけられない。
        // 例：L で LinkedIn より Personal（末尾の l）が先に来ていた。
        return hit.sorted { a, b in
            let pa = a.lowercased().hasPrefix(q), pb = b.lowercased().hasPrefix(q)
            if pa != pb { return pa }
            return a < b
        }
    }

    private func field(_ label: String, _ ph: String, _ text: Binding<String>,
                       _ which: Field, suggestions: [String] = []) -> some View {
        let hits = focus == which
            ? Array(matches(text.wrappedValue, suggestions).prefix(6))
            : []

        return VStack(alignment: .leading, spacing: 7) {
            Text(label).metaStyle(10)
            TextField(ph, text: text)
                .textFieldStyle(.plain)
                .font(Typo.body(13))
                .foregroundStyle(Color.ink)
                .focused($focus, equals: which)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))
                .onSubmit {
                    // 候補を選んでいる最中の Enter は「その候補で決定」。
                    // ここで submit まで走らせると、確かめる間もなく案件ができる
                    if highlighted >= 0 { highlighted = -1 } else { submit() }
                }
                .onKeyPress(.downArrow) { move(1, hits, text) }
                .onKeyPress(.upArrow)   { move(-1, hits, text) }
                // **入力欄に掛けること。** VStack に掛けるとラベルぶん上にずれる
                .overlay(alignment: .topLeading) { popup(hits, text) }
        }
        .padding(.bottom, 18)
        // 開いている欄を最前面に。でないと下の欄の枠が候補の上に描かれる
        .zIndex(focus == which ? 10 : 0)
    }

    @ViewBuilder
    private func popup(_ hits: [String], _ text: Binding<String>) -> some View {
        if !hits.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(hits.enumerated()), id: \.offset) { i, s in
                    Text(s)
                        .font(Typo.body(12))
                        .foregroundStyle(i == highlighted ? Color.onAccent : Color.mist)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(i == highlighted ? Color.signalBlue : .clear)
                        .contentShape(Rectangle())
                        .onTapGesture { text.wrappedValue = s; highlighted = -1 }
                }
            }
            .frame(width: 220)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.midnightInk))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.slateBody, lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
            .offset(y: 44)
            .zIndex(10)
        }
    }

    private func move(_ d: Int, _ hits: [String], _ text: Binding<String>) -> KeyPress.Result {
        guard !hits.isEmpty else { return .ignored }
        highlighted = max(-1, min(hits.count - 1, highlighted + d))
        if highlighted >= 0 { text.wrappedValue = hits[highlighted] }
        return .handled
    }

    private func submit() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            focus = .name
            return
        }
        store.create(name: name, type: type, client: client)
        name = ""; type = ""; client = ""
        highlighted = -1
    }
}
