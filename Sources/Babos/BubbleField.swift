import SwiftUI

/// 氣泡區。這個 app 的招牌，也是這次要先驗證的部分——
/// 如果物理與質感在 SwiftUI 裡站得住，其他版面都只是工。
struct BubbleField: View {
    var cases: [Case]
    @Binding var selectedID: String?

    @State private var field = Field()
    /// 拖曳超過 5px 就不算點選，避免拖完順手選到別的案子
    @State private var dragMoved = false

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { _ in
                Canvas { ctx, size in
                    // Canvas 只畫背景暈染，氣泡本身用真的 View 疊上去，
                    // 這樣才能直接吃手勢，不用自己算 hit test
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .radialGradient(
                            Gradient(colors: [.violetWash, .midnightInk]),
                            center: CGPoint(x: size.width * 0.5, y: size.height * 0.48),
                            startRadius: 0,
                            endRadius: max(size.width, size.height) * 0.62))
                }
                .overlay { bubbles }
                .onChange(of: geo.size, initial: true) { _, new in
                    field.bounds = new
                    field.sync(cases)
                }
                .onChange(of: cases.map(\.step), initial: false) { _, _ in
                    field.sync(cases)
                }
                .task(id: "physics") { await run() }
            }
        }
    }

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
        let selected = selectedID == c.id
        let d = b.r * 2

        return Circle()
            .fill(Color.haloViolet.opacity(Encoding.opacity(c.progress)))
            .frame(width: d, height: d)
            // 選取時外圈一層青色暈，這是全場唯一的高彩度
            .shadow(color: selected ? Color.arcCyan.opacity(0.45) : .clear,
                    radius: 18)
            .overlay {
                // 直徑夠大才顯示名稱，小氣泡放字只會糊掉
                if d >= 52 {
                    Text(c.name)
                        .font(.system(size: 9 + max(0, d - 42) * 0.034, weight: .regular))
                        .foregroundStyle(Color.midnightInk)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: d * 0.82)
                }
            }
            .position(x: b.x, y: b.y)
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
                        if !dragMoved { selectedID = c.id }
                    }
            )
    }

    /// 物理迴圈。跟畫面刷新分開跑，畫面只是讀 field 的結果。
    private func run() async {
        while !Task.isCancelled {
            field.tick()
            try? await Task.sleep(for: .milliseconds(16))
        }
    }
}
