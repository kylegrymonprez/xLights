# Phase C — Effect Settings Inspector (Pending Work)

Scope: the four panels that appear next to an effect on desktop —
**Effect settings**, **Color**, **Buffer**, **Blending** — and how the
iPad SwiftUI inspector (`src-iPad/App/EffectSettingsView.swift` + kin)
compares.

This is the remaining-work view. Items that have landed (tab shell,
visibility engine, value-curve editor, SubBuffer, RotoZoom, Blending
rows, palette, ~40 custom rows) are git history, not plan content.

---

## TL;DR

The metadata-driven skeleton is in good shape. Parsing, layout,
visibility rules, value curves, SubBuffer, RotoZoom presets, Blending,
Colour palette, and ~40 custom rows all round-trip byte-for-byte with
desktop. Undo/redo is wired into setting edits and exposed via toolbar
+ Cmd+Z / Cmd+Shift+Z.

Remaining gaps fall into six buckets, ordered by user-visible impact:

1. **Discoverability / information architecture** — one long scroll
   per tab, no search, no collapse-all, no recent settings. Flagged in
   code as "doesn't scale past a handful of properties."
2. **Media picker and sequence-wide media management** — iPad's file
   picker is filename + Select/Clear with no thumbnail, no "media
   already used in this sequence" list, and no equivalent of desktop's
   `ManageMediaPanel` (embed / extract / rename / remove-unused / AI
   generate / video compat check). Reusing the same image across ten
   Pictures effects means ten filesystem browses.
3. **Multi-effect operations** — bulk-edit, lock, randomize are not on
   iPad. The plumbing to select multiple effects exists in the grid,
   but the inspector has no multi-selection model.
4. **Expert-surface controls** — palette ColorCurves, per-slider
   right-click / long-press context actions (copy, paste, reset, lock,
   randomize, value-curve, bulk-edit), effect-level presets.
5. **Assist panels and specialised editors** — Morph line editor,
   Sketch path editor, Pictures frame editor, Moving Head fixture
   editor. Only Moving Head is a wholesale gap; the others have
   desktop-created data that iPad round-trips but can't edit.
6. **Workflow niceties** — transition preview thumbnail, transition
   Adjust slider interactivity for supported types, DMX Remap / Save
   State / Load State dialogs.

---

## 1. Inspector scaffolding

Four-tab shell (Effect / Colors / Blending / Buffer) with
`@AppStorage`-persisted segmented tab bar is in place. Metadata reload
cached in `metadataCache`. Layout primitives (flat list + `tabs` /
`sections` / `xyCenter` groups) match desktop's organisation.

**Gap G1 — No tear-out / multi-window for the four inspector tabs.**
Desktop lets users dock Color, Buffer, Blending as separate wx panels.
iPad plan routes this through Phase F ("Open in new window"). Not a
correctness gap; noted here so it isn't lost.

**Gap G2 — Information architecture (rescoped 2026-04-20).**
Original framing assumed generic search / collapse-all / pin across
every tab. A property-count audit showed that's overkill: the four
C/T/B/Effect tabs plus the `tabs` / `section` / `xyCenter` groups
authored into each effect's JSON already break almost every effect
down to < 10 properties per tab. Liquid (44 props) renders as 4
internal tabs of 7-8 props; Morph (21) as 3 tabs; Pictures / Text
(17) as tabs + xyCenter groups; etc.

What actually remains:

- ~~**G2-a — Shape.json grouping.**~~ **Landed 2026-04-20.** Added a
  4-tab layout (Shape / Size / Motion / Triggers) plus an xyCenter
  group for Shape_CentreX / Shape_CentreY to `Shape.json`. All 27
  properties land inside a tab; no ungrouped flat scroll remains.
  Renders through the shared schema path on both desktop
  (`JsonEffectPanel`) and iPad (`EffectMetadataPanel`) without code
  changes. README.txt has a corresponding `-enh` line since it's a
  user-visible desktop layout change.
- ~~**G2-b — Remembered DMX bank state.**~~ **Landed 2026-04-20.**
  `DMXChannelsNotebookView.expandedGroupRaw` is now
  `@AppStorage("DMXExpandedGroup")` (Int, -1 sentinel for all
  collapsed), so the currently-expanded bank survives selection
  changes and app relaunches.
- **G2-c — Shader uniform grouping.** Usually fine (most .fs files
  declare < 10 uniforms), but large shader packs with 20+ uniforms
  turn into a flat scroll. If `GLSL_GROUP:` comment conventions
  exist in desktop's shader parser, respect them in
  `ShaderConfig::GetDynamicPropertiesJson()` so the schema already
  carries section structure by the time iPad sees it. Deferred
  until a real complaint surfaces.

Generic inspector-wide search / collapse-all / pin is no longer
planned.

---

## 2. Effect settings tab (per-effect controls)

### Metadata coverage

