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

/// F-2 / F-3 — responsive layout classification for the sequencer
/// shell. Derived from `horizontalSizeClass` + measured width so we
/// can distinguish "11" fullscreen or narrow Stage Manager" from
/// "12.9" fullscreen" even though both report `.regular`.
enum PreviewLayoutMode {
    /// Slide Over / very narrow Stage Manager split. Inspector
    /// collapses to a sheet; a single preview is docked at a time
    /// with a swap picker to change it. Detach controls hidden —
    /// Stage Manager is the escape hatch for moving panels out.
    case compact
    /// 11" iPad fullscreen or medium Stage Manager (roughly
    /// 1024-1200 pt wide). Inspector stays as sidebar; one preview
    /// docked with a swap picker; the other can detach via the
    /// View menu.
    case regularNarrow
    /// 12.9"+ fullscreen or wide Stage Manager (≥1200 pt).
    /// Side-by-side House + Model previews above the grid,
    /// matching the desktop layout intent.
    case regularWide
}

/// F-3 — which preview sits in the single-preview slot on the
/// narrow / compact layouts. Persisted as a user preference so the
/// last selection is remembered across launches.
enum DockedPreviewKind: String, CaseIterable {
    case house
    case model
}

struct SequencerView: View {
    @Environment(SequencerViewModel.self) var viewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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

    // F-3 narrow-mode docked-preview selection. @AppStorage until
    // F-5 lifts this to @SceneStorage.
    @AppStorage("dockedPreview") private var dockedPreviewRaw: String = DockedPreviewKind.house.rawValue
    private var dockedPreview: Binding<DockedPreviewKind> {
        Binding(
            get: { DockedPreviewKind(rawValue: dockedPreviewRaw) ?? .house },
            set: { dockedPreviewRaw = $0.rawValue }
        )
    }

    // F-2 / F-3 layout breakpoints. sizeClass `.compact` covers
    // Slide Over and the narrowest Stage Manager splits; inside
    // `.regular`, 1200 pt separates "11" narrow" from "12.9" wide".
    private func layoutMode(for width: CGFloat) -> PreviewLayoutMode {
        if horizontalSizeClass == .compact { return .compact }
        if width < 1200 { return .regularNarrow }
        return .regularWide
    }

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
            let mode = layoutMode(for: geo.size.width)
            VStack(spacing: 0) {
                toolbar
                Divider()

                if viewModel.showPreview {
                    previewBand(mode: mode, effectiveH: effectiveH)
                    previewResizeHandle(cap: cap)
                }

                HStack(spacing: 0) {
                    SequencerGridV2View(timeline: timeline)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // F-2: inspector stays as a 280pt sidebar on
                    // regular widths. In compact mode the sidebar is
                    // dropped and the inspector is presented as a
                    // sheet instead (see the `.sheet(...)` modifier
                    // further down).
                    if mode != .compact, viewModel.showInspector {
                        Divider()
                        EffectSettingsView()
                            .frame(width: 280)
                    }
                }

                EffectPaletteView()
            }
            // F-2 compact inspector — same toggle (viewModel.showInspector),
            // but presented as a sheet instead of inline so the grid keeps
            // its full width.
            .sheet(isPresented: compactInspectorBinding(mode: mode)) {
                EffectSettingsView()
                    .environment(viewModel)
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
        .sheet(isPresented: Bindable(viewModel).showingSequenceSettings) {
            SequenceSettingsSheet()
                .environment(viewModel)
        }
        // F-4 menu routing — one-shot tokens bumped by the
        // WindowGroup's `.commands` block. Save As and Close involve
        // file-exporter / dirty-prompt flows that live here on the
        // view; observing a monotonic counter makes the command
        // invocation idempotent w.r.t. SwiftUI state resets.
        .onChange(of: viewModel.saveAsRequestToken) { _, _ in
            startSaveAs()
        }
        .onChange(of: viewModel.closeRequestToken) { _, _ in
            if viewModel.checkDirtyNow() {
                showingUnsavedPrompt = true
            } else {
                viewModel.closeSequence()
            }
        }
        // F-4: expose the live timeline to menu-bar commands (zoom).
        // `SequencerScene`-level Commands use `@FocusedValue(\.timeline)`.
        .focusedValue(\.timeline, timeline)
    }

    // MARK: - Save As (E-1)

    @State private var showingSaveAsExporter = false
    @State private var saveAsDoc: XLSequenceExportDoc? = nil
    @State private var saveAsDefaultName: String = "Sequence.xsq"
    @State private var saveAsError: String? = nil

    // MARK: - Sequence Settings (E-3)
    //
    // State moved to `SequencerViewModel.showingSequenceSettings` so
    // the F-4 menu command can flip it alongside the gear toolbar
    // button. No local @State here.

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
                .disabled(!viewModel.isDirty)

