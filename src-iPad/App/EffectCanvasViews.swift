import SwiftUI
import UIKit

/// A plain UIView whose `draw(_:)` routes to a closure that reads the
/// tile's horizontal offset within the parent canvas. Used as one slice
/// in a manually-tiled canvas: each `CanvasTileView` is sized under
/// Metal's ~16k texture limit, so very wide canvases (e.g. a 5-minute
/// sequence zoomed to 1 px/ms) can be rendered without CATiledLayer's
/// background-thread drawing (which asserted on a CoreAnimation queue
/// for our mix of CG / UIKit-text drawing).
final class CanvasTileView: UIView {
    /// Horizontal offset, in the parent canvas's coordinate space, of
    /// this tile's left edge.
    var tileOriginX: CGFloat = 0
    /// Closure that performs the actual drawing. `worldRect` is the
    /// tile's dirty rect translated into the parent canvas's full
    /// coordinate system — identical to what the original monolithic
    /// canvases used for rect culling.
    var drawContent: (CGContext, CGRect) -> Void = { _, _ in }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        // The parent canvas owns all gestures.
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        // Translate so the drawing code can keep using world-x
        // coordinates — same coord system the monolithic canvases used.
        cg.saveGState()
        cg.translateBy(x: -tileOriginX, y: 0)
        let worldRect = rect.offsetBy(dx: tileOriginX, dy: 0)
        drawContent(cg, worldRect)
        cg.restoreGState()
    }
}

/// Mark every tile whose frame overlaps any of `xRanges` as needing a
/// full redraw. Callers pass world-x ranges; we test each tile's
/// `[tileOriginX, tileOriginX+width]` for intersection. Going full-tile
/// (`setNeedsDisplay()`) rather than sub-rect (`setNeedsDisplay(_:)`)
/// avoids a stale-residue artifact where UIKit's sub-rect dirty
/// tracking combined with our CTM translation in `CanvasTileView.draw`
/// could leave older draw output visible outside the current dirty
/// rect. A single 4096-px tile redraw during drag is still cheap;
/// tiles outside the range aren't touched.
private func invalidateTileRanges(
    _ tiles: [CanvasTileView],
    xRanges: [ClosedRange<CGFloat>]
) {
    guard !tiles.isEmpty, !xRanges.isEmpty else { return }
    for tile in tiles {
        let tileMin = tile.tileOriginX
        let tileMax = tileMin + tile.bounds.width
        for range in xRanges {
            if range.upperBound < tileMin || range.lowerBound > tileMax {
                continue
            }
            tile.setNeedsDisplay()
            break
        }
    }
}

/// Lay out / reuse a set of `CanvasTileView`s as horizontal tiles
/// covering `size.width`, each at most `tileMaxWidth` wide. Called from
/// the parent's `layoutSubviews`.
private func layoutHorizontalTiles(
    in container: UIView,
    tiles: inout [CanvasTileView],
    size: CGSize,
    tileMaxWidth: CGFloat,
    drawClosure: @escaping (CGContext, CGRect) -> Void
) {
    let w = size.width
    let h = size.height
    guard w > 0, h > 0 else {
        for t in tiles { t.removeFromSuperview() }
        tiles.removeAll()
        return
    }
    let tileCount = max(1, Int(ceil(w / tileMaxWidth)))
    while tiles.count < tileCount {
        let t = CanvasTileView()
        container.addSubview(t)
        tiles.append(t)
    }
    while tiles.count > tileCount {
        let t = tiles.removeLast()
        t.removeFromSuperview()
    }
    for (i, t) in tiles.enumerated() {
        let x = CGFloat(i) * tileMaxWidth
        let tw = min(tileMaxWidth, w - x)
        t.tileOriginX = x
        t.drawContent = drawClosure
        t.frame = CGRect(x: x, y: 0, width: tw, height: h)
        t.setNeedsDisplay()
    }
}

/// Callbacks the grid canvas delivers to SwiftUI for user gestures.
/// The canvas is gesture-aware because a single UIView is the simplest
/// place to do precise hit-testing across thousands of effects.
struct EffectCanvasActions {
    var onTapEffect: (_ row: Int, _ effect: Int) -> Void = { _,_ in }
    /// Fires on any tap that didn't land on an effect. When the tap
    /// was inside a model row (but on empty time), `rowIndex` and `ms`
    /// are non-nil so the caller can create an effect there; on an
    /// outside-rows tap both are nil.
    var onTapEmpty: (_ rowIndex: Int?, _ ms: Int?) -> Void = { _,_ in }
    var onMoveEffect: (_ row: Int, _ effect: Int, _ newStartMS: Int, _ newEndMS: Int) -> Void = { _,_,_,_ in }
    /// Move an effect to a *different* row. Fires only when the drag
    /// ended on a row whose id differs from the effect's home row.
    /// Source-row effects shift up to fill the gap, target row shifts
    /// to accommodate.
    var onMoveEffectToRow: (_ srcRow: Int, _ effect: Int, _ dstRow: Int,
                             _ newStartMS: Int, _ newEndMS: Int) -> Void = { _,_,_,_,_ in }
    var onResizeEdge: (_ row: Int, _ effect: Int, _ edge: Int, _ newMS: Int) -> Void = { _,_,_,_ in }
    /// Fires when a fade-in or fade-out drag ends. `edge`: 0 = fade-in,
    /// 1 = fade-out. `seconds` is the new committed fade duration.
    var onAdjustFade: (_ row: Int, _ effect: Int, _ edge: Int, _ seconds: Float) -> Void = { _,_,_,_ in }
    var onPinchZoom: (_ scaleDelta: CGFloat, _ anchorX: CGFloat) -> Void = { _,_ in }
    /// Fires when the user taps the ruler / waveform to set the play
    /// position. `ms` is the time the tap landed on.
    var onSeekToMS: (_ ms: Int) -> Void = { _ in }
    /// Fires when a long-press selects an effect. The canvas converts
    /// the touch location into view-space coordinates so the menu can
    /// anchor near the finger.
    var onRequestContextMenu: (_ row: Int, _ effect: Int, _ anchorInCanvas: CGPoint) -> Void = { _,_,_ in }
}

/// State provider for per-effect lock / disabled look. Keeping this as a
/// struct of closures avoids threading every flag through the view data
/// array when the underlying C++ model is the source of truth.
struct EffectStateLookup {
    var isLocked: (_ row: Int, _ effect: Int) -> Bool = { _,_ in false }
    var isDisabled: (_ row: Int, _ effect: Int) -> Bool = { _,_ in false }
}

/// UIView-backed canvas that draws the model-area effects in a single
/// pass using Core Graphics. This mirrors desktop's
/// `EffectsGrid::DrawEffects` loop (`src-ui-wx/ui/sequencer/EffectsGrid.cpp`):
/// a full repaint each tick is cheaper than managing thousands of
/// SwiftUI views. Per-effect visual spec (brackets + centerline + icon
/// + fade bars) comes from the plan's section 3 "Effect visual spec."
struct ModelEffectsCanvas: UIViewRepresentable {
    let rows: [SequencerViewModel.RowInfo]
    let metrics: GridMetrics
    let pixelsPerMS: CGFloat
    let contentWidth: CGFloat
    let contentHeight: CGFloat
    let timingMarkTimesMS: [Int]
    let selection: SequencerViewModel.EffectSelection?
    /// Bumps whenever an inspector edit writes a setting. Compared
    /// between old and new state in `updateUIView`; a change invalidates
    /// the currently-selected effect's x-range so fade bars etc. redraw
    /// without the effect needing to move / resize / rename.
    let inspectorRevision: Int
    let fadeProvider: (Int, Int) -> (Float, Float) // (row, effectIdx) -> (fadeInSec, fadeOutSec)
    let stateLookup: EffectStateLookup
    let actions: EffectCanvasActions
    let document: XLSequenceDocument

    func makeUIView(context: Context) -> EffectsCanvasUIView {
        let v = EffectsCanvasUIView()
        v.isOpaque = false
        v.backgroundColor = .clear
        v.contentMode = .redraw
        v.installGestures()
        return v
    }

    func updateUIView(_ view: EffectsCanvasUIView, context: Context) {
        let newSize = CGSize(width: contentWidth, height: contentHeight)

        // Changes where the whole canvas layout shifts (row count, row
        // heights, zoom, total size, timing-mark lines) force every tile
        // to redraw. A selection row change also triggers full redraw
        // because the selected row grows (metrics.selectedRowHeight),
        // which shifts the y of every row below it. Anything more
        // localized (rows changed but same structure, selection moved
        // within the same row) is narrowed to a dirty x-range.
        let selRowChanged = view.selection?.rowIndex != selection?.rowIndex
        let fullInvalidate =
            view.metrics != metrics ||
            view.pixelsPerMS != pixelsPerMS ||
            view.totalSize != newSize ||
            view.timingMarkTimesMS != timingMarkTimesMS ||
            !rowStructureMatches(old: view.rows, new: rows) ||
            selRowChanged

        var dirtyRanges: [ClosedRange<CGFloat>] = []
        if !fullInvalidate {
            // Per-effect changes (move / resize / rename / add-without-
            // restructure). Union of old + new x-ranges for each changed
            // slot, widened by a few pixels so brackets aren't clipped.
            dirtyRanges.append(contentsOf: rowEffectDiffRanges(
                old: view.rows, new: rows, pixelsPerMS: pixelsPerMS))

            // Selection moved: redraw old + new selected effect's range.
            if view.selection != selection {
                if let s = view.selection {
                    dirtyRanges.append(selectionRange(s, pixelsPerMS: pixelsPerMS))
                }
                if let s = selection {
                    dirtyRanges.append(selectionRange(s, pixelsPerMS: pixelsPerMS))
                }
            }

            // Inspector setting edit on the selected effect — fade bars,
            // lock/disable glyph state, (eventually) cached background
            // thumbnails, etc. The effect itself didn't move/rename so
            // rowEffectDiffRanges won't pick it up; use the revision
            // bump and the stable selection to know which slot redraws.
            if view.inspectorRevision != inspectorRevision, let s = selection {
                dirtyRanges.append(selectionRange(s, pixelsPerMS: pixelsPerMS))
            }
        }

        let sizeChanged = view.totalSize != newSize
        view.rows = rows
        view.metrics = metrics
        view.pixelsPerMS = pixelsPerMS
        view.totalSize = newSize
        view.timingMarkTimesMS = timingMarkTimesMS
        view.selection = selection
        view.inspectorRevision = inspectorRevision
        view.fadeProvider = fadeProvider
        view.stateLookup = stateLookup
        view.actions = actions
        view.document = document
        if sizeChanged {
            view.frame.size = newSize
            view.invalidateIntrinsicContentSize()
        }
        if fullInvalidate {
            view.setNeedsDisplay()
        } else if !dirtyRanges.isEmpty {
            view.invalidate(xRanges: dirtyRanges)
        }
    }
}

