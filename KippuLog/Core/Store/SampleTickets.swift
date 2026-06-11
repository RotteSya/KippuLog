import Foundation

extension Ticket {
    /// A small, warm starter collection — eight journeys across two years,
    /// so the timeline reads like a travelogue from the first open.
    static let samples: [Ticket] = [
        sample(
            seed: 0xA1, year: 2026, month: 6, day: 7,
            from: "新宿", to: "箱根湯本", price: 2470,
            kind: .tokkyu, brand: .odakyu,
            train: "はこね５３号", seat: "１号車１番Ｃ席",
            memo: "ロマンスカーの展望席。前面の窓いっぱいに山が来る。"
        ),
        sample(
            seed: 0xB2, year: 2026, month: 5, day: 24,
            from: "東京", to: "京都", price: 14170,
            kind: .shinkansen, brand: .jrCentral,
            train: "のぞみ２２５号", seat: "７号車１２番Ａ席",
            memo: "初夏の京都へ。鴨川の川床、夕暮れの先斗町。"
        ),
        sample(
            seed: 0xC3, year: 2026, month: 4, day: 12,
            from: "浅草", to: "東武日光", price: 2860,
            kind: .tokkyu, brand: .tobu,
            train: "けごん１３号", seat: "３号車８番Ｄ席",
            memo: "眠り猫に会いに。杉並木の参道は雨上がりだった。"
        ),
        sample(
            seed: 0xD4, year: 2026, month: 2, day: 8,
            from: "札幌", to: "小樽", price: 750,
            kind: .joshaken, brand: .jrHokkaido,
            memo: "雪あかりの路。運河のガス灯と粉雪。"
        ),
        sample(
            seed: 0xE5, year: 2026, month: 1, day: 2,
            from: "京都", to: "稲荷", price: 150,
            kind: .joshaken, brand: .jrWest,
            memo: "初詣は伏見稲荷へ。千本鳥居の朝の光。"
        ),
        sample(
            seed: 0xF6, year: 2025, month: 11, day: 23,
            from: "尾道", to: "", price: 150,
            kind: .nyujoken, brand: .jrWest,
            memo: "坂と猫の町。ホームの端から海が見えた。"
        ),
        sample(
            seed: 0x17, year: 2025, month: 10, day: 4,
            from: "高山", to: "名古屋", price: 6140,
            kind: .tokkyu, brand: .jrCentral,
            train: "ひだ１０号", seat: "５号車２番Ａ席",
            memo: "車窓はずっと飛騨川。紅葉にはまだ少し早い。"
        ),
        sample(
            seed: 0x28, year: 2025, month: 8, day: 11,
            from: "松本", to: "新宿", price: 6620,
            kind: .tokkyu, brand: .jrEast,
            train: "あずさ２６号", seat: "９号車６番Ａ席",
            memo: "夏の終わりの帰り道。八ヶ岳が夕陽で染まる。"
        ),
    ]

    private static func sample(
        seed: UInt64,
        year: Int, month: Int, day: Int,
        from: String, to: String, price: Int,
        kind: TicketKind, brand: RailBrand,
        train: String? = nil, seat: String? = nil,
        memo: String = ""
    ) -> Ticket {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))
        var ticket = Ticket()
        ticket.id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", seed)) ?? UUID()
        ticket.createdAt = date ?? .now
        ticket.fromStation = from
        ticket.toStation = to
        ticket.travelDate = date
        ticket.price = price
        ticket.kind = kind
        ticket.brand = brand
        ticket.trainName = train
        ticket.seat = seat
        ticket.memo = memo
        ticket.styleSeed = seed &* 0x9E3779B97F4A7C15
        ticket.isSample = true
        return ticket
    }
}
