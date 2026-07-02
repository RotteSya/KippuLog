import SwiftUI

/// The first page of an empty magazine — an invitation, not a void.
/// It wears the same masthead as the filled magazine, so the welcome's
/// lights-up lands on a real cover, not a bare room.
struct EmptyStateView: View {
    @Environment(TicketStore.self) private var store
    /// The colophon door — the only cover corner an empty issue needs.
    var onOkuzuke: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            MagazineMasthead(onOkuzuke: onOkuzuke)
                .padding(.top, 22)

            Spacer()

            BlankStock()
                .padding(.bottom, 46)

            Text("まだ切符がありません")
                .font(Typo.mincho(20))
                .tracking(3)
                .foregroundStyle(Ink.text)
                .padding(.bottom, 14)

            Text("下のボタンから、最初の一枚を。")
                .font(Typo.gothic(13))
                .tracking(1)
                .foregroundStyle(Ink.textSoft)

            Spacer()

            Button {
                Haptic.play(.stamp)
                withAnimation(.spring(duration: 0.6)) {
                    store.addSamples()
                }
            } label: {
                Text("サンプルの旅を見てみる")
                    .font(Typo.gothic(12, bold: true))
                    .tracking(1.5)
                    .foregroundStyle(Ink.textSoft)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .overlay {
                        Capsule().stroke(Ink.rule, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 110)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Blank MARS stock — guilloche printed, nothing else yet. The first
/// page of the collection is real paper waiting for a journey.
private struct BlankStock: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(hex: 0xF2EDE1))
            .visualEffect { content, geo in
                content.colorEffect(
                    ShaderLibrary.ticketPaper(
                        .float2(geo.size),
                        .color(Color(hex: 0x9AA89E).opacity(0.13)),
                        .float(412),
                        .float(0),
                        .float(0),
                        .float(0)
                    )
                )
            }
            .frame(width: 232, height: 232 / MarsTicketFace.aspect)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1.5)
            .shadow(color: .black.opacity(0.13), radius: 20, y: 11)
            .rotationEffect(.degrees(-2))
    }
}

#Preview {
    EmptyStateView()
        .background(Ink.background)
        .environment(TicketStore())
}
