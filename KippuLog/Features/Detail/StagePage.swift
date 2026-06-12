import SwiftUI

/// One ticket under the lamp: the real photographed ticket settles as you
/// arrive, tilts in your hand (gloss answering), and casts a faint
/// reflection on the table. Facts ride on a torn stub below.
struct StagePage: View {
    @Environment(TicketStore.self) private var store
    let ticketID: UUID
    var shredProgress: Double = 0

    @State private var tilt: CGSize = .zero
    @State private var settled = false
    @State private var showInspector = false
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

                Group {
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
                }
                // The page clears its throat while the gate takes the ticket.
                .opacity(1 - min(1, shredProgress * 2.6))

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
        .fullScreenCover(isPresented: $showInspector) {
            if let photo = store.photo(for: ticket) {
                PhotoInspector(photo: photo)
            }
        }
    }

    // MARK: Hero

    private func heroWidth(_ ticket: Ticket) -> CGFloat {
        ticket.kind.isEdmondson ? 290 : 352
    }

    private func heroCard(_ ticket: Ticket) -> some View {
        TicketCardContent(
            ticket: ticket,
            photo: store.photo(for: ticket),
            cutout: store.cutout(for: ticket),
            lying: false
        )
        .frame(maxWidth: heroWidth(ticket))
        .visualEffect { [tilt] content, proxy in
            content.colorEffect(
                ShaderLibrary.holoSheen(
                    .float2(proxy.size),
                    .float2(Float(tilt.width), Float(tilt.height)),
                    .float(Float(min(1, hypot(tilt.width, tilt.height) * 1.8 + 0.12)))
                )
            )
        }
    }

    private func hero(_ ticket: Ticket) -> some View {
        heroCard(ticket)
            .rotation3DEffect(.degrees(Double(-tilt.height) * 13), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(Double(tilt.width) * 15), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .shadow(
                color: .black.opacity(0.50),
                radius: 22 + hypot(tilt.width, tilt.height) * 12,
                x: -tilt.width * 16,
                y: 16 + tilt.height * 10
            )
            .shredFall(progress: shredProgress, seed: ticket.styleSeed)
            .scaleEffect(settled ? 1 : 0.955)
            .opacity(settled ? 1 : 0)
            .simultaneousGesture(tiltGesture)
            .onTapGesture {
                guard store.photo(for: ticket) != nil else { return }
                Haptic.play(.tick)
                showInspector = true
            }
            .padding(.horizontal, 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("切符 \(ticket.routeText)。タップで原寸表示")
            .accessibilityIdentifier("stage-hero")
    }

    // MARK: Reflection

    private func reflection(_ ticket: Ticket) -> some View {
        let mag = min(1, hypot(tilt.width, tilt.height) * 1.4)
        return heroCard(ticket)
            .scaleEffect(x: 1, y: -1)
            .blur(radius: 3.5)
            .opacity(settled ? (0.13 - 0.08 * mag) * (1 - min(1, shredProgress * 2.6)) : 0)
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
        let width = heroWidth(ticket)
        let aspect: CGFloat
        if let cutout = store.cutout(for: ticket), cutout.size.height > 0 {
            aspect = cutout.size.width / cutout.size.height
        } else if store.photo(for: ticket) != nil, let raw = ticket.photoAspect {
            aspect = CardMetrics.clampedPhotoAspect(raw)
        } else {
            aspect = TicketArtView.aspect(for: ticket.kind)
        }
        return width / aspect + 10
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
