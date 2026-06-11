import SwiftUI
import PhotosUI

/// The gate — full capture flow.
///
///   gathering (camera or import) → gate (改札 ceremony, OCR in
///   parallel) → confirm (reveal + edit + save)
struct CaptureFlowView: View {
    @Environment(TicketStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Image handed in from drag & drop — skips straight to the gate.
    var initialImage: UIImage?

    @State private var camera = CameraService()
    @State private var phase = Phase.gathering
    @State private var pickerItem: PhotosPickerItem?
    @State private var scan: UIImage?
    @State private var draft = Ticket()
    @State private var ocrTask: Task<[String], Never>?
    @State private var autoArmed = true
    @State private var shutterBusy = false

    enum Phase { case gathering, gate, confirm }

    var body: some View {
        ZStack {
            Ink.studio.ignoresSafeArea()

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
                    ConfirmTicketView(
                        scan: scan,
                        draft: $draft,
                        onSave: save,
                        onRetake: retake
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: phaseKey)
        .overlay(alignment: .topTrailing) {
            if phase != .confirm {
                Button {
                    dismiss()
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
            Haptic.play(.tick)
            shutter()
        }
    }

    private var phaseKey: Int {
        switch phase {
        case .gathering: 0
        case .gate: 1
        case .confirm: 2
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
            CaptureGuideOverlay(
                quad: camera.guideQuad,
                bufferAspect: camera.bufferAspect,
                steady: camera.quadSteady
            )
            .ignoresSafeArea()

            VStack {
                Text("切符を枠のなかへ")
                    .font(Typo.gothic(12, bold: true))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.top, 64)
                Spacer()
                controls
                    .padding(.bottom, 30)
            }
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
        Task {
            defer { shutterBusy = false }
            guard let photo = try? await camera.capturePhoto() else { return }
            await acquired(photo)
        }
    }

    private func importPicked(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        pickerItem = nil
        await acquired(image)
    }

    private func acquired(_ image: UIImage) async {
        camera.stop()
        let flattened = await TicketRecognizer.flatten(image)
        scan = flattened
        draft = Ticket() // fresh seed — the gate's punch is forever
        ocrTask = Task.detached(priority: .userInitiated) {
            (try? await TicketRecognizer.recognizeText(in: flattened)) ?? []
        }
        phase = .gate
    }

    // MARK: Gate → confirm

    private func finishGate() {
        Task {
            let lines = await ocrTask?.value ?? []
            var parsed = TicketTextParser.parse(lines: lines)
            parsed.styleSeed = draft.styleSeed
            parsed.id = draft.id
            draft = parsed
            phase = .confirm
        }
    }

    // MARK: Outcomes

    private func save() {
        store.add(draft, photo: scan)
        dismiss()
    }

    private func retake() {
        scan = nil
        draft = Ticket()
        autoArmed = true
        phase = .gathering
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
