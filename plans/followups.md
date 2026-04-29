# Cross-phase follow-ups

Small items left over from phases that otherwise landed. No new
phase home; catalogued here so they don't fall off.

## Phase A — Core-path hardening

- ~~**Re-prompt on failed `ObtainAccessToURL`.**~~ Minimum version
  landed 2026-04-28 (`iPadRenderContext::LoadShowFolder`): the
  show-folder access failure is logged, and any media folder that
  fails `ObtainAccessToURL` is dropped from `_mediaFolders` before
  it reaches `FileUtils::SetFixFileDirectories`. Defensive logging
  also added to `OpenSequence` and `SaveViewpoints`. Full re-prompt
  UX (Swift callback into `UIDocumentPickerViewController`) is still
  open — the current change just stops the silent-fail path that
  led to phantom missing-media warnings.

## Phase E — Sequence management polish

Phase E closed 2026-04-21. Deferred items:

- **Batch Render tool.** ✓ landed 2026-04-28. Toolbar entry on
  `SequencePickerView` opens a sheet that walks the show folder
  recursively (skipping `Backup/` and dot-folders) and lets the
  user check sequences to re-render. Selections persist per show
  folder in the `xLights-BatchRender` UserDefaults suite.
  `BatchRenderRunner` drives a serial open → render →
  `writeFseq` → close loop directly against the bridge so the
  picker stays on screen between iterations. Cancel + progress
  ("Rendering N of M") supported. Bypasses the FSEQ load
  short-circuit via a new `forceRender` flag on
  `SequencerViewModel.openSequence`. Picker UI now also surfaces
  sequences in subfolders with the parent path shown as a caption,
  so users with one-folder-per-sequence layouts can open from the
  list directly.

- **`.fseq` emission alongside save.** ✓ landed 2026-04-27.
  `FolderConfig` got a "Save FSEQ on save" toggle + optional
  fseq-folder picker; `iPadRenderContext::WriteFseq` produces a
  v2/zstd/sparse fseq matching desktop's
  `xLightsFrame::WriteFalconPiFile` (master-view sparse ranges,
  `mf` / `sp` / FE / FC variable headers). On open,
  `iPadRenderContext::TryLoadFseq` short-circuits the render
  when a non-stale fseq exists with matching shape. Path rule
  mirrors desktop: blank fseq folder → next to the .xsq;
  configured fseq folder → flatten into that folder. Opens the
  door to FPP Connect / Batch Render integrations once those
  land on iPad.

- ~~**Sequence Settings → Timings import/export tab.**~~ Landed
  2026-04-28. New "Timings" tab in `SequenceSettingsSheet` lists
  every timing element (layer 0 only) with per-track Rename /
  Export… / Delete actions. Top "Import…" section accepts
  `.xtiming` / `.lms` / `.pgo`. Bridge gained
  `importLorTimingFromPath:` and `importPapagayoTimingFromPath:`
  alongside the existing `.xtiming` import; both wrap
  `SequenceFile::ProcessLorTiming` /
  `SequenceFile::ProcessPapagayo` and follow the same
  "make-newest-active + repopulate row info" post-import dance.
  Per-track export rides a value-type `XTimingFile: FileDocument`
  that captures bytes at construction time on the main actor so
  `fileWrapper(_:)` stays actor-free.

- **Sequence Settings → Audio Tracks tab.** Alt-audio tracks
  round-trip through XML untouched today; no authoring UI.
  Sheet with add / remove / rename / file-pick; routes picked
  files through `MediaRelocation`. P2.

- **Sequence Settings → Data Layers tab.** Image-data layers
  authoring. Lowest priority — deferred until someone
  actually uses them on iPad.

## Phase C — Effect Settings Inspector polish

Phase C closed 2026-04-21. Small deferred items:

- **G3+ — Moving Head colour / dimmer / path authoring.** iPad
  v1 supports fixture selection + Pan / Tilt / Offsets /
  Groupings / Cycles. Colour wheel picker, dimmer canvas, and
  path (Sketch-style waypoint) authoring still require the
  desktop Effect Assist. A future pass would add: a `ColorPicker`
  sheet that writes `Color:` into active `MH*_Settings`; a
  simple dimmer intensity row; a reuse of `SketchPathEditor` on
  `MHPathDef`. P2.

- ~~**G8+ — Persist iPad-saved DMX states to
  `xlights_rgbeffects.xml`.**~~ Landed 2026-04-28.
  `iPadRenderContext::SaveModelStates` mirrors `SaveViewpoints`:
  walks `_dirtyStateModels`, locates each `<model name="…">` in
  the on-disk rgbeffects XML, drops existing `<stateInfo>`
  children, rewrites them via `Model::WriteStateInfo`, and saves.
  `MarkModelStateDirty` is the public hook; `dmxSaveStateForRow`
  in `XLSequenceDocument.mm` calls it then immediately invokes
  `SaveModelStates` so each user-saved state survives show-folder
  close.

- **G2-c — Shader dynamic uniform grouping for large `.fs`
  files.** Most shaders declare < 10 uniforms so grouping isn't
  needed; packs with 20+ turn into a flat scroll. Respect
  `GLSL_GROUP:` comment conventions in
  `ShaderConfig::GetDynamicPropertiesJson()` so grouping carries
  across. Deferred until a real shader pack trips the issue. P2.

- **Video compat badge in the media manager.** Incompatible
  videos show as "External" today; badging them requires caching
  the `CheckVideoFile` probe per entry so the inventory refresh
  doesn't re-open every video. Low priority.
