import SwiftUI

/// The one way a ticket appears as a physical object anywhere in the app.
///
/// No frames, no mats — the ticket itself is the object:
/// 1. **Cutout** — the subject-lifted ticket (alpha PNG): its true shape
///    rests on the page, shadow tracing its own silhouette.
/// 2. **Scan** — a tight perspective-corrected capture shown full-bleed
///    with real ticket corners and a paper-thickness catch-light.
/// 3. **Plate** — the data-drawn fallback for tickets with no photo
///    (samples, manual entries).
/// All three wear the identical `studioFrame`, so the magazine reads as
/// one shoot under one lamp.
///
/// Store-backed; for contexts without the environment (share-sheet
/// `ImageRenderer`) or with unsaved images (capture confirm), use
/// `TicketCardContent` directly.
struct TicketCard: View {
    @Environment(TicketStore.self) private var store
    let ticket: Ticket
    /// Upright on the hero stage; laid at a seeded angle in the magazine.
    var lying = true
    /// Passing gloss (−1…1): the lamp's sweep as the page scrolls.
    var gloss: CGFloat = 0

    var body: some View {
        TicketCardContent(
            ticket: ticket,
            photo: store.photo(for: ticket),
            cutout: store.cutout(for: ticket),
            lying: lying,
            gloss: gloss
        )
    }
}

/// Pure, environment-free card — explicit images (both nil → plate).
struct TicketCardContent: View {
    let ticket: Ticket
    let photo: UIImage?
    var cutout: UIImage? = nil
    var lying = true
    var gloss: CGFloat = 0

    var body: some View {
        Group {
            if let cutout {
                // The lifted ticket — its own silhouette is the card.
                Image(uiImage: cutout)
                    .resizable()
                    .scaledToFit()
            } else if let photo {
                ScanObject(photo: photo, aspect: scanAspect(photo))
            } else {
                TicketArtView(ticket: ticket)
            }
        }
        // The sweep lives INSIDE the studio frame: gloss on the paper
        // face only, never on the shadows around it (a colorEffect over
        // a shadowed layer smears white halos through the soft edges).
        .modifier(PassingGloss(gloss: gloss))
        .studioFrame(seed: ticket.styleSeed, lying: lying)
    }

    /// The photo's true aspect — the ticket is always shown whole, never
    /// cropped to a layout box (the magazine, the stage and the album all
    /// read the same real shape).
    private func scanAspect(_ photo: UIImage) -> CGFloat {
        ticket.photoAspect
            ?? (photo.size.height > 0 ? photo.size.width / photo.size.height : MarsTicketFace.aspect)
    }
}

/// The scroll's light sweep, applied to the bare card face. Skips the
/// shader entirely at rest so still pages pay nothing.
private struct PassingGloss: ViewModifier {
    var gloss: CGFloat

    func body(content: Content) -> some View {
        if gloss == 0 {
            content
        } else {
            content.visualEffect { [gloss] view, proxy in
                view.colorEffect(
                    ShaderLibrary.holoSheen(
                        .float2(proxy.size),
                        .float2(Float(gloss), 0),
                        .float(0.11)
                    )
                )
            }
        }
    }
}

/// A tight scan shown as the ticket itself: true corners (≈1 mm), a
/// hairline of caught light along the top edge for paper thickness, and
/// nothing else — the photograph is the surface.
struct ScanObject: View {
    let photo: UIImage
    let aspect: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            // Real MARS corner ≈ 1mm on an 85mm ticket.
            let corner = max(3, w * 0.013)
            Image(uiImage: photo)
                .resizable()
                .scaledToFit()
                .frame(width: w, height: w / aspect)
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay {
                    // Paper-thickness light: bright along the top edge,
                    // a breath of seat shadow at the bottom. No outline.
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.55), location: 0),
                                    .init(color: .white.opacity(0.0), location: 0.18),
                                    .init(color: .black.opacity(0.0), location: 0.82),
                                    .init(color: .black.opacity(0.18), location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: max(0.7, w * 0.0024)
                        )
                        .blendMode(.overlay)
                }
        }
        .aspectRatio(aspect, contentMode: .fit)
    }
}

#Preview("Plate fallback") {
    TicketCard(ticket: Ticket.samples[1])
        .frame(width: 300)
        .padding(40)
        .background(Ink.background)
        .environment(TicketStore())
}