Primitive types (`slider`, `text`, `choice`, `checkbox`, `spin`,
`fontpicker`, `filepicker`, `colorpicker`, `custom`), most visibility
rules (`equals`, `notEquals`, `oneOf`, `notOneOf`, `greaterThan`,
`startsWith`, `any`), grouped `tabs` / `sections`, `xyCenter` (via
`XYCenterPadView`), and ~40 custom row ids are handled.

**Parity on primitives:** ✓

### Custom rows

**Missing on iPad:**

- **Gap G3 — Moving Head fixture editor.** Desktop's one non-JSON
  panel: hand-built in wxSmith for DMX fixture mapping, pan/tilt /
  colour wheels, position curves, etc. No iPad counterpart at all.
  Moving Head sequences edited on desktop render fine on iPad (core
  renderers are shared) but can't be edited. ~30+ controls.

- **Gap G4 — Sketch path editor.** `SketchInfoRowView` /
  `SketchDefRowView` / `SketchBackgroundRowView` display the encoded
  sketch definition read-only. Code comment: *"Sketch paths are drawn
  via the desktop Effect Assist. iPad playback works, but the path
  editor is desktop-only."* No polyline drawing UI.

- **Gap G5 — Morph line editor (Effect Assist).** Desktop ships
  `xlGridCanvasMorph` (drag start/end line endpoints on a 100×100
  grid). iPad has QuickSet presets + Swap but no direct line editing.
  Users on iPad can pick one of 8 quick presets or type numbers; they
  cannot drag a line.

- **Gap G6 — Pictures frame/GIF timing editor (Effect Assist).**
  `PicturesAssistPanel` on desktop lets users scrub animated-GIF
  frames, set per-frame timing. iPad: filename picker only, no frame
  UI.

- **Gap G8 — DMX Remap / Save State / Load State buttons.** Rendered
  disabled. Depends on desktop dialog flow and model-state read/write
  bridge paths that haven't been ported to iPad.

### Per-property actions (right-click on desktop)

**Desktop** exposes a context menu on virtually every slider / text /
choice / colourpicker:

- Value Curve editor (also on dedicated VC button)
- Lock (skip this control during Randomize Effect)
- Randomize (randomize just this one control)
- Bulk Edit — apply this value to all selected effects
- Copy value / Paste value / Reset to default
- Some controls: Shift-click to paste into all selected

**iPad:** no long-press / context menu on property rows.
`.contextMenu` appears on `RowHeaderViews.swift` (model rows) and
`SequencerGridV2View.swift` (effect bars), but nothing in
`EffectPropertyView.swift`, `EffectCustomRows*.swift`, or
`BlendingPanelViews.swift`. Value curves work via a dedicated VC
button; no other per-property action is reachable.

- **Gap G9 — Per-property context menu.** Long-press on a slider /
  field to access: VC (already has a button), Lock, Randomize
  (single), Bulk Edit, Copy / Paste / Reset.

- **Gap G10 — Lock + Randomize per property.** `EffectMetadata.swift`
  parses the `lockable` flag but never renders a lock UI. Top-level
  "Randomize Effect" button (desktop `TopEffectsPanel` has this next
  to the effect icon) is not present on iPad either — the inspector
  has no "randomize this whole effect" action.

- **Gap G11 — Bulk Edit.** Desktop's `SetSupportsBulkEdit(true)`
  controls get a gold-check indicator and a "Apply to all selected"
  context-menu entry. iPad: no indicator, no entry, no multi-effect
  selection carry-over to the inspector. The grid *does* support
  multi-select; the inspector just doesn't use it.

### Effect-level operations

- **Gap G12 — Effect presets.** Desktop has `EffectPresetManager` +
  effect-tree UI for saving named preset bundles (full effect +
  colour + buffer + blending settings). iPad: no save / load preset
  UI.

- **Gap G13 — Copy / Paste effect settings.** Desktop copy of an
  effect pastes settings into another. iPad grid supports copy/paste
  of whole effects (`"Paste Effect"` undo action exists), but
  per-setting clipboard from the inspector doesn't exist.

- **Gap G14 — "Update all like this" / Find similar.** Desktop has an
  "Update" button (top bar) that writes the current panel values
  across all selected. iPad: no equivalent. Missing because there's
  no multi-selection from the inspector's point of view.

### Keyboard

- **Gap G15 — Keyboard shortcuts in the inspector.** Desktop: Ctrl+E
  opens VC editor, Ctrl+L toggles lock, tab navigation moves focus
  through controls. iPadOS 26 supports hardware keyboards and
  `.keyboardShortcut`, but the inspector doesn't declare any
  shortcuts. Phase F ("menu bar + discoverable shortcuts") covers
  this at the app level; individual inspector actions would need to
  be exposed.

### Minor polish

