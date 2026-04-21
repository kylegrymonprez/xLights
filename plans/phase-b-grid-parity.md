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
in practice. B85 (word → phoneme breakdown) unblocked 2026-04-21 —
`PhonemeDictionary` ported to `src-core/lyrics/`; iPad bridge +
bundled-dictionary wiring is the remaining work. B86 removed — not
a real desktop feature.

---

## 1. Effects grid canvas

### 1.1 Selection

- **Gap B3 — Tab-to-next-effect.** Hardware keyboard only. Arrow
  keys already move selection row-ward and column-ward; Tab /
  Shift+Tab aren't bound. **P2.**

### 1.2 Editing — positional

- **Gap B4 — Shift+arrow stretch, Ctrl+arrow fine nudge.**
  **[landed 2026-04-20].** Six new hidden-button keyboard
  shortcuts on `SequencerView`: Shift+← / → stretches the
  selected effect's end by one frame interval; Ctrl+← / →
  nudges start+end by 1 ms (duration preserved); Option(Alt)+
  ← / → nudges by one frame interval. `stretchSelectedEffect-
  End(by:)` and `nudgeSelectedEffect(by:)` route through
  `moveEffect` with neighbour-aware clamps.
- **Gap B6 — Nudge by timing mark.** Ctrl+PageUp / Ctrl+PageDown
  moves selection forward / back one active mark. **P2.**
- **Gap B7 — Edge-unlink indicator + unlink command.** Desktop
  tags an effect edge that's been "unlinked" from its neighbour
  so paste / align won't re-butt them. **P2.**

### 1.3 Editing — range / bulk

All depend on B1 (done).

- **Gap B9 — Shift-Align Start / End.** **[landed 2026-04-20].**
  `.startTimesShift` / `.endTimesShift` modes on `AlignMode` slide
  each effect by a delta so its start/end matches the anchor,
  preserving duration (vs the regular `startTimes`/`endTimes` modes
  which stretch/shrink). Menu entries "Shift-Align Start" and
  "Shift-Align End" in the multi-select context menu.
- **Gap B10 — Align to Closest Timing Mark.** **[landed
  2026-04-20].** `alignSelectedEffectsToTimingMarks()` snaps each
  selected effect's start and end independently to the nearest
  active-timing-row mark edge within ~half the effect's duration.
  Rejects when no timing rows are active. Single undo group.
- **Gap B11 — Close Gap.** **[landed 2026-04-20].**
  `closeGapInSelectedEffects()` groups selection by row, sorts
  each group by startMS, and for each consecutive pair slides
  the later effect's start back to the earlier effect's end
  (duration preserved). Cross-row pairs are ignored. Gated by
  `canCloseGapInSelection` so the menu entry only appears when
  at least one pair has a positive gap.
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
- **Gap B21 — Timing dialog.** **[landed 2026-04-20].** "Edit
  Timing…" entry on the single-effect context menu opens an
  alert with Start / End text fields in seconds (`5.250` format,
  3 decimal places). `parseSeconds` uses `strtod` per repo rule
  (no throwing `std::stod`). On commit, calls `moveEffect` to
  validate + register undo.
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

- **Gap B32 — Loop region.** **[landed 2026-04-20].** Long-press
  + drag on the ruler establishes a `[loopStartMS, loopEndMS]`
  region; live drag extent draws a soft blue band across the
  whole top-chrome strip with stroked edges. A plain long-press
  inside an existing loop band (≤ 6 px drag) surfaces a context
  menu with Play Loop / Render Loop Region / Clear Loop. Region
  stored on `SequencerViewModel.loopStartMS` / `loopEndMS` with
  `hasLoopRegion` convenience. `setLoopRegion(startMS:endMS:)`
  clamps to sequence bounds; `clearLoopRegion()` also turns off
  play-loop mode.
- **Gap B33 — Play region from loop.** **[landed 2026-04-20].**
  `loopPlayEnabled` flag + timer hook: when on and
  `hasLoopRegion`, the playback tick wraps `playPositionMS` back
  to `loopStartMS` each time it crosses `loopEndMS`. Audio path
  calls `audioSeek(toMS:)` to keep the stream synced; timer-only
  (no-audio) path resets the wall-clock anchor. Entry point:
  "Play Loop Region" in the loop context menu — seeks to
  loopStart, enables the flag, and starts playback.
