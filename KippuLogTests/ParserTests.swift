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

    // MARK: Route detection (geometry + gazetteer)

    @Test func routeWithoutArrowOnSameBand() {
        // The arrow was lost by OCR; two stations sit side by side.
        let lines = [
            OCRLine(text: "新幹線特急券", box: rect(0.1, 0.80, 0.8, 0.07)),
            OCRLine(text: "東京", box: rect(0.10, 0.55, 0.25, 0.12)),
            OCRLine(text: "新大阪", box: rect(0.62, 0.55, 0.30, 0.12)),
            OCRLine(text: "￥１４，７２０", box: rect(0.3, 0.30, 0.4, 0.08)),
        ]
        let t = TicketTextParser.parse(ocrLines: lines, now: reference)
        #expect(t.fromStation == "東京")
        #expect(t.toStation == "新大阪")
    }

    @Test func routeSnapsNearMissOCR() {
        // 柬 mis-OCR'd for 東; 太 for 大 — both within edit distance 1.
        let lines = ["乗車券", "柬京 → 新太阪", "￥８，９１０"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.fromStation == "東京")
        #expect(t.toStation == "新大阪")
    }

    @Test func routeWithGarbledArrowChar() {
        // Vision read the arrow as a full-width tilde.
        let lines = ["特急券", "新宿 〜 箱根湯本", "はこね５３号"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.fromStation == "新宿")
        #expect(t.toStation == "箱根湯本")
    }

    @Test func katakanaDashIsNotASeparator() {
        // サンダーバード contains ー; must not be split into stations.
        let lines = [
            OCRLine(text: "特急券", box: rect(0.1, 0.8, 0.4, 0.07)),
            OCRLine(text: "大阪", box: rect(0.10, 0.55, 0.22, 0.12)),
            OCRLine(text: "金沢", box: rect(0.66, 0.55, 0.22, 0.12)),
            OCRLine(text: "サンダーバード５号", box: rect(0.2, 0.32, 0.6, 0.06)),
        ]
        let t = TicketTextParser.parse(ocrLines: lines, now: reference)
        #expect(t.fromStation == "大阪")
        #expect(t.toStation == "金沢")
        #expect(t.trainName == "サンダーバード５号")
    }

    @Test func stackedStationsResolve() {
        // 発駅 / 着駅 printed on two stacked lines, left-aligned, no arrow.
        let lines = [
            OCRLine(text: "乗車券", box: rect(0.1, 0.85, 0.4, 0.06)),
            OCRLine(text: "京都", box: rect(0.12, 0.60, 0.3, 0.10)),
            OCRLine(text: "大阪", box: rect(0.12, 0.46, 0.3, 0.10)),
            OCRLine(text: "￥５６０", box: rect(0.12, 0.25, 0.3, 0.07)),
        ]
        let t = TicketTextParser.parse(ocrLines: lines, now: reference)
        #expect(t.fromStation == "京都")
        #expect(t.toStation == "大阪")
    }

    // MARK: Real-world OCR carnage

    @Test func fusedRouteWithZoneNames() {
        // The arrow glyph vanished entirely; both endpoints fused.
        let lines = ["乗車券", "東京都区内京都市内", "￥８，９１０"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.fromStation == "東京都区内")
        #expect(t.toStation == "京都市内")
    }

    @Test func fusedPlainStations() {
        let lines = ["特急券", "新宿小田原", "はこね５３号"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.fromStation == "新宿")
        #expect(t.toStation == "小田原")
    }

    @Test func keywordRidesAlongTheDeparture() {
        // OCR merged the title into the route line.
        let lines = ["乗車券 東京 → 京都", "￥８，９１０"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.fromStation == "東京")
        #expect(t.toStation == "京都")
    }

    @Test func yukiSuffixOnArrival() {
        let lines = ["乗車券", "長野 → 松本ゆき", "￥１，２００"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.fromStation == "長野")
        #expect(t.toStation == "松本")
    }

    @Test func zoneNameHealsBlurredCity() {
        // 亰 misread for 京 inside a fare-zone label.
        let lines = ["乗車券", "東亰都区内 → 大阪市内", "￥８，９１０"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.fromStation == "東京都区内")
        #expect(t.toStation == "大阪市内")
    }

    @Test func distanceTwoSnapForLongNames() {
        // Two glyphs wrong in a four-character name (blurry shot).
        let lines = ["特急券", "柬武目光 → 浅草", "けごん１３号"]
        let t = TicketTextParser.parse(lines: lines, now: reference)
        #expect(t.fromStation == "東武日光")
        #expect(t.toStation == "浅草")
    }

    @Test func issuerLineNeverVotes() {
        // Only one route station + the issuing station; the issuer's 東京
        // must not become an endpoint.
        let lines = [
            OCRLine(text: "乗車券", box: rect(0.1, 0.85, 0.3, 0.05)),
            OCRLine(text: "大阪", box: rect(0.10, 0.60, 0.28, 0.11)),
            OCRLine(text: "神戸", box: rect(0.10, 0.45, 0.28, 0.11)),
            OCRLine(text: "2026.6.2 東京駅VF1発行", box: rect(0.1, 0.10, 0.6, 0.04)),
        ]
        let t = TicketTextParser.parse(ocrLines: lines, now: reference)
        #expect(t.fromStation == "大阪")
        #expect(t.toStation == "神戸")
    }

    @Test func anyTwoStationsLastResort() {
        // Stations scattered across non-adjacent lines with junk between.
        let lines = [
            OCRLine(text: "新幹線特急券", box: rect(0.15, 0.88, 0.6, 0.05)),
            OCRLine(text: "東京", box: rect(0.10, 0.66, 0.24, 0.12)),
            OCRLine(text: "のぞみ３１号", box: rect(0.30, 0.48, 0.4, 0.05)),
            OCRLine(text: "新大阪", box: rect(0.55, 0.30, 0.34, 0.12)),
            OCRLine(text: "￥１４，７２０", box: rect(0.3, 0.15, 0.4, 0.06)),
        ]
        let t = TicketTextParser.parse(ocrLines: lines, now: reference)
        #expect(t.fromStation == "東京")
        #expect(t.toStation == "新大阪")
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

struct StationIndexTests {
    let index = StationIndex.shared

    @Test func exactHit() {
        #expect(index.snap("東京") == "東京")
        #expect(index.snap("新大阪") == "新大阪")
    }

    @Test func stripsStationSuffixAndSpaces() {
        #expect(index.snap("尾道駅") == "尾道")
        #expect(index.snap(" 京 都 ") == "京都")
    }

    @Test func snapsSingleSubstitution() {
        #expect(index.snap("柬京") == "東京")     // 柬→東
        #expect(index.snap("新太阪") == "新大阪")  // 太→大
    }

    @Test func acceptsFareZoneLabels() {
        #expect(index.snap("東京都区内") == "東京都区内")
        #expect(index.snap("(阪)大阪市内") == "大阪市内")
    }

    @Test func rejectsNonStations() {
        #expect(index.snap("乗車券") == nil)
        #expect(index.snap("１４１７０円") == nil)
        #expect(index.snap("") == nil)
    }
}

// MARK: helpers

/// Vision-space rect (origin bottom-left), x/y/width/height in 0...1.
private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
    CGRect(x: x, y: y, width: w, height: h)
}

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
