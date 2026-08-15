import SwiftUI

/// 氣泡區。這個 app 的招牌。
struct BubbleField: View {
    @Bindable var store: Store
    /// スクリーンセーバー時は減衰を緩めてゆっくり漂わせる
    var relaxed = false

    @State private var field = Field()
    /// 拖曳超過 5px 就不算點選，避免拖完順手選到別的案子
    @State private var dragMoved = false

    /// 完了アニメーション中の案件も、抜け終わるまでは描き続ける。
    /// bubbleCases を1件ごとになめると O(n²) になるので、先に Set にする。
    private var cases: [Case] {
        let visible = Set(store.bubbleCases.map(\.id))
        return store.cases.filter {
            visible.contains($0.id) || store.finishing.contains($0.id)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backdrop
                bubbles
            }
            // 気泡区の外へは描かない。掴んで引っぱったとき、

            // 隣の詳細カードの上まで円が出てしまうため

            .clipped()

            .overlay(alignment: .top) { chips }
            .overlay(alignment: .bottom) { legend }
            .background { driver }        // 物理はここで駆動する
            .onChange(of: geo.size, initial: true) { _, new in
                field.bounds = new
                field.relaxed = relaxed
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

    // MARK: 絞り込みチップ

    /// サイドバーと同じ条件だが、こちらは気泡を見ながら切り替えるためのもの。
    /// セーバー中は出さない。
    private var chips: some View {
        HStack(spacing: 8) {
            chip(nil, store.t.all, store.aliveCount)
            ForEach([Status.active, .waiting, .near], id: \.self) { s in
                chip(s, s.label(store.t), store.count(s))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .opacity(relaxed ? 0 : 1)
        .allowsHitTesting(!relaxed)
    }

    private func chip(_ s: Status?, _ label: String, _ n: Int) -> some View {
        let on = store.statusFilter == s
        return Button {
            store.statusFilter = (store.statusFilter == s) ? nil : s
        } label: {
            HStack(spacing: 6) {
                Text(label).font(Typo.body(11.5))
                Text("\(n)").font(Typo.mono(10))
                    .foregroundStyle(Color.fog)
            }
            .foregroundStyle(on ? Color.ink : Color.mist)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .overlay(Capsule().strokeBorder(on ? Color.ink : Color.slateBody, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: 凡例

    /// 濃淡が何を意味するかの唯一の説明。**気泡そのものには
    /// リングも％も付けない**ので、読み方はここでしか示されない。
    private var legend: some View {
        HStack(spacing: 10) {
            Text(store.t.legendStart).metaStyle(10)
            LinearGradient(
                colors: [Color.haloViolet.opacity(0.18), Color.haloViolet],
                startPoint: .leading, endPoint: .trailing)
                .frame(height: 8)
                .clipShape(Capsule())
            Text(store.t.legendEnd).metaStyle(10)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .opacity(relaxed ? 0 : 1)
        .allowsHitTesting(false)
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
                        .font(Typo.body(9 + max(0, d - 42) * 0.034))
                        .foregroundStyle(Color.bubbleText)
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
