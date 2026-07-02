# Design Language

きっぷログ is a quiet, premium object: a magazine of journeys, printed on
paper and lit like a studio still-life. Everything below is in service of
two materials — **paper** and **ink** — and one ceremony: the punch of a
ticket gate.

## Principles

1. **The ticket is the object — never framed, never boxed.** The hero
   everywhere is the user's own photographed 切符, presented as the thing
   itself: halo-peeled, scanner-tight perspective crop shown full-bleed
   with a paper-thickness edge light (`ScanObject`), or — when the photo
   carries background — the subject-lifted silhouette resting directly on
   the page, its shadow tracing its own alpha. No mats, no strokes, no
   borders. And always reading right side up: EXIF is baked at
   acquisition, and every scan/cutout is righted by the print itself
   (each OCR line's glyph-run vector votes; `rightSideUp`), however the
   photo was held. The app *reads* the ticket to fill in the journey but never
   replaces the photo with a drawing; the rendered plate (`TicketArtView`)
   survives only as the fallback for photo-less tickets (samples, manual
   entries), wearing the identical `studioFrame`.
2. **One accent.** 朱 (vermilion, `#D8401F`) appears only where the app
   acts: the punch button, live markers, the era stamp. Everything else is
   paper and sumi ink.
3. **The room dims, the ticket doesn't.** Dark mode dims surfaces; ticket
   paper stays paper. A hero ticket always sits in a near-black studio.
4. **Motion is physical.** Springs over curves. Tickets tilt, slide
   through gates, dissolve into ink. Every flourish maps to something a
   ticket could physically do.
5. **Editorial, not utilitarian.** The timeline reads like a travel
   magazine's table of contents: kanji month headers, serif figures,
   hairline rules, generous margins. The page runs out into paper at
   its edges (`PaperFade`) — type never collides with the clock above
   or the punch below.
6. **No false affordances.** Nothing suggests an interaction it doesn't
   honour: no sheet grabbers on desks that don't drag, no control ever
   sliced off at a screen edge — all six kind stamps share the row as
   equals on every width of phone.

## Palette

| Token | Light | Dark | Use |
|---|---|---|---|
| `Ink.background` | `#F7F3EB` 生成り | `#171411` | app surface |
| `Ink.backgroundDeep` | `#EFE9DC` | `#1F1B16` | recessed wells |
| `Ink.studio` | `#14110E` | same | hero backdrop |
| `Ink.text` | `#26211B` | `#EDE6DA` | primary |
| `Ink.textSoft` / `textFaint` | greys, warm | | secondary / captions |
| `Ink.shu` | `#D8401F` | same | the single accent |
| ticket papers | constant | constant | cream MARS, buff edmondson |

Brand lattice tints live on `RailBrand.patternHex` (JR East teal, JR
Central orange, JR West blue, private-rail hues) — printed at low contrast
over cream paper, like real security patterns.

## Type

- **Wordmark / stations / headers:** Hiragino Mincho ProN (W6, W3) with
  wide tracking.
- **Labour text / ticket faces:** Hiragino Sans (W3, W6). Ticket faces use
  full-width numerals (２２５号) like real MARS prints.
- **Editorial figures & latin captions:** New York (`.serif`) for numbers,
  SF tracked caps for captions ("JUNE 2026").

## The studio system (TicketCard)

`TicketCard` is the one way a ticket appears as an object, in priority:
the **subject-lifted cutout** (the ticket's true silhouette, alpha-masked),
the **borderless scan** (halo-peeled quad, corners inset 1.2%, full-bleed
with a top edge catch-light), or the rendered plate for photo-less
tickets. All wear the same `studioFrame`. Tap the stage hero for the
full-screen `PhotoInspector` (pinch 1–5×, double-tap, drag-down); pinch a
timeline card outward to zoom into its stage.

### The fallback plate (TicketArt)

Rendered purely from data — used only when there is no photo:

- **MARS plate** (85 × 57.5 ratio): brand lattice over cream, top title
  row, large station route line, date/train/seat rows, fare, bottom serial
  + issuing box. Square-ish corners (1mm).
- **Edmondson plate** (57.5 × 30.5) for 入場券: buff card, centered
  station, fare boxed, red serial.
- **Deterministic quirks** from `styleSeed`: serial numbers, guilloche
  phase, punch-hole position jitter — every ticket individually printed,
  identically styled.
- **Paper physics (`ticketPaper` shader, one pass):** pulp-density
  mottle, tooth speckle, grain-axis fibre flecks, a braided
  counter-phase sine guilloche underprint in the operator's tint, and
  cut-edge darkening. No overlay gradients anywhere.
- **Letterpress (`inkPress` layerEffect):** every glyph's leading edge
  pools a hair darker, its trailing edge catches a hairline of light —
  the print sits *in* the paper.
- **Studio presentation:** contact + ambient key shadows (one elevation
  system), seeded resting rotation, gloss-first `holoSheen` that answers
  tilt with spectral fringes only at strong angles.
- **The dark room (`studioLight`):** a dithered warm pool of light —
  never flat black, never banded. Hero tickets cast a faint table
  reflection that fades as they lift.

## The opening ceremony (first launch only)

開幕 — the house lights dim over the paper page, a lamp catches, the
wordmark presses in glyph by glyph, the hanko stamps (ink-bloom ring),
and a ticket machine prints a 見本 in nine line-feeds: guilloche stock,
「ここから → どこまでも」, fare printed as ¥＊＊＊＊, a diagonal 見本
strike in 朱. The gate punches it (the chad tumbles out), the ticket
drops into the hand — it tilts, gloss answering — and the two exits are
the app's whole pitch: 最初の一枚を撮る, or まずは見てまわる. Either
way the specimen dives into the punch button (which pops once): the
ticket itself teaches where the gate lives.

Rules: runs once (`hasWelcomed`); any tap skips to the settled scene;
Reduce Motion opens settled; the engine is Core Animation on one
CADisplayLink clock (`Features/Welcome/`) — SwiftUI above carries only
the words and buttons. The launch screen wears `LaunchBackground`
(生成り / dark studio) so the app never flashes white before the show.

## Motion vocabulary

| Moment | Treatment |
|---|---|
| first launch | the opening ceremony above; lights-up hands off to the masthead, whose seal stamps in once per session |
| open capture | no system slide — the studio dims in over the page (0.38s), the same lights that opened the app |
| leave capture | lights up over a shelf already walking to the fresh plate; the punched-in sweep lands as the paper returns |
| timeline → detail | zoom transition; the photo settles under the lamp |
| timeline ⇄ 収蔵帳 | pinch the magazine closed → the year album (kraft spreads, photo-corner mounts, month slips); pinch open to return |
| detail | the real photo, tilt for gloss + table reflection; facts on the 半券 stub |
| detail browse | horizontal paging, cards swap with bouncy springs |
| detail dismiss | pinch-out or drag; card returns to its shelf |
| viewfinder | one living guide, three acts: corner grips breathe around a MARS window → fly onto the detected ticket's corners (veil re-cuts itself around the quad, one animatable `Quad4` drives every shape) → a vermilion loop draws from the top centre both ways across the hold-still window and seals as the gate fires; the shutter dial mirrors the same clock |
| capture moment | white blink, the frame freezes, the room goes near-black around the ticket — flatten and orientation work under the cover |
| capture | 改札 reader head (machined bevel, marching shu chevrons): the ticket rises from below the frame, leans back, feeds, squishes, gets bitten — the head flinches and the punched chad flutters out of the slot |
| handoff | after the reading light, the ticket glides onto `ConfirmStage` — the one geometry the reveal also reads — settles completely, and the confirm arrives `.identity` under the fading chrome: a held object, never a crossfade dip. One `StudioBackdrop` (Animatable) lights all three phases; the lamp swings, rooms never crossfade |
| reveal | the raw frame recedes and blurs; the ticket lifts into the lamp; the form-desk rises from fully below the frame |
| keyboard | the ticket steps aside; the desk takes the whole room; save never sinks below the keys |
| delete | 改札回収 — the card tears into strips that flutter and fall (shredFall layerEffect) |
| scroll | subtle parallax + light sweep across cards |

## Haptics

`Haptic.Effect`: tick (paper), punch (gate clack + after-knock), stamp
(press + settle), success (rising pair), page (notch). No audio — the
phone stays polite.
