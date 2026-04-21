# Phase F — Window System + Display Elements

Consumes finished previews from Phase D, the document lifecycle from
Phase E, and the Metal-backed grid + inspector from Phases B / C.
Focus is the Scene-level layout, menu bar, multi-window / external
display routing, and — the one item that unlocks new user capability —
the **Display Elements** editor. All other Phase F items are polish on
a surface that already works as a single window.

---

## Strategy and sequencing

The current app is one `WindowGroup("xLights", id: "sequencer")` at
`src-iPad/App/XLightsApp.swift:23` with everything crammed into
`SequencerView` at `src-iPad/App/SequencerView.swift`. It works; the
user can edit, render, play back, save. What they *can't* do:

1. Author named views (add / rename / reorder / populate) —
   the view picker at `SequencerGridV2View.swift:418-473` is
   read-only. **This blocks power users on any multi-scene show**.
2. Discover keyboard shortcuts via the iPadOS 26 menu bar — every
   shortcut is a hidden button in the toolbar (`SequencerView.swift:307-382`).
3. Detach a preview or inspector to a second window, an external
   display, or a Stage Manager pane on 12.9" iPad.
4. Resume where they left off after a cold launch (which preview was
   visible, which inspector tab, 2D/3D mode per pane).

Of these, #1 is a hard block on the authoring workflow; #2 is the
difference between "feels native on iPadOS 26" and "feels like a port";
#3/#4 are quality-of-life once the foundation exists.

**Proposed ordering** — each bullet is ~1 self-contained PR:

1. **F-6 Display Elements** (modal sheet, ~1 week). Self-contained. New
   bridge surface for view CRUD + model membership + per-element
   visibility + per-timing-track view membership, new SwiftUI sheet.
   Ships immediately — nothing else in Phase F blocks on it.
2. **F-4 Menu bar + Commands** (~3 days). Wrap the existing hidden-
   button shortcuts in a `.commands { }` block on the scene; route
   File / Edit / View / Playback / Help. No behaviour changes, just
   discoverability.
3. **F-1 Scene-level layout** (~1 week). Add second `WindowGroup` for
   detachable previews and a keyed `WindowGroup` for detachable
   inspector tabs. Keep the main window functional as-is; detach is
   opt-in.
4. **F-5 Persistence** (~2 days). Once F-1 lands, sprinkle
   `@SceneStorage` across the scene roots so layout survives relaunch.
5. **F-2 Size-class responsive layout** (~3 days). Adapt
   `SequencerView` for compact (Slide Over) and 12.9"+ wide layouts.
6. **F-3 Docked layout** (~2 days). 12.9"+ side-by-side previews;
   11" toggle-which-preview-docks.

Items 1 and 2 get the app from "usable but limited" to "usable with
full authoring surface + native feel". Items 3–6 layer on multi-window
polish; any of them can slip to G without blocking shipping.

Total Phase F is 3–4 weeks if F-1 through F-5 all land; **F-6 + F-4
alone is ~2 weeks and removes the remaining hard blocks.**

---

## F-6. Display Elements editor *(✓ landed 2026-04-21 — pending device verification)*

**Shipped:** bridge additions on `XLSequenceDocument` (view CRUD +
reorder, models-in-view add/remove/move, element roster + visibility,
per-timing-track view membership, `addTimingToAllViews:` for B82,
show-layout roster via `modelsAvailableInShowLayout`,
`addModel(toMasterView:)`, `elementHasEffects:`,
`removeElementFromMasterView:`); SwiftUI sheet
`DisplayElementsSheet.swift` (NavigationSplitView sidebar with
Master-locked views list, two-pane transfer UI for both Master and
user views — Available / In-View — with visibility eye toggles plus
remove-with-warning on Master View for effects and timings); entry
point in the existing view-picker Menu at `SequencerGridV2View.swift`
("Edit Display Elements…"). Clean build against the xLights-iPad
target.

