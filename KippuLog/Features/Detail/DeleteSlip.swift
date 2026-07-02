import SwiftUI

/// 改札の問い — the gate asks before it takes a ticket back. A paper
/// slip slides onto the desk with a torn top edge and two stamps; the
/// room dims a step while the question stands. No system dialog ever
/// wears the right paper.
struct DeleteSlip: View {
    var onRelease: () -> Void
    var onKeep: () -> Void

    @State private var seated = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // The room holds its breath.
            Color.black
                .opacity(seated ? 0.38 : 0)
                .ignoresSafeArea()
                .onTapGesture { leave(then: onKeep) }
                .accessibilityLabel("やめる")

            // The slip.
            VStack(spacing: 0) {
                Text("この切符を手放しますか")
                    .font(Typo.mincho(16))
                    .tracking(2)
                    .foregroundStyle(Ink.text)
                    .padding(.top, 30)
                    .padding(.bottom, 8)

                Text("改札が回収し、誌面から下がります")
                    .font(Typo.gothic(11.5))
                    .tracking(1)
                    .foregroundStyle(Ink.textSoft)
                    .padding(.bottom, 24)

                HStack(spacing: 10) {
                    Button {
                        Haptic.play(.punch)
                        leave(then: onRelease)
                    } label: {
                        Text("手放す")
                            .font(Typo.gothic(13, bold: true))
                            .tracking(2)
                            .foregroundStyle(Color(hex: 0xF7F3EB))
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Ink.shu)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("slip-release")

                    Button {
                        Haptic.play(.tick)
                        leave(then: onKeep)
                    } label: {
                        Text("やめる")
                            .font(Typo.gothic(13, bold: true))
                            .tracking(2)
                            .foregroundStyle(Ink.textSoft)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Ink.rule, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("slip-keep")
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity)
            .background {
                TornTopRectangle()
                    .fill(Ink.background)
                    .shadow(color: .black.opacity(0.45), radius: 26, y: -8)
                    .ignoresSafeArea(edges: .bottom)
            }
            .padding(.horizontal, 10)
            .offset(y: seated ? 0 : 340)
            .rotationEffect(.degrees(seated ? 0 : -0.6), anchor: .bottomTrailing)
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                seated = true
            }
        }
    }

    /// The slip withdraws, then the answer lands.
    private func leave(then action: @escaping () -> Void) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            seated = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(210))
            action()
        }
    }
}

/// Paper torn along its top edge — the same tear the 半券 stub wears.
private nonisolated struct TornTopRectangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tooth: CGFloat = 7
        let depth: CGFloat = 5
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + depth))
        var x = rect.minX
        var up = true
        while x < rect.maxX {
            let nextX = min(x + tooth, rect.maxX)
            path.addLine(to: CGPoint(x: nextX, y: up ? rect.minY : rect.minY + depth))
            up.toggle()
            x = nextX
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        Ink.studio.ignoresSafeArea()
        DeleteSlip(onRelease: {}, onKeep: {})
    }
}
