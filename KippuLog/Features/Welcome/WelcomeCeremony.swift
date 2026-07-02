import SwiftUI

/// 開幕 — the first launch. The machine prints you a 見本, punches it,
/// and lays it in your hand; then the ticket itself shows you where the
/// gate lives. The engine below runs the theatre; this view holds only
/// the quiet words and the two ways out.
struct WelcomeCeremony: View {
    @Environment(TicketStore.self) private var store

    @State private var handle = WelcomeEngineHandle()
    @State private var phase: WelcomeEngine.Phase = .opening
    @State private var leaving = false

    var body: some View {
        ZStack {
            WelcomeEngineView(handle: handle) { newPhase in
                withAnimation(.easeOut(duration: 0.55)) {
                    phase = newPhase
                }
            }
            .ignoresSafeArea()
            .accessibilityElement()
            .accessibilityLabel("きっぷログのご案内。切符を撮ると、旅がここに綴じられていきます。")

            VStack(spacing: 0) {
                Spacer()

                Text("切符を撮ると、旅がここに綴じられていく。")
                    .font(Typo.mincho(15, light: true))
                    .tracking(2.5)
                    .foregroundStyle(Stage.softText)
                    .padding(.bottom, 40)

                Button {
                    Haptic.play(.punch)
                    leave(.capture)
                } label: {
                    Text("最初の一枚を撮る")
                        .font(Typo.gothic(15, bold: true))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(Ink.shu).interactive(), in: .capsule)
                .accessibilityIdentifier("welcome-capture")
                .padding(.horizontal, 44)
                .padding(.bottom, 14)

                Button {
                    Haptic.play(.tick)
                    leave(.settle)
                } label: {
                    Text("まずは見てまわる")
                        .font(Typo.gothic(12))
                        .tracking(1.5)
                        .foregroundStyle(Stage.faintText)
                        .padding(10)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("welcome-later")
                .padding(.bottom, 22)
            }
            .opacity(phase == .settled && !leaving ? 1 : 0)
            .offset(y: phase == .settled && !leaving ? 0 : 14)
            .allowsHitTesting(phase == .settled && !leaving)
        }
        .statusBarHidden(true)
        .task {
            #if DEBUG
            // `-uiTestWelcomeAutoExit` — deterministic exit for screenshot
            // bursts (the ceremony can't be tapped from simctl).
            if ProcessInfo.processInfo.arguments.contains("-uiTestWelcomeAutoExit") {
                while phase != .settled { try? await Task.sleep(for: .milliseconds(120)) }
                try? await Task.sleep(for: .milliseconds(1000))
                leave(.settle)
            }
            #endif
        }
    }

    /// The ceremony's one exit: the specimen dives into the gate, the
    /// lights come up, and the shelf takes over.
    private func leave(_ followUp: TicketStore.WelcomeFollowUp) {
        guard !leaving else { return }
        withAnimation(.easeIn(duration: 0.25)) { leaving = true }
        guard let engine = handle.engine else {
            store.completeWelcome(followUp: followUp)
            return
        }
        engine.exitToGate {
            store.completeWelcome(followUp: followUp)
        }
    }
}

/// A hand on the engine for the SwiftUI layer above it.
@MainActor
final class WelcomeEngineHandle {
    weak var engine: WelcomeEngine?
}

private struct WelcomeEngineView: UIViewRepresentable {
    let handle: WelcomeEngineHandle
    var onPhase: (WelcomeEngine.Phase) -> Void

    func makeUIView(context: Context) -> WelcomeEngine {
        let engine = WelcomeEngine(frame: .zero)
        engine.onPhaseChange = onPhase
        handle.engine = engine
        return engine
    }

    func updateUIView(_ uiView: WelcomeEngine, context: Context) {}
}

#Preview {
    WelcomeCeremony()
        .environment(TicketStore())
}
