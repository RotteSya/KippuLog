import SwiftUI

/// One spread in the magazine, set like a line in a great table of
/// contents: the catalogue number leads across a dotted leader to the
/// date, the plate sits on the page's one strong left axis, and the
/// route runs its own leader out to the fare. Small cards keep their
/// real-world scale — the leaders span the full column, so an edmondson
/// stub reads as deliberately small, not lost.
///
/// The card itself is the zoom-transition source — tapping anywhere on
/// the entry (or pinching the card outward) sends the *ticket* flying
/// into its stage, not the surrounding text.
struct TimelineEntry: View {
    @Environment(LiftEngine.self) private var lift: LiftEngine?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ticket: Ticket
    var number = 0
    var onOpen: () -> Void = {}

    @State private var pinchScale: CGFloat = 1
    @State private var pinchFired = false
    /// The card's centre as a fraction of the screen's height — drives
    /// the passing gloss and the plate's gentle parallax.
    @State private var screenPlace: CGFloat = 0.5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            catalogueLine
                .padding(.bottom, 12)

            plate
                .padding(.bottom, 18)

            routeLine
                .padding(.bottom, 7)

            if let caption = captionLine {
                Text(caption)
                    .font(Typo.caption(10))
                    .tracking(1.6)
                    .foregroundStyle(Ink.textFaint)
            }
        }
        .scrollTransition(.interactive) { content, phase in
            content.opacity(phase.isIdentity ? 1 : 0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptic.play(.tick)
            onOpen()
        }
        .simultaneousGesture(pinchToOpen)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline-entry-\(ticket.routeText)")
    }

    // MARK: The plate

    /// The ticket, alive on the page: a soft gloss travels its face as
    /// it passes the reader (the lamp is fixed; the page moves), and the
    /// plate hangs a breath behind the type — paper has more mass than
    /// ink. Both go still under Reduce Motion.
    private var plate: some View {
        TicketCard(ticket: ticket, gloss: reduceMotion ? 0 : (0.5 - screenPlace) * 0.9)
            .offset(y: parallax)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                // The slot's printed place — where the lift lands.
                // `.offset` is a render shift the geometry can't see, so
                // fold it in by hand: flights must land on pixels.
                lift?.homes["t-\(ticket.id)"] = frame.offsetBy(dx: 0, dy: parallax)
                let screen = UIScreen.main.bounds.height
                if screen > 0 {
                    screenPlace = frame.midY / screen
                }
            }
            .scaleEffect(pinchScale, anchor: .center)
            .frame(maxWidth: plateWidth, alignment: .leading)
    }

    private var parallax: CGFloat {
        reduceMotion ? 0 : (0.5 - screenPlace) * 9
    }

    /// Pinch a card outward and it grows in your fingers, then commits to
    /// the stage — the timeline *is* zoomable.
    private var pinchToOpen: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let m = value.magnification
                pinchScale = min(max(m, 0.96), 1.22)
                if m > 1.16, !pinchFired {
                    pinchFired = true
                    Haptic.play(.tick)
                    onOpen()
                }
            }
            .onEnded { _ in
                pinchFired = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    pinchScale = 1
                }
            }
    }

    // MARK: Lines

    /// No. 008 ・・・・・・・・・・・・ 6.7 SUN
    private var catalogueLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(String(format: "No. %03d", number))
                .font(Typo.serifFigure(10, weight: .regular))
                .foregroundStyle(Ink.textFaint)
            DotLeader(color: Ink.textFaint.opacity(0.55))
            if let date = ticket.travelDate {
                Text(Editorial.shortDate(date))
                    .font(Typo.caption(9))
                    .tracking(2)
                    .foregroundStyle(Ink.textFaint)
            }
        }
    }

    /// 新宿 → 箱根湯本 ・・・・・・・ ¥2,470
    private var routeLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(ticket.routeText)
                .font(Typo.mincho(20))
                .tracking(1.5)
                .foregroundStyle(Ink.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
            if ticket.price != nil {
                DotLeader(color: Ink.textFaint.opacity(0.55))
            }
            if let price = ticket.price {
                Text(Editorial.yen(price))
                    .font(Typo.serifFigure(12.5, weight: .regular))
                    .foregroundStyle(Ink.textSoft)
            }
        }
    }

    private var captionLine: String? {
        var parts: [String] = []
        if let train = ticket.trainName { parts.append(train) }
        parts.append(ticket.brand.displayName)
        return parts.isEmpty ? nil : parts.joined(separator: " ・ ")
    }

    /// MARS plates fill most of the column; edmondson cards keep their
    /// real-world smaller scale.
    private var plateWidth: CGFloat {
        ticket.kind.isEdmondson ? 236 : 318
    }
}
