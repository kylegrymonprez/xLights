# Phase D — Model Preview + preview polish

Both previews render and have gestures on device (Model Preview +
House Preview, pinch / pan / orbit / rotate / double-tap reset; saved
cameras from `xlights_rgbeffects.xml` are loaded on show open). This
file tracks the gap between what desktop `ModelPreview` /
`HousePreviewPanel` expose and what the iPad has today. Anything here
is *preview-scope*: appearance, camera, overlays, transport. Layout
editing (drag-to-move, align/distribute, resize handles, polyline
editing, property grid) stays desktop-only per the top-level plan.
Multi-`LayoutGroup` / per-view visibility is Phase F.

Sections below are ordered roughly "highest user impact first". Each
item names the desktop source it's replicating so implementation can
crib the behaviour rather than redesign it.

Cross-phase reminders: layout editing stays desktop-only per the top-
level plan; multi-`LayoutGroup` and per-view visibility management are
Phase F (Window System + Display Elements); save/open/new file
plumbing that several items here reference is Phase E (Sequence
Management).

## D-3. Saved camera views — UI surface

`xlights_rgbeffects.xml` already stores named cameras via `<Viewpoints>`
/ `ViewpointMgr::Load()`. Plumbing the load side through
`iPadRenderContext` is the remaining glue; read/apply in the menu is
straightforward once the bridge exists.

- Bridge `ViewpointMgr` through `iPadRenderContext`. Today the desktop
  `TabSequence` owns viewpoint load/save; iPad's `LoadShowFolder`
  currently skips the `<Viewpoints>` node.
- Long-press on a preview opens a menu listing the named cameras,
  filtered by the current 2D/3D mode of that preview.
- Tap a name → applies the `PreviewCamera` via `operator=`.
- "Save current view as…" entry at the bottom of the menu captures the
  live camera state into `ViewpointMgr::AddCamera`.
- "Restore Default ViewPoint" entry mirrors the desktop context-menu
  item (`ModelPreview.cpp` right-click handler).
- Save path: `ViewpointMgr::Save` is already plumbed desktop-side; iPad
  needs to trigger a rewrite of `xlights_rgbeffects.xml` on changes.

## D-4. 2D vs 3D toggle

Per-preview toolbar / segmented control that switches the
`PreviewCamera` between `is_3d = true/false`. Distinct from
"current mode comes from the selected saved view" — the toggle is a
preview-local override. Persist at the scene level during Phase F.

Bridge methods (`setIs3D:` / `is3D`) are already in place; this is
purely a SwiftUI control next to the existing overlay buttons in
`HousePreviewView.swift`.

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

## D-6. Zoom / fit / center shortcuts

Per-pane controls overlay already exposes +, -, 1x, and Reset View
(mapped to `setCameraZoom` / `resetCamera`). Still to add:

- **Fit All Models** — fit the full house bounding box to the preview.
- **Fit Selected Model** — fit the currently-selected model (or its
  bounding box) to the preview.

Both map to existing `PreviewCamera` operations; this is a UI addition
with no new math.

## D-7. Background image + brightness / alpha

Desktop `ModelPreview` draws an optional background image with
brightness (0–100) and alpha (0–100) controls, plus a "scale to fit"
toggle. Settings are stored per-`LayoutGroup` in
`xlights_rgbeffects.xml` (`GetBackgroundImage`, `GetBackgroundBrightness`,
`GetBackgroundAlpha`). The default House Preview reads
`xLightsFrame::GetDefaultPreviewBackground*` (global defaults).

Today iPad ignores the node entirely — background is always solid
black and there is no control to change it.

- Plumb `mBackgroundImage` / `mBackgroundBrightness` / `mBackgroundAlpha`
  / `mScaleBackgroundImage` through `iPadModelPreview` (the desktop
  draw code at `ModelPreview.cpp:1411+` is reusable — it already uses
  `xlGraphicsContext::createTexture` and a brightness shader).
- Read the global defaults on load (`SetBackgroundBrightness` /
  `SetbackgroundImage` in the same file).
- Surface a "Background…" entry in the preview long-press menu (D-3):
  pick image, brightness slider, alpha slider, "scale to fit" toggle.
- Writes round-trip back to `xlights_rgbeffects.xml` via the same
  `<LayoutGroup>` attributes desktop writes to.

## D-8. 2D overlays — grid and bounding box

Desktop exposes three 2D-only overlays via `SetDisplay2DGrid`,
`SetDisplay2DCenter0`, `SetDisplay2DBoundingBox` (ModelPreview.h:147–151).
Settings live in `xlights_rgbeffects.xml` (`Display2DGrid`,
`Display2DGridSpacing`, `Display2DCenter0`, `Display2DBoundingBox`).

- Grid overlay at configurable spacing (default 100 units), origin
  either at centre or top-left.
- Bounding-box overlay showing the union of all visible models.
- Both draw in `ModelPreview::RenderModels` via the grid-line
  accumulator; iPad can reuse the same accumulator path once 2D mode
  (D-4) lands.
- Settings menu: checkbox entries in the preview long-press menu
  (D-3). Values persist to `rgbeffects`.

## D-9. Model-name and model-info overlays

`SetShowModelNames` / `SetShowModelInfo` toggle per-model text labels
over each model in the preview (drawn by the text block at
`ModelPreview.cpp:813`). Model name = the model's display name; model
info = start channel / end channel summary. First-pixel highlight
(`_showFirstPixel`) draws a coloured marker at node 0 of each model.

