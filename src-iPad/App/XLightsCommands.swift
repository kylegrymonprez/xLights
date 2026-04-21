import SwiftUI

// F-4 — iPadOS 26 menu bar.
//
// Attached to the main `WindowGroup` in `XLightsApp.swift` via
// `.commands { XLSequencerCommands(viewModel: viewModel) }`. Each
// item calls the same code path the pre-F-4 visible / hidden
// toolbar shortcut buttons did, but now surfaces in the hardware-
// keyboard menu bar for discoverability.
//
// Actions that need view-owned state (Save As file exporter,
// Sequence Settings sheet, Close dirty-prompt, Display Elements
// sheet) flip flags / bump tokens on `SequencerViewModel`; the
// owning view observes and performs the actual presentation (see
// `.onChange(of: viewModel.saveAsRequestToken)` et al in
// `SequencerView`).
//
// Zoom commands depend on the timeline state which is view-owned,
// so they read it via `@FocusedValue(\.timeline)` exposed by
// `SequencerView.focusedValue(\.timeline, timeline)`.

struct XLSequencerCommands: Commands {
    let viewModel: SequencerViewModel

    var body: some Commands {
        // File menu — replacing the default "New Item" / "Save Item"
        // groups so our items live where users expect them on iPadOS.
        CommandGroup(replacing: .newItem) { }   // clear "New Window"
        CommandGroup(replacing: .saveItem) {
            Button("Close") {
                viewModel.closeRequestToken &+= 1
            }
            .keyboardShortcut("w", modifiers: [.command])
            .disabled(!viewModel.isSequenceLoaded)

            Divider()

            Button("Save") { _ = viewModel.saveSequence() }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!viewModel.isDirty)

            Button("Save As…") {
                viewModel.saveAsRequestToken &+= 1
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!viewModel.isSequenceLoaded)

            Divider()

            Button("Sequence Settings…") {
                viewModel.showingSequenceSettings = true
            }
            .disabled(!viewModel.isSequenceLoaded)
        }

        // Edit menu — Undo / Redo replace the system defaults;
        // Pasteboard group gets Copy / Paste / Duplicate / Delete
        // (Cut and Find intentionally omitted until B53 / B97 land,
        // since disabled-but-bound shortcuts still swallow key
        // events).
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { viewModel.undo() }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(!viewModel.undoManager.canUndo)