**Key correction vs first pass:** Master View is "elements the
sequence has opted in", NOT "every model in the show". Effect
Sequences start with the Available pane populated and the In-Master
pane empty; users bring models in one at a time. Removing from
Master deletes the Element (and any effects on it), matching
desktop's `RemoveSelectedModels` MASTER_VIEW path including the
pre-delete `AbortRender()` guard (issue #4134).

**Device verification (pending user):**
- Create "Roof" view with two models → save → reopen — view survives
  as `<view name="Roof" models="…"/>` in `.xsq`.
- Add timing track "Drum" to Roof + Master — `DisplayElements`
  `views="Master View,Roof"` round-trips.
- Rename, reorder, clone, delete flows.
- Hide/show Master-View elements persists via `DisplayElements`
  `visible=` attribute.

---

## F-6 original spec (for audit reference)

Ports `src-ui-wx/layout/ViewsModelsPanel.cpp` (~2900 LOC; we don't need
all of it). Presented as a SwiftUI `.sheet`, not a dockable panel —
used infrequently, doesn't need to stay on screen.

### Scope

What the panel must do, distilled from `ViewsModelsPanel.cpp` +
`src-core/render/SequenceViewManager.{h,cpp}` +
`src-core/render/SequenceElements.cpp:891-1043`:

- **Views list** (left/top).
  - Add / rename / delete / clone view.
  - Reorder up / down (`SequenceViewManager::MoveViewUp/Down`).
  - Select current view (wires through existing
    `setCurrentViewIndex` bridge at `XLSequenceDocument.mm:849`).
  - Master View pinned at index 0; can't delete or rename it
    (matches `SequenceViewManager::MASTER_VIEW_NAME` handling at
    `SequenceViewManager.cpp:225-230`).
- **Models in current view** (right).
  - Ordered list, matches desktop `ListCtrlModels`.
  - Add selected / Add all / Remove selected / Remove all.
  - Move selected up / down / top / bottom.
  - Per-row visibility toggle (`Element::SetVisible`).
  - Flat list, not tree — matches desktop.
- **Non-members** (left, alongside views).
  - Every model in the show that isn't in the current view, plus
    every timing track.
  - For timing tracks: per-view membership checkbox (the
    `TimingElement::mViews` comma-separated list). Desktop shows
    this via the views column on the timings side.
- **Copy To Master** (desktop `Button_MakeMaster`) —
  destructive, ask to confirm. P2; drop for first pass.
- **Import views from another sequence / rgbeffects.xml** — desktop
  `ButtonImport`. P2; drop for first pass.

### Bridge surface

All of this should live on `XLSequenceDocument` (matches existing view
methods at `XLSequenceDocument.mm:835-866`). Add:

```objc
// Views — CRUD
- (BOOL)addViewNamed:(NSString*)name;
- (BOOL)deleteViewAtIndex:(int)idx;
- (BOOL)renameViewAtIndex:(int)idx to:(NSString*)name;
- (BOOL)cloneViewAtIndex:(int)idx as:(NSString*)name;
- (BOOL)moveViewUpAtIndex:(int)idx;
- (BOOL)moveViewDownAtIndex:(int)idx;

// Models in view (delegates to SequenceView::AddModel/RemoveModel/
//                InsertModelBefore/InsertModelAfter + SequenceElements
//                ::PopulateView to keep mAllViews in sync)
- (NSArray<NSString*>*)modelsInViewAtIndex:(int)idx;
- (BOOL)addModel:(NSString*)name toViewAtIndex:(int)idx atPosition:(int)pos;  // -1 = end
- (BOOL)removeModel:(NSString*)name fromViewAtIndex:(int)idx;
- (BOOL)moveModel:(NSString*)name inViewAtIndex:(int)idx toPosition:(int)pos;

// Elements roster (for the "available models + timings" side)
- (NSArray<NSString*>*)allModelNamesInShow;       // Master-View model list
- (NSArray<NSString*>*)allTimingTrackNames;       // every TimingElement
- (BOOL)elementVisible:(NSString*)name;
- (BOOL)setElementVisible:(NSString*)name visible:(BOOL)v;

// Per-timing-track view membership (TimingElement::mViews)
- (NSArray<NSString*>*)viewsContainingTiming:(NSString*)name;
- (BOOL)addTiming:(NSString*)name toViewNamed:(NSString*)view;
- (BOOL)removeTiming:(NSString*)name fromViewNamed:(NSString*)view;
- (BOOL)addTimingToAllViews:(NSString*)name;  // B82
```

Each mutating call marks the document dirty (same path the inspector
uses) so the existing 500 ms dirty poll picks it up and the save
button activates. For views CRUD, post a notification
(`XLViewsChanged`) so the existing view picker at
`SequencerGridV2View.swift:418-473` refreshes; for model-membership
changes in the *current* view, also call `PopulateRowInformation` so
`reloadRows()` produces the new row set.

Implementation hooks on the C++ side already exist — everything the
bridge needs is on `SequenceViewManager` (`AddView / DeleteView /
RenameView / MoveViewUp / MoveViewDown`) and `SequenceElements`
(`AddTimingToView / AddTimingToAllViews / PopulateView /
AddMissingModelsToSequence / SetTimingVisibility`). No C++ additions
required.

### SwiftUI surface

New file `src-iPad/App/DisplayElementsSheet.swift`. Presented from
two entry points:

- View menu (F-4): "Edit Display Elements…" command.
- Toolbar gear / picker accessory next to the view dropdown at
  `SequencerGridV2View.swift:424-459` — add an "Edit…" entry to the
  existing Menu's action list.

Layout (iPad-appropriate, not a 1:1 clone of the wx panel):

```
Sheet (full-screen on compact, large form-sheet on regular)
├─ NavigationStack
│  ├─ ToolbarItem(.confirmationAction) — Done
│  └─ ToolbarItem(.cancellationAction) — Cancel (reloads from disk)
└─ HSplitView / NavigationSplitView
   ├─ Sidebar: views list
   │  ├─ List(viewsVM.views, selection: $selectedView)
   │  │  └─ Row: view name, pencil-to-rename, drag handle to reorder
   │  └─ Toolbar: [+] [–] [Clone] [Up] [Down]
   └─ Detail: two-pane "members / non-members" transfer UI
      ├─ Non-members (filterable list — models + timings, grouped)
      │  └─ Multi-select with [→] button per row or batch bar
      └─ Members (the ordered list for `selectedView`)
         ├─ Reorderable list (SwiftUI `.onMove`)
         ├─ Per-row eye toggle → `setElementVisible:`
         └─ For timings: chevron disclosing "in views: …" editor
```

Use `NavigationSplitView` so compact-width collapses the sidebar into
a dropdown — keeps Slide Over usable.

### State model

One sheet-local `@Observable` VM (`DisplayElementsViewModel`) that
mirrors the bridge. On open, snapshot everything via the bridge into
Swift-side structs; mutate in place against the bridge; on Cancel,
reload from disk via `document.reloadSequence()` (needs verifying that
autosave doesn't get in the way — if so, the cancel path instead
re-fetches via the same snapshot-get bridge calls without writing). On
Done, close sheet; the underlying dirty-poll + save flow handles
persistence.

### Tests / verification

- Open a sequence with no non-Master views, add "Roof" view with two
  models, switch to it, save, reopen — view survives in
  `<views>…<view name="Roof" models="Roof1,Roof2"/>…</views>` in the
  `.xsq` (matches `SequenceFile.cpp:1410-1430`).
- Add timing track "Drum" to the "Roof" view and to Master — verify
  `DisplayElements` entry `<Element type="timing" name="Drum" …
  views="Master View,Roof"/>` round-trips.
- Rename a view while it's the active view — ensure the view picker
  label and the active-view index both follow.
- Delete the currently-active view — bridge should fall back to
  Master View (match desktop `ViewsModelsPanel::DeleteSelectedView`
  at line 1388).
- Hide a model in the current view — the grid drops the row on next
  `reloadRows()`.

### Out of scope for F-6

- `Button_MakeMaster` (copy-to-master) — P2, leave a menu stub.
- `ButtonImport` (import views from another sequence) — P2.
- Drag-and-drop between panes (use explicit buttons for iPad touch).

---

## F-4. Menu bar + Commands *(✓ landed 2026-04-21 — pending device verification)*

**Shipped:**
- `src-iPad/App/XLightsCommands.swift` — `XLSequencerCommands: Commands`
  hosting File / Edit / View / Playback menus. Attached to the
  WindowGroup in `XLightsApp.swift` via `.commands { … }`.
- `TimelineFocusedValueKey` + `FocusedValues.timeline` extension
  added to `TimelineState.swift`. `SequencerView` exposes its
  timeline via `.focusedValue(\.timeline, timeline)` so the
  Zoom In / Out commands can read it.
- `SequencerViewModel` gained `showingSequenceSettings`,
  `showingDisplayElements`, `saveAsRequestToken`, and
  `closeRequestToken` so view-owned flows (file exporter, dirty-
  prompt, Display Elements sheet, Sequence Settings sheet) can be
  signalled from the app-level command handlers. `SequencerView`
  `.onChange` observes the tokens and runs the existing
  `startSaveAs()` / dirty-prompt logic.
- Deleted the hidden shortcut Group at the bottom of the toolbar in
  `SequencerView.swift`; removed `.keyboardShortcut` modifiers from
  visible toolbar buttons (Save, Save As, Undo, Redo, Play/Pause,
  Zoom In, Zoom Out). Toolbar buttons still respond to taps; the
  shortcut bindings now live exclusively in Commands.

**Shortcuts now in the menu bar:**

| Menu | Item | Shortcut |
|---|---|---|
| File | Close | ⌘W |
| File | Save | ⌘S |
| File | Save As… | ⇧⌘S |
| File | Sequence Settings… | — |
| Edit | Undo | ⌘Z |
| Edit | Redo | ⇧⌘Z |
| Edit | Copy | ⌘C |
| Edit | Paste | ⌘V |
| Edit | Duplicate | ⌘D |
| Edit | Delete | ⌫ |
| Edit | Clear Selection | ⎋ |
| View | Zoom Out | ⌘- |
| View | Zoom In | ⌘= |
| View | Show / Hide Preview | ⌘1 |
| View | Show / Hide Inspector | ⌘2 |
| View | Edit Display Elements… | ⇧⌘D |
| Playback | Play / Pause | Space |
| Playback | Stop | — |
| Playback | Rewind to Start | Home |
| Playback | Jump to End | End |
| Playback | Back 10 Seconds | ⌥← |
| Playback | Forward 10 Seconds | ⌥→ |
| Playback | Previous / Next Frame | , / . |
| Playback | Previous / Next / Above / Below Effect | ← / → / ↑ / ↓ |

**Intentionally omitted from v1:** Cut (⌘X) and Find (⌘F). Both
would swallow the key event even while disabled; better to leave them
out until B53 (row-level cut) and B97 (Find/Replace) land. Also
excluded: New Sequence and Open… from the File menu — the sequence
picker is reachable via Close, and wiring menu→picker-sheet adds
surface without freeing the user from anything.

**Device verification (pending user):** hardware keyboard attached,
menu bar shows File / Edit / View / Playback, every command fires,
disabled states track selection / playback / sequence-loaded, Space
doesn't swallow typing when a text field has focus (Display Elements
name field, Sequence Settings metadata fields, etc.).

