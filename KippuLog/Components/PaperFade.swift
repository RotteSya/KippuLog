import SwiftUI

/// The page runs out into paper. A breath of `Ink.background` easing over
/// the scroll edges so type never collides with the clock above or the
/// punch below — the magazine's own margins, not a scrim.
struct PaperFade: View {
    enum Side { case top, bottom }
    var side: Side
    var height: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Ink.background, location: 0),
                .init(color: Ink.background.opacity(0.93), location: 0.18),
                .init(color: Ink.background.opacity(0.68), location: 0.42),
                .init(color: Ink.background.opacity(0.30), location: 0.68),
                .init(color: Ink.background.opacity(0.08), location: 0.88),
                .init(color: Ink.background.opacity(0), location: 1),
            ],
            startPoint: side == .top ? .top : .bottom,
            endPoint: side == .top ? .bottom : .top
        )
        .frame(height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
