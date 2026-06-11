import SwiftUI

/// One spread in the magazine: a plate under the studio lamp with its
/// editorial caption, alternating left and right down the page.
/// Edmondson cards keep their true smaller physical scale.
struct TimelineEntry: View {
    let ticket: Ticket
    var alignment: HorizontalAlignment = .leading
    var highlighted = false

    @State private var sweep: Double = -0.25

    var body: some View {
        VStack(alignment: alignment, spacing: 18) {
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

            VStack(alignment: alignment, spacing: 7) {
                Text(ticket.routeText)
                    .font(Typo.mincho(21))
                    .tracking(2)
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(Editorial.caption(for: ticket))
                    .font(Typo.caption(10.5))
                    .tracking(1.4)
                    .foregroundStyle(Ink.textSoft)
            }
            .scrollTransition(.interactive) { content, phase in
                content.opacity(phase.isIdentity ? 1 : 0.4)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .contentShape(Rectangle())
    }

    /// MARS plates fill most of the column; edmondson cards keep their
    /// real-world 57.5/85 scale relationship.
    private var plateWidth: CGFloat {
        ticket.kind.isEdmondson ? 236 : 318
    }

    private var frameAlignment: Alignment {
        alignment == .leading ? .leading : .trailing
    }
}