// MARK: - Row diff helpers for localized tile invalidation

/// True when the two row lists share the same row count, row IDs,
/// layer indices, and effect counts per row — i.e. only per-effect
/// fields changed. Any structural difference (row added/removed/moved
/// or an effect added/removed from a row) returns false, which forces
/// a full-canvas invalidate.
private func rowStructureMatches(
    old: [SequencerViewModel.RowInfo],
    new: [SequencerViewModel.RowInfo]
) -> Bool {
    guard old.count == new.count else { return false }
    for (o, n) in zip(old, new) {
        if o.id != n.id || o.layerIndex != n.layerIndex { return false }
        if o.effects.count != n.effects.count { return false }
    }
    return true
}

/// Per-slot diff. Assumes `rowStructureMatches` already returned true.
/// Produces one x-range per slot whose `(startMS, endMS, name)` changed.
/// Each range is the union of the old and new effect extents, widened
/// generously so selection bracket strokes, fade-handle diamonds, lock
/// glyph, and anti-aliased edges are all inside the dirty rect.
private func rowEffectDiffRanges(
    old: [SequencerViewModel.RowInfo],
    new: [SequencerViewModel.RowInfo],
    pixelsPerMS: CGFloat
) -> [ClosedRange<CGFloat>] {
    var out: [ClosedRange<CGFloat>] = []
    for (oRow, nRow) in zip(old, new) {
        for (oE, nE) in zip(oRow.effects, nRow.effects) {
            if oE.startTimeMS == nE.startTimeMS
                && oE.endTimeMS == nE.endTimeMS
                && oE.name == nE.name { continue }
            let startMS = min(oE.startTimeMS, nE.startTimeMS)
            let endMS   = max(oE.endTimeMS,   nE.endTimeMS)
            let x1 = CGFloat(startMS) * pixelsPerMS - 16
            let x2 = CGFloat(endMS) * pixelsPerMS + 16
            if x2 > x1 { out.append(x1...x2) }
        }
    }
    return out
}

private func selectionRange(
    _ sel: SequencerViewModel.EffectSelection,
    pixelsPerMS: CGFloat
) -> ClosedRange<CGFloat> {
    let x1 = CGFloat(sel.startTimeMS) * pixelsPerMS - 16
    let x2 = CGFloat(sel.endTimeMS) * pixelsPerMS + 16
    return x1...x2
}

final class EffectsCanvasUIView: UIView {
    // Maximum per-tile width. Kept well under Metal's ~16k texture limit
    // (logical × contentScale must fit), giving headroom on 3x Retina.
    private static let tileMaxWidth: CGFloat = 4096
    private var tiles: [CanvasTileView] = []

    var rows: [SequencerViewModel.RowInfo] = []
    var metrics: GridMetrics = .standard
    var pixelsPerMS: CGFloat = 0.1
    var totalSize: CGSize = .zero
    var timingMarkTimesMS: [Int] = []
    var selection: SequencerViewModel.EffectSelection?
    var inspectorRevision: Int = 0
    var fadeProvider: (Int, Int) -> (Float, Float) = { _,_ in (0, 0) }
    var stateLookup: EffectStateLookup = EffectStateLookup()
    var actions: EffectCanvasActions = EffectCanvasActions()
    // Set by the Representable during updateUIView. Used when the
    // canvas asks `EffectIconCache` for an effect's bitmap.
    weak var document: XLSequenceDocument?

    // Matches `MINIMUM_EFFECT_WIDTH_FOR_SMALL_RECT` on desktop; below
    // this pixel width we skip the icon and draw only brackets + a
    // centerline dash.
    private let minIconWidth: CGFloat = 14

