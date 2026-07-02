import SwiftUI

/// One spread in the magazine. A catalogue line floats above the plate
/// (collector's number left, date right); below, the route in mincho
/// with the fare on the same baseline, then the quiet caption.
///
/// The card itself is the zoom-transition source — tapping anywhere on the
/// entry (or pinching the card outward) sends the *ticket* flying into its
/// stage, not the surrounding text.
struct TimelineEntry: View {
    @Environment(LiftEngine.self) private var lift: LiftEngine?
    let ticket: Ticket
    var number = 0
    var alignment: HorizontalAlignment = .leading
    var highlighted = false
    var onOpen: () -> Void = {}

    @State private var sweep: Double = -0.25
    @State private var pinchScale: CGFloat = 1
    @State private var pinchFired = false

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            catalogueLine
                .frame(maxWidth: plateWidth)
                .padding(.bottom, 10)

            TicketCard(ticket: ticket)
                .lightSweep(progress: sweep)
                .frame(maxWidth: plateWidth)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    // The slot's printed place — where the lift lands.
                    lift?.homes["t-\(ticket.id)"] = frame
                }
                .scaleEffect(pinchScale, anchor: .center)
                .scrollTransition(.interactive) { content, phase in
                    content
                        .offset(y: phase.value * -14)
                        .rotation3DEffect(
                            .degrees(phase.value * 2.4),
                            axis: (x: 1, y: 0, z: 0),
                            perspective: 0.4
                        )
                        .opacity(phase.isIdentity ? 1 : 0.65)
                }
                .onChange(of: highlighted) { _, isOn in
                    guard isOn else { return }
                    sweep = -0.25
                    withAnimation(.easeInOut(duration: 1.1)) {
                        sweep = 1.25
                    }
                }
                .padding(.bottom, 16)

            HStack(alignment: .firstTextBaseline) {
                Text(ticket.routeText)
                    .font(Typo.mincho(20))
                    .tracking(1.5)
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 12)
                if let price = ticket.price {
                    Text(Editorial.yen(price))
                        .font(Typo.serifFigure(12.5, weight: .regular))
                        .foregroundStyle(Ink.textSoft)
                }
            }
            .frame(maxWidth: plateWidth)
            .padding(.bottom, 6)

            if let caption = captionLine {
                Text(caption)
                    .font(Typo.caption(10))
                    .tracking(1.6)
                    .foregroundStyle(Ink.textFaint)
                    .frame(maxWidth: plateWidth, alignment: frameTextAlignment)
            }
        }
        .scrollTransition(.interactive) { content, phase in
            content.opacity(phase.isIdentity ? 1 : 0.5)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptic.play(.tick)
            onOpen()
        }
        .simultaneousGesture(pinchToOpen)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline-entry-\(ticket.routeText)")
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

    private var catalogueLine: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(String(format: "No. %03d", number))
                .font(Typo.serifFigure(10, weight: .regular))
                .foregroundStyle(Ink.textFaint)
            Spacer(minLength: 12)
            if let date = ticket.travelDate {
                Text(Editorial.shortDate(date))
                    .font(Typo.caption(9))
                    .tracking(2)
                    .foregroundStyle(Ink.textFaint)
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

    private var frameAlignment: Alignment {
        alignment == .leading ? .leading : .trailing
    }

    private var frameTextAlignment: Alignment {
        alignment == .leading ? .leading : .trailing
    }
}
