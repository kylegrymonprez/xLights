# Phase B — Effects Grid Parity (Pending Work)

Scope: the sequencer canvas the user spends 90 % of their time in —
the **effects grid**, **timeline ruler**, **waveform**, **row
headings**, and the **timing tracks** strip between them. Phase B and
B-Metal closed out the rebuild and the Metal render pipeline; this
sub-plan tracks the remaining authoring gaps vs desktop.

---

## Status (2026-04-20)

All twelve original P0s are closed. The work now shifts into a long
tail of P1 polish + P2 nice-to-haves, a few verify-only items, and
one P1 item that's explicitly deferred pending user testing.

**Landed since the 2026-04-20 gap audit:**

- **Multi-select + align + split + playhead follow.** B1 (two-finger
  marquee select with `selectedEffects: Set<EffectSelection>`), B2
  (Select All in Row / Column context-menu entries), B5 (snap-to-
  active-timing-mark on drag move/resize), B8 (align Start / End /
  Both / Centers / Match Duration on multi-select), B12 (Split at
  Play Marker on single effect), B31 (persistent status-bar readout
  for the current selection), B93 (auto-scroll the grid to follow
  the play marker during playback).
- **Timing-mark editing.** B67 (long-press empty timing band → Add
  Mark Here, 500 ms default clamped to neighbors), B68 (pan a mark's
  edges or center to resize / move, snap to other marks at 10 px),
  B69 (Delete Mark), B70 (Rename Mark alert), B71 (Split Mark at
  Play Marker), B72 (Merge with Next), B73 (Add Timing Track from
  the View-picker menu + timing-row header).
- **Lyric rendering + breakdown.** B88 (colour-coded label
  backgrounds for Phrases / Words / Phonemes sub-layers — matches
  desktop `COLOR_PHRASES` / `_WORDS` / `_PHONEMES`), B84 (row-level
  "Breakdown Phrases" that splits every non-empty phrase label by
  whitespace and populates a fresh word layer).
- **Scroll polish.** B95 (`allowedScrollTypesMask = .all` on the
  three Metal canvases' pan recognisers so trackpad / scroll-wheel
  events drive pan).

**Still the biggest open item by far** is the loop-region / tags /
render-selected-region family (B32, B33, B34, B35, B44) — it's the
one remaining cohesive desktop workflow that has no iPad path. See
§ 5 below.

**Out of Phase B:** B16 (drag-from-palette with ghost) deferred
pending user feedback — tap-to-arm + tap-to-place is working well
in practice. B85 (word → phoneme breakdown) deferred pending a
wx-free port of `PhonemeDictionary`. B86 removed — not a real
desktop feature.

---

## 1. Effects grid canvas

### 1.1 Selection

- **Gap B3 — Tab-to-next-effect.** Hardware keyboard only. Arrow
  keys already move selection row-ward and column-ward; Tab /
  Shift+Tab aren't bound. **P2.**

### 1.2 Editing — positional

- **Gap B4 — Shift+arrow stretch, Ctrl+arrow fine nudge.** Arrow
  keys currently move selection *cursor*, not time. Desktop's
  modified-arrow semantics (Shift stretches, Ctrl nudges by 1 ms,
  Alt by 1 frame) aren't implemented. **P1.**
- **Gap B6 — Nudge by timing mark.** Ctrl+PageUp / Ctrl+PageDown
  moves selection forward / back one active mark. **P2.**
- **Gap B7 — Edge-unlink indicator + unlink command.** Desktop
  tags an effect edge that's been "unlinked" from its neighbour
  so paste / align won't re-butt them. **P2.**

### 1.3 Editing — range / bulk

All depend on B1 (done).

- **Gap B9 — Shift-Align Start / End.** Slide selection to align
  without overlapping. **P1.**
- **Gap B10 — Align to Closest Timing Mark.** Snap selected
  effects' start / end to the nearest mark on the active timing
  track. **P1.**
- **Gap B11 — Close Gap.** Remove space between two selected
  effects. **P1.**
- **Gap B13 — Extend effect to next / previous.** Keyboard-only
  on desktop; handy. **P2.**
- **Gap B14 — Paste by cell.** Desktop paste respects the
  currently-selected grid cell (row + time range) and drops the
  clipboard effect into it. iPad paste targets the selected
  effect's row at play position. **P1.**
