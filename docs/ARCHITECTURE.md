# Architecture

Zero dependencies. Swift 6, MainActor-by-default isolation
(`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`); recognition work hops off
the main actor explicitly.

## Data flow

```
photo (camera / library / drop)
   → TicketRecognizer.flatten + recognizeLines  (Vision OCR + boxes, off-main)
   → RouteDetector (geometry + StationIndex gazetteer) → 発駅/着駅
   → TicketTextParser (date, price, train, seat, kind, brand)
   → confirm sheet (user edits)
   → TicketStore.add(ticket, photo)  (computes photoAspect)
   → tickets.json + photos/<uuid>.jpg   (Application Support/KippuLog)
```

The **real photo is the object** the app shows (`TicketCard` →
`MattedPhoto`). `TicketArtView` is the data-drawn *fallback* for tickets
with no photo (samples, manual entry); art is never stored, always
re-drawn. Both share `studioFrame`.

## Modules

- **Core/Models** — `Ticket` (value type, Codable), `TicketKind`,
  `RailBrand` (operator → lattice tint, mark, paper warmth),
  `SeededRandom` (SplitMix64; print quirks are stable forever).
- **Core/Store** — `TicketStore`, `@Observable`, owns the JSON file and
  photo directory. Sorted newest-first; `monthGroups` powers the
  timeline. Launch args: `-uiTestReset` wipes, `-uiTestSeedSamples`
  seeds 8 sample journeys.
- **TicketArt** — `TicketCard`/`TicketCardContent` (photo or fallback) +
  `MattedPhoto`, the shared `studioFrame`, and the data-drawn plate
  renderer (grain/holo/letterpress shaders).
- **Features/Timeline** — magazine scroll, month sections, glass bottom
  bar, empty state.
- **Features/Detail** — studio stage (photo hero, tilt + reflection),
  paging, edit, share, delete.
- **Features/Capture** — AVFoundation camera with rectangle detection +
  perspective crop, library import fallback, gate animation, confirm
  (mat-settle reveal + form).
- **Features/Recognition** — `TicketRecognizer` (Vision OCR + boxes,
  quad/flatten), `RouteDetector` (geometry + gazetteer station pairing),
  `StationIndex` (bundled `Resources/stations.json`, exact + edit-distance-1
  snap), `TicketTextParser` (date/price/train/seat/kind/brand).
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
