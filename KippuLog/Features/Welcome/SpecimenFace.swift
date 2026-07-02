import UIKit

/// The 見本 — the one ticket きっぷログ itself issues, printed by the
/// welcome machine. Drawn entirely in CoreGraphics so the ceremony engine
/// can hold it as a texture: MARS stock, guilloche underprint, mottle,
/// letterpress-dark ink, a diagonal specimen overprint in 朱.
///
/// The face must read as a *real* MARS print — the app's materials are
/// paper and ink, and the very first object the user meets sets the bar.
enum SpecimenFace {
    static let aspect: CGFloat = 85.0 / 57.5
    /// The seed every specimen shares — its punch, serial and guilloche
    /// phase are the app's own, not random per launch.
    static let seed: UInt64 = 0x716B

    /// Ink palette mirrors `Ink.ticket*` (constants — tickets are objects).
    private static let paper = UIColor(red: 0.949, green: 0.929, blue: 0.882, alpha: 1)      // 0xF2EDE1
    private static let ink = UIColor(red: 0.169, green: 0.149, blue: 0.125, alpha: 1)        // 0x2B2620
    private static let inkSoft = UIColor(red: 0.431, green: 0.396, blue: 0.341, alpha: 1)    // 0x6E6557
    private static let tint = UIColor(red: 0.604, green: 0.659, blue: 0.620, alpha: 1)       // 0x9AA89E
    private static let shu = UIColor(red: 0.847, green: 0.251, blue: 0.122, alpha: 1)        // 0xD8401F

