import SwiftUI

/// The one way a ticket appears as a physical object anywhere in the app.
///
/// A captured ticket shows the **real photo**, matted like a catalogue print
/// — tight on a thin paper border, uniform corner, seeded resting tilt, the
/// shared studio shadow. A ticket with no photo (the sample collection, a
/// manual entry) falls back to the rendered `TicketArtView` plate. Both wear
/// the identical `studioFrame`, so the magazine reads as one shoot.
///
/// Store-backed: pulls the photo from `TicketStore`. For contexts without the
/// environment (share-sheet `ImageRenderer`) or with an unsaved image (the
/// capture confirm), use `TicketCardContent` directly.
struct TicketCard: View {
    @Environment(TicketStore.self) private var store
    let ticket: Ticket
    /// Upright on the hero stage; laid at a seeded angle in the magazine.
    var lying = true

    var body: some View {
        TicketCardContent(ticket: ticket, photo: store.photo(for: ticket), lying: lying)
    }
}

/// Pure, environment-free card — explicit photo (nil → rendered plate).
struct TicketCardContent: View {
    let ticket: Ticket
    let photo: UIImage?
    var lying = true

    var body: some View {
        Group {
            if let photo {
                MattedPhoto(ticket: ticket, photo: photo)
            } else {
                TicketArtView(ticket: ticket)
            }
        }
        .studioFrame(seed: ticket.styleSeed, lying: lying)
    }
}

/// Shared mat geometry, so the stage (reflection offset) and the card agree.
enum CardMetrics {
    /// Mat inset as a fraction of card width.
    static let matInset: CGFloat = 0.035

    /// Photo aspect (w/h), clamped so neither a panorama nor a tall crop
    /// breaks the page rhythm.
    static func clampedPhotoAspect(_ raw: CGFloat) -> CGFloat {
        min(max(raw, 1.05), 2.1)
    }

    /// Overall card aspect (w/h) for a matted photo of the given photo aspect.
    static func cardAspect(photoAspect raw: CGFloat) -> CGFloat {
        let photoH = (1 - matInset * 2) / clampedPhotoAspect(raw)
        return 1 / (photoH + matInset * 2)
    }
}

/// A photographed ticket mounted on a paper mat. The photo keeps its true
/// aspect (clamped to a sane band so an un-cropped frame can't dominate the
/// page); the mat carries the same warm paper and faint grain as the plates.
struct MattedPhoto: View {
    let ticket: Ticket
    let photo: UIImage

    private let corner: CGFloat = 7

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let inset = w * CardMetrics.matInset
            ZStack {
                // Paper mat — same stock world as the rendered plates.
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color(hex: 0xF3EEE3))
                    .visualEffect { [seed = ticket.styleSeed] content, geo in
                        content.colorEffect(
                            ShaderLibrary.ticketPaper(
                                .float2(geo.size),
                                .color(Color.clear),
                                .float(Float(seed % 9973)),
                                .float(0)
                            )
                        )
                    }

                // The photograph, inset on the mat.
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: w - inset * 2,
                        height: (w - inset * 2) / photoAspect
                    )
                    .clipShape(RoundedRectangle(cornerRadius: corner * 0.6))
                    .overlay {
                        // Hairline so the print reads as mounted, not floating.
                        RoundedRectangle(cornerRadius: corner * 0.6)
                            .stroke(Color.black.opacity(0.14), lineWidth: 0.6)
                    }
                    // A whisper of inner shadow where print meets mat.
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: corner)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.7)
            }
        }
        .aspectRatio(CardMetrics.cardAspect(photoAspect: rawAspect), contentMode: .fit)
    }

    private var rawAspect: CGFloat {
        ticket.photoAspect ?? (photo.size.height > 0 ? photo.size.width / photo.size.height : MarsTicketFace.aspect)
    }

    private var photoAspect: CGFloat {
        CardMetrics.clampedPhotoAspect(rawAspect)
    }
}

#Preview("Plate fallback") {
    TicketCard(ticket: Ticket.samples[1])
        .frame(width: 300)
        .padding(40)
        .background(Ink.background)
        .environment(TicketStore())
}