Today iPad has no text overlay and no first-pixel marker.

- Three independent toggles in the preview long-press menu.
- Re-use the desktop `fontInfo`/`xlFontInfo` text block — already
  wx-free. Text rendering on iPad goes through
  `CoreGraphicsTextDrawingContext` (already in `src-iPad/Bridge/`).
- Labels should scale sensibly for touch; desktop picks a font size
  based on camera zoom — same logic should port.

## D-10. Preview image export

Desktop exposes `PreviewSaveImage()` (PNG dump of the current preview
framebuffer) and `PreviewPrintImage()` via the Layout panel and the
preview context menu. Useful for sharing house layouts offline and
for bug reports.

- iPad: add "Save Image…" to the preview long-press menu. Capture the
  current `CAMetalLayer` drawable to a `UIImage`, then present a
  `UIActivityViewController` (Files / Photos / Mail / AirDrop). No
  print equivalent — iPadOS handles Print via the share sheet once the
  image is in hand.
- Include a "Copy Image" variant that goes straight to the pasteboard.

## D-11. House Preview transport — parity with desktop

Desktop's `HousePreviewPanel` embeds a transport strip directly under
the preview: Play, Pause, Stop, Rewind-to-start, Rewind 10s, FF 10s,
plus a scrubber slider and frame/time readout. The iPad today has
Play/Pause/Stop in the sequencer toolbar — no rewind-10 / FF-10 / no
scrubber attached to the preview, and the time readout is in the main
toolbar instead of under the preview.

- Decide placement: either add a transport strip beneath each preview
  pane (closer to desktop parity) or extend the existing toolbar
  strip with Rewind10 / FForward10 and verify the `playPositionMS`
  slider (if we add one) scrubs the render correctly.
- Rewind10 / FF10 on desktop post `EVT_SEQUENCE_REWIND10` /
  `EVT_SEQUENCE_FFORWARD10`; the iPad equivalent is a direct
  `seekTo(ms:)` on `SequencerViewModel` offset by ±10000 ms.
- Scrubber must not fight the playback loop — drag-to-scrub should
  pause, scrub, then resume on release (matches desktop behaviour).

## D-12. Pixel / point-size control

Desktop reads point size from preferences
(`xLightsFrame::GetModelHandleSize` / per-preview "pixel size" menu)
so the user can make pixels more visible on large displays or print
screenshots. iPad is hard-coded to 2.0 in `XLMetalBridge.mm:22`.

- Expose a slider (or +/- buttons) in the preview long-press menu.
- Persist per-preview in `SceneStorage` (alongside the 2D/3D override
  from Phase F-5).

## D-13. View-object visibility (quick toggle)

Desktop's `ViewsModelsPanel` has full per-view-object show/hide (house
mesh, terrain, ruler, gridlines, image/mesh objects). Full Display
Elements parity is Phase F-6, but a coarse "show view objects /
hide view objects" toggle is useful before then — it's the difference
between showing the house/mesh backdrop and showing pixels only.

- Single toggle in the preview long-press menu: "Show View Objects".
- Maps to a bool on `iPadModelPreview`; the House Preview draw loop
  already iterates `ctx->GetAllObjects()` (`XLMetalBridge.mm:213`) and
  can short-circuit when the flag is off.
- Per-object show/hide remains Phase F territory.

## D-14. Alternate LayoutGroup previews (stretch — overlaps with Phase F)

Desktop lets users define additional named `<LayoutGroup>` entries
beyond the default House Preview (`LayoutGroup.cpp` — each carries its
own background image, brightness, alpha, and model visibility). The
desktop preview right-click menu lists them and lets the user switch.

Creating/editing layout groups is desktop-scope (layout editor). But
*viewing* an existing show's extra layout groups should work on iPad.

- `iPadRenderContext` needs to load the `<LayoutGroup>` nodes from
  `rgbeffects` (currently only the default House is loaded).
- The preview long-press menu (D-3) lists available layout groups; tap
  switches the pane's backing group.
- The actual window/routing — which preview pane shows which layout
  group — is Phase F.

## D-15. FPS / render-time overlay (optional)

Desktop has an optional FPS counter drawn in the corner of the preview
(useful while diagnosing effect performance). Low priority but cheap
to add and extremely useful for field-debugging iPad performance on
real shows.

- Toggle in the preview long-press menu. Draws over the title label in
  `HousePreviewView.swift`.

---

## Explicitly out of scope for Phase D

Captured here so future audits don't re-flag them:

- **Model selection / drag-to-move / resize handles / polyline vertex
  editing / property grid** — all part of the desktop Layout editor,
  which stays desktop-only per the top-level plan.
- **Align / distribute / flip / resize-to-match / CAD/DXF export /
  wiring view / bulk edit** — same, all Layout-editor concerns.
- **Per-model show/hide + Views management** — that's the Display
  Elements dialog in Phase F-6. D-13 only adds a single coarse view-
  objects toggle as a stop-gap.
- **Detach previews to external display / separate window** — Phase
  F-1 (scene-level window system).
- **3D Connexion / space-mouse input** — desktop-only peripheral.
- **Keyboard shortcut camera nudging** — iPad input is touch-first;
  gesture equivalents already cover these.
