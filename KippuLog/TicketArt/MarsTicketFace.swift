import SwiftUI

/// The standard MARS-stock plate — 85 × 57.5 proportions, brand lattice
/// over cream, gothic print. Every measurement scales from the width so
/// the plate is identical at thumbnail and hero sizes.
struct MarsTicketFace: View {
    let ticket: Ticket

    static let aspect: CGFloat = 85.0 / 57.5

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let margin = w * 0.055

            ZStack {
                paper(w: w)
                LatticePattern(brand: ticket.brand, seed: ticket.styleSeed)
                    .padding(w * 0.012)

                // ── Title row ─────────────────────────────────────────
                brandMark(w: w)
                    .position(x: margin + w * 0.052, y: margin + w * 0.030)

                Text(ticket.kind.faceTitle)
                    .font(Typo.gothic(w * 0.047, bold: true))
                    .tracking(w * 0.012)
                    .foregroundStyle(Ink.ticketInk)
                    .position(x: w / 2, y: margin + w * 0.030)

                Text(TicketText.serial(seed: ticket.styleSeed))
                    .font(Typo.gothic(w * 0.026))
                    .foregroundStyle(Ink.ticketInkSoft)
                    .position(x: w - margin - w * 0.072, y: margin + w * 0.026)

                // ── Stations ──────────────────────────────────────────
                stationsRow(w: w)
                    .frame(width: w - margin * 2)
                    .position(x: w / 2, y: h * 0.355)

                // ── Journey details ───────────────────────────────────
                detailRows(w: w)
                    .frame(width: w - margin * 2, alignment: .leading)
                    .position(x: w / 2, y: h * 0.565)

                // ── Fare ──────────────────────────────────────────────
                if let price = ticket.price {
                    Text(TicketText.price(price))
                        .font(Typo.gothic(w * 0.058, bold: true))
                        .tracking(w * 0.004)
                        .foregroundStyle(Ink.ticketInk)
                        .position(x: w / 2, y: h * 0.745)
                }

                // ── Issue line ────────────────────────────────────────
                bottomLine(w: w, h: h, margin: margin)
            }
            .compositingGroup()
            .visualEffect { content, geo in
                content.colorEffect(
                    ShaderLibrary.paperGrain(
                        .float2(geo.size),
                        .float(Float(ticket.styleSeed % 977))
                    )
                )
            }
            .clipShape(punchShape(w: w), style: FillStyle(eoFill: true))
            .overlay {
                punchShape(w: w)
                    .stroke(Color.black.opacity(0.10), lineWidth: 0.7)
            }
            .overlay { holeShadow(w: w, h: h) }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
    }

    // MARK: Pieces

    private func paper(w: CGFloat) -> some View {
        Rectangle()
            .fill(ticket.brand.warmPaper ? Color(hex: 0xF5EDDA) : Color(hex: 0xF1ECDF))
            .overlay {
                LinearGradient(
                    colors: [.white.opacity(0.26), .clear, .black.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
    }

    private func brandMark(w: CGFloat) -> some View {
        Text(ticket.brand.mark)
            .font(Typo.gothic(w * 0.034, bold: true))
            .tracking(w * 0.002)
            .foregroundStyle(Ink.ticketInk)
            .padding(.horizontal, w * 0.012)
            .padding(.vertical, w * 0.006)
            .overlay {
                Rectangle().stroke(Ink.ticketInk.opacity(0.75), lineWidth: max(0.6, w * 0.0024))
            }
    }

    private func stationsRow(w: CGFloat) -> some View {
        HStack(spacing: w * 0.030) {
            Text(ticket.fromStation)
                .font(Typo.gothic(w * 0.082, bold: true))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            if !ticket.toStation.isEmpty {
                RouteArrow()
                    .fill(Ink.ticketInk)
                    .frame(width: w * 0.135, height: w * 0.030)
                Text(ticket.toStation)
                    .font(Typo.gothic(w * 0.082, bold: true))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
        }
        .foregroundStyle(Ink.ticketInk)
        .frame(maxWidth: .infinity)
    }

    private func detailRows(w: CGFloat) -> some View {
        VStack(alignment: .center, spacing: w * 0.020) {
            HStack(spacing: w * 0.045) {
                if let date = ticket.travelDate {
                    Text(TicketText.faceDate(date))
                }
                if let train = ticket.trainName {
                    Text(train)
                }
            }
            if let seat = ticket.seat {
                Text(seat)
            }
        }
        .font(Typo.gothic(w * 0.040))
        .foregroundStyle(Ink.ticketInk.opacity(0.92))
        .frame(maxWidth: .infinity)
    }

    private func bottomLine(w: CGFloat, h: CGFloat, margin: CGFloat) -> some View {
        let issue = ticket.travelDate ?? ticket.createdAt
        return ZStack {
            Text("\(TicketText.issueDate(issue)) \(TicketText.issuer(station: ticket.fromStation, seed: ticket.styleSeed))")
                .font(Typo.gothic(w * 0.028))
                .foregroundStyle(Ink.ticketInkSoft)
                .frame(width: w - margin * 2, alignment: .leading)
                .position(x: w / 2, y: h - margin - w * 0.012)

            if ticket.kind == .joshaken {
                Text("下車前途無効")
                    .font(Typo.gothic(w * 0.028))
                    .foregroundStyle(Ink.ticketInkSoft)
                    .frame(width: w - margin * 2, alignment: .trailing)
                    .position(x: w / 2, y: h - margin - w * 0.012)
            }
        }
    }

    // MARK: Punch

    private var punch: PunchGeometry {
        PunchGeometry(seed: ticket.styleSeed, kind: ticket.kind)
    }

    private func punchShape(w: CGFloat) -> PunchedTicketShape {
        PunchedTicketShape(
            corner: w * 0.018,
            holeUnit: punch.hole,
            holeRadiusUnit: 0.026,
            notchUnitX: nil
        )
    }

    private func holeShadow(w: CGFloat, h: CGFloat) -> some View {
        Group {
            if let hole = punch.hole {
                Circle()
                    .stroke(Color.black.opacity(0.30), lineWidth: w * 0.004)
                    .blur(radius: w * 0.003)
                    .frame(width: w * 0.052, height: w * 0.052)
                    .position(x: hole.x * w, y: hole.y * h)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Long-tailed solid arrow between stations.
nonisolated struct RouteArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let shaft = rect.height * 0.26
        let headLength = rect.width * 0.30
        path.addRect(CGRect(
            x: rect.minX,
            y: midY - shaft / 2,
            width: rect.width - headLength,
            height: shaft
        ))
        path.move(to: CGPoint(x: rect.maxX - headLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX - headLength, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