---

## F-4 original spec (for audit reference)

iPadOS 26 shows the SwiftUI menu bar whenever a hardware keyboard is
attached. Every shortcut the app already implements is discoverable
there. Implementation is a single `.commands { }` on the main
`WindowGroup`:

```swift
WindowGroup("xLights", id: "sequencer") { ContentView() }
    .commands {
        CommandGroup(replacing: .newItem) { /* New / Open / … */ }
        CommandMenu("Playback") { /* Play, Rewind, Seek … */ }
        CommandMenu("View") { /* toggles + Edit Display Elements */ }
        CommandGroup(replacing: .undoRedo) { /* Undo / Redo */ }
        CommandGroup(replacing: .pasteboard) { /* Cut / Copy / Paste / Dup */ }
    }
```

### Menu layout

Mirrors the desktop xLights menu bar. Each command calls into the
same `viewModel` methods the hidden toolbar buttons at
`SequencerView.swift:307-382` already call — we're just exposing them
with a label.

| Menu | Item | Shortcut | Hooks |
|---|---|---|---|
| File | New Sequence… | ⌘N | existing New wizard |
| File | Open… | ⌘O | existing Open |
| File | Open Recent ▸ | — | existing Recent list |
| File | Close | ⌘W | existing Close |
| File | Save | ⌘S | existing |
| File | Save As… | ⇧⌘S | existing |
| File | Sequence Settings… | — | existing gear button |
| Edit | Undo | ⌘Z | existing |
| Edit | Redo | ⇧⌘Z | existing |
| Edit | Cut | ⌘X | **gap** (B53 row-level cut lands in Phase B) |
| Edit | Copy | ⌘C | existing |
| Edit | Paste | ⌘V | existing |
| Edit | Duplicate | ⌘D | existing |
| Edit | Select All | ⌘A | existing (B2) |
| Edit | Find… | ⌘F | **stub**, routes to B97 Find/Replace (P2) |
| View | Zoom In | ⌘= | existing |
| View | Zoom Out | ⌘– | existing |
| View | Zoom to Fit | ⌘0 | B37 (Phase B) |
| View | Zoom to Selection | ⌥⌘0 | B36 (Phase B) |
| View | Toggle Preview | ⌘1 | existing |
| View | Toggle Inspector | ⌘2 | existing |
| View | Open Effect Settings in New Window | ⌥⌘E | F-1 hook |
| View | Open Colors in New Window | ⌥⌘C | F-1 hook |
| View | Open Blending in New Window | ⌥⌘B | F-1 hook |
| View | Open Buffer in New Window | ⌥⌘U | F-1 hook |
| View | Detach House Preview | ⌥⌘H | F-1 hook |
| View | Detach Model Preview | ⌥⌘M | F-1 hook |
| View | **Edit Display Elements…** | ⇧⌘D | F-6 sheet |
| Playback | Play / Pause | Space | existing |
| Playback | Stop | ⌘. | existing |
| Playback | Rewind to Start | Home | existing |
| Playback | Back 10s | ⌥← | existing |
| Playback | Forward 10s | ⌥→ | existing |
| Playback | Previous Frame | , | existing |
| Playback | Next Frame | . | existing |
| Help | xLights Help… | — | link to wiki |

