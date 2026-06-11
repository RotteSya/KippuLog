import SwiftUI

/// The magazine — a scrolling catalogue of every journey, grouped by
/// month, set like a table of contents. Tap a plate to step into its
/// studio; the punch button below opens the gate.
struct TimelineView: View {
    @Environment(TicketStore.self) private var store
    @Namespace private var zoomNamespace
    @State private var selectedTicket: Ticket?
    @State private var showCapture = false

    var body: some View {
        NavigationStack {
            Group {
                if store.tickets.isEmpty {
                    EmptyStateView()
                } else {
                    magazine
                }
            }
            .background(Ink.background)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedTicket) { ticket in
                TicketStageView(ticket: ticket)
                    .navigationTransition(.zoom(sourceID: ticket.id, in: zoomNamespace))
            }
        }
        .overlay(alignment: .bottom) {
            PunchButton {
                showCapture = true
            }
            .padding(.bottom, 14)
        }
        .fullScreenCover(isPresented: $showCapture) {
            CaptureFlowView()
        }
    }

    // MARK: Magazine

    private var magazine: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                masthead
                    .padding(.top, 24)
                    .padding(.bottom, 44)

                let groups = store.monthGroups
                let starts = entryStartIndices(groups)
                ForEach(Array(groups.enumerated()), id: \.element.month) { groupIndex, group in
                    monthSection(group, startIndex: starts[groupIndex])
                }

                colophon
                    .padding(.top, 36)
                    .padding(.bottom, 120)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var masthead: some View {
        VStack(spacing: 14) {
            Text("きっぷログ")
                .font(Typo.mincho(24))
                .tracking(10)
                .foregroundStyle(Ink.text)
                .padding(.leading, 10) // optically recenter the tracked text
            Rectangle()
                .fill(Ink.rule)
                .frame(width: 56, height: 1)
            Text("COLLECTED JOURNEYS")
                .font(Typo.caption(10))
                .tracking(3.5)
                .foregroundStyle(Ink.textFaint)
        }
        .frame(maxWidth: .infinity)
    }

    /// Running entry offsets so the left/right rhythm carries across months.
    private func entryStartIndices(_ groups: [(month: DateComponents, tickets: [Ticket])]) -> [Int] {
        var starts: [Int] = []
        var total = 0
        for group in groups {
            starts.append(total)
            total += group.tickets.count
        }
        return starts
    }

    private func monthSection(_ group: (month: DateComponents, tickets: [Ticket]), startIndex: Int) -> some View {
        VStack(spacing: 0) {
            monthHeader(group.month)
                .padding(.horizontal, 28)
                .padding(.bottom, 34)

            ForEach(Array(group.tickets.enumerated()), id: \.element.id) { index, ticket in
                TimelineEntry(
                    ticket: ticket,
                    alignment: (startIndex + index).isMultiple(of: 2) ? .leading : .trailing
                )
                .matchedTransitionSource(id: ticket.id, in: zoomNamespace)
                .onTapGesture {
                    Haptic.play(.tick)
                    selectedTicket = ticket
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 54)
            }
        }
        .padding(.bottom, 18)
    }

    private func monthHeader(_ month: DateComponents) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text(Editorial.kanjiMonth(month.month ?? 1))
                    .font(Typo.mincho(34))
                    .tracking(5)
                    .foregroundStyle(Ink.text)
                Spacer()
                Text(Editorial.latinMonthYear(month))
                    .font(Typo.caption(10))
                    .tracking(3)
                    .foregroundStyle(Ink.textSoft)
            }
            Rectangle()
                .fill(Ink.rule)
                .frame(height: 1)
        }
    }

    private var colophon: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(Ink.rule)
                .frame(width: 56, height: 1)
            Text("全 \(store.tickets.count) 枚 — \(Editorial.yen(store.totalSpent))")
                .font(Typo.serifFigure(13, weight: .regular))
                .foregroundStyle(Ink.textSoft)
            Text("FIN")
                .font(Typo.caption(9))
                .tracking(4)
                .foregroundStyle(Ink.textFaint)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let store = TicketStore()
    if store.tickets.isEmpty { store.addSamples() }
    return TimelineView().environment(store)
}
