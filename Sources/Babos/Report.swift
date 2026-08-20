import Foundation
import AppKit

/// 一巡ぶんのレポート。Markdown で書き出す。
///
/// **画面に出る形ではなくファイルにする。** この機能の目的は
/// 「上に見せる」「あとで読み返す」であって、アプリの中で眺めることではない。
/// 20 件の記録を一度に読むのに、アプリの詳細カードは狭すぎる。
extension Store {

    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func fmtDay(_ d: Date) -> String { Self.day.string(from: d) }

    func buildReport(_ cycle: SealedCycle) -> String {
        var out: [String] = []
        out.append("# \(t.reportTitle)")
        out.append("")
        out.append("**\(t.reportRange)**: \(fmtDay(cycle.start)) 〜 \(fmtDay(cycle.end))")
        out.append("**\(t.reportCases)**: \(cycle.caseIds.count)")
        out.append("")
        out.append("---")
        out.append("")

        for id in cycle.caseIds {
            // 消された案件は飛ばす。id だけ残っていても中身が無い
            guard let c = cases.first(where: { $0.id == id }) else { continue }
            out.append("## \(c.name)")
            let meta = [c.type, c.client].filter { !$0.isEmpty }.joined(separator: " · ")
            if !meta.isEmpty { out.append("_\(meta)_") }
            out.append("")

            let logs = c.logs.sorted { $0.ts < $1.ts }
            if logs.isEmpty {
                out.append(t.reportNoLogs)
                out.append("")
            } else {
                for l in logs { out.append("- `\(fmtDay(l.ts))` \(l.text)") }
                out.append("")
            }
            if !c.memo.isEmpty {
                out.append("> " + c.memo.replacingOccurrences(of: "\n", with: "\n> "))
                out.append("")
            }
        }
        return out.joined(separator: "\n")
    }

    /// 保存先を訊いてから書く。
    /// **`begin` ではなく `runModal` を使う。** 非同期版だと呼び出し元の
    /// alert が閉じきる前にパネルが出て、どちらも操作できなくなることがある。
    /// 書き出せたら true。**呼び出し側はこれを見てから案件を消すこと。**
    /// パネルを閉じただけ・書き込みに失敗した場合は false を返すので、
    /// 記録が残らないまま案件だけ消えることはない。
    @discardableResult
    func exportReport(_ cycle: SealedCycle) -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "babos-report-\(fmtDay(cycle.end)).md"
        panel.allowedContentTypes = [.init(filenameExtension: "md")].compactMap { $0 }
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try buildReport(cycle).write(to: url, atomically: true, encoding: .utf8)
            // 保存先を出さないと、どこへ行ったのか分からない
            notify(t.reportSaved(url.path))
            return true
        } catch {
            notify(t.reportFailed)
            return false
        }
    }
}