Once the menu bar exists, **delete** the hidden keyboard-shortcut
buttons at `SequencerView.swift:307-382`. The commands replace them;
keeping both produces duplicate-shortcut warnings in iPadOS 26.

Items that reference Phase B unlanded gaps (Find, Zoom to Selection /
Fit, Cut Row) ship **with the Phase B work that fills them in**, not
with F-4. F-4 itself adds the menu shell with those entries disabled
(or hidden behind `#available`-style guards) until Phase B catches up.

---

## F-1. Scene-level layout

Split `ContentView` into multiple scenes:

```swift
@main struct XLightsApp: App {
    @State private var viewModel = SequencerViewModel()
    var body: some Scene {
        WindowGroup("xLights", id: "sequencer") {
            ContentView().environment(viewModel)
        }
        .commands { …F-4… }

        Window("House Preview", id: "house-preview") {
            DetachedHousePreviewRoot().environment(viewModel)
        }
        .defaultSize(width: 960, height: 540)

        Window("Model Preview", id: "model-preview") {
            DetachedModelPreviewRoot().environment(viewModel)
        }
        .defaultSize(width: 640, height: 480)

        WindowGroup(id: "inspector-tab", for: InspectorTab.self) { $tab in
            DetachedInspectorRoot(tab: tab ?? .effect).environment(viewModel)
        }
        .defaultSize(width: 360, height: 720)
    }
}
```

