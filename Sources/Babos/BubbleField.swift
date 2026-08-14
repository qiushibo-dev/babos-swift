import SwiftUI

/// 氣泡區。這個 app 的招牌。
struct BubbleField: View {
    @Bindable var store: Store

    @State private var field = Field()
    /// 拖曳超過 5px 就不算點選，避免拖完順手選到別的案子
    @State private var dragMoved = false

    /// 完了アニメーション中の案件も、抜け終わるまでは描き続ける
    private var cases: [Case] {
        store.cases.filter { !$0.done || store.finishing.contains($0.id) }
            .filter { c in store.bubbleCases.contains { $0.id == c.id } || store.finishing.contains(c.id) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backdrop
                bubbles
            }
            .background { driver }        // 物理はここで駆動する
            .onChange(of: geo.size, initial: true) { _, new in
                field.bounds = new
                field.sync(cases)
            }
            .onChange(of: cases.map(\.step)) { _, _ in field.sync(cases) }
            .onChange(of: cases.map(\.id))   { _, _ in field.sync(cases) }
            .onChange(of: store.finishing)   { _, new in field.finishing = new }
        }
    }

    // MARK: 駆動

    /// **物理は画面の再描画と同じ拍で進める。**
    ///
    /// 最初は独立した Task で `Task.sleep(16ms)` を回していたが、あれは精度が悪く
    /// ずれていく。画面は vsync で描かれるので両者の刻みが噛み合わず、
    /// 「1フレームに2回進む／0回進む」が混ざって、気泡と文字が細かく震えて見えた。
    ///
    /// TimelineView(.animation) の date は vsync に同期しているので、
    /// その変化で tick すれば必ず1フレーム1回になる。
    /// 中身は Color.clear——描画には一切関与させない。
    private var driver: some View {
        TimelineView(.animation) { timeline in
            Color.clear
                .onChange(of: timeline.date) { _, _ in field.tick() }
        }
    }

    // MARK: 背景

    /// HTML 版は `radial-gradient(ellipse 70% 62% at 50% 48%, …74%)`。
    /// SwiftUI の RadialGradient は真円なので EllipticalGradient を使う。
    private var backdrop: some View {
        EllipticalGradient(
            colors: [.violetWash, .midnightInk],
            center: UnitPoint(x: 0.5, y: 0.48),
            startRadiusFraction: 0,
            endRadiusFraction: 0.74)
    }

    // MARK: 気泡

    private var bubbles: some View {
        ZStack(alignment: .topLeading) {
            ForEach(field.bodies, id: \.id) { b in
                if let c = cases.first(where: { $0.id == b.id }) {
                    bubble(c, b)
                }
            }
        }
    }

    private func bubble(_ c: Case, _ b: PhysicsBody) -> some View {
        let selected = store.selectedID == c.id
        let leaving = store.finishing.contains(c.id)
        let d = b.r * 2

        return Circle()
            .fill(Color.haloViolet.opacity(Encoding.opacity(c.progress)))
            .frame(width: d, height: d)
            // 選取時外圈一層青色暈，這是全場唯一的高彩度。
            // **drawingGroup は使わないこと。** 影ごと矩形のテクスチャに
            // 焼かれてしまい、円のまわりに四角い光の枠が出る。
            .shadow(color: selected ? Color.arcCyan.opacity(0.45) : .clear, radius: 18)
            .overlay {
                // 直徑夠大才顯示名稱，小氣泡放字只會糊掉
                if d >= 52 {
                    Text(c.name)
                        .font(.system(size: 9 + max(0, d - 42) * 0.034))
                        .foregroundStyle(Color.midnightInk)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: d * 0.82)
                }
            }
            .modifier(FloatAway(active: leaving))
            .position(x: b.x, y: b.y)
            .allowsHitTesting(!leaving)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !field.bodies.contains(where: { $0.id == c.id && $0.dragging }) {
                            field.beginDrag(c.id)
                            dragMoved = false
                        }
                        if abs(g.translation.width) + abs(g.translation.height) > 5 {
                            dragMoved = true
                        }
                        field.drag(c.id, to: g.location)
                    }
                    .onEnded { _ in
                        field.endDrag(c.id)
                        if !dragMoved { store.selectedID = c.id }
                    }
            )
    }
}

// MARK: - 完了アニメーション

/// **この app で唯一、儀式的な演出をしていい場所。** 他はすべて静かに保つ。
///
/// HTML 版の `@keyframes float-away` をそのまま移した：
/// 0% → 22% でいったん上に 14px 浮いて 1.14 倍に膨らみ（最後の一呼吸）、
/// そこから -340px まで抜けながら半分に縮んで消える。計 2.1 秒。
private struct FloatAway: ViewModifier, Animatable {
    var active: Bool

    struct Values {
        var y: Double = 0
        var scale: Double = 1
        var opacity: Double = 1
    }

    func body(content: Content) -> some View {
        content.keyframeAnimator(
            initialValue: Values(),
            trigger: active
        ) { view, v in
            view
                .offset(y: v.y)
                .scaleEffect(v.scale)
                .opacity(v.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.y) {
                CubicKeyframe(active ? -14 : 0, duration: 0.46)
                CubicKeyframe(active ? -340 : 0, duration: 1.64)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(active ? 1.14 : 1, duration: 0.46)
                CubicKeyframe(active ? 0.5 : 1, duration: 1.64)
            }
            KeyframeTrack(\.opacity) {
                CubicKeyframe(1, duration: 0.46)
                CubicKeyframe(active ? 0 : 1, duration: 1.64)
            }
        }
    }
}
