# Phase B — Effects Grid Parity (Pending Work)

Scope: the sequencer canvas the user spends 90 % of their time in —
the **effects grid**, **timeline ruler**, **waveform**, **row
headings**, and the **timing tracks** strip between them. Phase B and
B-Metal closed out the rebuild and the Metal render pipeline; this
sub-plan tracks the remaining authoring gaps vs desktop.

---

## Status (2026-04-21)

All original P0s closed, plus 20+ P1s landed across the 2026-04-20
and 2026-04-21 sessions. What remains is a short tail of P1 polish
+ a long tail of P2 nice-to-haves.

**Current counts:** 0 × P0, **6 × P1**, ~40 × P2, 1 × Verify,
1 × Deferred, 1 × Removed.

### What landed since the 2026-04-20 gap audit

- **Multi-select + align + split + playhead follow** — B1, B2, B5,
  B8, B9, B10, B11, B12, B14, B21, B31, B36, B37, B39, B93.
  Two-finger marquee, every align variant (start / end / both /
  centers / match / shift-start / shift-end / align-to-mark /
  close-gap), split-at-play-marker, exact-time dialog, zoom-to-fit
  / -selection, drag-to-scrub, follow-playhead, selection status
  readout.
- **Timing-mark editing** — B67, B68, B69, B70, B71, B72, B73.
  Long-press create, pan move / resize (snap to other marks),
  delete, rename, split, merge with next, add timing track.
- **Lyric rendering + breakdown** — B84 (phrase → words), B85
  (words → phonemes using the wx-free `PhonemeDictionary` ported
  to `src-core/lyrics/`), B87 (remove words/phonemes), B88
  (per-layer label colour coding), B78 (import lyrics sheet),
  B89 (auto-label marks).
- **Loop region + play-loop + render-selected** — B32, B33, B44,
  B45. Long-press on ruler sets region; menu has Play Loop /
  Render Loop Region / Clear Loop.
- **Waveform filters** — B41. Long-press on waveform → Full Range
  / Bass / Treble / Alto / Non-Vocals picker via
  `AudioManager::GetFilteredAudioData`.
- **Row-heading expansion** — B46 (rename layer), B50 (delete all
  effects on row), B51 (enable / disable render on model), B52
  (select all effects in model), B53 / B54 (cut / copy row +
  model), B57 (expand / collapse all), B61 (drag-resize header
  column width), B65 (tooltip on truncated row names).
- **Multi-effect clipboard + keyboard editing** — B4 (shift /
  ctrl / alt arrow stretch + nudge), B98 (relative-timing
  clipboard).
- **Subdivided timing tracks** — B80 (1/2 .. 8× submenu).
- **`.xtiming` I/O** — B74 import, B75 export.
- **Hover states** — B30. `.hoverEffect` on SwiftUI row-header
  controls + `UIHoverGestureRecognizer` on the Metal grid for
  Magic Keyboard pointer users.
- **Scroll polish** — B95 (trackpad / wheel).

### What's still open

- **One P1 cluster**: Tags (B34 numbered markers + B35 tag context
  menu) — the last piece of the loop-region / tags / render
  bundle.
- **Scattered P1s**: B15 randomize / reset (needs metadata-default
  plumbing), B19 effect-presets menu stub (Phase C storage), B49
  export-model (file I/O), B94 visible scrollbars (custom Metal
  overlay).
- **P2 polish** — ~40 items across editing, visual, row-heading,
  timing, scroll, find, clipboard.

**Out of Phase B:** B16 (drag-from-palette with ghost) deferred
pending user feedback; tap-to-arm + tap-to-place is working well
in practice. B26 (ColorCurve gradient) awaits a device-side verify
— the `DrawEffectBackground` path is already wired so this may
already work. B86 (Breakdown Phoneme) removed; not a real desktop
feature.

---

## 1. Effects grid canvas

### 1.1 Selection

- **Gap B3 — Tab-to-next-effect.** Hardware keyboard only. Arrow
  keys already move selection row-ward and column-ward; Tab /
  Shift+Tab aren't bound. **P2.**

### 1.2 Editing — positional

- **Gap B6 — Nudge by timing mark.** Ctrl+PageUp / Ctrl+PageDown
  moves selection forward / back one active mark. **P2.**
- **Gap B7 — Edge-unlink indicator + unlink command.** Desktop
  tags an effect edge that's been "unlinked" from its neighbour
  so paste / align won't re-butt them. **P2.**

