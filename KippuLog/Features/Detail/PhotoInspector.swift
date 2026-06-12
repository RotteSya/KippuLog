import SwiftUI
import UIKit

/// The complete view — the stored capture, full screen, pinch to 5×,
/// double-tap to dive, drag down to put it away. Photos-grade handling
/// via a real UIScrollView.
struct PhotoInspector: View {
    let photo: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var dragOffset: CGFloat = 0
    @State private var zoomed = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .opacity(backdropOpacity)

            ZoomableImage(image: photo, zoomed: $zoomed)
                .offset(y: dragOffset)
                .scaleEffect(dismissScale)
                .ignoresSafeArea()
        }
        .simultaneousGesture(dismissDrag)
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Stage.softText)
                    .frame(width: 40, height: 40)
            }
            .glassEffect(.regular, in: .circle)
            .accessibilityIdentifier("inspector-close")
            .padding(.leading, 20)
            .padding(.top, 8)
            .opacity(dragOffset == 0 ? 1 : 0)
        }
        .statusBarHidden(true)
    }

    private var backdropOpacity: Double {
        1 - min(0.6, Double(abs(dragOffset)) / 500)
    }

    private var dismissScale: CGFloat {
        1 - min(0.12, abs(dragOffset) / 1800)
    }

    /// One-finger drag down (only while un-zoomed) slides the photo away.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard !zoomed, value.translation.height > 0 else { return }
                dragOffset = value.translation.height
            }
            .onEnded { value in
                guard !zoomed else { return }
                if value.translation.height > 130 || value.predictedEndTranslation.height > 320 {
                    Haptic.play(.tick)
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

/// UIScrollView-backed zoom: pinch 1–5×, double-tap to toggle 2.6× at the
/// tapped point, content stays centered at every scale. Layout rides
/// `layoutSubviews` so the fit is correct from the first frame.
private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    @Binding var zoomed: Bool

    func makeUIView(context: Context) -> LayoutAwareScrollView {
        let scrollView = LayoutAwareScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        scrollView.bouncesZoom = true

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        scrollView.onLayout = { [weak scrollView, coordinator = context.coordinator] in
            guard let scrollView else { return }
            coordinator.layout(scrollView, bounds: scrollView.bounds.size)
        }

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: LayoutAwareScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(zoomed: $zoomed)
    }

    final class LayoutAwareScrollView: UIScrollView {
        var onLayout: (() -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onLayout?()
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        private var lastLaidOutSize: CGSize = .zero
        private let zoomed: Binding<Bool>

        init(zoomed: Binding<Bool>) {
            self.zoomed = zoomed
        }

        func layout(_ scrollView: UIScrollView, bounds: CGSize) {
            guard let imageView, bounds != .zero, bounds != lastLaidOutSize else { return }
            lastLaidOutSize = bounds
            scrollView.zoomScale = 1
            // Fit the image inside the bounds.
            guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else { return }
            let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
            let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            imageView.frame = CGRect(origin: .zero, size: fitted)
            scrollView.contentSize = fitted
            center(scrollView)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            center(scrollView)
            zoomed.wrappedValue = scrollView.zoomScale > 1.01
        }

        /// Keep the image centered when smaller than the viewport.
        private func center(_ scrollView: UIScrollView) {
            let bounds = scrollView.bounds.size
            let content = scrollView.contentSize
            let insetX = max(0, (bounds.width - content.width) / 2)
            let insetY = max(0, (bounds.height - content.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView, let imageView else { return }
            if scrollView.zoomScale > 1.01 {
                scrollView.setZoomScale(1, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let scale: CGFloat = 2.6
                let size = CGSize(
                    width: scrollView.bounds.width / scale,
                    height: scrollView.bounds.height / scale
                )
                let rect = CGRect(
                    origin: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2),
                    size: size
                )
                scrollView.zoom(to: rect, animated: true)
            }
        }
    }
}
