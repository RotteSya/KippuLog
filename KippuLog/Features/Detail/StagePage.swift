import SwiftUI

/// One ticket on the stage: tilt it in your hand (holo foil answers),
/// tap to flip to the original photo, read the facts, write the memo.
struct StagePage: View {
    @Environment(TicketStore.self) private var store
    let ticketID: UUID
    var dissolveProgress: Double = 0

    @State private var tilt: CGSize = .zero
    @State private var flipAngle: Double = 0
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
                hero(ticket)
                    .padding(.top, 76)
                    .padding(.bottom, 44)

                Text(ticket.routeText)
                    .font(Typo.mincho(26))
                    .tracking(3)
                    .foregroundStyle(Stage.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)

                if let date = ticket.travelDate {
                    Text(Editorial.shortDate(date))
                        .font(Typo.caption(11))
                        .tracking(2.5)
                        .foregroundStyle(Stage.faintText)
                }

                factsGrid(ticket)
                    .padding(.horizontal, 32)
                    .padding(.top, 38)

                memoBlock(ticket)
                    .padding(.horizontal, 32)
                    .padding(.top, 30)

                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.hidden)
        .onAppear { memoDraft = ticket.memo }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Hero

    private func hero(_ ticket: Ticket) -> some View {
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
                            .float(Float(min(1, hypot(tilt.width, tilt.height) * 1.7)))
                        )
                    )
                }
                .opacity(flipAngle < 90 ? 1 : 0)
        }
        .frame(maxWidth: ticket.kind.isEdmondson ? 290 : 352)
        .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .rotation3DEffect(.degrees(Double(-tilt.height) * 13), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .rotation3DEffect(.degrees(Double(tilt.width) * 15), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .shadow(
            color: .black.opacity(0.55),
            radius: 22 + hypot(tilt.width, tilt.height) * 10,
            x: -tilt.width * 16,
            y: 16 + tilt.height * 10
        )
        .inkDissolve(progress: dissolveProgress, seed: ticket.styleSeed)
        .simultaneousGesture(tiltGesture)
        .onTapGesture { flip() }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("切符 \(ticket.routeText)。タップで裏返す")
        .accessibilityIdentifier("stage-hero")
    }

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

    // MARK: Facts

    private func factsGrid(_ ticket: Ticket) -> some View {
        VStack(spacing: 0) {
            factRow("種別", ticket.kind.label)
            factRow("会社", ticket.brand.displayName)
            if let train = ticket.trainName { factRow("列車", train) }
            if let seat = ticket.seat { factRow("座席", seat) }
            if let price = ticket.price { factRow("運賃", Editorial.yen(price)) }
        }
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(Typo.gothic(11))
                    .tracking(2)
                    .foregroundStyle(Stage.faintText)
                Spacer()
                Text(value)
                    .font(Typo.gothic(13))
                    .foregroundStyle(Stage.softText)
            }
            .padding(.vertical, 13)
            Rectangle()
                .fill(Stage.rule)
                .frame(height: 1)
        }
    }

    // MARK: Memo

    private func memoBlock(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("この旅のこと")
                .font(Typo.gothic(11))
                .tracking(2)
                .foregroundStyle(Stage.faintText)

            TextField(
                "ひとこと残す…",
                text: $memoDraft,
                axis: .vertical
            )
            .font(Typo.gothic(13.5))
            .lineSpacing(7)
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
