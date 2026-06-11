import Foundation

/// Print-house text helpers — full-width forms, MARS date quirks,
/// deterministic serials. The obsessive details that make a plate
/// read as *printed* rather than *rendered*.
nonisolated enum TicketText {
    /// ASCII → full-width (０-９Ａ-Ｚ). Leaves everything else alone.
    static func zenkaku(_ string: String) -> String {
        String(string.unicodeScalars.map { scalar -> Character in
            switch scalar.value {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A:
                return Character(UnicodeScalar(scalar.value + 0xFEE0)!)
            default:
                return Character(scalar)
            }
        })
    }

    /// ￥１４，１７０ — full-width price with full-width comma.
    static func price(_ yen: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let base = formatter.string(from: NSNumber(value: yen)) ?? String(yen)
        return "￥" + zenkaku(base).replacingOccurrences(of: ",", with: "，")
    }

    /// ６月２４日 — date as printed across the ticket face.
    static func faceDate(_ date: Date) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return zenkaku("\(c.month ?? 1)月\(c.day ?? 1)日")
    }

    /// 2026.-5.24 — the MARS issue-line date, with its famous leading
    /// minus standing in for a space on single-digit months/days.
    static func issueDate(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let month = (c.month ?? 1) < 10 ? "-\(c.month ?? 1)" : "\(c.month ?? 1)"
        let day = (c.day ?? 1) < 10 ? "-\(c.day ?? 1)" : "\(c.day ?? 1)"
        return "\(c.year ?? 2026).\(month).\(day)"
    }

    /// 25.11.23 — the small stamped date on edmondson card stock.
    static func stampDate(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let yy = (c.year ?? 2026) % 100
        return String(format: "%02d.%2d.%2d", yy, c.month ?? 1, c.day ?? 1)
    }

    /// 東京駅ＭＲ２１発行 — issuing station + machine number from seed.
    static func issuer(station: String, seed: UInt64) -> String {
        var rng = SeededRandom(seed ^ 0x15A4)
        let machines = ["ＭＲ", "ＭＶ", "ＶＦ", "ＭＫ"]
        let machine = machines[rng.int(in: 0...(machines.count - 1))]
        let number = zenkaku(String(rng.int(in: 11...89)))
        let name = station.hasSuffix("駅") ? station : station + "駅"
        return "\(name)\(machine)\(number)発行"
    }

    /// ０４２１７－０６ — ticket serial, stable per ticket.
    static func serial(seed: UInt64) -> String {
        var rng = SeededRandom(seed ^ 0xC0FFEE)
        return zenkaku(rng.digits(5)) + "－" + zenkaku(rng.digits(2))
    }

    /// ００７２３４ — red edmondson serial.
    static func edmondsonSerial(seed: UInt64) -> String {
        var rng = SeededRandom(seed ^ 0xED0)
        return zenkaku(rng.digits(6))
    }

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return c
    }
}
