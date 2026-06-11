import SwiftUI

/// One ticket under the lamp: it settles as you arrive, tilts in your
/// hand (gloss answering), flips to the original photo, and casts a
/// faint reflection on the table. Facts ride on a torn stub below.
struct StagePage: View {
    @Environment(TicketStore.self) private var store
    let ticketID: UUID
    var dissolveProgress: Double = 0

    @State private var tilt: CGSize = .zero
    @State private var flipAngle: Double = 0
    @State private var settled = false
    @State private var memoDraft = ""
    @FocusState private var memoFocused: Bool

    var body: some View {
        if let ticket = store.tickets.first(where: { $0.id == ticketID }) {
            content(ticket)
        } else {
            Color.clear
        }
    }

    private func content(_ ticket: Ticket) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    // Table reflection — fades as the ticket lifts.
                    reflection(ticket)
                        .offset(y: reflectionOffset(ticket))
                    hero(ticket)
                }
                .padding(.top, 74)
                .padding(.bottom, 50)

                Text(ticket.routeText)
                    .font(Typo.mincho(25))
                    .tracking(2.5)
                    .foregroundStyle(Stage.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 9)

                if let date = ticket.travelDate {
                    Text(Editorial.shortDate(date))
                        .font(Typo.caption(10.5))
                        .tracking(3)
                        .foregroundStyle(Stage.faintText)
                }

                StubCard(ticket: ticket)
                    .frame(maxWidth: 318)
                    .padding(.horizontal, 30)
                    .padding(.top, 34)

                memoBlock(ticket)
                    .padding(.horizontal, 36)
                    .padding(.top, 30)

                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.hidden)
        .onAppear {
            memoDraft = ticket.memo
            guard !settled else { return }
            withAnimation(.spring(response: 0.65, dampingFraction: 0.72).delay(0.05)) {
                settled = true
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Hero

    private func heroCard(_ ticket: Ticket) -> some View {
        ZStack {
            TicketBackFace(ticket: ticket, photo: store.photo(for: ticket))
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipAngle >= 90 ? 1 : 0)
            TicketArtView(ticket: ticket)
                .visualEffect { [tilt] content, proxy in
                    content.colorEffect(
                        ShaderLibrary.holoSheen(
                            .float2(proxy.size),
                            .float2(Float(tilt.width), Float(tilt.height)),
                            .float(Float(min(1, hypot(tilt.width, tilt.height) * 1.8 + 0.12)))
                        )
                    )
                }
                .opacity(flipAngle < 90 ? 1 : 0)
        }
        .frame(maxWidth: ticket.kind.isEdmondson ? 290 : 352)
    }

    private func hero(_ ticket: Ticket) -> some View {
        heroCard(ticket)
            .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .scaleEffect(flipScale)
            .rotation3DEffect(.degrees(Double(-tilt.height) * 13), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(Double(tilt.width) * 15), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .shadow(
                color: .black.opacity(0.50),
                radius: 22 + hypot(tilt.width, tilt.height) * 12,
                x: -tilt.width * 16,
                y: 16 + tilt.height * 10
            )
            .inkDissolve(progress: dissolveProgress, seed: ticket.styleSeed)
            .rotationEffect(.degrees(settled ? 0 : settleAngle(ticket)))
            .scaleEffect(settled ? 1 : 0.965)
            .simultaneousGesture(tiltGesture)
            .onTapGesture { flip() }
            .padding(.horizontal, 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("切符 \(ticket.routeText)。タップで裏返す")
            .accessibilityIdentifier("stage-hero")
    }

    /// The flip dips slightly at its midpoint — cardstock has weight.
    private var flipScale: CGFloat {
        let mid = abs(sin(flipAngle * .pi / 180))
        return 1 - 0.035 * mid
    }

    private func settleAngle(_ ticket: Ticket) -> Double {
        var rng = SeededRandom(ticket.styleSeed ^ 0x5E77)
        return rng.double(in: 1.6...2.6) * (rng.unit() > 0.5 ? 1 : -1)
    }

    // MARK: Reflection

    private func reflection(_ ticket: Ticket) -> some View {
        let mag = min(1, hypot(tilt.width, tilt.height) * 1.4)
        return heroCard(ticket)
            .scaleEffect(x: 1, y: -1)
            .blur(radius: 3.5)
            .opacity(flipAngle < 90 ? (0.13 - 0.08 * mag) : 0.05)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.62),
                        .init(color: .clear, location: 0.97),
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            }
            .offset(x: -tilt.width * 6)
            .allowsHitTesting(false)
    }

    private func reflectionOffset(_ ticket: Ticket) -> CGFloat {
        let width: CGFloat = ticket.kind.isEdmondson ? 290 : 352
        let height = width / TicketArtView.aspect(for: ticket.kind)
        return height + 10
    }

    // MARK: Gestures

    private var tiltGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let w = (value.translation.width / 220).clamped(to: -1...1)
                let h = (value.translation.height / 220).clamped(to: -1...1)
                tilt = CGSize(width: w, height: h)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.55, dampingFraction: 0.42)) {
                    tilt = .zero
                }
            }
    }

    private func flip() {
        Haptic.play(.tick)
        withAnimation(.spring(response: 0.62, dampingFraction: 0.72)) {
            flipAngle = flipAngle == 0 ? 180 : 0
        }
    }

    // MARK: Memo

    private func memoBlock(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Ink.shu)
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(-3))
                Text("旅の記")
                    .font(Typo.gothic(10, bold: true))
                    .tracking(3)
                    .foregroundStyle(Stage.faintText)
            }

            TextField(
                "ひとこと残す…",
                text: $memoDraft,
                axis: .vertical
            )
            .font(Typo.gothic(13.5))
            .lineSpacing(8)
            .foregroundStyle(Stage.softText)
            .tint(Ink.shu)
            .focused($memoFocused)
            .lineLimit(2...8)
            .accessibilityIdentifier("memo-field")
            .onChange(of: memoFocused) { _, focused in
                if !focused { saveMemo(ticket) }
            }
            .submitLabel(.done)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toolbar {
            if memoFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        memoFocused = false
                    }
                    .font(Typo.gothic(13, bold: true))
                    .tint(Ink.shu)
                }
            }
        }
    }

    private func saveMemo(_ ticket: Ticket) {
        let trimmed = memoDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != ticket.memo else { return }
        var updated = ticket
        updated.memo = trimmed
        store.update(updated)
        Haptic.play(.tick)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
