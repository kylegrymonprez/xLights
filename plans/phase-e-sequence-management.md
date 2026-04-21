# Phase E — Sequence management

Everything to do with the *lifecycle of a `.xsq` document*: create
it, open it, edit it, save it, close it, and manage the per-sequence
settings that exist outside the effect grid (timing tracks,
metadata, media file, sequence type, audio tracks, data layers,
render mode).

Open + save + close-with-dirty-prompt + missing-media detection
already shipped as the foundation for Phase C C5 work. Everything
below is what's still open.

---

## E-1. Document lifecycle — remaining pieces

Base save / save-as / dirty-tracking / close-with-prompt landed.
Open items:

- **Save-As UI.** Bridge method `saveSequenceAs:` exists; still
  need a `UIDocumentPicker` / `.fileExporter` sheet with `.xsq`
  as the allowed UTType, plus a Cmd+Shift+S keyboard shortcut on
  the new button.
- **`.fseq` emission alongside save.** Desktop writes a compiled
  `.fseq` to the FSEQ directory so Falcon Player / downstream
  playback can consume it. iPad has no consumer today (controller
  output is out of MVP), so plumb the same `FSEQFile::createFSEQFile`
  path only when a real need surfaces.

## E-2. New Sequence wizard

Desktop's "New" closes the current sequence and launches
`SeqSettingsDialog` in wizard mode
(`src-ui-wx/import_export/SeqFileUtilities.cpp:94`). Required data
before the sequence can be saved:

1. Sequence type (Musical / Animation / Effect — drives which
   wizard pages appear).
2. Media file path (Musical only — otherwise just duration).
3. Duration (Animation / Effect — in seconds or mm:ss).
4. Frame rate (25 / 50 ms are the stock picks; allow custom).
5. Timing-track import (optional — can pick from an existing
   sequence, a `.xtiming` file, or skip).

iPad plan:

- SwiftUI full-screen sheet (`NavigationStack` with step-by-step
  pages). Use the same terminology and order as desktop so docs /
  tutorials still apply.
- Page 1: type picker. Page 2a (Musical): media picker (routes
  through existing `MediaRelocation` modifier so the file ends up
  under the show folder or a configured media folder). Page 2b
  (Animation / Effect): duration + frame rate. Page 3: timing
  track import (optional).
- On finish: bridge
  `-newSequenceWithType:mediaPath:durationMS:frameMS:` creates a
  blank `SequenceElements` tree, imports the picked timing tracks,
  loads into `SequencerViewModel`. Sequence is marked dirty until
  the first save so the user can't lose the wizard work by
  accident.
- Entry points: File menu (Phase F-4), empty-state screen on app
  launch when no recent sequence is open, toolbar "+" next to the
  sequence name.

## E-3. Sequence Settings dialog

Post-open editor for sequence-wide settings. Desktop
`SeqSettingsDialog` has six notebook tabs (Info, Timings, Metadata,
Data Layers, Audio, plus wizard pages hidden outside the wizard
flow). Source: `src-ui-wx/sequencer/SeqSettingsDialog.{h,cpp}`.

Implement as a `.sheet` with a segmented control or sidebar tabs —
not a wizard. Desktop shares the dialog between New and
Sequence-Settings workflows; iPad splits them (E-2 handles New).

Tabs to port, ordered by how often users touch them:

- **Timings** — add / rename / delete timing tracks; import from
  another sequence or `.xtiming`; export to `.xtiming`. Partial
  support already exists (rename / delete via row-header long-press);
  the dialog centralises it and adds import / export.
- **Metadata** — song, artist, album, author, website, comment,
  music URL. Plain text fields persisted on `SequenceFile`
  metadata attributes. New bridge getters / setters needed.
- **Info** — read-only summary (filename, file version, model
  count) plus sequence type selector. Rarely changed
  post-creation.
- **Media file** — swap the media file. Routes through
  `MediaRelocation` again; may re-run the audio-analysis path if
  the file changes.
- **Audio Tracks** — list of alternate audio tracks (add / remove
  / rename / pick file). Deferred behind a feature flag if we
  ship Phase E without alt-track playback; the data still
  round-trips through the XML either way so it's not destructive
  to skip the UI.
- **Render Mode / Blending** — GPU blend mode dropdown + model-
  blending toggle. Rarely changed; small surface.
- **Data Layers** — image-data layers UI. Lowest priority;
  deferred post-MVP unless someone is using them on the iPad.

Entry: File menu → "Sequence Settings…" and a gear icon in the
sequencer toolbar.

## E-4. Load-time migration + remaining media pieces

Missing-media detection + banner landed. Per-row "Replace from
Disk…" relocation shipped (2026-04-21) — broken rows expose a red
swipe action that opens `.fileImporter`, copies the picked file
into the show folder's type-appropriate subdir, and either
`ReloadMedia`s in place (when the target happens to match the
stored path byte-for-byte) or routes through `RenameMedia` +
`rewriteEffectValues` so every referencing effect picks up the
new path. Open items:

- **Effect version migration banner.** `SequenceFile::LoadSequence`
  already runs `RenderableEffect::adjustSettings(version, effect)`
  across every effect (`SequenceFile.cpp:1895-1933`). What's
  missing: bubble the sequence's original file version up to Swift
  so the UI can tell the user "this sequence was created in
  xLights 2024.07 and has been migrated; save to update". Also
  mark the sequence dirty after a migration ran so the user's
  first save persists the upgraded form.

## E-5. Recent documents + empty state

Desktop has an MRU list surfaced via the File menu. iPad should
have the equivalent plus a launch-time empty state:

- Persist the last N opened `.xsq` bookmarks (security-scoped) in
  UserDefaults. Surface as "Open Recent" in the File menu (F-4)
  and as cards on a launch-screen view when no sequence is open.
- Launch-screen view: "New Sequence" button (E-2), "Open
  Sequence" button (picker), "Open Recent" list. Replaces the
  current cold-launch state where the user has to manually tap
  into the sequencer with nothing loaded.

## E-6. Autosave / crash recovery (`.xbkp`)

Desktop periodically writes an `.xbkp` snapshot to the show folder
so a crash doesn't lose more than the autosave interval. On next
open, if a newer `.xbkp` exists alongside the `.xsq`, it's offered
for recovery. Source: `src-ui-wx/import_export/SeqFileUtilities.cpp`
autosave timer + the close-time timestamp adjustment that
suppresses the offer after an explicit discard.

- Port the autosave timer into `SequencerViewModel` (a
  `Timer.publish` at a configurable interval; default 5 min).
- On sequence open, check for `<basename>.xbkp` newer than the
  `.xsq`; if present, sheet the user: "Recover changes from
  <time>?" Apply or discard via the same bridge save path.
- On explicit Close → Save / Close → Discard, update the `.xbkp`
  mtime so recovery isn't re-offered.

---

## Explicitly out of scope for Phase E

- **iCloud Drive coordination** (`NSFileCoordinator`, ubiquity
  status) — Phase G covers this. E-1 writes through plain file
  I/O.
- **Files-app "Open in xLights" routing** — Phase G-3 registers
  the document type. Phase E opens via in-app pickers only.
- **Data Layers UI** — deferred until a user actually needs it on
  iPad. The XML round-trips through the loader unchanged.
- **Full `SeqSettingsDialog` wizard fidelity** — Phase E-2 uses
  the same data flow but doesn't attempt pixel parity with the
  desktop wxSmith layout.
