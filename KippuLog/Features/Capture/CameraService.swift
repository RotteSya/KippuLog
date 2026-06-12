@preconcurrency import AVFoundation
import UIKit
import Vision

/// Camera session + live ticket detection. The session is configured on
/// its own queue; all published state lives on the main actor.
@Observable
final class CameraService {
    enum Availability { case unknown, ready, denied, missing }

    /// How long the quad must hold still before the gate fires on its own.
    /// The viewfinder draws this very window as the closing vermilion loop.
    static let steadyTarget: TimeInterval = 0.9

    private(set) var availability: Availability = .unknown
    /// Detected ticket quad — normalized image coords, origin top-left —
    /// plus the (portrait) buffer aspect, smoothed for the guide overlay.
    private(set) var guideQuad: [CGPoint]?
    private(set) var bufferAspect: CGFloat = 9.0 / 16.0
    /// When the quad started holding still — the viewfinder animates the
    /// countdown from this instant.
    private(set) var steadySince: Date?
    /// True once the quad has held still long enough to auto-capture.
    private(set) var quadSteady = false

    nonisolated(unsafe) let session = AVCaptureSession()
    private nonisolated let sessionQueue = DispatchQueue(label: "jp.kippulog.camera.session")
    private nonisolated let analysisQueue = DispatchQueue(label: "jp.kippulog.camera.analysis")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()

    private var videoDelegate: VideoTap?
    private var photoDelegate: PhotoTap?
    private var rawQuad: [CGPoint]?
    private var lastQuadAt: Date?

    // MARK: Lifecycle

    func start() async {
        // Already configured (e.g. coming back from a retake): the session
        // was stopped, not torn down — just run it again.
        if availability == .ready {
            nonisolated(unsafe) let session = session
            sessionQueue.async {
                if !session.isRunning { session.startRunning() }
            }
            return
        }
        guard availability == .unknown else { return }
        guard AVCaptureDevice.default(for: .video) != nil else {
            availability = .missing
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            availability = .denied
            return
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                availability = .denied
                return
            }
        default:
            break
        }
        configureAndRun()
        availability = .ready
    }

    private func configureAndRun() {
        let tap = VideoTap { [weak self] quad, aspect in
            Task { @MainActor [weak self] in
                self?.ingest(quad: quad, aspect: aspect)
            }
        }
        videoDelegate = tap
        nonisolated(unsafe) let session = session
        nonisolated(unsafe) let photoOutput = photoOutput
        nonisolated(unsafe) let videoOutput = videoOutput
        let analysisQueue = analysisQueue

        sessionQueue.async {
            session.beginConfiguration()
            session.sessionPreset = .photo
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(tap, queue: analysisQueue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            for connection in [photoOutput.connection(with: .video), videoOutput.connection(with: .video)] {
                if let connection, connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }
            session.commitConfiguration()
            session.startRunning()
        }
    }

    func stop() {
        nonisolated(unsafe) let session = session
        sessionQueue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: Capture

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let tap = PhotoTap { [weak self] result in
                Task { @MainActor [weak self] in
                    self?.photoDelegate = nil
                    continuation.resume(with: result)
                }
            }
            photoDelegate = tap
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: tap)
        }
    }

    // MARK: Quad ingestion

    private func ingest(quad: [CGPoint]?, aspect: CGFloat) {
        bufferAspect = aspect
        guard let quad else {
            // Detection flickers frame to frame; hold the last lock briefly
            // so the guide doesn't fly home over a single missed frame.
            if let lastQuadAt, Date.now.timeIntervalSince(lastQuadAt) < 0.45 {
                return
            }
            guideQuad = nil
            rawQuad = nil
            lastQuadAt = nil
            steadySince = nil
            quadSteady = false
            return
        }
        lastQuadAt = .now
        // Smooth toward the new quad for a calm guide.
        if let old = guideQuad, old.count == 4 {
            guideQuad = zip(old, quad).map { o, n in
                CGPoint(x: o.x + (n.x - o.x) * 0.38, y: o.y + (n.y - o.y) * 0.38)
            }
        } else {
            guideQuad = quad
        }
        // Steadiness: all corners within epsilon of the last raw quad.
        if let previous = rawQuad, previous.count == 4 {
            let drift = zip(previous, quad)
                .map { hypot($0.x - $1.x, $0.y - $1.y) }
                .max() ?? 1
            if drift < 0.012 {
                if let since = steadySince {
                    quadSteady = Date.now.timeIntervalSince(since) > Self.steadyTarget
                } else {
                    steadySince = .now
                }
            } else {
                steadySince = nil
                quadSteady = false
            }
        }
        rawQuad = quad
    }
}

// MARK: - Delegates

/// Frame tap: throttled rectangle detection off the main actor.
private nonisolated final class VideoTap: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let onQuad: @Sendable ([CGPoint]?, CGFloat) -> Void
    private let busy = OSAllocatedUnfairLockFlag()
    private var frameCount = 0

    init(onQuad: @escaping @Sendable ([CGPoint]?, CGFloat) -> Void) {
        self.onQuad = onQuad
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameCount += 1
        guard frameCount % 5 == 0,
              busy.tryEnter(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let aspect = CGFloat(width) / CGFloat(max(height, 1))
        nonisolated(unsafe) let buffer = pixelBuffer
        let onQuad = onQuad
        let busy = busy
        Task.detached(priority: .userInitiated) {
            defer { busy.leave() }
            var request = DetectRectanglesRequest()
            request.maximumObservations = 1
            request.minimumAspectRatio = 0.45
            request.maximumAspectRatio = 0.95
            request.minimumSize = 0.22
            request.minimumConfidence = 0.6
            let observations = (try? await request.perform(on: buffer)) ?? []
            guard let quad = observations.first else {
                onQuad(nil, aspect)
                return
            }
            // Vision: origin bottom-left → flip to top-left.
            let points = [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft]
                .map { CGPoint(x: $0.x, y: 1 - $0.y) }
            onQuad(points, aspect)
        }
    }
}

/// One-shot photo capture tap.
private nonisolated final class PhotoTap: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: @Sendable (Result<UIImage, Error>) -> Void

    init(completion: @escaping @Sendable (Result<UIImage, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        if let error {
            completion(.failure(error))
        } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            completion(.success(image))
        } else {
            completion(.failure(CocoaError(.fileReadCorruptFile)))
        }
    }
}

/// Tiny sendable try-lock for "skip frame if still analyzing".
private nonisolated final class OSAllocatedUnfairLockFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    func tryEnter() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if flag { return false }
        flag = true
        return true
    }

    func leave() {
        lock.lock()
        flag = false
        lock.unlock()
    }
}
