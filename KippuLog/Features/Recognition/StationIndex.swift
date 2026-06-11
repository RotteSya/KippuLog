import Foundation

/// The station gazetteer — 8,400+ Japanese station names bundled as a flat
/// list (see `scripts/build_stations.swift`). Used to validate OCR route
/// candidates and to *snap* near-misses back to a real name
/// (e.g. 柬京 → 東京), which is what makes 発駅/着駅 detection reliable.
///
/// Immutable after load, so it is safe to read from any thread. Warm it
/// off-main at capture start; the first access otherwise pays a one-time
/// ~few-ms file read.
nonisolated final class StationIndex: Sendable {
    static let shared = StationIndex()

    private let exact: Set<String>
    /// Names bucketed by character count, for pruned edit-distance search.
    private let byLength: [Int: [[Character]]]

    init() {
        let names = Self.loadNames()
        exact = Set(names)
        var buckets: [Int: [[Character]]] = [:]
        for name in names {
            buckets[name.count, default: []].append(Array(name))
        }
        byLength = buckets
    }

    // MARK: Public

    /// True if `name` is a real station (after cleaning) or a fare-zone label.
    func isStation(_ name: String) -> Bool {
        snap(name) != nil
    }

    /// Resolve a raw OCR token to a canonical station name, or nil.
    ///
    /// - Strips a trailing 駅, zone prefixes like `(都)`, and inner spaces.
    /// - Fare-zone labels (◯◯市内 / ◯◯区内 / 都区内) are accepted verbatim —
    ///   they are legitimate ticket endpoints but never appear in a station DB.
    /// - Exact hit wins; otherwise the nearest name within edit-distance 1
    ///   that shares a first or last character (guards against wild snaps).
    func snap(_ raw: String) -> String? {
        let cleaned = Self.clean(raw)
        guard (1...12).contains(cleaned.count) else { return nil }
        if Self.isZoneLabel(cleaned) { return cleaned }
        if exact.contains(cleaned) { return cleaned }
        // A single character has too many edit-distance-1 neighbours to snap
        // safely (場 → 馬場, 券 → …); require an exact hit for length 1.
        guard cleaned.count >= 2 else { return nil }

        let target = Array(cleaned)
        var best: String?
        for len in (cleaned.count - 1)...(cleaned.count + 1) {
            for candidate in byLength[len] ?? [] {
                guard candidate.first == target.first || candidate.last == target.last else { continue }
                if Self.isEditDistanceAtMostOne(target, candidate) {
                    // Prefer an equal-length (single substitution) match.
                    if candidate.count == target.count { return String(candidate) }
                    if best == nil { best = String(candidate) }
                }
            }
        }
        return best
    }

    // MARK: Cleaning

    private static let zonePrefixes = ["(都)", "(区)", "(阪)", "(神)", "(名)", "(京)", "(福)", "(広)", "(仙)", "(札)", "(横)", "（都）", "（区）"]

    static func clean(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        for prefix in zonePrefixes where s.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
        }
        s = s.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
        // Strip a trailing 駅 (but not from one-character names).
        if s.count > 1, s.hasSuffix("駅") {
            s = String(s.dropLast())
        }
        return s
    }

    static func isZoneLabel(_ s: String) -> Bool {
        s.hasSuffix("市内") || s.hasSuffix("区内") || s.hasSuffix("都区内")
    }

    // MARK: Edit distance (capped at 1)

    static func isEditDistanceAtMostOne(_ a: [Character], _ b: [Character]) -> Bool {
        let la = a.count, lb = b.count
        if abs(la - lb) > 1 { return false }
        if la == lb {
            var diff = 0
            for i in 0..<la where a[i] != b[i] {
                diff += 1
                if diff > 1 { return false }
            }
            return true
        }
        // Lengths differ by one: allow a single insertion/deletion.
        let (short, long) = la < lb ? (a, b) : (b, a)
        var i = 0, j = 0
        var skipped = false
        while i < short.count, j < long.count {
            if short[i] == long[j] {
                i += 1; j += 1
            } else {
                if skipped { return false }
                skipped = true
                j += 1
            }
        }
        return true
    }

    // MARK: Loading

    private static func loadNames() -> [String] {
        // Bundle(for:) resolves the app module's bundle even under a test host,
        // where Bundle.main is the test runner.
        let bundle = Bundle(for: StationIndex.self)
        let url = bundle.url(forResource: "stations", withExtension: "json")
            ?? Bundle.main.url(forResource: "stations", withExtension: "json")
        guard let url,
              let data = try? Data(contentsOf: url),
              let names = try? JSONDecoder().decode([String].self, from: data)
        else {
            assertionFailure("stations.json missing from bundle")
            return []
        }
        return names
    }
}
