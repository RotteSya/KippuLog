import SwiftUI

/// The studio — a dark room holding one lit ticket at a time.
/// Swipe sideways to leaf through the collection; pinch closed (or drag
/// the zoom transition) to put the magazine back on the table.
struct TicketStageView: View {
    @Environment(TicketStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: Ticket?

    @State private var pageID: UUID
    @State private var pinchScale: CGFloat = 1
    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var shredProgress: Double = 0
    /// The departure: facts and chrome dissolve, then the ticket flies.
    @State private var departing = false
    /// Lights out — fired *with* the pop, so the room dissolves inside
    /// the shrinking window while the ticket rides it home.
    @State private var lightsOut = false

    init(selection: Binding<Ticket?>) {
        _selection = selection
        _pageID = State(initialValue: selection.wrappedValue?.id ?? UUID())
    }

    var body: some View {
        ZStack {
            StudioBackdrop(center: UnitPoint(x: 0.5, y: 0.26), radius: 0.85, warmth: 0.55, air: true)
                .opacity(lightsOut ? 0 : 1)
                .animation(.easeOut(duration: 0.22), value: lightsOut)

            StageRail(
                tickets: store.tickets,
                pageID: $pageID,
                shredProgress: shredProgress,
                departing: departing
            )
            .ignoresSafeArea(edges: .bottom)
        }
        // Behind the studio, the window is the same paper as the page it
        // shrinks onto — when the lights go out mid-pop, the room gives
        // way to paper-on-paper and the lone ticket rides the window home.
        .containerBackground(Ink.background, for: .navigation)
        .scaleEffect(pinchScale)
        .opacity(Double(0.4 + pinchScale * 0.6))
        .simultaneousGesture(pinchToClose)
        .overlay(alignment: .top) {
            chrome
                .opacity(departing ? 0 : 1)
                .animation(.easeOut(duration: 0.16), value: departing)
        }
        .onChange(of: pageID) { old, new in
            // The rail's notch already spoke (haptic); keep the zoom
            // source in step with the card under the lamp.
            guard old != new else { return }
            if let ticket = store.tickets.first(where: { $0.id == new }) {
                selection = ticket
            }
        }
        .sheet(isPresented: $showEdit) {
            if let ticket = currentTicket {
                EditTicketSheet(ticket: ticket)
            }
        }
        .overlay {
            // The gate asks in its own voice — a paper slip on the desk,
            // not a system dialog.
            if confirmDelete {
                DeleteSlip(
                    onRelease: {
                        confirmDelete = false
                        shredAndDelete()
                    },
                    onKeep: {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            confirmDelete = false
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .task {
            #if DEBUG
            // `-uiTestProbeReturn` — close after a beat through the exact
            // path the X button takes, for external burst dissection.
            if ProcessInfo.processInfo.arguments.contains("-uiTestProbeReturn") {
                try? await Task.sleep(for: .seconds(2.5))
                flyHome()
            }
            #endif
        }
    }

    // MARK: Departure

    /// Departure: the facts dissolve, the room's lights go out — and the
    /// system pop is left shrinking a lone lit ticket home to its slot,
    /// never a dark rectangle of room.
    private func flyHome() {
        guard !departing else { return }
        Haptic.play(.tick)
        withAnimation(.easeOut(duration: 0.16)) { departing = true }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { pinchScale = 1 }
        Task {
            // Beat one: the facts dissolve. Beat two: the lamp goes out,
            // leaving the lone ticket on paper. Beat three: the pop rides
            // the ticket home — a paper window over a paper page, so the
            // only thing seen moving is the ticket itself.
            try? await Task.sleep(for: .milliseconds(140))
            lightsOut = true
            try? await Task.sleep(for: .milliseconds(90))
            dismiss()
        }
    }

    private var currentTicket: Ticket? {
        store.tickets.first(where: { $0.id == pageID })
    }

    // MARK: Chrome

    private var chrome: some View {
        HStack {
            Button {
                flyHome()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Stage.softText)
                    .frame(width: 40, height: 40)
            }
            .glassEffect(.regular, in: .circle)
            .accessibilityIdentifier("stage-close")

            Spacer()

            if let ticket = currentTicket {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    ShareLink(
                        item: TicketShareCard(
                            ticket: ticket,
                            photo: store.photo(for: ticket),
                            cutout: store.cutout(for: ticket)
                        ),
                        preview: SharePreview("きっぷ — \(ticket.routeText)")
                    ) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            confirmDelete = true
                        }
                    } label: {
                        Label("手放す", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Stage.softText)
                        .frame(width: 40, height: 40)
                }
                .glassEffect(.regular, in: .circle)
                .accessibilityIdentifier("stage-menu")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: Gestures

    private var pinchToClose: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let m = value.magnification
                if m < 1 {
                    pinchScale = max(0.82, 0.82 + 0.18 * m)
                }
            }
            .onEnded { value in
                if value.magnification < 0.72 {
                    flyHome()
                } else {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.7)) {
                        pinchScale = 1
                    }
                }
            }
    }

    // MARK: Delete

    /// 改札が回収する — the gate takes the ticket back: a punch, then the
    /// card tears into strips that flutter away.
    private func shredAndDelete() {
        guard let ticket = currentTicket else { return }
        Haptic.play(.punch)
        let neighbors = store.tickets
        let index = neighbors.firstIndex(where: { $0.id == ticket.id }) ?? 0
        let next = neighbors.indices.contains(index + 1) ? neighbors[index + 1]
            : (index > 0 ? neighbors[index - 1] : nil)

        Task {
            try? await Task.sleep(for: .milliseconds(420))
            Haptic.play(.stamp)
        }
        // The hosted page animates the tear itself (see StagePage) — a
        // plain assignment is the whole signal.
        shredProgress = 1
        Task {
            try? await Task.sleep(for: .milliseconds(980))
            store.remove(ticket)
            shredProgress = 0
            if let next {
                pageID = next.id
                selection = next
            } else {
                dismiss()
            }
        }
    }
}

/// Stage-only colors (the studio is always night).
enum Stage {
    static let text = Color(hex: 0xEDE6DA)
    static let softText = Color(hex: 0xBCB3A8)
    static let faintText = Color(hex: 0x847B70)
    static let rule = Color(hex: 0x2B261F)
}
