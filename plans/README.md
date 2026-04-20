# iPad xLights — Plan Index

Work to ship the iPad app is tracked across focused sub-plans here. The
top-level `iPad-xLights-Plan.md` (one directory up) keeps the "what is the
overall situation" material (current state, phase summary, risks, open
questions) and links here for the details.

| File | Phase | Status |
|---|---|---|
| [phase-b-grid-parity.md](phase-b-grid-parity.md) | B — Effects grid parity with desktop | In progress — ~100 items pending; multi-select in flight on a separate thread |
| [phase-c-inspector.md](phase-c-inspector.md) | C — Effect settings inspector | In progress — C4 (multi-effect) blocked on grid multi-select; C7 (specialised editors) still open |
| [phase-d-preview.md](phase-d-preview.md) | D — Model Preview + preview polish | ✓ complete |
| [phase-e-sequence-management.md](phase-e-sequence-management.md) | E — Sequence management (open / save / new / settings) | Partial — save / dirty / close-with-prompt and missing-media detection landed; New wizard, Sequence Settings dialog, recent documents, autosave outstanding |
| [phase-f-window-system.md](phase-f-window-system.md) | F — Window system + Display Elements | Not started |
| [phase-g-document.md](phase-g-document.md) | G — Document / iCloud polish | Not started |
| [phase-h-app-store.md](phase-h-app-store.md) | H — App Store readiness | Not started |
| [followups.md](followups.md) | Cross-phase small items | In progress |
| [future-effect-presets.md](future-effect-presets.md) | Deferred — G12 effect presets | Not first-pass |
| [future-pictures-frame-editor.md](future-pictures-frame-editor.md) | Deferred — G6 Pictures / GIF frame-timing editor | Desktop needs redesign too |
| [future-ai-palette-generate.md](future-ai-palette-generate.md) | Deferred — AI palette generation | Needs iOS AI bridge first |
| [future-ai-image-generate.md](future-ai-image-generate.md) | Deferred — G33 AI image generation | Shares AI bridge with palette-generate |
| [future-palette-drag.md](future-palette-drag.md) | Deferred — G18 drag colours between palette slots | Low impact |
| [future-layout-editing.md](future-layout-editing.md) | Deferred — layout-editing overlays / model manipulation | Post-MVP |

Phase A (core-path hardening), B-Metal (grid render pipeline
migration), and D (Model Preview polish) are complete and have no
pending items. Phase B has the Metal-backed grid, basic selection,
drag / resize, and long-press menu shipped, with the remaining
parity work tracked in
[phase-b-grid-parity.md](phase-b-grid-parity.md). Cross-phase odds
and ends live in `followups.md`.

Ground rules for sub-plans:

1. Only track **pending** work. Finished items are git history, not plan
   noise.
2. Each bullet should be concrete enough to scope against without
   re-reading the codebase.
3. Keep files focused. If a sub-plan grows past ~600 lines it probably
   needs to be split.
