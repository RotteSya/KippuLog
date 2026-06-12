import SwiftUI

/// The final word on boundaries — drag the four corners yourself.
/// The original photo under the lamp, the cut marked in shu, everything
/// outside dimmed like rejected negative. Document-scanner manners,
/// printed-matter soul.
struct QuadEditorView: View {
    let original: UIImage
    let initialQuad: TicketQuad
    var onApply: (TicketQuad) -> Void
    var onCancel: () -> Void

    @State private var quad: TicketQuad
    @State private var activeCorner: Corner?

    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

    init(original: UIImage, initialQuad: TicketQuad?,
         onApply: @escaping (TicketQuad) -> Void, onCancel: @escaping () -> Void) {
        self.original = original
        self.initialQuad = initialQuad ?? .fallback
        self.onApply = onApply
        self.onCancel = onCancel
        _quad = State(initialValue: initialQuad ?? .fallback)
    }

    var body: some View {
        ZStack {
            StudioBackdrop(center: UnitPoint(x: 0.5, y: 0.45), radius: 1.0, warmth: 0.3)

            VStack(spacing: 0) {
                Text("切り取り範囲")
                    .font(Typo.mincho(16))
                    .tracking(4)
                    .foregroundStyle(Stage.text)
                    .padding(.top, 24)
                Text("角をドラッグして合わせる")
                    .font(Typo.gothic(11))
                    .tracking(1.5)
                    .foregroundStyle(Stage.faintText)
                    .padding(.top, 6)

                editorCanvas
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)

                actions
                    .padding(.bottom, 22)
            }
        }
        .statusBarHidden(true)
    }

    // MARK: Canvas

    private var editorCanvas: some View {
        GeometryReader { proxy in
            let fit = fittedRect(in: proxy.size)
            ZStack {
                Image(uiImage: original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: fit.width, height: fit.height)
                    .position(x: fit.midX, y: fit.midY)

                // Reject everything outside the cut.
                DimOutsideQuad(quad: quad, fit: fit)
                    .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

                // The cut, in shu.
                QuadOutline(quad: quad, fit: fit)
                    .stroke(Ink.shu, lineWidth: 1.6)
                    .shadow(color: Ink.shu.opacity(0.5), radius: 4)

                ForEach(corners, id: \.self) { corner in
                    handle(for: corner, fit: fit)
                }
            }
            .contentShape(Rectangle())
        }
        .aspectRatio(max(0.55, min(1.6, originalAspect)), contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var corners: [Corner] { [.topLeft, .topRight, .bottomLeft, .bottomRight] }

    private func handle(for corner: Corner, fit: CGRect) -> some View {
        let p = point(for: corner)
        let position = CGPoint(x: fit.minX + p.x * fit.width, y: fit.minY + p.y * fit.height)
        return Circle()
            .fill(.white.opacity(0.001))
            .frame(width: 46, height: 46)
            .overlay {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xF7F3EB))
                        .frame(width: 17, height: 17)
                        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    Circle()
                        .stroke(Ink.shu, lineWidth: 2.2)
                        .frame(width: 17, height: 17)
                }
                .scaleEffect(activeCorner == corner ? 1.45 : 1)
                .animation(.spring(response: 0.28, dampingFraction: 0.6), value: activeCorner == corner)
            }
            .position(position)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if activeCorner != corner {
                            activeCorner = corner
                            Haptic.play(.tick)
                        }
                        let nx = ((value.location.x - fit.minX) / fit.width).clamped(to: 0...1)
                        let ny = ((value.location.y - fit.minY) / fit.height).clamped(to: 0...1)
                        set(corner: corner, to: CGPoint(x: nx, y: ny))
                    }
                    .onEnded { _ in
                        activeCorner = nil
                        Haptic.play(.tick)
                    }
            )
            .accessibilityIdentifier("quad-handle-\(label(for: corner))")
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: 14) {
            Button {
                Haptic.play(.tick)
                onCancel()
            } label: {
                Text("やめる")
                    .font(Typo.gothic(13))
                    .tracking(1.5)
                    .foregroundStyle(Stage.softText)
                    .frame(width: 110, height: 46)
            }
            .glassEffect(.regular, in: .capsule)

            Button {
                Haptic.play(.stamp)
                onApply(quad)
            } label: {
                Text("この範囲で切る")
                    .font(Typo.gothic(14, bold: true))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                    .frame(width: 170, height: 46)
            }
            .glassEffect(.regular.tint(Ink.shu).interactive(), in: .capsule)
            .accessibilityIdentifier("quad-apply")
        }
        .buttonStyle(.plain)
    }

    // MARK: Geometry

    private var originalAspect: CGFloat {
        original.size.height > 0 ? original.size.width / original.size.height : 1.4
    }

    private func fittedRect(in bounds: CGSize) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / original.size.width, bounds.height / original.size.height)
        let size = CGSize(width: original.size.width * scale, height: original.size.height * scale)
        return CGRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func point(for corner: Corner) -> CGPoint {
        switch corner {
        case .topLeft: quad.topLeft
        case .topRight: quad.topRight
        case .bottomLeft: quad.bottomLeft
        case .bottomRight: quad.bottomRight
        }
    }

    private func set(corner: Corner, to p: CGPoint) {
        switch corner {
        case .topLeft: quad.topLeft = p
        case .topRight: quad.topRight = p
        case .bottomLeft: quad.bottomLeft = p
        case .bottomRight: quad.bottomRight = p
        }
    }

    private func label(for corner: Corner) -> String {
        switch corner {
        case .topLeft: "tl"
        case .topRight: "tr"
        case .bottomLeft: "bl"
        case .bottomRight: "br"
        }
    }
}

/// Quad outline path in view space.
private nonisolated struct QuadOutline: Shape {
    let quad: TicketQuad
    let fit: CGRect

    func path(in _: CGRect) -> Path {
        var path = Path()
        func v(_ p: CGPoint) -> CGPoint {
            CGPoint(x: fit.minX + p.x * fit.width, y: fit.minY + p.y * fit.height)
        }
        path.move(to: v(quad.topLeft))
        path.addLine(to: v(quad.topRight))
        path.addLine(to: v(quad.bottomRight))
        path.addLine(to: v(quad.bottomLeft))
        path.closeSubpath()
        return path
    }
}

/// Fit-rect minus the quad, for the rejected-negative dim (even-odd).
private nonisolated struct DimOutsideQuad: Shape {
    let quad: TicketQuad
    let fit: CGRect

    func path(in _: CGRect) -> Path {
        var path = Path()
        path.addRect(fit)
        func v(_ p: CGPoint) -> CGPoint {
            CGPoint(x: fit.minX + p.x * fit.width, y: fit.minY + p.y * fit.height)
        }
        path.move(to: v(quad.topLeft))
        path.addLine(to: v(quad.topRight))
        path.addLine(to: v(quad.bottomRight))
        path.addLine(to: v(quad.bottomLeft))
        path.closeSubpath()
        return path
    }
}