- **`ShapeChar` glyph preview.** 32pt live-preview area renders
  today; cosmetic polish would enlarge the preview and improve
  typography fallback when the code isn't a registered glyph.

- **`StatePanel.State_Mode`.** Rendered as a standard choice; verify
  on device that the enum values round-trip correctly with
  `dynamicOptions: "states"` resolution.

---

## 3. Color panel

### Palette

**Desktop:** 8 slots, each can hold either a colour (hex) *or* an
active ColorCurve serialised string. Buttons include Shift-left /
Shift-right, Reverse, Recent-palettes menu, Import / Export /
Generate / Delete / Save / Save-As. Right-click a slot toggles
active/inactive; double-click switches a slot into colour-curve mode.

**iPad:** 8 slots (enable toggle + `ColorPicker`). Default palette
matches desktop. Wide-gamut Display P3 → sRGB conversion handled
before emitting hex.

- **Gap G16 — Palette ColorCurve editor (with integrated time /
  spatial mode selector).** Slots containing a ColorCurve string
  render as a grey tile with "(curve)" label today; the stored value
  round-trips but the user can't edit it.

  The full editor is a modal sheet along the same lines as
  `ValueCurveEditor.swift` — draggable gradient control points,
  presets, flip / mirror — but with one iPad-specific consolidation:
  **the desktop's separate per-slot time / spatial mode button is
  merged into this dialog** rather than shipping as its own row of 8
  buttons.

  **What the merged mode selector does.** Every ColorCurve has a
  `_timecurve` field (`ColorCurve.h:152-160`) that controls how the
  gradient is evaluated at render time:

  | Mode | Constant | Behaviour |
  |---|---|---|
  | Time | `TC_TIME` (0) | Gradient advances over the effect's duration (default). |
  | Right / Down / Left / Up | `TC_RIGHT`, `TC_DOWN`, `TC_LEFT`, `TC_UP` (1-4) | Gradient evaluated spatially across the buffer in that direction. |
  | Radial in / out | `TC_RADIALIN`, `TC_RADIALOUT` (5-6) | Gradient radiates from or to centre. |
  | CW / CCW | `TC_CW`, `TC_CCW` (7-8) | Gradient rotates around the centre. |

  On desktop this is a cycle-button under the lock
  (`ID_BITMAPBUTTON_BUTTON_PaletteCC1..8`,
  `ColorPanel.cpp:311-322`) whose bitmap doubles as at-a-glance
  status. On iPad we're reclaiming that button row for palette space
  and putting the control inside the editor as a segmented picker.

  **Availability is per-effect.** When the user selects an effect,
  `tabSequencer.cpp:2582` calls `colorPanel->SetSupports(...)`. The
  virtuals live on `RenderableEffect` and are overridden per effect:
  - Both: `OnEffect`
  - Linear only: `Bars`, `Spirals`, `Shimmer`, `SingleStrand`, `Warp`
  - Radial only: `Fan`, `Pinwheel`, `Ripple`, `Shockwave`
  - Neither: `Kaleidoscope`, `Shader` (locked to `TC_TIME`)

  On iPad the segmented picker greys out unavailable groups based on
  the effect's support flags.

  **At-a-glance status on the slot itself.** To preserve the
  discoverability desktop gets "for free" from the mode-icon button,
  the iPad palette slot shows a **small mode badge** overlaid on the
  gradient thumbnail when a curve is active (↔ for L/R, ↕ for U/D,
  ◎ for radial, ↻ for rotation, no badge for TC_TIME). Read-only;
  tapping the slot opens the editor where the mode can be changed.

  **Bridge work that lands with this gap:**
  - `SequencerViewModel` call exposing `(supportsLinear: Bool,
    supportsRadial: Bool)` for the currently-selected effect, via
    `RenderableEffect::SupportsLinearColorCurves` /
    `SupportsRadialColorCurves`.
  - ColorCurve parse / serialise wrapper (analogue of `XLValueCurve`)
    — a read/write ObjC++ bridge so SwiftUI can drive the editor
    without re-implementing the serialisation format.
  - SwiftUI `ColorCurveEditor` sheet (gradient canvas + point editor
    + time / spatial picker + type / preset controls).
  - Slot badge renderer.

- **Gap G17 — Palette management actions.** Shift left / right,
  Reverse, Recent palettes, Import / Export / Save-As / Generate.
  None present on iPad.

- **Gap G18 — Drag colours between slots.** Desktop supports
  drag-drop within palette; iPad doesn't.

### Palette-adjacent rows

ChromaKey, Sparkles (including VC), and BrightnessLevel are landed.
The HSV adjustment sliders (`C_SLIDER_Brightness`,
`C_SLIDER_Contrast`, `C_SLIDER_Color_HueAdjust`,
`C_SLIDER_Color_SaturationAdjust`, `C_SLIDER_Color_ValueAdjust`) are
defined in `shared/Color.json` and should fall through the generic
metadata path.

