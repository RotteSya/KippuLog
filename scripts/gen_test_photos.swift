#!/usr/bin/env swift
//
//  gen_test_photos.swift — synthetic "photographed ticket" fixtures.
//
//  Emits two PNGs used by UI tests and manual verification:
//    /tmp/kippu_test_ticket.png   straight-on ticket on plain dark ground
//                                 (exercises the tight-flatten path)
//    /tmp/kippu_test_angled.png   ticket at 13° on busy wood with clutter
//                                 (defeats rectangle detection → exercises
//                                  the subject-lift cutout path)
//
//  Run:  swift scripts/gen_test_photos.swift

import AppKit
import CoreText

func makeContext(_ width: Int, _ height: Int) -> CGContext {
    CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

func savePNG(_ context: CGContext, to path: String) {
    let image = context.makeImage()!
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(path) (\(context.width)x\(context.height))")
}

func draw(text: String, size: CGFloat, weight: String, at point: CGPoint,
          in ctx: CGContext, color: CGColor, centered: Bool = true, tracking: CGFloat = 0) {
    let font = CTFontCreateWithName("HiraginoSans-\(weight)" as CFString, size, nil)
    let attr: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: color)!,
        .kern: tracking,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attr))
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.textPosition = centered
        ? CGPoint(x: point.x - bounds.width / 2, y: point.y - bounds.height / 2)
        : point
    CTLineDraw(line, ctx)
}

/// The ticket face itself, drawn into its own layer so we can rotate it.
func ticketImage(width: Int, height: Int) -> CGImage {
    let ctx = makeContext(width, height)
    let w = CGFloat(width), h = CGFloat(height)

    // Stock.
    let paper = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: w, height: h),
        cornerWidth: w * 0.012, cornerHeight: w * 0.012, transform: nil
    )
    ctx.addPath(paper)
    ctx.setFillColor(CGColor(red: 0.955, green: 0.935, blue: 0.88, alpha: 1))
    ctx.fillPath()

    // Faint guilloche-ish underprint rows.
    ctx.setStrokeColor(CGColor(red: 0.72, green: 0.62, blue: 0.45, alpha: 0.28))
    ctx.setLineWidth(1.2)
    for row in 0..<22 {
        let y = CGFloat(row) / 22 * h
        ctx.move(to: CGPoint(x: 0, y: y))
        var x: CGFloat = 0
        while x < w {
            let wave = sin(x / w * .pi * 7 + CGFloat(row)) * h * 0.004
            ctx.addLine(to: CGPoint(x: x, y: y + wave))
            x += 14
        }
        ctx.strokePath()
    }

    let ink = CGColor(red: 0.13, green: 0.11, blue: 0.09, alpha: 1)
    let soft = CGColor(red: 0.32, green: 0.29, blue: 0.25, alpha: 1)

    draw(text: "新幹線特急券・乗車券", size: h * 0.062, weight: "W6",
         at: CGPoint(x: w / 2, y: h * 0.875), in: ctx, color: ink, tracking: 2)
    draw(text: "東京 → 新大阪", size: h * 0.135, weight: "W6",
         at: CGPoint(x: w / 2, y: h * 0.66), in: ctx, color: ink, tracking: 4)
    draw(text: "６月１０日　のぞみ３１号", size: h * 0.068, weight: "W3",
         at: CGPoint(x: w / 2, y: h * 0.47), in: ctx, color: ink)
    draw(text: "９号車４番Ｅ席", size: h * 0.068, weight: "W3",
         at: CGPoint(x: w / 2, y: h * 0.36), in: ctx, color: ink)
    draw(text: "￥１４，７２０", size: h * 0.095, weight: "W6",
         at: CGPoint(x: w / 2, y: h * 0.22), in: ctx, color: ink, tracking: 3)
    draw(text: "2026.-6.10 東京駅ＭＲ２１発行　ＪＲ東海", size: h * 0.042, weight: "W3",
         at: CGPoint(x: w / 2, y: h * 0.075), in: ctx, color: soft)

    return ctx.makeImage()!
}

