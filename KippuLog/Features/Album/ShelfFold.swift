import SwiftUI
import UIKit

/// 綴じ — the fold between the 誌面 (the open issue) and the 収蔵帳
/// (the collection it belongs to). The issue lies on top of the album;
/// pinching it closed lays the page back on its bottom hinge and the
/// collection is simply *uncovered* beneath — one continuous fold that
/// the fingers scrub live and the release carries straight through.
/// The two shelves never crossfade: uncovering is the transition.
///
/// Same architecture as the lift: a CADisplayLink integrates one spring,
/// SwiftUI merely prints the values. At rest the fold leaves no residue
/// anywhere — identity geometry, full hit-testing, one shelf mounted.
@Observable
@MainActor
final class ShelfFold: NSObject {

    /// 0 = the issue lies flat on top … 1 = folded away, album showing.
    private(set) var fold: Double = 0
    /// The resting truth — which shelf owns the room between folds.
    private(set) var albumShowing: Bool
    /// A finger owns the fold right now (release hands it to the spring).
    private(set) var scrubbing = false
    /// Reduce Motion folds nothing — the shelves hand over in a dissolve.
    private(set) var foldsPages = !UIAccessibility.isReduceMotionEnabled

    /// Mount rules: both shelves live only while the fold is in motion.
    var albumMounted: Bool { albumShowing || fold > 0.001 }
    var magazineMounted: Bool { !albumShowing || fold < 0.999 }

    init(startInAlbum: Bool = false) {
        albumShowing = startInAlbum
        fold = startInAlbum ? 1 : 0
    }

    // MARK: The fingers

    /// The issue's pinch — magnification below 1 folds the page away.
    func scrubClose(magnification m: Double) {
        beginScrub()
        fold = (scrubBase + (1 - m) / 0.42).clamped(to: 0...0.78)
    }

    /// The album's pinch — magnification above 1 lays the page back down.
    func scrubOpen(magnification m: Double) {
        beginScrub()
        fold = (scrubBase - (m - 1) / 0.50).clamped(to: 0.22...1)
    }

    /// Release the closing pinch: past the threshold the fold commits,
    /// otherwise the page settles back where it lay.
    func releaseClose() {
        guard scrubbing else { return }
        scrubbing = false
        go(toAlbum: fold > 0.18)
    }

    /// Release the opening pinch.
    func releaseOpen() {
        guard scrubbing else { return }
        scrubbing = false
        go(toAlbum: fold > 0.85)
    }

    private func beginScrub() {
        if !scrubbing {
            scrubbing = true
            scrubBase = fold
            target = nil
            foldsPages = !UIAccessibility.isReduceMotionEnabled
            stop()
        }
    }

    // MARK: The doors

    /// Fold the whole way on the engine's own clock (corner doors, month
    /// stamps, and every released pinch end up here).
    func go(toAlbum: Bool) {
        let destination: Double = toAlbum ? 1 : 0
        if toAlbum != albumShowing { Haptic.play(.page) }
        scrubbing = false
        foldsPages = !UIAccessibility.isReduceMotionEnabled
        albumShowing = toAlbum
        guard abs(fold - destination) > 0.0005 else {
            fold = destination
            return
        }
        target = destination
        velocity = 0
        startClock()
    }

    // MARK: Spring internals

    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var lastTick: CFTimeInterval = 0
    @ObservationIgnored private var velocity: Double = 0
    @ObservationIgnored private var target: Double?
    @ObservationIgnored private var scrubBase: Double = 0
    @ObservationIgnored private var clockStart: CFTimeInterval = 0

    private func startClock() {
        clockStart = CACurrentMediaTime()
        lastTick = clockStart
        link?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 1.0 / 30.0)
        lastTick = now
        guard let target else { stop(); return }

        // Paper rolled, not bounced — a dead-beat spring with a touch of
        // glide (the roll travels the page's whole diagonal), and a hard
        // ceiling so a starved run loop can never strand the fold.
        let accel = -150 * (fold - target) - 24.5 * velocity
        velocity += accel * dt
        fold += velocity * dt

        let overdue = now - clockStart > 1.2
        if overdue || (abs(fold - target) < 0.002 && abs(velocity) < 0.05) {
            fold = target
            self.target = nil
            stop()
        }
    }

    private func stop() {
        link?.invalidate()
        link = nil
    }
}

// MARK: - What the fold does to each shelf

extension View {
    /// The issue in the fold's hand: hinged at its bottom edge, laying
    /// back into shadow as the album is uncovered top-first beneath it.
    /// At rest this is value-identical to not being here at all.
    func magazineFold(_ engine: ShelfFold) -> some View {
        modifier(MagazineFoldEffect(engine: engine))
    }

    /// The collection beneath: a step recessed and shaded while covered,
    /// rising into its own light as the page above lays away.
    func albumReveal(_ engine: ShelfFold) -> some View {
        modifier(AlbumRevealEffect(engine: engine))
    }
}

private struct MagazineFoldEffect: ViewModifier {
    let engine: ShelfFold

