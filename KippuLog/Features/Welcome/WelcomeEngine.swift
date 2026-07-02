import UIKit

/// The opening ceremony's engine — a dark room, a ticket machine, and one
/// printed 見本.
///
/// Built straight on Core Animation: a `CADisplayLink` master clock drives
/// every layer property each frame from one pure `evaluate(t)` timeline
/// (no implicit animations, no springs scheduled ahead) — so the ceremony
/// is deterministic, scrubbable, and a tap can jump the clock without
/// tearing. SwiftUI supplies only the static copy and buttons above.
@MainActor
final class WelcomeEngine: UIView {

    // MARK: Phases surfaced to SwiftUI

    enum Phase: Comparable { case opening, settled, exiting }
    var onPhaseChange: ((Phase) -> Void)?
    private(set) var phase: Phase = .opening {
        didSet { if oldValue != phase { onPhaseChange?(phase) } }
    }

    // MARK: The beat sheet (seconds on the master clock)

    private enum Beat {
        static let lampOn = 0.12
        static let lampSteady = 0.62
        static let glyphStart = 0.55
        static let glyphStagger = 0.11
        static let glyphDur = 0.48
        static let hanko = 1.62
        static let mouthWake = 1.95
        static let printStart = 2.35
        static let feedSteps = 9
        static let feedStep = 0.165      // 0.10 travel + 0.065 dwell
        static var printEnd: Double { printStart + Double(feedSteps) * feedStep }
        static let punch = printEnd + 0.42
        static let release = punch + 0.36
        static let releaseDur = 0.72
        static var settled: Double { release + releaseDur }
    }

    // MARK: Layers

    private let roomLayer = CALayer()
    private var glyphLayers: [CATextLayer] = []
    private let hankoLayer = CALayer()
    private let hankoBloom = CAShapeLayer()
    private let mouthGroup = CALayer()          // body + slot + lamp + chevrons (flinches together)
    private let mouthBody = CALayer()
    private let slotGlow = CALayer()
    private let statusLamp = CALayer()
    private var chevrons: [CAShapeLayer] = []
    private let ticketWindow = CALayer()        // static mask: nothing shows above the slot
    private let ticketLayer = CALayer()
    private let glossLayer = CAGradientLayer()
    private let printLine = CALayer()
    private let chadLayer = CALayer()

    // MARK: Clock

    private var link: CADisplayLink?
    private var startStamp: CFTimeInterval = 0
    private var clockOffset: Double = 0         // skip jumps land here
    private var lastT: Double = 0
    private var firedHaptics = Set<String>()

    // MARK: Interaction

    private var tiltTarget = CGPoint.zero       // -1…1
    private var tilt = CGPoint.zero

    // MARK: Exit

    private enum Exit { case none, toGate(CGPoint, Double) }   // target, start t
    private var exit = Exit.none
    private var exitCompletion: (() -> Void)?

    // MARK: Geometry (resolved in layoutSubviews)

    private var ticketSize = CGSize.zero
    private var slotLineY: CGFloat = 0
    private var settleCenter = CGPoint.zero
    private var wordmarkCenterY: CGFloat = 0
    private var mouthCenterY: CGFloat = 0
    private var built = false
    private var holePoint: CGPoint?             // unit, from PunchGeometry

    private let reduceMotion = UIAccessibility.isReduceMotionEnabled

