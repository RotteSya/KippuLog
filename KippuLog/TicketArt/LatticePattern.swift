import SwiftUI

/// The large diagonal watermark under the guilloche — a sparse run of
/// the operator's mark, barely there, like the JR ghost on real stock.
struct LatticePattern: View {
    let brand: RailBrand
    let seed: UInt64

    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed ^ 0x1A77)
            let tint = Color(hex: brand.patternHex)
            let fontSize = size.height * 0.34
            let mark = TicketText.zenkaku(watermark)
            let resolved = context.resolve(
                Text(String(repeating: mark + "　", count: 6))
                    .font(.custom("HiraginoSans-W6", size: fontSize))
                    .tracking(fontSize * 0.32)
                    .foregroundStyle(tint.opacity(0.055))
            )
            let phase = CGFloat(rng.double(in: -0.5...0.5)) * fontSize
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: .degrees(-13))
            context.draw(
                resolved,
                at: CGPoint(x: phase, y: 0),
                anchor: .center
            )
        }
        .allowsHitTesting(false)
    }

    private var watermark: String {
        switch brand {
        case .jrEast, .jrCentral, .jrWest, .jrHokkaido, .jrKyushu, .jrShikoku:
            return "JR"
        default:
            return brand.mark
        }
    }
}
