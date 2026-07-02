import SwiftUI
import Combine

/// The reveal — the app lifts the ticket off the table: the raw frame
/// recedes and dissolves, the ticket object rises into the lamp. Then a
/// paper desk slides up from below carrying the form. When the keyboard
/// rises, the ticket steps back and the desk takes the whole room — the
/// form is never squeezed.
struct ConfirmTicketView: View {
    let scan: UIImage
    var cutout: UIImage?
    @Binding var draft: Ticket
    /// The save is underway — desk withdraws, ticket sinks to the book.
    var saving = false
    var onSave: () -> Void
    var onRetake: () -> Void
    /// Opens the manual corner editor; nil when no original survives.
    var onAdjust: (() -> Void)?

    @State private var lifted = false
    @State private var deskRaised = false
    @State private var keyboardUp = false

    /// The scan's true proportions, softly clamped like the gate's.
    private var scanAspect: CGFloat {
        let raw = scan.size.height > 0 ? scan.size.width / scan.size.height : MarsTicketFace.aspect
        return min(max(raw, 1.10), 3.20)
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if !keyboardUp {
                    reveal
                        .frame(height: ConfirmStage.fitted(aspect: scanAspect, in: proxy.size).height)
                        .frame(maxWidth: .infinity)
                        .padding(.top, ConfirmStage.topPadding)
                        .padding(.bottom, 26)
                        .transition(
                            .scale(scale: 0.8, anchor: .top)
                                .combined(with: .opacity)
                        )
                }

                desk
                    .offset(y: deskRaised && !saving ? 0 : 640)   // below the frame until it rises
                    .padding(.top, keyboardUp ? 10 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .task { await choreograph() }
        .task {
            #if DEBUG
            // `-uiTestProbeSave` — the desk presses its own save on a
            // fixed clock, so an external recording can dissect the
            // save-to-shelf flight.
            if ProcessInfo.processInfo.arguments.contains("-uiTestProbeSave") {
                try? await Task.sleep(for: .milliseconds(1900))
                Haptic.play(.success)
                onSave()
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                keyboardUp = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                keyboardUp = false
            }
        }
    }

    // MARK: Reveal

    private var reveal: some View {
        ZStack {
            // The raw frame — still wearing the gate's punch, so the
            // handoff from the ceremony is seamless; the hole heals
            // quietly inside the lift. Recedes and blurs as the ticket
            // rises.
            let punch = PunchGeometry(seed: draft.styleSeed, kind: .joshaken)
            Image(uiImage: scan)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: ConfirmStage.maxWidth, maxHeight: ConfirmStage.maxHeight)
                .clipShape(
                    PunchedTicketShape(
                        corner: 6,
                        holeUnit: punch.hole,
                        holeRadiusUnit: 0.026,
                        notchUnitX: nil
                    ),
                    style: FillStyle(eoFill: true)
                )
                .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
                .opacity(lifted ? 0 : 1)
                .scaleEffect(lifted ? 0.94 : 1)
                .blur(radius: lifted ? 7 : 0)

            // The ticket itself, lifted into the light. Animates only on
            // kind changes — keystrokes must never schedule springs.
            TicketCardContent(ticket: draft, photo: scan, cutout: cutout, lying: false)
                .frame(maxWidth: draft.kind.isEdmondson ? 250 : 305)
                .opacity(lifted ? 1 : 0)
                .scaleEffect(lifted ? 1 : 0.92)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: draft.kind)
        }
        .padding(.horizontal, 30)
    }

    // MARK: Desk

    private var desk: some View {
        VStack(spacing: 0) {
            ScrollView {
                TicketFormFields(ticket: $draft)
                    .padding(.top, 26)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            actions
        }
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26)
                .fill(Ink.background)
                .shadow(color: .black.opacity(0.5), radius: 28, y: -6)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Haptic.play(.success)
                onSave()
            } label: {
                Text("コレクションに追加")
                    .font(Typo.gothic(15, bold: true))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Ink.shu).interactive(), in: .capsule)
            .accessibilityIdentifier("confirm-save")

            HStack(spacing: 26) {
                Button {
                    Haptic.play(.tick)
                    onRetake()
                } label: {
                    Text("撮り直す")
                        .font(Typo.gothic(12))
                        .tracking(1.5)
                        .foregroundStyle(Ink.textSoft)
                        .padding(6)
                }
                .buttonStyle(.plain)

                if let onAdjust {
                    Button {
                        Haptic.play(.tick)
                        onAdjust()
                    } label: {
                        Text("切り取りを直す")
                            .font(Typo.gothic(12))
                            .tracking(1.5)
                            .foregroundStyle(Ink.textSoft)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("adjust-crop")
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: Choreography

    private func choreograph() async {
        guard !lifted else { return }
        // Let the gate's chrome finish fading before the lift.
        try? await Task.sleep(for: .milliseconds(420))
        guard !Task.isCancelled else { return }
        Haptic.play(.stamp)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            lifted = true
        }
        try? await Task.sleep(for: .milliseconds(340))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.84)) {
            deskRaised = true
        }
    }
}
