import SwiftUI

/// The 改札 ceremony. The captured ticket rises from the hand, leans back
/// and feeds upward through the reader head — squish, *kachunk*, punch,
/// a chad of paper flutters out — then the reading light sweeps it while
/// OCR works, and the ticket glides to the exact spot where the confirm
/// desk will pick it up. Pure theatre, precisely timed.
struct GatePassView: View {
    let scan: UIImage
    /// Punch geometry must match the final plate, so the hole the gate
    /// bites here is the hole the ticket keeps forever.
    let styleSeed: UInt64
    /// Fired when choreography completes (OCR may still be running).
    var onFinished: () -> Void

    // Choreography state
    @State private var ticketOffset: CGFloat = 0.62   // ×height — starts in the hand, below the frame
    @State private var lean: Double = -16
    @State private var scale: CGFloat = 0.965
    @State private var squish: Double = 0
    @State private var punched = false
    @State private var chad = false
    @State private var headBite = false
    @State private var scanProgress: Double = -0.2
    @State private var showCaption = false
    @State private var slotFlash = false

    /// The scan's own proportions — never force MARS onto an Edmondson,
    /// and never crop a long 私鉄 ticket's ends. Soft-clamped only against
    /// pathological mis-scans.
    private var aspect: CGFloat {
        let raw = scan.size.height > 0 ? scan.size.width / scan.size.height : MarsTicketFace.aspect
        return min(max(raw, 1.10), 3.20)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let ticketWidth = size.width * 0.64

            ZStack {
                // Ticket travelling through.
                ticketBody(width: ticketWidth)
                    .scaleEffect(scale)
                    .rotation3DEffect(.degrees(lean), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .offset(y: ticketOffset * size.height)
                    .zIndex(1)

                // The reader head.
                readerHead(width: size.width)
                    .offset(y: headBite ? 2 : 0)
                    .zIndex(2)

                // The punched-out chad, fluttering from the slot.
                if chad {
                    PunchChad(
                        diameter: ticketWidth * 0.048,
                        startX: chadX(ticketWidth: ticketWidth)
                    )
                    .zIndex(3)
                }

                // Caption under everything.
                VStack {
                    Spacer()
                    Text(showCaption ? "読み取り中…" : " ")
                        .font(Typo.gothic(11.5))
                        .tracking(2.5)
                        .foregroundStyle(Stage.faintText)
                        .opacity(showCaption ? 1 : 0)
                        .padding(.bottom, size.height * 0.15)
                }
                .animation(.easeInOut(duration: 0.3), value: showCaption)
                .zIndex(4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task { await choreograph(size: size, ticketWidth: ticketWidth) }
        }
    }

    // MARK: Ticket

    private func ticketBody(width: CGFloat) -> some View {
        let punch = PunchGeometry(seed: styleSeed, kind: .joshaken)
        return Image(uiImage: scan)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: width / aspect)
            .clipShape(
                PunchedTicketShape(
                    corner: 6,
                    holeUnit: punched ? punch.hole : nil,
                    holeRadiusUnit: 0.026,
                    notchUnitX: nil
                ),
                style: FillStyle(eoFill: true)
            )
            .visualEffect { [squish] content, geo in
                content.distortionEffect(
                    ShaderLibrary.gateSquish(
                        .float2(geo.size),
                        .float(Float(squish))
                    ),
                    maxSampleOffset: CGSize(width: 40, height: 40)
                )
            }
            .visualEffect { [scanProgress] content, geo in
                content.colorEffect(
                    ShaderLibrary.scanSweep(
                        .float2(geo.size),
                        .float(Float(scanProgress))
                    )
                )
            }
            // Matches the confirm reveal's shadow exactly — the handoff
            // must not re-light the object.
            .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
    }

    private func chadX(ticketWidth: CGFloat) -> CGFloat {
        let punch = PunchGeometry(seed: styleSeed, kind: .joshaken)
        return ((punch.hole?.x ?? 0.5) - 0.5) * ticketWidth
    }

    // MARK: Reader head

    private func readerHead(width: CGFloat) -> some View {
        ZStack {
            // Body — a machined block catching the lamp on its top face.
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: 0x221C15))
                .overlay {
                    // Top-face light, a real object's shading.
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.085), location: 0),
                                    .init(color: .clear, location: 0.45),
                                    .init(color: .black.opacity(0.18), location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    // Machined bevel: bright top hairline, dark bottom seat.
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.14), .black.opacity(0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .frame(width: width * 0.94, height: 86)
                .shadow(color: .black.opacity(0.45), radius: 22, y: 14)

            // The slot — an actual recess.
            Capsule()
                .fill(Color.black.opacity(0.92))
                .frame(width: width * 0.74, height: 9)
                .overlay {
                    Capsule()
                        .strokeBorder(Color.black.opacity(0.8), lineWidth: 1)
                        .blur(radius: 0.6)
                        .offset(y: -0.6)
                        .mask(Capsule())
                }
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .offset(y: 1.6)
                }
                .overlay {
                    Capsule()
                        .stroke(slotFlash ? Ink.shu : .clear, lineWidth: 1.2)
                        .shadow(color: slotFlash ? Ink.shu.opacity(0.9) : .clear, radius: 8)
                }

            // Feed-direction chevrons, marching.
            MarchingChevrons()
                .offset(x: -width * 0.33, y: -24)

