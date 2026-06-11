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

    /// 一枚 / 三枚 — small kanji counts for month headers.
    static func kanjiCount(_ n: Int) -> String {
        let kanji = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        guard n >= 1 else { return "" }
        guard n <= 10 else { return "\(n)枚" }
        return kanji[n - 1] + "枚"
    }
}
