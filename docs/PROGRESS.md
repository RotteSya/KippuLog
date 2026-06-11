# Progress

Running build log. Newest first.

## 2026-06-11

- [x] Scaffold: hand-written pbxproj (objectVersion 77, synchronized
      folders, 3 targets), shared scheme, builds & runs on iPhone 17 sim.
- [x] Design tokens: paper/ink palette (`Ink`), Mincho/Gothic type system
      (`Typo`), CoreHaptics vocabulary (`Haptic`).
- [x] Models: `Ticket`, `TicketKind`, `RailBrand` (20 operators with
      lattice tints), `SeededRandom`.
- [x] Store: JSON + photo-file persistence, month grouping, UI-test hooks,
      8 sample journeys (2025-08 → 2026-06).
- [x] TicketArt studio renderer (MARS + edmondson, lattice, punch,
      print typography) — verified at hero/catalog sizes.
- [x] Magazine timeline — global alternating rhythm, scroll parallax +
      paper tilt, month headers, colophon, empty state, light-sweep
      highlight for fresh tickets, drag & drop import.
- [x] Studio stage — zoom transition, tilt + holo sheen, flip to photo
      (見本 stamp for samples), paging w/ zoom-source handoff, pinch
      dismiss, memo editing, edit sheet, share card, ink-dissolve delete.
- [x] Capture — camera service (live quad, auto-capture), guide overlay,
      perspective flatten, 改札 gate ceremony (squish shader + punch
      haptic), ja-JP OCR + parser (9 unit tests), reveal flip, confirm.
- [x] Shaders: paperGrain, holoSheen, scanSweep, inkDissolve, gateSquish.
- [x] App icon (scripts/generate_icon.swift), launch fade-in.
- [x] Final verification sweep — full suite green (9 unit + 8 UI tests:
      launch, stage walk, capture e2e with real OCR, empty state, memo,
      edit sheet, delete dissolve, pinch dismiss, punch-button gate);
      dark-mode gate/confirm/timeline checked by screenshot; icon on
      home screen; persistence across launches confirmed.

### Decisions

- Tickets re-rendered from data, photo kept on the back (museum-catalogue
  model) — see DESIGN.md.
- JSON store over SwiftData: inspectable, migration-free, tiny.
- 入場券 renders as edmondson card; all else MARS stock.
- No audio; haptic-only theatre.
