import SwiftUI

/// The security lattice printed across ticket stock — wavy ribbons of a
/// tiny repeated operator mark (ＪＲＪＲＪＲ…), tinted per brand.
/// Drawn in segments so each row undulates like the real rotogravure print.
struct LatticePattern: View {
    let brand: RailBrand
    let seed: UInt64

    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed ^ 0x1A77)
            let phase = rng.double(in: 0 ... .pi * 2)
            let tint = Color(hex: brand.patternHex)

            let rowHeight = size.height * 0.068
            let fontSize = size.height * 0.046
            let mark = TicketText.zenkaku(latticeMark)
            let segmentWidth = size.width / 9

            let rowCount = Int(size.height / rowHeight) + 2
            for row in 0..<rowCount {
                let y = CGFloat(row) * rowHeight + rowHeight * 0.4
                let xJitter = CGFloat(rng.double(in: 0...1)) * segmentWidth
                let resolved = context.resolve(
                    Text(String(repeating: mark, count: 4))
                        .font(.custom("HiraginoSans-W3", size: fontSize))
                        .tracking(fontSize * 0.30)
                        .foregroundStyle(tint.opacity(row.isMultiple(of: 2) ? 0.20 : 0.145))
                )
                var x = -segmentWidth - xJitter
                while x < size.width + segmentWidth {
                    let wave = sin((x / size.width) * .pi * 2.6 + phase + Double(row) * 0.9)
                    let yOffset = wave * size.height * 0.008
                    context.draw(resolved, at: CGPoint(x: x, y: y + yOffset), anchor: .leading)
                    x += resolved.measure(in: size).width + fontSize * 0.4
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var latticeMark: String {
        switch brand {
        case .jrEast, .jrCentral, .jrWest, .jrHokkaido, .jrKyushu, .jrShikoku:
            return "JR"
        default:
            return brand.mark
        }
    }
}
