import SwiftUI
import AppKit

/// 書体。同梱した Inter と IBM Plex Mono を使い、和文・中文は OS のものに落とす。
///
/// フォントは `Contents/Resources/Fonts` に置き、Info.plist の
/// `ATSApplicationFontsPath` でそこを指している。macOS が起動時に登録するので
/// CTFontManager を自分で叩く必要はない。
enum Typo {
    /// 同梱フォントが実際に登録されたか。**起動時に一度だけ端末へ出す。**
    /// 見つからないと SwiftUI は黙ってシステムフォントに落ちるので、
    /// 「なんとなく違う気がする」で終わってしまう。
    /// GUI アプリの stdout/stderr は端末から起動しても素直に出てこないことがある
    /// （print は全バッファリング、stderr も届かなかった）。確実なファイルに書く。
    static func report() {
        let want = ["Inter", "IBM Plex Mono"]
        let have = NSFontManager.shared.availableFontFamilies
        let lines = want.map { have.contains($0) ? "✓ \($0)" : "✗ NOT FOUND: \($0)" }
        try? lines.joined(separator: "\n")
            .write(to: URL(fileURLWithPath: "/tmp/babos-font.log"),
                   atomically: true, encoding: .utf8)
    }

    /// 本文・見出し。Inter は可変フォントなので1ファイルで全ウェイトを賄う
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    /// `.meta` 相当。小さいラベルと数字
    static func mono(_ size: CGFloat) -> Font {
        .custom("IBM Plex Mono", size: size)
    }
}

/// `.meta` は等幅・字間 0.085em。HTML 版の `.meta` をそのまま持ってきている。
extension View {
    func metaStyle(_ size: CGFloat = 11) -> some View {
        self.font(Typo.mono(size))
            .tracking(size * 0.085)
            .foregroundStyle(Color.fog)
    }
}
