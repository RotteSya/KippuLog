import SwiftUI

/// Editorial type system.
///
/// 明朝 (Hiragino Mincho ProN) carries the magazine voice — station names,
/// headers, the wordmark. ゴシック (Hiragino Sans) does quiet labour —
/// captions, labels, ticket faces. Latin/numeral accents use New York
/// via `.fontDesign(.serif)` where it matters.
enum Typo {
    /// Display serif. W6 by default; pass `light: true` for W3.
    static func mincho(_ size: CGFloat, light: Bool = false) -> Font {
        .custom(light ? "HiraMinProN-W3" : "HiraMinProN-W6", size: size)
    }

    /// Workhorse gothic.
    static func gothic(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "HiraginoSans-W6" : "HiraginoSans-W3", size: size)
    }

    /// Small latin caption — SF with generous tracking, meant for
    /// `.textCase(.uppercase)` captions like "JUNE 2026".
    static func caption(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium)
    }

    /// Serif numerals (New York) for editorial figures.
    static func serifFigure(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
