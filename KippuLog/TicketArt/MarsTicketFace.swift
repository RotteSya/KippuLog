import SwiftUI

/// The standard MARS-stock plate — 85 × 57.5 proportions, guilloche
/// underprint, letterpress ink. Every measurement scales from the width
/// so the plate is identical at thumbnail and hero sizes.
struct MarsTicketFace: View {
    let ticket: Ticket

    static let aspect: CGFloat = 85.0 / 57.5

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let margin = w * 0.055

            ZStack {
                paper
                LatticePattern(brand: ticket.brand, seed: ticket.styleSeed)
                    .padding(w * 0.02)

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
                content.layerEffect(
                    ShaderLibrary.inkPress(
                        .float2(geo.size),
                        .float(0.16)
                    ),
                    maxSampleOffset: CGSize(width: 0, height: 2)
                )
            }
            .clipShape(punchShape(w: w), style: FillStyle(eoFill: true))
            .overlay {
                punchShape(w: w)
                    .stroke(Color.black.opacity(0.10), lineWidth: 0.7)
            }
            .overlay { holeRelief(w: w, h: h) }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
    }

    // MARK: Pieces

    private var paper: some View {
        let base = ticket.brand.warmPaper ? Color(hex: 0xF4EDDB) : Color(hex: 0xF2EDE1)
        let tint = Color(hex: ticket.brand.patternHex)
        return Rectangle()
            .fill(base)
            .visualEffect { [seed = ticket.styleSeed, material = ticket.paperMaterial, age = ticket.paperAge] content, geo in
                content.colorEffect(
                    ShaderLibrary.ticketPaper(
                        .float2(geo.size),
                        .color(tint.opacity(0.13)),
                        .float(Float(seed % 9973)),
                        .float(0),
                        .float(material),
                        .float(age)
                    )
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
                    .frame(width: w * 0.14, height: w * 0.034)
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

    private func holeRelief(w: CGFloat, h: CGFloat) -> some View {
        Group {
            if let hole = punch.hole {
                HoleRelief(diameter: w * 0.052)
                    .position(x: hole.x * w, y: hole.y * h)
            }
        }
    }
}

/// Directional crescent shading inside a punched hole: shadow where the
/// top light is occluded, a hairline of lit paper-edge at the bottom.
struct HoleRelief: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.52, to: 0.98)
                .stroke(Color.black.opacity(0.32), lineWidth: diameter * 0.085)
                .blur(radius: diameter * 0.05)
            Circle()
                .trim(from: 0.06, to: 0.44)
                .stroke(Color.white.opacity(0.30), lineWidth: diameter * 0.06)
                .blur(radius: diameter * 0.04)
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
    }
}

/// MARS route arrow — long tapered shaft, broad head, the slightest
/// flare at the tail like the machine actually prints.
nonisolated struct RouteArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let headLength = rect.width * 0.34
        let shaftEnd = rect.maxX - headLength
        let shaftHalf = rect.height * 0.155
        let tailHalf = rect.height * 0.21

        path.move(to: CGPoint(x: rect.minX, y: midY - tailHalf))
        path.addLine(to: CGPoint(x: shaftEnd, y: midY - shaftHalf))
        path.addLine(to: CGPoint(x: shaftEnd, y: midY - rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        path.addLine(to: CGPoint(x: shaftEnd, y: midY + rect.height * 0.5))
        path.addLine(to: CGPoint(x: shaftEnd, y: midY + shaftHalf))
        path.addLine(to: CGPoint(x: rect.minX, y: midY + tailHalf))
        path.closeSubpath()
        return path
    }
}
