import SwiftUI
import UniformTypeIdentifiers

/// A ticket exported as a studio print — rendered lazily when the user
/// actually shares (Transferable keeps it off the hot path). The photo is
/// captured up front (in the stage, where the store is available) so the
/// `ImageRenderer` needs no environment.
struct TicketShareCard: Transferable {
    let ticket: Ticket
    let photo: UIImage?

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            try await card.pngData()
        }
        .suggestedFileName { "kippu-\($0.ticket.routeText).png" }
    }

    @MainActor
    private func pngData() throws -> Data {
        let renderer = ImageRenderer(content: ShareCardView(ticket: ticket, photo: photo))
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: 540, height: 675)
        guard let data = renderer.uiImage?.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}

/// 4:5 studio print — the ticket centered, route below, quiet colophon.
struct ShareCardView: View {
    let ticket: Ticket
    var photo: UIImage?

    var body: some View {
        ZStack {
            Ink.studio

            VStack(spacing: 0) {
                Spacer()

                TicketCardContent(ticket: ticket, photo: photo, lying: false)
                    .frame(maxWidth: ticket.kind.isEdmondson ? 360 : 430)
                    .padding(.horizontal, 48)

                Spacer().frame(height: 52)

                Text(ticket.routeText)
                    .font(Typo.mincho(31))
                    .tracking(3)
                    .foregroundStyle(Stage.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 40)

                if let date = ticket.travelDate {
                    Text(Editorial.shortDate(date))
                        .font(Typo.caption(13))
                        .tracking(3)
                        .foregroundStyle(Stage.faintText)
                        .padding(.top, 10)
                }

                Spacer()

                VStack(spacing: 8) {
                    Rectangle()
                        .fill(Stage.rule)
                        .frame(width: 40, height: 1)
                    Text("きっぷログ")
                        .font(Typo.mincho(12))
                        .tracking(5)
                        .foregroundStyle(Stage.faintText)
                }
                .padding(.bottom, 32)
            }
        }
        .frame(width: 540, height: 675)
    }
}

#Preview {
    ShareCardView(ticket: Ticket.samples[1], photo: nil)
}
