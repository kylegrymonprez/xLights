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

## TestFlight quality (pre-submission)

These are not engineering blockers but are the "any TestFlight
report will need this" items the gap analysis (2026-04-23) flagged.
Each is a near-trivial addition that materially improves the
tester loop. Pull into MVP if there's bandwidth before H-5 wraps.

- **Log export** (gap-analysis H-3, **P0 for TestFlight**). Zip
  the spdlog rotate-files + show folder + currently-open `.xsq`
  and present via `UIActivityViewController`. Without it, "weird
  thing happened" reports come back with nothing actionable.
- **About dialog** (H-1). Version + build + EULA + dependency
  credits. Reachable from the menu bar Help / About entry.
- **Help menu populated** (H-2). Online docs / forum / tutorial
  videos / issue tracker / donate. Just URLs opening in
  `SFSafariViewController`.
- **Crash telemetry** (H-4). MetricKit (no SDK churn, no privacy-
  manifest changes) is the simpler choice over Sentry; pick before
  wiring. Surfaces on-device crashes without waiting for a tester
  to forward a `.crash`.
- **Check Sequence runner** (T-1, P1). Validation report —
  duplicate universes, non-contiguous channels, missing media,
  broken model refs, etc. Engine logic already exists in
  `src-core/sequencer/SequenceCheck` (or similar); just needs an
  iPad UI sheet to surface it.
- **Incompatible video warning at sequence load** (A-8, P1).
  Per-effect probe `videoCompatibilityIssueForPath:` already
  exists; sequence-load pass needs to walk every VideoEffect and
  surface a one-shot summary so the tester knows up front instead
  of getting silent black frames mid-playback.
- **Recent Show Folders list** (L-1b). Recent Sequences is
  scoped per show folder (2026-04-30 refactor — flipping shows
  swaps the picker's recent list cleanly), but the folder-config
  sheet itself only remembers the *current* show folder. Add a
  "Recent Show Folders" section so users can flip between shows
  without re-picking from Files every time.
