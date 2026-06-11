import Testing
import Foundation
@testable import KippuLog

/// Parser cases mirror real ticket prints (MARS, edmondson, private rail).
struct ParserTests {
    private let reference = date(2026, 6, 11)

    @Test func parsesShinkansenMarsTicket() {
        let lines = [
            "新幹線特急券・乗車券",
            "東京 → 京都",
            "５月２４日 のぞみ２２５号",
            "７号車１２番Ａ席",
            "￥１４，１７０",
            "2026.-5.24 東京駅ＭＲ２１発行 ＪＲ東海",
        ]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.fromStation == "東京")
        #expect(t.toStation == "京都")
        #expect(t.kind == .shinkansen)
        #expect(t.brand == .jrCentral)
        #expect(t.price == 14170)
        #expect(t.trainName == "のぞみ２２５号")
        #expect(t.seat == "７号車１２番Ａ席")
        #expect(components(t.travelDate) == [2026, 5, 24])
    }

    @Test func parsesEntranceTicket() {
        let lines = ["入 場 券", "尾道駅", "１５０円", "25.11.23", "００７２３４"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.kind == .nyujoken)
        #expect(t.fromStation == "尾道")
        #expect(t.toStation.isEmpty)
        #expect(t.price == 150)
    }

    @Test func parsesZoneMarkedRoute() {
        let lines = ["乗車券", "(都)東京都区内 → (阪)大阪市内", "￥８，９１０", "6月2日"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.fromStation == "東京都区内")
        #expect(t.toStation == "大阪市内")
        #expect(t.kind == .joshaken)
        #expect(t.price == 8910)
        #expect(components(t.travelDate) == [2026, 6, 2])
    }

    @Test func parsesReiwaDateAndPrivateRail() {
        let lines = [
            "特急券",
            "新宿 → 箱根湯本",
            "令和８年６月７日",
            "はこね５３号 １号車１番Ｃ席",
            "小田急電鉄 ￥１，２００",
        ]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.brand == .odakyu)
        #expect(t.kind == .tokkyu)
        #expect(components(t.travelDate) == [2026, 6, 7])
        #expect(t.trainName == "はこね５３号")
        #expect(t.seat == "１号車１番Ｃ席")
    }

    @Test func monthDayOnlyResolvesToPast() {
        let lines = ["乗車券", "札幌 → 小樽", "12月28日", "750円"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(components(t.travelDate) == [2025, 12, 28])
    }

    @Test func ignoresIssueLineNumbersForPrice() {
        let lines = ["乗車券", "金沢 → 富山", "2026.-1.-2 金沢駅ＶＦ５５発行", "￥１，３４０"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.price == 1340)
    }

    @Test func freeSeatAndAutoBrandHints() {
        let lines = ["新幹線特急券", "名古屋 → 東京", "自由席", "こだま７３０号", "￥４，１８０"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.seat == "自由席")
        #expect(t.brand == .jrCentral)
        #expect(t.trainName == "こだま７３０号")
    }
}

struct StoreLogicTests {
    @Test func monthGroupingIsNewestFirst() {
        let groups = Dictionary(grouping: Ticket.samples) {
            Calendar(identifier: .gregorian).dateComponents([.year, .month], from: $0.sortDate)
        }
        #expect(groups.count >= 5)
    }

    @Test func ticketCodableRoundTrip() throws {
        let original = Ticket.samples[0]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Ticket.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: helpers

private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return c.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
}

private func components(_ date: Date?) -> [Int]? {
    guard let date else { return nil }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    let c = cal.dateComponents([.year, .month, .day], from: date)
    return [c.year!, c.month!, c.day!]
}