- **Gap G19 — Verify HSV adjustment sliders render.** Code-side audit
  2026-04-20: schema correct, all five declared as sliders. Four have
  `valueCurve: true` (Brightness, HueAdjust, SaturationAdjust,
  ValueAdjust); Contrast does not (desktop parity — no VC on Contrast
  either, so the original gap description was imprecise). Device
  check: select any effect → Colors tab → 5 sliders past the palette,
  4 with the VC pill. Close once verified.

---

## 4. Buffer panel

Buffer tab is largely at parity. SubBuffer canvas is interactive
(draggable corners, presets menu, xc/yc offsets, per-slot value
curves). RotoZoomPreset menu writes the same slider + VC strings as
desktop's `BufferPanel::OnPresetSelect`.

- **Gap G21 — PerPreviewCamera dynamic list.** Code-side audit
  2026-04-20: blocked on Phase D-3 (ViewpointMgr bridging), not a
  bug in the inspector. `Buffer.json` declares
  `options: ["2D"]` with no `dynamicOptions` source; desktop
  populates at runtime from `ViewpointMgr::GetNum3DCameras()` +
  `GetCamera3D(i)->GetName()`, and iPad's `iPadRenderContext`
  doesn't bridge `ViewpointMgr` yet. When D-3 lands, add a
  `"cameras"` dynamicOptions source wired to a new bridge method
  (`cameraNames` returning `["2D"] + 3D camera names`) and drop the
  static `options` array from the schema. Until then the picker
  shows a single-entry "2D" on iPad — that's today's expected state.

Note: "Reset panel when changing effects" (desktop wxConfig preference)
is intentionally suppressed on iPad — the iPad doesn't reset state on
effect change, so `EmptyView` is the correct rendering. Not a gap.

---

## 5. Blending panel

Blending tab largely at parity. LayerMorphRow, LayerMethodRow (with
help sheet), CanvasRow with modal layer-selection picker, Transition
headers with fade-time presets. Runtime disable of Adjust / Reverse
when `fade == 0` or type ∈ `kTransitionsNoAdjust` /
`kTransitionsNoReverse` has landed.

- ~~**Gap G23 — Transition Adjust slider for supported types.**~~
  **Landed 2026-04-20.** Code-side audit showed the supported-adjust
  path was already functional — `EffectPropertyView.runtimeDisabled`
  returns false when the selected transition is not in
  `kTransitionsNoAdjust` / `kTransitionsNoReverse` with a non-zero
  fade, so the slider / checkbox / VC button all enable normally in
  that state. One actual gap found: iPad's `kTransitionsNoReverse`
  was a 5-entry subset of desktop's 12-entry `TRANSITIONS_NO_REVERSE`
  (`BlendingPanel.cpp:76`), so Reverse was mis-enabled for Slide
  Bars / Circular Swirl / Zoom / Doorway / Pinwheel / Swap / Circles.
  Synced the list to match desktop verbatim so the enable / disable
  decision is identical on both platforms. Reactivity was already in
  place via the observable `selectedEffectSettings` dict — changing
  the Type picker auto-refreshes sibling Adjust / Reverse rows.

- **Gap G24 — Transition live preview thumbnail.** Desktop renders a
  small animated thumb of the current transition. iPad: none. Can
  ship first as a static icon per type and land the live thumb later.

- **Gap G25 — `SuppressEffectUntil` / `FreezeEffectAtFrame`.** Code-
  side audit 2026-04-20: schema correct (`spin` 0..999999,
  `suppressIfDefault: true` for both), `EffectPropertyView.spinView`
  handles the range (`EditableNumberField` for typed input + Stepper
  ±1). Device check: select any effect → Blending tab → both appear,
  typed value accepted, returning to default (0 / 999999) removes
  the setting. Close once verified.

---

## 6. Media picker and sequence-wide media management

This cuts across the Effect tab for every effect that references a
file: **Pictures**, **Video**, **Shader**, **Text** (text-from-file
and bitmap-font files), **Shape** (SVG), **Ripple** (SVG), **Sketch**
(background image), **Faces** (per-phoneme images), **Glediator**,
**VUMeter**. That's 10+ effects that all hit the same picker today.

### 6.1 Desktop picker: `MediaPickerCtrl` + `SelectMediaDialog`

**`src-ui-wx/shared/controls/MediaPickerCtrl.cpp/h`** is the per-field
picker used inside effect panels. It's *not* just a file dialog:

- **Small thumbnail preview** (32-48 px) inline next to the filename
  — images, SVGs, first-frame of a video, first frame of an animated
  GIF. Animated GIFs auto-cycle frames while the panel is visible.
- **"Select…" button** opens `SelectMediaDialog`, which is backed by
  `ManageMediaPanel` in single-select mode. That dialog shows a
  **two-level tree of every media file already referenced in the
  sequence**, grouped by media type then source directory. Pick with
  one tap; don't re-browse the filesystem.
