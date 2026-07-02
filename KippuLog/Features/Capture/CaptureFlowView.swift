import SwiftUI
import PhotosUI

/// The gate — full capture flow.
///
///   gathering (camera or import) → gate (改札 ceremony, OCR in
///   parallel) → confirm (reveal + edit + save)
struct CaptureFlowView: View {
    @Environment(TicketStore.self) private var store
    @Environment(LiftEngine.self) private var lift: LiftEngine?
    @Environment(\.dismiss) private var dismiss

    /// Image handed in from drag & drop — skips straight to the gate.
    var initialImage: UIImage?

    @State private var camera = CameraService()
    @State private var phase = Phase.gathering
    @State private var pickerItem: PhotosPickerItem?
    @State private var scan: UIImage?
    @State private var cutout: UIImage?
    @State private var original: UIImage?
    @State private var quad: TicketQuad?
    @State private var showQuadEditor = false
    @State private var draft = Ticket()
    @State private var ocrTask: Task<[OCRLine], Never>?
    @State private var cutoutTask: Task<UIImage?, Never>?
    @State private var autoArmed = true
    @State private var shutterBusy = false
    /// Shutter blink — peaks the instant the photo is taken, decays over
    /// the cut into the gate so the phase swap hides inside it.
    @State private var flash: Double = 0
    /// The captured frame, frozen over the live feed while flatten works.
    @State private var frozenStill: UIImage?
    @State private var hadLock = false
    /// The room's dimmer. The cover presents with no system animation —
    /// entering the gate is the page going dark, leaving is lights-up.
    @State private var roomLit = false
    /// Saving: the desk withdraws and the ticket sinks toward the book
    /// while the lights come up — one motion, no cut.
    @State private var saving = false

    enum Phase { case gathering, gate, confirm }