    func body(content: Content) -> some View {
        let f = engine.fold
        let folds = engine.foldsPages
        content
            // The page is PAPER — it carries its own opaque sheet. The
            // shared app background lives behind the album; without this
            // the fold would show the collection straight through the
            // issue's clear scroll surface.
            .background(Ink.background.ignoresSafeArea())
            // Reduce Motion: no roll — a quiet dissolve between shelves.
            .opacity(folds ? 1 : 1 - smoothWindow(f, from: 0.15, to: 0.85))
            // The still-flat part of the sheet. Everything past the
            // contact line has wound onto the roll — a diagonal mask,
            // pure compositing, so the LIVE scroll view keeps breathing
            // underneath. (A Metal layerEffect cannot see a platform-
            // backed ScrollView at all — the layer renders empty; hence
            // the curl is drawn, not sampled.)
            .mask {
                FlatSheetRegion(fold: folds ? f : 0, radius: ShelfFold.curlRadius)
                    .ignoresSafeArea()
            }
            // The roll itself, drawn per frame: a cylinder of the page's
            // own paper — crest light, silhouette rim, and the shadows it
            // drags across what it uncovers. Every column of the page
            // bends on its own; nothing moves like a slide transition.
            .overlay {
                // Structurally absent at rest — the round-8 lesson: any
                // standing residue over the page corrupts synthesized-
                // event routing for XCUITest, even hit-test-transparent.
                if folds && f > 0.0005 {
                    CurlRoll(fold: f, radius: ShelfFold.curlRadius)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .allowsHitTesting(engine.scrubbing || f < 0.02)
            .accessibilityHidden(f > 0.5)
    }
}

extension ShelfFold {
    /// The roll's radius in points — one cylinder for mask and chrome.
    static let curlRadius: CGFloat = 58
}

/// The half-plane of page still lying flat: everything the roll hasn't
/// reached, measured along the diagonal from the bottom-trailing corner.
private struct FlatSheetRegion: Shape {
    var fold: Double
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        guard fold > 0.0005 else { return Path(rect.insetBy(dx: -80, dy: -80)) }
        let diagonal = hypot(rect.width, rect.height)
        let contact = fold * (diagonal + 2.6 * radius)
        // A huge rect in curl coordinates (x along the diagonal from the
        // corner), swung into place about the bottom-trailing corner.
        let span = diagonal * 4
        return Path(CGRect(x: contact, y: -span, width: span * 2, height: span * 2))
            .applying(
                CGAffineTransform(translationX: rect.maxX, y: rect.maxY)
                    .rotated(by: atan2(-rect.height, -rect.width))
            )
    }
}

/// The rolled-up paper travelling the diagonal, drawn — not sampled.
private struct CurlRoll: View {
    var fold: Double
    var radius: CGFloat
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { ctx, size in
            guard fold > 0.0005 else { return }
            let diagonal = hypot(size.width, size.height)
            let contact = fold * (diagonal + 2.6 * radius)
            let r = radius
            // How much paper the roll has wound up — nothing to shade
            // at the very first touch.
            let body = min(contact / (.pi * r), 1)

            ctx.transform = CGAffineTransform(translationX: size.width, y: size.height)
                .rotated(by: atan2(-size.height, -size.width))
            let span = diagonal * 4
            func band(_ from: CGFloat, _ to: CGFloat) -> Path {
                Path(CGRect(x: from, y: -span, width: to - from, height: span * 2))
            }
            func at(_ x: CGFloat) -> CGPoint { CGPoint(x: x, y: 0) }

            // The sheet's own paper, lit around the cylinder: silhouette
            // edge dark against the album, crest catching the lamp, a
            // crease where the flat page feeds under.
            let stops: [Gradient.Stop] = [
                .init(color: paper(0.75), location: 0),
                .init(color: paper(0.90), location: 0.24),
                .init(color: paper(1.035), location: 0.52),
                .init(color: paper(0.965), location: 0.80),
                .init(color: paper(0.86), location: 1),
            ]
            // The shadow the roll drags across the uncovered collection.
            ctx.fill(
                band(contact - r - 46, contact - r + 0.5),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.15 * body), location: 1),
                    ]),
                    startPoint: at(contact - r - 46),
                    endPoint: at(contact - r)
                )
            )
            // The roll.
            ctx.fill(
                band(contact - r, contact + r),
                with: .linearGradient(
                    Gradient(stops: stops),
                    startPoint: at(contact - r),
                    endPoint: at(contact + r)
                )
            )
            // Paper-thickness rim on the silhouette edge.
            ctx.fill(
                band(contact - r, contact - r + 0.9),
                with: .color(.black.opacity(0.20 * body))
            )
            // The loom: soft shade pooling on the flat page just ahead.
            ctx.fill(
                band(contact + r, contact + r + 32),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .black.opacity(0.13 * body), location: 0),
                        .init(color: .clear, location: 1),
                    ]),
                    startPoint: at(contact + r),
                    endPoint: at(contact + r + 32)
                )
            )
        }
    }

    /// The page's paper shaded around the cylinder — resolved by scheme
    /// (Ink.background's own light/dark stock).
    private func paper(_ k: Double) -> Color {
        let base: (Double, Double, Double) = scheme == .dark
            ? (0.090, 0.078, 0.067)   // #171411
            : (0.969, 0.953, 0.922)   // #F7F3EB
        return Color(
            red: min(base.0 * k, 1),
            green: min(base.1 * k, 1),
            blue: min(base.2 * k, 1)
        )
    }
}

private struct AlbumRevealEffect: ViewModifier {
    let engine: ShelfFold

    func body(content: Content) -> some View {
        let f = engine.fold
        let folds = engine.foldsPages
        let rise = Ease.outCubic(f)
        content
            .scaleEffect(folds ? 0.955 + 0.045 * rise : 1)
            .brightness(folds ? -0.08 * (1 - rise) : 0)
            .opacity(folds ? 1 : smoothWindow(f, from: 0.15, to: 0.85))
            .allowsHitTesting(engine.scrubbing || f > 0.98)
            .accessibilityHidden(f < 0.5)
    }
}

/// 0→1 across [from, to] with cubic smoothing (never write
/// smoothstep(e0, e1, x) with e0 ≥ e1 — the Metal lesson, kept here).
private func smoothWindow(_ x: Double, from lo: Double, to hi: Double) -> Double {
    let t = ((x - lo) / max(hi - lo, 0.0001)).clamped(to: 0...1)
    return t * t * (3 - 2 * t)
}