- **"Add from Disk…"** button inside the dialog for when a new file
  is really needed — and when adding a video, it runs
  `MaybeConvertIncompatibleVideo()` which checks macOS AVFoundation
  codec compatibility and prompts to transcode .avi / .mkv → .mov.
- **Clear (X) button** clears the value.
- **Bulk-edit integration**: the hidden `wxFilePickerCtrl` plugs into
  the bulk-edit framework, so picking a file with N effects selected
  applies to all of them.

### 6.2 Desktop `ManageMediaPanel` — the sequence-wide manager

**`src-ui-wx/media/ManageMediaPanel.cpp/h`** is both:

1. The backing UI for `SelectMediaDialog` (single-select picker).
2. A sequence-level manager users reach to rationalise media.

Operations it exposes:

- **Media tree**: every media file touched by any effect in the
  sequence, grouped by type (Images / Videos / Shaders / SVGs / Text
  / Binary) and then by source directory, with columns: Name, Size
  (dimensions for images), Frames (for animated formats), Status
  (Embedded / External / "(broken)" in red if missing).
- **Preview pane**: 100×100 scaled thumbnail, with animated cycling
  for multi-frame images.
- **Embed / Extract** (per file or `Embed All` / `Extract All` for
  all of a type): writes base64 data into the `.xsq` so the sequence
  is portable, or extracts back to disk on demand.
- **Rename** (embedded images): renames the cache key and walks every
  effect in the sequence updating references — users can't get into
  a "broken by rename" state.
- **Remove unused**: scans effects, drops any media not referenced.
- **AI Generate…**: creates an image via xLights' AI service and adds
  it to the sequence cache directly.

### 6.3 Under both: `SequenceMedia` (shared core)

`src-core/render/SequenceMedia.cpp/h` is the engine both sides share.
It owns the per-sequence cache, the base64 embed / extract machinery,
the hot-reload-on-mtime-change logic, and the six entry types
(`ImageCacheEntry`, `SVGMediaCacheEntry`, `ShaderMediaCacheEntry`,
`TextMediaCacheEntry`, `BinaryMediaCacheEntry`,
`VideoMediaCacheEntry`). iPad *already* consumes this on load —
embedded images from a desktop-authored `.xsq` render fine on iPad.
What iPad is missing is the UI over the top.

### 6.4 What iPad has today

**`src-iPad/App/EffectFilenameBlockView.swift`** (Pictures / Video /
Shader) and **`FilepickerPropertyView.swift`** (generic JSON
filepicker: Glediator / VUMeter SVG / etc.):

- Filename label.
- `Select…` button → SwiftUI `.fileImporter()`.
- `X` clear button.
- **No thumbnail.**
- **No "media already in this sequence" shortcut list.**
- **No embed / extract.**
- **No rename.**
- **No remove-unused.**
- **No AI generate.**
- **No video compat check.**

**`src-iPad/App/MediaRelocation.swift`** is the one piece iPad does
*better* than desktop: picked files outside the show / media folders
are auto-copied into a chosen root (Show Folder / Media Folder N)
before the path is stored, and all stored paths round-trip through
`makeRelativePath()`. That's a genuine portability improvement —
broken references are structurally prevented. Not a gap; called out
because the existing plumbing is exactly what a "media manager" view
would build on.

### 6.5 Gaps

- **Gap G26 — No thumbnail on the effect-panel picker.** Users pick
  by filename only; no way to tell `xmas-01.png` from `xmas-02.png`
  without committing. Bridge could vend thumbnail PNG bytes from the
  shared `SequenceMedia` cache; SwiftUI renders.

- **Gap G27 — No "already used in this sequence" quick-pick list.**
  Biggest day-to-day friction the user called out: reusing the same
  image in ten Pictures effects means ten full filesystem browses.
  Desktop offers every referenced file as a one-tap choice in
  `SelectMediaDialog`'s tree. iPad has no equivalent UI even though
  `SequenceMedia::GetAllMediaPaths()` (or equivalent) already knows
  the answer.

- **Gap G28 — No sequence-wide media manager view.** No iPad view
  equivalent to `ManageMediaPanel`. Users can't see what media the
  sequence uses, can't spot missing files in one place, can't clean
  up unused ones, can't embed / extract in bulk.

- **Gap G29 — No embed / extract UI.** Even though `SequenceMedia` on
  iPad round-trips embedded media correctly, there's no way to turn
  embedding on or off from iPad. Users who want to publish a portable
  `.xsq` must do it on desktop first.

- **Gap G30 — No rename-embedded-with-reference-update.** Desktop's
  `EmbedWithRename()` / `ExtractWithRename()` walk all effects in the
  sequence updating settings when a filename changes. Not available
  on iPad.

