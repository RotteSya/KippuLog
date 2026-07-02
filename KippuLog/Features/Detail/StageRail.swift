import SwiftUI
import UIKit

/// The shelf rail — how the stage leafs through the collection.
///
/// The system pager snaps page-to-page with a hard notch and no life in
/// the cards. This rail is the camera instead: one continuous position
/// on a shelf axis, driven by a CADisplayLink spring. Your finger owns
/// the rail directly; cards lean into the pull like paper with mass,
/// neighbours recede a step out of the lamp, the notch is a haptic, and
/// every motion is interruptible mid-flight — grab it and it's yours,
/// no phase, no cut.
///
/// SwiftUI supplies each page's furniture (`StagePage`); the rail owns
/// every moving part.
struct StageRail: UIViewRepresentable {
    @Environment(TicketStore.self) private var store
    let tickets: [Ticket]
    @Binding var pageID: UUID
    var shredProgress: Double
    var departing: Bool

    func makeUIView(context: Context) -> StageRailView {
        let view = StageRailView()
        view.onSettle = { id in
            if pageID != id { pageID = id }
        }
        view.hostProvider = { [store] ticket, shred, leaving in
            AnyView(
                StagePage(
                    ticketID: ticket.id,
                    shredProgress: shred,
                    departing: leaving
                )
                .environment(store)
            )
        }
        view.reload(tickets: tickets, current: pageID)
        return view
    }

    func updateUIView(_ view: StageRailView, context: Context) {
        view.update(
            tickets: tickets,
            current: pageID,
            shredProgress: shredProgress,
            departing: departing
        )
    }
}

/// The engine. One `position` (a continuous index along the shelf) is
/// the whole truth; layout is a pure function of it, evaluated per frame.
@MainActor
final class StageRailView: UIView, UIGestureRecognizerDelegate {

    // MARK: Wiring

    var onSettle: ((UUID) -> Void)?
    var hostProvider: ((Ticket, Double, Bool) -> AnyView)?

    // MARK: Shelf state

    private var tickets: [Ticket] = []
    private var shredProgress: Double = 0
    private var departing = false

    /// The camera's place on the shelf, in card units. 2.35 = between
    /// card 2 and 3, a third of the way across.
    private var position: CGFloat = 0
    /// Spring target and velocity (card units, units/second).
    private var target: CGFloat = 0
    private var velocity: CGFloat = 0
    /// The finger's anchor while dragging.
    private var dragAnchor: CGFloat = 0
    private var dragging = false
    /// The last index a notch haptic fired for.
    private var notchIndex = 0

    private var link: CADisplayLink?
    private var lastTick: CFTimeInterval = 0

    // MARK: Hosts (three seats, rebound as the shelf slides)

    private struct Seat {
        let controller: UIHostingController<AnyView>
        var index: Int = .min
    }

    private var seats: [Seat] = []

