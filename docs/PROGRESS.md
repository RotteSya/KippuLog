# Progress

Running build log. Newest first.

## 2026-07-03 — 持ち上げ: one engine, three flights; the collector's stock

The navigation stack left the reading flow. `LiftEngine` (a
CADisplayLink spring publishing raw per-frame values — SwiftUI only
prints them) owns every journey as one continuous shot:

- [x] OPEN — tap a card: it peels off the page top-edge-first (−7°
      settling flat), the room dims around it as it rises into the
      lamp, the stage mounts the frame it seats on identical pixels,
      chrome and captions follow a breath later.
- [x] CLOSE — facts dissolve, the lamp lets go, the lone ticket lays
      itself back down onto its printed place (album mounts land at
      their seeded tilt).
- [x] SAVE — the desk withdraws, the capture room lets go, and the
      fresh ticket sails down into the slot the page had already
      turned to beneath the cover; the studio light sweeps it in.
- [x] Flights chase their slot LIVE each tick (fresh rows settle
      under a flight — the ticket lands where the slot ends up, not
      where it stood at take-off). Settle detector + 1.4s hard
      ceiling; NSObject-backed for the display-link selector.
      Probes: -uiTestProbeReturn / -uiTestProbeSave.
- [x] The collector's stock (`ticketPaper` material/age): coated MARS
      reels (tight tooth, faint calender lines), edmondson card
      (heavy fibre, guillotined edge), private-rail pulp (warm cast,
      tea-and-rust recycled flecks) — and age from travelDate: the
      print fades a step, edges yellow inward, corners soften. All
      deterministic per ticket; stubs/kraft/blanks stay plain.
- [x] holoSheen grew a cut-edge rim: paper thickness catches the lamp
      on whichever side the hand raises — no caller changes.
- [x] Full suite green; open/close/save dissected frame-by-frame.

## 2026-07-02 (night) — the rail, the slip, and the sinking ticket

Answering "generic motion, awkward layout": the last system-feeling
moments on the stage are gone, and the stage's column breathes right.

- [x] StageRail (`Features/Detail/StageRail.swift`): the stage's pager
      is no longer a system TabView — it's a shelf rail driven by a
      CADisplayLink spring. One continuous `position` is the whole
      truth; your finger owns it directly (interrupt anything mid-
      flight), cards lean slightly away on a perspective rail,
      neighbours recede a step out of the lamp, the flick projects to
      a notch, and the notch is a haptic. Three recycled hosting seats
      carry the SwiftUI furniture; the camera is pure UIKit/CA.
      LESSON: `withAnimation` does NOT interpolate across a
      UIHostingController boundary — the shred jumped 0→1 invisibly
      until the page took its own `.animation(value:)` clock inside
      the hosted tree.
- [x] 改札の問い (`DeleteSlip`): the delete confirm is a paper slip
      with a torn top edge sliding onto the desk — 手放す in shu,
      やめる in hairline — not a system dialog. The room dims a step
      while the question stands.
- [x] Saving sinks the ticket: on コレクションに追加 the desk
      withdraws, the ticket drifts down toward the book and fades as
      the lights come up on a shelf already walking to the fresh
      plate — one motion from form to page.
- [x] Stage layout trued up: the memo now shares the stub's column
      (one margin system below the exhibit); the table reflection is
      foreshortened (0.62) and dissolves by a third of its height — a
      sheen at the card's foot, never a dark band; vertical rhythm
      rebalanced (64/52/38/36).
- [x] Full suite green; rail drag, shred, slip, save-sink, and both
      returns dissected frame-by-frame from recordings.

## 2026-07-02 (evening) — the ticket comes home; the cover grows doors; 1.0.1 ships

- [x] The zoom RETURN was the last "AI-slop" seam: closing a ticket
      shrank the whole dark stage into a shelf slot (screenshot-
      minimizing-with-white-veil, caught by video-frame dissection via
      the new `-uiTestProbeReturn` rig). Now departure is staged —
      facts dissolve, the lamp goes out riding into the pop, and the
      navigation container behind the studio is the same paper as the
      page beneath: the system pop shrinks a paper window over a paper
      page, so the only visible motion is the lone lit ticket springing
      home. Works identically from 誌面 and 収蔵帳 (which now scrolls
      its spread during stage paging so the slot is there to catch it).
      A full custom overlay-flight engine (FlightBoard) was built,
      outclassed by this simpler cut, and removed.
- [x] The cover grew its two doors — 収蔵帳 / 奥付 in hairline-box small
      print (the album mirrors: 誌面 / 奥付). The pinch remains the
      connoisseur route; the colophon still whispers it.
