import SwiftUI

/// One ticket under the lamp: the real photographed ticket sits lit and
/// still, its paper stock and cut edges catching the studio light — the
/// lift's flights carry the motion, the exhibit itself is calm. Facts
/// ride on a torn stub below.
struct StagePage: View {
    @Environment(TicketStore.self) private var store
    let ticketID: UUID
    var shredProgress: Double = 0
    /// Departure: facts dissolve while the ticket holds the light.
    var departing = false

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
                    .padding(.top, 64)
                    .padding(.bottom, 52)

                Group {
                    Text(ticket.routeText)
                        .font(Typo.mincho(25))
                        .tracking(2.5)
                        .foregroundStyle(Stage.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 10)

                    if let date = ticket.travelDate {
                        Text(Editorial.shortDate(date))
                            .font(Typo.caption(10.5))
                            .tracking(3)
                            .foregroundStyle(Stage.faintText)
                    }

                    StubCard(ticket: ticket)
                        .frame(maxWidth: 318)
                        .padding(.horizontal, 30)
                        .padding(.top, 38)

                    // The note shares the stub's column — one margin
                    // system for everything below the exhibit.
                    memoBlock(ticket)
                        .frame(maxWidth: 318)
                        .padding(.horizontal, 30)
                        .padding(.top, 36)
                }
                // The page clears its throat while the gate takes the
                // ticket — and again when the ticket departs for home.
                .opacity(departing ? 0 : 1 - min(1, shredProgress * 2.6))
                .animation(.easeOut(duration: 0.16), value: departing)

                Spacer(minLength: 96)
            }
        }
        // The shred interpolates HERE, inside the hosted tree — a
        // `withAnimation` outside the rail's hosting boundary arrives as
        // a bare 0→1 jump, so the page owns its own tearing clock.
        .animation(.easeIn(duration: 0.95), value: shredProgress)
        .scrollIndicators(.hidden)
        .onAppear {
            memoDraft = ticket.memo
        }
        .scrollDismissesKeyboard(.interactively)
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
        // One soft gloss at rest — the same sheen the ticket wears as it
        // flies in on the lift, so the seated hero and the flight match.
        .visualEffect { content, proxy in
            content.colorEffect(
                ShaderLibrary.holoSheen(
                    .float2(proxy.size),
                    .float2(0, 0),
                    .float(0.12)
                )
            )
        }
    }

    /// The exhibit under glass — lit, grounded, and still. The lift's
    /// open/close flights carry all the drama; the seated ticket is calm,
    /// its paper stock and cut edges doing the work (no drag, no mirror).
    private func hero(_ ticket: Ticket) -> some View {
        heroCard(ticket)
            .shadow(color: .black.opacity(0.50), radius: 24, y: 18)
            .shredFall(progress: shredProgress, seed: ticket.styleSeed)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("切符 \(ticket.routeText)")
            .accessibilityIdentifier("stage-hero")
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