                Button {
                    startSaveAs()
                } label: {
                    Label("Save As…", systemImage: "square.and.arrow.down.on.square")
                }
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
                viewModel.showingSequenceSettings = true
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
            Button(action: {
                viewModel.seekTo(ms: min(viewModel.sequenceDurationMS,
                                         viewModel.playPositionMS + 10_000))
            }) {
                Image(systemName: "goforward.10")
            }

            // Play position + duration already appear under the
            // view picker (SequencerGridV2View.topLeftCorner). The
            // redundant toolbar copy ate ~170pt of horizontal room
            // and forced the "Show Preview" label into a second line
            // in narrow / portrait layouts, so it's gone now.

            if viewModel.isRendering {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()

            Text(viewModel.sequenceName ?? "")
                .font(.headline)

            Spacer()

            // Undo / Redo — shortcuts live in the F-4 `.commands`
            // block (XLightsCommands.swift); these toolbar buttons
            // are now tap-only.
            Button(action: { viewModel.undo() }) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!viewModel.undoManager.canUndo)

            Button(action: { viewModel.redo() }) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!viewModel.undoManager.canRedo)


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
            // Keyboard shortcuts for zoom live in the F-4 `.commands`
            // block, reading the timeline via `@FocusedValue`.
            HStack(spacing: 4) {
                Button(action: {
                    timeline.pixelsPerMS = max(0.005, timeline.pixelsPerMS / 1.5)
                }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                Button(action: {
                    timeline.pixelsPerMS = min(2.0, timeline.pixelsPerMS * 1.5)
                }) {
                    Image(systemName: "plus.magnifyingglass")
                }
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
        // F-1: iPadOS 26 Stage Manager renders a close/-/fullscreen
        // pill (~75pt wide) at the window's top-left as an overlay —
        // it's NOT reported via safe-area insets. `safeAreaPadding`
        // is a no-op here, so hard-code the clearance. Apps in
        // fullscreen mode will see ~80pt of extra space on the
        // toolbar's leading edge, which reads as normal margin.
        .padding(.leading, 80)
        .background(.bar)
    }

    // MARK: - Preview band (F-2 / F-3)

    /// Builds the preview region. In `regularWide` we stack House
    /// and Model side-by-side (the existing layout). In
    /// `regularNarrow` / `compact` we show one preview at a time
    /// with a segmented picker to swap between them; the hidden
    /// preview can still be opened in its own window via the View
    /// menu (F-4) or by swapping to it first and tapping Detach.
    @ViewBuilder
    private func previewBand(mode: PreviewLayoutMode,
                             effectiveH: Double) -> some View {
        switch mode {
        case .regularWide:
            HStack(spacing: 0) {
                embeddedModelPreview
                    .frame(maxWidth: .infinity)
                Divider()
                embeddedHousePreview
                    .frame(maxWidth: .infinity)
            }
            .frame(height: effectiveH)

        case .regularNarrow, .compact:
            VStack(spacing: 0) {
                HStack {
                    Picker("Preview", selection: dockedPreview) {
                        Text("House").tag(DockedPreviewKind.house)
                        Text("Model").tag(DockedPreviewKind.model)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)

                Group {
                    switch dockedPreview.wrappedValue {
                    case .house: embeddedHousePreview
                    case .model: embeddedModelPreview
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: effectiveH)
        }
    }

    /// F-1 embedded House Preview with detach-on-tap placeholder
    /// swap. Factored so both layout branches reuse it.
    @ViewBuilder
    private var embeddedHousePreview: some View {
        if viewModel.housePreviewDetached {
            HousePreviewDockedPlaceholder()
        } else {
            HousePreviewView(onDetach: {
                viewModel.pendingDetachTokens.insert("house-preview")
                openWindow(id: "house-preview")
            })
        }
    }

    @ViewBuilder
    private var embeddedModelPreview: some View {
        if viewModel.modelPreviewDetached {
            ModelPreviewDockedPlaceholder()
        } else {
            ModelPreviewView(onDetach: {
                viewModel.pendingDetachTokens.insert("model-preview")
                openWindow(id: "model-preview")
            })
        }
    }

    /// F-2 compact inspector binding. Only presents as a sheet when
    /// the sizeClass is compact AND the user has asked for the
    /// inspector (same flag the sidebar branches check). Setting
    /// false dismisses and flips the view-model flag back.
    private func compactInspectorBinding(mode: PreviewLayoutMode) -> Binding<Bool> {
        Binding(
            get: { mode == .compact && viewModel.showInspector },
            set: { newValue in
                if !newValue { viewModel.showInspector = false }
            }
        )
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

