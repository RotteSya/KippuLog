import SwiftUI

/// Debug shelf — every sample plate under the studio lamp.
/// Reached with `-uiScreen gallery`; not part of the product flow.
struct ArtGalleryView: View {
    /// Which half of the samples to show (screenshot paging).
    var page = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                ForEach(visibleSamples) { ticket in
                    VStack(spacing: 10) {
                        TicketPlate(ticket: ticket)
                            .frame(maxWidth: ticket.kind.isEdmondson ? 250 : 320)
                        Text("\(ticket.routeText) — \(ticket.brand.displayName)")
                            .font(Typo.gothic(11))
                            .foregroundStyle(Ink.textSoft)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        }
        .background(Ink.background)
    }

    private var visibleSamples: [Ticket] {
        let all = Ticket.samples
        return page == 0 ? Array(all.prefix(4)) : Array(all.suffix(from: 4))
    }
}

/// Single plate, full width — for close inspection of print details.
struct ArtHeroView: View {
    var body: some View {
        VStack(spacing: 48) {
            TicketPlate(ticket: Ticket.samples[1], lying: false)
            TicketPlate(ticket: Ticket.samples[5], lying: false)
                .frame(maxWidth: 260)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.background)
    }
}

#Preview {
    ArtGalleryView()
}
