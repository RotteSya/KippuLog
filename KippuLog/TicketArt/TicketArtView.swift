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

// MARK: - The collector's stock

nonisolated extension Ticket {
    /// The stock this ticket was printed on, for the paper shader:
    /// 0 coated MARS reel ・ 1 edmondson card ・ 2 private-rail pulp.
    var paperMaterial: Float {
        if kind.isEdmondson { return 1 }
        switch brand {
        case .jrEast, .jrCentral, .jrWest, .jrHokkaido, .jrKyushu, .jrShikoku, .other:
            return 0
        default:
            return 2
        }
    }

    /// Years in the shoebox, 0…1 across ~2.5 years — bucketed by month so
    /// the patina never shifts under the reader's eyes.
    var paperAge: Float {
        guard let travelDate else { return 0 }
        let months = Calendar(identifier: .gregorian)
            .dateComponents([.month], from: travelDate, to: .now).month ?? 0
        return min(1, Float(max(0, months)) / 30)
    }
}

/// Studio presentation applied identically to every object in the
/// collection — the real photo *and* the rendered fallback plate — so the
/// whole magazine reads as one shoot under one lamp: paired key light and a
/// seeded "laid on the table" rotation.
struct StudioFrame: ViewModifier {
    let seed: UInt64
    /// Disable for the hero stage, where the object stands upright.
    var lying = true

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1.5)   // contact
            .shadow(color: .black.opacity(0.13), radius: 20, y: 11)   // ambient key
            .rotationEffect(.degrees(lying ? restingAngle : 0))
    }

    private var restingAngle: Double {
        var rng = SeededRandom(seed ^ 0x71E)
        return rng.double(in: -2.1...2.1)
    }
}

extension View {
    /// Seat this object under the studio lamp (see `StudioFrame`).
    func studioFrame(seed: UInt64, lying: Bool = true) -> some View {
        modifier(StudioFrame(seed: seed, lying: lying))
    }
}

/// The rendered plate, framed. Kept for tickets with no photo (samples /
/// manual entry); captured tickets show their real photo via `TicketCard`.
struct TicketPlate: View {
    let ticket: Ticket
    var lying = true

    var body: some View {
        TicketArtView(ticket: ticket)
            .studioFrame(seed: ticket.styleSeed, lying: lying)
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