    // MARK: Setup

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            link?.invalidate()
            link = nil
        } else if link == nil {
            startClock()
        }
    }

    // MARK: Rebinding from SwiftUI

    func reload(tickets: [Ticket], current: UUID) {
        self.tickets = tickets
        position = CGFloat(tickets.firstIndex(where: { $0.id == current }) ?? 0)
        target = position
        notchIndex = Int(position.rounded())
        setNeedsLayout()
    }

    func update(tickets: [Ticket], current: UUID, shredProgress: Double, departing: Bool) {
        let ticketsChanged = tickets.map(\.id) != self.tickets.map(\.id)
        self.shredProgress = shredProgress
        self.departing = departing
        if ticketsChanged {
            // A ticket left the shelf (delete) — keep the camera sane.
            self.tickets = tickets
            for i in seats.indices { seats[i].index = .min }
            let idx = CGFloat(tickets.firstIndex(where: { $0.id == current }) ?? 0)
            position = min(position, CGFloat(max(tickets.count - 1, 0)))
            target = idx
        } else if !dragging,
                  let want = tickets.firstIndex(where: { $0.id == current }),
                  want != Int(target.rounded()) {
            // External page change (accessibility, tests) — glide there.
            target = CGFloat(want)
        }
        // Shred/departure changes re-render the current seat's content.
        rebindSeats(force: true)
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        if seats.isEmpty, hostProvider != nil {
            for _ in 0..<3 {
                let host = UIHostingController(rootView: AnyView(EmptyView()))
                host.view.backgroundColor = .clear
                addSubview(host.view)
                seats.append(Seat(controller: host))
            }
        }
        rebindSeats(force: false)
        place()
    }

    /// Give the three seats the right tickets for wherever the camera is.
    private func rebindSeats(force: Bool) {
        guard !seats.isEmpty, !tickets.isEmpty, let hostProvider else { return }
        let center = Int(position.rounded())
        for offset in -1...1 {
            let index = center + offset
            let seatSlot = ((index % 3) + 3) % 3
            guard tickets.indices.contains(index) else {
                if seats[seatSlot].index != .min, !tickets.indices.contains(seats[seatSlot].index) {
                    seats[seatSlot].controller.rootView = AnyView(EmptyView())
                    seats[seatSlot].index = .min
                }
                continue
            }
            if force || seats[seatSlot].index != index {
                let ticket = tickets[index]
                let isCurrent = index == Int(position.rounded())
                seats[seatSlot].controller.rootView = hostProvider(
                    ticket,
                    isCurrent ? shredProgress : 0,
                    departing
                )
                seats[seatSlot].index = index
            }
        }
    }

    /// Pure function of `position`: each seat's transform on the shelf.
    private func place() {
        let width = bounds.width
        guard width > 0 else { return }
        for seat in seats {
            guard seat.index != .min else {
                seat.controller.view.isHidden = true
                continue
            }
            let progress = CGFloat(seat.index) - position   // −: left of camera
            seat.controller.view.isHidden = abs(progress) > 1.2
            guard !seat.controller.view.isHidden else { continue }

            seat.controller.view.frame = bounds

            // The shelf: neighbours sit one pace along, a step back from
            // the lamp, leaning slightly away — paper on a rail, not
            // screens on a conveyor.
            var transform = CATransform3DIdentity
            transform.m34 = -1 / 1400
            transform = CATransform3DTranslate(transform, progress * width * 0.92, 0, 0)
            let recede = min(abs(progress), 1)
            transform = CATransform3DScale(transform, 1 - recede * 0.075, 1 - recede * 0.075, 1)
            transform = CATransform3DRotate(transform, -progress * 0.10, 0, 1, 0)
            seat.controller.view.layer.transform = transform

            // A step out of the pool of light.
            seat.controller.view.alpha = 1 - recede * 0.45
        }
    }

    // MARK: Clock

    private func startClock() {
        lastTick = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 1.0 / 30.0)
        lastTick = now
        guard !dragging else { return }

        // Critically-damped-ish spring toward the target notch.
        let stiffness: CGFloat = 190
        let damping: CGFloat = 24
        let displacement = position - target
        let accel = -stiffness * displacement - damping * velocity
        velocity += accel * CGFloat(dt)
        position += velocity * CGFloat(dt)

        if abs(displacement) < 0.0006, abs(velocity) < 0.004 {
            position = target
            velocity = 0
        }

        crossNotchIfNeeded()
        rebindSeats(force: false)
        place()
    }

    /// The notch: the moment a card takes the lamp.
    private func crossNotchIfNeeded() {
        let nearest = Int(position.rounded())
        guard tickets.indices.contains(nearest), nearest != notchIndex else { return }
        notchIndex = nearest
        Haptic.play(.page)
        onSettle?(tickets[nearest].id)
    }

    // MARK: The finger owns the rail

    @objc private func onPan(_ pan: UIPanGestureRecognizer) {
        let width = max(bounds.width, 1)
        switch pan.state {
        case .began:
            // Interrupt whatever the spring was doing — it's yours now.
            dragging = true
            dragAnchor = position
        case .changed:
            let dx = pan.translation(in: self).x
            var next = dragAnchor - dx / (width * 0.92)
            // Rubber-band past the shelf's ends.
            let maxIndex = CGFloat(max(tickets.count - 1, 0))
            if next < 0 { next = next / 3 }
            if next > maxIndex { next = maxIndex + (next - maxIndex) / 3 }
            position = next
            crossNotchIfNeeded()
            rebindSeats(force: false)
            place()
        case .ended, .cancelled, .failed:
            dragging = false
            let vx = -pan.velocity(in: self).x / (width * 0.92)
            velocity = vx
            // Flick decides the notch; otherwise the nearest one.
            let projected = position + vx * 0.22
            let maxIndex = CGFloat(max(tickets.count - 1, 0))
            target = min(max(projected.rounded(), 0), maxIndex)
        default:
            break
        }
    }

    /// Horizontal pulls take the rail; vertical stays with the page's own
    /// scroll. Steep diagonals go to whoever is steeper.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let v = pan.velocity(in: self)
        return abs(v.x) > abs(v.y) * 1.15
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        // The hero's tilt drag lives inside the page — both may listen,
        // exactly as the system pager allowed.
        true
    }
}
