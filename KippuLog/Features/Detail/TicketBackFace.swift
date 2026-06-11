import SwiftUI

/// The back of the plate — the original capture, kept like a negative
/// behind the print. Samples (no photo) show a 見本 stamp instead.
struct TicketBackFace: View {
    let ticket: Ticket
    let photo: UIImage?

    var body: some View {
        Group {
            if let photo {
                Color.clear
                    .aspectRatio(TicketArtView.aspect(for: ticket.kind), contentMode: .fit)
                    .overlay {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.white.opacity(0.12), lineWidth: 0.8)
                    }
            } else {
                emptyBack
            }
        }
    }

    private var emptyBack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: 0x24201A))
            LatticePattern(brand: ticket.brand, seed: ticket.styleSeed)
                .opacity(0.25)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(spacing: 10) {
                Text(ticket.isSample ? "見　本" : "写真なし")
                    .font(Typo.mincho(26))
                    .tracking(6)
                    .foregroundStyle(Ink.shu.opacity(0.75))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Ink.shu.opacity(0.55), lineWidth: 1.4)
                    }
                    .rotationEffect(.degrees(-7))
                Text(ticket.isSample ? "サンプルの切符です" : "原本の写真はありません")
                    .font(Typo.gothic(11))
                    .foregroundStyle(Stage.faintText)
            }
        }
        .aspectRatio(TicketArtView.aspect(for: ticket.kind), contentMode: .fit)
    }
}

#Preview {
    ZStack {
        Ink.studio.ignoresSafeArea()
        TicketBackFace(ticket: Ticket.samples[0], photo: nil)
            .frame(width: 340)
    }
}
