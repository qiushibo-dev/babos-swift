import SwiftUI

/// 無操作が続いたときの画面。**気泡と時計だけ。**
///
/// HTML 版はここでウィンドウを本物のフルスクリーンにしようとして
/// `setFullscreen` を3回試し3回とも落ちた。ネイティブなら素直に
/// ウィンドウいっぱいに広げるだけで済む——WebView を経由しないので
/// あの問題は最初から存在しない。
struct ScreenSaver: View {
    @Bindable var store: Store
    @State private var now = Date.now

    var body: some View {
        ZStack {
            // セーバー中は減衰を緩めてゆっくり漂わせる
            BubbleField(store: store, relaxed: true)

            VStack(spacing: 4) {
                Text(now.formatted(.dateTime.hour().minute()))
                    .font(Typo.mono(15))
                    .foregroundStyle(Color.mist)
                Text("\(store.aliveCount)\(store.t.saverCases)")
                    .metaStyle(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(28)
            .opacity(0.5)
        }
        .background(Color.midnightInk)
        .task {
            while !Task.isCancelled {
                now = .now
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }
}
