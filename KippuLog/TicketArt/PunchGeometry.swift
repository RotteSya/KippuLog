import SwiftUI

/// Where the gate bit the ticket. Deterministic per seed.
struct PunchGeometry {
    /// Circular punch (MARS stock), in unit coordinates.
    var hole: CGPoint?
    /// V-notch cut on the top edge (edmondson stock), unit x.
    var notchX: CGFloat?

    init(seed: UInt64, kind: TicketKind) {
        var rng = SeededRandom(seed ^ 0x9A7C)
        if kind.isEdmondson {
            notchX = CGFloat(rng.double(in: 0.26...0.74))
            hole = nil
        } else {
            // Corner territory only — the punch never bites the station band.
            let anchors: [CGPoint] = [
                CGPoint(x: 0.100, y: 0.205),
                CGPoint(x: 0.900, y: 0.205),
                CGPoint(x: 0.100, y: 0.790),
            ]
            var p = anchors[rng.int(in: 0...2)]
            p.x += CGFloat(rng.double(in: -0.012...0.012))
            p.y += CGFloat(rng.double(in: -0.020...0.020))
            hole = p
            notchX = nil
        }
    }
}

/// Ticket outline with the punch subtracted — rounded stock, optional
/// circular hole, optional V-notch on the top edge. Even-odd fill.
nonisolated struct PunchedTicketShape: Shape {
    var corner: CGFloat
    var holeUnit: CGPoint?
    var holeRadiusUnit: CGFloat
    var notchUnitX: CGFloat?

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if let notchUnitX {
            // Stock outline with a V bite taken out of the top edge.
            let nx = rect.minX + notchUnitX * rect.width
            let halfWidth = rect.width * 0.030
            let depth = rect.height * 0.13
            let r = corner
            path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            path.addLine(to: CGPoint(x: nx - halfWidth, y: rect.minY))
            path.addLine(to: CGPoint(x: nx, y: rect.minY + depth))
            path.addLine(to: CGPoint(x: nx + halfWidth, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                        radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                        radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.closeSubpath()
        } else {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: corner, height: corner))
        }
        if let holeUnit {
            let radius = holeRadiusUnit * rect.width
            let center = CGPoint(x: rect.minX + holeUnit.x * rect.width,
                                 y: rect.minY + holeUnit.y * rect.height)
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                       width: radius * 2, height: radius * 2))
        }
        return path
    }
}
