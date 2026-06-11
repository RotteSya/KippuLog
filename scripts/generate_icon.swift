// App icon generator — run from repo root:
//   swift scripts/generate_icon.swift
// Writes KippuLog/Assets.xcassets/AppIcon.appiconset/icon-1024.png
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError() }

// ── Night studio backdrop ────────────────────────────────────────────
let bg = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(calibratedRed: 0.165, green: 0.145, blue: 0.118, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.082, green: 0.070, blue: 0.055, alpha: 1).cgColor,
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(bg, start: CGPoint(x: 200, y: size), end: CGPoint(x: 824, y: 0), options: [])

// ── The ticket ───────────────────────────────────────────────────────
let ticketW: CGFloat = 700
let ticketH: CGFloat = ticketW / (85.0 / 57.5)
let ticketRect = CGRect(x: (size - ticketW) / 2, y: (size - ticketH) / 2, width: ticketW, height: ticketH)

ctx.saveGState()
ctx.translateBy(x: ticketRect.midX, y: ticketRect.midY)
ctx.rotate(by: -8 * .pi / 180)
ctx.translateBy(x: -ticketRect.midX, y: -ticketRect.midY)

// Shadow.
ctx.setShadow(offset: CGSize(width: 0, height: -26), blur: 60,
              color: NSColor.black.withAlphaComponent(0.55).cgColor)

// Paper with the punch hole cut out (even-odd).
let paperPath = CGMutablePath()
paperPath.addRoundedRect(in: ticketRect, cornerWidth: 22, cornerHeight: 22)
let holeCenter = CGPoint(x: ticketRect.minX + ticketW * 0.118, y: ticketRect.maxY - ticketH * 0.225)
paperPath.addEllipse(in: CGRect(x: holeCenter.x - 26, y: holeCenter.y - 26, width: 52, height: 52))
ctx.addPath(paperPath)
ctx.setFillColor(NSColor(calibratedRed: 0.957, green: 0.933, blue: 0.870, alpha: 1).cgColor)
ctx.fillPath(using: .evenOdd)
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Faint lattice rows on the stock.
let lattice = NSColor(calibratedRed: 0.42, green: 0.58, blue: 0.53, alpha: 0.20)
let latticeFont = NSFont(name: "HiraginoSans-W3", size: 30) ?? .systemFont(ofSize: 30)
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: ticketRect, cornerWidth: 22, cornerHeight: 22, transform: nil))
ctx.clip()
for row in 0..<8 {
    let y = ticketRect.minY + CGFloat(row) * 62 + 14
    let text = String(repeating: "ＪＲ ", count: 16) as NSString
    text.draw(at: NSPoint(x: ticketRect.minX + CGFloat(row % 3) * 16 - 20, y: y),
              withAttributes: [.font: latticeFont, .foregroundColor: lattice])
}
ctx.restoreGState()

// Hole inner shadow ring.
ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.30).cgColor)
ctx.setLineWidth(3)
ctx.strokeEllipse(in: CGRect(x: holeCenter.x - 26, y: holeCenter.y - 26, width: 52, height: 52))

// ── Print: stations + the shu arrow ─────────────────────────────────
let ink = NSColor(calibratedRed: 0.165, green: 0.145, blue: 0.118, alpha: 1)
let stationFont = NSFont(name: "HiraginoSans-W6", size: 132) ?? .boldSystemFont(ofSize: 132)

func drawText(_ s: String, font: NSFont, color: NSColor, center: CGPoint) {
    let str = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
    let sz = str.size()
    str.draw(at: NSPoint(x: center.x - sz.width / 2, y: center.y - sz.height / 2))
}

let midY = ticketRect.midY - 10
drawText("東", font: stationFont, color: ink,
         center: CGPoint(x: ticketRect.minX + ticketW * 0.245, y: midY))
drawText("京", font: stationFont, color: ink,
         center: CGPoint(x: ticketRect.maxX - ticketW * 0.245, y: midY))

// Vermilion arrow between them.
let shu = NSColor(calibratedRed: 0.847, green: 0.251, blue: 0.122, alpha: 1)
let arrowY = midY
let shaftL = ticketRect.minX + ticketW * 0.395
let shaftR = ticketRect.maxX - ticketW * 0.420
ctx.setFillColor(shu.cgColor)
ctx.fill(CGRect(x: shaftL, y: arrowY - 9, width: shaftR - shaftL, height: 18))
ctx.beginPath()
ctx.move(to: CGPoint(x: shaftR, y: arrowY - 34))
ctx.addLine(to: CGPoint(x: shaftR + 58, y: arrowY))
ctx.addLine(to: CGPoint(x: shaftR, y: arrowY + 34))
ctx.closePath()
ctx.fillPath()

// Small title + rule, like the plate's top row.
let titleFont = NSFont(name: "HiraginoSans-W6", size: 44) ?? .boldSystemFont(ofSize: 44)
drawText("乗 車 券", font: titleFont, color: ink.withAlphaComponent(0.88),
         center: CGPoint(x: ticketRect.midX, y: ticketRect.maxY - ticketH * 0.16))
let serifFont = NSFont(name: "HiraginoSans-W3", size: 30) ?? .systemFont(ofSize: 30)
drawText("２０２６．６．１１　きっぷログ発行", font: serifFont, color: ink.withAlphaComponent(0.55),
         center: CGPoint(x: ticketRect.midX, y: ticketRect.minY + ticketH * 0.14))

ctx.restoreGState()
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("encode") }
let out = "KippuLog/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
