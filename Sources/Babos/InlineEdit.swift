import SwiftUI

/// その場で書き換えるテキスト。押すと入力欄になり、Enter か外れると確定、Esc で取消。
///
/// **画面を作り直さずに編集する。** HTML 版でも「編集中は renderAll を呼ばない」
/// と注記していたのと同じ理由——作り直すと入力欄ごと消える。
struct InlineText: View {
    let text: String
    var placeholder: String = ""
    var font: Font = Typo.body(13)
    var color: Color = .ink
    /// 候補。空なら補完しない
    var suggestions: [String] = []
    let commit: (String) -> Void

    @State private var editing = false
    @State private var draft = ""
    @State private var highlighted = -1
    @FocusState private var focused: Bool

    private var matches: [String] {
        let q = draft.trimmingCharacters(in: .whitespaces).lowercased()
        return suggestions.filter {
            $0.lowercased().contains(q) && $0.lowercased() != q
        }
    }

    var body: some View {
        if editing {
            field
        } else {
            Text(text.isEmpty ? placeholder : text)
                .font(font)
                .foregroundStyle(text.isEmpty ? Color.fog : color)
                .contentShape(Rectangle())
                .onTapGesture {
                    draft = text
                    highlighted = -1
                    editing = true
                    focused = true
                }
        }
    }

    private var field: some View {
        TextField("", text: $draft)
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(color)
            .focused($focused)
            .onSubmit { finish(save: true) }
            .onExitCommand { finish(save: false) }          // Esc
            .onChange(of: focused) { _, has in
                // 外れたら確定。押し間違えて消えるより残るほうがまし
                if !has { finish(save: true) }
            }
            .onKeyPress(.downArrow) { move(1) }
            .onKeyPress(.upArrow)   { move(-1) }
            .overlay(alignment: .topLeading) { popup }
    }

    @ViewBuilder
    private var popup: some View {
        if !matches.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(matches.prefix(6).enumerated()), id: \.offset) { i, s in
                    Text(s)
                        .font(Typo.body(12))
                        .foregroundStyle(i == highlighted ? Color.onAccent : Color.mist)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(i == highlighted ? Color.signalBlue : .clear)
                        .contentShape(Rectangle())
                        // TextField からフォーカスが外れる前に拾う
                        .onTapGesture { draft = s; finish(save: true) }
                }
            }
            .frame(width: 200)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.midnightInk))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.slateBody, lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
            .offset(y: 24)
            .zIndex(10)
        }
    }

    private func move(_ d: Int) -> KeyPress.Result {
        guard !matches.isEmpty else { return .ignored }
        highlighted = max(-1, min(matches.count - 1, highlighted + d))
        if highlighted >= 0 { draft = matches[highlighted] }
        return .handled
    }

    private func finish(save: Bool) {
        guard editing else { return }
        editing = false
        highlighted = -1
        let v = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if save, v != text { commit(v) }
    }
}

// MARK: - リンク追加

struct AddLinkSheet: View {
    @Bindable var store: Store
    let caseID: String
    @Environment(\.dismiss) private var dismiss

    @State private var kind: Link.Kind = .url
    @State private var url = ""
    @FocusState private var urlFocused: Bool

    private var t: L { store.t }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(t.addLinkTitle)
                .font(Typo.body(20, .light))
                .foregroundStyle(Color.ink)

            VStack(alignment: .leading, spacing: 7) {
                Text(t.linkType).metaStyle(10)
                HStack(spacing: 8) {
                    ForEach(Link.Kind.allCases, id: \.self) { k in
                        Button { kind = k } label: {
                            Text(k.rawValue)
                                .font(Typo.body(12))
                                .foregroundStyle(kind == k ? Color.onAccent : Color.mist)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(kind == k ? Color.signalBlue : .clear))
                                .overlay(Capsule().strokeBorder(
                                    kind == k ? .clear : Color.slateBody, lineWidth: 1))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(t.linkPath).metaStyle(10)
                TextField(t.phUrl, text: $url)
                    .textFieldStyle(.plain)
                    .font(Typo.body(13))
                    .foregroundStyle(Color.ink)
                    .focused($urlFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))
                    .onSubmit(submit)
            }

            HStack {
                Spacer()
                Button(t.cancel) { dismiss() }
                    .buttonStyle(.plain)
                    .font(Typo.body(12))
                    .foregroundStyle(Color.mist)
                Button(action: submit) {
                    Text(t.add)
                        .font(Typo.body(13))
                        .foregroundStyle(Color.onAccent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.signalBlue))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .frame(width: 460)
        .background(Color.midnightInk)
        .onAppear { urlFocused = true }
    }

    private func submit() {
        let v = url.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { urlFocused = true; return }
        store.addLink(caseID, Link(type: kind, url: v))
        dismiss()
    }
}
