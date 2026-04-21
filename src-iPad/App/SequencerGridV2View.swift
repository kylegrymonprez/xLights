import SwiftUI
import UniformTypeIdentifiers

/// Dynamic UTType for `.xtiming` timing-track files. Declared here
/// (not in Info.plist) because the import / export UI needs a
/// content type but the iPad doesn't yet own the file type. Falls
/// back to `.xml` so the system picker never no-ops.
let kXTimingFileType: UTType = UTType(filenameExtension: "xtiming") ?? .xml

/// File document wrapper for the Save / Export timing-track flow.
/// Holds the bytes already-written to a temp path so SwiftUI's
/// `.fileExporter` can copy them to the user's destination.
struct XTimingExportDoc: FileDocument {
    static var readableContentTypes: [UTType] { [kXTimingFileType] }
    static var writableContentTypes: [UTType] { [kXTimingFileType] }
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

/// Six-region effects grid shell with synchronized scrolling. Placeholder
/// content in each cell — the drawing (effects, timing marks, icons,
/// transitions) comes in Phase B-3. This view exists to prove sticky-top
/// and sticky-left behavior holds up on device before we invest in the
/// per-pixel drawing.
///
/// Layout:
///
///   row 1: View/time corner | ruler + waveform  (v-locked)
///   row 2: timing headers   | timing effects    (v-locked)
///   row 3: model headers    | model effects     (both axes)
///
/// Horizontal scroll shared across row-2 and row-3 right cells via
/// `TimelineState.hScrollOffsetPx`. Vertical scroll shared across row-3
/// left and right cells via `RowsScrollState.vScrollOffsetPx`.
struct SequencerGridV2View: View {
    @Environment(SequencerViewModel.self) var viewModel
    // Timeline state is owned by the parent (SequencerView) so toolbar
    // zoom controls and pinch-to-zoom here share the same state.
    let timeline: TimelineState
    @State private var metrics = GridMetrics.standard
    @State private var rowsScroll = RowsScrollState()
    @State private var timingScroll = RowsScrollState()
    @State private var contextMenuTarget: ContextMenuTarget?
    // Tracks which sequence duration we've already auto-fit to, so we
    // only zoom-to-fit once per sequence load.
    @State private var fitDurationMS: Int = -1

    private struct ContextMenuTarget: Identifiable {
        let rowIndex: Int
        let effectIndex: Int
        var id: String { "\(rowIndex)-\(effectIndex)" }
    }

    /// B67 / B69 timing-mark long-press target. `markIndex == nil`
    /// means "empty space at `ms`" (→ Add Mark Here menu); non-nil
    /// points to an existing mark (→ Delete Mark menu).
    private struct TimingMarkMenuTarget: Identifiable {
        let rowIndex: Int
        let markIndex: Int?
        let ms: Int
        var id: String { "\(rowIndex)-\(markIndex ?? -1)-\(ms)" }
    }
    @State private var timingMarkMenuTarget: TimingMarkMenuTarget?

    /// B73 add-timing-track alert state.
    @State private var showAddTimingTrackAlert: Bool = false
    @State private var newTimingTrackName: String = ""

    /// B70 rename-timing-mark alert state.
    @State private var renameMarkTarget: TimingMarkMenuTarget?
    @State private var renameMarkText: String = ""

    /// B32 loop-region context-menu trigger. Set non-nil when the
    /// user long-presses inside the existing loop band; cleared
    /// when the confirmation dialog dismisses.
    @State private var loopMenuPresented: Bool = false
    /// B41 waveform filter-picker trigger.
    @State private var waveformMenuPresented: Bool = false

    /// B74 import-xtiming file-picker trigger.
    @State private var showingXTimingImporter: Bool = false
    /// B78 import-lyrics sheet state.
    @State private var importLyricsTargetRow: Int? = nil
    @State private var importLyricsText: String = ""
    @State private var importLyricsStart: String = "0.000"
    @State private var importLyricsEnd: String = ""
    /// B89 auto-label sheet state.
    @State private var autoLabelTargetRow: Int? = nil
    @State private var autoLabelStart: String = "1"
    @State private var autoLabelEnd: String = "100"
    @State private var autoLabelOverwrite: Bool = false
    /// B75 export-xtiming state. Target row is captured when the
    /// menu fires; the bridge writes to a temp path which the
    /// fileExporter then copies to the user's chosen destination.
    @State private var xtimingExportDoc: XTimingExportDoc? = nil
    @State private var showingXTimingExporter: Bool = false
    @State private var xtimingDefaultName: String = "Timing.xtiming"

    /// B21 edit-timing dialog state. Fields are bound to seconds
    /// strings so users enter `5.25` and see `0.75` for duration;
    /// commit parses with `strtod`.
    @State private var editTimingTarget: ContextMenuTarget?
    @State private var editTimingStartText: String = ""
    @State private var editTimingEndText: String = ""

