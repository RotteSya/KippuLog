import SwiftUI

/// The magazine — a scrolling catalogue of every journey, grouped by
/// month, set like a table of contents. Tap a plate to step into its
/// studio; the punch button below opens the gate.
struct TimelineView: View {
    @Environment(TicketStore.self) private var store
    @State private var selectedTicket: Ticket?
    @State private var showCapture = false
    /// The lift — every page⇄stage journey is one of its flights.
    @State private var lift = LiftEngine()
    @State private var showAlbum = ProcessInfo.processInfo.arguments.contains("-uiTestAlbum")
    @State private var pinchLive: CGFloat = 1
    @State private var albumPinchLive: CGFloat = 1
    @State private var jumpTargetID: UUID?
    @State private var highlightID: UUID?
    @State private var droppedImage: UIImage?
    @State private var arrived = false
    /// One-shot pop when the welcome specimen dives into the button.
    @State private var punchPop = false
    /// The colophon page — the magazine's few settings live there.
    @State private var showOkuzuke = false

    var body: some View {
        GeometryReader { proxy in
            stackRoot
                .overlay {
                    // The stage — mounted the frame the lift seats its
                    // ticket, already wearing identical pixels. Identity
                    // transition: the engine owns every visible motion,
                    // the mount itself must be a hard swap.
                    if selectedTicket != nil {
                        TicketStageView(selection: $selectedTicket)
                            .environment(lift)
                            .transition(.identity)
                            .zIndex(2)
                    }
                }
                .overlay {
                    LiftOverlay(engine: lift)
                        .zIndex(3)
                }
                .onAppear { configureLift(proxy: proxy) }
        }
        .environment(lift)
        .overlay(alignment: .bottom) {
            if selectedTicket == nil {
                PunchButton {
                    openGate()
                }
                .scaleEffect(punchPop ? 1.16 : 1)
                .padding(.bottom, 14)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedTicket == nil)
        .fullScreenCover(isPresented: $showCapture, onDismiss: { droppedImage = nil }) {
            CaptureFlowView(initialImage: droppedImage)
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showOkuzuke) {
            OkuzukeView(onReplayWelcome: {
                Task {
                    try? await Task.sleep(for: .milliseconds(420))
                    store.replayWelcome()
                }
            })
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
                    openGate()
                }
            }
        }
        .task {
            #if DEBUG
            // `-uiTestImport` launches straight into the gate ceremony.
            if ProcessInfo.processInfo.arguments.contains("-uiTestImport"), !showCapture {
                try? await Task.sleep(for: .milliseconds(700))
                openGate()
            }
            // `-uiTestProbeReturn` — opens the first ticket on a fixed
            // clock; the stage closes itself via the same `dismiss()` the
            // X button uses (see TicketStageView), so an external burst
            // can dissect the real return zoom. Combine with -uiTestAlbum
            // for the album's return.
            if ProcessInfo.processInfo.arguments.contains("-uiTestProbeReturn") {
                try? await Task.sleep(for: .seconds(2))
                if let first = store.tickets.first {
                    openStage(first, slotKey: (showAlbum ? "a-" : "t-") + first.id.uuidString)
                }
            }
            #endif
        }
    }

    private var stackRoot: some View {
            ZStack {
                if showAlbum {
                    AlbumView(
                        selection: selectedTicket,
                        onOpen: { ticket in
                            openStage(ticket, slotKey: "a-\(ticket.id)")
                        },
                        onJumpMonth: jumpToMonth,
                        onCloseAlbum: {
                            Haptic.play(.page)
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                                showAlbum = false
                            }
                        },
                        onOkuzuke: { showOkuzuke = true }
                    )
                    .scaleEffect(albumPinchLive)
                    .simultaneousGesture(albumPinchOpen)
                    .transition(.scale(scale: 1.12).combined(with: .opacity))
                } else {
                    Group {
                        if store.tickets.isEmpty {
                            EmptyStateView(onOkuzuke: { showOkuzuke = true })
                        } else {
                            magazine
                        }
                    }
                    .scaleEffect(pinchLive)
                    // The pinch folds the page as a book closing — a few
                    // degrees of lean and a deepening edge; releasing
                    // unfolds it into the commit spring.
                    .rotation3DEffect(
                        .degrees(Double(1 - pinchLive) * 46),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.30
                    )
                    .shadow(
                        color: .black.opacity(Double(1 - pinchLive) * 1.4),
                        radius: 30,
                        y: 18
                    )
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
                openGate()
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
            .onChange(of: selectedTicket) { old, new in
                // Stage paging: keep the landing slot under whichever card
                // is on stage, in whichever shelf is showing.
                guard old != nil, let new else { return }
                lift.activeKey = (showAlbum ? "a-" : "t-") + new.id.uuidString
            }
    }

    // MARK: The lift

    /// The engine reads real object aspects for hero geometry; its open
    /// flight mounts the stage the frame it seats.
    private func configureLift(proxy: GeometryProxy) {
        LiftEngine.aspectSource = { [weak store] ticket in
            guard let store else { return TicketArtView.aspect(for: ticket.kind) }
            if let cutout = store.cutout(for: ticket), cutout.size.height > 0 {
                return cutout.size.width / cutout.size.height
            }
            if store.photo(for: ticket) != nil, let raw = ticket.photoAspect {
                return raw
            }
            return TicketArtView.aspect(for: ticket.kind)
        }
    }

    /// Tap a card: the lift raises it into the lamp, then the stage takes
    /// over on identical pixels.
    private func openStage(_ ticket: Ticket, slotKey: String) {
        guard selectedTicket == nil, lift.flight == nil else { return }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first?.keyWindow
        let container = window?.bounds ?? UIScreen.main.bounds
        let safeTop = window?.safeAreaInsets.top ?? 59
        lift.onSeated = { selectedTicket = ticket }
        lift.open(ticket, fromSlot: slotKey, container: container, safeTop: safeTop)
    }

    /// Open the gate with no system slide — the capture room dims itself
    /// over the page (its own entrance owns the moment).
    private func openGate() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { showCapture = true }
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
                // A fresh ticket just punched in. The shelf jumps to its
                // slot while the capture cover still hides the page — the
                // lift needs a stable slot to land on — then the studio
                // light sweeps the plate as it settles.
                guard let new else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(60))
                    proxy.scrollTo(new, anchor: .center)
                    try? await Task.sleep(for: .milliseconds(780))
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
        MagazineMasthead(
            onAlbum: {
                Haptic.play(.page)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    showAlbum = true
                }
            },
            onOkuzuke: { showOkuzuke = true }
        )
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
                    onOpen: {
                        openStage(ticket, slotKey: "t-\(ticket.id)")
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
            RestampableSeal()
            Text("全 \(store.tickets.count) 枚 — \(Editorial.yen(store.totalSpent))")
                .font(Typo.serifFigure(13, weight: .regular))
                .foregroundStyle(Ink.textSoft)
            Text("旅はつづく")
                .font(Typo.mincho(11, light: true))
                .tracking(5)
                .foregroundStyle(Ink.textFaint)

            Text("つまんで 収蔵帳へ")
                .font(Typo.caption(8.5))
                .tracking(2.5)
                .foregroundStyle(Ink.textFaint.opacity(0.75))
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The colophon's seal answers a touch with a fresh press of ink —
/// a small pleasure for whoever reads to the end of the issue.
private struct RestampableSeal: View {
    @State private var pressT = 0
    @State private var bloom = false

    var body: some View {
        Button {
            Haptic.play(.stamp)
            bloom = false
            withAnimation(.spring(response: 0.24, dampingFraction: 0.5)) {
                pressT += 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.04)) {
                bloom = true
            }
        } label: {
            HankoSeal(size: 15)
                .keyframeAnimator(initialValue: 1.0, trigger: pressT) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(1.28, duration: 0.10)
                        SpringKeyframe(1.0, duration: 0.34, spring: .init(response: 0.3, dampingRatio: 0.55))
                    }
                }
                .background {
                    Circle()
                        .stroke(Ink.shu.opacity(bloom ? 0 : 0.5), lineWidth: 1.1)
                        .scaleEffect(bloom ? 2.6 : 0.6)
                        .accessibilityHidden(true)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("きっぷログの落款")
    }
}

#Preview {
    let store = TicketStore()
    if store.tickets.isEmpty { store.addSamples() }
    return TimelineView().environment(store)
}
