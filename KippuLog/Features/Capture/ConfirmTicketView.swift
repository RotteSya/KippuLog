import SwiftUI

/// The reveal — the raw scan flips into the understood plate under the
/// studio lamp, while a paper desk rises from below carrying the form.
struct ConfirmTicketView: View {
    let scan: UIImage
    @Binding var draft: Ticket
    var onSave: () -> Void
    var onRetake: () -> Void

    @State private var revealAngle: Double = 0
    @State private var deskRaised = false

    var body: some View {
        ZStack {
            StudioBackdrop(center: UnitPoint(x: 0.5, y: 0.20), radius: 0.8, warmth: 0.5)

            VStack(spacing: 0) {
                reveal
                    .padding(.top, 38)
                    .padding(.bottom, 26)

                desk
                    .offset(y: deskRaised ? 0 : 420)
            }
        }
        .task { await choreograph() }
    }

    // MARK: Reveal

    private var reveal: some View {
        ZStack {
            // Raw scan (front until the flip passes 90°).
            Image(uiImage: scan)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: 300)
                .aspectRatio(MarsTicketFace.aspect, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .opacity(revealAngle < 90 ? 1 : 0)

            // The understood plate (back face, pre-rotated).
            TicketPlate(ticket: draft, lying: false)
                .frame(maxWidth: draft.kind.isEdmondson ? 240 : 300)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(revealAngle >= 90 ? 1 : 0)
        }
        .rotation3DEffect(.degrees(revealAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .scaleEffect(1 - 0.03 * abs(sin(revealAngle * .pi / 180)))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 14)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: draft)
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
        guard revealAngle == 0 else { return }
        try? await Task.sleep(for: .milliseconds(320))
        Haptic.play(.stamp)
        withAnimation(.spring(response: 0.75, dampingFraction: 0.78)) {
            revealAngle = 180
        }
        try? await Task.sleep(for: .milliseconds(380))
        withAnimation(.spring(response: 0.6, dampingFraction: 0.84)) {
            deskRaised = true
        }
    }
}