    /// Draw a small diamond handle centered at `(x, y)` — used to
    /// indicate the current fade-in / fade-out edge on the selected
    /// effect. White outline keeps it readable against any fade color.
    private func drawFadeHandle(cg: CGContext, x: CGFloat, y: CGFloat, fill: UIColor) {
        let r: CGFloat = 3.5
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y - r))
        path.addLine(to: CGPoint(x: x + r, y: y))
        path.addLine(to: CGPoint(x: x, y: y + r))
        path.addLine(to: CGPoint(x: x - r, y: y))
        path.closeSubpath()
        cg.addPath(path)
        cg.setFillColor(fill.withAlphaComponent(0.95).cgColor)
        cg.fillPath()
        cg.addPath(path)
        cg.setStrokeColor(UIColor.white.cgColor)
        cg.setLineWidth(1)
        cg.strokePath()
    }

    /// Per-row heights and cumulative top offsets. The row whose `id`
    /// matches the current selection's row grows to
    /// `metrics.selectedRowHeight` so the edge + fade handles become
    /// finger-friendly; everyone else uses `metrics.rowHeight`.
    private func rowLayout() -> (tops: [CGFloat], heights: [CGFloat]) {
        var tops: [CGFloat] = []
        var heights: [CGFloat] = []
        tops.reserveCapacity(rows.count)
        heights.reserveCapacity(rows.count)
        let selId = selection?.rowIndex
        var y: CGFloat = 0
        for row in rows {
            tops.append(y)
            let h = (row.id == selId) ? metrics.selectedRowHeight : metrics.rowHeight
            heights.append(h)
            y += h
        }
        return (tops, heights)
    }

    /// Fetch the decoded XPM icon for this effect at the appropriate
    /// size bucket for the current display scale. The cache is keyed by
    /// (name, bucket) so zooms that stay inside one bucket reuse.
    private func effectIcon(for name: String,
                            desiredSize: CGFloat,
                            doc: XLSequenceDocument) -> CGImage? {
        let scale = window?.screen.scale ?? UIScreen.main.scale
        let bucket = EffectIconCache.bucket(forDesiredPx: desiredSize * scale)
        return EffectIconCache.shared.image(for: name, bucket: bucket, document: doc)
    }

    // Pan drag state.
    private enum DragKind { case move, resizeLeft, resizeRight, fadeIn, fadeOut }
    private struct DragState {
        let rowIndex: Int
        let effectIndex: Int
        let origStartMS: Int
        let origEndMS: Int
        let origFadeInSec: Float
        let origFadeOutSec: Float
        /// Hard floor for start — either 0 (no left neighbor) or the
        /// previous effect's `endTimeMS` on the same row. Enforced at
        /// every .changed tick so dragging can't plow into an adjacent
        /// effect.
        let minStartMS: Int
        /// Hard ceiling for end — either `Int.max` (no right neighbor)
        /// or the next effect's `startTimeMS` on the same row.
        let maxEndMS: Int
        let kind: DragKind
    }
    private var drag: DragState?
    // Transient overrides so dragged effects render live under the finger.
    private var liveStartMS: Int?
    private var liveEndMS: Int?
    private var liveFadeInSec: Float?
    private var liveFadeOutSec: Float?
    /// `id` of the row the drag is currently hovering over. nil = same
    /// as the drag's origin row (no cross-row move). Set only for
    /// `.move` drags — resizes and fade drags stay in the home row.
    private var liveRowId: Int?
    /// True when the current cross-row drop would overlap an effect
    /// in the target row. The ghost renders in a warning tint and
    /// `.ended` cancels the move rather than committing it.
    private var liveDropInvalid: Bool = false
    // High-water-mark extremes of the drag. Monotonically grow from the
    // drag's origin: if the user drags right to 500 ms then back left,
    // these still remember the 500 ms excursion so we can invalidate
    // every tile the effect has *ever* been rendered at during the
    // current drag — otherwise the right-excursion tiles would keep
    // their stale render after the finger returns.
    private var dragMinMS: Int = 0
    private var dragMaxMS: Int = 0
    // Scroll-suppression: while a canvas drag is active we disable the
    // enclosing UIScrollView's pan so the whole grid doesn't scroll
    // along with our move/resize. Restored on drag end/cancel/fail.
    private weak var suppressedScrollView: UIScrollView?
    // Canvas's own pan recognizer — stored so we can configure the
    // enclosing scroll view to require it to fail before scrolling.
    private weak var ownPanRecognizer: UIPanGestureRecognizer?
    // Auto-scroll: a CADisplayLink-driven offset push that fires while
    // the drag finger is hovering near the viewport edge. Pulling one
    // frame at a time (vs. a one-shot nudge on each .changed call)
    // keeps the grid scrolling continuously even if the user's finger
    // stops moving but stays near the edge.
    private var autoScrollLink: CADisplayLink?
    private var autoScrollSpeedX: CGFloat = 0
    private var autoScrollSpeedY: CGFloat = 0
    private var lastDragLocationInSelf: CGPoint = .zero

    override var intrinsicContentSize: CGSize { totalSize }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutHorizontalTiles(in: self,
                              tiles: &tiles,
                              size: bounds.size,
                              tileMaxWidth: Self.tileMaxWidth) { [weak self] cg, worldRect in
            self?.drawContent(cg: cg, worldRect: worldRect)
        }
    }

    override func setNeedsDisplay() {
        super.setNeedsDisplay()
        for t in tiles { t.setNeedsDisplay() }
    }

    /// Targeted redraw of just the tiles whose frames overlap `xRanges`
    /// (world-x coordinates). Rows span full tile height, so the y-axis
    /// isn't narrowed.
    func invalidate(xRanges: [ClosedRange<CGFloat>]) {
        invalidateTileRanges(tiles, xRanges: xRanges)
    }

    fileprivate func drawContent(cg: CGContext, worldRect rect: CGRect) {
        let (tops, heights) = rowLayout()

        // Row zebra-striping.
        for (i, row) in rows.enumerated() {
            let y = tops[i]
            let h = heights[i]
            cg.setFillColor((row.id % 2 == 0
                             ? UIColor(white: 0.08, alpha: 1)
                             : UIColor(white: 0.10, alpha: 1)).cgColor)
            cg.fill(CGRect(x: rect.minX, y: y, width: rect.width, height: h))
        }

        // Vertical timing lines from active timing rows — draw across
        // the whole content area so they span all model rows.
        if !timingMarkTimesMS.isEmpty {
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.15).cgColor)
            cg.setLineWidth(1)
            for ms in timingMarkTimesMS {
                let x = CGFloat(ms) * pixelsPerMS
                if x < rect.minX - 1 || x > rect.maxX + 1 { continue }
                cg.move(to: CGPoint(x: x + 0.5, y: 0))
                cg.addLine(to: CGPoint(x: x + 0.5, y: totalSize.height))
            }
            cg.strokePath()
        }

        // Effects per row.
        for (i, row) in rows.enumerated() {
            let y = tops[i]
            let h = heights[i]
            let top = y + 1
            let bottom = y + h - 1
            let mid = (top + bottom) / 2

            for (eIdx, effect) in row.effects.enumerated() {
                let isDragged = (drag?.rowIndex == row.id && drag?.effectIndex == eIdx)
                // While a cross-row drag is active, don't draw the
                // dragged effect at its home row — it's rendered
                // below at the target row's y so it follows the
                // finger vertically.
                if isDragged && liveRowId != nil { continue }
                let startMS = isDragged ? (liveStartMS ?? effect.startTimeMS) : effect.startTimeMS
                let endMS   = isDragged ? (liveEndMS   ?? effect.endTimeMS)   : effect.endTimeMS
                let x1 = CGFloat(startMS) * pixelsPerMS
                let x2 = CGFloat(endMS) * pixelsPerMS
                if x2 < rect.minX || x1 > rect.maxX { continue }
                let isSelected = (selection?.rowIndex == row.id && selection?.effectIndex == eIdx)
                drawEffect(cg: cg,
                           x1: x1, x2: x2, top: top, bottom: bottom, mid: mid,
                           effect: effect, isSelected: isSelected,
                           rowIndex: row.id, effectIndex: eIdx)
                if isDragged, let d = drag {
                    drawDragFeedback(cg: cg, x1: x1, x2: x2, top: top,
                                     effect: effect, d: d)
                }
            }
        }

        // Cross-row drag ghost: if the finger is hovering over a
        // different row, render the dragged effect at that row's y
        // position instead. On .ended the bridge commits the move —
        // unless `liveDropInvalid` is set, in which case a red tint
        // overlays the ghost to signal the drop would collide with
        // an existing effect and the move will be silently cancelled.
        if let d = drag,
           d.kind == .move,
           let dstRowId = liveRowId,
           let dstIdx = rows.firstIndex(where: { $0.id == dstRowId }),
           let srcRow = rows.first(where: { $0.id == d.rowIndex }),
           d.effectIndex < srcRow.effects.count {
            let effect = srcRow.effects[d.effectIndex]
            let y = tops[dstIdx]
            let h = heights[dstIdx]
            let top = y + 1
            let bottom = y + h - 1
            let mid = (top + bottom) / 2
            let startMS = liveStartMS ?? effect.startTimeMS
            let endMS   = liveEndMS   ?? effect.endTimeMS
            let x1 = CGFloat(startMS) * pixelsPerMS
            let x2 = CGFloat(endMS) * pixelsPerMS
            if x2 >= rect.minX && x1 <= rect.maxX {
                drawEffect(cg: cg,
                           x1: x1, x2: x2, top: top, bottom: bottom, mid: mid,
                           effect: effect,
                           isSelected: true,
                           rowIndex: d.rowIndex,
                           effectIndex: d.effectIndex)
                if liveDropInvalid {
                    cg.setFillColor(UIColor.systemRed
                        .withAlphaComponent(0.35).cgColor)
                    cg.fill(CGRect(x: x1, y: top,
                                    width: max(1, x2 - x1),
                                    height: bottom - top))
                }
                drawDragFeedback(cg: cg, x1: x1, x2: x2, top: top,
                                 effect: effect, d: d)
            }
        }
    }

    /// Short floating label that shows the value being changed during
    /// a live drag — the new start time for a move/resize-left, the
    /// new end time for resize-right, or the fade duration for fade
    /// drags. Positioned just above the effect rect; draws with a
    /// semi-transparent black pill so it's legible against any
    /// background color the grid is using.
    private func drawDragFeedback(cg: CGContext,
                                   x1: CGFloat, x2: CGFloat, top: CGFloat,
                                   effect: SequencerViewModel.EffectInfo,
                                   d: DragState) {
        let labelText: String
        switch d.kind {
        case .move:
            let s = liveStartMS ?? effect.startTimeMS
            let e = liveEndMS   ?? effect.endTimeMS
            labelText = "\(Self.formatTimeMS(s)) – \(Self.formatTimeMS(e))"
        case .resizeLeft:
            let s = liveStartMS ?? effect.startTimeMS
            let e = liveEndMS   ?? effect.endTimeMS
            labelText = "\(Self.formatTimeMS(s)) (\(Self.formatDurMS(e - s)))"
        case .resizeRight:
            let s = liveStartMS ?? effect.startTimeMS
            let e = liveEndMS   ?? effect.endTimeMS
            labelText = "\(Self.formatTimeMS(e)) (\(Self.formatDurMS(e - s)))"
        case .fadeIn:
            labelText = "fade in: \(Self.formatFade(liveFadeInSec ?? 0))"
        case .fadeOut:
            labelText = "fade out: \(Self.formatFade(liveFadeOutSec ?? 0))"
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.white,
        ]
        let textSize = (labelText as NSString).size(withAttributes: attrs)
        let padX: CGFloat = 5
        let padY: CGFloat = 2
        let w = textSize.width + padX * 2
        let h = textSize.height + padY * 2
        // Prefer placing above the effect; flip below if we'd clip
        // off the top of the canvas.
        let effectCenterX = (x1 + x2) / 2
        let pillX = max(2, min(totalSize.width - w - 2, effectCenterX - w / 2))
        let pillY = top - h - 2 >= 0 ? top - h - 2 : top + 2
        let pillRect = CGRect(x: pillX, y: pillY, width: w, height: h)
        let path = CGPath(roundedRect: pillRect,
                           cornerWidth: 3, cornerHeight: 3, transform: nil)
        cg.addPath(path)
        cg.setFillColor(UIColor.black.withAlphaComponent(0.75).cgColor)
        cg.fillPath()
        (labelText as NSString).draw(
            at: CGPoint(x: pillX + padX, y: pillY + padY),
            withAttributes: attrs)
    }

    /// Format a millisecond timestamp as m:ss.mmm, mirroring the
    /// ruler labels so the user sees consistent time values.
    private static func formatTimeMS(_ ms: Int) -> String {
        let sign = ms < 0 ? "-" : ""
        let m = abs(ms)
        return String(format: "%@%d:%02d.%03d",
                      sign, m / 60000, (m / 1000) % 60, m % 1000)
    }

    private static func formatDurMS(_ ms: Int) -> String {
        let seconds = Double(ms) / 1000.0
        if seconds >= 10 {
            return String(format: "%.1fs", seconds)
        }
        return String(format: "%.2fs", seconds)
    }

    private static func formatFade(_ seconds: Float) -> String {
        return String(format: "%.2fs", seconds)
    }

    private func drawEffect(cg: CGContext,
                            x1: CGFloat, x2: CGFloat,
                            top: CGFloat, bottom: CGFloat, mid: CGFloat,
                            effect: SequencerViewModel.EffectInfo,
                            isSelected: Bool,
                            rowIndex: Int,
                            effectIndex: Int) {
        let width = max(x2 - x1, 1)
        let isLocked = stateLookup.isLocked(rowIndex, effectIndex)
        let isDisabled = stateLookup.isDisabled(rowIndex, effectIndex)
        let strokeColor: UIColor
        if isDisabled {
            strokeColor = UIColor(white: 0.45, alpha: 1)
        } else if isSelected {
            strokeColor = UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 1)
        } else if isLocked {
            strokeColor = UIColor(red: 0.65, green: 0.8, blue: 1.0, alpha: 1)
        } else {
            strokeColor = UIColor(white: 0.85, alpha: 1)
        }

        if isDisabled {
            cg.setFillColor(UIColor(white: 0.15, alpha: 0.65).cgColor)
            cg.fill(CGRect(x: x1, y: top, width: width, height: bottom - top))
        }

        cg.setStrokeColor(strokeColor.cgColor)
        cg.setLineWidth(isSelected ? 2 : 1)

        // Left + right brackets.
        cg.move(to: CGPoint(x: x1 + 0.5, y: top))
        cg.addLine(to: CGPoint(x: x1 + 0.5, y: bottom))
        cg.move(to: CGPoint(x: x2 - 0.5, y: top))
        cg.addLine(to: CGPoint(x: x2 - 0.5, y: bottom))
        cg.strokePath()

        // Icon-or-dash centerline.
        let hasIconRoom = width > minIconWidth
        let iconSize = min(max(bottom - top - 4, 8), 22)
        let iconX = (x1 + x2) / 2
        let iconLeft = iconX - iconSize / 2
        let iconRight = iconX + iconSize / 2

        cg.setStrokeColor(strokeColor.cgColor)
        cg.setLineWidth(1)
        // Precompute where the optional name label will sit so the
        // right-hand centerline stops short of it instead of drawing
        // under the glyphs.
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: strokeColor.withAlphaComponent(0.95),
        ]
        let nameSize = (effect.name as NSString).size(withAttributes: nameAttrs)
        let nameStartX = iconRight + 4
        let nameMaxX = x2 - 3
        let showName = !effect.name.isEmpty
            && width > 70
            && (nameMaxX - nameStartX) > 14
        let nameEndX: CGFloat = showName
            ? min(nameStartX + nameSize.width, nameMaxX)
            : iconRight

        if hasIconRoom {
            cg.move(to: CGPoint(x: x1, y: mid + 0.5))
            cg.addLine(to: CGPoint(x: iconLeft, y: mid + 0.5))
            // Start centerline after the name label (if any) so the
            // stroke doesn't bleed through the text.
            cg.move(to: CGPoint(x: nameEndX + 2, y: mid + 0.5))
            cg.addLine(to: CGPoint(x: x2, y: mid + 0.5))
            cg.strokePath()

            let iconRect = CGRect(x: iconLeft, y: mid - iconSize / 2,
                                  width: iconSize, height: iconSize)
            if let doc = document,
               let cgImage = effectIcon(for: effect.name, desiredSize: iconSize, doc: doc) {
                // Draw the desktop's XPM-derived icon. Flip the CTM so
                // the bitmap isn't upside-down (Core Graphics default Y
                // is bottom-up; our context is top-down).
                cg.saveGState()
                cg.translateBy(x: 0, y: iconRect.maxY)
                cg.scaleBy(x: 1, y: -1)
                let drawRect = CGRect(x: iconRect.origin.x, y: 0,
                                      width: iconRect.width, height: iconRect.height)
                cg.draw(cgImage, in: drawRect)
                cg.restoreGState()
            } else {
                // Fallback for effects that didn't resolve to an icon:
                // a 3-letter abbreviation in the stroke color. Same as
                // what was shipping before the cache wired up.
                let label = String(effect.name.prefix(3)).uppercased()
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: iconSize * 0.55, weight: .semibold),
                    .foregroundColor: strokeColor,
                ]
                let textSize = (label as NSString).size(withAttributes: attrs)
                let textRect = CGRect(x: iconX - textSize.width / 2,
                                      y: mid - textSize.height / 2,
                                      width: textSize.width,
                                      height: textSize.height)
                (label as NSString).draw(in: textRect, withAttributes: attrs)
            }

            // Effect name label, drawn to the right of the icon when
            // there's comfortable room for it. Clips at the right
            // edge; no manual truncation needed.
            if showName {
                let textRect = CGRect(x: nameStartX,
                                       y: mid - nameSize.height / 2,
                                       width: nameMaxX - nameStartX,
                                       height: nameSize.height)
                (effect.name as NSString).draw(in: textRect,
                                                withAttributes: nameAttrs)
            }
        } else {
            // Dash through center.
            cg.move(to: CGPoint(x: x1, y: mid + 0.5))
            cg.addLine(to: CGPoint(x: x2, y: mid + 0.5))
            cg.strokePath()
        }

        // Fade-in/fade-out bars (top edge). During a fade drag, the
        // live overrides take precedence so the bar animates under the
        // finger; for anything else we read from the document via the
        // fadeProvider closure.
        let isDraggedFade = (drag?.rowIndex == rowIndex
                             && drag?.effectIndex == effectIndex
                             && (drag?.kind == .fadeIn || drag?.kind == .fadeOut))
        let resolved = fadeProvider(rowIndex, effectIndex)
        let fadeInSec:  Float = isDraggedFade ? (liveFadeInSec  ?? resolved.0) : resolved.0
        let fadeOutSec: Float = isDraggedFade ? (liveFadeOutSec ?? resolved.1) : resolved.1
        let fadeInPx = CGFloat(fadeInSec) * 1000 * pixelsPerMS
        let fadeOutPx = CGFloat(fadeOutSec) * 1000 * pixelsPerMS
        let barH: CGFloat = 3

        if fadeInPx > 0 || fadeOutPx > 0 {
            let inRect = CGRect(x: x1, y: top, width: min(fadeInPx, width), height: barH)
            let outRect = CGRect(x: max(x1, x2 - fadeOutPx), y: top,
                                 width: min(fadeOutPx, width), height: barH)
            cg.setFillColor(UIColor.systemGreen.withAlphaComponent(0.85).cgColor)
            cg.fill(inRect)
            cg.setFillColor(UIColor.systemRed.withAlphaComponent(0.85).cgColor)
            cg.fill(outRect)
            let overlap = inRect.intersection(outRect)
            if !overlap.isNull && overlap.width > 0 {
                cg.setFillColor(UIColor.systemYellow.withAlphaComponent(0.95).cgColor)
                cg.fill(overlap)
            }
        }

        // Fade handles (diamond glyphs) — only on the selected effect so
        // the user sees a grabbable target that tracks the current fade.
        if isSelected && width > 8 {
            drawFadeHandle(cg: cg,
                           x: x1 + min(fadeInPx, width),
                           y: top + barH / 2,
                           fill: UIColor.systemGreen)
            drawFadeHandle(cg: cg,
                           x: max(x1, x2 - fadeOutPx),
                           y: top + barH / 2,
                           fill: UIColor.systemRed)
        }

        // Lock glyph in the upper-right if the effect is locked.
        if isLocked && width > 10 {
            let glyph = "🔒" as NSString
            let glyphAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
            ]
            glyph.draw(at: CGPoint(x: x2 - 12, y: top), withAttributes: glyphAttrs)
        }
    }

    // MARK: - Gestures

    func installGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = gestureDelegate
        addGestureRecognizer(pan)
        ownPanRecognizer = pan

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        pinch.delegate = gestureDelegate
        addGestureRecognizer(pinch)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
        // Slightly more grace time before long-press wins so users
        // have room to transition from "tap to select" into a drag
        // without accidentally summoning the context menu. The low
        // `allowableMovement` keeps the long-press from hijacking a
        // drag that clearly began moving.
        longPress.minimumPressDuration = 0.6
        longPress.allowableMovement = 4
        longPress.delegate = gestureDelegate
        addGestureRecognizer(longPress)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Scroll-vs-drag fight is resolved via the enable/disable
        // dance on `pan.began` below — no `require(toFail:)` is set
        // here. Earlier attempts to set it at view-attach time proved
        // brittle against the SyncedScrollView's host lifecycle and
        // occasionally left the scroll view's pan stuck waiting.
    }

    @objc private func onLongPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began else { return }
        let p = g.location(in: self)
        guard let hit = hitTestEffect(at: p) else { return }
        // Select first so the context menu's actions operate on the
        // effect the user pressed.
        actions.onTapEffect(hit.rowIndex, hit.effectIndex)
        actions.onRequestContextMenu(hit.rowIndex, hit.effectIndex, p)
    }

    // Allow the outer UIScrollView's pan/pinch to run alongside ours
    // when the hit test lands in an empty area (so pan-to-scroll still
    // works). We suppress scrolling while a drag is active via the
    // canGestureStart filter below.
    private lazy var gestureDelegate: CanvasGestureDelegate = {
        let d = CanvasGestureDelegate()
        d.owner = self
        return d
    }()

    private enum HitZone { case empty, center, leftEdge, rightEdge, fadeIn, fadeOut }
    private struct Hit {
        let rowIndex: Int
        let effectIndex: Int
        let zone: HitZone
    }

    /// Vertical hit-slop for the fade drag zone at the top of a selected
    /// effect. Also controls the visual tap-target — the fade bar itself
    /// is only 3 px tall, but we treat the top ~7 px as grabbable.
    private let fadeHitStripH: CGFloat = 7

    /// Pixel threshold for snapping to nearby active timing marks
    /// during a move or resize drag. Matches desktop feel.
    private let snapThresholdPx: CGFloat = 10

    /// Snap `ms` to any active timing-mark time within
    /// `snapThresholdPx` pixels. Returns `ms` unchanged if no mark is
    /// close enough.
    private func snapToNearestMark(_ ms: Int) -> Int {
        guard !timingMarkTimesMS.isEmpty, pixelsPerMS > 0 else { return ms }
        let thresholdMS = Int(snapThresholdPx / pixelsPerMS)
        var bestMS = ms
        var bestDelta = thresholdMS + 1
        for mark in timingMarkTimesMS {
            let d = abs(mark - ms)
            if d < bestDelta {
                bestDelta = d
                bestMS = mark
            }
        }
        return bestMS
    }

    private func hitTestEffect(at p: CGPoint) -> Hit? {
        let (tops, heights) = rowLayout()
        var rIdxInList = -1
        for i in 0..<rows.count {
            if p.y >= tops[i] && p.y < tops[i] + heights[i] {
                rIdxInList = i
                break
            }
        }
        guard rIdxInList >= 0 else { return nil }
        let row = rows[rIdxInList]
        let ms = Int(p.x / pixelsPerMS)
        let slop = metrics.edgeHandleHitWidth / pixelsPerMS // ms
        let rowTop = tops[rIdxInList]
        let inFadeStrip = (p.y - rowTop) < fadeHitStripH + 1
        for (eIdx, effect) in row.effects.enumerated() {
            if ms < effect.startTimeMS - Int(slop) { break }
            if ms > effect.endTimeMS + Int(slop) { continue }
            let isSelected = (selection?.rowIndex == row.id && selection?.effectIndex == eIdx)

            // Fade zones only exist while selected. They live in the top
            // strip of the effect's rectangle; take priority over edge
            // resize so touching the corner of a selected effect grabs
            // the fade, not the edge.
            if isSelected
                && inFadeStrip
                && ms >= effect.startTimeMS
                && ms <= effect.endTimeMS {
                let midMS = (effect.startTimeMS + effect.endTimeMS) / 2
                return Hit(rowIndex: row.id, effectIndex: eIdx,
                           zone: ms <= midMS ? .fadeIn : .fadeOut)
            }

            if ms >= effect.startTimeMS - Int(slop/2) && ms <= effect.startTimeMS + Int(slop/2) && isSelected {
                return Hit(rowIndex: row.id, effectIndex: eIdx, zone: .leftEdge)
            }
            if ms >= effect.endTimeMS - Int(slop/2) && ms <= effect.endTimeMS + Int(slop/2) && isSelected {
                return Hit(rowIndex: row.id, effectIndex: eIdx, zone: .rightEdge)
            }
            if ms >= effect.startTimeMS && ms <= effect.endTimeMS {
                return Hit(rowIndex: row.id, effectIndex: eIdx, zone: .center)
            }
        }
        return nil
    }

    @objc private func onTap(_ g: UITapGestureRecognizer) {
        let p = g.location(in: self)
        if let hit = hitTestEffect(at: p), hit.zone != .empty {
            actions.onTapEffect(hit.rowIndex, hit.effectIndex)
            return
        }
        // Resolve which model row (if any) the tap landed in so the
        // caller can offer to add an effect there when a palette
        // entry is armed. Timing rows are excluded — palette effects
        // only make sense on model layers.
        let (tops, heights) = rowLayout()
        var rowId: Int? = nil
        for i in 0..<rows.count {
            if p.y >= tops[i] && p.y < tops[i] + heights[i] {
                if rows[i].timing == nil {
                    rowId = rows[i].id
                }
                break
            }
        }
        let ms: Int? = (rowId != nil && pixelsPerMS > 0)
            ? max(0, Int(p.x / pixelsPerMS)) : nil
        actions.onTapEmpty(rowId, ms)
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        switch g.state {
        case .began:
            let p = g.location(in: self)
            guard let hit = hitTestEffect(at: p) else { drag = nil; return }
            guard let row = rows.first(where: { $0.id == hit.rowIndex }),
                  hit.effectIndex < row.effects.count else { return }
            let effect = row.effects[hit.effectIndex]
            let kind: DragKind
            switch hit.zone {
            case .leftEdge:  kind = .resizeLeft
            case .rightEdge: kind = .resizeRight
            case .fadeIn:    kind = .fadeIn
            case .fadeOut:   kind = .fadeOut
            default:         kind = .move
            }
            let (curFadeIn, curFadeOut) = fadeProvider(hit.rowIndex, hit.effectIndex)
            // Neighbor bounds on the same row — effects are stored in
            // start-time order so index-1/index+1 gives the adjacent
            // effects. Used below to clamp live move/resize values so
            // effects can't overlap.
            let prevEnd = hit.effectIndex > 0
                ? row.effects[hit.effectIndex - 1].endTimeMS
                : 0
            let nextStart = hit.effectIndex + 1 < row.effects.count
                ? row.effects[hit.effectIndex + 1].startTimeMS
                : Int.max
            drag = DragState(rowIndex: hit.rowIndex,
                             effectIndex: hit.effectIndex,
                             origStartMS: effect.startTimeMS,
                             origEndMS: effect.endTimeMS,
                             origFadeInSec: curFadeIn,
                             origFadeOutSec: curFadeOut,
                             minStartMS: prevEnd,
                             maxEndMS: nextStart,
                             kind: kind)
            liveStartMS = effect.startTimeMS
            liveEndMS = effect.endTimeMS
            liveFadeInSec = curFadeIn
            liveFadeOutSec = curFadeOut
            dragMinMS = effect.startTimeMS
            dragMaxMS = effect.endTimeMS
            // Prevent the enclosing UIScrollView from panning the whole
            // grid along with the drag. Disabling cancels any in-flight
            // recognition; we re-enable on .ended/.cancelled/.failed.
            if let sv = findEnclosingScrollView() {
                suppressedScrollView = sv
                sv.panGestureRecognizer.isEnabled = false
                sv.panGestureRecognizer.isEnabled = true
                sv.panGestureRecognizer.isEnabled = false
            }
        case .changed:
            guard let d = drag else { return }
            let tx = g.translation(in: self).x
            let dMS = Int(tx / pixelsPerMS)
            let prevStart = liveStartMS ?? d.origStartMS
            let prevEnd   = liveEndMS   ?? d.origEndMS
            switch d.kind {
            case .move:
                // Snap whichever edge is closer to a timing mark; keep
                // duration fixed so the effect slides as a whole.
                let duration = d.origEndMS - d.origStartMS
                // Bounds: when hovering over the source row, use the
                // source-row neighbors captured at drag.began.
                // Otherwise find the target row's own neighbors
                // around the unconstrained tentative position so the
                // effect can't plow into an existing one in the
                // target row either.
                let unclampedStart = d.origStartMS + dMS
                let unclampedEnd = unclampedStart + duration
                var minStart = d.minStartMS
                var maxEnd = d.maxEndMS
                var invalid = false
                if let dstId = liveRowId,
                   let dstRow = rows.first(where: { $0.id == dstId }) {
                    var prevEnd = 0
                    var nextStart = Int.max
                    for e in dstRow.effects {
                        // Does this target-row effect overlap the
                        // unclamped drop range? If so the gap that
                        // contains our drop point doesn't exist.
                        let overlaps = unclampedStart < e.endTimeMS
                            && unclampedEnd > e.startTimeMS
                        if overlaps { invalid = true }
                        if e.endTimeMS <= unclampedStart {
                            prevEnd = max(prevEnd, e.endTimeMS)
                        } else if e.startTimeMS >= unclampedEnd {
                            nextStart = min(nextStart, e.startTimeMS)
                        }
                    }
                    minStart = prevEnd
                    maxEnd = nextStart
                }
                let maxStart = maxEnd == Int.max
                    ? Int.max
                    : maxEnd - duration
                // If duration won't fit in the gap, the drop is
                // invalid — ghost still renders at the unconstrained
                // finger position so the user sees where they were
                // dropping, but with a warning tint.
                if maxStart < minStart { invalid = true }
                liveDropInvalid = invalid
                let clampedStart: Int = invalid
                    ? unclampedStart
                    : max(minStart, min(maxStart, unclampedStart))
                let tentativeStart = clampedStart
                let tentativeEnd = tentativeStart + duration
                let snappedStart = snapToNearestMark(tentativeStart)
                let snappedEnd   = snapToNearestMark(tentativeEnd)
                // Use the effective (source or target) bounds so
                // timing-mark snap doesn't pull the ghost out of a
                // valid target-row gap into an adjacent effect.
                let withinLeft  = snappedStart >= minStart
                let withinRight = snappedEnd   <= maxEnd
                if withinLeft && withinRight
                    && snappedStart != tentativeStart
                    && snappedEnd == tentativeEnd {
                    liveStartMS = snappedStart
                    liveEndMS   = snappedStart + duration
                } else if withinLeft && withinRight
                    && snappedEnd != tentativeEnd
                    && snappedStart == tentativeStart {
                    liveEndMS   = snappedEnd
                    liveStartMS = snappedEnd - duration
                } else if withinLeft && withinRight
                    && snappedStart != tentativeStart
                    && snappedEnd != tentativeEnd {
                    // Both snap — pick whichever is closer.
                    if abs(snappedStart - tentativeStart) <= abs(snappedEnd - tentativeEnd) {
                        liveStartMS = snappedStart
                        liveEndMS   = snappedStart + duration
                    } else {
                        liveEndMS   = snappedEnd
                        liveStartMS = snappedEnd - duration
                    }
                } else {
                    liveStartMS = tentativeStart
                    liveEndMS   = tentativeEnd
                }
            case .resizeLeft:
                // Floor at left neighbor's end (or 0); ceiling is just
                // below the anchored right edge.
                let ns = max(d.minStartMS, d.origStartMS + dMS)
                var snapped = snapToNearestMark(ns)
                if snapped < d.minStartMS { snapped = ns }
                liveStartMS = min(snapped, d.origEndMS - 1)
                liveEndMS = d.origEndMS
            case .resizeRight:
                // Ceiling at right neighbor's start (or Int.max);
                // floor is just above the anchored left edge.
                let raw = d.origEndMS + dMS
                let capped = min(d.maxEndMS, raw)
                var snapped = snapToNearestMark(capped)
                if snapped > d.maxEndMS { snapped = capped }
                liveEndMS = max(snapped, d.origStartMS + 1)
                liveStartMS = d.origStartMS
            case .fadeIn, .fadeOut:
                // Fades: clamp so fadeIn + fadeOut <= effect duration
                // (half each if both pushed to max).
                let durMS = max(1, d.origEndMS - d.origStartMS)
                let otherFade = d.kind == .fadeIn
                    ? d.origFadeOutSec
                    : d.origFadeInSec
                let otherMS = Int(otherFade * 1000)
                let maxMS = max(0, durMS - otherMS)
                let deltaMS = d.kind == .fadeIn ? dMS : -dMS
                let origMS = Int((d.kind == .fadeIn ? d.origFadeInSec : d.origFadeOutSec) * 1000)
                let newMS = max(0, min(maxMS, origMS + deltaMS))
                let newSec = Float(newMS) / 1000.0
                if d.kind == .fadeIn {
                    liveFadeInSec = newSec
                } else {
                    liveFadeOutSec = newSec
                }
            }
            // Auto-scroll: if the finger is near the horizontal edge
            // of the enclosing viewport, push the scroll offset so
            // the dragged effect can be moved past what's currently
            // on-screen. Proximity drives speed; a display link keeps
            // the scroll going even if the finger is held stationary.
            lastDragLocationInSelf = g.location(in: self)
            updateAutoScrollForDrag()

            // Cross-row hover detection: move drags only. If the
            // finger has wandered into a different model row the
            // effect will render as a ghost there until .ended
            // commits or cancels the cross-row move. Resize and fade
            // drags stay anchored to the home row.
            if d.kind == .move {
                let p = g.location(in: self)
                let (tops, heights) = rowLayout()
                var hoverId: Int? = nil
                for i in 0..<rows.count {
                    if p.y >= tops[i] && p.y < tops[i] + heights[i] {
                        hoverId = rows[i].id
                        break
                    }
                }
                // Reject timing rows as drop targets — you can't drop
                // a model-layer effect onto a timing track.
                if let h = hoverId,
                   let r = rows.first(where: { $0.id == h }),
                   r.timing != nil {
                    hoverId = nil
                }
                let newLiveRow = (hoverId == d.rowIndex) ? nil : hoverId
                if newLiveRow != liveRowId {
                    liveRowId = newLiveRow
                    setNeedsDisplay() // full redraw — row layout visual changes
                }
            }

            // Expand the drag's high-water-mark range to include this
            // frame's position. This monotonically grows — so if the
            // user drags right and then back, the right-excursion
            // tiles still get invalidated and their stale draw
            // cleared. Invalidate the entire high-water range each
            // frame, widened with generous slop for selection bracket
            // strokes / fade handles / lock glyph / anti-alias.
            _ = prevStart; _ = prevEnd
            if let ls = liveStartMS { dragMinMS = min(dragMinMS, ls) }
            if let le = liveEndMS   { dragMaxMS = max(dragMaxMS, le) }
            // Wider slop during drag so the floating time/fade
            // feedback label (which can be ~160 px wide and is
            // centered on the effect) doesn't leave trails when the
            // effect itself is narrow.
            let slop: CGFloat = 100
            let x1 = CGFloat(dragMinMS) * pixelsPerMS - slop
            let x2 = CGFloat(dragMaxMS) * pixelsPerMS + slop
            invalidate(xRanges: [x1...x2])
        case .ended, .cancelled, .failed:
            // Always restore the scroll view's pan first so a bail-out
            // below doesn't leave the grid unscrollable.
            suppressedScrollView?.panGestureRecognizer.isEnabled = true
            suppressedScrollView = nil
            guard let d = drag else {
                drag = nil
                stopAutoScroll()
                return
            }
            _ = d
            if let ls = liveStartMS { dragMinMS = min(dragMinMS, ls) }
            if let le = liveEndMS   { dragMaxMS = max(dragMaxMS, le) }
            let endSlop: CGFloat = 100
            let x1 = CGFloat(dragMinMS) * pixelsPerMS - endSlop
            let x2 = CGFloat(dragMaxMS) * pixelsPerMS + endSlop
            switch d.kind {
            case .move:
                if let ls = liveStartMS, let le = liveEndMS {
                    if let dst = liveRowId, dst != d.rowIndex {
                        // Drop was over a different row. Commit only
                        // if the drop would actually fit in the
                        // target row's gap; otherwise cancel silently
                        // — the effect stays in its home row.
                        if !liveDropInvalid {
                            actions.onMoveEffectToRow(d.rowIndex, d.effectIndex,
                                                        dst, ls, le)
                        }
                    } else {
                        actions.onMoveEffect(d.rowIndex, d.effectIndex, ls, le)
                    }
                }
            case .resizeLeft:
                if let ls = liveStartMS {
                    actions.onResizeEdge(d.rowIndex, d.effectIndex, 0, ls)
                }
            case .resizeRight:
                if let le = liveEndMS {
                    actions.onResizeEdge(d.rowIndex, d.effectIndex, 1, le)
                }
            case .fadeIn:
                if let v = liveFadeInSec {
                    actions.onAdjustFade(d.rowIndex, d.effectIndex, 0, v)
                }
            case .fadeOut:
                if let v = liveFadeOutSec {
                    actions.onAdjustFade(d.rowIndex, d.effectIndex, 1, v)
                }
            }
            drag = nil
            liveStartMS = nil
            liveEndMS = nil
            liveFadeInSec = nil
            liveFadeOutSec = nil
            liveRowId = nil
            liveDropInvalid = false
            stopAutoScroll()
            invalidate(xRanges: [x1...x2])
        default:
            break
        }
    }

    /// Walk `superview` chain to find the UIScrollView that wraps this
    /// canvas. Used to suspend its pan during an effect drag.
    private func findEnclosingScrollView() -> UIScrollView? {
        var v: UIView? = superview
        while let cur = v {
            if let sv = cur as? UIScrollView { return sv }
            v = cur.superview
        }
        return nil
    }

    // MARK: - Auto-scroll during drag

    /// Edge margin at which auto-scroll kicks in. Finger closer than
    /// this to the visible left/right edge scrolls the viewport.
    private static let autoScrollMargin: CGFloat = 60
    /// Max scroll speed in pixels per display frame — tuned so a long
    /// hold at the very edge slews smoothly without overshooting.
    private static let autoScrollMaxPxPerFrame: CGFloat = 18

    /// Recompute whether the finger is near an edge of the enclosing
    /// scroll view's visible area. Starts or stops the auto-scroll
    /// display link and sets the current speed.
    private func updateAutoScrollForDrag() {
        guard let sv = suppressedScrollView else {
            stopAutoScroll()
            return
        }
        // Convert finger position from self-coords to the scroll
        // view's visible rect (bounds within its own coordinate space).
        let inSV = convert(lastDragLocationInSelf, to: sv)
        let visibleW = sv.bounds.width
        let visibleH = sv.bounds.height
        let distLeft = inSV.x
        let distRight = visibleW - inSV.x
        let distTop = inSV.y
        let distBottom = visibleH - inSV.y
        let margin = Self.autoScrollMargin

        var speedX: CGFloat = 0
        if distLeft < margin {
            let t = max(0, min(1, (margin - distLeft) / margin))
            speedX = -t * Self.autoScrollMaxPxPerFrame
        } else if distRight < margin {
            let t = max(0, min(1, (margin - distRight) / margin))
            speedX = t * Self.autoScrollMaxPxPerFrame
        }
        var speedY: CGFloat = 0
        if distTop < margin {
            let t = max(0, min(1, (margin - distTop) / margin))
            speedY = -t * Self.autoScrollMaxPxPerFrame
        } else if distBottom < margin {
            let t = max(0, min(1, (margin - distBottom) / margin))
            speedY = t * Self.autoScrollMaxPxPerFrame
        }
        autoScrollSpeedX = speedX
        autoScrollSpeedY = speedY
        if speedX == 0 && speedY == 0 {
            stopAutoScroll()
        } else if autoScrollLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(autoScrollTick))
            link.add(to: .main, forMode: .common)
            autoScrollLink = link
        }
    }

    /// Per-frame auto-scroll. Pushes the scroll view's contentOffset
    /// by the current speed; `scrollViewDidScroll` then syncs the
    /// shared `TimelineState.hScrollOffsetPx` so other synced panes
    /// (row headers, ruler) follow. We also re-run the drag update so
    /// `liveStartMS/liveEndMS` reflect the new content under the
    /// finger even when the finger itself isn't moving.
    @objc private func autoScrollTick() {
        guard let sv = suppressedScrollView, let d = drag else {
            stopAutoScroll(); return
        }
        let maxX = max(0, sv.contentSize.width - sv.bounds.width)
        let maxY = max(0, sv.contentSize.height - sv.bounds.height)
        let newX = max(0, min(maxX, sv.contentOffset.x + autoScrollSpeedX))
        let newY = max(0, min(maxY, sv.contentOffset.y + autoScrollSpeedY))
        if newX == sv.contentOffset.x && newY == sv.contentOffset.y {
            return
        }
        let dx = newX - sv.contentOffset.x
        let dy = newY - sv.contentOffset.y
        sv.contentOffset = CGPoint(x: newX, y: newY)
        // Re-run live drag math with the scrolled-updated location.
        lastDragLocationInSelf.x += dx
        lastDragLocationInSelf.y += dy
        // Re-evaluate cross-row hover using the new Y (for .move
        // drags) so the ghost snaps to a newly-visible row.
        if d.kind == .move {
            let (tops, heights) = rowLayout()
            var hoverId: Int? = nil
            for i in 0..<rows.count {
                if lastDragLocationInSelf.y >= tops[i]
                    && lastDragLocationInSelf.y < tops[i] + heights[i] {
                    hoverId = rows[i].id
                    break
                }
            }
            if let h = hoverId,
               let r = rows.first(where: { $0.id == h }),
               r.timing != nil {
                hoverId = nil
            }
            let newLive = (hoverId == d.rowIndex) ? nil : hoverId
            if newLive != liveRowId {
                liveRowId = newLive
                setNeedsDisplay()
            }
        }
        applyDragUpdateForCurrentFingerLocation(d: d)
    }

    /// Replays the drag's `.changed` math from the current
    /// `lastDragLocationInSelf` without a gesture-recognizer event.
    /// Mirrors the core of `onPan(.changed)` for move / resize cases.
    private func applyDragUpdateForCurrentFingerLocation(d: DragState) {
        // Derive the same delta the gesture would give us:
        //   dMS = (currentFingerX - beganFingerX) / pixelsPerMS
        // We never recorded the begin X, so reconstruct it from the
        // effect's original start + the live start: the effect has
        // drifted by `liveStart - origStart` in world ms, which maps
        // to the finger's cumulative delta in world pixels.
        guard pixelsPerMS > 0 else { return }
        let effectDriftMS: Int
        switch d.kind {
        case .move, .resizeLeft:
            effectDriftMS = (liveStartMS ?? d.origStartMS) - d.origStartMS
        case .resizeRight:
            effectDriftMS = (liveEndMS ?? d.origEndMS) - d.origEndMS
        default:
            return
        }
        // The new drift is previous drift + autoScrollSpeedX (one
        // frame's worth). Apply the same clamping as the real
        // gesture path does.
        let extraMS = Int(autoScrollSpeedX / pixelsPerMS)
        let totalDeltaMS = effectDriftMS + extraMS

        switch d.kind {
        case .move:
            let duration = d.origEndMS - d.origStartMS
            let minStart = d.minStartMS
            let maxStart = d.maxEndMS == Int.max
                ? Int.max : d.maxEndMS - duration
            let newStart = max(minStart,
                                min(maxStart, d.origStartMS + totalDeltaMS))
            liveStartMS = newStart
            liveEndMS = newStart + duration
        case .resizeLeft:
            let ns = max(d.minStartMS, d.origStartMS + totalDeltaMS)
            liveStartMS = min(ns, d.origEndMS - 1)
            liveEndMS = d.origEndMS
        case .resizeRight:
            let raw = d.origEndMS + totalDeltaMS
            let capped = min(d.maxEndMS, raw)
            liveEndMS = max(capped, d.origStartMS + 1)
            liveStartMS = d.origStartMS
        default:
            return
        }
        if let ls = liveStartMS { dragMinMS = min(dragMinMS, ls) }
        if let le = liveEndMS { dragMaxMS = max(dragMaxMS, le) }
        let slop: CGFloat = 16
        let x1 = CGFloat(dragMinMS) * pixelsPerMS - slop
        let x2 = CGFloat(dragMaxMS) * pixelsPerMS + slop
        invalidate(xRanges: [x1...x2])
    }

    private func stopAutoScroll() {
        autoScrollLink?.invalidate()
        autoScrollLink = nil
        autoScrollSpeedX = 0
        autoScrollSpeedY = 0
    }

    private var pinchAnchorX: CGFloat = 0
    private var pinchLastScale: CGFloat = 1

    @objc private func onPinch(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .began:
            pinchAnchorX = g.location(in: self).x
            pinchLastScale = 1
        case .changed:
            let delta = g.scale / pinchLastScale
            pinchLastScale = g.scale
            actions.onPinchZoom(delta, pinchAnchorX)
        default:
            break
        }
    }

    func hitTestEffectPublic(at p: CGPoint) -> (Int, Int)? {
        guard let h = hitTestEffect(at: p) else { return nil }
        return (h.rowIndex, h.effectIndex)
    }

    // Lets the owning SyncedScrollView's pan still scroll when the
    // touch doesn't land on an effect. The canvas's pan takes over
    // only after onPan(.began) finds a hit.
    func canvasHasDragCandidate(at p: CGPoint) -> Bool {
        guard let hit = hitTestEffect(at: p) else { return false }
        if hit.zone == .center {
            // Only the center of an *already selected* effect starts a
            // move — this keeps the finger free to scroll otherwise.
            return selection?.rowIndex == hit.rowIndex && selection?.effectIndex == hit.effectIndex
        }
        return hit.zone == .leftEdge
            || hit.zone == .rightEdge
            || hit.zone == .fadeIn
            || hit.zone == .fadeOut
    }

    /// Attach `ourPan` to the enclosing UIScrollView's pan recognizer
    /// as a required-failure dependency, so the scroll view's pan
    /// can't fire while our pan is live. Called from the delegate's
    /// `shouldBegin` every time our pan wants to start, so the
    /// relationship stays attached to whatever scroll view currently
    /// wraps us (view switches / host rebuilds can swap it out).
    /// Setting the same requirement repeatedly is idempotent.
    func ensureScrollViewRequiresFailure(of ourPan: UIPanGestureRecognizer) {
        guard let sv = findEnclosingScrollView() else { return }
        sv.panGestureRecognizer.require(toFail: ourPan)
    }
}

