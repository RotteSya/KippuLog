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
    var onSave: () -> Void
    var onRetake: () -> Void

    @State private var lifted = false
    @State private var deskRaised = false
    @State private var keyboardUp = false

    var body: some View {
        ZStack {
            StudioBackdrop(center: UnitPoint(x: 0.5, y: 0.20), radius: 0.8, warmth: 0.5)

            VStack(spacing: 0) {
                if !keyboardUp {
                    reveal
                        .padding(.top, 38)
                        .padding(.bottom, 26)
                        .transition(
                            .scale(scale: 0.8, anchor: .top)
                                .combined(with: .opacity)
                        )
                }

                desk
                    .offset(y: deskRaised ? 0 : 420)
                    .padding(.top, keyboardUp ? 10 : 0)
            }
        }
        .task { await choreograph() }
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
            // The raw frame — recedes and blurs away as the ticket lifts.
            Image(uiImage: scan)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 300, maxHeight: 230)
                .clipShape(RoundedRectangle(cornerRadius: 5))
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
        .frame(maxHeight: 250)
        .padding(.horizontal, 30)
    }

    // MARK: Desk

    private var desk: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Ink.rule)
                        .frame(width: 34, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 18)

                    TicketFormFields(ticket: $draft)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 16)
                }
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
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: Choreography

    private func choreograph() async {
        guard !lifted else { return }
        try? await Task.sleep(for: .milliseconds(340))
        Haptic.play(.stamp)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            lifted = true
        }
        try? await Task.sleep(for: .milliseconds(340))
        withAnimation(.spring(response: 0.6, dampingFraction: 0.84)) {
            deskRaised = true
        }
    }
}
