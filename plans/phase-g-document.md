# Phase G — Document / iCloud polish

Builds on the Phase E document lifecycle. Phase E gets save / save-as
/ open / close / new working against the local filesystem and the
show-folder bookmark; Phase G layers on the iPadOS-idiomatic polish
around iCloud Drive, multi-process file coordination, and the "Open
in xLights" system integration.

**Status: ✓ complete 2026-04-21 — pending device verification.**

## What landed

### G-3 — `.xsq` registered as a document type

- Partial `Info.plist` at `macOS/Assets/xLights-iPad/Info.plist`
  declares `org.xlights.sequence` (conforms to `public.xml`,
  extension `xsq`) with a single `CFBundleDocumentTypes` entry
  (role `Editor`, `LSHandlerRank=Owner`). `INFOPLIST_FILE` build
  setting points at it; `GENERATE_INFOPLIST_FILE = YES` stays so
  Xcode still merges in `CFBundle*`, scene-manifest, and
  orientation keys from the pbxproj.
- `ContentView` gained `.onOpenURL { handleIncomingSequenceURL($0) }`.
  Handler calls `XLSequenceDocument.obtainAccess(toPath:…)` to
  mint a security-scoped bookmark for the URL (so reads/writes
  survive app restart), then routes into `viewModel.openSequence`.
- If the URL arrives before the show folder has finished loading
  (typical cold-launch flow from Files), it's queued in
  `pendingOpenURL` and replayed when `isShowFolderLoaded`
  transitions to true.
- **`.xsqz` intentionally NOT registered** — the zip-container
  extraction lives in `src-core/render/SequencePackage.cpp` and
  isn't wired into the iPad bridge yet. Advertising `.xsqz` would
  route taps into xLights that we can't fulfil. Revisit when
  `SequencePackage` is integrated on iPad.

### G-1 — `NSFileCoordinator` on sequence writes

- `SequencerViewModel` added a `coordinatedWrite(at:_:)` helper
  that wraps the bridge call in
  `NSFileCoordinator.coordinate(writingItemAt:options:.forReplacing)`.
  Blocks Files-app / iCloud-daemon / any other file presenter for
  the duration of the write, so concurrent activity can't corrupt
  the `.xsq`.
- `saveSequence()`, `saveSequenceAs(path:)`, and
  `tickAutosave()` (for `.xbkp` writes) all route through the
  helper. Empty-path case (new unsaved sequence) bypasses the
  coordinator — nothing to coordinate against.

### G-2 — iCloud ubiquity status in the sequence picker

- `UbiquityStatus` enum (`.local` / `.downloaded` / `.downloading`
  / `.notDownloaded`) + `ubiquityStatus(for: URL)` helper that
  reads `URLResourceKey.isUbiquitousItemKey`,
  `ubiquitousItemDownloadingStatusKey`, and
  `ubiquitousItemIsDownloadingKey`.
- `UbiquityBadge` view renders `icloud` /
  `icloud.and.arrow.down` icons with appropriate tints. `.local`
  suppresses the badge so on-disk files read as plain text.
- `SequencePickerView`'s Recent and show-folder rows carry the
  badge.
- `openWithDownloadIfNeeded(path:status:)` — for `.notDownloaded`
  taps, calls `FileManager.default.startDownloadingUbiquitousItem(at:)`
  and then polls up to ~5 s for the file to land before calling
  `openSequence`. Other statuses open immediately.

### G-4 — scene-lifecycle audit

- `quiesceForInactive()` already pauses playback + scrub (stops
  frame timers, audio); sufficient for `.inactive`.
- `shutdownForBackground()` already cancels the background render
  poll and calls `abortRenderAndWait(3.0)` to unwind render
  workers.
- **Added:** `shutdownForBackground` now also stops controller
  output (`document.stopOutput()` + clear `isOutputting`). iOS
  throttles backgrounded apps' network traffic so an active
  sACN/ArtNet/DDP stream becomes unreliable; halting cleanly
  avoids partial-frame sends. User re-enables via the toolbar
  output toggle on foreground.
- No explicit render-cache flush needed — `abortRenderAndWait`
  plus the existing memory-pressure handlers
  (`handleMemoryWarning` / `handleMemoryCritical`) cover the
  resident-memory cleanup story.

## Device verification (pending)

- Tap a `.xsq` in Files → system menu offers xLights → taps open
  the file with security-scoped access that survives the app
  restart.
- Save a sequence while Files.app is viewing the same folder →
  no corruption, save completes cleanly.
- Open a sequence that lives in iCloud Drive but isn't
  downloaded → badge shows `icloud.and.arrow.down` → tapping
  triggers download and opens when available.
- With controller output active, background the app → output
  stops cleanly; foreground and re-enable works.
