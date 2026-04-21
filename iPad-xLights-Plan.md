# xLights iPad — Implementation Plan

This file tracks overall status. Details for each phase live under
[`plans/`](plans/README.md) — one focused sub-plan per phase, listing
only the work still to do. Completed phases have no sub-plan.

---

## Current state

### Goal of the work so far

The work so far has been scoped to the **core rendering path**: load a
sequence, render it through the same C++ effect pipeline as desktop
xLights, and display the house preview during playback. That is done
and verified on a physical iPad. Shaders, video effects, and most
effects render correctly.

Everything above the core baseline — effects grid, inspector, output,
preview chrome — has been rebuilt for touch. The effects grid is now
Metal-backed, the inspector is metadata-driven with a four-tab shell,
and both previews are interactive on device. A 2026-04-20 parity
audit caught ~100 missing authoring behaviours vs desktop; the P0
bundle (multi-select + marquee, align/split, timing-mark editing,
phrase breakdown, lyric sub-layer rendering, follow-playhead) has
been cleared except for the loop-region / tags / render-selected
cluster. Remaining work is one P0 bundle plus a long tail of P1/P2
polish — see [`plans/phase-b-grid-parity.md`](plans/phase-b-grid-parity.md).

### Code layout

iPad code lives at `src-iPad/` at the repo root (peer to `src-ui-wx/`).
It is not under `macOS/`: code in `macOS/` cannot depend on anything
outside `macOS/`, so the iPad UI sits alongside the other UI layer
instead.

```
src-iPad/
  App/            SwiftUI views + view model
  Bridge/         ObjC++ bridges (XLSequenceDocument, iPadRenderContext,
                  XLiPadInit, CoreGraphicsTextDrawingContext,
                  XLValueCurve)
  Metal/          xlStandaloneMetalCanvas, iPadModelPreview,
                  XLMetalBridge, iPadGridPreview, XLGridMetalBridge
  Metadata/       EffectMetadata.swift (JSON model for effectmetadata/*.json)
```

Shared core that iPad consumes:

- `src-core/` — wx-free C++ core (renderers, models, outputs, render
  engine, effect manager, sequence file/elements, audio manager).
- `macOS/src-apple-core/` — Apple shared code (Metal device manager,
  external hooks, Apple utilities in Swift and ObjC++).

### Xcode targets

| Target | Purpose | Multi-platform |
|---|---|---|
| `xLights-core` | wx-free core (`src-core/`) | macOS + iOS |
| `xLights-Apple-core` | Apple shared code (`macOS/src-apple-core/`) | macOS + iOS |
| `xLights-macOSLib-UI` | macOS-only UI (`macOS/src-mac-ui/`) | macOS only |
| `xLights` | Desktop app | macOS only |
| `EffectComputeFunctions` | Metal shaders | macOS + iOS |
| `UIMetalShaders` | UI Metal shaders | macOS only |
| `ISPCEffectComputeFunctions` | SIMD kernels | macOS + iOS |
| `xLights-iPadLib` | iPad bridge code (`src-iPad/`) | iOS |
| `xLights-iPad` | SwiftUI iPad app | iOS 26+ |

iOS dependencies live at `/opt/xLights-macOS-dependencies/lib-ios/`:
`libcurl.a`, `libEGL.xcframework`, `libGLESv2.xcframework` (ANGLE),
`libliquidfun.a`, `liblua.a`, `libxlsxwriter.a`, `libzstd.a`. Debug
variants in `libdbg-ios/`.

---

## Phase status

| Phase | Title | Status | Sub-plan |
|---|---|---|---|
| A | Core-path hardening | ✓ complete | — (one small follow-up in [`plans/followups.md`](plans/followups.md)) |
| B | Effects grid parity with desktop | In progress — all original P0 gaps closed 2026-04-20: multi-select + two-finger marquee, align family, split-at-play-marker, timing-mark editing (create / drag / rename / delete / split / merge / add-track), row-level phrase breakdown, lyric sub-layer rendering, follow-playhead, trackpad scroll. One P0 bundle still open (loop region / tags / render-selected-region) plus a long tail of P1 polish (row-heading ops, waveform filter variants, `.xtiming` import/export, drag-to-scrub). | [`plans/phase-b-grid-parity.md`](plans/phase-b-grid-parity.md) |
| B-Metal | Grid render pipeline migration (CG → Metal) | ✓ complete | — |
| C | Effect settings inspector | ✓ complete — two polish follow-ups (MH colour/path authoring, DMX state persistence) tracked in [`plans/followups.md`](plans/followups.md) | — |
| D | Model Preview + preview polish | ✓ complete — layout-editor overlays parked in [`plans/future-layout-editing.md`](plans/future-layout-editing.md) | [`plans/phase-d-preview.md`](plans/phase-d-preview.md) |
| E | Sequence management (open / save / new / settings) | ✓ complete — E-1 through E-6 shipped 2026-04-21. Deferred tabs (Timings import/export, Audio Tracks, Data Layers) + `.fseq` emission tracked in [`plans/followups.md`](plans/followups.md) | — |
| F | Window system + Display Elements | In progress — F-6 Display Elements editor landed 2026-04-21 (bridge + SwiftUI sheet + view-picker entry). F-4 (menu bar / `.commands`), F-1 (scene split), F-2 / F-3 / F-5 still open. | [`plans/phase-f-window-system.md`](plans/phase-f-window-system.md) |
| G | Document / iCloud polish | Not started | [`plans/phase-g-document.md`](plans/phase-g-document.md) |
| H | App Store readiness | Not started | [`plans/phase-h-app-store.md`](plans/phase-h-app-store.md) |

**Parallelism.** Phase B is the only remaining pre-Phase-F work;
it runs against the Metal grid + `SequencerViewModel` + row
headers. Phase F composes the finished pieces (previews,
inspector, grid) plus the File-menu commands (E) into the final
window / menu-bar layout. G and H are sequential at the end.

**Preview scope.** Phase D is preview *viewing and appearance*: camera,
overlays, background, labels, transport, export. Desktop `ModelPreview`
also hosts the layout editor (drag-to-move, resize handles, polyline
editing, align/distribute, property grid) — that behaviour stays
desktop-only and is not in Phase D or anywhere else in the iPad plan.
Per-view model visibility / layout-group management is Phase F.

### Deferred / explicitly out of MVP

- **Controller output** — infrastructure is in the tree (output
  manager, per-frame send, sACN / ArtNet / DDP / OPC) but not on the
  MVP critical path. Revisit after App Store submission.
- **JobPool requeue redesign** — desktop-scope refactor to replace
  block-on-other-model-frame with re-enqueue. Tracked separately; the
  iPad workaround is "more threads."
- **Layout editor, controller setup** — stays desktop-only.

---

## Risks

- **JobPool deadlock on complex sequences** — mitigated by raising the
  thread count; the underlying "workers block on peers" pattern is
  still there.
- **Memory on mid-tier iPads** — Phase A memory-pressure handling is
  in place but under-tested.
- **AVFoundation codec coverage** — video effects with unusual codecs
  fail; no FFmpeg fallback on iPad.

---

## Open questions

1. For Phase H (App Store), existing Apple Developer team? And is the
   iPad app a separate App Store record or shipped as a universal app
   alongside macOS? (Impacts bundle id and entitlements.)
