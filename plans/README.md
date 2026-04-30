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
| [followups.md](followups.md) | Cross-phase | Small items left over from A / C / E / H |

## Residual sub-plans (phase complete)

Kept around for deferral / caveat reference; landed implementation
prose is in git history.

| File | Phase | Why kept |
|---|---|---|
| [phase-d-preview.md](phase-d-preview.md) | D — Model Preview | "View Objects" coarse toggle, Fit Selected silent no-op caveat |
| [phase-f-window-system.md](phase-f-window-system.md) | F — Window system | Stage Manager position quirk, detached-scene preview state deferral |
| [phase-g-document.md](phase-g-document.md) | G — Document / iCloud | `.piz`/`.zip` UTI deferral, save-back from non-Files providers |

## Future / post-MVP

No commitment — captured so we don't lose the design context.

| File | Topic | Blocker |
|---|---|---|
| [future-effect-presets.md](future-effect-presets.md) | Disk-persistent effect presets | In-session ship covers the common path; needs preset-tree UI + bridge |
| [future-pictures-frame-editor.md](future-pictures-frame-editor.md) | Pictures / GIF frame-timing editor | Desktop side needs redesign too |
| [future-ai-palette-generate.md](future-ai-palette-generate.md) | AI palette generation | Needs shared iOS AI bridge |
| [future-ai-image-generate.md](future-ai-image-generate.md) | AI image generation | Same iOS AI bridge dependency |
| [future-layout-editing.md](future-layout-editing.md) | Layout-editor overlays / model manipulation | Largest scope; explicit post-MVP |

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
