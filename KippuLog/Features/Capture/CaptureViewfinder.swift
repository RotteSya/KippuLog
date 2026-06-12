import SwiftUI

/// The living viewfinder. One guide system in three acts:
///
///   seeking — four corner grips breathe around a MARS-proportioned
///             window cut out of a dim veil;
///   lock-on — the grips fly onto the detected ticket and hold its actual
///             corners while the veil re-cuts itself around the quad and
///             deepens — the room steps back, the ticket is the subject;
///   hold    — a vermilion loop draws itself around the ticket from the
///             top centre, both ways at once, timing the hold-still
///             window; the loop seals exactly as the gate fires.
///
/// `frozen` is the instant after the shutter: the veil goes near-black
/// and every guide retires — the room goes dark, the ticket stays lit.
struct CaptureViewfinder: View {
    /// Detected quad in normalized buffer coords (top-left origin),
    /// ordered topLeft, topRight, bottomRight, bottomLeft.
    var quad: [CGPoint]?
    /// Buffer aspect (w/h) for aspect-fill mapping.
    var bufferAspect: CGFloat
    /// When the quad started holding still — drives the vermilion loop.
    var steadySince: Date?
    var frozen: Bool

    @State private var display: Quad4?
    @State private var tracking = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let locked = quad != nil
            ZStack {
                if let display {
                    veil(display, locked: locked)
                    guides(display, locked: locked)
                        .opacity(frozen ? 0 : 1)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: locked)
            .animation(.easeInOut(duration: 0.30), value: frozen)
            .onAppear { retarget(quad, in: size, animated: false) }
            .onChange(of: quad) { _, newValue in
                retarget(newValue, in: size, animated: true)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Layers

    private func veil(_ display: Quad4, locked: Bool) -> some View {
        Color.black.opacity(frozen ? 0.965 : locked ? 0.56 : 0.42)
            .mask {
                QuadHole(quad: display, cornerRadius: 10)
                    .fill(.white, style: FillStyle(eoFill: true))
            }
    }

    private func guides(_ display: Quad4, locked: Bool) -> some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: frozen)) { timeline in
            let hold = CaptureHold.progress(at: timeline.date, since: steadySince)
            ZStack {
                CornerGrips(quad: display, arm: locked ? 22 : 26, cornerRadius: 10)
                    .stroke(
                        .white.opacity(locked ? 0.97 : breath(at: timeline.date)),
                        style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 4, y: 1)

                if hold > 0 {
                    ZStack {
                        QuadLoop(quad: display, clockwise: true, cornerRadius: 10)
                            .trim(from: 0, to: hold * 0.5)
                            .stroke(Ink.shu, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        QuadLoop(quad: display, clockwise: false, cornerRadius: 10)
                            .trim(from: 0, to: hold * 0.5)
                            .stroke(Ink.shu, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                    .shadow(color: Ink.shu.opacity(0.8), radius: 7)
                }
            }
        }
    }

    /// Slow paper-lantern breathing while seeking.
    private func breath(at date: Date) -> Double {
        0.50 + 0.34 * (0.5 + 0.5 * sin(date.timeIntervalSinceReferenceDate * 2 * .pi / 2.6))
    }

    // MARK: Targeting

    private func retarget(_ newQuad: [CGPoint]?, in size: CGSize, animated: Bool) {
        let target: Quad4
        let animation: Animation
        if let newQuad, newQuad.count == 4 {
            target = Quad4(
                topLeft: Self.mapToLayer(newQuad[0], bufferAspect: bufferAspect, in: size),
                topRight: Self.mapToLayer(newQuad[1], bufferAspect: bufferAspect, in: size),
                bottomRight: Self.mapToLayer(newQuad[2], bufferAspect: bufferAspect, in: size),
                bottomLeft: Self.mapToLayer(newQuad[3], bufferAspect: bufferAspect, in: size)
            )
            // First sight is a flight; after that, glide with the hand.
            animation = tracking
                ? .spring(response: 0.30, dampingFraction: 0.92)
                : .spring(response: 0.50, dampingFraction: 0.74)
            tracking = true
        } else {
            target = Self.homeQuad(in: size)
            animation = .spring(response: 0.55, dampingFraction: 0.86)
            tracking = false
        }
        guard animated, display != nil else {
            display = target
            return
        }
        withAnimation(animation) { display = target }
    }

    /// MARS-proportioned home window, centred where a held ticket sits.
    static func homeQuad(in size: CGSize) -> Quad4 {
        let width = size.width * 0.84
        let height = width / MarsTicketFace.aspect
        let rect = CGRect(
            x: (size.width - width) / 2,
            y: size.height * 0.42 - height / 2,
            width: width,
            height: height
        )
        return Quad4(rect: rect)
    }

    /// Normalized buffer point → layer point under aspect-fill.
    static func mapToLayer(_ p: CGPoint, bufferAspect: CGFloat, in layer: CGSize) -> CGPoint {
        let layerAspect = layer.width / max(layer.height, 1)
        var displayWidth = layer.width
        var displayHeight = layer.height
        if bufferAspect > layerAspect {
            displayWidth = layer.height * bufferAspect
        } else {
            displayHeight = layer.width / bufferAspect
        }
        let offsetX = (layer.width - displayWidth) / 2
        let offsetY = (layer.height - displayHeight) / 2
        return CGPoint(x: offsetX + p.x * displayWidth, y: offsetY + p.y * displayHeight)
    }
}

// MARK: - The hold clock

/// One clock for the hold-to-fire window: the camera service arms it, the
/// quad loop and the shutter ring both draw it.
enum CaptureHold {
    /// A touch longer than the service's trigger so the loop is just
    /// sealing as the gate fires — the flash answers the closed loop.
    static let window: TimeInterval = CameraService.steadyTarget + 0.12

    static func progress(at date: Date, since: Date?) -> Double {
        guard let since else { return 0 }
        return min(1, max(0, date.timeIntervalSince(since) / window))
    }
}

// MARK: - Studio dressing

/// Quiet vignette over the live preview — the corners fall away so the
/// frame reads like a lit table, not a security feed.
struct StudioVignette: View {
    var body: some View {
        EllipticalGradient(
            stops: [
                .init(color: .clear, location: 0.58),
                .init(color: .black.opacity(0.34), location: 1.0),
            ],
            center: UnitPoint(x: 0.5, y: 0.44)
        )
        .blendMode(.multiply)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Geometry

/// Four corners, animatable — the single currency every guide shape
/// shares, so veil, grips and loop morph in perfect lockstep.
nonisolated struct Quad4: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    init(rect: CGRect) {
        topLeft = CGPoint(x: rect.minX, y: rect.minY)
        topRight = CGPoint(x: rect.maxX, y: rect.minY)
        bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
    }

    typealias Data = AnimatablePair<
        AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData>,
        AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData>
    >

    var animatableData: Data {
        get {
            AnimatablePair(
                AnimatablePair(topLeft.animatableData, topRight.animatableData),
                AnimatablePair(bottomRight.animatableData, bottomLeft.animatableData)
            )
        }
        set {
            topLeft.animatableData = newValue.first.first
            topRight.animatableData = newValue.first.second
            bottomRight.animatableData = newValue.second.first
            bottomLeft.animatableData = newValue.second.second
        }
    }

    /// The rounded outline, starting at the top edge's midpoint and
    /// running one way around — trim two of these, one per direction, and
    /// the loop closes like hands sealing around the ticket.
    func loopPath(clockwise: Bool, cornerRadius: CGFloat, closed: Bool = false) -> Path {
        let mid = CGPoint(x: (topLeft.x + topRight.x) / 2, y: (topLeft.y + topRight.y) / 2)
        let ring = clockwise
            ? [topRight, bottomRight, bottomLeft, topLeft]
            : [topLeft, bottomLeft, bottomRight, topRight]
        var path = Path()
        path.move(to: mid)
        var previous = mid
        for (index, corner) in ring.enumerated() {
            let next = index + 1 < ring.count ? ring[index + 1] : mid
            let entry = Self.direction(from: previous, to: corner)
            let exit = Self.direction(from: corner, to: next)
            let radius = min(
                cornerRadius,
                Self.distance(previous, corner) * 0.4,
                Self.distance(corner, next) * 0.4
            )
            path.addLine(to: Self.offset(corner, by: entry, scaled: -radius))
            path.addQuadCurve(to: Self.offset(corner, by: exit, scaled: radius), control: corner)
            previous = corner
        }
        if closed {
            path.closeSubpath()
        } else {
            path.addLine(to: mid)
        }
        return path
    }

    static func direction(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = max(hypot(dx, dy), 0.0001)
        return CGPoint(x: dx / length, y: dy / length)
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }

    static func offset(_ p: CGPoint, by d: CGPoint, scaled s: CGFloat) -> CGPoint {
        CGPoint(x: p.x + d.x * s, y: p.y + d.y * s)
    }
}

/// Dim veil with the quad cut out (even-odd).
private nonisolated struct QuadHole: Shape {
    var quad: Quad4
    var cornerRadius: CGFloat

    var animatableData: Quad4.Data {
        get { quad.animatableData }
        set { quad.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addPath(quad.loopPath(clockwise: true, cornerRadius: cornerRadius, closed: true))
        return path
    }
}

/// Four corner grips — fragments of the same rounded outline, so locking
/// on reads as the frame becoming the ticket's own corners.
private nonisolated struct CornerGrips: Shape {
    var quad: Quad4
    var arm: CGFloat
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<Quad4.Data, CGFloat> {
        get { AnimatablePair(quad.animatableData, arm) }
        set {
            quad.animatableData = newValue.first
            arm = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let ring = [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft]
        for index in 0..<4 {
            let corner = ring[index]
            let prev = ring[(index + 3) % 4]
            let next = ring[(index + 1) % 4]
            let inDir = Quad4.direction(from: prev, to: corner)
            let outDir = Quad4.direction(from: corner, to: next)
            let armIn = min(arm, Quad4.distance(prev, corner) * 0.3)
            let armOut = min(arm, Quad4.distance(corner, next) * 0.3)
            let radius = min(cornerRadius, armIn * 0.55, armOut * 0.55)
            path.move(to: Quad4.offset(corner, by: inDir, scaled: -armIn))
            path.addLine(to: Quad4.offset(corner, by: inDir, scaled: -radius))
            path.addQuadCurve(to: Quad4.offset(corner, by: outDir, scaled: radius), control: corner)
            path.addLine(to: Quad4.offset(corner, by: outDir, scaled: armOut))
        }
        return path
    }
}

/// The hold loop — one direction of the sealing stroke.
private nonisolated struct QuadLoop: Shape {
    var quad: Quad4
    var clockwise: Bool
    var cornerRadius: CGFloat

    var animatableData: Quad4.Data {
        get { quad.animatableData }
        set { quad.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        quad.loopPath(clockwise: clockwise, cornerRadius: cornerRadius)
    }
}
