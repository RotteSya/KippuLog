# Architecture

Zero dependencies. Swift 6, MainActor-by-default isolation
(`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`); recognition work hops off
the main actor explicitly.

## Data flow

```
photo (camera / library / drop)
   → TicketRecognizer (Vision OCR, ja-JP, off-main)
   → TicketParse (stations, date, price, train, seat, kind, brand)
   → confirm sheet (user edits)
   → TicketStore.add(ticket, photo)
   → tickets.json + photos/<uuid>.jpg   (Application Support/KippuLog)
```

`TicketArtView` renders purely from `Ticket` fields — art is never stored,
always re-drawn (resolution-independent, theme-proof, shader-friendly).

## Modules

- **Core/Models** — `Ticket` (value type, Codable), `TicketKind`,
  `RailBrand` (operator → lattice tint, mark, paper warmth),
  `SeededRandom` (SplitMix64; print quirks are stable forever).
- **Core/Store** — `TicketStore`, `@Observable`, owns the JSON file and
  photo directory. Sorted newest-first; `monthGroups` powers the
  timeline. Launch args: `-uiTestReset` wipes, `-uiTestSeedSamples`
  seeds 8 sample journeys.
- **TicketArt** — pure-SwiftUI plate renderer + studio presentation
  (shadow, rotation, grain/holo shaders).
- **Features/Timeline** — magazine scroll, month sections, glass bottom
  bar, empty state.
- **Features/Detail** — studio stage, tilt + flip, paging, edit, share,
  delete.
- **Features/Capture** — AVFoundation camera with rectangle detection +
  perspective crop, library import fallback, gate animation, confirm
  sheet.
- **Features/Recognition** — `TicketRecognizer` (Vision) +
  `TicketTextParser` (regex heuristics for Japanese ticket text).
- **Shaders** — `Tickets.metal`: paperGrain, holoSheen, scanSweep,
  inkDissolve, gateSquish.

## Testing

- `KippuLogTests` — Swift Testing; parser cases, store round-trip.
- `KippuLogUITests` — XCUITest; walks timeline → detail → capture;
  screenshots captured via `simctl` during development.

## Project file

Hand-written `project.pbxproj`, objectVersion 77 with
`PBXFileSystemSynchronizedRootGroup` — folders are the build phases; no
file lists to maintain. Explicit shared scheme in
`xcshareddata/xcschemes` (auto-generation doesn't fire for hand-made
projects).