/// Keeps the outer UIScrollView's own gestures from fighting with our
/// pan/pinch unless a real drag target is under the finger.
final class CanvasGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var owner: EffectsCanvasUIView?

    func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard let view = owner else { return true }
        if g is UIPinchGestureRecognizer { return true }
        if g is UILongPressGestureRecognizer {
            let p = g.location(in: view)
            return view.hitTestEffectPublic(at: p) != nil
        }
        if let pan = g as? UIPanGestureRecognizer {
            let p = pan.location(in: view)
            let hasCandidate = view.canvasHasDragCandidate(at: p)
            if hasCandidate {
                // Re-assert require-to-fail against the current
                // enclosing scroll view every time our pan intends
                // to begin. Cheap if already set (UIKit stores these
                // in a set), correct if the scroll view was swapped.
                view.ensureScrollViewRequiresFailure(of: pan)
            }
            return hasCandidate
        }
        return true
    }

    // Pan-vs-pan: block the enclosing UIScrollView's pan from
    // running at the same time as ours. Our `shouldBegin` already
    // filters based on drag-candidate, so the scroll view still
    // takes over cleanly when the touch has no effect under it.
    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        if g is UIPanGestureRecognizer && other is UIPanGestureRecognizer {
            return false
        }
        return true
    }
}

