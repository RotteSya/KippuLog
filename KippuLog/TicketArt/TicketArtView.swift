import SwiftUI

/// The studio renderer's front door — picks the right stock for the kind.
/// Pure function of `Ticket`; no photo, no state.
struct TicketArtView: View {
    let ticket: Ticket

    var body: some View {
        if ticket.kind.isEdmondson {
            EdmondsonTicketFace(ticket: ticket)
        } else {
            MarsTicketFace(ticket: ticket)
        }
    }

    /// Aspect ratio of this ticket's stock.
    static func aspect(for kind: TicketKind) -> CGFloat {
        kind.isEdmondson ? EdmondsonTicketFace.aspect : MarsTicketFace.aspect
    }
}

/// Studio presentation: identical key light (paired shadows) and a
/// seeded "laid on the table" rotation. Every plate in the magazine
/// is photographed under the same lamp.
struct TicketPlate: View {
    let ticket: Ticket
    /// Disable for the hero stage, where the ticket stands upright.
    var lying = true

    var body: some View {
        TicketArtView(ticket: ticket)
            .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
            .shadow(color: .black.opacity(0.16), radius: 16, y: 12)
            .rotationEffect(.degrees(lying ? restingAngle : 0))
    }

    private var restingAngle: Double {
        var rng = SeededRandom(ticket.styleSeed ^ 0x71E)
        return rng.double(in: -2.1...2.1)
    }
}

#Preview("MARS") {
    TicketPlate(ticket: Ticket.samples[1])
        .padding(40)
        .background(Ink.background)
}

#Preview("Edmondson") {
    TicketPlate(ticket: Ticket.samples[5])
        .padding(40)
        .background(Ink.background)
}