    // MARK: Setup

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap))
        addGestureRecognizer(tap)
        // The theatre is decoration — the story and the buttons above
        // carry the accessible experience, and nothing here may swallow
        // their hit points.
        isAccessibilityElement = false
        accessibilityElementsHidden = true
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            link?.invalidate()
            link = nil
        } else if link == nil, built {
            startClock()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 100, bounds.height > 100, !built else { return }
        built = true
        resolveGeometry()
        buildLayers()
        if reduceMotion {
            clockOffset = Beat.settled + 0.01
        }
        startClock()
    }

    private func resolveGeometry() {
        let w = bounds.width
        let h = bounds.height
        let safeTop = safeAreaInsets.top
        wordmarkCenterY = safeTop + h * 0.085
        mouthCenterY = safeTop + h * 0.215
        slotLineY = mouthCenterY + 10          // paper leaves below the slot line
        let ticketW = min(w * 0.66, 300)
        ticketSize = CGSize(width: ticketW, height: ticketW / SpecimenFace.aspect)
        settleCenter = CGPoint(x: w / 2, y: h * 0.485)
        // The specimen's punch is composed, not drawn by lot: top-right,
        // balancing the operator box at top-left.
        holePoint = CGPoint(x: 0.893, y: 0.212)
    }

    // MARK: Layer construction

    private func buildLayers() {
        let scale = window?.screen.scale ?? 3

        // The room — an opaque night with a warm dithered pool.
        roomLayer.contents = Self.renderRoom(size: bounds.size, scale: min(scale, 2)).cgImage
        roomLayer.frame = bounds.insetBy(dx: -bounds.width * 0.2, dy: -bounds.height * 0.2)
        layer.addSublayer(roomLayer)

        // Wordmark, one glyph at a time.
        let glyphFont = UIFont(name: "HiraMinProN-W6", size: 27) ?? .systemFont(ofSize: 27, weight: .semibold)
        let word = "きっぷログ"
        let gap: CGFloat = 11
        let widths: [CGFloat] = word.map { ch in
            (String(ch) as NSString).size(withAttributes: [.font: glyphFont]).width
        }
        let totalW = widths.reduce(0, +) + gap * CGFloat(word.count - 1)
        var x = (bounds.width - totalW) / 2
        for (i, ch) in word.enumerated() {
            let tl = CATextLayer()
            tl.string = String(ch)
            tl.font = glyphFont
            tl.fontSize = glyphFont.pointSize
            tl.foregroundColor = UIColor(red: 0.929, green: 0.902, blue: 0.855, alpha: 1).cgColor // Stage.text
            tl.alignmentMode = .center
            tl.contentsScale = scale
            let size = CGSize(width: widths[i] + 8, height: glyphFont.lineHeight + 6)
            tl.frame = CGRect(
                x: x - 4, y: wordmarkCenterY - size.height / 2,
                width: size.width, height: size.height
            )
            tl.opacity = 0
            // Letterpress: the glyph sits *in* the paper — a breath of
            // ink-bleed shadow that relaxes as it settles.
            tl.shadowColor = UIColor.black.cgColor
            tl.shadowOffset = CGSize(width: 0, height: 1)
            tl.shadowRadius = 1.2
            tl.shadowOpacity = 0
            layer.addSublayer(tl)
            glyphLayers.append(tl)
            x += widths[i] + gap
        }

        // 落款 — stamps in after the word.
        let hankoSize: CGFloat = 19
        hankoLayer.contents = Self.renderHanko(size: hankoSize, scale: scale).cgImage
        hankoLayer.frame = CGRect(
            x: x + 6, y: wordmarkCenterY - hankoSize / 2 - 3,
            width: hankoSize, height: hankoSize
        )
        hankoLayer.opacity = 0
        layer.addSublayer(hankoLayer)

        hankoBloom.path = UIBezierPath(ovalIn: CGRect(x: -18, y: -18, width: 36, height: 36)).cgPath
        hankoBloom.position = CGPoint(x: hankoLayer.frame.midX, y: hankoLayer.frame.midY)
        hankoBloom.fillColor = nil
        hankoBloom.strokeColor = UIColor(red: 0.847, green: 0.251, blue: 0.122, alpha: 1).cgColor
        hankoBloom.lineWidth = 1.4
        hankoBloom.opacity = 0
        layer.addSublayer(hankoBloom)

        // Ticket window: everything of the specimen above the slot line is
        // machine territory — a static mask the print slides through.
        ticketWindow.frame = bounds
        let windowMask = CALayer()
        windowMask.backgroundColor = UIColor.black.cgColor
        windowMask.frame = CGRect(x: 0, y: slotLineY, width: bounds.width, height: bounds.height - slotLineY)
        ticketWindow.mask = windowMask
        layer.addSublayer(ticketWindow)

        // The specimen itself.
        ticketLayer.contents = SpecimenFace.render(width: ticketSize.width, screenScale: scale).cgImage
        ticketLayer.bounds = CGRect(origin: .zero, size: ticketSize)
        ticketLayer.position = CGPoint(x: bounds.midX, y: slotLineY - ticketSize.height / 2)
        ticketLayer.shadowColor = UIColor.black.cgColor
        ticketLayer.shadowOpacity = 0
        ticketLayer.shadowRadius = 18
        ticketLayer.shadowOffset = CGSize(width: 0, height: 12)
        ticketLayer.shadowPath = UIBezierPath(
            roundedRect: CGRect(origin: .zero, size: ticketSize), cornerRadius: 5
        ).cgPath
        ticketWindow.addSublayer(ticketLayer)

        // Paper gloss that answers the hand after the settle.
        glossLayer.type = .axial
        glossLayer.colors = [
            UIColor.white.withAlphaComponent(0).cgColor,
            UIColor.white.withAlphaComponent(0.18).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor,
        ]
        glossLayer.locations = [0.35, 0.5, 0.65]
        glossLayer.startPoint = CGPoint(x: 0.1, y: 0)
        glossLayer.endPoint = CGPoint(x: 0.9, y: 1)
        glossLayer.frame = CGRect(origin: .zero, size: ticketSize)
        glossLayer.opacity = 0
        ticketLayer.addSublayer(glossLayer)

        // The machine mouth — printed after the ticket so it covers the slot.
        let mouthSize = CGSize(width: min(bounds.width * 0.80, 340), height: 58)
        mouthGroup.frame = CGRect(
            x: bounds.midX - mouthSize.width / 2, y: mouthCenterY - mouthSize.height / 2,
            width: mouthSize.width, height: mouthSize.height
        )
        mouthGroup.opacity = 0
        layer.addSublayer(mouthGroup)

        mouthBody.contents = Self.renderMouth(size: mouthSize, scale: scale).cgImage
        mouthBody.frame = CGRect(origin: .zero, size: mouthSize)
        mouthBody.shadowColor = UIColor.black.cgColor
        mouthBody.shadowOpacity = 0.5
        mouthBody.shadowRadius = 20
        mouthBody.shadowOffset = CGSize(width: 0, height: 12)
        mouthBody.shadowPath = UIBezierPath(
            roundedRect: CGRect(origin: .zero, size: mouthSize), cornerRadius: 17
        ).cgPath
        mouthGroup.addSublayer(mouthBody)

        // Slot glow — 朱 breath while printing.
        let slotW = mouthSize.width * 0.72
        slotGlow.frame = CGRect(x: (mouthSize.width - slotW) / 2, y: mouthSize.height / 2 + 6, width: slotW, height: 3)
        slotGlow.backgroundColor = UIColor(red: 0.847, green: 0.251, blue: 0.122, alpha: 1).cgColor
        slotGlow.cornerRadius = 1.5
        slotGlow.shadowColor = slotGlow.backgroundColor
        slotGlow.shadowOpacity = 0.9
        slotGlow.shadowRadius = 6
        slotGlow.shadowOffset = .zero
        slotGlow.opacity = 0
        mouthGroup.addSublayer(slotGlow)

        // Status lamp.
        statusLamp.frame = CGRect(x: mouthSize.width - 26, y: 16, width: 6.5, height: 6.5)
        statusLamp.cornerRadius = 3.25
        statusLamp.backgroundColor = UIColor(red: 0.23, green: 0.21, blue: 0.18, alpha: 1).cgColor
        statusLamp.shadowColor = UIColor(red: 0.847, green: 0.251, blue: 0.122, alpha: 1).cgColor
        statusLamp.shadowOpacity = 0
        statusLamp.shadowRadius = 5
        statusLamp.shadowOffset = .zero
        mouthGroup.addSublayer(statusLamp)

        // Feed chevrons, pointing out of the slot.
        for i in 0..<3 {
            let ch = CAShapeLayer()
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: 4.5, y: 5.5))
            p.addLine(to: CGPoint(x: 9, y: 0))
            ch.path = p.cgPath
            ch.strokeColor = UIColor(red: 0.847, green: 0.251, blue: 0.122, alpha: 1).cgColor
            ch.fillColor = nil
            ch.lineWidth = 1.8
            ch.lineCap = .round
            ch.lineJoin = .round
            ch.frame = CGRect(x: 22 + CGFloat(i) * 14, y: 14, width: 9, height: 6)
            ch.opacity = 0.18
            mouthGroup.addSublayer(ch)
            chevrons.append(ch)
        }

        // The print line — a warm thread of light where paper meets air.
        printLine.frame = CGRect(x: bounds.midX - ticketSize.width / 2, y: slotLineY - 1, width: ticketSize.width, height: 2)
        printLine.backgroundColor = UIColor(red: 1.0, green: 0.93, blue: 0.78, alpha: 1).cgColor
        printLine.shadowColor = printLine.backgroundColor
        printLine.shadowOpacity = 0.8
        printLine.shadowRadius = 4
        printLine.shadowOffset = .zero
        printLine.opacity = 0
        layer.addSublayer(printLine)

        // The chad — punched out and gone.
        let chadD = ticketSize.width * 0.052
        chadLayer.bounds = CGRect(x: 0, y: 0, width: chadD, height: chadD)
        chadLayer.cornerRadius = chadD / 2
        chadLayer.backgroundColor = UIColor(red: 0.937, green: 0.906, blue: 0.839, alpha: 1).cgColor
        chadLayer.opacity = 0
        layer.addSublayer(chadLayer)
    }

    // MARK: Clock

    private func startClock() {
        startStamp = CACurrentMediaTime()
        lastT = clockOffset
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick() {
        let t = CACurrentMediaTime() - startStamp + clockOffset
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        evaluate(t)
        CATransaction.commit()
        lastT = t
    }

    /// Jump the clock (tap-to-skip): everything lands mid-flight state-free.
    private func skipToSettled() {
        guard phase == .opening, case .none = exit else { return }
        // Haptics for skipped beats never fire; one soft settle instead.
        firedHaptics = ["glyph", "hanko", "wake", "feed0", "feed1", "feed2", "feed3",
                        "feed4", "feed5", "feed6", "feed7", "feed8", "punch", "land"]
        clockOffset = Beat.settled + 0.01 - (CACurrentMediaTime() - startStamp)
        Haptic.play(.stamp)
    }

    // MARK: Timeline evaluation — one pure pass, every frame

    private func evaluate(_ t: Double) {
        room(t)
        wordmark(t)
        machine(t)
        specimen(t)
        if case .toGate(let target, let t0) = exit {
            evaluateExit(t, target: target, start: t0)
        } else if t >= Beat.settled, phase == .opening {
            phase = .settled
            fire("land") { Haptic.play(.stamp) }
        }
    }

    private func room(_ t: Double) {
        // The house lights dim first — the paper page beneath sinks into
        // the dark before the show begins. No hard cut from the launch.
        let dim = Ease.linstep(t, 0.04, 0.48)
        // Then the lamp catches: two quick dips like a filament finding itself.
        let warm: Double
        if t < Beat.lampOn {
            warm = 0
        } else if t < Beat.lampSteady {
            let p = Ease.linstep(t, Beat.lampOn, Beat.lampSteady)
            let flicker = (sin(p * 26) * 0.5 + 0.5) * (1 - p) * 0.45
            warm = max(0, p - flicker)
        } else {
            warm = 1
        }
        roomLayer.opacity = Float(Ease.outCubic(dim))
        // The pool drifts from the machine down to the settled exhibit.
        let follow = Ease.outCubic(Ease.linstep(t, Beat.release, Beat.settled))
        let poolY = Ease.lerp(mouthCenterY + 40, settleCenter.y - 30, follow)
        roomLayer.position = CGPoint(x: bounds.midX, y: bounds.midY + (poolY - bounds.height * 0.30) * 0.22)
        // Warmth rides on the pool image itself; scale breathes it in.
        let breathe = 0.92 + 0.08 * warm
        roomLayer.transform = CATransform3DMakeScale(breathe, breathe, 1)
    }

    private func wordmark(_ t: Double) {
        for (i, glyph) in glyphLayers.enumerated() {
            let t0 = Beat.glyphStart + Double(i) * Beat.glyphStagger
            let p = Ease.linstep(t, t0, t0 + Beat.glyphDur)
            let e = Ease.outCubic(p)
            glyph.opacity = Float(e)
            let s = 1.05 - 0.05 * e
            glyph.transform = CATransform3DMakeScale(s, s, 1)
            // Ink bleed relaxes as the press lifts.
            glyph.shadowOpacity = Float(0.55 * (1 - e) + 0.18 * e)
            if p > 0 { fire("glyph\(i)") { if i == 0 { Haptic.play(.tick) } } }
        }
        // Hanko: falls in hard, settles, blooms a ring of 朱.
        let hp = Ease.linstep(t, Beat.hanko, Beat.hanko + 0.34)
        if hp > 0 {
            fire("hanko") { Haptic.play(.stamp) }
            let e = Ease.outBack(hp, 1.9)
            hankoLayer.opacity = Float(min(1, hp * 3))
            let s = 1.65 - 0.65 * e
            var tr = CATransform3DMakeScale(s, s, 1)
            tr = CATransform3DRotate(tr, CGFloat((1 - e) * -0.14 - 0.044), 0, 0, 1)
            hankoLayer.transform = tr
        } else {
            hankoLayer.opacity = 0
        }
        let bp = Ease.linstep(t, Beat.hanko + 0.10, Beat.hanko + 0.75)
        if bp > 0, bp < 1 {
            hankoBloom.opacity = Float((1 - bp) * 0.55)
            let s = 0.4 + Ease.outCubic(bp) * 1.1
            hankoBloom.transform = CATransform3DMakeScale(s, s, 1)
        } else {
            hankoBloom.opacity = 0
        }
    }

    private func machine(_ t: Double) {
        // The mouth is discovered by the light.
        let wake = Ease.linstep(t, Beat.mouthWake - 0.35, Beat.mouthWake + 0.25)
        mouthGroup.opacity = Float(Ease.outCubic(wake))
        if wake >= 1 { fire("wake") { Haptic.play(.tick) } }

        // Status lamp: blinks twice on wake, holds 朱 through the print.
        let sinceWake = t - Beat.mouthWake
        let printing = t >= Beat.printStart && t <= Beat.printEnd
        let blink = sinceWake > 0 && sinceWake < 0.5 && (sinceWake.truncatingRemainder(dividingBy: 0.25) < 0.12)
        let lampOn = blink || printing
        statusLamp.backgroundColor = lampOn
            ? UIColor(red: 0.847, green: 0.251, blue: 0.122, alpha: 1).cgColor
            : UIColor(red: 0.23, green: 0.21, blue: 0.18, alpha: 1).cgColor
        statusLamp.shadowOpacity = lampOn ? 0.9 : 0

        // Chevrons march while paper moves.
        for (i, ch) in chevrons.enumerated() {
            if printing {
                let cycle = (t * 2.4 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                ch.opacity = Float(0.18 + 0.82 * (0.5 + 0.5 * sin(cycle * 2 * .pi)))
            } else {
                ch.opacity = 0.18
            }
        }

        // Slot glow breathes with the feed.
        slotGlow.opacity = printing ? Float(0.35 + 0.4 * feedPulse(t)) : 0

        // Punch flinch — the whole mouth takes the bite.
        let sincePunch = t - Beat.punch
        if sincePunch > 0 {
            let knock = exp(-sincePunch * 13) * sin(sincePunch * 42) * 2.6
            mouthGroup.transform = CATransform3DMakeTranslation(0, knock, 1)
        } else {
            mouthGroup.transform = CATransform3DIdentity
        }
    }

    /// 0…1 pulse within the current feed step (drives glow + print line).
    private func feedPulse(_ t: Double) -> Double {
        guard t >= Beat.printStart, t <= Beat.printEnd else { return 0 }
        let local = (t - Beat.printStart).truncatingRemainder(dividingBy: Beat.feedStep)
        return 1 - Ease.linstep(local, 0, Beat.feedStep)
    }

    /// Emergence 0…1 — nine hard line-feeds with tiny dwell, like thermal
    /// stock leaving a real machine.
    private func emergence(_ t: Double) -> Double {
        if t <= Beat.printStart { return 0 }
        if t >= Beat.printEnd { return 1 }
        let stepIdx = Int((t - Beat.printStart) / Beat.feedStep)
        let local = (t - Beat.printStart) - Double(stepIdx) * Beat.feedStep
        let travel = Ease.outCubic(Ease.linstep(local, 0, 0.10))
        fire("feed\(stepIdx)") { Haptic.play(.tick) }
        return min(1, (Double(stepIdx) + travel) / Double(Beat.feedSteps))
    }

    private func specimen(_ t: Double) {
        let e = emergence(t)

        // Print line rides the slot while paper moves.
        printLine.opacity = (t >= Beat.printStart && t <= Beat.printEnd + 0.1)
            ? Float(0.35 + 0.55 * feedPulse(t)) : 0

        // Position: hanging out of the slot by `e`, then released to hand.
        var center: CGPoint
        var scale: CGFloat = 1
        var rotZ: CGFloat = 0
        if t < Beat.release {
            let hang = slotLineY + CGFloat(e) * ticketSize.height - ticketSize.height / 2
            center = CGPoint(x: bounds.midX, y: hang)
        } else {
            let p = Ease.linstep(t, Beat.release, Beat.release + Beat.releaseDur)
            let drop = Ease.inOutCubicSettle(p)
            let from = CGPoint(x: bounds.midX, y: slotLineY + ticketSize.height / 2)
            center = CGPoint(
                x: Ease.lerp(from.x, settleCenter.x, drop),
                y: Ease.lerp(from.y, settleCenter.y, drop)
            )
            scale = Ease.lerp(1.0, 1.12, drop)
            rotZ = CGFloat(sin(drop * .pi) * -0.020)   // a leaf of sway on the way down
        }

        // Idle: the exhibit breathes.
        if t >= Beat.settled {
            let idle = t - Beat.settled
            center.y += CGFloat(sin(idle * 0.9)) * 2.6
            rotZ += CGFloat(sin(idle * 0.62 + 1.2)) * 0.006
        }

        // Tilt answers the hand (post-settle) — perspective + gloss.
        tilt.x += (tiltTarget.x - tilt.x) * 0.14
        tilt.y += (tiltTarget.y - tilt.y) * 0.14

        var tr = CATransform3DIdentity
        tr.m34 = -1 / 900
        tr = CATransform3DRotate(tr, tilt.y * -0.22, 1, 0, 0)
        tr = CATransform3DRotate(tr, tilt.x * 0.26, 0, 1, 0)
        tr = CATransform3DRotate(tr, rotZ, 0, 0, 1)
        tr = CATransform3DScale(tr, scale, scale, 1)
        ticketLayer.position = center
        ticketLayer.transform = tr

        // Gloss follows the tilt.
        let mag = min(1, hypot(tilt.x, tilt.y) * 1.6)
        glossLayer.opacity = Float(mag * 0.8)
        glossLayer.startPoint = CGPoint(x: 0.1 + tilt.x * 0.3, y: 0 + tilt.y * 0.3)
        glossLayer.endPoint = CGPoint(x: 0.9 + tilt.x * 0.3, y: 1 + tilt.y * 0.3)

        // Shadow deepens as the ticket leaves the machine's grip.
        let free = Ease.linstep(t, Beat.release, Beat.release + Beat.releaseDur)
        ticketLayer.shadowOpacity = Float(0.12 * e + 0.38 * free)
        ticketLayer.shadowRadius = 10 + 12 * free
        ticketLayer.shadowOffset = CGSize(width: 0, height: 8 + 8 * free)

        punchAndChad(t)
    }

    private func punchAndChad(_ t: Double) {
        guard let hole = holePoint else { return }
        let sincePunch = t - Beat.punch
        guard sincePunch >= 0 else {
            ticketLayer.mask = nil
            chadLayer.opacity = 0
            return
        }
        fire("punch") { Haptic.play(.punch) }

        // The hole — cut by mask, permanent from here on. Its cut edge
        // catches a hairline of light, like real punched stock.
        if ticketLayer.mask == nil {
            let m = CAShapeLayer()
            let path = UIBezierPath(rect: CGRect(origin: .zero, size: CGSize(width: ticketSize.width, height: ticketSize.height)))
            let r = ticketSize.width * 0.026
            let c = CGPoint(x: hole.x * ticketSize.width, y: hole.y * ticketSize.height)
            path.append(UIBezierPath(ovalIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)))
            m.path = path.cgPath
            m.fillRule = .evenOdd
            m.fillColor = UIColor.black.cgColor
            ticketLayer.mask = m

            let rim = CAShapeLayer()
            rim.path = UIBezierPath(ovalIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)).cgPath
            rim.fillColor = nil
            rim.strokeColor = UIColor.black.withAlphaComponent(0.30).cgColor
            rim.lineWidth = 1.1
            ticketLayer.addSublayer(rim)
        }

        // The chad — a breath of paper, falling and tumbling, gone.
        let life = 0.85
        if sincePunch < life {
            let p = sincePunch / life
            let holeInView = ticketLayer.convert(
                CGPoint(x: hole.x * ticketSize.width, y: hole.y * ticketSize.height),
                to: layer
            )
            chadLayer.opacity = Float(1 - Ease.linstep(p, 0.6, 1))
            let fall = CGFloat(p * p) * 190
            let swayX = CGFloat(sin(p * 7.3)) * 9
            chadLayer.position = CGPoint(x: holeInView.x + swayX, y: holeInView.y + fall)
            var tr = CATransform3DMakeRotation(CGFloat(p * 2.4), 0, 0, 1)
            tr = CATransform3DScale(tr, 1, max(0.12, abs(cos(p * 9.0))), 1)   // seen edge-on as it turns
            chadLayer.transform = tr
        } else {
            chadLayer.opacity = 0
        }
    }

    // MARK: Exit — the specimen hands itself to the gate

    /// The ceremony ends: the ticket glides into the punch button's spot,
    /// the room's lights come up, and the page beneath is live.
    func exitToGate(completion: @escaping () -> Void) {
        guard case .none = exit else { return }
        phase = .exiting
        exitCompletion = completion
        let target = CGPoint(
            x: bounds.midX,
            y: bounds.height - safeAreaInsets.bottom - 44
        )
        exit = .toGate(target, lastT)
    }

    private func evaluateExit(_ t: Double, target: CGPoint, start: Double) {
        let dur = 0.62
        let p = Ease.linstep(t, start, start + dur)
        let e = Ease.inCubic(p)

        // The ticket dives for the gate, shrinking into it.
        let from = settleCenter
        var center = CGPoint(
            x: Ease.lerp(from.x, target.x, e),
            y: Ease.lerp(from.y, target.y, e)
        )
        center.y -= CGFloat(sin(p * .pi)) * 26   // a small arc, not a straight fall
        let scale = Ease.lerp(1.12, 0.10, e)
        var tr = CATransform3DMakeScale(scale, scale, 1)
        tr = CATransform3DRotate(tr, CGFloat(e * -0.35), 0, 0, 1)
        ticketLayer.position = center
        ticketLayer.transform = tr
        ticketLayer.shadowOpacity = Float(0.38 * (1 - p))
        ticketLayer.opacity = Float(1 - Ease.linstep(p, 0.82, 1))

        // Everything else breathes out; the room's lights come up.
        let fade = Float(1 - Ease.linstep(p, 0, 0.55))
        for g in glyphLayers { g.opacity = fade }
        hankoLayer.opacity = fade
        mouthGroup.opacity = fade
        roomLayer.opacity = Float(1 - Ease.inCubic(Ease.linstep(p, 0.25, 1)))

        if p >= 1 {
            fire("exit") { Haptic.play(.punch) }
            exit = .none
            link?.invalidate()
            link = nil
            exitCompletion?()
            exitCompletion = nil
        }
    }

    // MARK: Input

    @objc private func onTap() {
        if phase == .opening { skipToSettled() }
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        guard phase == .settled else { return }
        switch g.state {
        case .changed:
            let tr = g.translation(in: self)
            tiltTarget = CGPoint(
                x: max(-1, min(1, tr.x / 190)),
                y: max(-1, min(1, tr.y / 190))
            )
        default:
            tiltTarget = .zero
        }
    }

    private func fire(_ name: String, _ play: () -> Void = {}) {
        guard !firedHaptics.contains(name) else { return }
        firedHaptics.insert(name)
        play()
    }

    // MARK: One-time textures

    /// The night room with its warm pool — dithered by hand so the falloff
    /// never bands, rendered once.
    private static func renderRoom(size: CGSize, scale: CGFloat) -> UIImage {
        let full = CGSize(width: size.width * 1.4, height: size.height * 1.4)
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(scale, 2)
        format.opaque = true
        return UIGraphicsImageRenderer(size: full, format: format).image { ctx in
            let cg = ctx.cgContext
            // Deep floor.
            cg.setFillColor(UIColor(red: 0.040, green: 0.033, blue: 0.026, alpha: 1).cgColor)
            cg.fill(CGRect(origin: .zero, size: full))
            // Warm pool, upper center — generous enough that the room
            // reads as *lit*, never flat black.
            let center = CGPoint(x: full.width / 2, y: full.height * 0.30)
            let colors = [
                UIColor(red: 0.168, green: 0.138, blue: 0.104, alpha: 1).cgColor,
                UIColor(red: 0.104, green: 0.086, blue: 0.065, alpha: 1).cgColor,
                UIColor(red: 0.040, green: 0.033, blue: 0.026, alpha: 0).cgColor,
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.42, 1]
            )!
            cg.drawRadialGradient(
                gradient,
                startCenter: center, startRadius: 0,
                endCenter: center, endRadius: full.width * 1.0,
                options: []
            )
            // Hand dither — kills the banding a pure gradient would show.
            var rng = SeededRandom(0xD17)
            cg.setBlendMode(.plusLighter)
            for _ in 0..<3600 {
                let x = CGFloat(rng.unit()) * full.width
                let y = CGFloat(rng.unit()) * full.height
                cg.setFillColor(UIColor.white.withAlphaComponent(CGFloat(rng.double(in: 0.004...0.012))).cgColor)
                cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
    }

    /// The machine mouth — machined block, recessed slot, bevel light.
    private static func renderMouth(size: CGSize, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let body = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 17)
            cg.addPath(body.cgPath)
            cg.clip()

            cg.setFillColor(UIColor(red: 0.133, green: 0.110, blue: 0.082, alpha: 1).cgColor)  // 0x221C15
            cg.fill(CGRect(origin: .zero, size: size))

            // Top-face light / bottom seat.
            let g = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.white.withAlphaComponent(0.085).cgColor,
                    UIColor.clear.cgColor,
                    UIColor.black.withAlphaComponent(0.18).cgColor,
                ] as CFArray,
                locations: [0, 0.45, 1]
            )!
            cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

            // Machined bevel.
            cg.resetClip()
            let bevel = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5), cornerRadius: 16.5)
            cg.addPath(bevel.cgPath)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.13).cgColor)
            cg.setLineWidth(1)
            cg.strokePath()

            // The slot — an actual recess with a lower lip highlight.
            let slotW = size.width * 0.72
            let slot = CGRect(x: (size.width - slotW) / 2, y: size.height / 2 + 2, width: slotW, height: 8)
            let slotPath = UIBezierPath(roundedRect: slot, cornerRadius: 4)
            cg.setFillColor(UIColor.black.withAlphaComponent(0.92).cgColor)
            cg.addPath(slotPath.cgPath)
            cg.fillPath()
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.08).cgColor)
            cg.setLineWidth(1)
            cg.move(to: CGPoint(x: slot.minX + 3, y: slot.maxY + 1.5))
            cg.addLine(to: CGPoint(x: slot.maxX - 3, y: slot.maxY + 1.5))
            cg.strokePath()
        }
    }

    /// 落款 — the same 白文 seal as `HankoSeal`, in CG.
    private static func renderHanko(size: CGFloat, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { ctx in
            let cg = ctx.cgContext
            let r = size * 0.16
            let box = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), cornerRadius: r)
            cg.setFillColor(UIColor(red: 0.847, green: 0.251, blue: 0.122, alpha: 1).cgColor)
            cg.addPath(box.cgPath)
            cg.fillPath()
            let inner = UIBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: size * 0.07, dy: size * 0.07),
                cornerRadius: r * 0.7
            )
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
            cg.setLineWidth(max(0.5, size * 0.03))
            cg.addPath(inner.cgPath)
            cg.strokePath()

            let font = UIFont(name: "HiraMinProN-W6", size: size * 0.60) ?? .boldSystemFont(ofSize: size * 0.60)
            let ch = NSAttributedString(string: "き", attributes: [
                .font: font,
                .foregroundColor: UIColor(red: 0.969, green: 0.953, blue: 0.922, alpha: 1),
            ])
            let chSize = ch.size()
            ch.draw(at: CGPoint(x: (size - chSize.width) / 2, y: (size - chSize.height) / 2 - size * 0.01))
        }
    }
}

// MARK: - Easing vocabulary

/// Tiny easing kit for the master clock — pure, allocation-free.
enum Ease {
    /// Clamped 0…1 progress of `t` across [a, b].
    static func linstep(_ t: Double, _ a: Double, _ b: Double) -> Double {
        guard b > a else { return t >= b ? 1 : 0 }
        return min(1, max(0, (t - a) / (b - a)))
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ p: Double) -> CGFloat {
        a + (b - a) * CGFloat(p)
    }

    static func outCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    static func inCubic(_ x: Double) -> Double { x * x * x }

    /// Ease-in then a soft landed settle — a drop with weight but no bounce.
    static func inOutCubicSettle(_ x: Double) -> Double {
        if x < 0.5 { return 4 * x * x * x }
        let f = 2 * x - 2
        return 1 + f * f * f / 2
    }

    /// Back overshoot (for stamps).
    static func outBack(_ x: Double, _ s: Double = 1.70158) -> Double {
        let c3 = s + 1
        return 1 + c3 * pow(x - 1, 3) + s * pow(x - 1, 2)
    }
}
