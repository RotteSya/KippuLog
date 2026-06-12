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
    /// - Fare-zone labels (◯◯市内 / ◯◯区内 / 都区内) are endpoints too: the
    ///   city part is itself snapped (so 東亰都区内 heals to 東京都区内).
    /// - Exact hit wins; otherwise the nearest name within edit-distance 1
    ///   (2 for names of 4+ characters — blur takes more than one glyph)
    ///   that shares a first or last character, guarding against wild snaps.
    func snap(_ raw: String) -> String? {
        let cleaned = Self.clean(raw)
        guard (1...12).contains(cleaned.count) else { return nil }
        if let zone = snapZone(cleaned) { return zone }
        return snapPlain(cleaned)
    }

    /// Strict variant — exact station or (city-healed) zone label only.
    /// Used where fuzzy matches would invite false positives (splitting a
    /// concatenated pair).
    func snapExact(_ raw: String) -> String? {
        let cleaned = Self.clean(raw)
        guard (1...12).contains(cleaned.count) else { return nil }
        if let zone = snapZone(cleaned) { return zone }
        return exact.contains(cleaned) ? cleaned : nil
    }

    private func snapPlain(_ cleaned: String) -> String? {
        if exact.contains(cleaned) { return cleaned }
        // A single character has too many edit-distance-1 neighbours to snap
        // safely (場 → 馬場, 券 → …); require an exact hit for length 1.
        guard cleaned.count >= 2 else { return nil }

        let target = Array(cleaned)
        let maxDistance = cleaned.count >= 4 ? 2 : 1
        var best: String?
        var bestRank = Int.max
        for len in (cleaned.count - maxDistance)...(cleaned.count + maxDistance) {
            for candidate in byLength[len] ?? [] {
                guard candidate.first == target.first || candidate.last == target.last else { continue }
                guard let d = Self.editDistance(target, candidate, atMost: maxDistance) else { continue }
                let rank = Self.rank(distance: d, target: target, candidate: candidate)
                if rank < bestRank {
                    bestRank = rank
                    best = String(candidate)
                    if rank == 0 { return best }
                }
            }
        }
        return best
    }

    /// Ranking: exact, then a single *visually plausible* substitution
    /// (OCR confuses lookalike glyphs, not random ones), then any single
    /// substitution, then insert/delete, then distance 2.
    private static func rank(distance: Int, target: [Character], candidate: [Character]) -> Int {
        switch distance {
        case 0: return 0
        case 1 where target.count == candidate.count:
            if let (a, b) = singleSubstitution(target, candidate), isConfusable(a, b) {
                return 1
            }
            return 2
        case 1: return 3
        default: return 6
        }
    }

    private static func singleSubstitution(_ a: [Character], _ b: [Character]) -> (Character, Character)? {
        var pair: (Character, Character)?
        for i in a.indices where a[i] != b[i] {
            guard pair == nil else { return nil }
            pair = (a[i], b[i])
        }
        return pair
    }

    /// Classic kanji/kana lookalikes that OCR actually swaps.
    private static let confusablePairs: Set<String> = {
        let pairs = [
            "京亰", "東柬", "東束", "大太", "大犬", "田由", "田甲", "日目", "日曰",
            "末未", "土士", "干千", "王玉", "人入", "口ロ", "力カ", "二ニ", "工エ",
            "戸尸", "阪坂", "崎﨑", "高髙", "浜濱", "沢澤", "井丼", "中申", "光先",
        ]
        var set = Set<String>()
        for p in pairs where p.count == 2 {
            let chars = Array(p)
            set.insert(String([chars[0], chars[1]]))
            set.insert(String([chars[1], chars[0]]))
        }
        return set
    }()

    private static func isConfusable(_ a: Character, _ b: Character) -> Bool {
        confusablePairs.contains(String([a, b]))
    }

    /// ◯◯市内 / ◯◯都区内 → heal the city part against the gazetteer and
    /// reattach the suffix. Returns nil if it isn't zone-shaped.
    private func snapZone(_ cleaned: String) -> String? {
        for suffix in ["都区内", "市内", "区内"] where cleaned.hasSuffix(suffix) {
            let city = String(cleaned.dropLast(suffix.count))
            guard (1...8).contains(city.count) else { return nil }
            if exact.contains(city) { return city + suffix }
            if city.count >= 2, let healed = snapPlain(city) { return healed + suffix }
            // Unknown city but plausibly CJK — keep verbatim (rare zones).
            let cjk = city.unicodeScalars.allSatisfy {
                (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value)
            }
            return cjk && !city.isEmpty ? cleaned : nil
        }
        return nil
    }

    /// Longest suffix of `raw` that resolves (station or zone) — for tokens
    /// like 乗車券東京 where a keyword rode along in front.
    func snapSuffix(_ raw: String) -> String? {
        let cleaned = Self.clean(raw)
        guard cleaned.count >= 2 else { return nil }
        let chars = Array(cleaned)
        let maxLen = min(chars.count, 12)
        for length in stride(from: maxLen, through: 2, by: -1) {
            let tail = String(chars.suffix(length))
            if let hit = snapExact(tail) { return hit }
        }
        return nil
    }

    /// Longest prefix of `raw` that resolves — for tokens like 京都市内ゆき.
    func snapPrefix(_ raw: String) -> String? {
        let cleaned = Self.clean(raw)
        guard cleaned.count >= 2 else { return nil }
        let chars = Array(cleaned)
        let maxLen = min(chars.count, 12)
        for length in stride(from: maxLen, through: 2, by: -1) {
            let head = String(chars.prefix(length))
            if let hit = snapExact(head) { return hit }
        }
        return nil
    }

    /// Splits a token that is two endpoints fused together (the arrow glyph
    /// vanished in OCR): 東京都区内京都市内 → (東京都区内, 京都市内).
    /// Both halves must resolve strictly; longer left halves win; a single
    /// junk character (the arrow's corpse) may be skipped at the seam.
    func splitFused(_ raw: String) -> (String, String)? {
        let cleaned = Self.clean(raw)
        let chars = Array(cleaned)
        guard (4...24).contains(chars.count) else { return nil }
        for i in stride(from: chars.count - 2, through: 2, by: -1) {
            guard let left = snapExact(String(chars.prefix(i))) else { continue }
            for skip in 0...1 where i + skip + 2 <= chars.count {
                if let right = snapExact(String(chars.suffix(chars.count - i - skip))),
                   left != right {
                    return (left, right)
                }
            }
        }
        return nil
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

    // MARK: Edit distance (bounded)

    /// Levenshtein distance if ≤ `limit`, else nil. Names are ≤12 chars,
    /// so the small DP is effectively free.
    static func editDistance(_ a: [Character], _ b: [Character], atMost limit: Int) -> Int? {
        let la = a.count, lb = b.count
        if abs(la - lb) > limit { return nil }
        if a == b { return 0 }
        var previous = Array(0...lb)
        var current = [Int](repeating: 0, count: lb + 1)
        for i in 1...la {
            current[0] = i
            var rowMin = current[0]
            for j in 1...lb {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,        // deletion
                    current[j - 1] + 1,     // insertion
                    previous[j - 1] + cost  // substitution
                )
                rowMin = min(rowMin, current[j])
            }
            if rowMin > limit { return nil }
            swap(&previous, &current)
        }
        let distance = previous[lb]
        return distance <= limit ? distance : nil
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