    var body: some View {
        ZStack {
            // One room. The lamp swings and warms continuously as the
            // ceremony moves — never two backdrops crossfading.
            StudioBackdrop(
                center: roomLight.center,
                radius: roomLight.radius,
                warmth: roomLight.warmth
            )

            switch phase {
            case .gathering:
                gathering
                    .transition(.opacity)
            case .gate:
                if let scan {
                    GatePassView(scan: scan, styleSeed: draft.styleSeed) {
                        finishGate()
                    }
                    .transition(.opacity)
                }
            case .confirm:
                if let scan {
                    // The gate parked the scan on the exact frame the
                    // reveal occupies (`ConfirmStage`), so the confirm
                    // arrives *already there* — only the gate's chrome
                    // fades over identical pixels. No dip, no jump.
                    ConfirmTicketView(
                        scan: scan,
                        cutout: cutout,
                        draft: $draft,
                        saving: saving,
                        onSave: save,
                        onRetake: retake,
                        onAdjust: original == nil ? nil : { showQuadEditor = true }
                    )
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
                }
            }

            // The shutter blink — above every phase so the viewfinder→gate
            // cut lives inside it.
            Color.white
                .opacity(flash)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .opacity(roomLit ? 1 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.38)) { roomLit = true }
        }
        .statusBarHidden(true)
        .fullScreenCover(isPresented: $showQuadEditor) {
            if let original {
                QuadEditorView(
                    original: original,
                    initialQuad: quad,
                    onApply: applyManualQuad,
                    onCancel: { showQuadEditor = false }
                )
            }
        }
        .overlay(alignment: .topTrailing) {
            if phase != .confirm {
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Stage.softText)
                        .frame(width: 40, height: 40)
                }
                .glassEffect(.regular, in: .circle)
                .accessibilityIdentifier("capture-close")
                .padding(.trailing, 20)
                .padding(.top, 8)
            }
        }
        .task {
            if let initialImage {
                await acquired(initialImage)
                return
            }
            await camera.start()
            #if DEBUG
            autoImportForUITests()
            #endif
        }
        .onDisappear { camera.stop() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await importPicked(item) }
        }
        .onChange(of: camera.quadSteady) { _, steady in
            guard steady, autoArmed, phase == .gathering,
                  camera.availability == .ready else { return }
            autoArmed = false
            shutter()
        }
        .onChange(of: camera.guideQuad) { _, newQuad in
            // One soft paper tick the moment the frame takes hold.
            let locked = newQuad != nil
            guard locked != hadLock else { return }
            hadLock = locked
            if locked { Haptic.play(.tick) }
        }
    }

    private var phaseKey: Int {
        switch phase {
        case .gathering: 0
        case .gate: 1
        case .confirm: 2
        }
    }

    /// The lamp per scene — animated through `StudioBackdrop.animatableData`.
    private var roomLight: (center: UnitPoint, radius: CGFloat, warmth: CGFloat) {
        switch phase {
        case .gathering: (UnitPoint(x: 0.5, y: 0.42), 0.95, 0.35)
        case .gate: (UnitPoint(x: 0.5, y: 0.50), 0.95, 0.40)
        case .confirm: (UnitPoint(x: 0.5, y: 0.20), 0.80, 0.50)
        }
    }

    // MARK: Gathering

    @ViewBuilder
    private var gathering: some View {
        switch camera.availability {
        case .ready:
            cameraStage
        case .denied, .missing:
            importStage
        case .unknown:
            Color.clear
        }
    }

    private var cameraStage: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            // The captured frame, frozen the instant the shutter fires —
            // the live feed stops dead while flatten works underneath.
            if let frozenStill {
                Color.clear
                    .overlay {
                        Image(uiImage: frozenStill)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .ignoresSafeArea()
            }

            StudioVignette()

            CaptureViewfinder(
                quad: camera.guideQuad,
                bufferAspect: camera.bufferAspect,
                steadySince: camera.steadySince,
                frozen: frozenStill != nil
            )
            .ignoresSafeArea()

            VStack {
                Text(camera.guideQuad != nil ? "そのまま…" : "切符を枠のなかへ")
                    .font(Typo.gothic(12, bold: true))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: camera.guideQuad != nil)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.top, 64)
                Spacer()
                controls
                    .padding(.bottom, 30)
            }
            .opacity(frozenStill == nil ? 1 : 0)
            .animation(.easeOut(duration: 0.22), value: frozenStill == nil)
        }
    }

    private var controls: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 48, height: 48)
            }
            .glassEffect(.regular, in: .circle)
            .accessibilityIdentifier("capture-library")

            Spacer()

            Button(action: shutter) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.95), lineWidth: 4)
                        .frame(width: 74, height: 74)

                    // The hold-to-fire window, mirrored on the dial.
                    SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: camera.steadySince == nil)) { timeline in
                        Circle()
                            .trim(from: 0, to: CaptureHold.progress(at: timeline.date, since: camera.steadySince))
                            .stroke(Ink.shu, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 74, height: 74)

                    Circle()
                        .fill(Ink.shu)
                        .frame(width: 58, height: 58)
                }
            }
            .buttonStyle(ShutterPressStyle())
            .disabled(shutterBusy)
            .accessibilityIdentifier("capture-shutter")

            Spacer()

            // Mirror spacer to keep the shutter centered.
            Color.clear.frame(width: 48, height: 48)
        }
        .padding(.horizontal, 36)
    }

    private var importStage: some View {
        VStack(spacing: 0) {
            Spacer()
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Stage.faintText, style: StrokeStyle(lineWidth: 1.2, dash: [7, 6]))
                .frame(width: 210, height: 210 / MarsTicketFace.aspect)
                .overlay {
                    Image(systemName: "camera.on.rectangle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Stage.faintText)
                }
                .padding(.bottom, 36)

            Text(camera.availability == .denied ? "カメラへのアクセスが必要です" : "このデバイスにカメラがありません")
                .font(Typo.mincho(17))
                .tracking(2)
                .foregroundStyle(Stage.text)
                .padding(.bottom, 10)
            Text("写真から切符を読み込めます")
                .font(Typo.gothic(12))
                .foregroundStyle(Stage.faintText)

            Spacer()

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("写真から選ぶ")
                    .font(Typo.gothic(14, bold: true))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .glassEffect(.regular.tint(Ink.shu).interactive(), in: .capsule)
            .accessibilityIdentifier("capture-library")
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }

    // MARK: Acquisition

    private func shutter() {
        guard !shutterBusy else { return }
        shutterBusy = true
        Haptic.play(.punch)
        withAnimation(.linear(duration: 0.05)) { flash = 0.9 }
        withAnimation(.easeOut(duration: 0.55).delay(0.07)) { flash = 0 }
        Task {
            defer { shutterBusy = false }
            guard let photo = try? await camera.capturePhoto() else {
                // The hardware blinked — reopen the room and re-arm.
                withAnimation(.easeOut(duration: 0.3)) { frozenStill = nil }
                autoArmed = true
                return
            }
            frozenStill = photo
            await acquired(photo)
        }
    }

    private func importPicked(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        pickerItem = nil
        await acquired(image)
    }

    private func acquired(_ photo: UIImage) async {
        camera.stop()
        // Bake EXIF rotation into pixels first — every Vision stage
        // downstream must see the photo the way the user saw it.
        let image = TicketRecognizer.normalized(photo)
        original = image
        let result = await TicketRecognizer.flatten(image)
        let flattened = result.image
        scan = flattened
        quad = result.quad
        cutout = nil
        draft = Ticket() // fresh seed — the gate's punch is forever
        ocrTask = Task.detached(priority: .userInitiated) {
            (try? await TicketRecognizer.recognizeLines(in: flattened)) ?? []
        }
        // A tight scan IS the ticket; otherwise lift the subject off its
        // background while the gate ceremony plays.
        cutoutTask = result.tight ? nil : Task.detached(priority: .userInitiated) {
            await TicketRecognizer.liftSubject(flattened)
        }
        // Warm the gazetteer off-main while the gate plays.
        Task.detached(priority: .utility) { _ = StationIndex.shared }
        // Explicit animation — switch-branch transitions must run on BOTH
        // sides; an implicit container animation drops the removal.
        withAnimation(.easeInOut(duration: 0.45)) {
            phase = .gate
        }
    }

    /// The user redrew the cut — their word is law: re-crop with zero
    /// inset, drop any cutout, and re-read. Fresh OCR fills only fields
    /// they haven't already set by hand.
    private func applyManualQuad(_ newQuad: TicketQuad) {
        guard let original else { return }
        showQuadEditor = false
        quad = newQuad
        Task {
            let recropped = await Task.detached(priority: .userInitiated) {
                TicketRecognizer.applyQuad(original, quad: newQuad, inset: 0)
            }.value
            guard let recropped else { return }
            let righted = await TicketRecognizer.rightSideUp(recropped, expectTicket: true)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                scan = righted
                cutout = nil
            }
            let lines = await Task.detached(priority: .userInitiated) {
                (try? await TicketRecognizer.recognizeLines(in: righted)) ?? []
            }.value
            let fresh = TicketTextParser.parse(ocrLines: lines)
            mergeFillingEmpty(from: fresh)
        }
    }

    private func mergeFillingEmpty(from fresh: Ticket) {
        if draft.fromStation.isEmpty { draft.fromStation = fresh.fromStation }
        if draft.toStation.isEmpty { draft.toStation = fresh.toStation }
        if draft.travelDate == nil { draft.travelDate = fresh.travelDate }
        if draft.price == nil { draft.price = fresh.price }
        if draft.trainName == nil { draft.trainName = fresh.trainName }
        if draft.seat == nil { draft.seat = fresh.seat }
        if draft.brand == .other { draft.brand = fresh.brand }
    }

    // MARK: Gate → confirm

    private func finishGate() {
        Task {
            let lines = await ocrTask?.value ?? []
            cutout = await cutoutTask?.value
            var parsed = TicketTextParser.parse(ocrLines: lines)
            parsed.styleSeed = draft.styleSeed
            parsed.id = draft.id
            draft = parsed
            // The gate parked the ticket where the reveal shows it — this
            // crossfade is the handoff, so both sides must actually fade.
            withAnimation(.easeInOut(duration: 0.45)) {
                phase = .confirm
            }
        }
    }

    // MARK: Outcomes

    /// Lights up, then hand the window back with no system slide — leaving
    /// the gate is the room brightening onto the page, not a card falling.
    private func close(after work: (() -> Void)? = nil) {
        camera.stop()
        withAnimation(.easeOut(duration: 0.30)) { roomLit = false }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            work?()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { dismiss() }
        }
    }

    private func save() {
        // Add first — the shelf beneath jumps to the fresh slot while the
        // cover still hides it, so the lift has a stable place to land.
        store.add(draft, photo: scan, cutout: cutout)
        camera.stop()
        // The desk withdraws; the ticket holds its seat for the handoff.
        withAnimation(.spring(response: 0.46, dampingFraction: 0.9)) { saving = true }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard let saved = store.tickets.first(where: { $0.id == draft.id }),
                  let lift else {
                withAnimation(.easeOut(duration: 0.30)) { roomLit = false }
                try? await Task.sleep(for: .milliseconds(300))
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { dismiss() }
                return
            }
            // Where the confirm seats the card right now, in window space.
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }.first?.keyWindow
            let bounds = window?.bounds ?? UIScreen.main.bounds
            let insets = window?.safeAreaInsets ?? .zero
            let safeSize = CGSize(
                width: bounds.width - insets.left - insets.right,
                height: bounds.height - insets.top - insets.bottom
            )
            let rawAspect = min(max(scan!.size.width / max(scan!.size.height, 1), 1.10), 3.20)
            let stageHeight = ConfirmStage.fitted(aspect: rawAspect, in: safeSize).height
            let cardAspect = LiftEngine.aspectSource?(saved)
                ?? TicketArtView.aspect(for: saved.kind)
            let cardWidth = min(saved.kind.isEdmondson ? 250 : 305, bounds.width - 60)
            let cardHeight = cardWidth / cardAspect
            let from = CGRect(
                x: bounds.midX - cardWidth / 2,
                y: insets.top + ConfirmStage.topPadding + stageHeight / 2 - cardHeight / 2,
                width: cardWidth,
                height: cardHeight
            )
            // The lift sails it into the book; the cover leaves silently
            // beneath the engine's identical room.
            lift.save(saved, from: from, toSlot: "t-\(saved.id)")
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { dismiss() }
        }
    }

    private func retake() {
        scan = nil
        cutout = nil
        cutoutTask = nil
        draft = Ticket()
        autoArmed = true
        frozenStill = nil
        flash = 0
        hadLock = false
        withAnimation(.easeInOut(duration: 0.4)) {
            phase = .gathering
        }
        Task { await camera.start() }
    }

    // MARK: UITest hook

    #if DEBUG
    /// `-uiTestImport <path>` — feed an image straight into the pipeline,
    /// bypassing camera/picker (deterministic end-to-end in simulator).
    private func autoImportForUITests() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-uiTestImport"),
              index + 1 < args.count,
              let image = UIImage(contentsOfFile: args[index + 1]) else { return }
        Task { await acquired(image) }
    }
    #endif
}

private struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
