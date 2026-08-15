import SwiftUI
import AppKit
import CoreText

/// 書体。Inter・IBM Plex Mono・Noto Sans JP・Noto Sans TC を同梱している。
///
/// フォントは `Contents/Resources/Fonts` に置き、Info.plist の
/// `ATSApplicationFontsPath` でそこを指す。macOS が起動時に登録するので
/// CTFontManager を自分で叩く必要はない。
enum Typo {

    // MARK: フォールバック

    /// **SwiftUI の `Font.custom` は1書体しか受け取らない。**
    /// Inter を指定しただけだと、和文・中文は「システムが選んだ何か」
    /// （macOS なら Hiragino）に落ちる。同梱した Noto を使わせるには
    /// CoreText のカスケードリストを自分で組む必要がある。
    ///
    /// 順番は Inter → Noto Sans JP → Noto Sans TC。
    /// 日本語と中国語で字形が違う漢字（骨・直・今 など）は先に来た JP が勝つ。
    /// 制作者は日本で仕事をしているのでその優先で問題ない。
    private static func cascaded(_ primary: String,
                                 size: CGFloat,
                                 weight: NSFont.Weight) -> Font {
        let fallbacks = ["Noto Sans JP", "Noto Sans TC"]
            .map { CTFontDescriptorCreateWithNameAndSize($0 as CFString, size) }

        let desc = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute: primary,
            kCTFontSizeAttribute: size,
            kCTFontCascadeListAttribute: fallbacks,
            kCTFontTraitsAttribute: [kCTFontWeightTrait: weight.rawValue],
        ] as CFDictionary)

        return Font(CTFontCreateWithFontDescriptor(desc, size, nil))
    }

    /// 本文・見出し。Inter は可変フォントなので1ファイルで全ウェイトを賄う
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        cascaded("Inter", size: size, weight: weight.ns)
    }

    /// `.meta` 相当。小さいラベルと数字。
    /// ここにも和文が入る（「ステータス」など）のでフォールバックは要る。
    static func mono(_ size: CGFloat) -> Font {
        cascaded("IBM Plex Mono", size: size, weight: .regular)
    }

    // MARK: 検証

    /// 同梱フォントが実際に登録されたか。**起動時に一度だけ確かめる。**
    /// 見つからないと SwiftUI は黙ってシステムフォントに落ちるので、
    /// 「なんとなく違う気がする」で終わってしまう。
    ///
    /// GUI アプリの stdout / stderr は端末から起動しても素直に出てこないため
    /// （print は全バッファリング、stderr も届かなかった）ファイルに書く。
    static func report() {
        let want = ["Inter", "IBM Plex Mono", "Noto Sans JP", "Noto Sans TC"]
        let have = NSFontManager.shared.availableFontFamilies
        let lines = want.map { have.contains($0) ? "✓ \($0)" : "✗ NOT FOUND: \($0)" }
        try? lines.joined(separator: "\n")
            .write(to: URL(fileURLWithPath: "/tmp/babos-font.log"),
                   atomically: true, encoding: .utf8)
    }
}

private extension Font.Weight {
    /// CoreText の重みは -1.0…1.0 の連続値
    var ns: NSFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin:       .thin
        case .light:      .light
        case .medium:     .medium
        case .semibold:   .semibold
        case .bold:       .bold
        case .heavy:      .heavy
        case .black:      .black
        default:          .regular
        }
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
