import SwiftUI
import Observation

/// 一顆氣泡的物理狀態。位置由這裡持有，畫面只負責讀。
struct PhysicsBody {
    var id: String
    var x: Double
    var y: Double
    var vx: Double = 0
    var vy: Double = 0
    var r: Double
    var dragging = false
    /// 漂移方向。**不是每幀重擲**——理由見 `Field.tick`
    var driftX: Double = 0
    var driftY: Double = 0
}

/// 每一幀解算一次的物理場。
///
/// HTML 版是同一套演算法（tick()）。原本規格寫要用 d3-force，
/// 但為了維持單一檔案零依賴而自己寫；這裡沒有那個限制，
/// 不過 12 顆規模自己寫仍然最輕，而且參數調整直觀。
@Observable
final class Field {
    var bodies: [PhysicsBody] = []
    var bounds: CGSize = .init(width: 900, height: 600)

    /// 螢幕保護時把衰減放鬆，讓氣泡漂得更久
    var relaxed = false

    /// 漂移強度。**0 で完全静止**（制作者の指定により既定は 0）。
    /// 0.018 くらいでゆっくり漂う。HTML 版は毎フレーム乱数で
    /// 実質 0.0275 相当だったが、ネイティブでは震えとして目に入る。
    var driftStrength: Double = 0

    /// 完成動畫進行中的氣泡。位置凍結，交給畫面那邊的關鍵影格接管
    var finishing: Set<String> = []

    private let padding = (top: 12.0, bottom: 12.0, side: 16.0)
    private var frame = 0

    // MARK: 同步

    /// 依案件清單建立／移除 body。尺寸每次都重新套用，
    /// 這樣進度一改，氣泡立刻跟著長大或縮小。
    func sync(_ cases: [Case]) {
        let alive = Set(cases.map(\.id))
        bodies.removeAll { !alive.contains($0.id) }

        for c in cases {
            let r = Encoding.size(c.progress) / 2
            if let i = bodies.firstIndex(where: { $0.id == c.id }) {
                bodies[i].r = r
            } else {
                // 新氣泡從外圍進來，不要憑空出現在正中央
                let a = Double.random(in: 0..<(.pi * 2))
                bodies.append(PhysicsBody(
                    id: c.id,
                    x: bounds.width / 2 + cos(a) * bounds.width * 0.42,
                    y: bounds.height / 2 + sin(a) * bounds.height * 0.34,
                    r: r))
            }
        }
    }

    // MARK: 每幀

    func tick() {
        let cx = bounds.width / 2
        let cy = bounds.height / 2

        // 漂移方向は 0.5 秒ごとにしか変えない。
        //
        // HTML 版は毎フレーム乱数を足していたが、そのまま移植したら
        // 「細かく震えている」と言われた。WebView の描画は輪郭が甘く、
        // 高周波の揺れが均されて見えていたのだと思う。ネイティブは輪郭が
        // 立つぶん、同じ強度でもチラつきとして目に入る。
        //
        // 方向を保持して緩やかに変えると、震えではなく漂いになる。
        frame += 1
        if driftStrength > 0, frame % 30 == 0 {
            for i in bodies.indices {
                bodies[i].driftX = Double.random(in: -driftStrength...driftStrength)
                bodies[i].driftY = Double.random(in: -driftStrength...driftStrength)
            }
        }

        // ① 互相推開
        for i in bodies.indices {
            for j in (i + 1)..<bodies.count {
                let dx = bodies[j].x - bodies[i].x
                let dy = bodies[j].y - bodies[i].y
                let d = max(sqrt(dx * dx + dy * dy), 0.01)
                let minDist = bodies[i].r + bodies[j].r + 6
                guard d < minDist else { continue }

                let push = (minDist - d) / d * 0.22
                let ox = dx * push, oy = dy * push
                if !bodies[i].dragging {
                    bodies[i].x -= ox; bodies[i].y -= oy
                    bodies[i].vx -= ox * 0.35; bodies[i].vy -= oy * 0.35
                }
                if !bodies[j].dragging {
                    bodies[j].x += ox; bodies[j].y += oy
                    bodies[j].vx += ox * 0.35; bodies[j].vy += oy * 0.35
                }
            }
        }

        // ② 中心力＋緩やかな漂い、衰減、邊界反彈
        let damp = relaxed ? 0.972 : 0.935
        for i in bodies.indices where !bodies[i].dragging && !finishing.contains(bodies[i].id) {
            bodies[i].vx += (cx - bodies[i].x) * 0.0007 + bodies[i].driftX
            bodies[i].vy += (cy - bodies[i].y) * 0.0007 + bodies[i].driftY
            bodies[i].vx *= damp
            bodies[i].vy *= damp
            bodies[i].x += bodies[i].vx
            bodies[i].y += bodies[i].vy

            let r = bodies[i].r
            if bodies[i].x - r < padding.side {
                bodies[i].x = padding.side + r; bodies[i].vx *= -0.42
            }
            if bodies[i].x + r > bounds.width - padding.side {
                bodies[i].x = bounds.width - padding.side - r; bodies[i].vx *= -0.42
            }
            if bodies[i].y - r < padding.top {
                bodies[i].y = padding.top + r; bodies[i].vy *= -0.42
            }
            if bodies[i].y + r > bounds.height - padding.bottom {
                bodies[i].y = bounds.height - padding.bottom - r; bodies[i].vy *= -0.42
            }
        }
    }

    // MARK: 拖曳

    func beginDrag(_ id: String) {
        guard let i = bodies.firstIndex(where: { $0.id == id }) else { return }
        bodies[i].dragging = true
    }

    /// 拖曳時把速度設成位移量，放手之後才會留下慣性。
    /// **枠内に収める。** 掴んだまま外へ引っぱると、気泡が隣のカードの上まで
    /// はみ出して描かれてしまう。
    func drag(_ id: String, to p: CGPoint) {
        guard let i = bodies.firstIndex(where: { $0.id == id }) else { return }
        let r = bodies[i].r
        let x = min(max(p.x, padding.side + r), bounds.width - padding.side - r)
        let y = min(max(p.y, padding.top + r), bounds.height - padding.bottom - r)
        bodies[i].vx = x - bodies[i].x
        bodies[i].vy = y - bodies[i].y
        bodies[i].x = x
        bodies[i].y = y
    }

    func endDrag(_ id: String) {
        guard let i = bodies.firstIndex(where: { $0.id == id }) else { return }
        bodies[i].dragging = false
    }
}
