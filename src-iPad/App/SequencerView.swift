import SwiftUI
import UniformTypeIdentifiers

/// Dynamic UTType for `.xsq` files. Declared here (not via
/// UTExportedTypeDeclarations in the Info.plist) because Save-As
/// needs a content type for the file exporter but iPad doesn't
/// yet own the `.xsq` document type — desktop does. `.xml` is
/// the fallback so the file exporter never no-ops.
let kXSQFileType: UTType =
    UTType(filenameExtension: "xsq") ?? .xml

/// `FileDocument` for the Save-As flow. Wraps the on-disk bytes
/// of an already-saved sequence so iOS's `.fileExporter` can
/// copy them to the user-picked destination. The sequence must
/// have been written to `sourcePath` before the exporter
/// presents; for new-but-unsaved sequences the caller saves to
/// the current path first (or falls back to empty XML so the
/// exporter still produces a file).
struct XLSequenceExportDoc: FileDocument {
    static var readableContentTypes: [UTType] { [kXSQFileType] }
    static var writableContentTypes: [UTType] { [kXSQFileType] }

    let sourcePath: String

    init(sourcePath: String) { self.sourcePath = sourcePath }

    init(configuration: ReadConfiguration) throws { sourcePath = "" }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        if !sourcePath.isEmpty,
           let data = try? Data(contentsOf: URL(fileURLWithPath: sourcePath)) {
            return FileWrapper(regularFileWithContents: data)
        }
        return FileWrapper(regularFileWithContents: Data())
    }
}

struct SequencerView: View {
    @Environment(SequencerViewModel.self) var viewModel
    // Shared with SequencerGridV2View so toolbar zoom and in-grid
    // pinch-to-zoom drive the same state.
    @State private var timeline = TimelineState()
    // Persisted preview-pane height. Default of 280 reads well on a
    // 10" iPad; 13" users can drag up to 360-380 pt. Clamp range is
    // intentionally wide — the drag handle constrains it, and we
    // also clamp against the live viewport so the grid never gets
    // squeezed out of view.
    @AppStorage("previewPaneHeight") private var previewPaneHeight: Double = 280
    private static let previewMinHeight: Double = 160
    private static let previewMaxHeight: Double = 800

