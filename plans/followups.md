# Cross-phase follow-ups

Small items left over from phases that otherwise landed. No new
phase home; catalogued here so they don't fall off.

## Phase A — Core-path hardening

- **Re-prompt on failed `ObtainAccessToURL`.** Desktop re-prompts
  the user with `UIDocumentPickerViewController` when a stale
  security-scoped bookmark fails to resolve; iPad currently
  ignores the return value, so a stale bookmark leads to silent
  lookup failure. Minimum version: check the return, log, and
  drop the failed folder from `_mediaFolders` before handing it
  to `FileUtils`. Full re-prompt UX needs a Swift callback +
  `UIDocumentPickerViewController` hook.

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

- **G8+ — Persist iPad-saved DMX states to
  `xlights_rgbeffects.xml`.** `dmxSaveState` writes to the
  model's in-memory `stateInfo` map; the save doesn't survive
  show-folder close. Follow-up: mirror the `SaveViewpoints`
  pattern in `iPadRenderContext` (reload XML, rewrite the
  model's `<stateInfo>` children from `Model::WriteStateInfo`,
  save). Needs per-model writable access + a "models that
  changed state" tracker. P2.

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
