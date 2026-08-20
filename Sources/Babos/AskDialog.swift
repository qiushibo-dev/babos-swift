import SwiftUI

/// 自前の確認ダイアログ。**SwiftUI の .alert には戻らない。**
///
/// 理由は二つ。
/// ① `.alert` は OS の見た目で出るので、配色もフォントもアプリから浮く。
///    ここは Sheets と同じトークン（Color.midnightInk / .ink / .slateBody）で描くので、
///    ameba と mono の切り替えに自動でついてくる。
/// ② `role: .destructive` は macOS では赤字になる。本人が赤は要らないと言ったので、
///    実行ボタンは削除でも通常の accent のまま。
///
/// HTML 版の ask() と同じ形にしてある（確認・通知の二種類、Esc で取消、Enter で実行）。

/// 出すときに積む一件ぶん。`alert` が真なら通知（ボタン一つ、押しても何も起きない）
struct AskRequest: Identifiable {
    let id = UUID()
    let message: String
    /// 実行ボタンの文言。nil なら「OK / 確定」
    var okLabel: String?
    /// 通知用。ボタンは一つだけになる
    var alert: Bool = false
    var onConfirm: () -> Void = {}
}

struct AskDialog: View {
    let request: AskRequest
    let t: L
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            // 背後を暗くする。押したら取消 —— HTML 版と同じ挙動
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { if !request.alert { dismiss() } }

            VStack(alignment: .leading, spacing: 0) {
                Text(request.message)
                    .font(Typo.body(14))
                    .foregroundStyle(Color.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Spacer()
                    if !request.alert {
                        Button(action: dismiss) {
                            Text(t.cancel)
                                .font(Typo.body(13))
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 18)
                                .frame(height: 34)
                                .overlay(Capsule().stroke(Color.slateBody, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.cancelAction)
                    }
                    Button {
                        request.onConfirm()
                        dismiss()
                    } label: {
                        Text(request.okLabel ?? t.confirmOk)
                            .font(Typo.body(13))
                            .foregroundStyle(Color.onAccent)
                            .padding(.horizontal, 18)
                            .frame(height: 34)
                            .background(Capsule().fill(Color.signalBlue))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 22)
            }
            .padding(24)
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.midnightInk)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.slateBody, lineWidth: 1))
            )
        }
        .transition(.opacity)
    }
}
