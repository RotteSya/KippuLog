import SwiftUI
import UIKit

/// The collection. Tickets persist as one small JSON file plus original
/// photos on disk — no database, nothing to migrate, everything inspectable.
@Observable
final class TicketStore {
    /// Newest journey first.
    private(set) var tickets: [Ticket] = []
    private(set) var isLoaded = false
    /// Transient: the ticket just punched in (drives the shelf highlight).
    private(set) var lastAddedID: UUID?

    /// First run only — the opening ceremony hasn't played yet.
    private(set) var needsWelcome = false
    /// What the ceremony's exit asked the timeline to do.
    enum WelcomeFollowUp { case settle, capture }
    var welcomeFollowUp: WelcomeFollowUp?

    private let directory: URL
    private let photosDirectory: URL
    private let thumbsDirectory: URL
    private var fileURL: URL { directory.appendingPathComponent("tickets.json") }

    private static let welcomedKey = "hasWelcomed"

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("KippuLog", isDirectory: true)
        photosDirectory = directory.appendingPathComponent("photos", isDirectory: true)
        thumbsDirectory = directory.appendingPathComponent("thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbsDirectory, withIntermediateDirectories: true)

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestReset") {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: photosDirectory)
            try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            // Walk tests start on the shelf; the ceremony is its own test.
            UserDefaults.standard.set(true, forKey: Self.welcomedKey)
        }
        load()
        if arguments.contains("-uiTestSeedSamples"), tickets.isEmpty {
            addSamples()
        }
        if arguments.contains("-uiTestWelcome") {
            UserDefaults.standard.removeObject(forKey: Self.welcomedKey)
        }
        needsWelcome = !UserDefaults.standard.bool(forKey: Self.welcomedKey)
    }

    /// The opening ceremony finished (or was skipped).
    func completeWelcome(followUp: WelcomeFollowUp) {
        UserDefaults.standard.set(true, forKey: Self.welcomedKey)
        needsWelcome = false
        welcomeFollowUp = followUp
    }

    // MARK: Mutations

    func add(_ ticket: Ticket, photo: UIImage? = nil, cutout: UIImage? = nil) {
        var ticket = ticket
        if let photo {
            ticket.photoFileName = savePhoto(photo, id: ticket.id)
            if photo.size.height > 0 {
                ticket.photoAspect = photo.size.width / photo.size.height
            }
        }
        if let cutout {
            ticket.cutoutFileName = saveCutout(cutout, id: ticket.id)
        }
        tickets.append(ticket)
        sortAndSave()
        lastAddedID = ticket.id
    }

    func update(_ ticket: Ticket) {
        guard let index = tickets.firstIndex(where: { $0.id == ticket.id }) else { return }
        tickets[index] = ticket
        sortAndSave()
    }

    func remove(_ ticket: Ticket) {
        tickets.removeAll { $0.id == ticket.id }
        for name in [ticket.photoFileName, ticket.cutoutFileName].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: photosDirectory.appendingPathComponent(name))
            try? FileManager.default.removeItem(at: thumbsDirectory.appendingPathComponent("thumb-" + name))
            imageCache.removeObject(forKey: name as NSString)
            imageCache.removeObject(forKey: ("thumb-" + name) as NSString)
        }
        save()
    }

    func addSamples() {
        tickets.append(contentsOf: Ticket.samples)
        sortAndSave()
    }

    /// The specimen journeys are on the shelf.
    var hasSamples: Bool {
        tickets.contains { $0.isSample }
    }

    /// 見本を片付ける — the sample journeys leave; the user's own remain.
    func removeSamples() {
        tickets.removeAll { $0.isSample }
        save()
    }

    /// 開幕をもう一度 — replay the opening ceremony once, on request.
    func replayWelcome() {
        needsWelcome = true
    }

    // MARK: Photos

    private let imageCache = NSCache<NSString, UIImage>()

    func photo(for ticket: Ticket) -> UIImage? {
        loadImage(named: ticket.photoFileName)
    }

    /// The subject-lifted ticket object, when one was produced at capture.
    func cutout(for ticket: Ticket) -> UIImage? {
        loadImage(named: ticket.cutoutFileName)
    }

    /// Album-sized image (≤420px), generated lazily and kept on disk —
    /// dozens of minis must scroll like silk. Nil → render the plate live.
    func thumbnail(for ticket: Ticket) -> UIImage? {
        let isCutout = ticket.cutoutFileName != nil
        guard let sourceName = ticket.cutoutFileName ?? ticket.photoFileName else { return nil }
        let thumbName = "thumb-" + sourceName
        if let cached = imageCache.object(forKey: thumbName as NSString) { return cached }
        let url = thumbsDirectory.appendingPathComponent(thumbName)
        if let onDisk = UIImage(contentsOfFile: url.path) {
            imageCache.setObject(onDisk, forKey: thumbName as NSString)
            return onDisk
        }
        guard let full = isCutout ? cutout(for: ticket) : photo(for: ticket) else { return nil }
        let thumb = Self.downscaled(full, maxDimension: 420)
        // Cutouts carry alpha — PNG; plain scans stay JPEG.
        let data = isCutout ? thumb.pngData() : thumb.jpegData(compressionQuality: 0.85)
        try? data?.write(to: url, options: .atomic)
        imageCache.setObject(thumb, forKey: thumbName as NSString)
        return thumb
    }

    private func loadImage(named name: String?) -> UIImage? {
        guard let name else { return nil }
        if let cached = imageCache.object(forKey: name as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: photosDirectory.appendingPathComponent(name).path) else {
            return nil
        }
        imageCache.setObject(image, forKey: name as NSString)
        return image
    }

    private func savePhoto(_ image: UIImage, id: UUID) -> String? {
        let sized = Self.downscaled(image, maxDimension: 2400)
        guard let data = sized.jpegData(compressionQuality: 0.9) else { return nil }
        let name = "\(id.uuidString).jpg"
        do {
            try data.write(to: photosDirectory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    private func saveCutout(_ image: UIImage, id: UUID) -> String? {
        let sized = Self.downscaled(image, maxDimension: 1600)
        guard let data = sized.pngData() else { return nil }
        let name = "\(id.uuidString)-cut.png"
        do {
            try data.write(to: photosDirectory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    /// Keep stored images at display resolution — decode stays cheap and
    /// the timeline scrolls like silk.
    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension, largest > 0 else { return image }
        let scale = maxDimension / largest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: Persistence

    private func load() {
        defer { isLoaded = true }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([Ticket].self, from: data) {
            tickets = decoded.sorted { $0.sortDate > $1.sortDate }
        }
    }

    private func sortAndSave() {
        tickets.sort { $0.sortDate > $1.sortDate }
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(tickets) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: Derived

    var totalSpent: Int {
        tickets.compactMap(\.price).reduce(0, +)
    }

    /// Chronological catalogue numbers — the oldest journey is No. 001.
    /// One numbering shared by the magazine's entries and the stage's
    /// placard.
    var catalogNumbers: [UUID: Int] {
        let ascending = tickets.sorted { $0.sortDate < $1.sortDate }
        return Dictionary(uniqueKeysWithValues: ascending.enumerated().map { ($1.id, $0 + 1) })
    }

    /// Tickets grouped year → month, newest first — the album's spreads.
    var yearGroups: [(year: Int, months: [(month: DateComponents, tickets: [Ticket])])] {
        let calendar = Calendar(identifier: .gregorian)
        let byYear = Dictionary(grouping: tickets) { calendar.component(.year, from: $0.sortDate) }
        return byYear
            .sorted { $0.key > $1.key }
            .map { year, yearTickets in
                let byMonth = Dictionary(grouping: yearTickets) {
                    calendar.dateComponents([.year, .month], from: $0.sortDate)
                }
                let months = byMonth
                    .sorted { ($0.key.month ?? 0) > ($1.key.month ?? 0) }
                    .map { (month: $0.key, tickets: $0.value.sorted { $0.sortDate > $1.sortDate }) }
                return (year: year, months: months)
            }
    }

    /// Tickets grouped by month of travel, newest month first.
    var monthGroups: [(month: DateComponents, tickets: [Ticket])] {
        let calendar = Calendar(identifier: .gregorian)
        let grouped = Dictionary(grouping: tickets) { ticket in
            calendar.dateComponents([.year, .month], from: ticket.sortDate)
        }
        return grouped
            .sorted { lhs, rhs in
                (lhs.key.year ?? 0, lhs.key.month ?? 0) > (rhs.key.year ?? 0, rhs.key.month ?? 0)
            }
            .map { (month: $0.key, tickets: $0.value.sorted { $0.sortDate > $1.sortDate }) }
    }
}