    var body: some View {
        GeometryReader { geo in
            // Partition rows into timing band (row 2) vs model band (row 3).
            // Uses the bridge's explicit timing-row index list.
            let timingIdxSet: Set<Int> = Set(
                (viewModel.document.timingRowIndices() as [NSNumber]).map { $0.intValue }
            )
            let timingRows = viewModel.rows.filter { timingIdxSet.contains($0.id) }
            let modelRows = viewModel.rows.filter { !timingIdxSet.contains($0.id) }

            let durationMS = viewModel.sequenceDurationMS
            let availableGridH = max(geo.size.height - metrics.topChromeHeight, 1)
            let rawTimingH = CGFloat(timingRows.count) * metrics.timingRowHeight
            // Cap timing band at ~1/3 of available grid height.
            let timingBandH = min(rawTimingH, availableGridH / 3)
            let selectedRowId = viewModel.selectedEffect?.rowIndex
            let modelAreaH = modelRows.reduce(CGFloat(0)) { sum, r in
                sum + ((r.id == selectedRowId) ? metrics.selectedRowHeight : metrics.rowHeight)
            }

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    // Row 1: view-picker corner + ruler/waveform strip.
                    HStack(alignment: .top, spacing: 0) {
                        topLeftCorner(availableWidth: geo.size.width)
                            .frame(width: metrics.rowHeaderWidth,
                                   height: metrics.topChromeHeight)
                        Divider()
                        TopChromeMetalGridView(
                            durationMS: durationMS,
                            pixelsPerMS: timeline.pixelsPerMS,
                            rulerHeight: metrics.rulerHeight,
                            waveformHeight: metrics.waveformHeight,
                            hasAudio: viewModel.hasAudio,
                            peaks: viewModel.hasAudio ? viewModel.waveformPeaks : [],
                            scrollOffsetX: Binding(
                                get: { timeline.hScrollOffsetPx },
                                set: { timeline.hScrollOffsetPx = $0 }),
                            onSeek: { ms in viewModel.seekTo(ms: ms) },
                            onPinchZoom: pinchZoomAction,
                            onUserInteraction: { timeline.noteUserInteraction() },
                            loopStartMS: viewModel.loopStartMS,
                            loopEndMS: viewModel.loopEndMS,
                            hasLoop: viewModel.hasLoopRegion,
                            onSetLoop: { start, end in
                                viewModel.setLoopRegion(startMS: start, endMS: end)
                            },
                            onLoopMenu: { _ in loopMenuPresented = true },
                            onWaveformMenu: { waveformMenuPresented = true }
                        )
                        .frame(height: metrics.topChromeHeight)
                    }
                    .frame(height: metrics.topChromeHeight)
                    Divider()

                    // Row 2: timing headers on the left (SwiftUI row
                    // labels in a scroll view for vertical sync), Metal
                    // canvas on the right. Only rendered when the
                    // current view has timing tracks.
                    if !timingRows.isEmpty {
                        let timingContentH = CGFloat(timingRows.count) * metrics.timingRowHeight
                        HStack(alignment: .top, spacing: 0) {
                            SyncedScrollView(
                                targetHOffset: nil,
                                targetVOffset: timingScroll.vScrollOffsetPx,
                                contentWidth: metrics.rowHeaderWidth,
                                contentHeight: timingContentH,
                                showsIndicators: false,
                                onScroll: { newOffset in
                                    timingScroll.vScrollOffsetPx = newOffset.y
                                }
                            ) {
                                timingHeaders(timingRows)
                            }
                            .frame(width: metrics.rowHeaderWidth,
                                   height: timingBandH)
                            Divider()
                            TimingEffectsMetalGridView(
                                rows: timingRows,
                                rowHeight: metrics.timingRowHeight,
                                pixelsPerMS: timeline.pixelsPerMS,
                                scrollOffsetX: Binding(
                                    get: { timeline.hScrollOffsetPx },
                                    set: { timeline.hScrollOffsetPx = $0 }),
                                scrollOffsetY: Binding(
                                    get: { timingScroll.vScrollOffsetPx },
                                    set: { timingScroll.vScrollOffsetPx = $0 }),
                                onSeek: { ms in viewModel.seekTo(ms: ms) },
                                onPinchZoom: pinchZoomAction,
                                onUserInteraction: { timeline.noteUserInteraction() },
                                onLongPressMark: { rowId, markIdx, ms in
                                    timingMarkMenuTarget = TimingMarkMenuTarget(
                                        rowIndex: rowId, markIndex: markIdx, ms: ms)
                                },
                                onMarkDragEnd: { rowId, markIdx, newStart, newEnd in
                                    _ = viewModel.moveTimingMark(
                                        rowIndex: rowId, markIndex: markIdx,
                                        newStartMS: newStart, newEndMS: newEnd)
                                }
                            )
                            .frame(height: timingBandH)
                        }
                        .frame(height: timingBandH)
                        Divider()
                    }

                    // Row 3 — fills remaining space
                    HStack(alignment: .top, spacing: 0) {
                        SyncedScrollView(
                            targetHOffset: nil,
                            targetVOffset: rowsScroll.vScrollOffsetPx,
                            contentWidth: metrics.rowHeaderWidth,
                            contentHeight: modelAreaH,
                            showsIndicators: false,
                            onScroll: { newOffset in
                                rowsScroll.vScrollOffsetPx = newOffset.y
                            }
                        ) {
                            modelHeaders(modelRows)
                        }
                        .frame(width: metrics.rowHeaderWidth)
                        Divider()
                        modelEffectsMetalView(modelRows: modelRows)
                    }
                }

                // Full-height play-position marker spanning ruler, waveform,
                // timing band, and effect grid. Only this subview reads
                // playPositionMS, so the main grid body no longer re-renders
                // (and canvases don't re-draw) on every playback tick.
                PlayPositionMarker(
                    timeline: timeline,
                    rowHeaderWidth: metrics.rowHeaderWidth,
                    gridWidth: geo.size.width,
                    gridHeight: geo.size.height
                )
                .allowsHitTesting(false)

                // B93: jump-scroll to keep the play marker visible during
                // playback. Isolated in its own view so the onChange that
                // fires on every playback tick only invalidates this
                // zero-sized placeholder, not the main grid body.
                AutoFollowPlayhead(
                    timeline: timeline,
                    availableContentWidth: max(0, geo.size.width - metrics.rowHeaderWidth)
                )
            }
            .onAppear {
                fitIfNeeded(durationMS: durationMS, availableWidth: geo.size.width)
                viewModel.refreshWaveformForZoom(pixelsPerMS: timeline.pixelsPerMS)
            }
            .onChange(of: durationMS) { _, newDuration in
                fitIfNeeded(durationMS: newDuration, availableWidth: geo.size.width)
            }
            .onChange(of: geo.size.width) { _, newWidth in
                // If the view is laid out after the sequence loaded with
                // zero width, retry the fit once a real width is known.
                if fitDurationMS != durationMS {
                    fitIfNeeded(durationMS: durationMS, availableWidth: newWidth)
                }
            }
            .onChange(of: timeline.pixelsPerMS) { _, newPPMS in
                viewModel.refreshWaveformForZoom(pixelsPerMS: newPPMS)
            }
            .onChange(of: viewModel.selectedEffect) { _, sel in
                scrollSelectionIntoView(
                    sel,
                    viewportWidth: geo.size.width - metrics.rowHeaderWidth,
                    availableGridH: availableGridH,
                    modelRows: modelRows,
                    timingBandH: timingBandH)
            }
        }
        .confirmationDialog(
            "Effect",
            isPresented: Binding(
                get: { contextMenuTarget != nil },
                set: { if !$0 { contextMenuTarget = nil } }
            ),
            presenting: contextMenuTarget
        ) { target in
            if viewModel.selectedEffects.count > 1 {
                // Multi-select bulk menu.
                let n = viewModel.selectedEffects.count
                Button("Align Start Times") {
                    viewModel.alignSelectedEffects(.startTimes)
                }
                Button("Align End Times") {
                    viewModel.alignSelectedEffects(.endTimes)
                }
                Button("Align Both Times") {
                    viewModel.alignSelectedEffects(.bothTimes)
                }
                Button("Align Centers") {
                    viewModel.alignSelectedEffects(.centerPoints)
                }
                Button("Match Duration") {
                    viewModel.alignSelectedEffects(.matchDuration)
                }
                Button("Shift-Align Start") {
                    viewModel.alignSelectedEffects(.startTimesShift)
                }
                Button("Shift-Align End") {
                    viewModel.alignSelectedEffects(.endTimesShift)
                }
                Button("Align to Closest Timing Mark") {
                    viewModel.alignSelectedEffectsToTimingMarks()
                }
                if viewModel.canCloseGapInSelection {
                    Button("Close Gap") {
                        viewModel.closeGapInSelectedEffects()
                    }
                }
                Button("Delete \(n) Effects", role: .destructive) {
                    viewModel.deleteSelectedEffects()
                }
                Button("Lock / Unlock \(n) Effects") {
                    viewModel.toggleLockSelectedEffects()
                }
                Button("Disable / Enable \(n) Effects") {
                    viewModel.toggleDisableSelectedEffects()
                }
                Button("Deselect All") {
                    viewModel.clearSelection()
                }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("Copy") { viewModel.copySelectedEffect() }
                if viewModel.hasClipboard {
                    Button("Paste Here") {
                        let startMS = (viewModel.rows[target.rowIndex].effects[target.effectIndex]).startTimeMS
                        viewModel.pasteEffect(rowIndex: target.rowIndex, startMS: startMS)
                    }
                }
                if viewModel.canSplitSelectedAtPlayMarker {
                    Button("Split at Play Marker") {
                        viewModel.splitSelectedEffectAtPlayMarker()
                    }
                }
                Button("Edit Timing…") {
                    let e = viewModel.rows[target.rowIndex].effects[target.effectIndex]
                    editTimingStartText = Self.formatMS(e.startTimeMS)
                    editTimingEndText = Self.formatMS(e.endTimeMS)
                    editTimingTarget = target
                }
                Button("Select All in Row") {
                    viewModel.selectAllEffectsInRow(rowIndex: target.rowIndex)
                }
                Button("Select All in Model") {
                    viewModel.selectAllEffectsInModel(rowIndex: target.rowIndex)
                }
                Button("Select All in Column") {
                    let e = viewModel.rows[target.rowIndex].effects[target.effectIndex]
                    viewModel.selectAllEffectsInColumn(spanStartMS: e.startTimeMS,
                                                       spanEndMS: e.endTimeMS)
                }
                Button(viewModel.isEffectLocked(rowIndex: target.rowIndex,
                                                 effectIndex: target.effectIndex)
                       ? "Unlock" : "Lock") {
                    viewModel.toggleLock(rowIndex: target.rowIndex,
                                         effectIndex: target.effectIndex)
                }
                Button(viewModel.isEffectRenderDisabled(rowIndex: target.rowIndex,
                                                        effectIndex: target.effectIndex)
                       ? "Enable" : "Disable") {
                    viewModel.toggleDisable(rowIndex: target.rowIndex,
                                            effectIndex: target.effectIndex)
                }
                Button("Delete", role: .destructive) {
                    viewModel.deleteEffect(rowIndex: target.rowIndex,
                                           effectIndex: target.effectIndex)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        // B67 / B69 timing-mark long-press menu. Distinct dialog from
        // the effect context menu so both can coexist without menu
        // content cross-contamination.
        .confirmationDialog(
            "Timing",
            isPresented: Binding(
                get: { timingMarkMenuTarget != nil },
                set: { if !$0 { timingMarkMenuTarget = nil } }
            ),
            presenting: timingMarkMenuTarget
        ) { target in
            if let markIdx = target.markIndex {
                Button("Rename Mark") {
                    let current = viewModel.rows[target.rowIndex].effects[markIdx].name
                    renameMarkText = current
                    renameMarkTarget = target
                }
                if viewModel.canSplitMarkAtPlayMarker(rowIndex: target.rowIndex,
                                                      markIndex: markIdx) {
                    Button("Split at Play Marker") {
                        _ = viewModel.splitTimingMark(rowIndex: target.rowIndex,
                                                       markIndex: markIdx,
                                                       atMS: viewModel.playPositionMS)
                    }
                }
                if viewModel.canMergeMarkWithNext(rowIndex: target.rowIndex,
                                                   markIndex: markIdx) {
                    Button("Merge with Next") {
                        _ = viewModel.mergeTimingMarkWithNext(rowIndex: target.rowIndex,
                                                               markIndex: markIdx)
                    }
                }
                Button("Delete Mark", role: .destructive) {
                    _ = viewModel.deleteTimingMark(rowIndex: target.rowIndex,
                                                    markIndex: markIdx)
                }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("Add Mark Here") {
                    addTimingMarkFromTap(rowIndex: target.rowIndex, atMS: target.ms)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        // B73 add-timing-track alert. A simple text-field prompt
        // sufficient for the initial cut; NewTimingDialog's fixed /
        // lyric / variable choice can land later.
        .alert("Add Timing Track",
               isPresented: $showAddTimingTrackAlert) {
            TextField("Name", text: $newTimingTrackName)
            Button("Add") {
                _ = viewModel.addTimingTrack(name: newTimingTrackName)
                newTimingTrackName = ""
            }
            Button("Cancel", role: .cancel) {
                newTimingTrackName = ""
            }
        } message: {
            Text("Name for the new variable timing track.")
        }
        // B21 edit-timing alert. Two fields (start, end) in seconds
        // with 3 decimal places; parses with `strtod` per repo rule
        // (no throwing std::stod). Calls `moveEffect` on commit.
        .alert("Edit Timing",
               isPresented: Binding(
                get: { editTimingTarget != nil },
                set: { if !$0 { editTimingTarget = nil } }
               ),
               presenting: editTimingTarget) { target in
            TextField("Start (seconds)", text: $editTimingStartText)
                .keyboardType(.decimalPad)
            TextField("End (seconds)", text: $editTimingEndText)
                .keyboardType(.decimalPad)
            Button("OK") {
                if let startMS = Self.parseSeconds(editTimingStartText),
                   let endMS = Self.parseSeconds(editTimingEndText),
                   endMS > startMS {
                    viewModel.moveEffect(rowIndex: target.rowIndex,
                                          effectIndex: target.effectIndex,
                                          newStartMS: startMS, newEndMS: endMS)
                }
                editTimingTarget = nil
            }
            Button("Cancel", role: .cancel) {
                editTimingTarget = nil
            }
        } message: { _ in
            Text("Enter start and end times in seconds.")
        }
        // B89 auto-label-marks alert.
        .alert("Auto-Label Marks",
               isPresented: Binding(
                get: { autoLabelTargetRow != nil },
                set: { if !$0 { autoLabelTargetRow = nil } }
               ),
               presenting: autoLabelTargetRow) { rowIdx in
            TextField("Start number", text: $autoLabelStart)
                .keyboardType(.numberPad)
            TextField("End number (wraps)", text: $autoLabelEnd)
                .keyboardType(.numberPad)
            Toggle("Overwrite existing labels", isOn: $autoLabelOverwrite)
            Button("Label") {
                let start = Int(autoLabelStart) ?? 1
                let end = Int(autoLabelEnd) ?? start
                _ = viewModel.autoLabelTimingMarks(
                    rowIndex: rowIdx, startNum: start, endNum: end,
                    overwrite: autoLabelOverwrite)
                autoLabelTargetRow = nil
            }
            Button("Cancel", role: .cancel) {
                autoLabelTargetRow = nil
            }
        } message: { _ in
            Text("Number the marks starting at Start; the count wraps back when it passes End. With Overwrite off, only unlabeled marks get numbers.")
        }
        // B78 import-lyrics sheet.
        .sheet(isPresented: Binding(
            get: { importLyricsTargetRow != nil },
            set: { if !$0 { importLyricsTargetRow = nil } }
        )) {
            if let rowIdx = importLyricsTargetRow {
                ImportLyricsSheet(
                    rowIndex: rowIdx,
                    text: $importLyricsText,
                    startText: $importLyricsStart,
                    endText: $importLyricsEnd,
                    onCommit: { start, end in
                        let startMS = Int((Double(start) ?? 0.0) * 1000)
                        let endMS = Int((Double(end) ?? 0.0) * 1000)
                        _ = viewModel.importLyrics(
                            rowIndex: rowIdx,
                            lyrics: importLyricsText,
                            startMS: startMS, endMS: endMS)
                        importLyricsTargetRow = nil
                    },
                    onCancel: { importLyricsTargetRow = nil }
                )
            }
        }
        // B74 .xtiming import.
        .fileImporter(
            isPresented: $showingXTimingImporter,
            allowedContentTypes: [kXTimingFileType],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let path = url.path
            _ = XLSequenceDocument.obtainAccess(toPath: path,
                                                  enforceWritable: false)
            _ = viewModel.importXTiming(path: path)
        }
        // B75 .xtiming export.
        .fileExporter(
            isPresented: $showingXTimingExporter,
            document: xtimingExportDoc,
            contentType: kXTimingFileType,
            defaultFilename: xtimingDefaultName
        ) { _ in
            // Nothing more to do — bridge already wrote the temp
            // file; the exporter copied it to the user's pick.
            xtimingExportDoc = nil
        }
        // B41 waveform filter picker.
        .confirmationDialog(
            "Waveform",
            isPresented: $waveformMenuPresented
        ) {
            ForEach(SequencerViewModel.WaveformFilter.allCases, id: \.rawValue) { filter in
                Button {
                    viewModel.waveformFilter = filter
                } label: {
                    if viewModel.waveformFilter == filter {
                        Label(filter.displayName, systemImage: "checkmark")
                    } else {
                        Text(filter.displayName)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        // B32 loop-region context menu (long-press inside the loop
        // band). Actions: toggle Play Loop (B33), Render Loop Region
        // (B44), Clear Loop.
        .confirmationDialog(
            "Loop Region",
            isPresented: $loopMenuPresented
        ) {
            Button(viewModel.loopPlayEnabled ? "Stop Play Loop" : "Play Loop Region") {
                if !viewModel.isPlaying {
                    viewModel.loopPlayEnabled = true
                    viewModel.seekTo(ms: viewModel.loopStartMS)
                    viewModel.play()
                } else {
                    viewModel.toggleLoopPlay()
                }
            }
            Button("Render Loop Region") {
                viewModel.renderLoopRegion()
            }
            Button("Clear Loop", role: .destructive) {
                viewModel.clearLoopRegion()
            }
            Button("Cancel", role: .cancel) {}
        }
        // B70 rename-timing-mark alert.
        .alert("Rename Mark",
               isPresented: Binding(
                get: { renameMarkTarget != nil },
                set: { if !$0 { renameMarkTarget = nil } }
               ),
               presenting: renameMarkTarget) { target in
            TextField("Label", text: $renameMarkText)
            Button("OK") {
                if let markIdx = target.markIndex {
                    _ = viewModel.renameTimingMark(rowIndex: target.rowIndex,
                                                    markIndex: markIdx,
                                                    label: renameMarkText)
                }
                renameMarkText = ""
                renameMarkTarget = nil
            }
            Button("Cancel", role: .cancel) {
                renameMarkText = ""
                renameMarkTarget = nil
            }
        } message: { _ in
            Text("Timing-mark label (leave blank to clear).")
        }
    }

    /// B21 time formatting / parsing helpers. `formatMS` emits
    /// `5.250` for 5250 ms (3 decimal places, trimmed trailing
    /// zero-run if none are needed — actually keep them for
    /// consistent alignment). `parseSeconds` goes the other way
    /// using strtod (the repo avoids std::stod / std::stoi because
    /// they throw on bad input).
    static func formatMS(_ ms: Int) -> String {
        return String(format: "%.3f", Double(ms) / 1000.0)
    }

    static func parseSeconds(_ s: String) -> Int? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var endPtr: UnsafeMutablePointer<CChar>? = nil
        let val = trimmed.withCString { cStr -> Double in
            strtod(cStr, &endPtr)
        }
        // Reject if strtod didn't consume anything meaningful.
        if endPtr == nil { return nil }
        if val < 0 || !val.isFinite { return nil }
        return Int((val * 1000.0).rounded())
    }

    /// B75: write the timing track to a temp `.xtiming` file and
    /// hand that path off to SwiftUI's `.fileExporter` so the user
    /// picks a destination. The exporter then copies the bytes.
    private func startXTimingExport(rowIndex: Int, trackName: String) {
        let safeName = trackName.isEmpty ? "Timing" : trackName
        let tempDir = FileManager.default.temporaryDirectory
        let tempPath = tempDir.appendingPathComponent("\(safeName)-\(UUID().uuidString).xtiming").path
        guard viewModel.exportTimingTrack(rowIndex: rowIndex, path: tempPath) else {
            return
        }
        xtimingExportDoc = XTimingExportDoc(sourcePath: tempPath)
        xtimingDefaultName = "\(safeName).xtiming"
        showingXTimingExporter = true
    }

    /// B67: default add-mark duration is 500 ms, clamped against the
    /// next existing mark on that row (min 100 ms) and the sequence
    /// end. Start = tap time (clamped >= previous mark's end).
    private func addTimingMarkFromTap(rowIndex: Int, atMS: Int) {
        guard rowIndex >= 0, rowIndex < viewModel.rows.count else { return }
        let row = viewModel.rows[rowIndex]
        var startMS = atMS
        var endMS = atMS + 500
        var prevEnd = 0
        var nextStart = viewModel.sequenceDurationMS
        for e in row.effects {
            if e.endTimeMS <= startMS { prevEnd = max(prevEnd, e.endTimeMS) }
            if e.startTimeMS >= startMS && e.startTimeMS < nextStart {
                nextStart = e.startTimeMS
            }
        }
        startMS = max(prevEnd, startMS)
        endMS = min(endMS, nextStart)
        if endMS <= startMS + 50 {
            // Collapsed window — fall back to 100 ms minimum or skip.
            endMS = startMS + 100
            if endMS > nextStart || endMS > viewModel.sequenceDurationMS {
                return
            }
        }
        _ = viewModel.addTimingMark(rowIndex: rowIndex,
                                     startMS: startMS, endMS: endMS)
    }

    // MARK: - Row 1: view/time corner + top chrome

    private func topLeftCorner(availableWidth: CGFloat) -> some View {
        let views = (viewModel.document.availableViews() as [String])
        let currentIdx = Int(viewModel.document.currentViewIndex())
        let currentName = (currentIdx >= 0 && currentIdx < views.count)
            ? views[currentIdx]
            : "Master View"
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("View:").font(.caption).foregroundStyle(.secondary)
                Menu {
                    ForEach(Array(views.enumerated()), id: \.offset) { idx, name in
                        Button {
                            viewModel.document.setCurrentViewIndex(Int32(idx))
                            viewModel.reloadRows()
                        } label: {
                            if idx == currentIdx {
                                Label(name, systemImage: "checkmark")
                            } else {
                                Text(name)
                            }
                        }
                    }
                    // B73 entry-point lives here (rather than only on
                    // timing-row headers) so users with zero timing
                    // tracks still have a path to add one.
                    Divider()
                    Button {
                        newTimingTrackName = ""
                        showAddTimingTrackAlert = true
                    } label: {
                        Label("Add Timing Track…", systemImage: "plus.rectangle")
                    }
                    Button {
                        showingXTimingImporter = true
                    } label: {
                        Label("Import Timing Track…",
                               systemImage: "square.and.arrow.down")
                    }
                    // B37: re-fit the whole sequence into the viewport.
                    Divider()
                    Button {
                        zoomToFitSequence(availableWidth: availableWidth)
                    } label: {
                        Label("Zoom to Fit", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    // B36: fit the current selection (single or multi).
                    if viewModel.selectedEffect != nil
                        || !viewModel.selectedEffects.isEmpty {
                        Button {
                            zoomToSelection(availableWidth: availableWidth)
                        } label: {
                            Label("Zoom to Selection", systemImage: "arrow.up.backward.and.arrow.down.forward")
                        }
                    }
                    // B57: global collapse / expand.
                    Divider()
                    Button {
                        viewModel.collapseAllModels()
                    } label: {
                        Label("Collapse All", systemImage: "chevron.up.chevron.down")
                    }
                    Button {
                        viewModel.expandAllElements()
                    } label: {
                        Label("Expand All", systemImage: "arrow.up.and.down")
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(currentName)
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            TimeDisplayLabel()
                .font(.system(.caption, design: .monospaced))
            SelectionReadout()
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(white: 0.12))
    }

    /// Shared pinch-to-zoom handler used by all three canvases so zoom
    /// steps and anchor behavior match everywhere.
    private var pinchZoomAction: (CGFloat, CGFloat) -> Void {
        { scaleDelta, anchorX in
            let oldPPMS = timeline.pixelsPerMS
            let newPPMS = min(max(oldPPMS * scaleDelta, 0.005), 2.0)
            if abs(newPPMS - oldPPMS) < 1e-6 { return }
            let anchorMS = oldPPMS > 0 ? anchorX / oldPPMS : 0
            let newAnchorX = anchorMS * newPPMS
            timeline.pixelsPerMS = newPPMS
            timeline.hScrollOffsetPx += (newAnchorX - anchorX)
        }
    }

    /// Ensure the newly-selected effect is visible: adjust horizontal
    /// scroll so the effect's x-range sits inside the viewport, and
    /// vertical scroll so its row is on-screen. Runs on any selection
    /// change — clicked effects already hit the viewport, but arrow-
    /// key navigation can land on off-screen effects.
    private func scrollSelectionIntoView(
        _ sel: SequencerViewModel.EffectSelection?,
        viewportWidth: CGFloat,
        availableGridH: CGFloat,
        modelRows: [SequencerViewModel.RowInfo],
        timingBandH: CGFloat
    ) {
        guard let sel = sel, viewportWidth > 0 else { return }
        // Horizontal: center the effect in the viewport if it's
        // fully off-screen; otherwise nudge the closest edge into
        // view with a bit of padding.
        let x1 = CGFloat(sel.startTimeMS) * timeline.pixelsPerMS
        let x2 = CGFloat(sel.endTimeMS)   * timeline.pixelsPerMS
        let curOffset = timeline.hScrollOffsetPx
        let pad: CGFloat = 24
        if x2 < curOffset + pad {
            timeline.hScrollOffsetPx = max(0, x1 - pad)
        } else if x1 > curOffset + viewportWidth - pad {
            timeline.hScrollOffsetPx = max(0, x2 - viewportWidth + pad)
        }

        // Vertical: only applies to the model-rows scroll area.
        guard let rowIdx = modelRows.firstIndex(where: { $0.id == sel.rowIndex })
        else { return }
        var rowTop: CGFloat = 0
        for i in 0..<rowIdx {
            rowTop += (modelRows[i].id == sel.rowIndex)
                ? metrics.selectedRowHeight : metrics.rowHeight
        }
        let rowH = metrics.selectedRowHeight
        let visibleH = max(0, availableGridH - timingBandH)
        let curV = rowsScroll.vScrollOffsetPx
        if rowTop < curV + pad {
            rowsScroll.vScrollOffsetPx = max(0, rowTop - pad)
        } else if rowTop + rowH > curV + visibleH - pad {
            rowsScroll.vScrollOffsetPx = max(0, rowTop + rowH - visibleH + pad)
        }
    }

    /// Zoom out so the full sequence duration fits inside the available
    /// horizontal content width. Runs once per sequence load (tracked by
    /// `fitDurationMS`) so later user zoom isn't clobbered.
    private func fitIfNeeded(durationMS: Int, availableWidth: CGFloat) {
        guard durationMS > 0 else { return }
        let contentAvail = availableWidth - metrics.rowHeaderWidth
        guard contentAvail > 1 else { return }
        if fitDurationMS == durationMS { return }
        let ppms = contentAvail / CGFloat(durationMS)
        timeline.pixelsPerMS = min(max(ppms, 0.005), 2.0)
        timeline.hScrollOffsetPx = 0
        fitDurationMS = durationMS
    }

    /// B37: unconditional zoom-to-fit (ignores the load-once guard on
    /// `fitDurationMS`). Wired to the View-picker menu entry.
    private func zoomToFitSequence(availableWidth: CGFloat) {
        let durationMS = viewModel.sequenceDurationMS
        guard durationMS > 0 else { return }
        let contentAvail = availableWidth - metrics.rowHeaderWidth
        guard contentAvail > 1 else { return }
        let ppms = contentAvail / CGFloat(durationMS)
        timeline.pixelsPerMS = min(max(ppms, 0.005), 2.0)
        timeline.hScrollOffsetPx = 0
    }

    /// B36: zoom so the selected effect's range (or the union of all
    /// selected effects' ranges) fills the horizontal viewport with
    /// small margins on each side. No-op when nothing is selected or
    /// when the resulting range would clamp against the zoom limits.
    private func zoomToSelection(availableWidth: CGFloat) {
        var minStart = Int.max
        var maxEnd = Int.min
        if let single = viewModel.selectedEffect {
            minStart = single.startTimeMS
            maxEnd = single.endTimeMS
        } else {
            for sel in viewModel.selectedEffects {
                minStart = min(minStart, sel.startTimeMS)
                maxEnd = max(maxEnd, sel.endTimeMS)
            }
        }
        guard minStart < maxEnd else { return }
        let contentAvail = availableWidth - metrics.rowHeaderWidth
        guard contentAvail > 1 else { return }
        let rangeMS = maxEnd - minStart
        // Reserve ~15% margin total (7.5% each side) so selection
        // doesn't kiss the edges.
        let margin: CGFloat = 0.15
        let targetPx = contentAvail * (1 - margin)
        let ppms = targetPx / CGFloat(rangeMS)
        timeline.pixelsPerMS = min(max(ppms, 0.005), 2.0)
        let selCenterMS = CGFloat(minStart + rangeMS / 2)
        let viewCenterPx = contentAvail / 2
        timeline.hScrollOffsetPx = max(0,
            selCenterMS * timeline.pixelsPerMS - viewCenterPx)
    }

    // MARK: - Row 2: timing band

    private func timingHeaders(_ rows: [SequencerViewModel.RowInfo]) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                TimingRowHeader(
                    row: row,
                    height: metrics.timingRowHeight,
                    document: viewModel.document,
                    onRowsChanged: { viewModel.reloadRows() },
                    canBreakdownPhrases: viewModel.canBreakdownPhrases(rowIndex: row.id),
                    onBreakdownPhrases: {
                        _ = viewModel.breakdownPhrases(rowIndex: row.id)
                    },
                    canRemoveWordsAndPhonemes: viewModel.canRemoveWordsAndPhonemes(rowIndex: row.id),
                    onRemoveWordsAndPhonemes: {
                        _ = viewModel.removeWordsAndPhonemes(rowIndex: row.id)
                    },
                    canMakeVariable: viewModel.timingTrackIsFixed(rowIndex: row.id),
                    onMakeVariable: {
                        _ = viewModel.makeTimingTrackVariable(rowIndex: row.id)
                    },
                    onSubdivide: { raw in
                        if let mode = SequencerViewModel.SubdivisionMode(rawValue: raw) {
                            _ = viewModel.generateSubdividedTimingTrack(
                                sourceRowIndex: row.id, mode: mode)
                        }
                    },
                    canSubdivide: row.layerIndex == 0 && !row.effects.isEmpty,
                    onExportTimingTrack: {
                        startXTimingExport(rowIndex: row.id,
                                             trackName: row.timing?.elementName ?? row.displayName)
                    },
                    onImportLyrics: {
                        importLyricsTargetRow = row.id
                        importLyricsText = ""
                        importLyricsStart = "0.000"
                        let endSec = Double(viewModel.sequenceDurationMS) / 1000.0
                        importLyricsEnd = String(format: "%.3f", endSec)
                    },
                    onAutoLabelMarks: {
                        autoLabelTargetRow = row.id
                        autoLabelStart = "1"
                        autoLabelEnd = "\(max(1, row.effects.count))"
                        autoLabelOverwrite = false
                    }
                )
            }
        }
    }

    // MARK: - Row 3: model area

    private func modelHeaders(_ rows: [SequencerViewModel.RowInfo]) -> some View {
        let selectedRowId = viewModel.selectedEffect?.rowIndex
        return VStack(spacing: 0) {
            ForEach(rows) { row in
                let h: CGFloat = (row.id == selectedRowId)
                    ? metrics.selectedRowHeight : metrics.rowHeight
                ModelRowHeader(
                    row: row,
                    height: h,
                    document: viewModel.document,
                    onSelect: { viewModel.selectPreviewModel(rowIndex: row.id) },
                    onRowsChanged: { viewModel.reloadRows() },
                    onSelectAllEffects: {
                        viewModel.selectAllEffectsInRow(rowIndex: row.id)
                    },
                    onSelectAllEffectsInModel: {
                        viewModel.selectAllEffectsInModel(rowIndex: row.id)
                    },
                    onRenameLayer: { newName in
                        _ = viewModel.renameLayer(rowIndex: row.id, name: newName)
                    },
                    effectCountOnRow: row.effects.count,
                    onDeleteAllEffectsOnRow: {
                        _ = viewModel.deleteAllEffectsOnRow(rowIndex: row.id)
                    },
                    elementRenderDisabled: viewModel.isElementRenderDisabled(rowIndex: row.id),
                    onToggleRenderDisabled: {
                        viewModel.toggleElementRenderDisabled(rowIndex: row.id)
                    },
                    onCopyRow: { viewModel.copyRow(rowIndex: row.id) },
                    onCutRow: { viewModel.cutRow(rowIndex: row.id) },
                    onCopyModel: { viewModel.copyModel(rowIndex: row.id) },
                    onCutModel: { viewModel.cutModel(rowIndex: row.id) }
                )
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Interactive Metal grid for the model-effect column. Builds
    /// the same `EffectCanvasActions` + `EffectStateLookup` the CG
    /// path constructs so the action semantics stay identical.
    private func modelEffectsMetalView(
        modelRows: [SequencerViewModel.RowInfo]
    ) -> some View {
        var actions = EffectCanvasActions()
        actions.onTapEffect = { rowIdx, effIdx in
            viewModel.selectEffect(rowIndex: rowIdx, effectIndex: effIdx)
        }
        actions.onTapEmpty = { rowIdx, ms in
            if let row = rowIdx, let atMS = ms,
               viewModel.selectedPaletteEffect != nil {
                viewModel.addEffectFromPaletteTap(rowIndex: row, atMS: atMS)
            } else {
                viewModel.clearSelection()
            }
        }
        actions.onMoveEffect = { rowIdx, effIdx, newStart, newEnd in
            viewModel.moveEffect(rowIndex: rowIdx, effectIndex: effIdx,
                                 newStartMS: newStart, newEndMS: newEnd)
        }
        actions.onMoveEffectToRow = { srcRow, effIdx, dstRow, newStart, newEnd in
            viewModel.moveEffectToRow(srcRowIndex: srcRow, effectIndex: effIdx,
                                       dstRowIndex: dstRow,
                                       newStartMS: newStart, newEndMS: newEnd)
        }
        actions.onResizeEdge = { rowIdx, effIdx, edge, newMS in
            viewModel.resizeEffectEdge(rowIndex: rowIdx, effectIndex: effIdx,
                                       edge: edge, newMS: newMS)
        }
        actions.onAdjustFade = { rowIdx, effIdx, edge, seconds in
            viewModel.adjustFade(rowIndex: rowIdx, effectIndex: effIdx,
                                 fadeInSec:  edge == 0 ? seconds : -1,
                                 fadeOutSec: edge == 1 ? seconds : -1)
        }
        actions.onActiveDragChanged = { snapshot in
            viewModel.activeDrag = snapshot
        }
        actions.onPinchZoom = pinchZoomAction
        actions.onRequestContextMenu = { rowIdx, effIdx, _ in
            contextMenuTarget = ContextMenuTarget(rowIndex: rowIdx, effectIndex: effIdx)
        }
        var stateLookup = EffectStateLookup()
        stateLookup.isLocked = { [document = viewModel.document] rowIdx, effIdx in
            document.effectIsLocked(inRow: Int32(rowIdx), at: Int32(effIdx))
        }
        stateLookup.isDisabled = { [document = viewModel.document] rowIdx, effIdx in
            document.effectIsRenderDisabled(inRow: Int32(rowIdx), at: Int32(effIdx))
        }
        return EffectsMetalGridView(
            rows: modelRows,
            metrics: metrics,
            pixelsPerMS: timeline.pixelsPerMS,
            selection: viewModel.selectedEffect,
            selectedEffects: viewModel.selectedEffects,
            activeDrag: viewModel.activeDrag,
            timingMarkTimesMS: collectActiveTimingMarkTimes(),
            renderedBackgroundsRevision: viewModel.renderedBackgroundsRevision,
            inspectorRevision: viewModel.inspectorRevision,
            scrollOffsetX: Binding(
                get: { timeline.hScrollOffsetPx },
                set: { timeline.hScrollOffsetPx = $0 }),
            scrollOffsetY: Binding(
                get: { rowsScroll.vScrollOffsetPx },
                set: { rowsScroll.vScrollOffsetPx = $0 }),
            actions: actions,
            stateLookup: stateLookup,
            fadeProvider: { [document = viewModel.document] rowIdx, effIdx in
                let fi = document.effectFadeInSeconds(forRow: Int32(rowIdx), at: Int32(effIdx))
                let fo = document.effectFadeOutSeconds(forRow: Int32(rowIdx), at: Int32(effIdx))
                return (fi, fo)
            },
            iconProvider: { [document = viewModel.document] name, bucket in
                var outSize: Int32 = 0
                guard let data = document.iconBGRA(
                    forEffectNamed: name,
                    desiredSize: Int32(bucket),
                    outputSize: &outSize),
                    outSize > 0
                else { return nil }
                return data
            },
            document: viewModel.document,
            onUserInteraction: { timeline.noteUserInteraction() },
            onMarqueeSelect: { hits in viewModel.setMultiSelection(hits) }
        )
    }

    /// Gather all timing-effect start times from timing rows whose
    /// element has `GetActive() == true`. These drive the vertical
    /// guide lines across the model effects canvas.
    private func collectActiveTimingMarkTimes() -> [Int] {
        let timingIdx = (viewModel.document.timingRowIndices() as [NSNumber]).map { $0.intValue }
        var out: [Int] = []
        for idx in timingIdx {
            guard viewModel.document.timingRowIsActive(at: Int32(idx)) else { continue }
            guard let row = viewModel.rows.first(where: { $0.id == idx }) else { continue }
            for e in row.effects {
                out.append(e.startTimeMS)
                out.append(e.endTimeMS)
            }
        }
        return out
    }

}

// MARK: - Subviews whose bodies read high-churn view-model state

/// B31: compact readout for the currently-selected effect. Shows
/// name, time range, duration, and row name when one effect is
/// selected; shows "N effects selected" when multi-selected; blank
/// when idle. Isolated as a subview so its re-renders on selection
/// change stay scoped to this small label.
private struct SelectionReadout: View {
    @Environment(SequencerViewModel.self) var viewModel
    var body: some View {
        if let sel = viewModel.selectedEffect {
            let dur = sel.endTimeMS - sel.startTimeMS
            let rowName = (sel.rowIndex >= 0 && sel.rowIndex < viewModel.rows.count)
                ? viewModel.rows[sel.rowIndex].displayName
                : ""
            Text("\(sel.name) · \(Self.ms(sel.startTimeMS))–\(Self.ms(sel.endTimeMS)) · \(Self.dur(dur)) · \(rowName)")
        } else if viewModel.selectedEffects.count > 1 {
            Text("\(viewModel.selectedEffects.count) effects selected")
        } else {
            // Reserve the line so layout doesn't shift on select/deselect.
            Text(" ").hidden()
        }
    }
    private static func ms(_ m: Int) -> String {
        return String(format: "%d:%02d.%03d",
                      m / 60000, (m / 1000) % 60, m % 1000)
    }
    private static func dur(_ m: Int) -> String {
        let s = Double(m) / 1000.0
        return s >= 10 ? String(format: "%.1fs", s)
                        : String(format: "%.2fs", s)
    }
}

/// Isolated time-display subview so the main grid body doesn't re-evaluate
/// every playback tick. SwiftUI's @Observable tracks reads per-body, so
/// moving `viewModel.playPositionMS` into its own view confines the
/// invalidation to just that label.
private struct TimeDisplayLabel: View {
    @Environment(SequencerViewModel.self) var viewModel
    var body: some View {
        Text(formatTime(viewModel.playPositionMS))
    }
    private func formatTime(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let frac = (ms % 1000) / 10
        return String(format: "%d:%02d.%02d", minutes, seconds, frac)
    }
}

/// Invisible observer that keeps the play marker on-screen during
/// playback (B93). Watches `viewModel.playPositionMS`; when the marker
/// nears the right edge of the viewport, jump-scrolls so the marker
/// sits ~10% from the left (one-viewport desktop parity). Also handles
/// the marker having wandered off the left edge (seek-backwards during
/// playback, or a sequence that wrapped).
///
/// Suppressed for 1.2 s after the user last touched any of the grid
/// canvases so a scroll-during-playback has time to be inspected
/// before the playhead yanks the viewport back. Suppressed outright
/// during effect-scrub (`isScrubbing`) so the scrub loop doesn't
/// reel the viewport around its narrow range.
private struct AutoFollowPlayhead: View {
    @Environment(SequencerViewModel.self) var viewModel
    let timeline: TimelineState
    let availableContentWidth: CGFloat

    private static let suppressionWindow: CFTimeInterval = 1.2
    private static let leftMarginFrac: CGFloat = 0.10

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onChange(of: viewModel.playPositionMS) { _, newMS in
                guard viewModel.isPlaying else { return }
                if viewModel.isScrubbing { return }
                if availableContentWidth <= 1 { return }
                let since = CACurrentMediaTime() - timeline.lastUserInteractionAt
                if since < Self.suppressionWindow { return }

                let worldX = CGFloat(newMS) * timeline.pixelsPerMS
                let cur = timeline.hScrollOffsetPx
                let leftMargin = availableContentWidth * Self.leftMarginFrac
                let rightEdge = cur + availableContentWidth
                // Marker fell off the right: jump so marker is at leftMargin.
                if worldX > rightEdge {
                    timeline.hScrollOffsetPx = max(0, worldX - leftMargin)
                }
                // Marker fell off the left: same — reseat at leftMargin.
                else if worldX < cur {
                    timeline.hScrollOffsetPx = max(0, worldX - leftMargin)
                }
            }
    }
}

/// Full-height vertical line marking the current playback position. Spans
/// ruler + waveform + timing band + effect grid — desktop parity. Only
/// visible when transport is active (play or pause); hidden during pure
/// effect-scrub so the scrub-loop cursor doesn't leak into the main view.
/// Isolated as its own view so position updates don't re-invalidate the
/// surrounding grid canvases.
private struct PlayPositionMarker: View {
    @Environment(SequencerViewModel.self) var viewModel
    let timeline: TimelineState
    let rowHeaderWidth: CGFloat
    let gridWidth: CGFloat
    let gridHeight: CGFloat

    private static let flagHalf: CGFloat = 10
    private static let flagHeight: CGFloat = 10

    var body: some View {
        let active = viewModel.isPlaying || viewModel.isPaused
        let worldX = CGFloat(viewModel.playPositionMS) * timeline.pixelsPerMS
        let visibleX = worldX - timeline.hScrollOffsetPx
        let availableW = gridWidth - rowHeaderWidth
        if active, visibleX >= 0, visibleX <= availableW {
            // Both the line and the triangle are drawn by a single
            // Shape so their x centers align automatically — nothing
            // to offset mismatch. The shape's width is 2*flagHalf;
            // the outer offset places the shape's center exactly on
            // the play line's world position.
            PlayheadShape(flagHalf: Self.flagHalf,
                           flagHeight: Self.flagHeight)
                .fill(Color.red)
                .frame(width: Self.flagHalf * 2, height: gridHeight)
                .offset(x: rowHeaderWidth + visibleX - Self.flagHalf, y: 0)
                .allowsHitTesting(false)
        }
    }
}

/// Single shape that combines the play-head triangle flag at the top
/// and the full-height vertical line, both centered on the shape's
/// midX so there's no sub-pixel offset between them.
private struct PlayheadShape: Shape {
    let flagHalf: CGFloat
    let flagHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        // Triangle flag (apex pointing down).
        p.move(to: CGPoint(x: cx - flagHalf, y: 0))
        p.addLine(to: CGPoint(x: cx + flagHalf, y: 0))
        p.addLine(to: CGPoint(x: cx, y: flagHeight))
        p.closeSubpath()
        // Full-height line.
        p.addRect(CGRect(x: cx - 1, y: 0, width: 2, height: rect.height))
        return p
    }
}

/// B78 lyrics-import sheet. Multi-line text field + start/end
/// seconds. On commit, the parent view dispatches to
/// `SequencerViewModel.importLyrics(rowIndex:lyrics:startMS:endMS:)`.
private struct ImportLyricsSheet: View {
    let rowIndex: Int
    @Binding var text: String
    @Binding var startText: String
    @Binding var endText: String
    let onCommit: (_ startSec: String, _ endSec: String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste lyrics below — one phrase per line. The full time range is divided evenly into phrases. Blank lines are skipped.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 240)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.4)))
                HStack {
                    VStack(alignment: .leading) {
                        Text("Start (seconds)").font(.caption).foregroundStyle(.secondary)
                        TextField("0.000", text: $startText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading) {
                        Text("End (seconds)").font(.caption).foregroundStyle(.secondary)
                        TextField("0.000", text: $endText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .padding()
            .navigationTitle("Import Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { onCommit(startText, endText) }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

