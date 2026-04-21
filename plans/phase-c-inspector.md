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

1. **Specialised editors** (C7) — Moving Head (G3), DMX dialog
   ports (G8). Each is its own session. Sketch (G4) and Morph (G5)
   shipped 2026-04-21.
2. **Polish items** — drag / drop in inspector, shader uniform
   grouping.

C4 (multi-effect operations) shipped 2026-04-21 — grid multi-select
now carries into the inspector with "N effects selected" header
chrome, a per-property "Apply to N Other Selected" context menu
entry, and an "Update All" header button that flushes every anchor
value to the set. E_ keys are filtered per target so effect-specific
props don't leak across types. G10 (Lock + Randomize) dropped per
user feedback.

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
- **G4 — Sketch path editor.** ✓ shipped 2026-04-21.
  `SketchPathEditorRowView` with per-endpoint + Bezier-control
  drag, Add-Line tap mode, New Path, Undo Point, Clear. Advanced
  authoring (cubic/quadratic creation, closing paths, SVG import)
  stays desktop-only; the round-trip through `SketchDefinition`
  preserves Q/C/c segments untouched.
- **G5 — Morph line editor.** ✓ shipped 2026-04-21.
  `MorphLineEditorRowView` renders the start + end lines on a
  100×100 grid; drag any endpoint to reposition, linked pairs pin
  their slave to the master.
- **G8 — DMX Remap / Save State / Load State buttons.** Rendered
  disabled today. Depends on model-state read / write bridge paths
  not yet on iPad. P1.

### Per-property & effect-level actions

All C4 items shipped (2026-04-21) — see TL;DR. G10 (Lock +
Randomize) is out per user feedback: the randomize UX wasn't a
fit for iPad, and the lock UI alone would be orphan without it.

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
| G8  | DMX Remap / Save State / Load State dialogs | Effect | P1 |
| G40 | Drag / drop in inspector | Cross-cutting | P2 |
| G1  | Tab tear-out / multi-window | Scaffolding | P2 (Phase F) |
| G2-c | Shader uniform grouping for large .fs | Scaffolding | P2 |
| G15 | Keyboard shortcuts in inspector | Effect | P2 (Phase F) |

---

## 7. Suggested phasing

**C7 — Specialised editors** *(bigger chunks — one per session)*
- G3: Moving Head. (open)
- G4: ✓ Sketch path editor (2026-04-21).
- G5: ✓ Morph line editor (2026-04-21).
- G8: DMX dialog ports. (open — blocked on model-state bridge)

Remaining editors (G3, G8) are independent.

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