            // Status lamp.
            Circle()
                .fill(slotFlash ? Ink.shu : Color(hex: 0x3A352D))
                .frame(width: 6.5, height: 6.5)
                .shadow(color: slotFlash ? Ink.shu.opacity(0.9) : .clear, radius: 5)
                .offset(x: width * 0.385, y: -24)
        }
        .animation(.easeOut(duration: 0.16), value: slotFlash)
    }

    // MARK: Choreography

    private func choreograph(size: CGSize, ticketWidth: CGFloat) async {
        // 1 — rise from the hand to just below the slot, leaning in.
        withAnimation(.spring(response: 0.62, dampingFraction: 0.78)) {
            ticketOffset = 0.155
            lean = -7
            scale = 1
        }
        try? await Task.sleep(for: .milliseconds(660))
        guard !Task.isCancelled else { return }

        // 2 — feed through the slot.
        withAnimation(.easeIn(duration: 0.52)) {
            ticketOffset = -0.20
            lean = 0
            squish = 1
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        // 3 — the bite. The head flinches, the chad flutters out.
        Haptic.play(.punch)
        slotFlash = true
        punched = true
        chad = true
        withAnimation(.spring(response: 0.16, dampingFraction: 0.55)) {
            headBite = true
        }
        try? await Task.sleep(for: .milliseconds(90))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            headBite = false
        }
        try? await Task.sleep(for: .milliseconds(150))
        slotFlash = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            squish = 0
        }
        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }

        // 4 — reading light.
        showCaption = true
        withAnimation(.easeInOut(duration: 0.85)) {
            scanProgress = 1.2
        }
        try? await Task.sleep(for: .milliseconds(950))
        guard !Task.isCancelled else { return }

        // 5 — hand the ticket to the desk: glide to the exact spot the
        // confirm reveal occupies, so the crossfade is a handoff, not a
        // jump.
        showCaption = false
        let park = parkTarget(size: size, ticketWidth: ticketWidth)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
            ticketOffset = park.offsetUnit
            scale = park.scale
        }
        // Let the spring settle completely — the confirm arrives under
        // these exact pixels, so the glide must be *finished*.
        try? await Task.sleep(for: .milliseconds(580))
        guard !Task.isCancelled else { return }

        onFinished()
    }

    /// Where ConfirmTicketView's reveal will show this very scan —
    /// `ConfirmStage` is the single source of that geometry.
    private func parkTarget(size: CGSize, ticketWidth: CGFloat) -> (offsetUnit: CGFloat, scale: CGFloat) {
        let targetCenterY = ConfirmStage.centerY(aspect: aspect, in: size)
        let targetWidth = ConfirmStage.fitted(aspect: aspect, in: size).width
        return (
            offsetUnit: (targetCenterY - size.height / 2) / size.height,
            scale: targetWidth / ticketWidth
        )
    }
}

/// The punched-out circle of ticket stock: it drops from the slot,
/// tumbling and swaying like the weightless paper it is, and is gone.
private struct PunchChad: View {
    let diameter: CGFloat
    let startX: CGFloat

    private struct Fall {
        var y: CGFloat = 6
        var x: CGFloat = 0
        var tumble: CGFloat = 1     // scaleY — the disc seen edge-on as it turns
        var spin: Double = 0
        var opacity: Double = 1
    }

    @State private var dropped = false

    var body: some View {
        KeyframeAnimator(initialValue: Fall(), trigger: dropped) { fall in
            Ellipse()
                .fill(Color(hex: 0xEFE7D6))
                .frame(width: diameter, height: diameter)
                .scaleEffect(y: max(fall.tumble, 0.08))
                .rotationEffect(.degrees(fall.spin))
                .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
                .offset(x: startX + fall.x, y: fall.y)
                .opacity(fall.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.y) {
                CubicKeyframe(26, duration: 0.16)
                CubicKeyframe(74, duration: 0.26)
                CubicKeyframe(168, duration: 0.34)
            }
            KeyframeTrack(\.x) {
                CubicKeyframe(5, duration: 0.20)
                CubicKeyframe(-4, duration: 0.26)
                CubicKeyframe(7, duration: 0.30)
            }
            KeyframeTrack(\.tumble) {
                CubicKeyframe(0.18, duration: 0.14)
                CubicKeyframe(0.85, duration: 0.18)
                CubicKeyframe(0.12, duration: 0.20)
                CubicKeyframe(0.65, duration: 0.24)
            }
            KeyframeTrack(\.spin) {
                LinearKeyframe(38, duration: 0.76)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(1, duration: 0.50)
                LinearKeyframe(0, duration: 0.26)
            }
        }
        .onAppear { dropped = true }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Three chevrons pointing along the feed, lighting in sequence.
private struct MarchingChevrons: View {
    @State private var marching = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                ChevronUp()
                    .stroke(Ink.shu, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 9, height: 5.5)
                    .opacity(marching ? 1 : 0.18)
                    .animation(
                        .easeInOut(duration: 0.42)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.16),
                        value: marching
                    )
            }
        }
        .onAppear { marching = true }
        .accessibilityHidden(true)
    }
}

private nonisolated struct ChevronUp: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

#Preview {
    GatePassView(
        scan: UIImage(systemName: "ticket")!,
        styleSeed: 42,
        onFinished: {}
    )
}
