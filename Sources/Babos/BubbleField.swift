import SwiftUI

/// 氣泡區。這個 app 的招牌。
struct BubbleField: View {
    @Bindable var store: Store
    /// スクリーンセーバー時は減衰を緩めてゆっくり漂わせる
    var relaxed = false

    @State private var field = Field()
    /// 拖曳超過 5px 就不算點選，避免拖完順手選到別的案子
    @State private var dragMoved = false

    /// ランプの枠。**飛び先の座標はここからしか出せない。**
    /// 気泡区と同じ座標系で測るので、`.named(Self.space)` を通す。
    @State private var lamp = LampBox()

    /// 気泡もランプも同じ座標系で測るための名前
    private static let space = "babos.bubblefield"

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
            // **`.coordinateSpace` は overlay より後に置くこと。**
            // 先に置くと overlay は名前付き座標系の「外」の兄弟になり、
            // ランプ枠を測った値が窓の原点基準で返る。気泡の `.position` は
            // 気泡区の原点基準なので、上部バーの高さぶん（約 94pt）だけ
            // 着地点が下にずれる——横位置だけ合っていて縦が落ちる、という出方をする。
            .coordinateSpace(name: Self.space)
            .onPreferenceChange(LampBoxKey.self) { lamp = $0 }
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
            lamps
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .opacity(relaxed ? 0 : 1)
        .allowsHitTesting(!relaxed)
    }

    // MARK: 一巡のランプ

    /// 右端に寄せた進み具合。**空き枠は描かない。**
    /// ゲームの HP と同じで、点いたぶんだけ右から左へ伸びていく。
    ///
    /// 一段に 20 個ぶんの幅が取れれば一段、無理なら 10 個ずつ二段。
    /// 入るだけ詰めない理由は `Cycle.perRow` を見ること。
    private var lamps: some View {
        GeometryReader { g in
            let per = Cycle.perRow(width: g.size.width)
            let inner = Cycle.innerSize(per: per)
            let on = min(store.cycle.caseIds.count, Cycle.size)
            let frame = g.frame(in: .named(Self.space))

            VStack(alignment: .trailing, spacing: Cycle.vgap) {
                ForEach(0..<(Cycle.size / per), id: \.self) { r in
                    let n = max(0, min(per, on - r * per))
                    if n > 0 { lampRow(n) }
                }
            }
            .frame(width: inner.width, height: inner.height, alignment: .topTrailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .animation(.easeOut(duration: 0.28), value: on)
            // 枠は 0 個のときも同じ寸法で報告する。飛び先をここから測るため
            .preference(key: LampBoxKey.self, value: LampBox(
                box: CGRect(x: frame.maxX - inner.width,
                            y: frame.midY - inner.height / 2,
                            width: inner.width, height: inner.height),
                per: per))
        }
        // GeometryReader は放っておくと縦にも伸びてチップ列を押し広げる
        .frame(height: 26)
    }

    /// **右端から左へ点けていく。** 添字 0 が一番右。
    /// 左から埋めると、増えるたびに列が右へ伸びていくように見えて落ち着かない。
    private func lampRow(_ n: Int) -> some View {
        HStack(spacing: Cycle.gap) {
            ForEach((0..<n).reversed(), id: \.self) { _ in
                Circle()
                    .fill(Color.mist)
                    .frame(width: Cycle.dot, height: Cycle.dot)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
    }

    /// 次に点くランプの中心。まだ枠を測れていなければ nil
    private func lampPoint(_ n: Int) -> CGPoint? {
        guard lamp.box != .zero, lamp.per > 0 else { return nil }
        let i = min(n, Cycle.size - 1)
        return CGPoint(
            x: lamp.box.maxX - Double(i % lamp.per) * (Cycle.dot + Cycle.gap) - Cycle.dot / 2,
            y: lamp.box.minY + Double(i / lamp.per) * (Cycle.dot + Cycle.vgap) + Cycle.dot / 2)
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

        // 行き先は「次に点くランプ」。飛んでいる間に点は増えないので
        // （点灯は着地後）、この値は飛行中ずっと同じ。
        let target = lampPoint(store.cycle.caseIds.count)
        // 枠がまだ測れていないときだけ、旧来どおり真上へ抜けさせる
        let dx = target.map { $0.x - b.x } ?? 0
        let dy = target.map { $0.y - b.y } ?? -340

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
            .modifier(FlyToLamp(active: leaving, dx: dx, dy: dy,
                                // 大きい気泡がそのまま点の大きさで着地するように
                                end: target == nil ? 0.5 : max(0.04, Cycle.dot / max(d, 1))))
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

// MARK: - ランプの枠を上へ渡す

/// 枠は overlay の中にあり、気泡は ZStack の中にある。
/// 兄弟どうしなので preference で親まで持ち上げるしかない。
struct LampBox: Equatable, Sendable {
    var box: CGRect = .zero
    var per: Int = Cycle.size
}

struct LampBoxKey: PreferenceKey {
    static let defaultValue = LampBox()
    static func reduce(value: inout LampBox, nextValue: () -> LampBox) { value = nextValue() }
}

// MARK: - 完了アニメーション

/// **この app で唯一、儀式的な演出をしていい場所。** 他はすべて静かに保つ。
///
/// 気泡は消えるのではなく、右上のランプまで飛んでいってそのまま点になる。
/// ただ上へ抜けさせていた頃は「消えた」で終わっていて、
/// 完了した1件がどこへ行ったのかが画面のどこにも残らなかった。
///
/// HTML 版の `@keyframes float-away`（1.4 秒）をそのまま移した：
/// 0% → 18% でいったん上に 16px 浮いて 1.14 倍に膨らみ（最後の一呼吸）、
/// そこから着地点まで一気に縮んでいく。
///
/// **長さは `Cycle.flyDuration` と必ず揃えること。**
/// ずれると点が先に現れるか、気泡が消えたあとに間が空く。
private struct FlyToLamp: ViewModifier {
    var active: Bool
    var dx: Double
    var dy: Double
    /// 着地時の縮小率。点と同じ大きさになる値を渡す
    var end: Double

    /// 1.4 × 0.18、1.4 × 0.82
    private let lead = 0.252, rest = 1.148

    struct Values {
        var x: Double = 0
        var y: Double = 0
        var scale: Double = 1
        var opacity: Double = 1
    }

    func body(content: Content) -> some View {
        content.keyframeAnimator(
            initialValue: Values(),
            trigger: active
        ) { view, v in
            // **順番を入れ替えてはいけない。** `.offset` を内側に書くと、
            // 外側の `.scaleEffect` が移動量まで一緒に縮める。
            // 着地時の倍率は 0.07 くらいなので、飛距離もその 7% しか出ず、
            // 気泡は元の位置のすぐ横で消える。
            view
                .scaleEffect(v.scale)
                .offset(x: v.x, y: v.y)
                .opacity(v.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.x) {
                CubicKeyframe(active ? dx * 0.06 : 0, duration: lead)
                CubicKeyframe(active ? dx : 0, duration: rest)
            }
            KeyframeTrack(\.y) {
                CubicKeyframe(active ? dy * 0.06 - 16 : 0, duration: lead)
                CubicKeyframe(active ? dy : 0, duration: rest)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(active ? 1.14 : 1, duration: lead)
                CubicKeyframe(active ? end : 1, duration: rest)
            }
            KeyframeTrack(\.opacity) {
                CubicKeyframe(1, duration: lead)
                CubicKeyframe(active ? 0.9 : 1, duration: rest)
            }
        }
    }
}