- **Gap B15 — Randomize selected / Reset to default / Lock-all /
  Disable-all on selection.** Lock-all / Disable-all landed with
  B1's bulk ops; Randomize + Reset-to-default still open. **P1.**

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
- **Gap B21 — Timing dialog.** Edit exact start / end ms.
  Essential for users who know the timecode they want. **P1.**
- **Gap B22 — Reset effect.** Revert the effect's settings to
  type defaults. **P2.**
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
- **Gap B30 — Hover / pointer-over states.** iPadOS 26 supports
  pointer hover via `.hoverEffect`. No hover rendering on the
  grid — no resize cursor, no edge-highlight pre-drag. **P1**
  for Magic Keyboard users.

---

## 2. Timeline (ruler)

`TopChromeMetalGridView.swift` — ruler + waveform in one strip.

- **Gap B32 — Loop region (shift-click start + end, drag).** Draws
  a highlight; `Render Selected Region` runs against it. No iPad
  equivalent. **P0** (the last remaining P0 bundle — see §10).
- **Gap B33 — Play region from loop.** `Play Loop` / loop-repeat
  mode that plays between two markers indefinitely. **P1.**
- **Gap B34 — Tags (0-9 numbered markers).** Right-click-add,
  Ctrl+N-go-to, persisted with the sequence. **P1.**
- **Gap B35 — Tag context menu** (rename, delete, delete-all).
  Rolls in with B34. **P1.**
- **Gap B36 — Zoom to selection.** Fits the selected range into
  the viewport. **P1.**
- **Gap B37 — Zoom to fit (sequence).** `fitIfNeeded` runs once
  on load; no button / shortcut to re-fit. **P1.**
- **Gap B38 — Zoom-level presets.** Desktop has 19 preset steps.
  iPad smooth pinch only. **P2.**
- **Gap B39 — Drag-to-scrub playback.** Desktop drags the play
  marker for continuous scrubbing. **P1.**
- **Gap B40 — Audio scrub** (play a short window of audio as the
  marker is dragged). **P2.**

---

## 3. Waveform

- **Gap B41 — Filter-variant rendering** (bass / alto / treble /
  non-vocals / custom). `AudioManager` already produces these; the
  iPad waveform reads raw only. **P1.**
- **Gap B42 — Double-height mode.** **P2.**
- **Gap B43 — Audio track switching** (alt audio tracks, e.g.
  clean vocal stem). **P2.**
- **Gap B44 — Render-selected-region.** Depends on B32. Kicks the
  renderer to re-run only the highlighted range. **P1.**
- **Gap B45 — Waveform drag-for-range.** Follows from B32. **P1.**

---

## 4. Row headings

`RowHeaderViews.swift`. Largest surface gap relative to desktop's
`RowHeading.cpp` (2228 LOC) after timing-mark editing.

### 4.1 Layer management

- **Gap B46 — Rename layer / Set layer name.** Layer names exist
  in the XML and are displayed but aren't editable from iPad.
  **P1.**
- **Gap B47 — Insert Multiple Layers Below.** Batch create N
  layers. **P2.**
- **Gap B48 — Delete Unused Layers.** Scan for layers with zero
  effects and drop them. **P2.**

### 4.2 Model / row operations

- **Gap B49 — Export model sequence / Render-and-Export.** 2 × 2
  variants (whole model vs selected effects × with / without
  render). **P1.**
- **Gap B50 — Delete all effects / SubModel effects / Strand
  effects / Node effects.** Bulk clear scoped to the selected row
  type. **P1.**
- **Gap B51 — Enable / Disable Render on model.** Row-level render
  toggle. **P1.**
- **Gap B52 — Select all effects in this model.** Covers the
  Model-wide variant that B2 didn't cover (row + column only).
  **P1.**
- **Gap B53 — Cut / Copy / Paste Row** (whole layer + all
  effects). **P1.**
- **Gap B54 — Cut / Copy / Paste Model** (all layers + all
  effects). Desktop also has `Copy Model incl SubModels`. **P1.**
- **Gap B55 — Convert Effects to 'Per Model'.** Scope-change
  operation collapsing per-strand effects to a single model-level
  layer. **P2.**
- **Gap B56 — Promote Node Effects / Convert To Effect.** **P2.**

### 4.3 Global row operations

- **Gap B57 — Show All Effects, Collapse All Models, Collapse All
  Layers.** Bulk visibility toggles. **P1.**
- **Gap B58 — Toggle Strands / Toggle Nodes / Toggle Models.**
  Global view-mode switches. **P2.**
