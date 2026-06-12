# Progress

Running build log. Newest first.

## 2026-06-12 — borderless objects + true zoom

X-feedback pass two: the photo mat read as a cheap frame, the zoom didn't
zoom, the inspector didn't exist.

- [x] Quad selection peels shadow halos (nested ≥55% candidate wins) and
      insets corners 1.2% — zero background slivers; fare OCR improved.
- [x] Subject lift (VNGenerateForegroundInstanceMask) when the quad
      fails → alpha-PNG cutout, the ticket's silhouette on the page.
- [x] TicketCard v2: cutout / borderless scan (edge catch-light, no
      strokes) / plate. MattedPhoto deleted. Image cache + save-time
      downscale.
- [x] Zoom: source moved onto the card alone; pinch-to-open timeline
      cards; PhotoInspector (UIScrollView 1–5×, double-tap, drag-down,
      layoutSubviews-driven fit).
- [x] Confirm reveal = lift (frame recedes/blurs, ticket rises).
- [x] Fixtures generator (straight + angled-on-clutter), new UI tests
      (inspector, pinch-open, angled e2e). Full suite green; light+dark.

## 2026-06-12 — photo-first + OCR accuracy

The rendered plate looked wrong whenever OCR missed, and the user's real
ticket was hidden. Pivoted: **the photographed ticket is now the hero**;
the plate is a fallback. Route parsing rebuilt on geometry + a station
dictionary.

- [x] Station gazetteer: `scripts/build_stations.swift` distills
      piuccio/open-data-jp-railway-stations → `Resources/stations.json`
      (8,460 names, 126 KB, no runtime network). `StationIndex` loads it
      lazily; `snap()` = exact + edit-distance-1 (柬京→東京), strips 駅,
      accepts 市内/区内 fare zones, exact-only for 1-char.
- [x] `TicketRecognizer.recognizeLines` returns `OCRLine` (text + box);
      quad detection widened. `RouteDetector`: same-line separators
      (expanded), から…まで, whitespace pair, same horizontal band,
      stacked lines — each candidate gazetteer-validated; katakana ー /
      table bars guarded. Parser delegates the route branch.
- [x] `TicketCard`/`TicketCardContent` + `MattedPhoto`: the real photo on
      a paper mat, clamped natural aspect, shared `StudioFrame`
      (extracted from `TicketPlate`). `photoAspect` persisted on `Ticket`.
- [x] Timeline / stage / edit / share / confirm swapped to the card.
      Stage flip-to-art removed (hero is the photo); confirm reveal is a
      scan→mat settle; `TicketBackFace` deleted.
- [x] 21 tests green incl. 2 real-Vision-OCR integration tests (render
      plate → OCR → assert route) + geometry/snap unit cases. Verified in
      sim: confirm fields all correct (東京/新大阪/¥14,720/のぞみ31号),
      photo card in timeline beside sample plates, photo hero on stage,
      light + dark.

## 2026-06-11 — design elevation pass

- [x] Plate v2: `ticketPaper` single-pass paper physics (guilloche
      underprint, mottle, fibres, edge darkening), `inkPress`
      letterpress relief, watermark marks, crescent hole relief, MARS
      arrow redrawn. All decorative gradients deleted.
- [x] Timeline v2: hanko masthead + thick-thin rules, kanji month
      headers with shu tick + 枚数, chronological catalogue numbers,
      baseline-aligned route/fare, custom punch-glyph button, blank
      guilloche stock empty state.
- [x] Stage v2: `studioLight` dithered light pool, table reflection,
      facts re-set as perforated 半券 stub (shares the plate's serial),
      旅の記 memo block, settle-in & cardstock flip dip.
- [x] Capture v2: machined reader head with marching chevrons, lean-in
      feed, studio-lit reveal over a rising paper desk, 判子 kind
      stamps, dotted printed-form rules.
- [x] Full suite re-verified green (9 unit + 8 UI); light/dark sweeps.

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
