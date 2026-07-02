import SwiftUI

/// The studio — a dark room holding one lit ticket at a time.
/// Swipe sideways to leaf through the collection; pinch closed (or drag
/// the zoom transition) to put the magazine back on the table.
struct TicketStageView: View {
    @Environment(TicketStore.self) private var store
    @Environment(LiftEngine.self) private var lift: LiftEngine?
    @Binding var selection: Ticket?

    @State private var pageID: UUID
    @State private var pinchScale: CGFloat = 1
    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var shredProgress: Double = 0
    /// The departure: facts and chrome dissolve, then the ticket flies.
    @State private var departing = false
    /// Arrival: the lift seated the hero; the captions and chrome follow
    /// a breath later, like a curator laying out the cards.
    @State private var furnished = false

    init(selection: Binding<Ticket?>) {
        _selection = selection
        _pageID = State(initialValue: selection.wrappedValue?.id ?? UUID())
    }

    var body: some View {
        ZStack {
            StudioBackdrop(center: UnitPoint(x: 0.5, y: 0.26), radius: 0.85, warmth: 0.55, air: true)

            StageRail(
                tickets: store.tickets,
                pageID: $pageID,
                shredProgress: shredProgress,
                departing: departing
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .task {
            // The lift hands over on identical pixels; the furniture
            // follows a breath later.
            guard !furnished else { return }
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                furnished = true
            }
        }
        .scaleEffect(pinchScale)
        .opacity(Double(0.4 + pinchScale * 0.6))
        .simultaneousGesture(pinchToClose)
        .overlay(alignment: .top) {
            chrome
                .opacity(departing || !furnished ? 0 : 1)
                .offset(y: furnished ? 0 : -10)
                .animation(.easeOut(duration: 0.16), value: departing)
                .animation(.easeOut(duration: 0.30), value: furnished)
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

    /// Departure: the facts dissolve, then the lift takes the lone lit
    /// ticket home to its slot while this room hands itself over to the
    /// engine's identical one.
    private func flyHome() {
        guard !departing else { return }
        Haptic.play(.tick)
        withAnimation(.easeOut(duration: 0.16)) { departing = true }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { pinchScale = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard let ticket = currentTicket else { selection = nil; return }
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }.first?.keyWindow
            lift?.close(
                ticket,
                container: window?.bounds ?? UIScreen.main.bounds,
                safeTop: window?.safeAreaInsets.top ?? 59
            )
            selection = nil
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
                // The collection emptied — the lights simply come up.
                withAnimation(.easeOut(duration: 0.16)) { departing = true }
                Task {
                    try? await Task.sleep(for: .milliseconds(170))
                    selection = nil
                }
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