/// Canvas for the timing effects row. Each timing effect draws as a
/// small vertical tick across the row height plus a label if the
/// effect has a non-empty name (lyrics words, phoneme labels, etc.).
struct TimingEffectsCanvas: UIViewRepresentable {
    let rows: [SequencerViewModel.RowInfo]
    let rowHeight: CGFloat
    let pixelsPerMS: CGFloat
    let contentWidth: CGFloat
    let contentHeight: CGFloat
    var actions: EffectCanvasActions = EffectCanvasActions()

    func makeUIView(context: Context) -> TimingCanvasUIView {
        let v = TimingCanvasUIView()
        v.isOpaque = false
        v.backgroundColor = .clear
        v.contentMode = .redraw
        v.installGestures()
        return v
    }

    func updateUIView(_ view: TimingCanvasUIView, context: Context) {
        let newSize = CGSize(width: contentWidth, height: contentHeight)

        let fullInvalidate =
            view.rowHeight != rowHeight ||
            view.pixelsPerMS != pixelsPerMS ||
            view.totalSize != newSize ||
            !rowStructureMatches(old: view.rows, new: rows)

        var dirtyRanges: [ClosedRange<CGFloat>] = []
        if !fullInvalidate {
            dirtyRanges.append(contentsOf: rowEffectDiffRanges(
                old: view.rows, new: rows, pixelsPerMS: pixelsPerMS))
        }

        let sizeChanged = view.totalSize != newSize
        view.rows = rows
        view.rowHeight = rowHeight
        view.pixelsPerMS = pixelsPerMS
        view.totalSize = newSize
        view.actions = actions
        if sizeChanged {
            view.frame.size = newSize
            view.invalidateIntrinsicContentSize()
        }
        if fullInvalidate {
            view.setNeedsDisplay()
        } else if !dirtyRanges.isEmpty {
            view.invalidate(xRanges: dirtyRanges)
        }
    }
}

