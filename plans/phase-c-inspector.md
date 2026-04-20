# Phase C — Effect Settings Inspector (Pending Work)

Scope: the four panels next to a selected effect — **Effect settings**,
**Color**, **Buffer**, **Blending**. Large chunks have landed —
primitive controls, custom rows, visibility engine, value-curve
editor, shader preview generation, palette ColorCurve editor,
palette file I/O, per-effect media picker with in-sequence reuse /
thumbnails / folder grouping, context menu, sequence-wide media
manager, embed / extract / rename / remove-unused / video compat
check, value-curve preset files + transforms + clipboard. Everything
below is what's still missing.

---

## TL;DR

1. **Multi-effect operations** (C4). Grid supports multi-select;
   inspector doesn't consume it yet. **Blocked** — upstream grid
   multi-select is in flight on a separate thread.
2. **Specialised editors** (C7) — Moving Head, Sketch path, Morph
   line, DMX Remap / Save State / Load State. Each is its own
   session.
3. **Polish items** — drag / drop in inspector, shader uniform
   grouping.

Two items are deferred to Phase F (tab tear-out, keyboard
shortcuts). A handful of smaller pieces live in `future-*.md`.

---

## 1. Inspector scaffolding

- **G2-c — Shader dynamic uniform grouping for large `.fs` files.**
  Most shaders declare < 10 uniforms so grouping isn't needed;
  packs with 20+ turn into a flat scroll. If `GLSL_GROUP:` comment
  conventions exist in desktop's shader parser, respect them in
  `ShaderConfig::GetDynamicPropertiesJson()` so grouping carries
  across. Deferred until a real shader pack trips the issue. P2.

---

## 2. Effect settings tab

### Specialised editors (desktop-authored data iPad can render but not edit)

- **G3 — Moving Head fixture editor.** Desktop's one non-JSON
  panel: hand-built in wxSmith for DMX fixture mapping, pan / tilt
  / colour wheels, position curves. ~30+ controls. P1.
- **G4 — Sketch path editor.** `SketchInfoRowView` /
  `SketchDefRowView` / `SketchBackgroundRowView` read the encoded
  sketch definition but don't offer a polyline editor. P1.
- **G5 — Morph line editor.** Desktop's `xlGridCanvasMorph` — drag
  start / end line endpoints on a 100×100 grid. iPad has QuickSet
  presets + Swap but no direct line editing. P1.
- **G8 — DMX Remap / Save State / Load State buttons.** Rendered
  disabled today. Depends on model-state read / write bridge paths
  not yet on iPad. P1.

### Per-property & effect-level actions

- **G10 — Per-property Lock + Randomize.** `EffectMetadata.swift`
  parses the `lockable` flag but no lock UI. No per-control
  Randomize menu entry, no top-level "Randomize Effect" button.
  Desktop's lock is in-memory session state (not persisted) so
  iPad should match. P1 (low priority — uncertain whether the
  randomize UX even belongs on iPad).
- **G11 — Bulk Edit.** Desktop's `SetSupportsBulkEdit(true)`
  controls get an "Apply to all selected" context-menu entry. iPad
  has no such entry and no multi-effect carry-over to the
  inspector. Needs G41 first (grid → inspector multi-selection). P1.
- **G14 — "Update all like this" batch update.** Desktop's top-bar
  "Update" writes the current panel values across all selected.
  Falls out of G11. P2.

---

## 3. Sequence-wide media management — remaining

The manager view, inventory bridge, embed / extract, rename (with
on-disk move + reference rewrite), remove-unused, and video compat
check are all landed. The one remaining Media-tab item is:

- **G33 — AI image generation entry point.** Deferred to
  [`future-ai-image-generate.md`](future-ai-image-generate.md).
  Shares the iOS AI service bridge with the palette-generate
  future work; both come up together when the bridge lands.

Small polish follow-ups still open:

- **Video compat badge in the media manager.** Incompatible
  videos show as "External" today; badging them requires caching
  the `CheckVideoFile` probe per entry so the inventory refresh
  doesn't re-open every video. Low priority.

---

## 4. Cross-cutting

- **G40 — Drag / drop in inspector.** Desktop supports drag-drop
  across palette slots and between controls. iPad has none. P2.
- **G41 — Multi-effect selection → inspector.** Grid supports
  multi-select; inspector doesn't materialise anything when
  multiple effects are selected. Desktop shows the first effect's
  panel and enables "Apply to all" context actions. iPad model
  decision: "3 effects selected" chrome vs. inspector bulk mode.
  Prerequisite for G11 / G14. P1.

---

## 5. Deferred to other phases

- **G1 — Tab tear-out / multi-window.** Phase F
  (`plans/phase-f-window-system.md`). P2.
- **G15 — Keyboard shortcuts in the inspector.** Rolls in with
  Phase F's app-level menu bar + discoverable shortcuts. P2.

---

## 6. Severity summary (pending only)

| # | Gap | Area | Severity |
|---|---|---|---|
| G3  | Moving Head fixture editor | Effect | P1 |
| G4  | Sketch path editor | Effect | P1 |
| G5  | Morph line editor | Effect | P1 |
| G8  | DMX Remap / Save State / Load State dialogs | Effect | P1 |
| G10 | Per-property Lock + Randomize | Effect | P1 |
| G11 | Bulk Edit (apply to N selected effects) | Effect | P1 |
| G14 | "Update all like this" batch update | Effect | P2 |
| G40 | Drag / drop in inspector | Cross-cutting | P2 |
| G41 | Multi-effect selection in inspector | Cross-cutting | P1 |
| G1  | Tab tear-out / multi-window | Scaffolding | P2 (Phase F) |
| G2-c | Shader uniform grouping for large .fs | Scaffolding | P2 |
| G15 | Keyboard shortcuts in inspector | Effect | P2 (Phase F) |

---

## 7. Suggested phasing

**C4 — Multi-effect operations** *(blocked on grid multi-select)*
- G41: wire grid multi-select into inspector. Upstream work on the
  Metal-backed grid's multi-select is in flight on a separate
  thread (Phase B grid-parity); hold on C4 until that lands so the
  inspector has a reliable selected-effects source to key off.
- G11: "Apply to all selected" per-control.
- G14: "Update all like this" as a consequence of G11.
- G10: Lock + single-control Randomize in the context menu;
  top-level "Randomize effect" button.

**C7 — Specialised editors** *(bigger chunks — one per session)*
- G3: Moving Head.
- G4: Sketch path editor.
- G5: Morph line editor.
- G8: DMX dialog ports.

**Ship order recommendation:** C7 items are independent and can
run in parallel with (or while waiting for) the grid multi-select
that unblocks C4.

---

## 8. Out of scope

- Core renderer parity (already verified on device).
- Rendering performance / JobPool tuning (main plan).
- Sequence-lifecycle / save / sequence-settings UI (Phase E).
- Controller output, iCloud document handling, App Store submission
  (Phases G / H).
- Model / layout editing (separate surface).
- Effect presets — deferred to
  [`future-effect-presets.md`](future-effect-presets.md).
- Pictures frame / GIF timing editor — deferred to
  [`future-pictures-frame-editor.md`](future-pictures-frame-editor.md).
- Palette Shift-left / Shift-right / Reverse — dropped (low value).
- Drag colours between palette slots — deferred to
  [`future-palette-drag.md`](future-palette-drag.md).
- AI palette generation — deferred to
  [`future-ai-palette-generate.md`](future-ai-palette-generate.md).
- AI image generation — deferred to
  [`future-ai-image-generate.md`](future-ai-image-generate.md).
