import SwiftUI

/// The first page of an empty magazine — an invitation, not a void.
struct EmptyStateView: View {
    @Environment(TicketStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            GhostTicket()
                .padding(.bottom, 44)

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

/// A dashed, empty ticket outline waiting to be filled.
private struct GhostTicket: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .strokeBorder(
                Ink.textFaint,
                style: StrokeStyle(lineWidth: 1.2, dash: [7, 6])
            )
            .frame(width: 224, height: 224 / MarsTicketFace.aspect)
            .overlay {
                RouteArrow()
                    .fill(Ink.textFaint)
                    .frame(width: 44, height: 12)
            }
    }
}

#Preview {
    EmptyStateView()
        .background(Ink.background)
        .environment(TicketStore())
}