final class TimingCanvasUIView: UIView {
    private static let tileMaxWidth: CGFloat = 4096
    private var tiles: [CanvasTileView] = []

    var rows: [SequencerViewModel.RowInfo] = []
    var rowHeight: CGFloat = 24
    var pixelsPerMS: CGFloat = 0.1
    var totalSize: CGSize = .zero
    var actions: EffectCanvasActions = EffectCanvasActions()

    override var intrinsicContentSize: CGSize { totalSize }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutHorizontalTiles(in: self,
                              tiles: &tiles,
                              size: bounds.size,
                              tileMaxWidth: Self.tileMaxWidth) { [weak self] cg, worldRect in
            self?.drawContent(cg: cg, worldRect: worldRect)
        }
    }

    override func setNeedsDisplay() {
        super.setNeedsDisplay()
        for t in tiles { t.setNeedsDisplay() }
    }

    func invalidate(xRanges: [ClosedRange<CGFloat>]) {
        invalidateTileRanges(tiles, xRanges: xRanges)
    }

    fileprivate func drawContent(cg: CGContext, worldRect rect: CGRect) {
        var y: CGFloat = 0
        // Alternate by element (track), not by row: all layers of one
        // timing track share a stripe color, the next track gets the
        // other. Tracks with no `timing.elementName` fall back to row
        // parity so we still draw something sensible.
        let bandEven = UIColor(hue: 0.33, saturation: 0.25, brightness: 0.17, alpha: 1)
        let bandOdd  = UIColor(hue: 0.33, saturation: 0.30, brightness: 0.11, alpha: 1)
        var elementOrder: [String: Int] = [:]
        for row in rows {
            let key = row.timing?.elementName ?? ""
            if !key.isEmpty, elementOrder[key] == nil {
                elementOrder[key] = elementOrder.count
            }
        }
        let tickColor = UIColor.white.withAlphaComponent(0.75)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(0.75),
        ]

        for (rowIdx, row) in rows.enumerated() {
            let elementIdx: Int
            if let name = row.timing?.elementName, let idx = elementOrder[name] {
                elementIdx = idx
            } else {
                elementIdx = rowIdx
            }
            let bandBg = (elementIdx % 2 == 0) ? bandEven : bandOdd
            cg.setFillColor(bandBg.cgColor)
            cg.fill(CGRect(x: rect.minX, y: y, width: rect.width, height: rowHeight))

            for effect in row.effects {
                let x1 = CGFloat(effect.startTimeMS) * pixelsPerMS
                let x2 = CGFloat(effect.endTimeMS) * pixelsPerMS
                if x2 < rect.minX || x1 > rect.maxX { continue }

                // Mark bracket (thin vertical lines at start + end).
                cg.setStrokeColor(tickColor.cgColor)
                cg.setLineWidth(1)
                cg.move(to: CGPoint(x: x1 + 0.5, y: y + 1))
                cg.addLine(to: CGPoint(x: x1 + 0.5, y: y + rowHeight - 1))
                cg.move(to: CGPoint(x: x2 - 0.5, y: y + 1))
                cg.addLine(to: CGPoint(x: x2 - 0.5, y: y + rowHeight - 1))
                cg.strokePath()

                // Label centered, if it fits.
                if !effect.name.isEmpty {
                    let labelW = (effect.name as NSString).size(withAttributes: labelAttrs).width
                    if labelW < (x2 - x1) - 4 {
                        let tx = (x1 + x2) / 2 - labelW / 2
                        let ty = y + (rowHeight - 11) / 2
                        (effect.name as NSString).draw(
                            at: CGPoint(x: tx, y: ty),
                            withAttributes: labelAttrs)
                    }
                }
            }
            y += rowHeight
        }
    }

    // MARK: - Gestures

    private var pinchAnchorX: CGFloat = 0
    private var pinchLastScale: CGFloat = 1

    func installGestures() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        pinch.delegate = passthroughDelegate
        addGestureRecognizer(pinch)
        // Tap anywhere in the timing band to seek — matches the
        // ruler behavior so any time-axis strip is a seek target.
        let tap = UITapGestureRecognizer(target: self, action: #selector(onSeekTap(_:)))
        tap.delegate = passthroughDelegate
        addGestureRecognizer(tap)
    }

    private lazy var passthroughDelegate: PassthroughGestureDelegate = {
        PassthroughGestureDelegate()
    }()

    @objc private func onPinch(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .began:
            pinchAnchorX = g.location(in: self).x
            pinchLastScale = 1
        case .changed:
            let delta = g.scale / pinchLastScale
            pinchLastScale = g.scale
            actions.onPinchZoom(delta, pinchAnchorX)
        default:
            break
        }
    }

    @objc private func onSeekTap(_ g: UITapGestureRecognizer) {
        guard pixelsPerMS > 0 else { return }
        let p = g.location(in: self)
        let ms = max(0, Int(p.x / pixelsPerMS))
        // Snap to the nearest timing-mark edge within 8 px so a
        // "tap on a mark" lands exactly on the mark's start/end.
        let thresholdMS = Int(8.0 / pixelsPerMS)
        var bestMS = ms
        var bestDist = thresholdMS + 1
        for row in rows {
            for e in row.effects {
                for candidate in [e.startTimeMS, e.endTimeMS] {
                    let d = abs(candidate - ms)
                    if d < bestDist {
                        bestDist = d
                        bestMS = candidate
                    }
                }
            }
        }
        actions.onSeekToMS(bestMS)
    }
}

