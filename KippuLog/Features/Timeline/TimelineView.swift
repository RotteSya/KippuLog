import SwiftUI

/// The magazine — a scrolling catalogue of every journey, grouped by
/// month, set like a table of contents. Tap a plate to step into its
/// studio; the punch button below opens the gate.
struct TimelineView: View {
    @Environment(TicketStore.self) private var store
    @Namespace private var zoomNamespace
    @State private var selectedTicket: Ticket?
    @State private var zoomSourceKey = ""
    @State private var showCapture = false
    @State private var showAlbum = ProcessInfo.processInfo.arguments.contains("-uiTestAlbum")
    @State private var pinchLive: CGFloat = 1
    @State private var albumPinchLive: CGFloat = 1
    @State private var jumpTargetID: UUID?
    @State private var highlightID: UUID?
    @State private var droppedImage: UIImage?
    @State private var arrived = false
    /// One-shot pop when the welcome specimen dives into the button.
    @State private var punchPop = false

    var body: some View {
        NavigationStack {
            ZStack {
                if showAlbum {
                    AlbumView(
                        zoomNamespace: zoomNamespace,
                        onOpen: { ticket in
                            zoomSourceKey = "a-\(ticket.id)"
                            selectedTicket = ticket
                        },
                        onJumpMonth: jumpToMonth
                    )
                    .scaleEffect(albumPinchLive)
                    .simultaneousGesture(albumPinchOpen)
                    .transition(.scale(scale: 1.12).combined(with: .opacity))
                } else {
                    Group {
                        if store.tickets.isEmpty {
                            EmptyStateView()
                        } else {
                            magazine
                        }
                    }
                    .scaleEffect(pinchLive)
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                }
            }
            .opacity(arrived ? 1 : 0)
            .offset(y: arrived ? 0 : 16)
            .onAppear {
                withAnimation(.spring(response: 0.85, dampingFraction: 0.92).delay(0.06)) {
                    arrived = true
                }
            }
            .dropDestination(for: Data.self) { items, _ in
                guard let data = items.first, let image = UIImage(data: data) else { return false }
                Haptic.play(.tick)
                droppedImage = image
                showCapture = true
                return true
            }
            .overlay {
                // The page runs out into paper before it can touch the
                // clock above or the punch below.
                VStack(spacing: 0) {
                    PaperFade(side: .top, height: 92)
                    Spacer(minLength: 0)
                    if !showAlbum, !store.tickets.isEmpty {
                        PaperFade(side: .bottom, height: 132)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .background(Ink.background)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedTicket) { ticket in
                TicketStageView(selection: $selectedTicket)
                    .navigationTransition(.zoom(
                        sourceID: zoomSourceKey.isEmpty ? "t-\(ticket.id)" : zoomSourceKey,
                        in: zoomNamespace
                    ))
            }
            .onChange(of: selectedTicket) { old, new in
                // Stage paging: keep the zoom anchored to the right card in
                // whichever shelf is showing.
                guard old != nil, let new else { return }
                zoomSourceKey = (showAlbum ? "a-" : "t-") + new.id.uuidString
            }
        }
        .overlay(alignment: .bottom) {
            if selectedTicket == nil {
                PunchButton {
                    showCapture = true
                }
                .scaleEffect(punchPop ? 1.16 : 1)
                .padding(.bottom, 14)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedTicket == nil)
        .fullScreenCover(isPresented: $showCapture, onDismiss: { droppedImage = nil }) {
            CaptureFlowView(initialImage: droppedImage)
        }
        .onChange(of: store.welcomeFollowUp) { _, followUp in
            // The welcome's specimen just dove into the punch button — the
            // button answers with one pop, then (if asked) opens the gate.
            guard let followUp else { return }
            store.welcomeFollowUp = nil
            Task {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { punchPop = true }
                try? await Task.sleep(for: .milliseconds(240))
                withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) { punchPop = false }
                if followUp == .capture {
                    try? await Task.sleep(for: .milliseconds(280))
                    showCapture = true
                }
            }
        }
        .task {
            #if DEBUG
            // `-uiTestImport` launches straight into the gate ceremony.
            if ProcessInfo.processInfo.arguments.contains("-uiTestImport"), !showCapture {
                try? await Task.sleep(for: .milliseconds(700))
                showCapture = true
            }
            #endif
        }
    }

    // MARK: Album ↔ magazine bridge

    /// Pinch the magazine closed → the album. Direction-split with the
    /// per-card pinch-open (which only listens above 1×).
    private var magazinePinchClose: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard value.magnification < 1 else { return }
                pinchLive = max(0.86, value.magnification)
            }
            .onEnded { value in
                if value.magnification < 0.92 {
                    Haptic.play(.page)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                        showAlbum = true
                        pinchLive = 1
                    }
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        pinchLive = 1
                    }
                }
            }
    }

    /// Pinch the album open → back into the magazine.
    private var albumPinchOpen: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard value.magnification > 1 else { return }
                albumPinchLive = min(1.12, value.magnification)
            }
            .onEnded { value in
                if value.magnification > 1.07 {
                    Haptic.play(.page)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                        showAlbum = false
                        albumPinchLive = 1
                    }
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        albumPinchLive = 1
                    }
                }
            }
    }

    /// A month stamp in the album → the magazine, opened to that month.
    private func jumpToMonth(_ month: DateComponents) {
        let calendar = Calendar(identifier: .gregorian)
        let target = store.tickets.first {
            calendar.dateComponents([.year, .month], from: $0.sortDate) == month
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
            showAlbum = false
        }
        jumpTargetID = target?.id
    }

    // MARK: Magazine

    private var magazine: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    masthead
                        .padding(.top, 22)
                        .padding(.bottom, 48)

                    let groups = store.monthGroups
                    let starts = entryStartIndices(groups)
                    let numbers = catalogNumbers
                    ForEach(Array(groups.enumerated()), id: \.element.month) { groupIndex, group in
                        monthSection(group, startIndex: starts[groupIndex], numbers: numbers)
                    }

                    colophon
                        .padding(.top, 40)
                        .padding(.bottom, 124)
                }
            }
            .scrollIndicators(.hidden)
            .simultaneousGesture(magazinePinchClose)
            .onChange(of: selectedTicket) { old, new in
                // Paging inside the stage: keep the shelf positioned so the
                // return zoom lands on the visible plate.
                guard old != nil, let new, !showAlbum else { return }
                proxy.scrollTo(new.id, anchor: .center)
            }
            .onChange(of: jumpTargetID) { _, target in
                guard let target else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    proxy.scrollTo(target, anchor: .top)
                    jumpTargetID = nil
                }
            }
            .onChange(of: store.lastAddedID) { _, new in
                // A fresh ticket just punched in — walk to it and let the
                // studio light sweep across the plate.
                guard let new else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.9)) {
                        proxy.scrollTo(new, anchor: .center)
                    }
                    try? await Task.sleep(for: .milliseconds(650))
                    highlightID = new
                    try? await Task.sleep(for: .milliseconds(1400))
                    highlightID = nil
                }
            }
        }
    }

    /// Chronological catalogue numbers — the oldest journey is No. 001.
    private var catalogNumbers: [UUID: Int] {
        let ascending = store.tickets.sorted { $0.sortDate < $1.sortDate }
        return Dictionary(uniqueKeysWithValues: ascending.enumerated().map { ($1.id, $0 + 1) })
    }

    // MARK: Masthead

    private var masthead: some View {
        MagazineMasthead()
    }

    // MARK: Sections

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

    private func monthSection(
        _ group: (month: DateComponents, tickets: [Ticket]),
        startIndex: Int,
        numbers: [UUID: Int]
    ) -> some View {
        VStack(spacing: 0) {
            monthHeader(group.month, count: group.tickets.count)
                .padding(.horizontal, 30)
                .padding(.bottom, 36)

            ForEach(Array(group.tickets.enumerated()), id: \.element.id) { index, ticket in
                TimelineEntry(
                    ticket: ticket,
                    number: numbers[ticket.id] ?? 0,
                    alignment: (startIndex + index).isMultiple(of: 2) ? .leading : .trailing,
                    highlighted: highlightID == ticket.id,
                    zoomNamespace: zoomNamespace,
                    onOpen: {
                        zoomSourceKey = "t-\(ticket.id)"
                        selectedTicket = ticket
                    }
                )
                .id(ticket.id)
                .padding(.horizontal, 26)
                .padding(.bottom, 56)
            }
        }
        .padding(.bottom, 16)
    }

    private func monthHeader(_ month: DateComponents, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Editorial.kanjiMonth(month.month ?? 1))
                .font(Typo.mincho(44))
                .tracking(4)
                .foregroundStyle(Ink.text)
                .padding(.bottom, 6)

            Text(Editorial.latinMonthYear(month))
                .font(Typo.caption(9))
                .tracking(3.2)
                .foregroundStyle(Ink.textFaint)
                .padding(.bottom, 14)

            // Branded tick + hairline; the month's count rests at the end.
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Ink.shu)
                    .frame(width: 20, height: 2)
                Rectangle()
                    .fill(Ink.rule)
                    .frame(height: 0.7)
                Text(Editorial.kanjiCount(count))
                    .font(Typo.gothic(10))
                    .tracking(1)
                    .foregroundStyle(Ink.textFaint)
                    .padding(.leading, 10)
            }
        }
    }

    // MARK: Colophon

    private var colophon: some View {
        VStack(spacing: 12) {
            HankoSeal(size: 15)
            Text("全 \(store.tickets.count) 枚 — \(Editorial.yen(store.totalSpent))")
                .font(Typo.serifFigure(13, weight: .regular))
                .foregroundStyle(Ink.textSoft)
            Text("旅はつづく")
                .font(Typo.mincho(11, light: true))
                .tracking(5)
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
