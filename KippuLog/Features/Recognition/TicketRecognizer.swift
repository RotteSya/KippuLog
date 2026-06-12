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

/// A ticket's outline in an image — normalized coordinates, top-left
/// origin (UIKit-friendly, ready for the corner editor).
nonisolated struct TicketQuad: Sendable, Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomLeft: CGPoint
    var bottomRight: CGPoint

    init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    /// From Vision (bottom-left origin) into top-left origin.
    init(observation o: RectangleObservation) {
        func flip(_ p: NormalizedPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }
        topLeft = flip(o.topLeft)
        topRight = flip(o.topRight)
        bottomLeft = flip(o.bottomLeft)
        bottomRight = flip(o.bottomRight)
    }

    /// A gentle default when nothing was detected: an 8%-inset frame.
    static let fallback = TicketQuad(
        topLeft: CGPoint(x: 0.08, y: 0.08),
        topRight: CGPoint(x: 0.92, y: 0.08),
        bottomLeft: CGPoint(x: 0.08, y: 0.92),
        bottomRight: CGPoint(x: 0.92, y: 0.92)
    )
}

/// What `flatten` hands back: the scan, whether a quad was found, and the
/// first-pass quad in original-image space (for the manual editor).
nonisolated struct FlattenResult: Sendable {
    let image: UIImage
    let tight: Bool
    let quad: TicketQuad?
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
    /// Collector photos (think Mercari listings) are hostile: the ticket
    /// casts a shadow that reads as a *second* equal-confidence rectangle,
    /// and set photos contain several tickets at once. Strategy: take the
    /// dominant candidate (area, then centrality among near-equals), then
    /// peel shadow halos — any candidate nested inside the pick that still
    /// covers most of it is the object inside its own shadow.
    static func detectQuad(in image: UIImage) async -> RectangleObservation? {
        guard let cgImage = image.cgImage else { return nil }
        var request = DetectRectanglesRequest()
        request.maximumObservations = 8
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
        func centerDistance(_ o: RectangleObservation) -> CGFloat {
            let r = o.boundingBox.cgRect
            return hypot(r.midX - 0.5, r.midY - 0.5)
        }
        guard let largest = candidates.max(by: { area($0) < area($1) }) else { return nil }
        // Several tickets in one shot: among candidates of comparable size,
        // the user is photographing the one in the middle of the frame.
        var best = candidates
            .filter { area($0) >= area(largest) * 0.75 }
            .min(by: { centerDistance($0) < centerDistance($1) }) ?? largest
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

    /// Crops `image` to a quad (normalized, top-left origin) with optional
    /// scanner-style over-crop. The workhorse behind auto-flatten and the
    /// manual corner editor.
    static func applyQuad(_ image: UIImage, quad: TicketQuad, inset: CGFloat) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let size = ciImage.extent.size

        // UIKit-normalized (top-left origin) → CI pixel space (bottom-left).
        func pixel(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height)
        }
        var corners = [quad.topLeft, quad.topRight, quad.bottomLeft, quad.bottomRight].map(pixel)
        if inset > 0 {
            let centroid = CGPoint(
                x: corners.map(\.x).reduce(0, +) / 4,
                y: corners.map(\.y).reduce(0, +) / 4
            )
            corners = corners.map {
                CGPoint(x: $0.x + (centroid.x - $0.x) * inset,
                        y: $0.y + (centroid.y - $0.y) * inset)
            }
        }

        let filter = CIFilter(name: "CIPerspectiveCorrection")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: corners[0]), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: corners[1]), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: corners[2]), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: corners[3]), forKey: "inputBottomRight")

        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        guard let corrected = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: corrected)
    }

    /// Perspective-corrects the photographed ticket to a flat scan.
    ///
    /// Two passes: the detected quad cut, then a second detection on the
    /// result — an offset shadow inflates the first quad on one side only,
    /// and the residue shows up as a near-full-frame rectangle the second
    /// pass shaves off. `tight` reports whether any quad was found; `quad`
    /// (first-pass, original image space) feeds the manual corner editor.
    static func flatten(_ image: UIImage) async -> FlattenResult {
        guard let first = await detectQuad(in: image) else {
            return FlattenResult(image: image, tight: false, quad: nil)
        }
        let quad = TicketQuad(observation: first)
        guard let pass1 = applyQuad(image, quad: quad, inset: 0.012) else {
            return FlattenResult(image: image, tight: false, quad: quad)
        }

        // Second pass: shave any one-sided residue.
        if let second = await detectQuad(in: pass1) {
            let r = second.boundingBox.cgRect
            let area = r.width * r.height
            if area > 0.60, area < 0.97,
               let pass2 = applyQuad(pass1, quad: TicketQuad(observation: second), inset: 0.004) {
                return FlattenResult(image: pass2, tight: true, quad: quad)
            }
        }
        return FlattenResult(image: pass1, tight: true, quad: quad)
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
        // Solidity: a ticket fills its own bounding box. A hand, a strap or
        // a shadow blob doesn't — reject those rather than mount them.
        guard alphaCoverage(cutout) >= 0.70 else { return nil }

        return UIImage(cgImage: cutout)
    }

    /// Fraction of opaque pixels, sampled at 48×48.
    static func alphaCoverage(_ image: CGImage) -> CGFloat {
        let side = 48
        guard let context = CGContext(
            data: nil, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 1 }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data else { return 1 }
        let pixels = data.bindMemory(to: UInt8.self, capacity: side * side * 4)
        var opaque = 0
        for i in 0..<(side * side) where pixels[i * 4 + 3] > 100 {
            opaque += 1
        }
        return CGFloat(opaque) / CGFloat(side * side)
    }
}