/// Gesture delegate that allows simultaneous recognition so a canvas's
/// pinch can coexist with the outer UIScrollView's pan (panning to
/// scroll continues to work while the user is pinching).
final class PassthroughGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }
}

/// Combined ruler + waveform canvas. Drawn in a single UIView so the
/// content renders reliably at the same large widths the effect grid
/// and timing band handle (the SwiftUI Canvas inside a UIHostingController
/// does not, breaking first-load display on typical multi-minute
/// sequences). Also hosts a pinch recognizer so zoom gestures work here
/// the same way they do over the grid.
struct TopChromeCanvas: UIViewRepresentable {
    let durationMS: Int
    let pixelsPerMS: CGFloat
    let contentWidth: CGFloat
    let rulerHeight: CGFloat
    let waveformHeight: CGFloat
    let hasAudio: Bool
    let peaks: [Float]
    var actions: EffectCanvasActions = EffectCanvasActions()

    func makeUIView(context: Context) -> TopChromeCanvasUIView {
        let v = TopChromeCanvasUIView()
        v.isOpaque = false
        v.backgroundColor = .clear
        v.contentMode = .redraw
        v.installGestures()
        return v
    }

    func updateUIView(_ view: TopChromeCanvasUIView, context: Context) {
        let newSize = CGSize(width: contentWidth,
                             height: rulerHeight + waveformHeight)
        let visualChanged =
            view.durationMS != durationMS ||
            view.pixelsPerMS != pixelsPerMS ||
            view.totalSize != newSize ||
            view.rulerHeight != rulerHeight ||
            view.waveformHeight != waveformHeight ||
            view.hasAudio != hasAudio ||
            view.peaks != peaks
        let sizeChanged = view.totalSize != newSize
        view.durationMS = durationMS
        view.pixelsPerMS = pixelsPerMS
        view.totalSize = newSize
        view.rulerHeight = rulerHeight
        view.waveformHeight = waveformHeight
        view.hasAudio = hasAudio
        view.peaks = peaks
        view.actions = actions
        if sizeChanged {
            view.frame.size = newSize
            view.invalidateIntrinsicContentSize()
        }
        if visualChanged {
            view.setNeedsDisplay()
        }
    }
}