Key decisions:

- **Shared `viewModel`.** The existing `SequencerViewModel` is
  `@Observable` and lives at app level (`XLightsApp.swift:5`). Pass
  the same instance to every scene via `.environment(viewModel)`.
  All derived state (selection, play position, row list, rendered
  background data) updates across windows for free.
- **Per-pane local state stays local.** `PreviewSettings` (is3D /
  showViewObjects) and per-preview camera state remain
  pane-scoped — each scene gets its own. This matches the current
  pattern at `HousePreviewView.swift:9-32` and behaves correctly
  when the user detaches and drags the pane to an external display.
- **Detach is a user action.** View menu entries (F-4) +
  toolbar "detach" buttons on each pane call
  `openWindow(id: "house-preview")` / `openWindow(id: "inspector-tab",
  value: .colors)`. When a scene is opened, the embedded version in
  `SequencerView` collapses (`@SceneStorage("housePreviewDetached")`).
  Re-dock via the window's close button — the scene's
  `.onDisappear` flips the flag back.
- **Inspector keying.** `WindowGroup(for: InspectorTab.self)` gives
  each tab its own scene window (iPadOS 26 treats each value as a
  distinct restorable window). When the user opens Effect and Colors
  windows, they're two real windows that can go to different
  displays.
- **External display routing.** iPadOS 26's Stage Manager treats
  external displays as additional scene groups; we don't pick the
  display, the user drags the window there. We only set
  `defaultSize` hints. The pre-existing D-13 / D-14 plumbing (layout
  group, view objects, camera state) keeps working without changes.