- [x] 奥付 — the colophon page holds the settings, in the paper voice:
      あしらい (おまかせ/紙/夜, three kind-stamps; sheets re-apply the
      scheme themselves), 見本の旅 (lay out / tidy away), 開幕をもう一度,
      しるべ (support / privacy / letter to the editors), and the
      imprint (seal, figures, 第 N 版). OkuzukeTests walk every door.
- [x] 1.0.1 shipped: version created, build 5 archived/exported/
      uploaded via asc, What's New in the quiet voice, and the deferred
      URL flip executed (support/marketing on the version localization
      + privacyPolicyUrl on app-info now point at
      rottesya.github.io/KippuLog). Validation clean; submitted —
      WAITING_FOR_REVIEW (submission 36bb7a76).

## 2026-07-02 — 開幕: the machine prints your first ticket

Round two of the "looks AI-generated" rebuttal — this time the missing
opening, the seams between rooms, and the flaws only full-res
screenshots confess.

- [x] The welcome ceremony (`Features/Welcome/`): first launch dims the
      house lights over the paper page, a lamp catches (filament
      flicker), きっぷログ presses in glyph by glyph, the hanko stamps
      with an ink-bloom ring, and a ticket machine prints a 見本 in nine
      line-feeds — punches it (chad tumbling out), releases it into the
      hand to tilt and admire (gloss answering), then the specimen dives
      into the punch button and the lights come up on the live page.
      Both exits (最初の一枚を撮る / まずは見てまわる) verified e2e;
      never replays; tap skips; Reduce Motion lands settled.
- [x] The engine is pure Core Animation on one CADisplayLink clock —
      a single `evaluate(t)` timeline (no scheduled springs), so the
      show is deterministic and scrubbable. The specimen face is
      CoreGraphics: counter-phase guilloche bundles, pulp mottle, fibre
      flecks, letterpress rows, full-width numerals, a diagonal 見本
      strike in 朱 — the same paper physics as the Metal plates.
- [x] Launch wears the paper: `UILaunchScreen` color asset (生成り /
      dark studio) kills the white flash; the Info.plist merges via
      INFOPLIST_FILE + a synchronized-folder membership exception.
- [x] The gate→confirm handoff is now one held object: `ConfirmStage`
      is the single geometry both the gate's final glide and the reveal
      read; the confirm inserts with `.identity` under the fading gate
      chrome (no luminance dip, no jump — pixel-diff verified). One
      `StudioBackdrop` (now `Animatable`) lights all three capture
      phases; the lamp swings, rooms never crossfade.
- [x] Entering/leaving capture is light, not a card: the cover presents
      with no system slide; the studio dims in over the page (0.38s)
      and lights up on save while the shelf walks to the fresh plate.
- [x] Flaws full-res screenshots confessed, fixed: the stage
      reflection's mask ran backwards (ghosted the stub — now a real
      mirror, gone by 44%); timeline text collided with the clock and
      the punch button (PaperFade edges); the kind chips overflowed —
      その他 was *entirely off-screen* on 402pt phones (six equal
      stamps now); the confirm desk wore a sheet-grabber it didn't
      honour (removed).
- [x] The masthead seal stamps in once per session (ink-bloom, stamp
      haptic); the colophon seal answers a touch with a fresh press.
      Empty state wears the masthead — the cover exists before the
      first ticket.
- [x] Full suite green (unit + 15 UI tests, incl. two new welcome
      walks); light/dark sweeps; burst-frame verification of welcome,
      exit, capture entrance, gate handoff.

### Decisions

- The welcome is UIKit/CA, not SwiftUI springs — cinematic timing wants
  one master clock. SwiftUI above supplies only copy and buttons.
- `-uiTestReset` marks the ceremony as seen (walk tests start on the
  shelf); `-uiTestWelcome` forces it; `-uiTestWelcomeAutoExit` drives
  the exit for screenshot bursts.
- The specimen face is drawn in CG (not ImageRenderer of the SwiftUI
  plate) — Metal colorEffects don't rasterize offscreen reliably, and
  the engine wants a bitmap it owns.

## 2026-06-12 — the viewfinder lives, the scan reads, the frames hold

Answering the "looks AI-generated" pile-on: the boring capture screen,
sideways vertical photos, and animation seams — all three, at the root.

