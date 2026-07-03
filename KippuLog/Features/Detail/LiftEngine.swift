import SwiftUI
import UIKit

/// 持ち上げ — the lift. Every journey between the page and the stage is
/// one continuous camera move owned by this engine: tap a card and the
/// room dims around the rising ticket; close and the lamp goes out as it
/// springs back to its printed place; save and the fresh ticket sails
/// from the desk down into the book. No navigation stack, no system
/// transition, no cut anywhere — a CADisplayLink integrates one spring
/// per flight and SwiftUI merely prints the values.
@Observable
@MainActor
final class LiftEngine: NSObject {

    // MARK: Slots — where tickets live on the page

    /// Global frames of every visible shelf slot, keyed "t-<id>" (誌面)
    /// or "a-<id>" (収蔵帳). Cards register themselves as they lay out.
    @ObservationIgnored var homes: [String: CGRect] = [:]
    /// The slot the stage will return to — follows paging.
    @ObservationIgnored var activeKey = ""

    /// A slot frame is trustworthy when it actually lies near the page.
    func home(for key: String) -> CGRect? {
        guard let frame = homes[key], frame.width > 20 else { return nil }
        let screen = UIScreen.main.bounds.insetBy(dx: -60, dy: -60)
        return screen.intersects(frame) ? frame : nil
    }

    // MARK: Flight state (published — the overlay prints these raw)

    enum Kind { case open, close, save }

    struct Flight {
        var kind: Kind
        var ticket: Ticket
        var from: CGRect
        var to: CGRect
        /// When set, the landing chases the slot's *live* frame — the
        /// page may still be settling under the flight (fresh rows,
        /// scroll catch-up), and the ticket must land where the slot
        /// truly ends up, not where it stood at take-off.
        var toKey: String?
        /// Landing tilt (album mounts rest a hair off true).
        var toRotation: Double = 0
        /// The room the flight moves through.
        var roomCenter = UnitPoint(x: 0.5, y: 0.26)
        var roomRadius: CGFloat = 0.85
        var roomWarmth: CGFloat = 0.55
    }

    private(set) var flight: Flight?
    /// Flight progress 0…1 with a breath of overshoot on open.
    private(set) var progress: Double = 0
    /// The room's presence: open pulls it up as the ticket rises; close
    /// and save let it go while the ticket travels.
    private(set) var roomOpacity: Double = 0

    /// Fired the frame the open flight seats — mount the stage now.
    @ObservationIgnored var onSeated: (() -> Void)?
    /// Fired when a close/save flight lands on the page.
    @ObservationIgnored var onLanded: (() -> Void)?

    // MARK: Spring internals

    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var lastTick: CFTimeInterval = 0
    @ObservationIgnored private var velocity: Double = 0
    @ObservationIgnored private var landingNotified = false
    @ObservationIgnored private var flightStart: CFTimeInterval = 0

    // MARK: Flights

    /// Page → stage. The room dims as the ticket rises into the lamp.
    func open(_ ticket: Ticket, fromSlot key: String, container: CGRect, safeTop: CGFloat) {
        guard flight == nil else { return }
        activeKey = key
        let from = home(for: key) ?? CGRect(
            x: container.midX - 60, y: container.midY - 40, width: 120, height: 80
        )
        let to = Self.heroFrame(for: ticket, container: container, safeTop: safeTop)
        start(Flight(kind: .open, ticket: ticket, from: from, to: to))
    }

    /// Stage → page. The lamp lets go; the ticket springs home.
    /// Falls back to a centre-fade when the slot has left the page.
    func close(_ ticket: Ticket, container: CGRect, safeTop: CGFloat) {
        guard flight == nil else { return }
        let from = Self.heroFrame(for: ticket, container: container, safeTop: safeTop)
        let to = home(for: activeKey) ?? CGRect(
            x: container.midX - 50, y: container.maxY - 180, width: 100, height: 66
        )
        start(Flight(
            kind: .close, ticket: ticket, from: from, to: to,
            toKey: activeKey,
            toRotation: activeKey.hasPrefix("a-") ? Self.albumRestingAngle(ticket) : 0
        ))
    }

    /// Desk → book. The saved ticket sails from the confirm stage down
    /// into its printed place while the capture room lets go.
    func save(_ ticket: Ticket, from: CGRect, toSlot key: String) {
        guard flight == nil else { return }
        let to = home(for: key) ?? CGRect(
            x: from.midX - 50, y: UIScreen.main.bounds.maxY - 200, width: 100, height: 66
        )
        start(Flight(
            kind: .save, ticket: ticket, from: from, to: to,
            toKey: key,
            roomCenter: UnitPoint(x: 0.5, y: 0.20), roomRadius: 0.80, roomWarmth: 0.50
        ))
    }