- **Gap G31 — No "Remove unused media" action.** No way for iPad
  users to drop orphaned media from the sequence file. Sequences
  imported onto iPad that were edited heavily on desktop may carry
  unused payload indefinitely.

- **Gap G32 — No video compat check / transcode.** Desktop's
  `MaybeConvertIncompatibleVideo()` catches AVFoundation-incompatible
  containers at pick time and prompts to transcode. iPad accepts the
  file silently; the effect fails to render later with no clear error
  path.

- **Gap G33 — No AI image generation entry point.** Desktop has AI
  Generate in both `PicturesPanel` and `ManageMediaPanel`. Not
  present on iPad.

- **Gap G34 — No animated-GIF / video thumbnail cycling.** Desktop
  `MediaPickerCtrl` and `ManageMediaPanel` both auto-cycle
  multi-frame thumbnails while visible. Read-only on iPad means no
  preview at all.

- **Gap G35 — Effects beyond the 3 custom filename-blocks.** The
  `EffectFilenameBlockView` only covers Pictures / Video / Shader.
  Shape / Ripple / Sketch / Text-from-file / Faces fall through
  generic `FilepickerPropertyView` which also has no thumbnail and
  no sequence-media shortcut. Any fix to G26 / G27 should cover both
  paths.

### 6.6 Suggested shape of the fix (sketch, not a plan)

Lowest-effort high-impact combo:

- Add `SequencerViewModel.mediaInSequence(ofType:)` bridge call that
  returns every path currently referenced by an effect in the
  sequence, grouped by effect type. Backed by
  `SequenceMedia::GetAllMediaPaths()` which already exists.
