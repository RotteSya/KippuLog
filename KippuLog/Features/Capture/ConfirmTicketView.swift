import SwiftUI

/// The reveal — the punched scan settles into its studio mat under the
/// lamp, then a paper desk rises from below carrying the form.
struct ConfirmTicketView: View {
    let scan: UIImage
    @Binding var draft: Ticket
    var onSave: () -> Void
    var onRetake: () -> Void

    @State private var framed = false
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
            // The bare scan, briefly, before the mat closes around it.
            Image(uiImage: scan)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: draft.kind.isEdmondson ? 240 : 300)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.5), radius: 20, y: 14)
                .opacity(framed ? 0 : 1)
                .scaleEffect(framed ? 1.05 : 1)

            // The framed studio card — the real ticket, matted.
            TicketCardContent(ticket: draft, photo: scan, lying: false)
                .frame(maxWidth: draft.kind.isEdmondson ? 240 : 300)
                .opacity(framed ? 1 : 0)
                .scaleEffect(framed ? 1 : 0.95)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: draft)
        }
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
        guard !framed else { return }
        try? await Task.sleep(for: .milliseconds(340))
        Haptic.play(.stamp)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
            framed = true
        }
        try? await Task.sleep(for: .milliseconds(360))
        withAnimation(.spring(response: 0.6, dampingFraction: 0.84)) {
            deskRaised = true
        }
    }
}