final class TopChromeCanvasUIView: UIView {
    private static let tileMaxWidth: CGFloat = 4096
    private var tiles: [CanvasTileView] = []

    var durationMS: Int = 0
    var pixelsPerMS: CGFloat = 0.1
    var totalSize: CGSize = .zero
    var rulerHeight: CGFloat = 24
    var waveformHeight: CGFloat = 48
    var hasAudio: Bool = false
    var peaks: [Float] = []
    var actions: EffectCanvasActions = EffectCanvasActions()

    override var intrinsicContentSize: CGSize { totalSize }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutHorizontalTiles(in: self,
                              tiles: &tiles,
                              size: bounds.size,
                              tileMaxWidth: Self.tileMaxWidth) { [weak self] cg, worldRect in
            self?.drawContent(cg: cg, worldRect: worldRect)
        }
    }

    override func setNeedsDisplay() {
        super.setNeedsDisplay()
        for t in tiles { t.setNeedsDisplay() }
    }

    fileprivate func drawContent(cg: CGContext, worldRect rect: CGRect) {
        // Ruler strip — only the slice covered by this tile's dirty rect.
        cg.setFillColor(UIColor.black.withAlphaComponent(0.2).cgColor)
        cg.fill(CGRect(x: rect.minX, y: 0, width: rect.width, height: rulerHeight))

        drawRulerTicks(cg: cg, rect: rect)

        // Waveform strip (or placeholder background if no audio).
        let waveRect = CGRect(x: rect.minX, y: rulerHeight,
                              width: rect.width, height: waveformHeight)
        if hasAudio {
            cg.setFillColor(UIColor.black.withAlphaComponent(0.3).cgColor)
            cg.fill(waveRect)
            drawWaveform(cg: cg, in: CGRect(x: 0, y: rulerHeight,
                                            width: totalSize.width,
                                            height: waveformHeight),
                         rect: rect)
        } else {
            cg.setFillColor(UIColor(white: 0.08, alpha: 1).cgColor)
            cg.fill(waveRect)
        }
    }

    // Matches desktop: label every major tick, minor tick at half the
    // major interval. Major spacing targets ~100 pixels so labels don't
    // collide. Intervals are picked from a table of "nice" ms values
    // that each divide cleanly in half, so minor ticks always fall on a
    // round time value (avoiding artifacts like 12.5ms half-steps).
    private static let niceMajorIntervalsMS: [Int] = [
        10, 20, 50, 100, 200, 500,
        1000, 2000, 5000, 10000, 20000, 30000, 60000,
        120000, 300000, 600000, 1200000, 3600000
    ]

    private func majorIntervalMS() -> Int {
        let targetPixels: CGFloat = 100
        guard pixelsPerMS > 0 else { return 1000 }
        let targetMS = Double(targetPixels / pixelsPerMS)
        for ms in Self.niceMajorIntervalsMS {
            if Double(ms) >= targetMS { return ms }
        }
        return Self.niceMajorIntervalsMS.last ?? 60000
    }

    private func drawRulerTicks(cg: CGContext, rect: CGRect) {
        let majorMS = majorIntervalMS()
        let minorMS = max(1, majorMS / 2)

        cg.setStrokeColor(UIColor.gray.cgColor)
        cg.setLineWidth(1)

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.gray,
        ]

        // Cull ticks to the dirty rect for performance at large widths.
        let startMS = max(0, Int(rect.minX / pixelsPerMS) / minorMS * minorMS)
        var ms = startMS
        while ms <= durationMS {
            let x = CGFloat(ms) * pixelsPerMS
            if x > rect.maxX + 60 { break }

            let isMajor = ms % majorMS == 0
            let tickH: CGFloat = isMajor ? 15 : 8
            cg.move(to: CGPoint(x: x, y: rulerHeight - tickH))
            cg.addLine(to: CGPoint(x: x, y: rulerHeight))

            if isMajor {
                let label = Self.formatTimeLabel(ms: ms, majorMS: majorMS) as NSString
                label.draw(at: CGPoint(x: x + 2, y: 2), withAttributes: labelAttrs)
            }

            ms += minorMS
        }
        cg.strokePath()
    }

    /// mm:ss.fff style, matching desktop. Trailing zero digits beyond
    /// the current major-tick precision are dropped so 1-second ticks
    /// show `0:05` instead of `0:05.000`.
    static func formatTimeLabel(ms: Int, majorMS: Int) -> String {
        let minutes = ms / 60000
        let seconds = (ms % 60000) / 1000
        let millis = ms % 1000
        let showFractional = majorMS < 1000
        if showFractional {
            // Decide precision from majorMS: sub-100ms → 3 digits, else 2.
            if majorMS < 100 {
                return String(format: "%d:%02d.%03d", minutes, seconds, millis)
            } else {
                return String(format: "%d:%02d.%02d", minutes, seconds, millis / 10)
            }
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // Desktop draws the waveform as a filled polygon (min line forward,
    // max line back) in a light-blue fill with a white outline. The
    // older per-bucket green vertical-line style obscured the envelope
    // shape at high zoom. See `Waveform::DrawWaveView` in
    // `src-ui-wx/ui/sequencer/Waveform.cpp` for the reference.
    private func drawWaveform(cg: CGContext, in waveRect: CGRect, rect: CGRect) {
        guard peaks.count >= 2 else { return }
        let numBuckets = peaks.count / 2
        let centerY = waveRect.midY
        let scale = (waveRect.height / 2) * 0.9
        let timelineWidth = CGFloat(durationMS) * pixelsPerMS
        guard timelineWidth > 0 else { return }

        // Cull to the dirty rect — one polygon per redraw, so we only
        // need to walk the visible bucket range.
        let firstBucket = max(0, Int((rect.minX / timelineWidth) * CGFloat(numBuckets)) - 1)
        let lastBucket  = min(numBuckets - 1,
                              Int((rect.maxX / timelineWidth) * CGFloat(numBuckets)) + 1)
        guard firstBucket <= lastBucket else { return }

        let path = CGMutablePath()
        // Forward along the min (bottom) edge.
        var startedPath = false
        for i in firstBucket...lastBucket {
            let x = (CGFloat(i) / CGFloat(numBuckets)) * timelineWidth
            let mn = CGFloat(peaks[i * 2])
            let yMin = centerY - mn * scale
            if !startedPath {
                path.move(to: CGPoint(x: x, y: yMin))
                startedPath = true
            } else {
                path.addLine(to: CGPoint(x: x, y: yMin))
            }
        }
        // Back along the max (top) edge to close the polygon.
        for i in stride(from: lastBucket, through: firstBucket, by: -1) {
            let x = (CGFloat(i) / CGFloat(numBuckets)) * timelineWidth
            let mx = CGFloat(peaks[i * 2 + 1])
            let yMax = centerY - mx * scale
            path.addLine(to: CGPoint(x: x, y: yMax))
        }
        path.closeSubpath()

        // Fill light blue (desktop COLOR_WAVEFORM = 130, 178, 207).
        cg.addPath(path)
        cg.setFillColor(UIColor(red: 130/255.0, green: 178/255.0,
                                blue: 207/255.0, alpha: 1.0).cgColor)
        cg.fillPath()

        // White outline on top.
        cg.addPath(path)
        cg.setStrokeColor(UIColor.white.cgColor)
        cg.setLineWidth(1)
        cg.strokePath()
    }

    // MARK: - Gestures

    private var pinchAnchorX: CGFloat = 0
    private var pinchLastScale: CGFloat = 1

    func installGestures() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        pinch.delegate = passthroughDelegate
        addGestureRecognizer(pinch)
        // Tap on the ruler / waveform to seek the play head to that
        // time. Works whether or not the sequence has audio.
        let tap = UITapGestureRecognizer(target: self, action: #selector(onSeekTap(_:)))
        tap.delegate = passthroughDelegate
        addGestureRecognizer(tap)
    }

    private lazy var passthroughDelegate: PassthroughGestureDelegate = {
        PassthroughGestureDelegate()
    }()

    @objc private func onPinch(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .began:
            pinchAnchorX = g.location(in: self).x
            pinchLastScale = 1
        case .changed:
            let delta = g.scale / pinchLastScale
            pinchLastScale = g.scale
            actions.onPinchZoom(delta, pinchAnchorX)
        default:
            break
        }
    }

    @objc private func onSeekTap(_ g: UITapGestureRecognizer) {
        guard pixelsPerMS > 0 else { return }
        let p = g.location(in: self)
        let ms = max(0, min(durationMS, Int(p.x / pixelsPerMS)))
        actions.onSeekToMS(ms)
    }
}
