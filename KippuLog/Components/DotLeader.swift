import SwiftUI

/// The table-of-contents leader — a quiet run of dots carrying the eye
/// from a title to its figure, the way a magazine's contents page has
/// always done it. Sits on the text baseline in a `firstTextBaseline`
/// stack.
struct DotLeader: View {
    var color: Color = Ink.textFaint

    var body: some View {
        LeaderLine()
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [0.1, 5.2])
            )
            .frame(height: 1.3)
            .frame(maxWidth: .infinity)
            .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 0.5 }
            .accessibilityHidden(true)
    }
}

nonisolated private struct LeaderLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.midY))
        return path
    }
}

#Preview {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text("No. 008").font(Typo.serifFigure(10, weight: .regular))
        DotLeader()
        Text("6.7 SUN").font(Typo.caption(9)).tracking(2)
    }
    .padding(30)
    .background(Ink.background)
}
