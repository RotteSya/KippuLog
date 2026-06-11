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

    /// Strongest rectangle in the frame (normalized corners), if any.
    static func detectQuad(in image: UIImage) async -> RectangleObservation? {
        guard let cgImage = image.cgImage else { return nil }
        var request = DetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumAspectRatio = 0.30   // tolerate both orientations
        request.maximumAspectRatio = 0.95
        request.minimumSize = 0.12
        request.minimumConfidence = 0.50
        let observations = (try? await request.perform(on: cgImage)) ?? []
        return observations.first
    }

    /// Perspective-corrects the photographed ticket to a flat scan.
    /// Falls back to the original image when no quad is found.
    static func flatten(_ image: UIImage) async -> UIImage {
        guard let quad = await detectQuad(in: image),
              let cgImage = image.cgImage else { return image }

        let ciImage = CIImage(cgImage: cgImage)
        let size = ciImage.extent.size
        func point(_ p: NormalizedPoint) -> CGPoint {
            CGPoint(x: p.x * size.width, y: p.y * size.height)
        }

        let filter = CIFilter(name: "CIPerspectiveCorrection")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: point(quad.topLeft)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: point(quad.topRight)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: point(quad.bottomLeft)), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: point(quad.bottomRight)), forKey: "inputBottomRight")

        guard let output = filter.outputImage else { return image }
        let context = CIContext()
        guard let corrected = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: corrected)
    }
}