### 1.3 Editing — range / bulk

- **Gap B13 — Extend effect to next / previous.** Keyboard-only
  on desktop; handy. **P2.**
- **Gap B15 — Randomize selected / Reset to default.** Bulk-edit
  flavours blocked on metadata defaults integration. Lock-all /
  Disable-all already landed with B1. **P1.**

### 1.4 Create / drop

- **Gap B17 — Random effect palette button.** Palette is explicit-
  choose only. **P2.**
- **Gap B18 — Double-click-to-create in selected range.** Power-
  user shortcut. **P2.**

### 1.5 Context menu entries

- **Gap B19 — Effect Presets submenu.** Save / load / apply named
  effect preset bundles. Full feature is Phase C / G12 territory;
  the grid entry-point menu item lands here. **P1.**
- **Gap B20 — Description field.** Free-text note stored on the
  effect, rendered as tooltip. **P2.**
- **Gap B22 — Reset effect.** Revert the effect's settings to
  type defaults (single-effect variant of B15). **P2.**
- **Gap B23 — Duplicate across models.** Desktop's `Copy Settings
  To N Models`. **P2.**
- **Gap B24 — Find Possible Source Effects.** Node-level search
  for effects that could have produced the data in the selected
  effect. Rare. **P2.**

### 1.6 Visual polish

- **Gap B25 — Bracket colours sourced from `ColorManager`.** iPad
  hardcodes bracket RGB (`EffectsMetalGridView.swift:292–295`);
  desktop sources from `ColorManager::COLOR_EFFECT_DEFAULT /
  _SELECTED / _LOCKED / _DISABLED` so user-customised palettes
  round-trip. Route iPad through the existing bridge. **P2.**
- **Gap B26 — Colour-curve / gradient preview inside effect bar.**
  **Verify only** — 14 effects override `DrawEffectBackground`
  (Color Wash, On, Morph, Galaxy, Shockwave, Fan, Twinkle,
  Pictures, Fireworks, Ripple, etc.) and BM-6 already runs that
  pass. Needs a device-side check with a known ColorCurve
  sequence to close.
- **Gap B27 — Node-level colour-channel stripes.** Desktop paints
  thin per-channel stripes on node-level effects for multi-channel
  models (RGBW etc.). **P2.**
- **Gap B28 — Reference / previous-selection indicator.** Desktop
  dims the previously-selected effect so "this vs last" is
  visible during compare-and-adjust cycles. **P2.**
- **Gap B29 — Text fade / size-stepping at small widths.** iPad
  hides the label below a hard 70 px threshold; desktop
  progressively shrinks + fades. **P2.**

---

## 2. Timeline (ruler)

- **Gap B34 — Tags (0-9 numbered markers).** Right-click-add,
  Ctrl+N-go-to, persisted with the sequence. **P1.** Last piece
  of the loop-region / tags / render cluster; everything else
  there landed.
- **Gap B35 — Tag context menu** (rename, delete, delete-all).
  Rolls in with B34. **P1.**
- **Gap B38 — Zoom-level presets.** Desktop has 19 preset steps.
  iPad smooth pinch only. **P2.**
- **Gap B40 — Audio scrub** (play a short window of audio as the
  marker is dragged during B39 drag-to-scrub). **P2.**

---

## 3. Waveform

- **Gap B42 — Double-height mode.** **P2.**
- **Gap B43 — Audio track switching** (alt audio tracks, e.g.
  clean vocal stem). **P2.**

---

## 4. Row headings

### 4.1 Layer management

- **Gap B47 — Insert Multiple Layers Below.** Batch create N
  layers. **P2.**
- **Gap B48 — Delete Unused Layers.** Scan for layers with zero
  effects and drop them. **P2.**

### 4.2 Model / row operations

- **Gap B49 — Export model sequence / Render-and-Export.** 2 × 2
  variants (whole model vs selected effects × with / without
  render). **P1.**
- **Gap B55 — Convert Effects to 'Per Model'.** Scope-change
  operation collapsing per-strand effects to a single model-level
  layer. **P2.**
- **Gap B56 — Promote Node Effects / Convert To Effect.** **P2.**

### 4.3 Global row operations

- **Gap B58 — Toggle Strands / Toggle Nodes / Toggle Models.**
  Global view-mode switches. **P2.**
- **Gap B59 — Edit Display Elements.** Phase F scope.

### 4.4 Drag / resize

- **Gap B60 — Drag row to reorder.** **P2.**

### 4.5 Icons / visual

- **Gap B63 — Papagayo / FPP / model-group icon glyphs.** Desktop
  decorates row names with small icons when the element is a
  Papagayo lyric track, FPP command / effect track, etc. iPad
  shows a folder for ModelGroup only. **P2.**
- **Gap B64 — Layer-count "[N]" indicator.** Desktop shows `Model
  Name [3]` when the element has 3 layers; iPad shows the layer
  toggle button but no count. **P2.**
- **Gap B66 — Muted visual state.** Desktop has distinct rendering
  for a muted element. **P2.**

---

## 5. Timing tracks (remaining)

### 5.1 Track management

- **Gap B77 — Import Notes** (MIDI / note file). **P2.**
- **Gap B79 — AI Speech 2 Lyrics.** Needs an iOS bridge for the
  AI call path. **P2.**
- **Gap B81 — Hide All Timing / Show All Timing** bulk toggle.
  **P2.**
- **Gap B82 — Add Timing Tracks to All Views.** Phase F adjacent.
  **P2.**
- **Gap B83 — Create Timing From Effects.** Generate timing
  marks from existing effects on a model. **P2.**

### 5.2 Per-mark / misc

- **Gap B84 (per-mark variant).** Single-mark "Breakdown Phrase"
  context-menu entry (row-level landed). **P2.**
- **Gap B90 — Add / Remove "-shimmer" suffix.** Convenience op on
  timing labels. **P2.**
- **Gap B91 — Divide Timings (Halve).** Subdivide each mark.
  **P2.**
- **Gap B92 — Double-tap timing mark → loop-play that region.**
  **P2.**

---

## 6. Scrolling, zoom, playback follow

- **Gap B94 — Visible scrollbars.** No scrollbars on iPad. Fine on
  touch, rough with a trackpad. iPadOS 26 supports compact
  scrollbars; the Metal-backed grid needs a custom overlay.
  **P1.**
- **Gap B96 — Scroll momentum.** iPad scroll stops when finger
  lifts. **P2.**

---

## 7. Find / Replace

- **Gap B97 — Find / Replace panel.** Bottom sheet or inspector-
  style overlay; cmd+F shortcut. **P2.**

---

## 8. Copy / paste beyond single effect

- **Gap B99 — System pasteboard integration** (`UIPasteboard` with
  a custom UTI so copy / paste crosses app restarts + Universal
  Clipboard). **P2.**
- **Gap B100 — Paste replacing an existing effect at the same
  cell** (with confirmation). **P2.**

---

## 9. Deferred / removed

- **Gap B16 — Drag from palette with live preview.** Deferred
  pending user feedback. Tap-to-arm + tap-to-place is working
  well on touch; revisit only if users ask for drag-cancel
  mid-gesture.
- **Gap B86 — Breakdown Phoneme.** Removed from scope. Not a real
  desktop feature (desktop has exactly Phrases + Words
  breakdowns; phonemes fall out of the Word breakdown).
- **Gap B59 — Edit Display Elements.** Phase F scope.
- **Gap B19 full-storage impl.** Phase C / G12 shares
  `EffectPresetManager`-backed storage; only the menu-entry stub
  lands here.

---

## 10. Suggested phasing for remaining work

The remaining P1s don't cluster — each is a bounded but distinct
piece. Rough ordering by value:

1. **B34 + B35 tags** (~1 week). Closes the last workflow bundle
   (loop / tags / render). Pairs with existing tag-style
   affordances in the timeline.
2. **B94 visible scrollbars** (~3-4 days). Chunkier because of
   the custom Metal overlay, but the last large discoverability
   gap on trackpad.
3. **B49 export model** (~3-4 days). File I/O; reuses the
   `.xtiming` / Save-As UTType + `.fileExporter` plumbing already
   in place.
4. **B15 randomize / reset** (~2-3 days). Needs the metadata
   default-value plumbing to settle; easier after any of the
   effect-preset work lands because both touch the same surface.
5. **B19 presets menu stub** (~1 day). Trivial dropdown that
   defers the actual storage to Phase C. Land whenever.

P2s are best handled in a polish sweep rather than one-by-one.
Candidates for batching: B25 + B29 (effect-bar visual polish),
B47 + B48 + B58 + B60 (row-heading polish), B77 + B81 + B82 + B90
+ B91 (timing-track polish).

---

## 11. Out of scope

- Core rendering (complete, verified on-device).
- Model / layout editing — stays desktop-only.
- Controller output — deferred to post-MVP in the top-level plan.
- Sequence-lifecycle plumbing — Phase E (complete).
- App Store submission — Phase H.
- Document / iCloud handling — Phase G.
- Audio-filter enhancements beyond the four standard filters —
  tracked in `plans/audio-analysis-enhancements.md`.

---

## 12. Summary gap table (open items only)

Severity key: **P1** = blocks a specialised workflow; **P2** =
nice-to-have / expert shortcut; **Verify** = likely already works,
needs device check; **Deferred** = pending upstream work or user
feedback.

| # | Gap | Area | Severity |
|---|---|---|---|
| B3 | Tab / Shift+Tab navigation | Selection | P2 |
| B6 | Nudge by timing mark | Editing | P2 |
| B7 | Edge-unlink indicator + command | Editing | P2 |
| B13 | Extend effect to next / previous | Editing | P2 |
| B15 | Randomize / Reset-to-default on selection | Editing | P1 |
| B16 | Drag-from-palette with preview ghost | Create | Deferred |
| B17 | Random-effect palette button | Create | P2 |
| B18 | Double-click create in range | Create | P2 |
| B19 | Effect presets menu entry | Ctx menu | P1 |
| B20 | Description / tooltip field | Ctx menu | P2 |
| B22 | Reset effect to defaults | Ctx menu | P2 |
| B23 | Duplicate across models | Ctx menu | P2 |
| B24 | Find possible source effects | Ctx menu | P2 |
| B25 | Bracket colours sourced from `ColorManager` | Visual | P2 |
| B26 | ColorCurve gradient preview in effect bar | Visual | Verify |
| B27 | Node-level channel stripes | Visual | P2 |
| B28 | Reference / previous-selection indicator | Visual | P2 |
| B29 | Text fade / size stepping | Visual | P2 |
| B34 | Tags (0-9 numbered markers) | Timeline | P1 |
| B35 | Tag context menu | Timeline | P1 |
| B38 | Desktop zoom-level presets | Timeline | P2 |
| B40 | Audio scrub | Timeline | P2 |
| B42 | Double-height waveform | Waveform | P2 |
| B43 | Audio-track switch (alt tracks) | Waveform | P2 |
| B47 | Insert Multiple Layers Below | Row heading | P2 |
| B48 | Delete Unused Layers | Row heading | P2 |
| B49 | Export model / Render-and-Export | Row heading | P1 |
| B55 | Convert Effects to 'Per Model' | Row heading | P2 |
| B56 | Promote Node / Convert To Effect | Row heading | P2 |
| B58 | Toggle Strands / Nodes / Models | Row heading | P2 |
| B60 | Drag row to reorder | Row heading | P2 |
| B63 | Papagayo / FPP / group icon glyphs | Row heading | P2 |
| B64 | Layer-count [N] indicator | Row heading | P2 |
| B66 | Muted row visual state | Row heading | P2 |
| B77 | Import Notes (MIDI) | Timing | P2 |
| B79 | AI Speech 2 Lyrics | Timing | P2 |
| B81 | Hide All / Show All Timing | Timing | P2 |
| B82 | Add Timing Tracks to All Views | Timing | P2 |
| B83 | Create Timing From Effects | Timing | P2 |
| B84 (per-mark) | Single-mark phrase breakdown | Timing | P2 |
| B86 | Breakdown Phoneme | Timing | Removed |
| B90 | Add / Remove "-shimmer" suffix | Timing | P2 |
| B91 | Divide Timings (Halve) | Timing | P2 |
| B92 | Double-tap timing mark → loop-play region | Timing | P2 |
| B94 | Visible scrollbars | Scroll | P1 |
| B96 | Scroll momentum | Scroll | P2 |
| B97 | Find / Replace | Find | P2 |
| B99 | System pasteboard (UIPasteboard) integration | Clipboard | P2 |
| B100 | Paste-replacing-existing with confirmation | Clipboard | P2 |

Counts (2026-04-21): **0 × P0**, **6 × P1**, **40 × P2**, **1 ×
Verify**, **1 × Deferred**, **1 × Removed**.
