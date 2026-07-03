import SwiftUI

/// One ticket under the lamp: the real photographed ticket sits lit and
/// still, its paper stock and cut edges catching the studio light — the
/// lift's flights carry the motion, the exhibit itself is calm.
///
/// Below it, the placard: the curator's reading of the journey. A
/// catalogue line, the route drawn as a line of track, the fare set in
/// serif, and the torn 半券 holding the collector's handwritten note —
/// nothing the ticket already prints is repeated as a table.
struct StagePage: View {
    @Environment(TicketStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ticketID: UUID
    var shredProgress: Double = 0
    /// Departure: facts dissolve while the ticket holds the light.
    var departing = false

    /// The placard clock — 0 at mount, swept to 1 as the exhibit
    /// settles; every element below the hero reads its own window.
    @State private var placardT: CGFloat = 0

    var body: some View {
        if let ticket = store.tickets.first(where: { $0.id == ticketID }) {
            content(ticket)
                // Seats are recycled as the rail slides — the page's
                // state (note draft, placard clock) belongs to the
                // exhibit, not the seat.
                .id(ticketID)
        } else {
            Color.clear
        }
    }

    private func content(_ ticket: Ticket) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                hero(ticket)
                    .padding(.top, 64)
                    .padding(.bottom, 56)

                Group {
                    catalogLine(ticket)
                        .cascade(placardT, 0.00...0.22)
                        .padding(.bottom, 34)

                    JourneyLine(ticket: ticket, progress: placardT)

                    if let price = ticket.price {
                        fareBlock(price)
                            .cascade(placardT, 0.68...0.94)
                            .padding(.top, 30)
                    }

                    MemoSlip(ticket: ticket)
                        .cascade(placardT, 0.76...1.00, rise: 12)
                        .padding(.top, 38)
                }
                .frame(maxWidth: 318)
                .padding(.horizontal, 30)
                // The page clears its throat while the gate takes the
                // ticket — and again when the ticket departs for home.
                .opacity(departing ? 0 : 1 - min(1, shredProgress * 2.6))
                .animation(.easeOut(duration: 0.16), value: departing)

                Spacer(minLength: 96)
            }
        }
        // The shred interpolates HERE, inside the hosted tree — a
        // `withAnimation` outside the rail's hosting boundary arrives as
        // a bare 0→1 jump, so the page owns its own tearing clock.
        .animation(.easeIn(duration: 0.95), value: shredProgress)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            guard placardT == 0 else { return }
            guard !reduceMotion else {
                placardT = 1
                return
            }
            // The lift seats the hero first; the curator lays the cards
            // out once the exhibit holds still.
            withAnimation(.easeInOut(duration: 1.1).delay(0.42)) {
                placardT = 1
            }
        }
    }

    // MARK: Hero

    private func heroWidth(_ ticket: Ticket) -> CGFloat {
        ticket.kind.isEdmondson ? 290 : 352
    }

    private func heroCard(_ ticket: Ticket) -> some View {
        TicketCardContent(
            ticket: ticket,
            photo: store.photo(for: ticket),
            cutout: store.cutout(for: ticket),
            lying: false
        )
        .frame(maxWidth: heroWidth(ticket))
        // No static sheen on the exhibit: a colorEffect layer under
        // `.shadow` rasterises into faint terraced halos around the card
        // (visible in the dark room), and a frozen gloss band adds ~2%
        // at most. The paper stock and cut edges carry the light; the
        // lift's flight card is bare for the same reason — identical
        // pixels at handover.
    }

    /// The exhibit under glass — lit, grounded, and still. The lift's
    /// open/close flights carry all the drama; the seated ticket is calm,
    /// its paper stock and cut edges doing the work (no drag, no mirror).
    private func hero(_ ticket: Ticket) -> some View {
        heroCard(ticket)
            .shadow(color: .black.opacity(0.50), radius: 24, y: 18)
            .shredFall(progress: shredProgress, seed: ticket.styleSeed)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("切符 \(ticket.routeText)")
            .accessibilityIdentifier("stage-hero")
    }

    // MARK: Placard

    /// 収蔵 No. 008 ・・・・・・・・ 6.7 SUN — the exhibit's catalogue line.
    private func catalogLine(_ ticket: Ticket) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("収蔵")
                .font(Typo.gothic(9.5, bold: true))
                .tracking(2.5)
                .foregroundStyle(Stage.faintText)
            if let number = store.catalogNumbers[ticket.id] {
                Text(String(format: "No. %03d", number))
                    .font(Typo.serifFigure(11, weight: .regular))
                    .foregroundStyle(Stage.softText)
            }
            DotLeader(color: Stage.faintText.opacity(0.55))
            if let date = ticket.travelDate {
                Text(Editorial.shortDate(date))
                    .font(Typo.caption(9.5))
                    .tracking(2.5)
                    .foregroundStyle(Stage.faintText)
            }
        }
    }

    /// The fare, set like a placard figure — one hairline, one label,
    /// one serif number.
    private func fareBlock(_ price: Int) -> some View {
        VStack(spacing: 13) {
            Rectangle()
                .fill(Stage.rule)
                .frame(height: 0.7)
            HStack(alignment: .firstTextBaseline) {
                Text("運賃")
                    .font(Typo.gothic(9.5, bold: true))
                    .tracking(2.5)
                    .foregroundStyle(Stage.faintText)
                Spacer()
                Text(Editorial.yen(price))
                    .font(Typo.serifFigure(22, weight: .regular))
                    .foregroundStyle(Stage.text)
            }
        }
    }
}

// MARK: Cascade

/// Windowed arrival off one clock: the element fades and rises inside
/// its own slice of the placard's sweep. Animatable, so the window is
/// honoured per frame instead of being flattened into one long fade.
private struct CascadeIn: ViewModifier, Animatable {
    var progress: CGFloat
    var window: ClosedRange<CGFloat>
    var rise: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let span = max(window.upperBound - window.lowerBound, 0.0001)
        let t = min(max((progress - window.lowerBound) / span, 0), 1)
        // Ease the landing so each element settles, never snaps.
        let eased = 1 - (1 - t) * (1 - t)
        return content
            .opacity(Double(eased))
            .offset(y: (1 - eased) * rise)
    }
}

extension View {
    func cascade(_ progress: CGFloat, _ window: ClosedRange<CGFloat>, rise: CGFloat = 8) -> some View {
        modifier(CascadeIn(progress: progress, window: window, rise: rise))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