- Replace `EffectFilenameBlockView`'s `Select…` button with a menu /
  sheet that shows:
  1. Recently used in this sequence (top, one-tap) — with thumbnails.
  2. "Browse…" (today's `.fileImporter` behaviour).
  3. "Clear".
- Add a thumbnail bridge call for a given stored path → `UIImage`
  (via `SequenceMedia::GetThumbnail()` on desktop's side).
- Reuse the same sheet as a standalone tab in FolderConfig or
  sequence-settings so users can browse / clean up media without an
  effect selected.

Embed / extract / rename / AI are deferred but are layered on the same
bridge.

---

## 7. Value Curves

The editor covers all 23 types, P1-P4, min/max, wrap / real values /
time offset, timing / audio / filter, custom-point canvas (tap to add,
drag to move, long-press to delete), live preview, byte-for-byte
serialisation parity with desktop, and dynamic Timing Track picker
backed by `dynamicOptions`. Pending:

- **Gap G36 — Preset load / save from disk.** Desktop can load `.xvc`
  presets from `xLights/valuecurves/`. iPad has no preset UI. Bridge
  would vend the preset list from the shared folder.
- **Gap G37 — VC copy / paste.** Desktop allows copying the
  serialised VC string to clipboard so it can be pasted to another
  control. iPad: no copy / paste.
- **Gap G38 — Flip / Mirror / Repeat shortcut buttons.** Desktop has
  one-tap buttons for these transforms. iPad: achievable by editing
  parameters but no shortcut.

---

## 8. Cross-cutting

### Drag / drop

- **Gap G40 — Drag colours, palettes, value curves.** Desktop
  supports drag-drop across slots and between controls. iPad has no
  drag-drop support in the inspector.

### Bulk / multi-selection

- **Gap G41 — Multi-select in the grid + inspector.** The grid
  supports multi-select (`contextMenuTarget` etc.). The inspector
  doesn't materialise anything when multiple effects are selected.
  Desktop typically shows the first-selected effect's panel but
  enables "Apply to all selected" context actions. iPad model needs
  to decide: do we show "3 effects selected" chrome, or switch the
  inspector into a "bulk" mode?

---

## 9. Assist panels inventory

| Assist | Desktop | iPad |
|---|---|---|
| Morph line editor | `xlGridCanvasMorph.cpp` — drag line endpoints | ✗ Missing (G5) |
| Pictures frame/GIF timing | `PicturesAssistPanel.cpp` | ✗ Missing (G6) |
| Sketch path drawing | `SketchAssistPanel.cpp` + `SketchCanvasPanel` | ✗ Missing (G4) |
| Moving Head fixture editor | `MovingHeadPanel.cpp` (wxSmith) | ✗ Missing (G3) |

All four let desktop users create data that iPad plays back correctly
but can't author. For MVP iPad, acceptable if the app positions
itself as "edit sequences authored on desktop." For full parity, all
four need SwiftUI equivalents.

---

## 10. Summary gap table

Severity key:
- **P0** — blocks common workflows; users hit this often.
- **P1** — blocks specialised workflows; some users hit this.
- **P2** — nice-to-have / parity items.

| # | Gap | Area | Severity |
|---|---|---|---|
| G1 | Tear-out / docking of tabs into separate windows | Scaffolding | P2 |
| ~~G2-a~~ | ~~Shape.json needs `tabs`/`section` grouping (only flat-scroll effect in the tree)~~ | ~~Scaffolding~~ | ~~landed~~ |
| ~~G2-b~~ | ~~Remembered DMX channel-bank expansion state across effect changes~~ | ~~Scaffolding~~ | ~~landed~~ |
| G2-c | Shader dynamic uniform grouping for large .fs files | Scaffolding | P2 |
| G3 | Moving Head fixture editor | Effect settings | P1 |
| G4 | Sketch path editor | Effect settings | P1 |
| G5 | Morph line editor | Effect settings | P1 |
| G6 | Pictures frame / GIF timing editor | Effect settings | P2 |
| G8 | DMX Remap / Save State / Load State dialogs | Effect settings | P1 |
| G9 | Per-property long-press context menu | Effect settings | P0 |
| G10 | Per-property Lock + Randomize | Effect settings | P1 |
| G11 | Bulk Edit (apply to multiple selected effects) | Effect settings | P1 |
| G12 | Effect presets (save / load named) | Effect settings | P1 |
| G13 | Per-setting Copy / Paste from inspector | Effect settings | P2 |
| G14 | "Update all like this" batch update | Effect settings | P2 |
| G15 | Keyboard shortcuts in inspector | Effect settings | P2 |
| G16 | Palette ColorCurve editor (incl. integrated time / spatial mode selector + on-slot mode badge) | Color | P1 |
| G17 | Palette shift / reverse / import / export / save-as | Color | P1 |
| G18 | Drag colours between palette slots | Color | P2 |
| G19 | Verify HSV adjustment sliders render | Color | P1 |
| G21 | Verify PerPreviewCamera dynamic options | Buffer | P1 |
| ~~G23~~ | ~~Transition Adjust + Reverse interactivity (supported types)~~ | ~~Blending~~ | ~~landed~~ |
| G24 | Transition live preview thumbnail | Blending | P2 |
| G25 | Verify SuppressUntil / FreezeAtFrame render | Blending | P1 |
| ~~G26~~ | ~~No thumbnail on effect-panel file picker~~ | ~~Media~~ | ~~landed~~ |
| ~~G27~~ | ~~No "already used in this sequence" quick-pick list~~ | ~~Media~~ | ~~landed~~ |
| G28 | No sequence-wide media manager view | Media | P1 |
| G29 | No embed / extract UI | Media | P1 |
| G30 | No rename-embedded with reference update | Media | P2 |
| G31 | No "Remove unused media" action | Media | P2 |
| G32 | No video compat check / transcode | Media | P1 |
| G33 | No AI image generation entry point | Media | P2 |
| ~~G34~~ | ~~No animated-GIF / video thumbnail cycling~~ | ~~Media~~ | ~~landed (images/video/GIF)~~; shader preview deferred |
| ~~G35~~ | ~~Generic `FilepickerPropertyView` also needs thumbnail + reuse list~~ | ~~Media~~ | ~~landed~~ |
| G36 | Value-curve preset load / save from disk | Value Curve | P2 |
| G37 | Value-curve copy / paste | Value Curve | P2 |
| G38 | Value-curve Flip / Mirror / Repeat shortcut buttons | Value Curve | P2 |
| G40 | Drag / drop in inspector | Cross-cutting | P2 |
| G41 | Multi-effect selection in inspector | Cross-cutting | P1 |

---

## 11. Suggested phasing

**C1 — Discoverability + quick wins (1-2 weeks)**
- ~~G9~~ **landed** — long-press context menu on slider / checkbox /
  choice / spin / text rows exposes Copy / Paste / Reset / Edit VC.
- ~~G13~~ **landed** — per-setting copy / paste falls out of G9 via
  the `xlprop:v1:` pasteboard prefix.
- ~~G2-a~~ **landed** — Shape.json now uses 4-tab grouping + xyCenter.
- ~~G2-b~~ **landed** — DMX channel-bank expansion persists via
  `@AppStorage`.
- G19 / G21 / G25: Verify auto-rendered sliders on device; file small
  issues if any fail. Code-side audits done 2026-04-20; G21 is
  blocked on Phase D-3 (ViewpointMgr bridging).

**C2 — Media picker reuse + thumbnails**
- ~~G26 + G27 + G35~~ **landed 2026-04-20.** `MediaPickerSheet.swift`
  replaces the plain Select… button on both `EffectFilenameBlockView`
  and `FilepickerPropertyView`. Top section lists every media file
  referenced by an effect in this sequence, filtered by type (image /
  video / shader / svg / binary / text), with async thumbnails and
  one-tap commit. Bottom section keeps Browse… (current fileImporter
  behaviour) and Clear. Bridge additions on `XLSequenceDocument`:
  `mediaPathsInSequence`, `ensureThumbnailPreview(forPath:…)`,
  `thumbnailPNG(forPath:frameIndex:)`,
  `thumbnailFrameTimeMS(forPath:frameIndex:)`. Backed by
  `SequenceMedia::GetAllMediaPaths()` + `MediaCacheEntry::GeneratePreview`
  (already-shared core API). Thumbnails load on a utility queue so
  cold caches don't block main.
- ~~G34~~ **landed 2026-04-20.** `MediaThumbnailView` cycles
  multi-frame content (animated GIF / WebP / video) at the cadence
  the underlying format declares, via a cooperative `Task`. Cycle
  pauses on scene-phase change and on view disappear.
- ~~G2-c~~ **landed 2026-04-20.** Shader preview generation ported
  from desktop `ShaderPreviewGenerator.cpp` — not wxGLCanvas-based as
  I'd initially miscategorised; it goes through the shared render
  engine against a standalone preset matrix model. iPad side:
  `iPadRenderContext` gained a preset scaffolding (`MatrixModel`
  64×64 RGB + dedicated `ModelManager` / `SequenceElements` /
  `SequenceData`), a `RenderEffectToFrames` helper ported verbatim
  from `xLightsFrame::RenderEffectToFrames`
  (`TabConvert.cpp:856`) — including the local `FillXlImage` /
  `RenderModelOnXlImage` raster helpers — plus
  `GenerateShaderPreview(ShaderMediaCacheEntry*)` which builds the
  default settings string (including all dynamic uniforms via
  `ShaderConfig::GetParms()`), adds a 1-second shader effect to the
  preset sequence, and fills the preview-frame strip. Bridge
  `ensureThumbnailPreviewForPath` routes shader entries through the
  new path; non-shader entries keep using `MediaCacheEntry::GeneratePreview`.
  Shader thumbnails cycle alongside GIFs / video in the picker.

**C3 — Multi-effect operations (2-3 weeks)**
- G11 + G41: Wire the grid's multi-select to the inspector. Add "N
  effects selected — apply value to all" affordance per control.
- G10: Lock + single-control Randomize in the context menu. Top-level
  "Randomize effect" button in the inspector header.
- G14: "Update all like this" as a consequence of G11.

**C4 — Sequence-wide media manager (1-2 weeks)**
- G28: Build iPad equivalent of `ManageMediaPanel` — full list of
  sequence media with per-file preview and status. Layered on the
  bridge from C2.
- G29: Embed / Extract buttons (per file + Embed All / Extract All
  per type).
- G30: Rename embedded media with reference update across all effects.
- G31: Remove unused media.
- G32: Video compat check on file pick (prompt to transcode via
  shared `MaybeConvertIncompatibleVideo` path).

**C5 — Colour workflow (2-3 weeks)**
- G16: Palette ColorCurve editor — modal sheet along
  `ValueCurveEditor.swift` lines, plus the time / spatial mode picker
  integrated as a segmented control inside the sheet (rather than a
  separate button row on the palette grid), plus a small read-only
  mode badge on the slot's gradient thumbnail for at-a-glance status.
  Bridge adds per-effect `SupportsLinearColorCurves` /
  `SupportsRadialColorCurves` to grey-out unavailable groups, plus a
  ColorCurve parse / serialise wrapper analogue to `XLValueCurve`.
  Single biggest user-visible missing feature on the Color tab.
- G17: Palette shift / reverse / save / load / import / export.
- G18: Drag colours between slots.

**C6 — Blending / Transitions polish (1 week)**
- ~~G23~~ **landed** — per-transition Adjust / Reverse enable tables
  synced with desktop.
- G24: Transition preview thumbnail (can be a static icon per type
  initially; live thumb later).

**C7 — Effect presets (1-2 weeks)**
- G12: Save / load presets, using the existing
  `EffectPresetManager`-compatible file format so presets round-trip
  with desktop.

**C8 — Specialised editors (bigger chunks)**
- G3: Moving Head — the largest single piece; full fixture editor.
- G4: Sketch path editor.
- G5: Morph line editor (smaller — a 2D drag surface).
- G6: Pictures frame timing.
- G8: DMX dialog ports.
- G33: AI image generation (also depends on iOS bridge for AI service).

**Deferrals**
- G1 (tear-out / multi-window) — scoped as Phase F; leave there.
- G15 (keyboard shortcuts) — rolls in with the Phase F menu bar.

---

## 12. Out of scope

- Core renderer parity (already verified on device).
- Rendering performance / JobPool tuning (covered in the main plan).
- Sequence-lifecycle / save / sequence-settings UI (Phase E in the
  main plan — the inspector edits settings in-memory; persistence
  and the Sequence Settings dialog belong there).
- Controller output, iCloud document handling, App Store submission
  (Phase G / H in the main plan).
- Model / layout editing (separate surface, not the effect inspector).