### Extraction work

Each detachable pane becomes a thin scene root that hosts the pane
content and its own controls:

- `DetachedHousePreviewRoot` — wraps existing `HousePreviewView`
  contents (`HousePreviewView.swift:20-66`) with a window-local
  toolbar (layout group picker, 2D/3D toggle, viewpoint menu, fit,
  share-sheet export), because the main window's toolbar is no
  longer visible.
- `DetachedModelPreviewRoot` — wraps `ModelPreviewView`
  (`HousePreviewView.swift:69-87`) similarly.
- `DetachedInspectorRoot(tab:)` — reuses the existing
  `EffectMetadataPanel` (`EffectSettingsView.swift:271-519`), drops
  the segmented picker (only one tab per window), keeps the header /
  multi-select chrome / timing row.

The embedded-in-main versions at `SequencerView.swift:68-77` and the
inspector at `:82-86` stay; they just branch on the SceneStorage flag
to show "Pane is in its own window. Dock here?" instead of the live
content when detached.

### Risks

- **MTKView identity across scene moves.** The Metal-backed previews
  each own an `MTKView`. When a scene moves between physical displays
  (internal → external), the view's `CAMetalLayer` underlying drawable
  changes; the render bridge must survive that. Worth a device test —
  this is a known weak spot.
- **Timer ownership.** The view model's playback timer is shared.
  Pausing playback when the main window goes to the background
  (Stage Manager) must still let preview windows continue drawing
  frames at the last-rendered position.
- **Keyboard shortcuts in secondary scenes.** `.commands` on a
  `WindowGroup` attaches to every window in that group. Secondary
  scene groups inherit only their own commands. We may need a shared
  `CommandMenu` applied to every scene — verify per-scene routing on
  device before declaring F-1 done.

