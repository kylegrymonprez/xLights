# Phase F — Window System + Display Elements

**Status: complete (2026-04-21).**

All F-1 through F-6 work shipped:

- **F-1** scene-level split with detachable House Preview,
  Model Preview, and keyed inspector tabs (additional
  `WindowGroup`s on the main scene; dismissing a detached
  window restores the docked layout).
- **F-2 / F-3** size-class responsive + docked layout. 12.9"
  landscape shows House + Model previews side by side;
  narrower regular widths still dock both; compact (Slide
  Over) falls back to a picker. Landscape-with-inspector tucks
  the preview band above the grid column only so the
  inspector sidebar runs the full height. Inspector sidebar
  width draggable + `@AppStorage`-persisted (clamped 280…720
  pt and ≤60% viewport, default 340 pt for the four-tab
  segmented picker).
- **F-4** menu bar / `.commands` block — every keyboard
  shortcut button the toolbar used to hide is now reachable
  via the iPadOS 26 menu bar (File / Edit / View / Playback /
  Help).
- **F-5** persistence — main scene declares a 1000×700
  content-size minimum, persisted scene sessions destroyed at
  launch via `UIApplicationDelegateAdaptor`, and detach state
  captured in `@AppStorage` from `.inactive` and `.background`
  scenePhase transitions and replayed on next launch.
- **F-6** Display Elements editor — `DisplayElementsSheet.swift`
  with Master-locked views list, two-pane Available / In-View
  transfer UI for both Master and user views, visibility eye
  toggles, and Master-View remove-with-warning for elements
  with effects. Bridge surface on `XLSequenceDocument`
  covers view CRUD + reorder, models-in-view add/remove/move,
  element roster + visibility, per-timing-track view
  membership, `addTimingToAllViews:` (B82),
  `modelsAvailableInShowLayout`, `addModel(toMasterView:)`,
  `elementHasEffects:`, and `removeElementFromMasterView:`.
  Master-View remove deletes through the same
  `RemoveSelectedModels` MASTER_VIEW path desktop uses,
  guarded by the issue #4134 pre-delete `AbortRender()`.

## Deferred

- **Detached-scene-owned preview state** (per-scene is3D,
  camera, layoutGroup) — not worth the refactor given the F-5
  session-destruction policy. Detached scenes share the main
  window's preview state via the `@Observable` view model.
  Revisit only if users ask for truly independent camera per
  detached pane.

## Caveats

- **Stage Manager position quirk.** Stage Manager caches
  window position outside SwiftUI's reach, so main can
  relaunch in a detached pane's last-active corner —
  self-corrects after one drag-reposition. Known iPadOS
  limitation; not worth further mitigation until iOS 27
  exposes a scene-position API.