// ---------------------------------------------------------------------------
// Fixture 1 — straight on plain dark ground (tight-flatten path).
// ---------------------------------------------------------------------------

func makeStraight() {
    let ctx = makeContext(2400, 1800)
    ctx.setFillColor(CGColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: 2400, height: 1800))

    let ticket = ticketImage(width: 1560, height: 1040)
    // Soft contact shadow.
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 60,
                  color: CGColor(gray: 0, alpha: 0.55))
    ctx.draw(ticket, in: CGRect(x: (2400 - 1560) / 2, y: (1800 - 1040) / 2, width: 1560, height: 1040))
    savePNG(ctx, to: "/tmp/kippu_test_ticket.png")
}

// ---------------------------------------------------------------------------
// Fixture 2 — angled on busy wood with clutter (subject-lift path).
// ---------------------------------------------------------------------------

func makeAngled() {
    let W = 2400, H = 1800
    let ctx = makeContext(W, H)

    // Wood: warm planks with grain streaks and noise.
    ctx.setFillColor(CGColor(red: 0.45, green: 0.33, blue: 0.22, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    var rng = SystemRandomNumberGenerator()
    for plank in 0..<6 {
        let y = CGFloat(plank) * CGFloat(H) / 6
        ctx.setFillColor(CGColor(
            red: 0.42 + .random(in: -0.04...0.06, using: &rng),
            green: 0.31 + .random(in: -0.03...0.05, using: &rng),
            blue: 0.20 + .random(in: -0.03...0.04, using: &rng), alpha: 1
        ))
        ctx.fill(CGRect(x: 0, y: y, width: CGFloat(W), height: CGFloat(H) / 6 - 4))
        // Grain streaks.
        for _ in 0..<60 {
            let gy = y + .random(in: 0...(CGFloat(H) / 6 - 4), using: &rng)
            let gx = CGFloat.random(in: 0...CGFloat(W), using: &rng)
            let len = CGFloat.random(in: 60...420, using: &rng)
            ctx.setStrokeColor(CGColor(red: 0.30, green: 0.21, blue: 0.13,
                                       alpha: .random(in: 0.05...0.22, using: &rng)))
            ctx.setLineWidth(.random(in: 1...3.4, using: &rng))
            ctx.move(to: CGPoint(x: gx, y: gy))
            ctx.addLine(to: CGPoint(x: gx + len, y: gy + .random(in: -6...6, using: &rng)))
            ctx.strokePath()
        }
    }
    // Clutter: a coffee ring and a pen.
    ctx.setStrokeColor(CGColor(red: 0.25, green: 0.16, blue: 0.10, alpha: 0.5))
    ctx.setLineWidth(26)
    ctx.strokeEllipse(in: CGRect(x: 1850, y: 1280, width: 380, height: 360))
    ctx.setFillColor(CGColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1))
    ctx.fill(CGRect(x: 120, y: 180, width: 700, height: 38))
    ctx.fill(CGRect(x: 806, y: 174, width: 60, height: 50)) // pen cap

    // The ticket, rotated 13°, with a believable drop shadow.
    let ticket = ticketImage(width: 1380, height: 920)
    ctx.saveGState()
    ctx.translateBy(x: CGFloat(W) / 2, y: CGFloat(H) / 2 + 30)
    ctx.rotate(by: -13 * .pi / 180)
    ctx.setShadow(offset: CGSize(width: 10, height: -26), blur: 48,
                  color: CGColor(gray: 0, alpha: 0.5))
    ctx.draw(ticket, in: CGRect(x: -690, y: -460, width: 1380, height: 920))
    ctx.restoreGState()

    savePNG(ctx, to: "/tmp/kippu_test_angled.png")
}

makeStraight()
makeAngled()
