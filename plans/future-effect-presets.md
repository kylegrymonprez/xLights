# Future — Effect Presets on iPad

## Status

**Partial — in-session presets shipped.** `SequencerViewModel`
exposes `saveSelectedEffectAsPreset(name:)` /
`applyPreset(_:)` / `deletePreset(_:)` and the effect
context menu in `SequencerGridV2View.swift` exercises them.
The store is `var presets: [EffectPreset]` — session-only,
cleared on app launch. **Disk-persistent presets remain
unshipped** and are still tracked here.

## Gap (still open)

**G12 — Effect presets (save / load named bundles, persistent).**
Desktop ships `EffectPresetManager` + an effect-tree UI that
persists presets into `xLights/presets/` and re-applies them
across sessions. iPad has the in-session capture/apply, but
nothing on disk and no preset-tree UI.

Outstanding work:

- Bridge method to list existing presets from `xLights/presets/`
  (and surface bundled / show-folder presets too).
- Bridge method to read the full effect settings string at a
  preset path + apply it to the currently-selected effect.
- SwiftUI sheet: preset tree, Save-As, Apply, Delete.
- Promote the existing in-session presets array onto the new
  persistent store (write captured presets to disk on save,
  not just keep them in memory).

## Why not done yet

- The in-session shortcut already covers the "I want to copy
  this effect's settings to a few siblings within one editing
  session" workflow, which is the most common reason power
  users reach for presets day-to-day.
- The on-disk side needs a real picker UI and round-trips with
  desktop's preset tree — non-trivial enough to defer until
  user demand calls it in.
- File-format plumbing is already shared via desktop; no core
  changes needed when we get to it.

Re-scope into Phase C (or a dedicated follow-up phase) when
real users ask to keep presets across launches.

## Pairs with EffectTree dialog

The 2026-04-23 gap analysis (AP-4 in §2.19) recommends shipping
the disk-persistent half together with the EffectTree / EffectList
dialog — preset-tree UI, drag-to-apply, manage / search / import /
export, GIF preview animation. They share a backing store and a
data model; landing one without the other leaves UX rough edges.
See [`future-aux-panels.md`](future-aux-panels.md) AP-4.
