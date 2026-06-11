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
- [ ] TicketArt studio renderer
- [ ] Magazine timeline
- [ ] Detail stage (tilt, flip, paging, pinch-dismiss)
- [ ] Capture + gate animation + OCR parse + confirm sheet
- [ ] Shaders: grain, holo, scan, ink dissolve, gate squish
- [ ] App icon, polish, full simulator verification

### Decisions

- Tickets re-rendered from data, photo kept on the back (museum-catalogue
  model) — see DESIGN.md.
- JSON store over SwiftData: inspectable, migration-free, tiny.
- 入場券 renders as edmondson card; all else MARS stock.
- No audio; haptic-only theatre.