---

## F-2. Size-class responsive layout

Current layout assumes full-screen on ≥11" iPad. Adapt
`SequencerView` with `@Environment(\.horizontalSizeClass)`:

- **Compact** (Slide Over, portrait 11" split) — inspector collapses
  into a bottom sheet (existing `ToolbarInspectorButton` toggles the
  sheet instead of the 280 pt sidebar); previews collapse to a single
  toggleable inline strip; detach actions hidden (Stage Manager is
  the escape hatch).
- **Regular, single display** — current layout, plus the
  per-inspector-tab "Open in new window" menu item.
- **Regular wide (12.9"+)** — F-3 side-by-side docked previews by
  default.

Use `ViewThatFits` where it reads cleanly; otherwise branch on size
class in a computed property.

---

## F-3. Docked layout

- On ≥1200 pt horizontal: two preview panes side-by-side at the top
  of the sequencer (current behaviour, already in
  `SequencerView.swift:68-77`). Persist the split via `@SceneStorage`.
- On 1024–1200 pt (11" iPad): one preview docked (House default),
  other offered in detached window via the View menu / pane toolbar.
  Segmented picker in the preview chrome lets the user swap which
  one is docked.
- On <1024 pt (compact): single toggleable preview strip, matches
  F-2 compact rules.

---

## F-5. Persistence

Once F-1 lands, add `@SceneStorage` at each scene root:

- `SequencerScene` — open sequence path (already persisted via folder
  bookmarks + lastView), which previews are docked vs detached, which
  inspector tabs are detached, inspector visibility, preview
  visibility, inspector width.
- Each detached scene — 2D/3D mode, camera (pan/zoom), viewpoint name
  shown, layout group.

Current `@AppStorage` keys stay where they are
(`previewPaneHeight`, `inspectorTab`, `DMXExpandedGroup`,
`mediaPicker.collapsedGroups`); those are app-global, not per-window.

Scene restoration needs verification that: opening a recent sequence
from the sequence picker still honours the stored scene layout; cold
launching with no recent sequence starts clean.

---

## F-7. Desktop panels deferred to post-MVP

The desktop View menu has more panels than Phases B–F cover. None
block MVP; documented here so reviewers / future milestones can find
them:

- **Effect Dropper** — subsumed into the bottom effect palette strip.
- **Value Curves** panel — the Phase C editor covers the modal case.
- **Color Dropper** — eyedrop a colour from any preview into the
  palette.
- **Effect Assist** — effect-specific helper panel (varies per
  effect; not all effects define one).
- **Select / Search / Find Effect Data** — three search UIs over
  effects in the sequence. B97 covers the Find case.
- **Video Preview** — plays the sequence's media track aligned to
  the playhead. Useful for sequences authored against reference
  video.
- **Jukebox** — quick-jump buttons to timing marks.

Post-MVP milestone "Panel parity" takes a pass at these in priority
order once F is stable.

---

## Summary

| Item | Scope | Effort | Ships |
|---|---|---|---|
| F-6 | Display Elements modal + view CRUD bridge | ~1 week | First |
| F-4 | `.commands` menu bar + shortcut cleanup | ~3 days | Second |
| F-1 | Scene-level split, detach previews + inspector | ~1 week | Third |
| F-5 | `@SceneStorage` across scene roots | ~2 days | With F-1 |
| F-2 | Size-class adaptive layout | ~3 days | Fourth |
| F-3 | Docked layout on 11" vs 12.9"+ | ~2 days | With F-2 |
| F-7 | Desktop-panel parity — deferred | — | Post-MVP |

**F-6 + F-4 alone (~2 weeks) clear the last blockers on the
single-window authoring experience.** F-1 onwards is multi-window
polish and can slip into Phase G or beyond without blocking the App
Store submission path.