            Button("Redo") { viewModel.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!viewModel.undoManager.canRedo)
        }
        CommandGroup(replacing: .pasteboard) {
            Button("Copy") { viewModel.copySelectedEffect() }
                .keyboardShortcut("c", modifiers: [.command])
                .disabled(viewModel.selectedEffect == nil)

            Button("Paste") {
                let rowIdx = viewModel.selectedEffect?.rowIndex
                    ?? viewModel.rows.firstIndex(where: { $0.timing == nil })
                    ?? 0
                viewModel.pasteEffect(rowIndex: rowIdx,
                                       startMS: viewModel.playPositionMS)
            }
            .keyboardShortcut("v", modifiers: [.command])
            .disabled(!viewModel.hasClipboard)

            Button("Duplicate") { viewModel.duplicateSelectedEffect() }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(viewModel.selectedEffect == nil)

            Divider()

            Button("Delete") { viewModel.deleteSelectedEffects() }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(viewModel.selectedEffect == nil
                           && viewModel.selectedEffects.isEmpty)

            Button("Clear Selection") { viewModel.clearSelection() }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(viewModel.selectedEffect == nil
                           && viewModel.selectedEffects.isEmpty)

            Divider()

            // B4 modified-arrow editing — Shift stretches end, Ctrl
            // fine-nudges start+end (1 ms), Option(Alt) nudges by one
            // frame interval. Duration preserved for the nudges;
            // stretch is end-only. All clamped against the selected
            // effect's neighbours. Mirrors desktop's convention.
            Menu("Nudge Selection") {
                Button("Stretch End Back") {
                    viewModel.stretchSelectedEffectEnd(by: -viewModel.frameIntervalMS)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.shift])
                .disabled(viewModel.selectedEffect == nil)

                Button("Stretch End Forward") {
                    viewModel.stretchSelectedEffectEnd(by: viewModel.frameIntervalMS)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.shift])
                .disabled(viewModel.selectedEffect == nil)

                Divider()

                Button("Nudge Back 1 ms") {
                    viewModel.nudgeSelectedEffect(by: -1)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.control])
                .disabled(viewModel.selectedEffect == nil)

                Button("Nudge Forward 1 ms") {
                    viewModel.nudgeSelectedEffect(by: 1)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.control])
                .disabled(viewModel.selectedEffect == nil)

                Divider()

                Button("Nudge Back One Frame") {
                    viewModel.nudgeSelectedEffect(by: -viewModel.frameIntervalMS)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.option])
                .disabled(viewModel.selectedEffect == nil)

                Button("Nudge Forward One Frame") {
                    viewModel.nudgeSelectedEffect(by: viewModel.frameIntervalMS)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.option])
                .disabled(viewModel.selectedEffect == nil)
            }
            .disabled(viewModel.selectedEffect == nil)
        }

        // View menu — iPadOS 26 provides a default View menu for
        // system items (Enter Full Screen, etc). Using
        // `CommandMenu("View")` creates a duplicate next to it; the
        // correct path is `CommandGroup(after: .sidebar)` which
        // appends our items into the existing menu.
        CommandGroup(after: .sidebar) {
            Button(viewModel.showPreview ? "Hide Preview" : "Show Preview") {
                viewModel.togglePreview()
            }
            .keyboardShortcut("1", modifiers: [.command])
            .disabled(!viewModel.isSequenceLoaded)

            Button(viewModel.showInspector ? "Hide Inspector" : "Show Inspector") {
                viewModel.showInspector.toggle()
            }
            .keyboardShortcut("2", modifiers: [.command])
            .disabled(!viewModel.isSequenceLoaded)

            Divider()

            XLZoomCommands()

            Divider()

            // F-1 — open / dismiss the dedicated House / Model
            // Preview scenes + each of the four inspector tabs.
            // `openWindow` / `dismissWindow` live in Environment
            // and must be read inside a View body, so the actions
            // are funnelled through helper views.
            XLPreviewDetachCommands(viewModel: viewModel)

            Divider()

            XLInspectorDetachCommands(viewModel: viewModel)

            Divider()

            Button("Edit Display Elements…") {
                viewModel.showingDisplayElements = true
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .disabled(!viewModel.isSequenceLoaded)
        }

        // Playback menu.
        CommandMenu("Playback") {
            Button(viewModel.isPlaying ? "Pause" : "Play") {
                viewModel.togglePlayPause()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(!viewModel.isSequenceLoaded)

            Button("Stop") { viewModel.stop() }
                .disabled(!viewModel.isSequenceLoaded)

            Divider()

            Button("Rewind to Start") { viewModel.seekTo(ms: 0) }
                .keyboardShortcut(.home, modifiers: [])
                .disabled(!viewModel.isSequenceLoaded)

            Button("Jump to End") {
                viewModel.seekTo(ms: viewModel.sequenceDurationMS)
            }
            .keyboardShortcut(.end, modifiers: [])
            .disabled(!viewModel.isSequenceLoaded)

            // ⌥← / ⌥→ are claimed by the Edit > Nudge Selection
            // submenu (B4 nudge-by-frame). "Back / Forward 10 Seconds"
            // stay as menu items without shortcuts — the toolbar
            // buttons still provide one-tap access.
            Button("Back 10 Seconds") {
                viewModel.seekTo(ms: max(0, viewModel.playPositionMS - 10_000))
            }
            .disabled(!viewModel.isSequenceLoaded)

            Button("Forward 10 Seconds") {
                viewModel.seekTo(ms: min(viewModel.sequenceDurationMS,
                                          viewModel.playPositionMS + 10_000))
            }
            .disabled(!viewModel.isSequenceLoaded)

            Divider()

            Menu("Speed") {
                // Desktop's 8-option set from
                // xLightsMain.cpp:SetPlaySpeed. Current speed gets a
                // checkmark by rendering with a Label that includes a
                // checkmark image when it matches playSpeed.
                ForEach(XLPlaybackSpeeds.options, id: \.rate) { opt in
                    Button {
                        viewModel.setPlaybackSpeed(opt.rate)
                    } label: {
                        if abs(viewModel.playSpeed - opt.rate) < 0.001 {
                            Label(opt.label, systemImage: "checkmark")
                        } else {
                            Text(opt.label)
                        }
                    }
                }
            }
            .disabled(!viewModel.isSequenceLoaded)

            Divider()

            Button("Previous Frame") {
                viewModel.seekTo(ms: viewModel.playPositionMS
                                      - viewModel.frameIntervalMS)
            }
            .keyboardShortcut(",", modifiers: [])
            .disabled(!viewModel.isSequenceLoaded)

            Button("Next Frame") {
                viewModel.seekTo(ms: viewModel.playPositionMS
                                      + viewModel.frameIntervalMS)
            }
            .keyboardShortcut(".", modifiers: [])
            .disabled(!viewModel.isSequenceLoaded)

            Divider()

            // Arrow-key effect navigation. Disabled when no effect is
            // selected; the same keys are used for "Back/Forward 10
            // seconds" with `.option` so only the modifier-less form
            // is gated on selection.
            Button("Previous Effect") { viewModel.selectPreviousEffect() }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(viewModel.selectedEffect == nil)

            Button("Next Effect") { viewModel.selectNextEffect() }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(viewModel.selectedEffect == nil)

            Button("Effect Above") { viewModel.selectEffectAbove() }
                .keyboardShortcut(.upArrow, modifiers: [])
                .disabled(viewModel.selectedEffect == nil)

            Button("Effect Below") { viewModel.selectEffectBelow() }
                .keyboardShortcut(.downArrow, modifiers: [])
                .disabled(viewModel.selectedEffect == nil)
        }
    }
}

