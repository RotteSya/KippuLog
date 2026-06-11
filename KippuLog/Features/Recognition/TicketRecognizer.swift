import Vision
import UIKit
import CoreImage

/// Vision front-end: reads the ticket's text and finds its outline.
/// Everything here is off-main and stateless.
nonisolated enum TicketRecognizer {
    /// Recognized text lines, top-to-bottom as printed.
    static func recognizeText(in image: UIImage) async throws -> [String] {
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
            .sorted { $0.boundingBox.cgRect.midY > $1.boundingBox.cgRect.midY }
            .compactMap { $0.topCandidates(1).first?.string }
    }

    /// Strongest rectangle in the frame (normalized corners), if any.
    static func detectQuad(in image: UIImage) async -> RectangleObservation? {
        guard let cgImage = image.cgImage else { return nil }
        var request = DetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumAspectRatio = 0.45   // edmondson cards are wide
        request.maximumAspectRatio = 0.95
        request.minimumSize = 0.18
        request.minimumConfidence = 0.55
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
