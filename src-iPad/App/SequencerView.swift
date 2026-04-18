import SwiftUI

struct SequencerView: View {
    @Environment(SequencerViewModel.self) var viewModel
    // Shared with SequencerGridV2View so toolbar zoom and in-grid
    // pinch-to-zoom drive the same state.
    @State private var timeline = TimelineState()

    var body: some View {
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
                .frame(height: 350)
                Divider()
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

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.closeSequence() }) {
                Image(systemName: "xmark")
            }

            Divider().frame(height: 24)

            // Playback controls — always shown, works with or without audio
            Button(action: { viewModel.stop() }) {
                Image(systemName: "stop.fill")
            }
            Button(action: { viewModel.togglePlayPause() }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
            }
            .keyboardShortcut(.space, modifiers: [])

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
                    viewModel.deleteSelectedEffect()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(viewModel.selectedEffect == nil)

                Button("Delete Forward") {
                    viewModel.deleteSelectedEffect()
                }
                .keyboardShortcut(.deleteForward, modifiers: [])
                .disabled(viewModel.selectedEffect == nil)

                Button("Copy") { viewModel.copySelectedEffect() }
                    .keyboardShortcut("c", modifiers: [.command])
                    .disabled(viewModel.selectedEffect == nil)

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

