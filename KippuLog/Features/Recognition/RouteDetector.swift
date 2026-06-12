import Foundation
import CoreGraphics

/// Finds 発駅 → 着駅 from OCR output. Japanese tickets *always* print both
/// stations, but real-world OCR mangles them every way imaginable — the
/// arrow vanishes (fusing both names into one token), keywords ride along,
/// blur swaps glyphs, the pair splits across lines. Strategies run from
/// most to least certain, every candidate validated against the station
/// gazetteer (`StationIndex`), which also heals near-miss OCR.
nonisolated enum RouteDetector {
    /// Arrows that *only* mean "to". A clean split here is high-confidence,
    /// so either side may be a gazetteer miss (a rare station) and still pass.
    private static let strongArrows = ["→", "➡", "⇒", "⇨", "➞", "➔", "➟", "▶", "▷", "❯", "〉", "≫", "»", "=>", "->", ">>"]

    /// Ambiguous dividers — a dash could be the ー inside a katakana name, a
    /// bar could be table ruling. Only trust these when *both* sides resolve.
    private static let weakSeparators = ["〜", "～", "~", "ー", "－", "—", "‐", "―", "｜", "|", "–"]

    // MARK: Entry

    static func detect(lines: [OCRLine], kind: TicketKind, index: StationIndex = .shared) -> (from: String, to: String)? {
        let norm = lines
            .map { OCRLine(text: TicketTextParser.normalize($0.text), box: $0.box) }
            .filter { !isIssuerLine($0.text) }

        // 1a. Explicit arrow on one line — accept loose candidates.
        if let pair = splitOnLine(norm, separators: strongArrows, requireStrong: false, index: index) {
            return pair
        }
        // 1b. から…まで / 〜行 textual route.
        if let pair = textualRoute(norm, index: index) {
            return pair
        }
        // 1c. Ambiguous divider — both sides must resolve.
        if let pair = splitOnLine(norm, separators: weakSeparators, requireStrong: true, index: index) {
            return pair
        }
        // 1d. One line, two space-separated stations (arrow was a vector
        //     mark or a blank gap that OCR collapsed to whitespace).
        if let pair = splitOnWhitespace(norm, index: index) {
            return pair
        }
        // 1e. The arrow vanished entirely: both endpoints fused into one
        //     token (東京都区内京都市内). Strict gazetteer split.
        for line in norm {
            if let pair = index.splitFused(line.text), pair.0 != pair.1 {
                return pair
            }
        }
        // 2. Two station tokens sharing a horizontal band (arrow lost).
        if let pair = sameBand(norm, index: index) {
            return pair
        }
        // 3. Two station tokens stacked on adjacent lines.
        if let pair = stacked(norm, index: index) {
            return pair
        }
        // 4. Last resort: the two most prominent gazetteer hits anywhere,
        //    in reading order.
        if let pair = anyTwoStations(norm, index: index) {
            return pair
        }
        return nil
    }

    /// Single station for 入場券 (or any single-station ticket): the most
    /// prominent gazetteer hit, preferring a 駅-suffixed line.
    static func detectEntrance(lines: [OCRLine], index: StationIndex = .shared) -> String? {
        let norm = lines
            .map { OCRLine(text: TicketTextParser.normalize($0.text), box: $0.box) }
            .filter { !isIssuerLine($0.text) }
        // Prefer an explicit "◯◯駅" line.
        for line in norm where line.text.replacingOccurrences(of: " ", with: "").hasSuffix("駅") {
            if let snapped = index.snap(line.text), !isKeyword(snapped) { return snapped }
        }
        // Otherwise the largest text box that resolves to a station.
        for line in norm.sorted(by: { $0.area > $1.area }) {
            if let snapped = index.snap(line.text), !isKeyword(snapped) { return snapped }
        }
        return nil
    }

    // MARK: Strategy 1 — split a single line

    private static func splitOnLine(_ lines: [OCRLine], separators: [String], requireStrong: Bool, index: StationIndex) -> (String, String)? {
        for line in lines {
            for separator in separators where line.text.contains(separator) {
                let parts = line.text.components(separatedBy: separator).filter { !$0.isEmpty }
                guard parts.count == 2 else { continue }
                guard let from = resolve(parts[0], side: .departure, requireStrong: requireStrong, index: index),
                      let to = resolve(parts[1], side: .arrival, requireStrong: requireStrong, index: index),
                      from != to else { continue }
                return (from, to)
            }
        }
        return nil
    }

    /// Two real stations on one line, separated only by whitespace.
    private static func splitOnWhitespace(_ lines: [OCRLine], index: StationIndex) -> (String, String)? {
        for line in lines {
            let tokens = line.text
                .split(whereSeparator: { $0 == " " || $0 == "\u{3000}" })
                .map(String.init)
            guard tokens.count >= 2 else { continue }
            let strong = tokens.compactMap { token -> String? in
                guard let s = index.snap(token), !isKeyword(s) else { return nil }
                return s
            }
            if strong.count == 2, strong[0] != strong[1] {
                return (strong[0], strong[1])
            }
        }
        return nil
    }

    private static func textualRoute(_ lines: [OCRLine], index: StationIndex) -> (String, String)? {
        for line in lines {
            let text = line.text
            guard text.contains("から") else { continue }
            let afterFrom = text.components(separatedBy: "から")
            guard afterFrom.count == 2 else { continue }
            guard let from = resolve(afterFrom[0], side: .departure, requireStrong: true, index: index),
                  let to = resolve(afterFrom[1], side: .arrival, requireStrong: true, index: index),
                  from != to else { continue }
            return (from, to)
        }
        return nil
    }

    // MARK: Strategy 2 — same horizontal band

    private static func sameBand(_ lines: [OCRLine], index: StationIndex) -> (String, String)? {
        guard lines.count >= 2 else { return nil }
        let tolerance = max(0.02, medianHeight(lines) * 0.6)

        var used = Set<Int>()
        // Walk bands from the most prominent (tallest) line down.
        for seed in lines.indices.sorted(by: { lines[$0].height > lines[$1].height }) {
            if used.contains(seed) { continue }
            let band = lines.indices.filter { abs(lines[$0].midY - lines[seed].midY) <= tolerance }
            band.forEach { used.insert($0) }
            guard band.count >= 2 else { continue }

            let ordered = band.sorted { lines[$0].minX < lines[$1].minX }
            let snapped = ordered.compactMap { index.snap(lines[$0].text) }.filter { !isKeyword($0) }
            if snapped.count >= 2, let first = snapped.first, let last = snapped.last, first != last {
                return (first, last)
            }
        }
        return nil
    }

    // MARK: Strategy 3 — stacked adjacent lines

    private static func stacked(_ lines: [OCRLine], index: StationIndex) -> (String, String)? {
        let snaps = lines.map { line -> String? in
            guard let s = index.snap(line.text), !isKeyword(s) else { return nil }
            return s
        }
        for i in 0..<max(0, lines.count - 1) {
            guard let top = snaps[i], let bottom = snaps[i + 1], top != bottom else { continue }
            // Roughly left-aligned (a real 発駅/着駅 stack), not scattered.
            guard abs(lines[i].minX - lines[i + 1].minX) < 0.18 else { continue }
            return (top, bottom)
        }
        return nil
    }

    // MARK: Strategy 4 — any two stations, by prominence

    /// When everything else failed: every line that resolves to a station
    /// (whole or as its longest prefix/suffix), ranked by printed height —
    /// the two tallest are the route, in reading order.
    private static func anyTwoStations(_ lines: [OCRLine], index: StationIndex) -> (String, String)? {
        var hits: [(name: String, line: OCRLine)] = []
        for line in lines {
            let name = index.snap(line.text) ?? index.snapPrefix(line.text) ?? index.snapSuffix(line.text)
            guard let name, !isKeyword(name) else { continue }
            if !hits.contains(where: { $0.name == name }) {
                hits.append((name, line))
            }
        }
        guard hits.count >= 2 else { return nil }
        let top = hits.sorted { $0.line.height > $1.line.height }.prefix(2)
        // Reading order: higher line first; same band → left first.
        let ordered = top.sorted {
            abs($0.line.midY - $1.line.midY) < 0.03
                ? $0.line.minX < $1.line.minX
                : $0.line.midY > $1.line.midY
        }
        return (ordered[0].name, ordered[1].name)
    }

    // MARK: Candidate resolution

    private enum Side { case departure, arrival }

    /// Snap a raw split-half to a station. Tries, in order: the whole
    /// token; ゆき/行き-stripped (arrival side); the longest resolving
    /// suffix (departure — keywords ride in front: 乗車券東京) or prefix
    /// (arrival — suffixes ride behind: 京都市内ゆき). `requireStrong`
    /// finally gates a loosely-plausible fallback for gazetteer misses.
    private static func resolve(_ raw: String, side: Side, requireStrong: Bool, index: StationIndex) -> String? {
        if let snapped = index.snap(raw), !isKeyword(snapped) { return snapped }

        if side == .arrival {
            var stripped = StationIndex.clean(raw)
            for tail in ["まで", "ゆき", "行き", "行"] where stripped.hasSuffix(tail) {
                stripped = String(stripped.dropLast(tail.count))
                break
            }
            if stripped != StationIndex.clean(raw),
               let snapped = index.snap(stripped), !isKeyword(snapped) {
                return snapped
            }
        }

        let trimmed = side == .departure ? index.snapSuffix(raw) : index.snapPrefix(raw)
        if let trimmed, !isKeyword(trimmed) { return trimmed }

        guard !requireStrong else { return nil }
        let cleaned = StationIndex.clean(raw)
        guard isPlausible(cleaned), !isKeyword(cleaned) else { return nil }
        return cleaned
    }

    // MARK: Helpers

    /// The issuing line (東京駅ＶＦ１発行…) names a station that is *not*
    /// the route — never let it vote.
    static func isIssuerLine(_ text: String) -> Bool {
        text.contains("発行") || text.contains("様") || text.contains("領収")
    }

    private static let keywords = [
        "入場券", "乗車券", "特急券", "特急", "新幹線", "定期", "発行", "下車", "前途", "無効",
        "鉄道", "電鉄", "号車", "指定席", "自由席", "領収", "経由", "有効",
    ]

    private static func isKeyword(_ s: String) -> Bool {
        keywords.contains { s.contains($0) }
    }

    private static func isPlausible(_ s: String) -> Bool {
        guard (1...12).contains(s.count) else { return false }
        let cjk = s.unicodeScalars.filter {
            (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value)
        }
        return cjk.count * 2 >= s.unicodeScalars.count
    }

    private static func medianHeight(_ lines: [OCRLine]) -> CGFloat {
        let heights = lines.map(\.height).sorted()
        guard !heights.isEmpty else { return 0 }
        return heights[heights.count / 2]
    }
}
