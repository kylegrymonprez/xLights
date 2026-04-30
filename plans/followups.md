# Cross-phase follow-ups

Small items left over from phases that otherwise landed. No new
phase home; catalogued here so they don't fall off.

## Phase A — Core-path hardening

- **Re-prompt on failed `ObtainAccessToURL`.** Minimum-version
  defensive logging is in place (`iPadRenderContext::LoadShowFolder`
  drops media folders that fail `ObtainAccessToURL`; `OpenSequence`
  and `SaveViewpoints` log too). Still missing: full re-prompt UX
  that surfaces a `UIDocumentPickerViewController` so the user can
  re-grant access when a bookmark goes stale, instead of just seeing
  empty models / missing-media warnings.

## Phase E — Sequence management polish

- **Sequence Settings → Data Layers tab.** Image-data layers
  authoring. Lowest priority — deferred until someone actually
  uses them on iPad.

## Phase C — Effect Settings Inspector polish

- **G3+ — Moving Head full waypoint path authoring.** Path tab
  currently shows the existing `Path:` value with a Clear action.
  Sketch-style drag waypoint authoring still requires desktop's
  Effect Assist panel.

- **G2-c — Shader dynamic uniform grouping for large `.fs`
  files.** Most shaders declare < 10 uniforms so grouping isn't
  needed; packs with 20+ turn into a flat scroll. Respect
  `GLSL_GROUP:` comment conventions in
  `ShaderConfig::GetDynamicPropertiesJson()` so grouping carries
  across. Deferred until a real shader pack trips the issue. P2.

- **Video compat badge in the media manager.** Per-effect block
  already calls `videoCompatibilityIssueForPath:`; the sequence-wide
  Media Manager inventory list still labels incompatible videos as
  plain "External". Badging them requires caching the
  `CheckVideoFile` probe per entry so the inventory refresh doesn't
  re-open every video. Low priority.

## Phase H — App Store

- **sACN multicast entitlement.** `com.apple.developer.networking.multicast`
  request submitted to Apple 2026-04-28. Once approved, add the key
  to `macOS/Assets/xLights-iPad/xLights-iPad.entitlements` so iPad
  testers can join `239.255.x.x` for sACN multicast output. Until
  then the toggle's "couldn't reach" alert text steers users to
  ArtNet, DDP, or sACN unicast.
