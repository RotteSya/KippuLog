import SwiftUI

/// 硬券 — the small edmondson card (57.5 × 30.5) used for 入場券.
/// Buff stock, centered stack, inked date stamp, red serial,
/// and the classic V-notch bitten from the top edge.
struct EdmondsonTicketFace: View {
    let ticket: Ticket

    static let aspect: CGFloat = 57.5 / 30.5

    private static let stampInk = Color(hex: 0x3D3D72)
    private static let serialRed = Color(hex: 0xB5352A)

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                paper

                // Station, large and proud.
                Text(stationTitle)
                    .font(Typo.gothic(w * 0.105, bold: true))
                    .tracking(w * 0.016)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Ink.ticketInk)
                    .frame(width: w * 0.9)
                    .position(x: w / 2, y: h * 0.30)

                // Title + fare on one quiet line.
                HStack(spacing: w * 0.045) {
                    Text("入場券")
                        .tracking(w * 0.014)
                    if let price = ticket.price {
                        Text(TicketText.zenkaku("\(price)円"))
                    }
                }
                .font(Typo.gothic(w * 0.052))
                .foregroundStyle(Ink.ticketInk.opacity(0.92))
                .position(x: w / 2, y: h * 0.56)

                // The stamped date — slightly drunk, like a real stamp.
                if let date = ticket.travelDate {
                    Text(TicketText.stampDate(date))
                        .font(.system(size: w * 0.046, weight: .medium, design: .monospaced))
                        .kerning(w * 0.012)
                        .foregroundStyle(Self.stampInk.opacity(0.82))
                        .padding(.horizontal, w * 0.016)
                        .padding(.vertical, w * 0.008)
                        .overlay {
                            RoundedRectangle(cornerRadius: w * 0.008)
                                .stroke(Self.stampInk.opacity(0.45), lineWidth: max(0.5, w * 0.0022))
                        }
                        .rotationEffect(.degrees(stampAngle))
                        .position(x: w * 0.30, y: h * 0.80)
                }

                // Red serial, bottom right.
                Text(TicketText.edmondsonSerial(seed: ticket.styleSeed))
                    .font(Typo.gothic(w * 0.050))
                    .tracking(w * 0.016)
                    .foregroundStyle(Self.serialRed.opacity(0.88))
                    .position(x: w * 0.74, y: h * 0.81)
            }
            .compositingGroup()
            .visualEffect { content, geo in
                content.layerEffect(
                    ShaderLibrary.inkPress(
                        .float2(geo.size),
                        .float(0.18)
                    ),
                    maxSampleOffset: CGSize(width: 0, height: 2)
                )
            }
            .clipShape(punchShape(w: w), style: FillStyle(eoFill: true))
            .overlay {
                punchShape(w: w)
                    .stroke(Color.black.opacity(0.12), lineWidth: 0.7)
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
    }

    /// Plain buff card — no underprint, just stock with a horizontal
    /// grain (the way B-type edmondsons are cut).
    private var paper: some View {
        Rectangle()
            .fill(Ink.edmondsonBuff)
            .visualEffect { [seed = ticket.styleSeed] content, geo in
                content.colorEffect(
                    ShaderLibrary.ticketPaper(
                        .float2(geo.size),
                        .color(Color.clear),
                        .float(Float(seed % 9973)),
                        .float(1)
                    )
                )
            }
    }

    private var stationTitle: String {
        let name = ticket.fromStation
        return name.hasSuffix("駅") ? name : name + "駅"
    }

    private var stampAngle: Double {
        var rng = SeededRandom(ticket.styleSeed ^ 0x57A3)
        return rng.double(in: -3.4 ... -1.2)
    }

    private var punch: PunchGeometry {
        PunchGeometry(seed: ticket.styleSeed, kind: ticket.kind)
    }

    private func punchShape(w: CGFloat) -> PunchedTicketShape {
        PunchedTicketShape(
            corner: w * 0.012,
            holeUnit: nil,
            holeRadiusUnit: 0,
            notchUnitX: punch.notchX
        )
    }
}
