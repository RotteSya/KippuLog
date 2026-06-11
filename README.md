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
├── TicketArt/      the studio renderer (MARS + edmondson plates)
├── Features/
│   ├── Timeline/   magazine timeline
│   ├── Detail/     single-ticket stage
│   ├── Capture/    camera, gate animation, confirm sheet
│   └── Recognition/ Vision OCR + Japanese ticket parser
├── Components/     shared custom controls
└── Shaders/        Metal: grain, holo sheen, scan, ink dissolve
```