// Desktop's eight Playback menu speed options, mirrored for the
// iPad Playback Speed submenu. Order matches the on-screen order:
// slow speeds ascending, then 1x Full, then fast speeds ascending.
enum XLPlaybackSpeeds {
    struct Option {
        let rate: Float
        let label: String
    }
    static let options: [Option] = [
        Option(rate: 0.25, label: "1/4x"),
        Option(rate: 0.5,  label: "1/2x"),
        Option(rate: 0.75, label: "3/4x"),
        Option(rate: 1.0,  label: "Full Speed"),
        Option(rate: 1.5,  label: "1.5x"),
        Option(rate: 2.0,  label: "2x"),
        Option(rate: 3.0,  label: "3x"),
        Option(rate: 4.0,  label: "4x"),
    ]
}

// Zoom In / Zoom Out need `TimelineState`, which is owned by
// `SequencerView`. `@FocusedValue` only resolves inside a `View`
// body, so the zoom commands live in this helper view injected
// into the View menu.
private struct XLZoomCommands: View {
    @FocusedValue(\.timeline) private var timeline

    var body: some View {
        Button("Zoom Out") {
            if let t = timeline {
                t.pixelsPerMS = max(0.005, t.pixelsPerMS / 1.5)
            }
        }
        .keyboardShortcut("-", modifiers: [.command])
        .disabled(timeline == nil)

        Button("Zoom In") {
            if let t = timeline {
                t.pixelsPerMS = min(2.0, t.pixelsPerMS * 1.5)
            }
        }
        .keyboardShortcut("=", modifiers: [.command])
        .disabled(timeline == nil)
    }
}

// F-1 — menu-bar entries for detaching previews into their own
// Window scenes. `@Environment(\.openWindow)` and `\.dismissWindow`
// resolve only inside a View body, so the commands live here and
// the viewModel is passed in explicitly (Commands can't inject via
// environment on their own).
private struct XLPreviewDetachCommands: View {
    let viewModel: SequencerViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        if viewModel.housePreviewDetached {
            Button("Dock House Preview") {
                dismissWindow(id: "house-preview")
            }
        } else {
            Button("Detach House Preview") {
                viewModel.pendingDetachTokens.insert("house-preview")
                openWindow(id: "house-preview")
            }
            .disabled(!viewModel.isSequenceLoaded)
        }

        if viewModel.modelPreviewDetached {
            Button("Dock Model Preview") {
                dismissWindow(id: "model-preview")
            }
        } else {
            Button("Detach Model Preview") {
                viewModel.pendingDetachTokens.insert("model-preview")
                openWindow(id: "model-preview")
            }
            .disabled(!viewModel.isSequenceLoaded)
        }
    }
}

// F-1c — menu entries to open each inspector tab in its own scene
// window. Each tab has a keyboard shortcut parallel to desktop:
// ⌥⌘E effect, ⌥⌘C colors, ⌥⌘B blending, ⌥⌘U buffer. Already-open
// tabs flip to a "Dock …" entry that dismisses the detached scene.
private struct XLInspectorDetachCommands: View {
    let viewModel: SequencerViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        ForEach(InspectorTab.allCases) { tab in
            if viewModel.detachedInspectorTabs.contains(tab.rawValue) {
                Button("Dock \(tab.label)") {
                    dismissWindow(id: "inspector-tab", value: tab)
                }
            } else {
                Button("Open \(tab.label) in New Window") {
                    viewModel.pendingDetachTokens.insert("inspector-tab:\(tab.rawValue)")
                    openWindow(id: "inspector-tab", value: tab)
                }
                .keyboardShortcut(tab.menuShortcut.key,
                                   modifiers: tab.menuShortcut.modifiers)
                .disabled(!viewModel.isSequenceLoaded)
            }
        }
    }
}

private extension InspectorTab {
    /// ⌥⌘+letter bindings for "Open <tab> in New Window" menu items.
    var menuShortcut: (key: KeyEquivalent, modifiers: EventModifiers) {
        switch self {
        case .effect:   return ("e", [.command, .option])
        case .colors:   return ("c", [.command, .option])
        case .blending: return ("b", [.command, .option])
        case .buffer:   return ("u", [.command, .option])
        }
    }
}