- **Gap B34 — Tags (0-9 numbered markers).** Right-click-add,
  Ctrl+N-go-to, persisted with the sequence. **P1.**
- **Gap B35 — Tag context menu** (rename, delete, delete-all).
  Rolls in with B34. **P1.**
- **Gap B36 — Zoom to selection.** **[landed 2026-04-20].**
  View-picker menu entry "Zoom to Selection" (shown when any
  selection is active) computes the selection's `[minStart,
  maxEnd]` range, sets `pixelsPerMS` so the range fills ~85 %
  of the viewport, and centres horizontal scroll on the
  selection midpoint.
- **Gap B37 — Zoom to fit (sequence).** **[landed 2026-04-20].**
  View-picker menu entry "Zoom to Fit". Calls a new
  `zoomToFitSequence` helper that bypasses the `fitDurationMS`
  load-once guard used by the on-load fit.
- **Gap B38 — Zoom-level presets.** Desktop has 19 preset steps.
  iPad smooth pinch only. **P2.**
- **Gap B39 — Drag-to-scrub playback.** **[landed 2026-04-20].**
  Pan starting in the ruler strip (`p.y < rulerHeight`) on
  `TopChromeMetalGridView` drives continuous `onSeek` on each
  `.changed` tick; pan starting in the waveform area keeps its
  existing scroll behaviour. Audio scrub (B40 — play a short
  audio window per tick) still deferred.
- **Gap B40 — Audio scrub** (play a short window of audio as the
  marker is dragged). **P2.**

---

## 3. Waveform

- **Gap B41 — Filter-variant rendering.** **[landed 2026-04-20].**
  Long-press on the waveform strip (below the ruler) surfaces a
  filter picker (Full Range / Bass / Treble / Alto / Non-Vocals,
  with a checkmark on the active choice). Bridge method gained
  a `filterType` parameter (0..4) mapping to `AUDIOSAMPLETYPE`;
  resolves the source pointer via
  `AudioManager::GetFilteredAudioData(type, 0, 127)` → `data0`
  with graceful fallback to the raw buffer when the filter
  isn't available yet. View model has `WaveformFilter` enum +
  observable `waveformFilter` property whose `didSet`
  re-samples the current range. Custom filter variant (desktop's
  CUSTOM lownote/highnote option) deferred — the four standard
  filters cover the common lyric / bass-drop workflow.
- **Gap B42 — Double-height mode.** **P2.**
- **Gap B43 — Audio track switching** (alt audio tracks, e.g.
  clean vocal stem). **P2.**
- **Gap B44 — Render-selected-region.** **[landed 2026-04-20].**
  `SequencerViewModel.renderLoopRegion()` iterates non-timing
  rows and kicks `renderRangeAndTrack` scoped to
  `[loopStartMS, loopEndMS]`. "Render Loop Region" entry on the
  loop context menu.
- **Gap B45 — Waveform drag-for-range.** **[landed 2026-04-20
  via B32].** The long-press + drag gesture installed for B32
  accepts drags that extend into the waveform area. A press
  that *begins* in the waveform strip still defers to pan
  (scroll) — matches desktop, where click-in-ruler vs click-in-
  waveform behave distinctly.

---

## 4. Row headings

`RowHeaderViews.swift`. Largest surface gap relative to desktop's
`RowHeading.cpp` (2228 LOC) after timing-mark editing.

### 4.1 Layer management

- **Gap B46 — Rename layer / Set layer name.** **[landed
  2026-04-20].** "Rename Layer" entry on the model-row header's
  long-press menu opens a text-field alert; commit routes
  through new bridge `-renameLayerAtRow:name:` →
  `EffectLayer::SetLayerName`. Undo-able with the original
  name.
- **Gap B47 — Insert Multiple Layers Below.** Batch create N
  layers. **P2.**
- **Gap B48 — Delete Unused Layers.** Scan for layers with zero
  effects and drop them. **P2.**

### 4.2 Model / row operations

- **Gap B49 — Export model sequence / Render-and-Export.** 2 × 2
  variants (whole model vs selected effects × with / without
  render). **P1.**
- **Gap B50 — Delete all effects / SubModel effects / Strand
  effects / Node effects.** **[landed 2026-04-20 — per-row
  variant].** "Delete All Effects on Row" destructive entry on
  model-row headers (any non-timing row with ≥ 1 effect). Uses
  the existing `deleteEffect` pipeline in descending-index order
  inside one undo group. Cascading variants that also clear
  submodels + strands + nodes are a follow-up.
- **Gap B51 — Enable / Disable Render on model.** **[landed
  2026-04-20].** "Enable Render" / "Disable Render" toggle entry
  on model-row headers. New bridge
  `-elementRenderDisabledAtRow:` / `-setElementRenderDisabled:atRow:`
  wraps `Element::IsRenderDisabled` / `SetRenderDisabled`.
  Applied at the Element level so submodels + strands + nodes
  inherit. Not undo-able in first cut.
- **Gap B52 — Select all effects in this model.** **[landed
  2026-04-20].** `selectAllEffectsInModel(rowIndex:)` walks back
  to the target model's top row (first row with `nestDepth ==
  0 && layerIndex == 0 && !isSubmodel`) then forward until the
  next such row, collecting effects on every non-timing row
  along the way. Menu entry on model-row headers ("Select All
  Effects in Model") and single-effect long-press ("Select All
  in Model").
- **Gap B53 — Cut / Copy / Paste Row.** **[landed 2026-04-20].**
  Model-row header menu: "Copy Row" (selects all effects in
  row then copies via multi-clipboard), "Cut Row" (copy +
  delete all). Paste is the same Cmd+V wired for B98.
- **Gap B54 — Cut / Copy / Paste Model.** **[landed 2026-04-20].**
  Model-row header menu: "Copy Model" (selects all effects
  across layers + submodels + strands + nodes via B52 then
  copies), "Cut Model" (copy + delete-all). Paste is the same
  Cmd+V; relative row offsets preserved by the clipboard so
  pasting at another model lands effects on the target's
  corresponding sub-rows (when row layout matches).
- **Gap B55 — Convert Effects to 'Per Model'.** Scope-change
  operation collapsing per-strand effects to a single model-level
  layer. **P2.**
- **Gap B56 — Promote Node Effects / Convert To Effect.** **P2.**

### 4.3 Global row operations

- **Gap B57 — Show All Effects, Collapse All Models, Collapse All
  Layers.** **[landed 2026-04-20].** View-picker menu entries
  "Collapse All" and "Expand All" call new bridge methods
  `-collapseAllElements` / `-expandAllElements` that iterate
  `SequenceElements::GetElement` and set `SetCollapsed` on every
  non-timing Element. Per-layer vs per-model granularity
  (desktop has both) is collapsed to one control for the iPad
  first cut.
- **Gap B58 — Toggle Strands / Toggle Nodes / Toggle Models.**
  Global view-mode switches. **P2.**
- **Gap B59 — Edit Display Elements.** Phase F scope.

### 4.4 Drag / resize

- **Gap B60 — Drag row to reorder.** **P2.**
- **Gap B61 — Drag right edge of row-heading column to resize
  column width.** **[landed 2026-04-20].** Replaced the three
  `Divider()` views between the row-header column and the grid
  canvas (top-chrome, timing band, model grid) with a new
  `ColumnResizeHandle` — 0.5-pt hairline + 12-pt transparent hit
  strip + `.hoverEffect(.highlight)` for Magic Keyboard pointer
  users. Width is persisted via `@AppStorage("gridRowHeaderWidth")`,
  clamped to 80..400 pt on every read via the `metrics` computed
  property. `metrics` itself became a computed var (was
  `@State`; never mutated in place, so no behavior change there).

### 4.5 Icons / visual

- **Gap B63 — Papagayo / FPP / model-group icon glyphs.** Desktop
  decorates row names with small icons when the element is a
  Papagayo lyric track, FPP command / effect track, etc. iPad
  shows a folder for ModelGroup only. **P2.**
- **Gap B64 — Layer-count "[N]" indicator.** Desktop shows `Model
  Name [3]` when the element has 3 layers; iPad shows the layer
  toggle button but no count. **P2.**
- **Gap B65 — Tooltips on truncated row names.** **[landed
  2026-04-20].** Added `.help(row.displayName)` to every
  `Text(row.displayName)` in `ModelRowHeader` +
  `TimingRowHeader`. Magic Keyboard pointer hover now shows the
  full name even when the cell truncates.
- **Gap B66 — Muted visual state.** Desktop has distinct rendering
  for a muted element. Hidden-state probably doesn't apply
  (hidden = not rendered at all), but muted has no iPad analog.
  **P2.**

---

## 5. Timing tracks (remaining)

Most mark-editing + breakdown work landed. What's left:

### 5.1 Track management

- **Gap B74 — Import Timing Track** from `.xtiming`. **[landed
  2026-04-20].** "Import Timing Track…" entry on the View-picker
  menu opens a `.fileImporter`; the picked path flows through
  new bridge `-importXTimingFromPath:` which calls
  `SequenceFile::ProcessXTiming({path}, iPadRenderContext)`. On
  success, other timing tracks are deactivated and the newly
  imported one goes active (matches desktop
  `ExecuteImportTimingElement`). Handles both single-`<timing>`
  and multi-track `<timings>` wrappers.
- **Gap B75 — Export Timing Track** to `.xtiming`. **[landed
  2026-04-20].** "Export Timing Track…" entry on the timing-row
  header long-press menu. New bridge
  `-exportTimingTrackAtRow:toPath:` wraps
  `TimingElement::GetExport()` in the standard `<?xml ?>` +
  `<timing name subType SourceVersion>` envelope matching
  desktop's `RowHeading.cpp:1276-1296`. iPad first writes to a
  temp `.xtiming` path, then presents SwiftUI's
  `.fileExporter` so the user picks a destination. Single-track
  export only for the first cut (desktop's
  `SelectTimingsDialog` multi-track export defers to a later
  polish pass).
- **Gap B76 — Make Timing Track Variable.** **[landed
  2026-04-20].** "Make Variable" entry on a fixed-interval
  timing-row header (gated by `timingTrackIsFixed`). New bridge
  `-makeTimingTrackVariableAtRow:` wraps
  `TimingElement::SetFixedTiming(0)` so the existing fixed-
  period marks stay in place and per-mark editing unlocks.
  Paired query `-timingTrackIsFixedAtRow:` surfaces the state
  for the gate.
- **Gap B77 — Import Notes** (MIDI / note file). **P2.**
- **Gap B78 — Import Lyrics.** **[landed 2026-04-20].** "Import
  Lyrics…" entry on the timing-row header long-press menu opens
  an `ImportLyricsSheet` with a multi-line `TextEditor` +
  Start/End seconds fields (default Start=0, End=sequence
  duration). On commit, non-empty lines are distributed evenly
  across the time range, each line's end snapped to the
  sequence frame period. New bridge
  `-importLyricsAtRow:phrases:startMS:endMS:` mirrors desktop
  `RowHeading::ImportLyrics`: clears all existing layers,
  unfixes the track, adds a single phrase layer, strips smart-
  quote unicode + a few illegal XML chars per line. Not
  undo-able in first cut (replaces layer structure; layer-
  level undo is follow-up). Paste-from-clipboard etc. comes
  for free via SwiftUI's `TextEditor`.
- **Gap B79 — AI Speech 2 Lyrics.** Needs an iOS bridge for the
  AI call path. **P2.**
- **Gap B80 — Generate Subdivided Timing Tracks.** **[landed
  2026-04-20].** Nested "Generate Subdivided Timing Track…"
  menu on a timing-row header with 8 entries: 1/2, 1/3, 1/4,
  1/6, 1/8, 2×, 4×, 8×. Positive divisors split each source
  mark into N equal sub-marks; negatives combine every |N|
  source marks. Source-name suffix matches desktop (` - 1/2`,
  ` - 2x`, etc.). Entirely in Swift via the existing
  `addTimingTrack` + `addTimingMark` primitives so no new
  bridge method needed. Desktop's multi-select
  "SubdivisionOptionsDialog" (pick N variants at once) is
  deferred — one-at-a-time is trivial to repeat on iPad.
- **Gap B81 — Hide All Timing / Show All Timing** bulk toggle.
  **P2.**
- **Gap B82 — Add Timing Tracks to All Views.** Phase F adjacent.
  **P2.**
- **Gap B83 — Create Timing From Effects.** Generate timing
  marks from existing effects on a model. **P2.**

### 5.2 Breakdown (remaining)

- **Gap B85 — Breakdown Word / Words.** **Unblocked
  2026-04-21 — wx-free port landed.** `PhonemeDictionary` and the
  `BreakdownPhrase` / `BreakdownWord` helpers now live in
  `src-core/lyrics/` and use only std::string / std::vector.
  Desktop still drives them via `xLightsFrame::dictionary` +
  `LoadPhonemeDictionaries()`; iPad wiring (bridge entry, bundled
  dictionary files, progress UI) is the remaining work for this
  gap. Existing Papagayo-authored sequences still render
  correctly (B88).
- **Gap B87 — Remove Words / Phonemes / Words-and-Phonemes.**
  **[landed 2026-04-20].** "Remove Words / Phonemes" destructive
  entry on the timing-row header long-press menu (layer 0 only,
  gated by `canRemoveWordsAndPhonemes`). New bridge
  `-removeWordsAndPhonemesAtRow:` strips layers 1 + 2 off the
  `TimingElement`. Lock-guard same as `BreakdownPhrases`:
  rejected if any word/phoneme mark is locked. Not undo-able
  in the first cut (mutates layer structure).
- **Gap B89 — Auto Label Timings.** **[landed 2026-04-20].**
  Labels every mark on a timing row with an incrementing integer
  in `[start, end]` (wraps back to `start` when it rolls past
  `end`; reversed direction supported via `start > end`).
  Overwrite toggle preserves already-labeled marks when off —
  matches desktop `EffectsGrid::AUTOLABEL` (`EffectsGrid.cpp:
  1105-1135`). Note: the original plan phrasing ("populate from
  loaded lyric text") was a misread — desktop's Auto-Label is
  numeric. Text-from-lyrics is what B78 already does. Entry:
  timing-row header long-press → "Auto-Label Marks…" alert with
  Start / End number fields + Overwrite toggle. Single undo
  group.
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

- **Gap B98 — Multi-effect clipboard.** **[landed 2026-04-20].**
  Clipboard moved from a single `EffectClipboard` struct to
  `[ClipboardEntry]` with per-entry `rowOffset` / `startOffsetMS`
  / `endOffsetMS`. `copySelectedEffects()` resolves the anchor
  (earliest-row, tiebreak earliest-start) and records every
  selected effect's offset. `pasteEffect(rowIndex:startMS:)`
  iterates entries, applying `rowOffset` + `startOffsetMS` to
  the target cell. Overlap rejection happens per-effect via the
  existing add pipeline; silent partial-paste on conflict. Cmd+C
  binds to `copySelectedEffects()` (falls back to single-copy
  when count ≤ 1). Duplicate shifts by `max(selection end)` so
  a copy-duplicate preserves inter-effect timing.
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
- **Gap B85 — Breakdown Word / Words.** See § 5.2 — port landed
  2026-04-21; iPad bridge + bundled dictionary still TODO.
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
| B4 | Shift / Ctrl arrow stretch / nudge | Editing | ✓ landed |
| B6 | Nudge by timing mark | Editing | P2 |
| B7 | Edge-unlink indicator + command | Editing | P2 |
| B9 | Shift-Align Start / End | Editing | ✓ landed |
| B10 | Align to closest timing mark | Editing | ✓ landed |
| B11 | Close Gap | Editing | ✓ landed |
| B13 | Extend effect to next / previous | Editing | P2 |
| B14 | Paste by cell | Editing | P1 |
| B15 | Randomize / Reset-to-default on selection | Editing | P1 |
| B16 | Drag-from-palette with preview ghost | Create | Deferred |
| B17 | Random-effect palette button | Create | P2 |
| B18 | Double-click create in range | Create | P2 |
| B19 | Effect presets menu entry | Ctx menu | P1 |
| B20 | Description / tooltip field | Ctx menu | P2 |
| B21 | Timing dialog (exact ms) | Ctx menu | ✓ landed |
| B22 | Reset effect to defaults | Ctx menu | P2 |
| B23 | Duplicate across models | Ctx menu | P2 |
| B24 | Find possible source effects | Ctx menu | P2 |
| B25 | Bracket colours sourced from `ColorManager` | Visual | P2 |
| B26 | ColorCurve gradient preview in effect bar | Visual | Verify |
| B27 | Node-level channel stripes | Visual | P2 |
| B28 | Reference / previous-selection indicator | Visual | P2 |
| B29 | Text fade / size stepping | Visual | P2 |
| B30 | Pointer hover states | Visual | P1 |
| B32 | Loop region (long-press + drag) | Timeline | ✓ landed |
| B33 | Play-loop mode | Timeline | ✓ landed |
| B34 | Tags (0-9 numbered markers) | Timeline | P1 |
| B35 | Tag context menu | Timeline | P1 |
| B36 | Zoom to selection | Timeline | ✓ landed |
| B37 | Zoom to fit (button) | Timeline | ✓ landed |
| B38 | Desktop zoom-level presets | Timeline | P2 |
| B39 | Drag to scrub | Timeline | ✓ landed |
| B40 | Audio scrub | Timeline | P2 |
| B41 | Waveform filter variants (bass / alto / treble) | Waveform | ✓ landed |
| B42 | Double-height waveform | Waveform | P2 |
| B43 | Audio-track switch (alt tracks) | Waveform | P2 |
| B44 | Render-selected-region | Waveform | ✓ landed |
| B45 | Click-seek + drag-range on waveform | Waveform | ✓ landed |
| B46 | Rename layer | Row heading | ✓ landed |
| B47 | Insert Multiple Layers Below | Row heading | P2 |
| B48 | Delete Unused Layers | Row heading | P2 |
| B49 | Export model / Render-and-Export | Row heading | P1 |
| B50 | Delete all effects on row | Row heading | ✓ landed |
| B51 | Enable / Disable render on model | Row heading | ✓ landed |
| B52 | Select all effects in model | Row heading | ✓ landed |
| B53 | Cut / Copy / Paste Row | Row heading | ✓ landed |
| B54 | Cut / Copy / Paste Model (+ submodels) | Row heading | ✓ landed |
| B55 | Convert Effects to 'Per Model' | Row heading | P2 |
| B56 | Promote Node / Convert To Effect | Row heading | P2 |
| B57 | Show All / Collapse All (unified) | Row heading | ✓ landed |
| B58 | Toggle Strands / Nodes / Models | Row heading | P2 |
| B60 | Drag row to reorder | Row heading | P2 |
| B61 | Drag-resize row-heading column width | Row heading | ✓ landed |
| B63 | Papagayo / FPP / group icon glyphs | Row heading | P2 |
| B64 | Layer-count [N] indicator | Row heading | P2 |
| B65 | Tooltip on truncated row name | Row heading | ✓ landed |
| B66 | Muted row visual state | Row heading | P2 |
| B74 | Import Timing Track (.xtiming) | Timing | ✓ landed |
| B75 | Export Timing Track (.xtiming) | Timing | ✓ landed |
| B76 | Make fixed timing track variable | Timing | ✓ landed |
| B77 | Import Notes (MIDI) | Timing | P2 |
| B78 | Import Lyrics | Timing | ✓ landed |
| B79 | AI Speech 2 Lyrics | Timing | P2 |
| B80 | Generate Subdivided Timing Tracks | Timing | ✓ landed |
| B81 | Hide All / Show All Timing | Timing | P2 |
| B82 | Add Timing Tracks to All Views | Timing | P2 |
| B83 | Create Timing From Effects | Timing | P2 |
| B84 (per-mark) | Single-mark phrase breakdown | Timing | P2 |
| B85 | Breakdown Word / Words | Timing | Deferred |
| B87 | Remove Words / Phonemes | Timing | ✓ landed |
| B89 | Auto Label Timings (numeric) | Timing | ✓ landed |
| B90 | Add / Remove "-shimmer" suffix | Timing | P2 |
| B91 | Divide Timings (Halve) | Timing | P2 |
| B92 | Double-tap timing mark → loop-play region | Timing | P2 |
| B94 | Visible scrollbars | Scroll | P1 |
| B96 | Scroll momentum | Scroll | P2 |
| B97 | Find / Replace | Find | P2 |
| B98 | Multi-effect clipboard with relative timing | Clipboard | ✓ landed |
| B99 | System pasteboard (UIPasteboard) integration | Clipboard | P2 |
| B100 | Paste-replacing-existing with confirmation | Clipboard | P2 |

Counts (2026-04-20 end-of-session): **1 × P0**, **9 × P1**, **40 ×
P2**, **1 × Verify**, **2 × Deferred**. 20 P1s landed this session:
B4, B9, B10, B11, B21, B36, B37, B39, B46, B50, B51, B52, B53,
B54, B57, B65, B76, B80, B87, B98.
