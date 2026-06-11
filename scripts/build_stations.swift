#!/usr/bin/env swift
//
//  build_stations.swift — distill the bundled station gazetteer.
//
//  Source: piuccio/open-data-jp-railway-stations (derived from 駅データ.jp /
//  the Association for Open Data of Public Transportation). Dev-time only;
//  the app never touches the network.
//
//  Regenerate:
//      curl -sL -o /tmp/stations_src.json \
//        https://raw.githubusercontent.com/piuccio/open-data-jp-railway-stations/master/stations.json
//      swift scripts/build_stations.swift /tmp/stations_src.json KippuLog/Resources/stations.json
//
//  Output: a sorted JSON array of unique Japanese station names (kanji/kana),
//  the validation/snap dictionary behind RouteDetector + StationIndex.

import Foundation

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: build_stations.swift <src.json> <out.json>\n".data(using: .utf8)!)
    exit(2)
}
let srcURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])

struct Station: Decodable {
    let name_kanji: String?
    let alternative_names: [String]?
    let stations: [Station]?
}

// Keep names made only of CJK ideographs, kana, and the few marks that appear
// in real station names (々 ー ・ ヶ ヵ). Reject anything with ASCII/digits.
func isStationName(_ s: String) -> Bool {
    guard (1...12).contains(s.count) else { return false }
    for u in s.unicodeScalars {
        switch u.value {
        case 0x3040...0x309F,            // hiragana
             0x30A0...0x30FF,            // katakana (incl. ー ・ ヶ ヵ)
             0x4E00...0x9FFF,            // CJK ideographs
             0x3005,                     // 々
             0x30FC:                     // ー (prolonged sound)
            continue
        default:
            return false
        }
    }
    return true
}

var names = Set<String>()
func collect(_ s: Station) {
    if let n = s.name_kanji?.trimmingCharacters(in: .whitespaces), isStationName(n) {
        names.insert(n)
    }
    for alt in s.alternative_names ?? [] {
        let a = alt.trimmingCharacters(in: .whitespaces)
        if isStationName(a) { names.insert(a) }
    }
    for child in s.stations ?? [] { collect(child) }
}

let data = try Data(contentsOf: srcURL)
let groups = try JSONDecoder().decode([Station].self, from: data)
groups.forEach(collect)

let sorted = names.sorted()
let out = try JSONSerialization.data(withJSONObject: sorted, options: [.sortedKeys])
// Re-encode as a tidy one-name-per-line array for a readable diff.
let body = sorted.map { "  \"\($0)\"" }.joined(separator: ",\n")
let pretty = "[\n\(body)\n]\n"
try pretty.data(using: .utf8)!.write(to: outURL, options: .atomic)

FileHandle.standardError.write("wrote \(sorted.count) station names → \(outURL.path) (\(out.count) bytes compact)\n".data(using: .utf8)!)
