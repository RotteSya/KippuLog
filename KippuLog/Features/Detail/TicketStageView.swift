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
    @State private var dissolveProgress: Double = 0

    init(selection: Binding<Ticket?>) {
        _selection = selection
        _pageID = State(initialValue: selection.wrappedValue?.id ?? UUID())
    }

    var body: some View {
        ZStack {
            StudioBackdrop(center: UnitPoint(x: 0.5, y: 0.26), radius: 0.85, warmth: 0.55)

            TabView(selection: $pageID) {
                ForEach(store.tickets) { ticket in
                    StagePage(
                        ticketID: ticket.id,
                        dissolveProgress: ticket.id == pageID ? dissolveProgress : 0
                    )
                    .tag(ticket.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
        }
        .scaleEffect(pinchScale)
        .opacity(Double(0.4 + pinchScale * 0.6))
        .simultaneousGesture(pinchToClose)
        .overlay(alignment: .top) { chrome }
        .onChange(of: pageID) { old, new in
            guard old != new else { return }
            Haptic.play(.page)
            if let ticket = store.tickets.first(where: { $0.id == new }) {
                selection = ticket
            }
        }
        .sheet(isPresented: $showEdit) {
            if let ticket = currentTicket {
                EditTicketSheet(ticket: ticket)
            }
        }
        .confirmationDialog(
            "この切符を手放しますか？",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("手放す", role: .destructive) { dissolveAndDelete() }
            Button("やめる", role: .cancel) {}
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .statusBarHidden(true)
    }

    private var currentTicket: Ticket? {
        store.tickets.first(where: { $0.id == pageID })
    }

    // MARK: Chrome

    private var chrome: some View {
        HStack {
            Button {
                dismiss()
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
                        item: TicketShareCard(ticket: ticket),
                        preview: SharePreview("きっぷ — \(ticket.routeText)")
                    ) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
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
                    Haptic.play(.tick)
                    dismiss()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.3)) {
                        pinchScale = 1
                    }
                } else {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.7)) {
                        pinchScale = 1
                    }
                }
            }
    }

    // MARK: Delete

    private func dissolveAndDelete() {
        guard let ticket = currentTicket else { return }
        Haptic.play(.stamp)
        let neighbors = store.tickets
        let index = neighbors.firstIndex(where: { $0.id == ticket.id }) ?? 0
        let next = neighbors.indices.contains(index + 1) ? neighbors[index + 1]
            : (index > 0 ? neighbors[index - 1] : nil)

        withAnimation(.easeIn(duration: 0.85)) {
            dissolveProgress = 1
        } completion: {
            store.remove(ticket)
            dissolveProgress = 0
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
