import Testing
import SwiftUI
@testable import KippuLog

/// End-to-end: render a ticket to an image, then run it back through the
/// *real* Vision OCR + RouteDetector + gazetteer. The rendered plate draws
/// its route arrow as a vector shape (no arrow glyph for OCR to find), so
/// this genuinely exercises the geometry/whitespace station-pairing path.
@MainActor
struct RecognitionIntegrationTests {
    @Test func readsRenderedShinkansenPlate() async throws {
        let ticket = Ticket.samples[1] // 東京 → 京都, のぞみ
        let image = try render(ticket)

        let lines = (try? await TicketRecognizer.recognizeLines(in: image)) ?? []
        #expect(!lines.isEmpty)

        let parsed = TicketTextParser.parse(ocrLines: lines)
        #expect(parsed.fromStation == "東京")
        #expect(parsed.toStation == "京都")
    }

    @Test func readsRenderedEntrancePlate() async throws {
        let ticket = Ticket.samples[5] // 尾道 入場券
        let image = try render(ticket)

        let lines = (try? await TicketRecognizer.recognizeLines(in: image)) ?? []
        let parsed = TicketTextParser.parse(ocrLines: lines)
        #expect(parsed.fromStation == "尾道")
    }

    // MARK: helpers

    private func render(_ ticket: Ticket) throws -> UIImage {
        let aspect = TicketArtView.aspect(for: ticket.kind)
        let width: CGFloat = 760
        let renderer = ImageRenderer(
            content: TicketArtView(ticket: ticket)
                .frame(width: width, height: width / aspect)
        )
        renderer.scale = 2
        guard let image = renderer.uiImage else {
            throw CocoaError(.fileWriteUnknown)
        }
        return image
    }
}
