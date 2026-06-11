import SwiftUI
import UIKit

/// The collection. Tickets persist as one small JSON file plus original
/// photos on disk — no database, nothing to migrate, everything inspectable.
@Observable
final class TicketStore {
    /// Newest journey first.
    private(set) var tickets: [Ticket] = []
    private(set) var isLoaded = false

    private let directory: URL
    private let photosDirectory: URL
    private var fileURL: URL { directory.appendingPathComponent("tickets.json") }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("KippuLog", isDirectory: true)
        photosDirectory = directory.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestReset") {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: photosDirectory)
            try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        }
        load()
        if arguments.contains("-uiTestSeedSamples"), tickets.isEmpty {
            addSamples()
        }
    }

    // MARK: Mutations

    func add(_ ticket: Ticket, photo: UIImage? = nil) {
        var ticket = ticket
        if let photo {
            ticket.photoFileName = savePhoto(photo, id: ticket.id)
        }
        tickets.append(ticket)
        sortAndSave()
    }

    func update(_ ticket: Ticket) {
        guard let index = tickets.firstIndex(where: { $0.id == ticket.id }) else { return }
        tickets[index] = ticket
        sortAndSave()
    }

    func remove(_ ticket: Ticket) {
        tickets.removeAll { $0.id == ticket.id }
        if let name = ticket.photoFileName {
            try? FileManager.default.removeItem(at: photosDirectory.appendingPathComponent(name))
        }
        save()
    }

    func addSamples() {
        tickets.append(contentsOf: Ticket.samples)
        sortAndSave()
    }

    // MARK: Photos

    func photo(for ticket: Ticket) -> UIImage? {
        guard let name = ticket.photoFileName else { return nil }
        return UIImage(contentsOfFile: photosDirectory.appendingPathComponent(name).path)
    }

    private func savePhoto(_ image: UIImage, id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        let name = "\(id.uuidString).jpg"
        do {
            try data.write(to: photosDirectory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
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
