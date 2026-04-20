# Phase D — Model Preview + preview polish

Open items for preview appearance, overlays, and camera polish. Scope
is *preview-viewing*: camera, overlays, background, transport, export.
Layout-editor overlays and model manipulation live in
[`future-layout-editing.md`](future-layout-editing.md); multi-
`LayoutGroup` visibility management lives in Phase F.

**Already landed** (see git history for detail): core render fixes for
2D mode (virtual canvas, `Display2DCenter0`, correct `is_3d` flag to
`DisplayModelOnWindow`); D-3 saved viewpoints; D-4 2D/3D toggle; D-7
read-only background image; D-10 preview image export; D-11
rewind/FF transport; D-13 "View Objects" toggle (one switch for
background + view objects + any future layout-editor overlays);
D-14 alternate LayoutGroup previews; D-12 pixel-size and D-15 FPS
counter were *dropped* for parity (no desktop counterpart).

Cross-phase reminders: layout editing stays desktop-only; multi-
`LayoutGroup` editing and per-view visibility management are Phase F
(Window System + Display Elements); save/open/new file plumbing that
several items here reference is Phase E (Sequence Management).

## D-5. Model placement on House Preview (2D/3D)

Desktop stores model placement for the house preview as part of each
`Model`'s `ModelScreenLocation` in `xlights_rgbeffects.xml` — verified
in place. Confirm during implementation:

- 3D placement attributes round-trip through `ModelManager::LoadModels`
  (they already do on iPad load; verify Save still writes them once we
  start editing).
- If any 2D/3D placement state is stored only in a desktop-side
  preference (e.g. layout-panel toolbar state) rather than `rgbeffects`,
  move it into `rgbeffects` so iPad sees the same state. Default
  assumption is that everything needed is already in `rgbeffects` and
  no schema change is required.

This is a verification task — triggered when Phase E sequence-editing
lands and we start writing rgbeffects back out.

## D-6. Zoom / fit / center shortcuts

Per-pane controls overlay already exposes +, -, 1x, and Reset View
(mapped to `setCameraZoom` / `resetCamera`). Still to add:

- **Fit All Models** — fit the full house bounding box to the preview.
- **Fit Selected Model** — fit the currently-selected model (or its
  bounding box) to the preview.

Both map to existing `PreviewCamera` operations; the camera math
differs between 2D (ortho half-width scaling) and 3D (distance +
angles) so each mode needs its own fit routine. No new shader work.

---

## Explicitly out of scope for Phase D

Captured here so future audits don't re-flag them:

- **Model-name / info / first-pixel overlays** — diagnostic overlays
  used while arranging a layout, not during playback preview. Parked
  in [`future-layout-editing.md`](future-layout-editing.md) (L-1).
- **2D grid / bounding-box overlays** (`Display2DGrid`,
  `Display2DGridSpacing`, `Display2DBoundingBox`) — measurement aids
  for laying out models, not playback. Parked in
  [`future-layout-editing.md`](future-layout-editing.md) (L-2).
  `Display2DCenter0` itself is already consumed by the 2D view matrix
  — it is part of the world-coord system, not a layout-editor overlay.
- **Model selection, drag-to-move, resize handles, polyline vertex
  editing, property grid, align/distribute, flip, resize-to-match,
  CAD/DXF export, wiring view, bulk edit** — all part of the desktop
  Layout editor, parked in
  [`future-layout-editing.md`](future-layout-editing.md).
- **Per-model show/hide + Views management** — that's the Display
  Elements dialog in Phase F-6. D-13 only adds a single coarse view-
  objects toggle as a stop-gap.
- **Detach previews to external display / separate window** — Phase
  F-1 (scene-level window system).
- **3D Connexion / space-mouse input** — desktop-only peripheral.
- **Keyboard shortcut camera nudging** — iPad input is touch-first;
  gesture equivalents already cover these.
- **Pixel-size slider** and **FPS counter** — no desktop counterpart,
  dropped for parity (see git history for full reasoning).
