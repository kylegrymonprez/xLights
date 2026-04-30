# iPad xLights — Plan Index

Work to ship the iPad app is tracked across focused sub-plans here. The
top-level [`iPad-xLights-Plan.md`](../iPad-xLights-Plan.md) (one
directory up) keeps the overall situation (current state, phase
summary, MVP-remaining list, risks, open questions) and links here
for the details.

## Active sub-plans

| File | Phase | What's left |
|---|---|---|
| [phase-h-app-store.md](phase-h-app-store.md) | H — App Store readiness | H-5: screenshots, App Store Connect metadata, submission |
| [phase-i-import-effects.md](phase-i-import-effects.md) | I — Import Effects | I-3 vendor-sequence regression + Auto Map UX polish, I-4 (`.sup`), I-5 (`.lms`/`.las`) |
| [phase-b-grid-parity.md](phase-b-grid-parity.md) | B — Effects grid parity | 2 P2 named (B77 MIDI, B79 AI Speech 2 Lyrics) + 3 deferred |
| [followups.md](followups.md) | Cross-phase | Small items left over from A / C / E / H plus a "TestFlight quality" bundle (log export, About, Help menu, crash telemetry, Check Sequence, …) |

## Residual sub-plans (phase complete)

Kept around for deferral / caveat reference; landed implementation
prose is in git history.

| File | Phase | Why kept |
|---|---|---|
| [phase-d-preview.md](phase-d-preview.md) | D — Model Preview | "View Objects" coarse toggle, Fit Selected silent no-op caveat |
| [phase-f-window-system.md](phase-f-window-system.md) | F — Window system | Stage Manager position quirk, detached-scene preview state deferral |
| [phase-g-document.md](phase-g-document.md) | G — Document / iCloud | `.piz`/`.zip` UTI deferral, save-back from non-Files providers |

## Future / post-MVP

No commitment — captured so we don't lose the design context. Most
items here trace back to the 2026-04-23 gap analysis.

| File | Topic | Severity / scale |
|---|---|---|
| [future-controllers-tab.md](future-controllers-tab.md) | Controllers tab — discovery, list, edit, upload (Phase R / R-pro) | P1 / XL+ — biggest single near-feature gap |
| [future-audio-authoring.md](future-audio-authoring.md) | Onset / tempo → timing tracks, spectrogram, pitch contour (Phase J) | P1 / M each |
| [future-aux-panels.md](future-aux-panels.md) | Search / Find / EffectTree / Jukebox / SequenceVideo / bulk-edit (Phase L) | P1 (Search, EffectTree) / others P2 |
| [future-preferences.md](future-preferences.md) | Preferences (10 panels, 96 options) + ColorManager + backup (Phase M) | P2 / L overall |
| [future-help-diagnostics.md](future-help-diagnostics.md) | Tip-of-Day, in-app log viewer, Package Show, RestoreBackup (Phase P) | P2 / M |
| [future-imports-exports.md](future-imports-exports.md) | Vixen 3, Papagayo, Audacity, MIDI, etc. + 14-format export + Convert dialog (Phase N) | P2 / L |
| [future-effect-presets.md](future-effect-presets.md) | Disk-persistent effect presets (G12) + EffectTree pairing | P1 / M |
| [future-pictures-frame-editor.md](future-pictures-frame-editor.md) | Pictures / GIF frame-timing editor + Effect Assist panels (EA-1..3) | P2 / XL each |
| [future-ai-palette-generate.md](future-ai-palette-generate.md) | AI palette generation (AI-1) | P2 / S |
| [future-ai-image-generate.md](future-ai-image-generate.md) | AI image generation (AI-2..AI-5) | P2 / M each |
| [future-layout-editing.md](future-layout-editing.md) | Layout panel — model placement, world layout (Phase S / S-pro) | P2 / XXL — multi-year |
| [future-custom-models.md](future-custom-models.md) | Custom model + Face/State + DMX deep + Wiring (Phases T/U/V/W) | P2 / XXL |

## Hard misses (no realistic iOS path)

Documented for the record so we don't keep re-litigating:

- **VAMP plugin host** (polyphonic transcription, custom user
  plugins). No iOS replacement. CoreML-based feature extraction is
  XXL and doesn't preserve plugin extensibility.
- **Python scripting** (pybind11 + Python 3 embedding). App Store
  hostile.
- **Lua scripting via JIT.** Same App Store concern; could ship
  interpreted but workflow value is low.
- **3D Connexion / SpaceMouse input.** Desktop peripheral.
- **FFmpeg whole library.** Bundling adds ~50 MB + licensing /
  review risk; AVFoundation-only is the policy.
- **Custom KeyBindings editor.** Touch-first iPad uses gestures +
  menu items.
- **AUI Manager perspectives.** Single-window iPad layout doesn't
  benefit.

---

## Ground rules for sub-plans

1. Only track **pending** work. Finished items are git history, not
   plan noise.
2. Each bullet should be concrete enough to scope against without
   re-reading the codebase.
3. Keep files focused. If a sub-plan grows past ~600 lines it
   probably needs to be split.
4. When a phase completes, the sub-plan shrinks to a residual file
   covering deferrals + caveats only — or is deleted entirely if
   nothing future-relevant remains.
5. The `future-*.md` files are not commitments. Severities and
   effort estimates are recommendations from the gap analysis;
   the team decides what ships.
