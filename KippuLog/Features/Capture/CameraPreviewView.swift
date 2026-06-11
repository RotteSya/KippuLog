import SwiftUI
import AVFoundation

/// AVCaptureVideoPreviewLayer wrapper.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewHost {
        let view = PreviewHost()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewHost, context: Context) {}

    final class PreviewHost: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// The breathing guide frame + detected-quad glow over the camera.
struct CaptureGuideOverlay: View {
    /// Normalized (top-left origin) quad in buffer space, if detected.
    var quad: [CGPoint]?
    /// Portrait buffer aspect (w/h) for aspect-fill mapping.
    var bufferAspect: CGFloat
    var steady: Bool

    @State private var breathe = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                // Dim everything but a ticket-shaped window.
                let window = guideRect(in: size)
                Canvas { context, _ in
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.52)))
                    context.blendMode = .destinationOut
                    context.fill(
                        Path(roundedRect: window, cornerRadius: 10),
                        with: .color(.white)
                    )
                }
                .allowsHitTesting(false)

                // Corner ticks on the window.
                CornerTicks(rect: window)
                    .stroke(Color.white.opacity(breathe ? 0.95 : 0.55), lineWidth: 2.2)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: breathe)

                // Detected ticket glow.
                if let quad, quad.count == 4 {
                    QuadShape(points: quad.map { mapToLayer($0, layer: size) })
                        .stroke(
                            steady ? Ink.shu : Color.white.opacity(0.85),
                            style: StrokeStyle(lineWidth: steady ? 3 : 2, lineJoin: .round)
                        )
                        .shadow(color: steady ? Ink.shu.opacity(0.8) : .white.opacity(0.4), radius: 8)
                        .animation(.easeOut(duration: 0.18), value: steady)
                }
            }
            .onAppear { breathe = true }
        }
        .allowsHitTesting(false)
    }

    /// Centered MARS-proportioned window.
    private func guideRect(in size: CGSize) -> CGRect {
        let width = size.width * 0.84
        let height = width / MarsTicketFace.aspect
        return CGRect(
            x: (size.width - width) / 2,
            y: size.height * 0.42 - height / 2,
            width: width,
            height: height
        )
    }

    /// Normalized buffer point → layer point under aspect-fill.
    private func mapToLayer(_ p: CGPoint, layer: CGSize) -> CGPoint {
        let layerAspect = layer.width / layer.height
        var displayWidth = layer.width
        var displayHeight = layer.height
        if bufferAspect > layerAspect {
            displayWidth = layer.height * bufferAspect
        } else {
            displayHeight = layer.width / bufferAspect
        }
        let offsetX = (layer.width - displayWidth) / 2
        let offsetY = (layer.height - displayHeight) / 2
        return CGPoint(x: offsetX + p.x * displayWidth, y: offsetY + p.y * displayHeight)
    }
}

private nonisolated struct QuadShape: Shape {
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count == 4 else { return path }
        path.move(to: points[0])
        for p in points.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}

/// Four open corners, like a viewfinder.
private nonisolated struct CornerTicks: Shape {
    var rect: CGRect

    func path(in _: CGRect) -> Path {
        var path = Path()
        let len: CGFloat = 26
        let r = rect
        // TL
        path.move(to: CGPoint(x: r.minX, y: r.minY + len))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.minX + len, y: r.minY))
        // TR
        path.move(to: CGPoint(x: r.maxX - len, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + len))
        // BR
        path.move(to: CGPoint(x: r.maxX, y: r.maxY - len))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.maxX - len, y: r.maxY))
        // BL
        path.move(to: CGPoint(x: r.minX + len, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - len))
        return path
    }
}
