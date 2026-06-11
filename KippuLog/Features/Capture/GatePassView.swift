import SwiftUI

/// The 改札 ceremony. The captured ticket leans back and feeds upward
/// through the reader head — squish, *kachunk*, punch — then the
/// reading light sweeps it while OCR works. Pure theatre, precisely
/// timed.
struct GatePassView: View {
    let scan: UIImage
    /// Punch geometry must match the final plate, so the hole the gate
    /// bites here is the hole the ticket keeps forever.
    let styleSeed: UInt64
    /// Fired when choreography completes (OCR may still be running).
    var onFinished: () -> Void

    // Choreography state
    @State private var ticketOffset: CGFloat = 0.46   // ×height
    @State private var lean: Double = 0
    @State private var squish: Double = 0
    @State private var punched = false
    @State private var scanProgress: Double = -0.2
    @State private var showCaption = false
    @State private var slotFlash = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let ticketWidth = size.width * 0.64

            ZStack {
                StudioBackdrop(center: UnitPoint(x: 0.5, y: 0.5), radius: 0.95, warmth: 0.4)

                // Ticket travelling through.
                ticketBody(width: ticketWidth)
                    .rotation3DEffect(.degrees(lean), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .offset(y: ticketOffset * size.height)
                    .zIndex(1)

                // The reader head.
                readerHead(width: size.width)
                    .zIndex(2)

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
                .zIndex(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await choreograph() }
    }

    // MARK: Ticket

    private func ticketBody(width: CGFloat) -> some View {
        let punch = PunchGeometry(seed: styleSeed, kind: .joshaken)
        return Image(uiImage: scan)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: width / MarsTicketFace.aspect)
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
            .shadow(color: .black.opacity(0.5), radius: 18, y: 12)
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

    private func choreograph() async {
        // 1 — rise from the hand to just below the slot, leaning in.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.74)) {
            ticketOffset = 0.155
            lean = -7
        }
        try? await Task.sleep(for: .milliseconds(620))

        // 2 — feed through the slot.
        withAnimation(.easeIn(duration: 0.52)) {
            ticketOffset = -0.20
            lean = 0
            squish = 1
        }
        try? await Task.sleep(for: .milliseconds(300))

        // 3 — the bite.
        Haptic.play(.punch)
        slotFlash = true
        punched = true
        try? await Task.sleep(for: .milliseconds(240))
        slotFlash = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            squish = 0
        }
        try? await Task.sleep(for: .milliseconds(260))

        // 4 — reading light.
        showCaption = true
        withAnimation(.easeInOut(duration: 0.85)) {
            scanProgress = 1.2
        }
        try? await Task.sleep(for: .milliseconds(950))

        onFinished()
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
