import Foundation
import CoreGraphics

/// Turns OCR'd Japanese ticket text into a `Ticket` draft.
/// Heuristics tuned for MARS prints, edmondson cards and private-rail
/// stock; everything stays editable in the confirm sheet. Route detection
/// (発駅/着駅) is delegated to `RouteDetector`, which uses OCR geometry +
/// the station gazetteer.
nonisolated enum TicketTextParser {
    /// String-only entry (tests, manual lines). Wraps each line as a
    /// full-width box stacked top-to-bottom so the geometry strategies still
    /// have something to work with.
    static func parse(lines: [String], now: Date = .now) -> Ticket {
        parse(ocrLines: syntheticLines(lines), now: now)
    }

    /// Primary entry — real OCR output carrying bounding boxes.
    static func parse(ocrLines: [OCRLine], now: Date = .now) -> Ticket {
        var ticket = Ticket()
        let normalized = ocrLines.map { normalize($0.text) }
        let joined = normalized.joined(separator: "\n")
        // Spaced-out prints (入 場 券) match keywords on the compact form.
        let compact = joined.replacingOccurrences(of: " ", with: "")

        ticket.kind = parseKind(compact)
        ticket.brand = parseBrand(compact)

        if let (from, to) = RouteDetector.detect(lines: ocrLines, kind: ticket.kind) {
            ticket.fromStation = from
            ticket.toStation = to
        } else if ticket.kind == .nyujoken, let station = RouteDetector.detectEntrance(lines: ocrLines) {
            ticket.fromStation = station
        }

        ticket.travelDate = parseDate(joined, now: now)
        ticket.price = parsePrice(normalized)
        ticket.trainName = parseTrain(joined)
        ticket.seat = parseSeat(joined)

        // 入場券 never carries a destination.
        if ticket.kind == .nyujoken { ticket.toStation = "" }
        return ticket
    }

    /// Lay out plain strings as full-width lines stacked top-to-bottom
    /// (first line highest), in Vision's bottom-left-origin space.
    private static func syntheticLines(_ lines: [String]) -> [OCRLine] {
        let n = max(lines.count, 1)
        let h = 0.8 / CGFloat(n)
        return lines.enumerated().map { i, text in
            let midY = 1 - (CGFloat(i) + 0.5) / CGFloat(n)
            return OCRLine(text: text, box: CGRect(x: 0, y: midY - h / 2, width: 1, height: h))
        }
    }

    // MARK: Normalisation

    /// Full-width → half-width for digits/latin, unify arrows, strip noise.
    static func normalize(_ line: String) -> String {
        var s = ""
        for scalar in line.unicodeScalars {
            switch scalar.value {
            case 0xFF10...0xFF19, 0xFF21...0xFF3A, 0xFF41...0xFF5A:
                s.unicodeScalars.append(UnicodeScalar(scalar.value - 0xFEE0)!)
            case 0xFF0C: s.append(",")
            case 0xFF0E: s.append(".")
            case 0x3000: s.append(" ")
            default: s.unicodeScalars.append(scalar)
            }
        }
        for arrow in ["➡", "⇒", "->", "→→"] {
            s = s.replacingOccurrences(of: arrow, with: "→")
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: Date

    static func parseDate(_ text: String, now: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

        // 2026.-5.24 / 2026.5.24 / 2026年5月24日 / 2026/5/24
        if let m = firstMatch(#"(20\d{2})[./年]\s?-?(\d{1,2})[./月]\s?-?(\d{1,2})日?"#, in: text),
           let date = calendar.date(from: DateComponents(
            year: Int(m[1]), month: Int(m[2]), day: Int(m[3]), hour: 9)) {
            return date
        }
        // 令和8年5月24日 (令和元年 = 2019)
        if let m = firstMatch(#"令和(\d{1,2}|元)年(\d{1,2})月(\d{1,2})日"#, in: text) {
            let eraYear = m[1] == "元" ? 1 : (Int(m[1]) ?? 1)
            if let date = calendar.date(from: DateComponents(
                year: 2018 + eraYear, month: Int(m[2]), day: Int(m[3]), hour: 9)) {
                return date
            }
        }
        // 5月24日 — most recent past occurrence.
        if let m = firstMatch(#"(\d{1,2})月\s?(\d{1,2})日"#, in: text),
           let month = Int(m[1]), let day = Int(m[2]) {
            let thisYear = calendar.component(.year, from: now)
            for year in [thisYear, thisYear - 1] {
                if let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9)),
                   date <= now {
                    return date
                }
            }
        }
        return nil
    }

    // MARK: Price

    static func parsePrice(_ lines: [String]) -> Int? {
        var best: Int?
        for line in lines {
            // Skip issue-line dates like 2026.-5.24 masquerading as numbers.
            if line.contains("発行") { continue }
            for m in matches(#"[¥￥]\s?([\d,]+)|(\d[\d,]*)\s?円"#, in: line) {
                let digits = (m[1].isEmpty ? m[2] : m[1]).replacingOccurrences(of: ",", with: "")
                guard let value = Int(digits), (50...200_000).contains(value) else { continue }
                // Prefer the largest plausible figure (fare beats seat numbers).
                if value > (best ?? 0) { best = value }
            }
        }
        return best
    }

    // MARK: Train / seat

    private static let trainNames = [
        "のぞみ", "ひかり", "こだま", "はやぶさ", "はやて", "やまびこ", "なすの",
        "とき", "たにがわ", "かがやき", "はくたか", "つるぎ", "あさま",
        "みずほ", "さくら", "つばめ", "こまち", "つばさ",
        "あずさ", "かいじ", "しなの", "ひだ", "しらさぎ", "サンダーバード",
        "ソニック", "にちりん", "かもめ", "ゆふ",
        "はこね", "スーパーはこね", "メトロはこね", "けごん", "きぬ", "スペーシア",
        "ラビュー", "ちちぶ", "こうや", "りょうもう", "しまかぜ", "ひのとり",
    ]

    static func parseTrain(_ text: String) -> String? {
        for name in trainNames {
            if let m = firstMatch("(\(name))\\s?(\\d{1,3})号", in: text) {
                return TicketText.zenkaku("\(m[1])\(m[2])号")
            }
            if text.contains(name + "号") {
                return TicketText.zenkaku(name + "号")
            }
        }
        return nil
    }

    static func parseSeat(_ text: String) -> String? {
        if let m = firstMatch(#"(\d{1,2})号車\s?(\d{1,2})番\s?([A-E])席?"#, in: text) {
            return TicketText.zenkaku("\(m[1])号車\(m[2])番\(m[3])席")
        }
        if text.contains("自由席") { return "自由席" }
        return nil
    }

    // MARK: Kind & brand

    /// Expects compact (space-stripped) text.
    static func parseKind(_ text: String) -> TicketKind {
        if text.contains("入場券") { return .nyujoken }
        if text.contains("定期") { return .teiki }
        if text.contains("新幹線") { return .shinkansen }
        if text.contains("特急") { return .tokkyu }
        return .joshaken
    }

    static func parseBrand(_ text: String) -> RailBrand {
        let table: [(String, RailBrand)] = [
            ("JR東日本", .jrEast), ("東日本会社", .jrEast),
            ("JR東海", .jrCentral), ("東海会社", .jrCentral),
            ("JR西日本", .jrWest), ("西日本会社", .jrWest),
            ("JR北海道", .jrHokkaido), ("JR九州", .jrKyushu), ("JR四国", .jrShikoku),
            ("東京メトロ", .tokyoMetro), ("メトロ", .tokyoMetro), ("都営", .toei),
            ("小田急", .odakyu), ("京王", .keio), ("東急", .tokyu), ("京急", .keikyu),
            ("西武", .seibu), ("東武", .tobu), ("近鉄", .kintetsu), ("近畿日本鉄道", .kintetsu),
            ("阪急", .hankyu), ("阪神", .hanshin), ("名鉄", .meitetsu), ("名古屋鉄道", .meitetsu),
            ("京成", .keisei), ("相鉄", .sotetsu), ("相模鉄道", .sotetsu),
        ]
        for (needle, brand) in table where text.contains(needle) {
            return brand
        }
        // Train-name hints when the company line didn't survive OCR.
        if text.contains("のぞみ") || text.contains("ひかり") || text.contains("こだま") {
            return .jrCentral
        }
        if text.contains("はやぶさ") || text.contains("あずさ") || text.contains("かいじ") {
            return .jrEast
        }
        if text.contains("はこね") { return .odakyu }
        if text.contains("けごん") || text.contains("きぬ") { return .tobu }
        if text.contains("JR") { return .jrEast }
        return .other
    }

    // MARK: Regex helpers

    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        matches(pattern, in: text).first
    }

    /// All matches; each entry is [full, group1, group2, …] with "" for
    /// unmatched groups.
    private static func matches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.matches(in: text, range: range).map { match in
            (0..<match.numberOfRanges).map { i in
                let r = match.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }
    }
}
