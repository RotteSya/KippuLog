import SwiftUI

/// The reveal — the raw scan flips over into the understood, re-set
/// plate; the journey's facts wait below, every one of them editable.
struct ConfirmTicketView: View {
    let scan: UIImage
    @Binding var draft: Ticket
    var onSave: () -> Void
    var onRetake: () -> Void

    @State private var revealAngle: Double = 0
    @State private var fieldsShown = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    reveal
                        .padding(.top, 26)
                        .padding(.bottom, 30)

                    if fieldsShown {
                        TicketFormFields(ticket: $draft)
                            .padding(.horizontal, 28)
                            .transition(.opacity.combined(with: .offset(y: 24)))
                    }

                    Spacer(minLength: 24)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            actions
        }
        .background(Ink.background)
        .task { await choreograph() }
    }

    // MARK: Reveal

    private var reveal: some View {
        ZStack {
            // Raw scan (front until the flip passes 90°).
            Image(uiImage: scan)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: 320)
                .aspectRatio(MarsTicketFace.aspect, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .opacity(revealAngle < 90 ? 1 : 0)

            // The understood plate (back face, pre-rotated).
            TicketPlate(ticket: draft, lying: false)
                .frame(maxWidth: draft.kind.isEdmondson ? 250 : 320)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(revealAngle >= 90 ? 1 : 0)
        }
        .rotation3DEffect(.degrees(revealAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: draft)
        .padding(.horizontal, 30)
    }

    private var actions: some View {
        VStack(spacing: 12) {
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
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }

    // MARK: Choreography

    private func choreograph() async {
        guard revealAngle == 0 else { return }
        try? await Task.sleep(for: .milliseconds(350))
        Haptic.play(.stamp)
        withAnimation(.spring(response: 0.75, dampingFraction: 0.78)) {
            revealAngle = 180
        }
        try? await Task.sleep(for: .milliseconds(420))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            fieldsShown = true
        }
    }
}
