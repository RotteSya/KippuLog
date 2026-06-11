import SwiftUI

/// One spread in the magazine. A catalogue line floats above the plate
/// (collector's number left, date right); below, the route in mincho
/// with the fare on the same baseline, then the quiet caption.
struct TimelineEntry: View {
    let ticket: Ticket
    var number = 0
    var alignment: HorizontalAlignment = .leading
    var highlighted = false

    @State private var sweep: Double = -0.25

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            catalogueLine
                .frame(maxWidth: plateWidth)
                .padding(.bottom, 10)

            TicketPlate(ticket: ticket)
                .lightSweep(progress: sweep)
                .frame(maxWidth: plateWidth)
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
