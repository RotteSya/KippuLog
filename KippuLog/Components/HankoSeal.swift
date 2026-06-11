import SwiftUI

/// 落款 — the editor's seal. A 白文 square: vermilion ground, the
/// character left as paper. Pressed a hair off true, like a real hand.
struct HankoSeal: View {
    var character = "き"
    var size: CGFloat = 17

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16)
                .fill(Ink.shu)
            RoundedRectangle(cornerRadius: size * 0.16)
                .inset(by: size * 0.07)
                .stroke(Color.white.opacity(0.35), lineWidth: max(0.5, size * 0.03))
            Text(character)
                .font(Typo.mincho(size * 0.60))
                .foregroundStyle(Color(hex: 0xF7F3EB))
                .offset(y: -size * 0.01)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-2.5))
        .accessibilityHidden(true)
    }
}

/// The punch glyph — a small ticket with the gate's bite taken out.
/// Replaces the generic plus.
struct PunchGlyph: View {
    var size: CGFloat = 24

    var body: some View {
        PunchGlyphShape()
            .fill(.white, style: FillStyle(eoFill: true))
            .frame(width: size, height: size * 0.66)
            .rotationEffect(.degrees(-22))
    }
}

private nonisolated struct PunchGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: rect.height * 0.16, height: rect.height * 0.16)
        )
        let r = rect.height * 0.17
        let c = CGPoint(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.34)
        path.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        // A second, smaller punch near the tail — the collector's mark.
        let r2 = rect.height * 0.10
        let c2 = CGPoint(x: rect.minX + rect.width * 0.74, y: rect.minY + rect.height * 0.62)
        path.addEllipse(in: CGRect(x: c2.x - r2, y: c2.y - r2, width: r2 * 2, height: r2 * 2))
        return path
    }
}

#Preview {
    HStack(spacing: 30) {
        HankoSeal()
        ZStack {
            Circle().fill(Ink.shu).frame(width: 58, height: 58)
            PunchGlyph()
        }
    }
    .padding(40)
    .background(Ink.background)
}
