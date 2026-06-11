# きっぷログ — KippuLog

A pocket museum for Japanese train tickets. Photograph a 切符, let the app
read it, and it is re-set as an idealized, studio-lit ticket plate — then
collected into a scrolling magazine of your journeys.

## Build & run

```sh
xcodebuild -project KippuLog.xcodeproj -scheme KippuLog \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- Xcode 26.5 / iOS 26.0+ / iPhone only / portrait only
- Zero third-party dependencies: SwiftUI, Metal, Vision, AVFoundation, CoreHaptics

## Dev & verification hooks (DEBUG builds)

Launch arguments, usable from `simctl launch` or scheme settings:

| Argument | Effect |
|---|---|
| `-uiTestReset` | wipe the on-disk collection |
| `-uiTestSeedSamples` | seed 8 sample journeys |
| `-uiScreen gallery\|gallery2\|hero` | jump straight to plate-renderer debug shelves |
| `-uiTestImport <png path>` | auto-open the gate and feed an image through flatten → OCR → parse |

App icon is generated, not drawn by hand: `swift scripts/generate_icon.swift`.

Tests: `xcodebuild … test` runs parser/store unit tests (Swift Testing)
plus XCUITest walks that screenshot every screen (export attachments via
`xcrun xcresulttool export attachments`).

## Documents

- [docs/DESIGN.md](docs/DESIGN.md) — design language: paper & ink, type, motion, the studio system
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — modules and data flow
- [docs/PROGRESS.md](docs/PROGRESS.md) — running build log

## Source layout

```
KippuLog/
├── App/            entry + root navigation
├── Core/
│   ├── Design/     palette, typography, haptics
│   ├── Models/     Ticket, TicketKind, RailBrand, SeededRandom
│   └── Store/      TicketStore (JSON + photo files), samples
├── TicketArt/      TicketCard (matted photo) + studioFrame + fallback plate
├── Features/
│   ├── Timeline/   magazine timeline
│   ├── Detail/     single-ticket stage
│   ├── Capture/    camera, gate animation, confirm sheet
│   └── Recognition/ Vision OCR + RouteDetector + StationIndex + parser
├── Components/     shared custom controls
├── Resources/      stations.json (bundled gazetteer)
└── Shaders/        Metal: grain, holo sheen, scan, ink dissolve
```

The hero everywhere is the **real photographed ticket** (matted, studio-lit);
the data-drawn plate is the fallback for tickets without a photo. Route
detection uses OCR geometry + a bundled station gazetteer — see
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