- **Gap B59 — Edit Display Elements.** Phase F scope.

### 4.4 Drag / resize

- **Gap B60 — Drag row to reorder.** **P2.**
- **Gap B61 — Drag right edge of row-heading column to resize
  column width.** Row-heading column is fixed-width on iPad.
  **P1.**

### 4.5 Icons / visual

- **Gap B63 — Papagayo / FPP / model-group icon glyphs.** Desktop
  decorates row names with small icons when the element is a
  Papagayo lyric track, FPP command / effect track, etc. iPad
  shows a folder for ModelGroup only. **P2.**
- **Gap B64 — Layer-count "[N]" indicator.** Desktop shows `Model
  Name [3]` when the element has 3 layers; iPad shows the layer
  toggle button but no count. **P2.**
- **Gap B65 — Tooltips on truncated row names.** Hover tooltip on
  Magic-Keyboard pointer would solve the discoverability problem
  with zero UI cost. **P1** for Magic Keyboard users.
- **Gap B66 — Muted visual state.** Desktop has distinct rendering
  for a muted element. Hidden-state probably doesn't apply
  (hidden = not rendered at all), but muted has no iPad analog.
  **P2.**

---

## 5. Timing tracks (remaining)

Most mark-editing + breakdown work landed. What's left:

### 5.1 Track management

- **Gap B74 — Import Timing Track** from `.xtiming`. **P1.**
- **Gap B75 — Export Timing Track** to `.xtiming`. **P1.**
- **Gap B76 — Make Timing Track Variable** (convert fixed →
  editable). Fixed tracks are common from beat-detection imports.
  **P1.**
- **Gap B77 — Import Notes** (MIDI / note file). **P2.**
- **Gap B78 — Import Lyrics** (text file). **P1.**
- **Gap B79 — AI Speech 2 Lyrics.** Needs an iOS bridge for the
  AI call path. **P2.**
- **Gap B80 — Generate Subdivided Timing Tracks** (1/2, 1/3, 1/4,
  1/6, 1/8, ×2, ×4, ×8). Common music-timing setup. **P1.**
- **Gap B81 — Hide All Timing / Show All Timing** bulk toggle.
  **P2.**
- **Gap B82 — Add Timing Tracks to All Views.** Phase F adjacent.
  **P2.**
- **Gap B83 — Create Timing From Effects.** Generate timing
  marks from existing effects on a model. **P2.**

### 5.2 Breakdown (remaining)

- **Gap B85 — Breakdown Word / Words.** **Deferred — requires
  phoneme dictionary port.** Desktop's `BreakdownWord` depends on
  `PhonemeDictionary` (CMU-dict-style loader + lookup) in
  `src-ui-wx/sequencer/PhonemeDictionary.{h,cpp}`. That class is
  wx-based (wxString, wxArrayString, wxFontEncoding) so shipping
  on iPad requires a wx-free port plus bundling the dictionary
  file(s). Existing Papagayo-authored sequences still render
  correctly (B88), so this only blocks iPad-authored lyric
  tracks.
- **Gap B87 — Remove Words / Phonemes / Words-and-Phonemes.**
  Bulk clear of sub-layer labels. **P1.**
- **Gap B89 — Auto Label Timings** (populate labels from loaded
  lyric text). Follows from B78. **P1.**
- **Gap B90 — Add / Remove "-shimmer" suffix.** Convenience op on
  timing labels. **P2.**
- **Gap B91 — Divide Timings (Halve).** Subdivide each mark.
  **P2.**

### 5.3 Per-mark variants

- **Gap B84 (per-mark variant).** Single-mark "Breakdown Phrase"
  context-menu entry (row-level landed). **P2.**
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

iPad clipboard holds one effect's name + settings + palette +
duration. It's app-internal, not the system pasteboard.

- **Gap B98 — Multi-effect clipboard** (array of effects preserving
  relative timing). **P1.**
- **Gap B99 — System pasteboard integration** (`UIPasteboard` with
  a custom UTI so copy / paste crosses app restarts + Universal
  Clipboard). **P2.**
- **Gap B100 — Paste replacing an existing effect at the same
  cell** (with confirmation). **P2.**

---

## 9. Deferred / explicitly out of Phase B

- **Gap B16 — Drag from palette with live preview.** Deferred
  pending user feedback. Tap-to-arm + tap-to-place is working
  well on touch; revisit only if users ask for drag-cancel
  mid-gesture.