    /// Renders the full face at `width` points × screen scale.
    static func render(width: CGFloat, screenScale: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: width / aspect)
        let format = UIGraphicsImageRendererFormat()
        format.scale = screenScale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let w = size.width
            let h = size.height
            let stock = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: w * 0.018)
            stock.addClip()

            // ── Paper ────────────────────────────────────────────────
            paper.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            drawGuilloche(cg, w: w, h: h)
            drawMottle(cg, w: w, h: h)
            drawEdgeDarkening(cg, w: w, h: h)

            // ── Print ────────────────────────────────────────────────
            let margin = w * 0.055

            // Operator box — きっぷログ is the issuing operator.
            let markFont = gothic(w * 0.034, bold: true)
            let mark = attributed("き", font: markFont, color: ink, kern: 0)
            let markSize = mark.size()
            let boxRect = CGRect(
                x: margin, y: margin - w * 0.004,
                width: markSize.width + w * 0.026, height: markSize.height + w * 0.010
            )
            cg.setStrokeColor(ink.withAlphaComponent(0.75).cgColor)
            cg.setLineWidth(max(0.6, w * 0.0024))
            cg.stroke(boxRect)
            mark.draw(at: CGPoint(x: boxRect.midX - markSize.width / 2, y: boxRect.midY - markSize.height / 2))

            // Title, spaced like a MARS print.
            let title = attributed("案　内　券", font: gothic(w * 0.047, bold: true), color: ink, kern: w * 0.012)
            let titleSize = title.size()
            title.draw(at: CGPoint(x: (w - titleSize.width) / 2, y: margin + w * 0.030 - titleSize.height / 2))

            // Serial.
            var rng = SeededRandom(seed)
            let serial = attributed(
                rng.digits(5) + "-" + rng.digits(2),
                font: gothic(w * 0.026, bold: false), color: inkSoft, kern: w * 0.004
            )
            let serialSize = serial.size()
            serial.draw(at: CGPoint(x: w - margin - serialSize.width, y: margin + w * 0.026 - serialSize.height / 2))

            // Stations row: ここから → どこまでも
            drawStations(cg, w: w, h: h)

            // Detail rows.
            let detailFont = gothic(w * 0.040, bold: false)
            let row1 = attributed(issueDateLine(), font: detailFont, color: ink, kern: w * 0.006)
            let r1 = row1.size()
            row1.draw(at: CGPoint(x: (w - r1.width) / 2, y: h * 0.520 - r1.height / 2))
            let row2 = attributed("自　由　席", font: detailFont, color: ink, kern: w * 0.006)
            let r2 = row2.size()
            row2.draw(at: CGPoint(x: (w - r2.width) / 2, y: h * 0.615 - r2.height / 2))

            // Fare — a specimen prints asterisks where money would be.
            let fare = attributed("¥＊＊＊＊", font: gothic(w * 0.058, bold: true), color: ink, kern: w * 0.004)
            let fareSize = fare.size()
            fare.draw(at: CGPoint(x: (w - fareSize.width) / 2, y: h * 0.745 - fareSize.height / 2))

            // Issue line.
            let issue = attributed(bottomLine(), font: gothic(w * 0.028, bold: false), color: inkSoft, kern: w * 0.002)
            let issueSize = issue.size()
            issue.draw(at: CGPoint(x: margin, y: h - margin * 0.9 - issueSize.height))

            // ── 見本 overprint — one confident diagonal stamp in 朱,
            // the way a real specimen is struck across its whole face ──
            cg.saveGState()
            cg.translateBy(x: w * 0.50, y: h * 0.54)
            cg.rotate(by: -16 * .pi / 180)
            let specimen = attributed("見　本", font: mincho(w * 0.26), color: shu.withAlphaComponent(0.15), kern: w * 0.10)
            let spSize = specimen.size()
            specimen.draw(at: CGPoint(x: -spSize.width / 2, y: -spSize.height / 2))
            cg.restoreGState()
        }
    }

    // MARK: Passages

    /// Two counter-phase sine bundles braid the classic engraved net —
    /// the CG twin of the `ticketPaper` shader's guilloche.
    private static func drawGuilloche(_ cg: CGContext, w: CGFloat, h: CGFloat) {
        let rows = 30
        let amplitude = 0.52 / CGFloat(rows) * h
        let phase = CGFloat(seed % 977) * 0.013
        cg.setLineWidth(max(0.5, h / CGFloat(rows) * 0.24))
        cg.setStrokeColor(tint.withAlphaComponent(0.30).cgColor)

        for bundle in 0..<2 {
            let bundlePhase = phase + (bundle == 1 ? .pi : 0)
            let yShift = bundle == 1 ? h / CGFloat(rows) * 0.5 : 0
            for k in 0...rows {
                let baseY = (CGFloat(k)) / CGFloat(rows) * h + yShift
                let path = CGMutablePath()
                var first = true
                var x: CGFloat = -2
                while x <= w + 2 {
                    let y = baseY - amplitude * sin(x / w * 9.8 + bundlePhase)
                    if first { path.move(to: CGPoint(x: x, y: y)); first = false }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                    x += 3
                }
                cg.addPath(path)
            }
            cg.strokePath()
        }
    }

    /// Pulp mottle, tooth speckle and grain-axis fibre flecks.
    private static func drawMottle(_ cg: CGContext, w: CGFloat, h: CGFloat) {
        var rng = SeededRandom(seed ^ 0x50AB)
        // Broad pulp shadows.
        for _ in 0..<26 {
            let r = CGFloat(rng.double(in: 14...42)) * w / 300
            let x = CGFloat(rng.unit()) * w
            let y = CGFloat(rng.unit()) * h
            let dark = rng.unit() > 0.5
            cg.setFillColor(
                (dark ? UIColor.black : UIColor.white)
                    .withAlphaComponent(CGFloat(rng.double(in: 0.008...0.018))).cgColor
            )
            cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        // Tooth speckle.
        for _ in 0..<900 {
            let s = CGFloat(rng.double(in: 0.4...1.1)) * w / 300
            let x = CGFloat(rng.unit()) * w
            let y = CGFloat(rng.unit()) * h
            let dark = rng.unit() > 0.42
            cg.setFillColor(
                (dark ? UIColor.black : UIColor.white)
                    .withAlphaComponent(CGFloat(rng.double(in: 0.015...0.05))).cgColor
            )
            cg.fill(CGRect(x: x, y: y, width: s, height: s))
        }
        // Fibre flecks along the grain.
        cg.setLineWidth(max(0.4, w * 0.0013))
        for _ in 0..<70 {
            let x = CGFloat(rng.unit()) * w
            let y = CGFloat(rng.unit()) * h
            let len = CGFloat(rng.double(in: 2.5...7)) * w / 300
            let tilt = CGFloat(rng.double(in: -0.22...0.22))
            cg.setStrokeColor(UIColor.black.withAlphaComponent(CGFloat(rng.double(in: 0.02...0.045))).cgColor)
            cg.move(to: CGPoint(x: x, y: y))
            cg.addLine(to: CGPoint(x: x + len, y: y + len * tilt))
            cg.strokePath()
        }
    }

    /// Cut edges pick up a hair of handling.
    private static func drawEdgeDarkening(_ cg: CGContext, w: CGFloat, h: CGFloat) {
        let inset = w * 0.006
        for i in 0..<3 {
            let alpha = 0.030 - Double(i) * 0.009
            cg.setStrokeColor(UIColor.black.withAlphaComponent(alpha).cgColor)
            cg.setLineWidth(inset)
            cg.stroke(CGRect(x: 0, y: 0, width: w, height: h).insetBy(dx: inset * CGFloat(i) + inset / 2, dy: inset * CGFloat(i) + inset / 2))
        }
    }

    private static func drawStations(_ cg: CGContext, w: CGFloat, h: CGFloat) {
        let stationFont = gothic(w * 0.072, bold: true)
        let from = attributed("ここから", font: stationFont, color: ink, kern: w * 0.002)
        let to = attributed("どこまでも", font: stationFont, color: ink, kern: w * 0.002)
        let fromSize = from.size()
        let toSize = to.size()
        let arrowW = w * 0.115
        let gap = w * 0.028
        let total = fromSize.width + gap + arrowW + gap + toSize.width
        var x = (w - total) / 2
        let midY = h * 0.360

        from.draw(at: CGPoint(x: x, y: midY - fromSize.height / 2))
        x += fromSize.width + gap

        // The MARS route arrow — a straight shaft with a solid head.
        let shaftY = midY
        let headW = arrowW * 0.34
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(max(1.2, w * 0.008))
        cg.move(to: CGPoint(x: x, y: shaftY))
        cg.addLine(to: CGPoint(x: x + arrowW - headW * 0.55, y: shaftY))
        cg.strokePath()
        let head = CGMutablePath()
        head.move(to: CGPoint(x: x + arrowW, y: shaftY))
        head.addLine(to: CGPoint(x: x + arrowW - headW, y: shaftY - headW * 0.42))
        head.addLine(to: CGPoint(x: x + arrowW - headW, y: shaftY + headW * 0.42))
        head.closeSubpath()
        cg.setFillColor(ink.cgColor)
        cg.addPath(head)
        cg.fillPath()
        x += arrowW + gap

        to.draw(at: CGPoint(x: x, y: midY - toSize.height / 2))
    }

    // MARK: Lines

    private static func issueDateLine() -> String {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let m = calendar.component(.month, from: now)
        let d = calendar.component(.day, from: now)
        return "\(fullWidth(m))月\(fullWidth(d))日　発行"
    }

    private static func bottomLine() -> String {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let y = calendar.component(.year, from: now)
        let m = calendar.component(.month, from: now)
        let d = calendar.component(.day, from: now)
        return "\(y).-\(m).-\(d) きっぷログ発行"
    }

    /// MARS prints use full-width numerals.
    private static func fullWidth(_ n: Int) -> String {
        String(String(n).map { c -> Character in
            guard let v = c.wholeNumberValue else { return c }
            return Character(UnicodeScalar(0xFF10 + v)!)
        })
    }

    // MARK: Type

    private static func gothic(_ size: CGFloat, bold: Bool) -> UIFont {
        UIFont(name: bold ? "HiraginoSans-W6" : "HiraginoSans-W3", size: size)
            ?? .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
    }

    private static func mincho(_ size: CGFloat) -> UIFont {
        UIFont(name: "HiraMinProN-W6", size: size) ?? .systemFont(ofSize: size, weight: .semibold)
    }

    private static func attributed(_ text: String, font: UIFont, color: UIColor, kern: CGFloat) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .kern: kern,
        ])
    }
}
