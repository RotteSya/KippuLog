import SwiftUI

/// 半券 — the journey's facts printed as a torn-off stub, perforation
/// teeth along the top. Same stock, same serial as the plate above it.
struct StubCard: View {
    let ticket: Ticket

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row.
            HStack(alignment: .firstTextBaseline) {
                Text("ご利用控")
                    .font(Typo.gothic(9.5, bold: true))
                    .tracking(2.5)
                Spacer()
                Text(TicketText.serial(seed: ticket.styleSeed))
                    .font(Typo.gothic(8.5))
            }
            .foregroundStyle(Ink.ticketInkSoft)
            .padding(.bottom, 14)

            // Facts, two columns of small print.
            let facts = factPairs
            let columns = [
                GridItem(.flexible(), alignment: .topLeading),
                GridItem(.flexible(), alignment: .topLeading),
            ]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 13) {
                ForEach(facts, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(label)
                            .font(Typo.gothic(8.5))
                            .tracking(2)
                            .foregroundStyle(Ink.ticketInkSoft.opacity(0.85))
                        Text(value)
                            .font(Typo.gothic(12, bold: true))
                            .foregroundStyle(Ink.ticketInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            StubShape(toothCount: 26, toothDepth: 4, corner: 5)
                .fill(Color(hex: 0xF2EDE1))
                .visualEffect { [seed = ticket.styleSeed] content, geo in
                    content.colorEffect(
                        ShaderLibrary.ticketPaper(
                            .float2(geo.size),
                            .color(Color.clear),
                            .float(Float((seed &+ 7) % 9973)),
                            .float(0)
                        )
                    )
                }
                .clipShape(StubShape(toothCount: 26, toothDepth: 4, corner: 5))
        }
        .overlay {
            StubShape(toothCount: 26, toothDepth: 4, corner: 5)
                .stroke(Color.black.opacity(0.10), lineWidth: 0.6)
        }
        .shadow(color: .black.opacity(0.30), radius: 10, y: 7)
        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }

    private var factPairs: [(String, String)] {
        var pairs: [(String, String)] = [
            ("種別", ticket.kind.label),
            ("会社", ticket.brand.displayName),
        ]
        if let train = ticket.trainName { pairs.append(("列車", train)) }
        if let seat = ticket.seat { pairs.append(("座席", seat)) }
        if let price = ticket.price { pairs.append(("運賃", TicketText.price(price))) }
        if let date = ticket.travelDate { pairs.append(("日付", TicketText.faceDate(date))) }
        return pairs
    }
}

/// Stub outline: perforation teeth across the top edge, rounded feet.
nonisolated struct StubShape: Shape {
    var toothCount: Int
    var toothDepth: CGFloat
    var corner: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let toothWidth = rect.width / CGFloat(toothCount)
        let top = rect.minY + toothDepth

        path.move(to: CGPoint(x: rect.minX, y: top))
        // Teeth march across the torn edge.
        for i in 0..<toothCount {
            let x0 = rect.minX + CGFloat(i) * toothWidth
            path.addLine(to: CGPoint(x: x0 + toothWidth * 0.5, y: rect.minY))
            path.addLine(to: CGPoint(x: x0 + toothWidth, y: top))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addArc(
            center: CGPoint(x: rect.maxX - corner, y: rect.maxY - corner),
            radius: corner, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + corner, y: rect.maxY - corner),
            radius: corner, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        StudioBackdrop()
        StubCard(ticket: Ticket.samples[1])
            .frame(width: 300)
    }
}