- [x] Orientation, twice over. `normalized()` bakes EXIF rotation into
      pixels at acquisition (the whole Vision pipeline was reading camera
      and library photos sideways); `rightSideUp()` then rights any scan
      that still reads wrong. Vision OCRs rotated text happily, so
      confidence can't vote — instead each recognized line's tight quad
      (`boundingBox(for:)`) runs along its own glyphs, and the weighted
      net of those vectors is the verdict: one small OCR pass decides
      0/90/180/270 with a ~250× margin on fixtures. Applied to tight
      scans, cutouts, manual re-crops; conservative thresholds for raw
      photos. Vertical + upside-down fixtures e2e in the suite.
- [x] The living viewfinder (CaptureViewfinder): one guide system in
      three acts — corner grips breathe around a MARS window; on
      detection they fly onto the ticket's actual corners while the dim
      veil re-cuts itself around the quad (all shapes share one
      animatable `Quad4`, so veil, grips and loop morph in lockstep);
      holding still draws a vermilion loop from the top centre both ways,
      sealing exactly as the gate auto-fires — the shutter dial mirrors
      the same clock. Capture = white blink + frozen frame + the room
      going near-black while flatten works. Studio vignette over the
      live feed; microcopy answers state (切符を枠のなかへ → そのまま…).
      Lock-on tick haptic; detection flicker damped by a 450ms grace.
- [x] Camera truths: the session now *restarts* after a retake
      (`start()` early-returned on `availability == .ready` — the
      preview came back frozen, forever); steadiness is published as
      `steadySince` so the UI draws the real countdown.
- [x] Gate ceremony, physical: enters from below the frame; the scan
      keeps its own aspect (no more force-cropping Edmondsons into MARS
      proportions); the head flinches 2pt at the bite and the punched
      chad flutters out of the slot (KeyframeAnimator tumble, seeded to
      the hole's x); choreography is cancellation-safe.
- [x] The handoff: after the sweep the ticket glides to the exact spot
      ConfirmTicketView's reveal occupies (stage negotiation mirrored:
      38pt + min(250, h/2−64) stage), the confirm raw frame wears the
      same punch hole, and the phase change crossfades under an explicit
      `withAnimation` — the implicit container animation was dropping
      the removal side, leaving a black frame between gate and confirm
      (caught frame-by-frame via simctl burst). The hole heals inside
      the lift; the desk starts fully below the frame (640pt).
- [x] Viewfinder rehearsal screen (`-uiScreen viewfinder`): synthetic
      desk scene under the real chrome, acts advance on tap so
      screenshots anchor to state — the simulator has no camera.
- [x] 46 tests green (vertical/upside-down e2e, viewfinder acts walk,
      full capture walk re-verified; handoff and chad confirmed by
      simctl frame bursts).

## 2026-06-12 — boundaries you can trust + the 収蔵帳

- [x] Boundary precision (informed by Mercari listing conventions):
      centre-weighted quad choice among near-equal candidates, double-pass
      flatten shaves one-sided shadow residue, cutout solidity ≥70%
      rejects mounted hands. Set-photo + offset-shadow fixtures assert
      the crop by aspect.
- [x] The last word is manual: 切り取りを直す opens a corner editor
      (drag four glass handles over the original, outside dimmed,
      re-crop at zero inset, re-OCR fills only untouched fields).
- [x] 収蔵帳: pinch out of the magazine into year spreads on kraft —
      serif year + 旅 hanko + totals, photo-corner mounted minis with
      seeded tilt, pasted month slips (tap → that month in the
      magazine), minis zoom into the stage, pinch back. Thumbnail
      pipeline (420px disk+cache) keeps it silk. Light + dark.
- [x] 43 tests green (album walk, quad-editor walk, set-photo and
      shadow e2e included).

## 2026-06-12 — rage-quit pass three: recognition, keyboard, shred

- [x] OCR route detection survives real carnage: fused endpoints
      (東京都区内京都市内), keyword riders (乗車券東京), まで/ゆき strips,
      issuer-line exclusion, any-two-stations fallback by print height,
      zone city healing (東亰都区内→東京都区内), distance-2 snap for 4+
      chars with an OCR-lookalike confusion table (亰→京 beats 亰→上).
      Hard-mode fixture (soft-focus green stock, dim desk) passes e2e.
- [x] Keyboard choreography: focusing a field collapses the
      reveal/preview, the desk takes everything above the keys, save
      stays hittable (asserted in UITest). Preview springs key on kind —
      keystrokes schedule no animations.
- [x] Delete = 改札回収: shredFall layerEffect (13 hashed strips,
      gravity + flutter + shear, inked torn edges, late fade), punch +
      stamp haptics, page contents clear beneath. Mid-fall frames
      verified.
- [x] Full suite green; 30 unit + UI walks incl. keyboard-up confirm.

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
