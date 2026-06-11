import SwiftUI

/// The gate. A vermilion liquid-glass punch that opens the capture flow —
/// the only loud object in the whole magazine.
struct PunchButton: View {
    var action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            Haptic.play(.punch)
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(Ink.shu.gradient)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 60, height: 60)
            .contentShape(Circle())
        }
        .buttonStyle(PunchPressStyle())
        .glassEffect(.regular.tint(Ink.shu.opacity(0.85)).interactive(), in: .circle)
        .shadow(color: Ink.shu.opacity(0.35), radius: 14, y: 6)
        .accessibilityLabel("切符を追加")
        .accessibilityIdentifier("punch-button")
    }
}

/// Springy press: the button squashes like a rubber stamp.
private struct PunchPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Ink.background.ignoresSafeArea()
        PunchButton {}
    }
}
