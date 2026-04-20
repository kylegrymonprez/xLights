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

## D-4. 2D vs 3D toggle — ✓ done (2026-04-20)

Segmented 2D/3D control on House Preview only (desktop Model Preview
is 2D-only). Toggles `settings.is3D`; `PreviewPaneView.updateUIView`
syncs it to `XLMetalBridge.setIs3D:` and re-renders. Scene-level
persistence still TODO (Phase F).

House Preview 2D mode also required `iPadRenderContext` to read
`<settings><previewWidth/Height>` and `<Display2DCenter0>` from
`xlights_rgbeffects.xml` and hand them to `iPadModelPreview`
(`SetVirtualCanvasSize` / `SetCenter2D0`) via
`XLMetalBridge.drawModelsForDocument:`. Without the virtual canvas,
the 2D ortho view matrix never scaled world coords onto pixel coords;
without `_center2D0`, centre-origin shows (models laid out around
X=0) rendered shifted left and most models off-screen. Model loading
also now uses the saved preview size rather than a hardcoded
1920×1080.

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

## D-7. Background image — ✓ done (2026-04-20)

Read-only display of the show's background image in the House Preview
2D mode. Editing (brightness / alpha / scale / pick-a-file) remains
desktop-only per the top-level scope — iPad just honours what the
show has already stored.

- `iPadRenderContext` now parses `backgroundImage`,
  `backgroundBrightness`, `backgroundAlpha`, and `scaleImage` from the
  rgbeffects `<settings>` node, FixFile-resolves the path against the
  show directory, and exposes `GetBackgroundImage` /
  `GetBackgroundBrightness` / `GetBackgroundAlpha` /
  `GetScaleBackgroundImage`.
- `XLMetalBridge` lazy-loads the image via `CGImageSource` into an
  `xlImage`, creates an `xlTexture` cached on the bridge (re-loaded
  only when the path changes), and enqueues the draw into
  `solidProgram` before model rendering. Draw math mirrors
  `ModelPreview.cpp:1431` — aspect-preserving fit inside the virtual
  preview rectangle when `scaleImage` is off, with the same
  `-virtualW/2` shift when `Display2DCenter0` is on.
- 3D House Preview intentionally does not draw the background, same as
  desktop.

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

## D-10. Preview image export — ✓ done (2026-04-20)

Share-sheet button in `PreviewControlsOverlay` posts
`.previewSaveImage`; the Coordinator snapshots its `MTKView` with
`drawHierarchy(in:afterScreenUpdates:)` and presents a
`UIActivityViewController` from the topmost presented view controller.
Share-sheet covers Files / Photos / Mail / AirDrop / Copy / Print out
of the box, so no separate copy or print entry was needed.

## D-11. House Preview transport — ✓ done (2026-04-20)

Toolbar now has Rewind-to-start / Rewind 10s / Stop / Play-Pause /
FF 10s, mirroring desktop's `HousePreviewPanel`. Scrubber coverage is
provided by the existing sequencer-ruler playhead drag in
`SequencerGridV2View`, which already drives `viewModel.seekTo(ms:)`.
Placement chose "main toolbar" rather than "strip beneath each
preview" — keeps the two preview panes uncluttered and avoids
duplicating the transport strip per pane.

## D-12. Pixel / point-size control — dropped

Removed on 2026-04-20. Desktop has no equivalent user-facing slider,
and the iPad stepper did not produce any user-visible change because
the MSL point-size path is effectively clamped at the shader level.
Keeping the hardcoded 2.0 in `PreviewPaneView.draw(in:)` matches
desktop behaviour and avoids a support-ticket vector ("my iPad shows
different pixel sizes than desktop"). Not reinstating without a
confirmed desktop counterpart.

## D-13. View-object visibility (quick toggle) — ✓ done (2026-04-20)

"View Objs" toggle button in `PreviewControlsOverlay` drives
`settings.showViewObjects`; bridged through
`XLMetalBridge.setShowViewObjects:` / `showViewObjects`. Now gates
**every** non-pixel scene element rather than only the view-object
loop, so users get one switch for the whole "visual backdrop":
- house-mesh / terrain / gridlines / ground images (ViewObjects)
- background image (D-7)
- D-8 overlays (grid, bounding box) — must hook into the same flag
  when they land.

Per-object show/hide stays Phase F-6.

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

## D-15. FPS / render-time overlay — dropped

Removed on 2026-04-20. Desktop FPS counter is a diagnostic tool; on
iPad it caused support-ticket confusion (users comparing iPad vs
desktop numbers that don't mean the same thing). Not shipping.

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
