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

        // Paper laid down, not bounced — a dead-beat spring, with a hard
        // ceiling so a starved run loop can never strand the fold.
        let accel = -175 * (fold - target) - 26 * velocity
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
        // The page stays paper-opaque through the fold — only the last
        // edge-on sliver dissolves, so the eye never reads two sheets.
        let opacity = folds
            ? 1 - smoothWindow(f, from: 0.72, to: 0.93)
            : 1 - smoothWindow(f, from: 0.15, to: 0.85)
        content
            // The page is PAPER — it carries its own opaque sheet. The
            // shared app background lives behind the album; without this
            // the fold would show the collection straight through the
            // issue's clear scroll surface.
            .background(Ink.background.ignoresSafeArea())
            .modifier(SheetFoldGeometry(fold: folds ? f : 0))
            .brightness(folds ? -0.30 * f : 0)
            .opacity(opacity)
            .allowsHitTesting(engine.scrubbing || f < 0.02)
            .accessibilityHidden(f > 0.5)
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
            .overlay {
                // The folding page's shade sweeping off the kraft — the
                // hinge is at the bottom, so the shadow pools there.
                LinearGradient(
                    colors: [.clear, .black.opacity(0.18 * sin(f * .pi))],
                    startPoint: UnitPoint(x: 0.5, y: 0.35),
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .allowsHitTesting(engine.scrubbing || f > 0.98)
            .accessibilityHidden(f < 0.5)
    }
}

/// The page's lay-back as one projection about its bottom edge — a
/// GeometryEffect so that at rest it is a TRUE identity (no transform
/// layer, no hit-test detour; the XCUITest event-routing lesson from
/// the stage's PageTurn holds here too).
private struct SheetFoldGeometry: GeometryEffect {
    var fold: Double

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard fold > 0.0001 else { return ProjectionTransform() }
        var t = CATransform3DIdentity
        // Eye distance ~1.9 page-heights: a sheet on a table, not a
        // door slamming in a fisheye.
        t.m34 = -1 / max(size.height * 1.9, 1)
        t = CATransform3DTranslate(t, 0, size.height, 0)
        t = CATransform3DRotate(t, fold * 76 * .pi / 180, 1, 0, 0)
        t = CATransform3DTranslate(t, 0, -size.height, 0)
        return ProjectionTransform(t)
    }
}

/// 0→1 across [from, to] with cubic smoothing (never write
/// smoothstep(e0, e1, x) with e0 ≥ e1 — the Metal lesson, kept here).
private func smoothWindow(_ x: Double, from lo: Double, to hi: Double) -> Double {
    let t = ((x - lo) / max(hi - lo, 0.0001)).clamped(to: 0...1)
    return t * t * (3 - 2 * t)
}
