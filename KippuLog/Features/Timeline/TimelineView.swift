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
    /// The fold — the one continuous sheet between the 誌面 and the
    /// 収蔵帳; pinches scrub it, the corner doors drive it whole.
    @State private var shelf = ShelfFold(
        startInAlbum: ProcessInfo.processInfo.arguments.contains("-uiTestAlbum")
    )
    @State private var jumpTargetID: UUID?
    @State private var droppedImage: UIImage?
    /// The issue prints itself onto the launch screen's blank paper —
    /// masthead first, then the entries, then the punch steps in.
    @State private var arrivalT: CGFloat = 0
    @State private var punchArrived = false
    /// One-shot pop when the welcome specimen dives into the button.
    @State private var punchPop = false
    /// The colophon page — the magazine's few settings live there.
    @State private var showOkuzuke = false

    var body: some View {
        GeometryReader { proxy in
            PageTurn(engine: lift) {
                stackRoot
            }
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
            // The gate belongs to the page's world: it leaves the moment
            // a lift takes hold, and steps back in once the ticket is
            // truly down and the spread lies flat again. Its spring is
            // scoped HERE — an ambient `.animation(value:)` on the whole
            // subtree would smear cross-fades over every one of the
            // engine's hand-placed frames.
            let pageSettled = selectedTicket == nil && lift.flight == nil && punchArrived
            ZStack {
                if pageSettled {
                    PunchButton {
                        openGate()
                    }
                    .scaleEffect(punchPop ? 1.16 : 1)
                    .padding(.bottom, 14)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: pageSettled)
        }
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
                // `-uiTestProbeLast` picks a single-station ticket (the
                // seeded 入場券) so bursts can dissect both placard shapes.
                let pick = ProcessInfo.processInfo.arguments.contains("-uiTestProbeLast")
                    ? (store.tickets.first(where: { $0.toStation.isEmpty }) ?? store.tickets.last)
                    : store.tickets.first
                if let pick {
                    openStage(pick, slotKey: (shelf.albumShowing ? "a-" : "t-") + pick.id.uuidString)
                }
            }
            #endif
        }
    }

    private var stackRoot: some View {
            ZStack {
                // The collection lives BENEATH the open issue — the fold
                // uncovers it; the two shelves never crossfade. Both are
                // mounted only while the fold is actually in motion.
                if shelf.albumMounted {
                    AlbumView(
                        selection: selectedTicket,
                        onOpen: { ticket in
                            openStage(ticket, slotKey: "a-\(ticket.id)")
                        },
                        onJumpMonth: jumpToMonth,
                        onCloseAlbum: { shelf.go(toAlbum: false) },
                        onOkuzuke: { showOkuzuke = true }
                    )
                    .albumReveal(shelf)
                    .simultaneousGesture(albumPinchOpen)
                    // Hard swap under explicit depth: a shelf only ever
                    // unmounts fully covered (or fully dissolved), and an
                    // ambient transaction must never turn that removal
                    // into a floating crossfade above its sibling.
                    .zIndex(0)
                    .transition(.identity)
                }
                if shelf.magazineMounted {
                    Group {
                        if store.tickets.isEmpty {
                            EmptyStateView(onOkuzuke: { showOkuzuke = true })
                        } else {
                            magazine
                        }
                    }
                    .magazineFold(shelf)
                    .zIndex(1)
                    .transition(.identity)
                }
            }
            .onAppear {
                guard arrivalT == 0 else { return }
                withAnimation(.easeOut(duration: 0.85).delay(0.05)) {
                    arrivalT = 1
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(440))
                    punchArrived = true
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
                    if !shelf.albumShowing, !store.tickets.isEmpty {
                        PaperFade(side: .bottom, height: 132)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .background(Ink.background)
            .onChange(of: selectedTicket) { old, new in
                // Stage paging: keep the landing slot under whichever card
                // is on stage, in whichever shelf is showing — and the
                // vacancy with it (the previous card sits back down, the
                // new exhibit's seat empties).
                guard old != nil, let new else { return }
                lift.activeKey = (shelf.albumShowing ? "a-" : "t-") + new.id.uuidString
                if lift.vacantKey != nil {
                    lift.vacantKey = lift.activeKey
                }
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

    /// Pinch the issue closed → the fingers hold the fold itself.
    /// Direction-split with the per-card pinch-open (above 1×).
    private var magazinePinchClose: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard value.magnification < 1 || shelf.scrubbing else { return }
                shelf.scrubClose(magnification: value.magnification)
            }
            .onEnded { _ in
                shelf.releaseClose()
            }
    }

    /// Pinch the album open → the page lays back down over it.
    private var albumPinchOpen: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard value.magnification > 1 || shelf.scrubbing else { return }
                shelf.scrubOpen(magnification: value.magnification)
            }
            .onEnded { _ in
                shelf.releaseOpen()
            }
    }

    /// A month stamp in the album → the magazine, opened to that month.
    private func jumpToMonth(_ month: DateComponents) {
        let calendar = Calendar(identifier: .gregorian)
        let target = store.tickets.first {
            calendar.dateComponents([.year, .month], from: $0.sortDate) == month
        }
        // The fold mounts the magazine first; the jump lands while the
        // page is still edge-on, so the reveal opens onto the month.
        shelf.go(toAlbum: false)
        jumpTargetID = target?.id
    }

    // MARK: Magazine

    private var magazine: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // The issue prints itself onto the blank launch paper:
                    // masthead first, the catalogue after, one clock.
                    masthead
                        .padding(.top, 22)
                        .padding(.bottom, 48)
                        .cascade(arrivalT, 0...0.5, rise: 6)

                    let numbers = store.catalogNumbers
                    ForEach(store.monthGroups, id: \.month) { group in
                        monthSection(group, numbers: numbers)
                            .cascade(arrivalT, 0.22...0.9, rise: 12)
                    }

                    colophon
                        .padding(.top, 40)
                        .padding(.bottom, 124)
                        .cascade(arrivalT, 0.22...0.9, rise: 12)
                }
            }
            .scrollIndicators(.hidden)
            .simultaneousGesture(magazinePinchClose)
            .onChange(of: selectedTicket) { old, new in
                // Paging inside the stage: keep the shelf positioned so the
                // return zoom lands on the visible plate.
                guard old != nil, let new, !shelf.albumShowing else { return }
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
                // A fresh ticket just punched in — the shelf jumps to its
                // slot while the capture cover still hides the page, so the
                // lift has a stable slot to land on.
                guard let new else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(60))
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    // MARK: Masthead

    private var masthead: some View {
        MagazineMasthead(
            onAlbum: { shelf.go(toAlbum: true) },
            onOkuzuke: { showOkuzuke = true }
        )
    }

    // MARK: Sections

    private func monthSection(
        _ group: (month: DateComponents, tickets: [Ticket]),
        numbers: [UUID: Int]
    ) -> some View {
        VStack(spacing: 0) {
            monthHeader(group.month, count: group.tickets.count)
                .padding(.horizontal, 30)
                .padding(.bottom, 36)

            ForEach(group.tickets) { ticket in
                TimelineEntry(
                    ticket: ticket,
                    number: numbers[ticket.id] ?? 0,
                    onOpen: {
                        openStage(ticket, slotKey: "t-\(ticket.id)")
                    }
                )
                .id(ticket.id)
                .padding(.horizontal, 30)
                .padding(.bottom, 60)
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

/// The whole spread as one sheet of paper in the lift's hand: opening a
/// ticket turns the page away behind its spine while the object rises;
/// closing swings it back beneath the descending ticket. Isolated in its
/// own view so the engine's per-frame clock re-renders this transform
/// alone — never the shelf inside it.
private struct PageTurn<Content: View>: View {
    let engine: LiftEngine
    @ViewBuilder var content: Content

    var body: some View {
        let turn = engine.pageTurn
        // Once the page is fully turned away AND the flight is done,
        // the opaque stage covers everything — so the page must return
        // to its EXACT resting configuration, as if PageTurn weren't
        // here. Any residue left on the hidden spread (opacity(0), a
        // standing perspective modifier, accessibilityHidden, a dead
        // hit-test region) poisons synthesized-event routing for the
        // stage above it — XCUITest pinches and taps die. Hence a
        // GeometryEffect (identity matrix at rest, no structural churn)
        // and value-identity modifiers everywhere else.
        let away = turn >= 0.999 && engine.flight == nil
        let turning = turn > 0.001 && !away
        ZStack {
            // The dark room lives BENEATH the paper — turning the page
            // reveals it; the sweep itself is the transition, no
            // curtain fading in above. Always in the tree (structural
            // churn re-plumbs the remote a11y snapshot), lit only when
            // the page is in motion or a flight is in the air.
            StudioBackdrop(
                center: UnitPoint(x: 0.5, y: 0.26),
                radius: 0.85,
                warmth: 0.55
            )
            .opacity(turning || engine.flight != nil ? 1 : 0)

            content
                .modifier(PageTurnGeometry(turn: turning ? turn : 0))
                // The far edge dips into the room's dark as it swings away.
                .brightness(turning ? -turn * 0.28 : 0)
                .opacity(turning ? 1 - Ease.inCubic(turn) : 1)
                .allowsHitTesting(!turning)
                // Proper modal semantics: a page fully behind the stage
                // is silent to VoiceOver — and stage chrome never shares
                // accessibility coordinates with page furniture (the
                // magazine's and album's corner doors sit exactly under
                // the stage's close button; element-routed taps would
                // land on the page's door instead of the X).
                .accessibilityHidden(away)
        }
    }
}

/// The page's swing as one projection matrix about the spine (the
/// leading edge). A GeometryEffect so that at rest it is a TRUE
/// identity — no transform layer, no hit-test detour, nothing for
/// event routing to trip on — and mid-turn the hardware projects the
/// spread exactly like a page on a hinge.
private struct PageTurnGeometry: GeometryEffect {
    var turn: Double

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard turn > 0.0001 else { return ProjectionTransform() }
        var t = CATransform3DIdentity
        // Eye distance ~1.8 page-widths: enough perspective to read as
        // a turning sheet, not so much that the far edge smears.
        t.m34 = -1 / max(size.width * 1.8, 1)
        // Rotate about the Y axis through the layer origin — the spine
        // runs down the page's leading edge.
        t = CATransform3DRotate(t, -turn * 74 * .pi / 180, 0, 1, 0)
        return ProjectionTransform(t)
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
