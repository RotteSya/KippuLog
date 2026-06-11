# Design Language

きっぷログ is a quiet, premium object: a magazine of journeys, printed on
paper and lit like a studio still-life. Everything below is in service of
two materials — **paper** and **ink** — and one ceremony: the punch of a
ticket gate.

## Principles

1. **Show the real ticket, framed like a catalogue.** The hero everywhere
   is the user's own photographed 切符 — matted on paper, tight-cropped,
   under one consistent studio light (`TicketCard` → `MattedPhoto`). The
   app *reads* the ticket to fill in the journey (route, date, fare), but
   it never replaces the photo with a synthetic drawing. The rendered
   plate (`TicketArtView`) survives only as the fallback for tickets with
   no photo — the sample collection and manual entries — wearing the
   identical `studioFrame` so plate and photo sit side by side as one shoot.
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
   hairline rules, generous margins.

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

`TicketCard` is the one way a ticket appears as an object. A captured
ticket shows its **real photo**, matted (`MattedPhoto`): tight on a thin
paper border that matches the plate stock, hairline edge, clamped to its
natural aspect so a panorama or tall crop can't break the page. A ticket
with no photo falls back to the rendered plate below. Both wear the same
`studioFrame`.

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

## Motion vocabulary

| Moment | Treatment |
|---|---|
| timeline → detail | zoom transition; the photo settles under the lamp |
| detail | the real photo, tilt for gloss + table reflection; facts on the 半券 stub |
| detail browse | horizontal paging, cards swap with bouncy springs |
| detail dismiss | pinch-out or drag; card returns to its shelf |
| capture | 改札 reader head (machined bevel, marching shu chevrons): the ticket leans back, feeds, squishes, gets bitten |
| reveal | the punched scan settles into its studio mat; the form-desk rises |
| delete | ink dissolve shader — the ticket scatters to sumi dust |
| scroll | subtle parallax + light sweep across cards |

## Haptics

`Haptic.Effect`: tick (paper), punch (gate clack + after-knock), stamp
(press + settle), success (rising pair), page (notch). No audio — the
phone stays polite.
