import SwiftUI

/// Dev/screenshot stand-in for the live camera (`-uiScreen viewfinder`):
/// a synthetic desk scene under the real viewfinder chrome. Each tap
/// advances an act — seek → lock-on → hold — so UI tests can anchor
/// screenshots to state instead of wall-clock time (there is no camera
/// in the simulator, and launch quiescing skews timers).
struct ViewfinderRehearsalView: View {
    @State private var act = 0
    @State private var quad: [CGPoint]?
    @State private var steadySince: Date?

    private let bufferAspect: CGFloat = 3.0 / 4.0

    /// Where the rehearsal ticket lies, in normalized buffer coords —
    /// slightly skewed, the way a real ticket sits under a hand-held
    /// phone. Chosen to land well inside the screen after aspect-fill.
    private let ticketQuad: [CGPoint] = [
        CGPoint(x: 0.300, y: 0.318),   // topLeft
        CGPoint(x: 0.706, y: 0.328),   // topRight
        CGPoint(x: 0.698, y: 0.512),   // bottomRight
        CGPoint(x: 0.292, y: 0.498),   // bottomLeft
    ]

    var body: some View {
        ZStack {
            RehearsalScene(ticketQuad: ticketQuad, bufferAspect: bufferAspect)
                .ignoresSafeArea()

            StudioVignette()

            CaptureViewfinder(
                quad: quad,
                bufferAspect: bufferAspect,
                steadySince: steadySince,
                frozen: false
            )
            .ignoresSafeArea()

            VStack {
                Text(quad != nil ? "そのまま…" : "切符を枠のなかへ")
                    .font(Typo.gothic(12, bold: true))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: quad != nil)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.top, 64)
                Spacer()
                rehearsalControls
                    .padding(.bottom, 30)
            }
        }
        .statusBarHidden(true)
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .accessibilityIdentifier("viewfinder-rehearsal")
    }

    private func advance() {
        act += 1
        switch act {
        case 1: quad = ticketQuad
        case 2: steadySince = .now
        default:
            act = 0
            quad = nil
            steadySince = nil
        }
    }

    /// Static copy of the capture controls, for framing only.
    private var rehearsalControls: some View {
        HStack {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 48, height: 48)
                .glassEffect(.regular, in: .circle)

            Spacer()

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.95), lineWidth: 4)
                    .frame(width: 74, height: 74)
                SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: steadySince == nil)) { timeline in
                    Circle()
                        .trim(from: 0, to: CaptureHold.progress(at: timeline.date, since: steadySince))
                        .stroke(Ink.shu, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 74, height: 74)
                Circle()
                    .fill(Ink.shu)
                    .frame(width: 58, height: 58)
            }

            Spacer()

            Color.clear.frame(width: 48, height: 48)
        }
        .padding(.horizontal, 36)
    }
}

/// A believable "phone over a dark desk" frame: walnut ground, a cream
/// ticket with faint print where the rehearsal quad says it lies.
private struct RehearsalScene: View {
    let ticketQuad: [CGPoint]
    let bufferAspect: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let corners = ticketQuad.map {
                CaptureViewfinder.mapToLayer($0, bufferAspect: bufferAspect, in: size)
            }
            Canvas { context, _ in
                // Desk.
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0x2A231C), Color(hex: 0x1C1712)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
                guard corners.count == 4 else { return }
                var ticket = Path()
                ticket.move(to: corners[0])
                for p in corners.dropFirst() { ticket.addLine(to: p) }
                ticket.closeSubpath()

                // Soft contact shadow, then stock.
                var shadow = context
                shadow.translateBy(x: 4, y: 10)
                shadow.addFilter(.blur(radius: 12))
                shadow.fill(ticket, with: .color(.black.opacity(0.55)))
                context.fill(ticket, with: .color(Color(hex: 0xF2ECDD)))

                // Print, in ticket-local coordinates (u across, v down):
                // title, the big route line, two detail rows, the fare.
                let origin = corners[0]
                let across = CGPoint(x: corners[1].x - origin.x, y: corners[1].y - origin.y)
                let down = CGPoint(x: corners[3].x - origin.x, y: corners[3].y - origin.y)
                func at(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
                    CGPoint(
                        x: origin.x + across.x * u + down.x * v,
                        y: origin.y + across.y * u + down.y * v
                    )
                }
                let ink = Color(hex: 0x26211B)
                let rows: [(u0: CGFloat, u1: CGFloat, v: CGFloat, w: CGFloat, alpha: CGFloat)] = [
                    (0.26, 0.74, 0.14, 0.022, 0.62),   // title
                    (0.16, 0.84, 0.36, 0.058, 0.86),   // route
                    (0.24, 0.76, 0.55, 0.026, 0.60),   // date/train
                    (0.30, 0.70, 0.67, 0.026, 0.55),   // seat
                    (0.32, 0.68, 0.84, 0.040, 0.78),   // fare
                ]
                let unit = hypot(down.x, down.y)
                for row in rows {
                    var line = Path()
                    line.move(to: at(row.u0, row.v))
                    line.addLine(to: at(row.u1, row.v))
                    context.stroke(
                        line,
                        with: .color(ink.opacity(row.alpha)),
                        style: StrokeStyle(lineWidth: max(1.5, unit * row.w), lineCap: .round)
                    )
                }
            }
        }
    }
}

#Preview {
    ViewfinderRehearsalView()
}
