import Vision
import UIKit
import CoreImage

/// One recognized line of text with its place on the ticket. The box is in
/// Vision's normalized space (origin bottom-left, y up).
nonisolated struct OCRLine: Sendable {
    let text: String
    let box: CGRect

    var midY: CGFloat { box.midY }
    var minX: CGFloat { box.minX }
    var height: CGFloat { box.height }
    var area: CGFloat { box.width * box.height }
}

/// Vision front-end: reads the ticket's text (with geometry) and finds its
/// outline. Everything here is off-main and stateless.
nonisolated enum TicketRecognizer {
    /// Recognized lines with bounding boxes, top-to-bottom as printed.
    static func recognizeLines(in image: UIImage) async throws -> [OCRLine] {
        guard let cgImage = image.cgImage else { return [] }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [
            Locale.Language(identifier: "ja-JP"),
            Locale.Language(identifier: "en-US"),
        ]
        request.usesLanguageCorrection = true
        let observations = try await request.perform(on: cgImage)
        return observations
            .compactMap { observation -> OCRLine? in
                guard let candidate = observation.topCandidates(1).first?.string else { return nil }
                return OCRLine(text: candidate, box: observation.boundingBox.cgRect)
            }
            .sorted { $0.midY > $1.midY }   // top of the image first
    }

    /// Recognized text lines, top-to-bottom — convenience for the field
    /// parsers that don't need geometry.
    static func recognizeText(in image: UIImage) async throws -> [String] {
        try await recognizeLines(in: image).map(\.text)
    }

    /// Best ticket rectangle in the frame, if any.
    ///
    /// A photographed ticket usually casts a soft shadow that detection
    /// reads as a *second*, slightly larger rectangle at equal confidence —
    /// taking it would bake a dark halo into the crop. So gather several
    /// candidates and peel the halos: whenever a candidate sits inside the
    /// current best and still covers most of it, it is the object inside
    /// its own shadow — prefer it.
    static func detectQuad(in image: UIImage) async -> RectangleObservation? {
        guard let cgImage = image.cgImage else { return nil }
        var request = DetectRectanglesRequest()
        request.maximumObservations = 5
        request.minimumAspectRatio = 0.30   // tolerate both orientations
        request.maximumAspectRatio = 0.95
        request.minimumSize = 0.12
        request.minimumConfidence = 0.50
        let observations = (try? await request.perform(on: cgImage)) ?? []
        return bestQuad(observations)
    }

    static func bestQuad(_ candidates: [RectangleObservation]) -> RectangleObservation? {
        func area(_ o: RectangleObservation) -> CGFloat {
            o.boundingBox.cgRect.width * o.boundingBox.cgRect.height
        }
        guard var best = candidates.max(by: { area($0) < area($1) }) else { return nil }
        while true {
            let bestRect = best.boundingBox.cgRect.insetBy(dx: -0.01, dy: -0.01)
            let nested = candidates.filter {
                bestRect.contains($0.boundingBox.cgRect)
                    && area($0) >= area(best) * 0.55
                    && area($0) < area(best) * 0.985
            }
            guard let tighter = nested.min(by: { area($0) < area($1) }) else { break }
            best = tighter
        }
        return best
    }

    /// Perspective-corrects the photographed ticket to a flat scan.
    /// `tight` reports whether a quad was found — a tight scan IS the
    /// ticket (borderless); a loose one still carries background and
    /// should go through `liftSubject`.
    static func flatten(_ image: UIImage) async -> (image: UIImage, tight: Bool) {
        guard let quad = await detectQuad(in: image),
              let cgImage = image.cgImage else { return (image, false) }

        let ciImage = CIImage(cgImage: cgImage)
        let size = ciImage.extent.size

        // Scanner-style over-crop: pull every corner 1.2% toward the quad's
        // centre so no sliver of background or shadow survives the cut.
        let corners = [quad.topLeft, quad.topRight, quad.bottomLeft, quad.bottomRight]
            .map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let centroid = CGPoint(
            x: corners.map(\.x).reduce(0, +) / 4,
            y: corners.map(\.y).reduce(0, +) / 4
        )
        func inset(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x + (centroid.x - p.x) * 0.012,
                    y: p.y + (centroid.y - p.y) * 0.012)
        }

        let filter = CIFilter(name: "CIPerspectiveCorrection")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: inset(corners[0])), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: inset(corners[1])), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: inset(corners[2])), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: inset(corners[3])), forKey: "inputBottomRight")

        guard let output = filter.outputImage else { return (image, false) }
        let context = CIContext()
        guard let corrected = context.createCGImage(output, from: output.extent) else {
            return (image, false)
        }
        return (UIImage(cgImage: corrected), true)
    }

    /// Lifts the ticket off its background — Photos-style subject
    /// segmentation. Returns the ticket alone, alpha-masked and cropped to
    /// its own extent, or nil when no clean subject is found. This is what
    /// lets a ticket lie on the page as an *object* instead of living
    /// inside a rectangle of background.
    static func liftSubject(_ image: UIImage) async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              !observation.allInstances.isEmpty
        else { return nil }

        guard let buffer = try? observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        ) else { return nil }

        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext()
        guard let cutout = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        // Sanity: a believable ticket cutout occupies a real share of the
        // frame and isn't a sliver. Otherwise trust the plain photo.
        let area = ciImage.extent.width * ciImage.extent.height
        let frameArea = CGFloat(cgImage.width * cgImage.height)
        guard area > frameArea * 0.04 else { return nil }
        let aspect = ciImage.extent.width / max(ciImage.extent.height, 1)
        guard (0.5...4.0).contains(aspect) else { return nil }

        return UIImage(cgImage: cutout)
    }
}