    var body: some View {
        GeometryReader { geo in
            // Cap the preview at roughly 2/3 of the viewport so the grid
            // + palette always have room even after an over-eager drag.
            // The drag handler also clamps, but honoring the viewport
            // here keeps stored values sensible across device rotations
            // and size classes.
            let cap = max(Self.previewMinHeight,
                          min(Self.previewMaxHeight,
                              geo.size.height * 0.65))
            let effectiveH = min(max(previewPaneHeight,
                                     Self.previewMinHeight), cap)
            VStack(spacing: 0) {
                toolbar
                Divider()

                if viewModel.showPreview {
                    HStack(spacing: 0) {
                        ModelPreviewView()
                            .frame(maxWidth: .infinity)
                        Divider()
                        HousePreviewView()
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: effectiveH)
                    previewResizeHandle(cap: cap)
                }

                HStack(spacing: 0) {
                    SequencerGridV2View(timeline: timeline)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if viewModel.showInspector {
                        Divider()
                        EffectSettingsView()
                            .frame(width: 280)
                    }
                }

                EffectPaletteView()
            }
        }
        .confirmationDialog("Unsaved Changes",
                            isPresented: $showingUnsavedPrompt,
                            titleVisibility: .visible) {
            Button("Save and Close") {
                if viewModel.saveSequence() {
                    viewModel.closeSequence()
                }
            }
            Button("Discard Changes", role: .destructive) {
                viewModel.closeSequence()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This sequence has unsaved changes.")
        }
        .fileExporter(
            isPresented: $showingSaveAsExporter,
            document: saveAsDoc,
            contentType: kXSQFileType,
            defaultFilename: saveAsDefaultName
        ) { result in
            if case .success(let url) = result {
                _ = viewModel.saveSequenceAs(path: url.path)
            }
            saveAsDoc = nil
        }
        .alert("Save-As Failed",
               isPresented: Binding(
                get: { saveAsError != nil },
                set: { if !$0 { saveAsError = nil } }
               )) {
            Button("OK", role: .cancel) { saveAsError = nil }
        } message: {
            Text(saveAsError ?? "")
        }
        .sheet(isPresented: $showingSequenceSettings) {
            SequenceSettingsSheet()
                .environment(viewModel)
        }
    }

    // MARK: - Save As (E-1)

    @State private var showingSaveAsExporter = false
    @State private var saveAsDoc: XLSequenceExportDoc? = nil
    @State private var saveAsDefaultName: String = "Sequence.xsq"
    @State private var saveAsError: String? = nil

    // MARK: - Sequence Settings (E-3)

    @State private var showingSequenceSettings = false

    /// Persist the current in-memory state to the existing path
    /// (so the bytes are up-to-date), then present the system
    /// file exporter. The exporter copies those bytes to the
    /// user-picked URL, and the completion handler updates the
    /// internal sequence path via `saveSequenceAs` so subsequent
    /// saves write to the new location.
    private func startSaveAs() {
        guard viewModel.isSequenceLoaded else {
            saveAsError = "No sequence is open."
            return
        }
        if viewModel.isDirty {
            _ = viewModel.saveSequence()
        }
        let path = viewModel.document.currentSequencePath() ?? ""
        if path.isEmpty {
            saveAsError = "Cannot Save As — the sequence hasn't been saved yet. Use the New wizard to establish a first location."
            return
        }
        saveAsDoc = XLSequenceExportDoc(sourcePath: path)
        // Seed the exporter's default filename from the current
        // basename so the system picker opens on a sensible name.
        let base = (path as NSString).lastPathComponent
        saveAsDefaultName = base.isEmpty ? "Sequence.xsq" : base
        showingSaveAsExporter = true
    }

    /// Draggable divider below the preview pane. Vertical drag
    /// updates the persisted `previewPaneHeight`; the `cap` comes
    /// from the enclosing `GeometryReader` so the handle can never
    /// let the stored value exceed the current viewport.
    private func previewResizeHandle(cap: Double) -> some View {
        PreviewResizeHandle(
            height: Binding(
                get: { previewPaneHeight },
                set: { previewPaneHeight = min(max($0, Self.previewMinHeight), cap) }
            )
        )
    }

    // MARK: - Toolbar

    @State private var showingUnsavedPrompt = false

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: {
                // Prompt if the user has unsaved edits; otherwise
                // close immediately.
                if viewModel.checkDirtyNow() {
                    showingUnsavedPrompt = true
                } else {
                    viewModel.closeSequence()
                }
            }) {
                Image(systemName: "xmark")
            }

