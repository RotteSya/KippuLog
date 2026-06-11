import Foundation

/// Magazine-voice date & figure formatting for the timeline.
enum Editorial {
    private static let kanjiMonths = [
        "一月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "十一月", "十二月",
    ]

    /// 六月
    static func kanjiMonth(_ month: Int) -> String {
        guard (1...12).contains(month) else { return "" }
        return kanjiMonths[month - 1]
    }

    /// JUNE 2026
    static func latinMonthYear(_ components: DateComponents) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM"
        var c = components
        c.day = 1
        let date = Calendar(identifier: .gregorian).date(from: c) ?? .now
        return "\(formatter.string(from: date).uppercased()) \(components.year ?? 0)"
    }

    /// 6.7 SUN
    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "M.d EEE"
        return formatter.string(from: date).uppercased()
    }

    /// ¥14,170 (halfwidth, editorial figures)
    static func yen(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "¥" + (formatter.string(from: NSNumber(value: amount)) ?? "\(amount)")
    }

    /// The caption line under a plate: 6.7 SUN ・ はこね５３号 ・ ¥2,470
    static func caption(for ticket: Ticket) -> String {
        var parts: [String] = []
        if let date = ticket.travelDate { parts.append(shortDate(date)) }
        if let train = ticket.trainName { parts.append(train) }
        if let price = ticket.price { parts.append(yen(price)) }
        if parts.isEmpty { parts.append(ticket.brand.displayName) }
        return parts.joined(separator: " ・ ")
    }
}