- **Gap B85 — Breakdown Word / Words.** See § 5.2 — needs
  `PhonemeDictionary` port.
- **Gap B86 — Breakdown Phoneme.** Removed from scope. Not a
  real desktop feature (desktop has exactly Phrases + Words
  breakdowns; phonemes fall out of the Word breakdown).
- **Gap B59 — Edit Display Elements.** Phase F scope.
- **Gap B19 — Effect Presets (full storage impl).** Phase C / G12
  shares `EffectPresetManager`-backed storage; the menu-entry
  stub lands separately.

---

## 10. Suggested phasing for remaining work

Only one P0 bundle left. Everything else is polish.

**B-IV — Loop region, tags, waveform variants, render-selected
(1-2 weeks)** — the last P0.

- B32 / B33 / B44 / B45 loop region + play-loop + render-
  selected-region + waveform drag-range.
- B34 / B35 numbered tags + tag menu.
- B36 / B37 zoom-to-selection / zoom-to-fit.
- B39 drag-to-scrub.
- B41 waveform filter variants.

**B-V — Row-heading expansion (1-2 weeks)** — biggest P1 cluster.

- B46 rename layer.
- B49 / B50 / B51 / B52 model-level export / bulk-delete /
  render-toggle / select-in-model.
- B53 / B54 cut-copy-paste row + model.
- B57 show-all / collapse-all.
- B61 drag-resize row-heading column.

**B-VI — Editing polish (1 week)**

- B4 shift-arrow stretch / fine nudge.
- B9 / B10 / B11 shift-align / align-to-mark / close-gap on
  selection.
- B14 paste-by-cell semantics.
- B15 randomize / reset-to-default on selection.
- B21 exact-time dialog on long-press.

**B-VII — Timing track polish (2-3 weeks)**

- B74 / B75 import / export `.xtiming`.
- B76 fixed-to-variable conversion.
- B78 import lyrics + B89 auto-label.
- B80 generate subdivided timing.
- B85 phoneme-dictionary port → word breakdown.
- B87 bulk remove words / phonemes.

**B-VIII — Visual + trackpad polish**

- B25 bracket-colours via ColorManager.
- B26 verify (ColorCurve already works via BM-6).
- B30 pointer hover states.
- B94 visible scrollbars.

**Deferred to Phase C**

- B19 effect presets (full impl).

**Deferred to Phase F**

- B59 Edit Display Elements.
- Menu-bar keyboard-shortcut exposure.
- Tear-out / dock behaviour.

---

## 11. Out of scope

- Core rendering (complete, verified on-device).
- Model / layout editing — stays desktop-only.
- Controller output — deferred to post-MVP in the top-level plan.
- Sequence-lifecycle plumbing (save / save-as / new / sequence
  settings / dirty prompt) — Phase E.
- App Store submission — Phase H.
- Document / iCloud handling — Phase G.

---

## 12. Summary gap table (open items only)

Severity key: **P0** = blocks a common user workflow; **P1** =
blocks a specialised workflow / regular users hit this; **P2** =
nice-to-have / expert shortcut; **Verify** = likely already works,
needs device check; **Deferred** = pending upstream work or user
feedback.

