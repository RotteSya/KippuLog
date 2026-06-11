import SwiftUI

/// The 改札 ceremony. The captured ticket feeds upward through a glass
/// gate slot — squish, *kachunk*, punch hole — then the reading light
/// sweeps it while OCR works. Pure theatre, precisely timed.
struct GatePassView: View {
    let scan: UIImage
    /// Punch geometry must match the final plate, so the hole the gate
    /// bites here is the hole the ticket keeps forever.
    let styleSeed: UInt64
    /// Fired when choreography completes (OCR may still be running).
    var onFinished: () -> Void

    // Choreography state
    @State private var ticketOffset: CGFloat = 0.46   // ×height
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
                // Ticket travelling through.
                ticketBody(width: ticketWidth)
                    .offset(y: ticketOffset * size.height)
                    .zIndex(1)

                // The gate slab.
                gateSlab(width: size.width)
                    .zIndex(2)

                // Caption under everything.
                VStack {
                    Spacer()
                    Text(showCaption ? "読み取り中…" : " ")
                        .font(Typo.gothic(12))
                        .tracking(2)
                        .foregroundStyle(Stage.faintText)
                        .opacity(showCaption ? 1 : 0)
                        .padding(.bottom, size.height * 0.16)
                }
                .zIndex(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await choreograph() }
    }

    // MARK: Pieces

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

    private func gateSlab(width: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(.clear)
                .frame(width: width * 0.94, height: 84)
                .glassEffect(
                    .regular.tint(Color(hex: 0x191512).opacity(0.82)),
                    in: .rect(cornerRadius: 22)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.16), .white.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .frame(width: width * 0.94, height: 84)
                }

            // The slot.
            Capsule()
                .fill(Color.black.opacity(0.85))
                .frame(width: width * 0.76, height: 7)
                .overlay {
                    Capsule()
                        .stroke(slotFlash ? Ink.shu : Color.white.opacity(0.1), lineWidth: 1.2)
                        .shadow(color: slotFlash ? Ink.shu.opacity(0.9) : .clear, radius: 7)
                }

            // Gate light.
            Circle()
                .fill(slotFlash ? Ink.shu : Color(hex: 0x3A352D))
                .frame(width: 7, height: 7)
                .shadow(color: slotFlash ? Ink.shu.opacity(0.9) : .clear, radius: 5)
                .offset(x: width * 0.40)
        }
        .animation(.easeOut(duration: 0.16), value: slotFlash)
    }

    // MARK: Choreography

    private func choreograph() async {
        // 1 — rise from the hand to just below the slot.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.74)) {
            ticketOffset = 0.155
        }
        try? await Task.sleep(for: .milliseconds(620))

        // 2 — feed through the slot.
        withAnimation(.easeIn(duration: 0.52)) {
            ticketOffset = -0.20
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

#Preview {
    ZStack {
        Ink.studio.ignoresSafeArea()
        GatePassView(
            scan: UIImage(systemName: "ticket")!,
            styleSeed: 42,
            onFinished: {}
        )
    }
}
