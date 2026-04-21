# iPad xLights — Plan Index

Work to ship the iPad app is tracked across focused sub-plans here. The
top-level `iPad-xLights-Plan.md` (one directory up) keeps the "what is the
overall situation" material (current state, phase summary, risks, open
questions) and links here for the details.

| File | Phase | Status |
|---|---|---|
| [phase-b-grid-parity.md](phase-b-grid-parity.md) | B — Effects grid parity with desktop | In progress — all P0s + 20+ P1s landed 2026-04-20/21; 6 P1s + ~40 P2 polish items open |
| [phase-d-preview.md](phase-d-preview.md) | D — Model Preview + preview polish | ✓ complete |
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
migration), C (effect settings inspector), D (Model Preview
polish), and E (sequence management) are complete and have no
pending items. Phase B has the Metal-backed grid + every original
P0 (multi-select marquee, align family, split, timing-mark
editing, loop region, lyric sub-layer rendering + word breakdown,
follow-playhead, trackpad scroll) and 20+ P1s (waveform filter
variants, `.xtiming` I/O, import lyrics + auto-label, cut-copy
row/model, multi-effect clipboard, pointer hover, column resize,
etc.) shipped across 2026-04-20/21. Six P1s remain — tags
(B34/B35), randomize/reset (B15), presets menu stub (B19),
export model (B49), visible scrollbars (B94) — plus ~40 P2
polish items tracked in
[phase-b-grid-parity.md](phase-b-grid-parity.md). Phase C closed
2026-04-21 — C4 multi-effect ops, C5 media management, C6 value-
curve presets, and C7 specialised editors (Sketch / Morph /
Moving Head / DMX) all landed. Phase E closed 2026-04-21 — E-1
through E-6 landed (Save-As UI, New Sequence wizard, Sequence
Settings dialog, migration banner, Recent documents, autosave
with `.xbkp` recovery); deferred tabs + `.fseq` emission live in
`followups.md`. Cross-phase odds and ends also live in
`followups.md`.

Ground rules for sub-plans:

1. Only track **pending** work. Finished items are git history, not plan
   noise.
2. Each bullet should be concrete enough to scope against without
   re-reading the codebase.
3. Keep files focused. If a sub-plan grows past ~600 lines it probably
   needs to be split.