| # | Gap | Area | Severity |
|---|---|---|---|
| B3 | Tab / Shift+Tab navigation | Selection | P2 |
| B4 | Shift / Ctrl arrow stretch / nudge | Editing | P1 |
| B6 | Nudge by timing mark | Editing | P2 |
| B7 | Edge-unlink indicator + command | Editing | P2 |
| B9 | Shift-Align Start / End | Editing | P1 |
| B10 | Align to closest timing mark | Editing | P1 |
| B11 | Close Gap | Editing | P1 |
| B13 | Extend effect to next / previous | Editing | P2 |
| B14 | Paste by cell | Editing | P1 |
| B15 | Randomize / Reset-to-default on selection | Editing | P1 |
| B16 | Drag-from-palette with preview ghost | Create | Deferred |
| B17 | Random-effect palette button | Create | P2 |
| B18 | Double-click create in range | Create | P2 |
| B19 | Effect presets menu entry | Ctx menu | P1 |
| B20 | Description / tooltip field | Ctx menu | P2 |
| B21 | Timing dialog (exact ms) | Ctx menu | P1 |
| B22 | Reset effect to defaults | Ctx menu | P2 |
| B23 | Duplicate across models | Ctx menu | P2 |
| B24 | Find possible source effects | Ctx menu | P2 |
| B25 | Bracket colours sourced from `ColorManager` | Visual | P2 |
| B26 | ColorCurve gradient preview in effect bar | Visual | Verify |
| B27 | Node-level channel stripes | Visual | P2 |
| B28 | Reference / previous-selection indicator | Visual | P2 |
| B29 | Text fade / size stepping | Visual | P2 |
| B30 | Pointer hover states | Visual | P1 |
| B32 | Loop region (shift-click + drag) | Timeline | P0 |
| B33 | Play-loop mode | Timeline | P1 |
| B34 | Tags (0-9 numbered markers) | Timeline | P1 |
| B35 | Tag context menu | Timeline | P1 |
| B36 | Zoom to selection | Timeline | P1 |
| B37 | Zoom to fit (button) | Timeline | P1 |
| B38 | Desktop zoom-level presets | Timeline | P2 |
| B39 | Drag to scrub | Timeline | P1 |
| B40 | Audio scrub | Timeline | P2 |
| B41 | Waveform filter variants (bass / alto / treble) | Waveform | P1 |
| B42 | Double-height waveform | Waveform | P2 |
| B43 | Audio-track switch (alt tracks) | Waveform | P2 |
| B44 | Render-selected-region | Waveform | P1 |
| B45 | Click-seek + drag-range on waveform | Waveform | P1 (with B32) |
| B46 | Rename layer | Row heading | P1 |
| B47 | Insert Multiple Layers Below | Row heading | P2 |
| B48 | Delete Unused Layers | Row heading | P2 |
| B49 | Export model / Render-and-Export | Row heading | P1 |
| B50 | Delete all effects / submodel / strand / node | Row heading | P1 |
| B51 | Enable / Disable render on model | Row heading | P1 |
| B52 | Select all effects in model | Row heading | P1 |
| B53 | Cut / Copy / Paste Row | Row heading | P1 |
| B54 | Cut / Copy / Paste Model (+ submodels) | Row heading | P1 |
| B55 | Convert Effects to 'Per Model' | Row heading | P2 |
| B56 | Promote Node / Convert To Effect | Row heading | P2 |
| B57 | Show All / Collapse All Models / Collapse All Layers | Row heading | P1 |
| B58 | Toggle Strands / Nodes / Models | Row heading | P2 |
| B60 | Drag row to reorder | Row heading | P2 |
| B61 | Drag-resize row-heading column width | Row heading | P1 |
| B63 | Papagayo / FPP / group icon glyphs | Row heading | P2 |
| B64 | Layer-count [N] indicator | Row heading | P2 |
| B65 | Tooltip on truncated row name | Row heading | P1 (MK) |
| B66 | Muted row visual state | Row heading | P2 |
| B74 | Import Timing Track (.xtiming) | Timing | P1 |
| B75 | Export Timing Track (.xtiming) | Timing | P1 |
| B76 | Make fixed timing track variable | Timing | P1 |
| B77 | Import Notes (MIDI) | Timing | P2 |
| B78 | Import Lyrics | Timing | P1 |
| B79 | AI Speech 2 Lyrics | Timing | P2 |
| B80 | Generate Subdivided Timing Tracks | Timing | P1 |
| B81 | Hide All / Show All Timing | Timing | P2 |
| B82 | Add Timing Tracks to All Views | Timing | P2 |
| B83 | Create Timing From Effects | Timing | P2 |
| B84 (per-mark) | Single-mark phrase breakdown | Timing | P2 |
| B85 | Breakdown Word / Words | Timing | Deferred |
| B87 | Remove Words / Phonemes | Timing | P1 |
| B89 | Auto Label Timings (from lyrics) | Timing | P1 |
| B90 | Add / Remove "-shimmer" suffix | Timing | P2 |
| B91 | Divide Timings (Halve) | Timing | P2 |
| B92 | Double-tap timing mark → loop-play region | Timing | P2 |
| B94 | Visible scrollbars | Scroll | P1 |
| B96 | Scroll momentum | Scroll | P2 |
| B97 | Find / Replace | Find | P2 |
| B98 | Multi-effect clipboard with relative timing | Clipboard | P1 |
| B99 | System pasteboard (UIPasteboard) integration | Clipboard | P2 |
| B100 | Paste-replacing-existing with confirmation | Clipboard | P2 |

Counts: **1 × P0**, **29 × P1**, **48 × P2**, **1 × Verify**, **2 ×
Deferred**.
