import SwiftUI
import UIKit

/// 和紙と墨 — the paper-and-ink palette of きっぷログ.
///
/// One warm paper, one warm ink, one vermilion accent.
/// Tickets themselves stay paper-coloured in both appearances;
/// only the room around them dims.
enum Ink {
    // MARK: Surfaces

    /// App background. 生成り paper in light, a dim studio in dark.
    static let background = Color.dynamic(light: 0xF7F3EB, dark: 0x171411)
    /// Slightly recessed surface (grouped rows, wells).
    static let backgroundDeep = Color.dynamic(light: 0xEFE9DC, dark: 0x1F1B16)
    /// The studio backdrop behind a hero ticket — always night.
    static let studio = Color(hex: 0x14110E)

    // MARK: Ink

    static let text = Color.dynamic(light: 0x26211B, dark: 0xEDE6DA)
    static let textSoft = Color.dynamic(light: 0x7A7166, dark: 0x9C938A)
    static let textFaint = Color.dynamic(light: 0xB3A998, dark: 0x5C554C)
    /// Hairline rules.
    static let rule = Color.dynamic(light: 0xDDD5C4, dark: 0x342E26)

    // MARK: Accent

    /// 朱 — the single accent. Punch buttons, live markers, era stamps.
    static let shu = Color(hex: 0xD8401F)
    static let shuDeep = Color(hex: 0xB23218)

    // MARK: Ticket papers (constant across appearances — tickets are objects)

    static let ticketCream = Color(hex: 0xF5EFE1)
    static let ticketCreamShade = Color(hex: 0xE9E1CD)
    static let edmondsonBuff = Color(hex: 0xE5D3AE)
    static let edmondsonShade = Color(hex: 0xD6C094)
    static let ticketInk = Color(hex: 0x2B2620)
    static let ticketInkSoft = Color(hex: 0x6E6557)
}

extension Color {
    /// sRGB color from 0xRRGGBB.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Trait-adaptive color from two hex values.
    ///
    /// `nonisolated` is load-bearing. SwiftUI resolves colours on a non-main
    /// render thread (`ViewGraphDisplayLink.asyncThread`); under this target's
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, an unannotated provider
    /// closure inherits `@MainActor` and traps (EXC_BREAKPOINT) the instant
    /// UIKit resolves it off-main. Keeping the helper — and thus its closure —
    /// nonisolated lets the trait lookup run safely on any thread.
    nonisolated static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
