import Foundation

/// One collected ticket — a journey, remembered.
nonisolated struct Ticket: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var createdAt = Date.now

    /// 発駅. For 入場券 this is the only station.
    var fromStation = ""
    /// 着駅. Empty for 入場券.
    var toStation = ""
    /// Date printed on the ticket (day precision).
    var travelDate: Date?
    /// Fare in yen.
    var price: Int?
    var kind = TicketKind.joshaken
    var brand = RailBrand.other
    /// e.g. のぞみ２２５号
    var trainName: String?
    /// e.g. ７号車１２番Ａ席
    var seat: String?
    var memo = ""

    /// Deterministic seed driving per-ticket print variation
    /// (serial numbers, punch position, lattice phase).
    var styleSeed: UInt64 = .random(in: UInt64.min ... UInt64.max)
    /// Original capture, stored next to the JSON.
    var photoFileName: String?
    var isSample = false

    /// 東京 → 京都, or just 尾道 for an entrance ticket.
    var routeText: String {
        if toStation.isEmpty { return fromStation }
        return "\(fromStation) → \(toStation)"
    }

    /// Sort & grouping date — the journey's date, falling back to capture time.
    var sortDate: Date { travelDate ?? createdAt }
}

nonisolated enum TicketKind: String, Codable, CaseIterable, Identifiable {
    case joshaken
    case shinkansen
    case tokkyu
    case nyujoken
    case teiki
    case other

    var id: String { rawValue }

    /// Chip label in UI.
    var label: String {
        switch self {
        case .joshaken: "乗車券"
        case .shinkansen: "新幹線"
        case .tokkyu: "特急"
        case .nyujoken: "入場券"
        case .teiki: "定期券"
        case .other: "その他"
        }
    }

    /// Title printed on the ticket face.
    var faceTitle: String {
        switch self {
        case .joshaken: "乗　車　券"
        case .shinkansen: "新幹線特急券"
        case .tokkyu: "特　急　券"
        case .nyujoken: "入 場 券"
        case .teiki: "定期乗車券"
        case .other: "乗 車 票"
        }
    }

    /// 入場券 renders as a small edmondson card; everything else as MARS stock.
    var isEdmondson: Bool { self == .nyujoken }
}

/// Railway operator → ticket paper personality.
nonisolated enum RailBrand: String, Codable, CaseIterable, Identifiable {
    case jrEast, jrCentral, jrWest, jrHokkaido, jrKyushu, jrShikoku
    case tokyoMetro, toei
    case odakyu, keio, tokyu, keikyu, seibu, tobu
    case kintetsu, hankyu, hanshin, meitetsu, keisei, sotetsu
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .jrEast: "JR東日本"
        case .jrCentral: "JR東海"
        case .jrWest: "JR西日本"
        case .jrHokkaido: "JR北海道"
        case .jrKyushu: "JR九州"
        case .jrShikoku: "JR四国"
        case .tokyoMetro: "東京メトロ"
        case .toei: "都営地下鉄"
        case .odakyu: "小田急電鉄"
        case .keio: "京王電鉄"
        case .tokyu: "東急電鉄"
        case .keikyu: "京急電鉄"
        case .seibu: "西武鉄道"
        case .tobu: "東武鉄道"
        case .kintetsu: "近畿日本鉄道"
        case .hankyu: "阪急電鉄"
        case .hanshin: "阪神電気鉄道"
        case .meitetsu: "名古屋鉄道"
        case .keisei: "京成電鉄"
        case .sotetsu: "相模鉄道"
        case .other: "鉄道"
        }
    }

    /// Short mark printed top-left on the ticket face.
    var mark: String {
        switch self {
        case .jrEast, .jrCentral, .jrWest, .jrHokkaido, .jrKyushu, .jrShikoku: "JR"
        case .tokyoMetro: "Ｍ"
        case .toei: "都"
        case .odakyu: "ＯＨ"
        case .keio: "ＫＯ"
        case .tokyu: "ＴＹ"
        case .keikyu: "ＫＫ"
        case .seibu: "ＳＩ"
        case .tobu: "ＴＮ"
        case .kintetsu: "Ｋ"
        case .hankyu: "ＨＫ"
        case .hanshin: "ＨＳ"
        case .meitetsu: "ＭＥ"
        case .keisei: "ＫＳ"
        case .sotetsu: "ＳＯ"
        case .other: "〇"
        }
    }

    /// Tint of the security lattice printed across the ticket paper.
    var patternHex: UInt32 {
        switch self {
        case .jrEast: 0x5F9286      // 青緑 — the classic JRE lattice
        case .jrCentral: 0xD89A6A   // 橙
        case .jrWest: 0x7B96BD      // 青
        case .jrHokkaido: 0x7FA383  // 萌黄
        case .jrKyushu: 0xC97C6B    // 赤
        case .jrShikoku: 0x84AEC2   // 水色
        case .tokyoMetro: 0x8FA7B5
        case .toei: 0x9AA48E
        case .odakyu: 0x86A8C8
        case .keio: 0xB58BA6
        case .tokyu: 0xC08B8B
        case .keikyu: 0xC98787
        case .seibu: 0x92AEC4
        case .tobu: 0xC79E72
        case .kintetsu: 0xB08A9C
        case .hankyu: 0xA38386
        case .hanshin: 0x8C9BB8
        case .meitetsu: 0xC78D85
        case .keisei: 0x90AAB8
        case .sotetsu: 0x9A9FB8
        case .other: 0xA3A092
        }
    }

    /// Operators whose stock leans warmer (affects paper tint subtly).
    var warmPaper: Bool {
        switch self {
        case .jrCentral, .jrKyushu, .tobu, .meitetsu: true
        default: false
        }
    }
}