    private func start(_ f: Flight) {
        flight = f
        progress = 0
        velocity = 0
        landingNotified = false
        roomOpacity = f.kind == .open ? 0 : 1
        flightStart = CACurrentMediaTime()
        lastTick = flightStart
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    // MARK: The clock

    @objc private func tick() {
        guard let flight else { stop(); return }
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 1.0 / 30.0)
        lastTick = now

        // Chase the slot's live frame — the page may settle mid-flight.
        if let key = flight.toKey, let live = homes[key], live != flight.to {
            self.flight?.to = live
        }

        // One spring for the journey. Open gets a livelier arrival (a
        // breath of overshoot as the ticket seats under the lamp);
        // close/save land dead-beat — paper set down, not bounced.
        let stiffness: Double = flight.kind == .open ? 165 : 175
        let damping: Double = flight.kind == .open ? 21.5 : 26.5
        let accel = -stiffness * (progress - 1) - damping * velocity
        velocity += accel * dt
        progress += velocity * dt

        // The room breathes with the flight, clamped and eased.
        switch flight.kind {
        case .open:
            roomOpacity = Ease.outCubic(min(max(progress * 1.35, 0), 1))
        case .close, .save:
            roomOpacity = 1 - Ease.outCubic(min(max(progress * 1.18, 0), 1))
        }

        // Landing — settle detection with a hard ceiling so a starved
        // run loop can never strand a flight mid-air.
        let overdue = now - flightStart > 1.4
        if !landingNotified, overdue || (progress > 0.992 && abs(velocity) < 0.08) {
            landingNotified = true
            progress = 1
            roomOpacity = flight.kind == .open ? 1 : 0
            switch flight.kind {
            case .open:
                onSeated?()
                // Hold one beat under the stage's own identical pixels,
                // then hand over.
                Task {
                    try? await Task.sleep(for: .milliseconds(60))
                    self.finish()
                }
            case .close, .save:
                Haptic.play(.tick)
                onLanded?()
                self.finish()
            }
        }
    }

    private func finish() {
        stop()
        flight = nil
        progress = 0
        roomOpacity = 0
    }

    private func stop() {
        link?.invalidate()
        link = nil
    }

    // MARK: Geometry the flights print

    /// The ticket's rect for the current progress — pure function.
    var ticketRect: CGRect {
        guard let flight else { return .zero }
        let p = progress
        // Scale interpolates through the spring (may overshoot past 1 on
        // open — the seat breath); position eases with it.
        let x = flight.from.midX + (flight.to.midX - flight.from.midX) * p
        let y = flight.from.midY + (flight.to.midY - flight.from.midY) * p
        let w = flight.from.width + (flight.to.width - flight.from.width) * p
        let h = flight.from.height + (flight.to.height - flight.from.height) * p
        return CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)
    }

    var ticketRotation: Double {
        guard let flight else { return 0 }
        switch flight.kind {
        case .open:
            // Un-tilting from an album mount, plus a leaf of sway.
            let start = activeKey.hasPrefix("a-") ? Self.albumRestingAngle(flight.ticket) : 0
            return start * (1 - progress) + sin(progress * .pi) * -0.5
        case .close:
            return flight.toRotation * progress + sin(progress * .pi) * -0.6
        case .save:
            return sin(progress * .pi) * -1.2
        }
    }

    /// The peel — opening, the card lifts off the page top-edge-first,
    /// flattening as it seats; closing, it lays itself back down.
    var ticketPeel: Double {
        guard let flight else { return 0 }
        let p = min(max(progress, 0), 1)
        switch flight.kind {
        case .open:
            return (1 - Ease.outCubic(p)) * -7.0
        case .close, .save:
            return Ease.inCubic(p) * -5.0
        }
    }

    var ticketShadowOpacity: Double {
        guard let flight else { return 0 }
        let lifted: Double = 0.45, resting: Double = 0.16
        switch flight.kind {
        case .open: return resting + (lifted - resting) * progress
        case .close, .save: return lifted + (resting - lifted) * progress
        }
    }

    var ticketShadowRadius: CGFloat {
        guard flight != nil else { return 0 }
        let p = flight?.kind == .open ? progress : 1 - progress
        return 4 + 18 * p
    }

    /// Where the stage seats its hero — must mirror StagePage's layout
    /// (top padding 64, width 352/290, height from the object's aspect).
    static func heroFrame(for ticket: Ticket, container: CGRect, safeTop: CGFloat) -> CGRect {
        let store = aspectSource
        let width = min(ticket.kind.isEdmondson ? 290 : 352, container.width - 48)
        let aspect = store?(ticket) ?? TicketArtView.aspect(for: ticket.kind)
        let height = width / aspect
        return CGRect(
            x: container.midX - width / 2,
            y: safeTop + 64,
            width: width,
            height: height
        )
    }

    /// Injected once (TimelineView) so hero geometry can read the real
    /// photo/cutout aspect without the engine owning the store.
    @ObservationIgnored static var aspectSource: ((Ticket) -> CGFloat)?

    static func albumRestingAngle(_ ticket: Ticket) -> Double {
        var rng = SeededRandom(ticket.styleSeed ^ 0xA1B)
        return rng.double(in: -2.4...2.4)
    }
}

// MARK: - The overlay that prints the engine's values

/// Dumb by design: reads the engine's per-frame numbers and lays them
/// out. Every curve already happened inside the clock — there is not a
/// single SwiftUI animation in this view.
struct LiftOverlay: View {
    @Environment(TicketStore.self) private var store
    let engine: LiftEngine

    var body: some View {
        if let flight = engine.flight {
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                let rect = engine.ticketRect

                ZStack {
                    StudioBackdrop(
                        center: flight.roomCenter,
                        radius: flight.roomRadius,
                        warmth: flight.roomWarmth
                    )
                    .opacity(engine.roomOpacity)

                    TicketCardContent(
                        ticket: flight.ticket,
                        photo: store.photo(for: flight.ticket),
                        cutout: store.cutout(for: flight.ticket),
                        lying: false
                    )
                    // Bare card, like the seated hero it becomes: a
                    // colorEffect layer under `.shadow` leaves terraced
                    // halos in the dark room, and handover must be
                    // pixel-identical.
                    .frame(width: rect.width, height: rect.height)
                    .rotationEffect(.degrees(engine.ticketRotation))
                    .rotation3DEffect(
                        .degrees(engine.ticketPeel),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.45
                    )
                    .shadow(
                        color: .black.opacity(engine.ticketShadowOpacity),
                        radius: engine.ticketShadowRadius,
                        y: engine.ticketShadowRadius * 0.7
                    )
                    .position(x: rect.midX - origin.x, y: rect.midY - origin.y)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