            // Save button — enabled when the sequence is dirty.
            // Long-press or the sibling arrow exposes Save As.
            Menu {
                Button {
                    _ = viewModel.saveSequence()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!viewModel.isDirty)

                Button {
                    startSaveAs()
                } label: {
                    Label("Save As…", systemImage: "square.and.arrow.down.on.square")
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!viewModel.isSequenceLoaded)
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "square.and.arrow.down")
                    if viewModel.isDirty {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .offset(x: 3, y: -2)
                    }
                }
            } primaryAction: {
                _ = viewModel.saveSequence()
            }
            .disabled(!viewModel.isSequenceLoaded)

            // Sequence Settings (E-3) — gear icon.
            Button {
                showingSequenceSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .disabled(!viewModel.isSequenceLoaded)

            Divider().frame(height: 24)

            // Playback controls — always shown, works with or without audio.
            // Rewind-to-start / back-10s / play-pause / forward-10s layout
            // mirrors desktop `HousePreviewPanel`'s transport strip.
            Button(action: { viewModel.seekTo(ms: 0) }) {
                Image(systemName: "backward.end.fill")
            }
            Button(action: { viewModel.seekTo(ms: max(0, viewModel.playPositionMS - 10_000)) }) {
                Image(systemName: "gobackward.10")
            }
            Button(action: { viewModel.stop() }) {
                Image(systemName: "stop.fill")
            }
            Button(action: { viewModel.togglePlayPause() }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
            }
            .keyboardShortcut(.space, modifiers: [])
            Button(action: {
                viewModel.seekTo(ms: min(viewModel.sequenceDurationMS,
                                         viewModel.playPositionMS + 10_000))
            }) {
                Image(systemName: "goforward.10")
            }

            Text(formatTime(viewModel.playPositionMS))
                .monospacedDigit()
                .frame(width: 80)
            Text("/").foregroundStyle(.secondary)
            Text(formatTime(viewModel.sequenceDurationMS))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 80)

            if viewModel.isRendering {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()

            Text(viewModel.sequenceName ?? "")
                .font(.headline)

            Spacer()

            // Undo / Redo
            Button(action: { viewModel.undo() }) {
                Image(systemName: "arrow.uturn.backward")
            }
            .keyboardShortcut("z", modifiers: [.command])
            .disabled(!viewModel.undoManager.canUndo)

            Button(action: { viewModel.redo() }) {
                Image(systemName: "arrow.uturn.forward")
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!viewModel.undoManager.canRedo)

            // Hidden buttons that exist purely to publish keyboard
            // shortcuts. SwiftUI requires the shortcut to live on a
            // visible control, but .frame(0) + .opacity(0) keeps them
            // invisible while still reachable by the key event.
            Group {
                Button("Delete") {
                    viewModel.deleteSelectedEffects()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(viewModel.selectedEffect == nil && viewModel.selectedEffects.isEmpty)

                Button("Delete Forward") {
                    viewModel.deleteSelectedEffects()
                }
                .keyboardShortcut(.deleteForward, modifiers: [])
                .disabled(viewModel.selectedEffect == nil && viewModel.selectedEffects.isEmpty)

                Button("Copy") { viewModel.copySelectedEffects() }
                    .keyboardShortcut("c", modifiers: [.command])
                    .disabled(viewModel.selectedEffect == nil
                              && viewModel.selectedEffects.isEmpty)

                Button("Paste") {
                    // Paste onto the selected effect's row at the
                    // current play position; if nothing is selected,
                    // fall back to the first model row. Silently
                    // skipped by the view model if no clipboard.
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

                // Arrow-key navigation: Left/Right cycles within the
                // current row, Up/Down steps between model rows and
                // picks the effect whose time range best overlaps.
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

                // B4 modified-arrow editing — Shift stretches end,
                // Ctrl fine-nudges start+end (1 ms), Option(Alt) nudges
                // by one frame interval. Duration preserved for the
                // nudges; stretch is end-only. All clamped against
                // the selected effect's neighbours.
                Button("Stretch End Forward") {
                    viewModel.stretchSelectedEffectEnd(by: viewModel.frameIntervalMS)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.shift])
                .disabled(viewModel.selectedEffect == nil)
                Button("Stretch End Back") {
                    viewModel.stretchSelectedEffectEnd(by: -viewModel.frameIntervalMS)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.shift])
                .disabled(viewModel.selectedEffect == nil)
                Button("Nudge Forward 1ms") {
                    viewModel.nudgeSelectedEffect(by: 1)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.control])
                .disabled(viewModel.selectedEffect == nil)
                Button("Nudge Back 1ms") {
                    viewModel.nudgeSelectedEffect(by: -1)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.control])
                .disabled(viewModel.selectedEffect == nil)
                Button("Nudge Forward Frame") {
                    viewModel.nudgeSelectedEffect(by: viewModel.frameIntervalMS)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.option])
                .disabled(viewModel.selectedEffect == nil)
                Button("Nudge Back Frame") {
                    viewModel.nudgeSelectedEffect(by: -viewModel.frameIntervalMS)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.option])
                .disabled(viewModel.selectedEffect == nil)

                // Escape cancels the current selection / context, so
                // arrow-key drill-down doesn't strand the user inside
                // a row they can't get out of with the keyboard.
                Button("Clear Selection") { viewModel.clearSelection() }
                    .keyboardShortcut(.escape, modifiers: [])

                // Home / End seek to sequence start / end. Frame-step
                // with ',' and '.' nudges `playPositionMS` by exactly
                // one frame interval — useful for precise scrub
                // without touching the ruler.
                Button("Seek Start") { viewModel.seekTo(ms: 0) }
                    .keyboardShortcut(.home, modifiers: [])
                Button("Seek End") { viewModel.seekTo(ms: viewModel.sequenceDurationMS) }
                    .keyboardShortcut(.end, modifiers: [])
                Button("Frame Back") {
                    viewModel.seekTo(ms: viewModel.playPositionMS - viewModel.frameIntervalMS)
                }
                .keyboardShortcut(",", modifiers: [])
                Button("Frame Forward") {
                    viewModel.seekTo(ms: viewModel.playPositionMS + viewModel.frameIntervalMS)
                }
                .keyboardShortcut(".", modifiers: [])
            }
            .frame(width: 0, height: 0)
            .opacity(0)

            Divider().frame(height: 24)

            // Inspector toggle
            Button(action: { viewModel.showInspector.toggle() }) {
                Image(systemName: "sidebar.trailing")
            }

            Divider().frame(height: 24)

            // Preview toggle
            Button(action: { viewModel.togglePreview() }) {
                Label(
                    viewModel.showPreview ? "Hide Preview" : "Show Preview",
                    systemImage: viewModel.showPreview ? "eye.fill" : "eye"
                )
            }

            Divider().frame(height: 24)

            // Zoom — shares state with pinch-to-zoom on the grid.
            HStack(spacing: 4) {
                Button(action: {
                    timeline.pixelsPerMS = max(0.005, timeline.pixelsPerMS / 1.5)
                }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .keyboardShortcut("-", modifiers: [.command])
                Button(action: {
                    timeline.pixelsPerMS = min(2.0, timeline.pixelsPerMS * 1.5)
                }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .keyboardShortcut("=", modifiers: [.command])
            }

            if viewModel.hasAudio {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { Double(viewModel.volume) },
                    set: { viewModel.setVolume(Int($0)) }
                ), in: 0...100)
                .frame(width: 80)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Helpers

    private func formatTime(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let frac = (ms % 1000) / 10
        return String(format: "%d:%02d.%02d", minutes, seconds, frac)
    }
}

/// Thin draggable divider that sits under the preview pane and
/// resizes it via a vertical drag. Wider hit strip than the visible
/// divider so it's a comfortable touch target; a three-dot grip
/// indicator in the middle makes the affordance visible.
private struct PreviewResizeHandle: View {
    @Binding var height: Double
    @State private var dragStartH: Double? = nil

    var body: some View {
        // Layered as three overlays on a fixed-height rectangle.
        // Earlier this was a ZStack with a VStack + `Spacer()` inside
        // it — the Spacer made the ZStack greedy and the handle blew
        // up to ~1/3 of the screen on first render. Overlays inherit
        // the Color.clear's height, so the handle stays 14pt tall
        // regardless of the siblings' layout priority.
        Color.clear
            .frame(height: 14)
            .overlay(alignment: .top) {
                // Top hairline matches the original fixed Divider.
                Rectangle()
                    .fill(Color(white: 0.25))
                    .frame(height: 0.5)
            }
            .overlay {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.secondary.opacity(0.6))
                            .frame(width: 3, height: 3)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartH == nil { dragStartH = height }
                        if let start = dragStartH {
                            height = start + value.translation.height
                        }
                    }
                    .onEnded { _ in dragStartH = nil }
            )
    }
}

