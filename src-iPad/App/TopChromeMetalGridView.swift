import SwiftUI
import UIKit
import MetalKit

/// Interactive Metal-backed ruler+waveform strip. Tap seeks the
/// play head, pinch zooms, horizontal drag scrolls. Vertical is
/// locked — top chrome has no vertical extent.
struct TopChromeMetalGridView: UIViewRepresentable {
    let durationMS: Int
    let pixelsPerMS: CGFloat
    let rulerHeight: CGFloat
    let waveformHeight: CGFloat
    let hasAudio: Bool
    let peaks: [Float]
    @Binding var scrollOffsetX: CGFloat
    let onSeek: (Int) -> Void
    let onPinchZoom: (CGFloat, CGFloat) -> Void
    var onUserInteraction: (() -> Void)?
    // B32 loop-region inputs + callbacks. When `hasLoop`, the region
    // is shaded across both ruler and waveform. Long-press + drag on
    // the ruler fires `onSetLoop(startMS, endMS)` on each .changed so
    // the outer view sees the live extent; long-press over an
    // existing loop (no drag) fires `onLoopMenu(x)` so the outer
    // view can present the loop context menu.
    var loopStartMS: Int = 0
    var loopEndMS: Int = 0
    var hasLoop: Bool = false
    var onSetLoop: ((_ startMS: Int, _ endMS: Int) -> Void)?
    var onLoopMenu: ((_ atXInView: CGFloat) -> Void)?
    /// B41: long-press on the waveform strip surfaces the filter-
    /// variant menu (bass / treble / alto / non-vocals / full).
    var onWaveformMenu: (() -> Void)?

    func makeUIView(context: Context) -> TopChromeMetalMTKView {
        let v = TopChromeMetalMTKView()
        v.coordinator = context.coordinator
        v.installGestures()
        return v
    }
    func updateUIView(_ view: TopChromeMetalMTKView, context: Context) {
        let c = context.coordinator
        c.durationMS = durationMS
        c.pixelsPerMS = pixelsPerMS
        c.rulerHeight = rulerHeight
        c.waveformHeight = waveformHeight
        c.hasAudio = hasAudio
        c.peaks = peaks
        c.scrollOffsetX = scrollOffsetX
        c.onSeek = onSeek
        c.onPinchZoom = onPinchZoom
        c.onUpdateScrollX = { scrollOffsetX = $0 }
        c.onUserInteraction = onUserInteraction
        c.loopStartMS = loopStartMS
        c.loopEndMS = loopEndMS
        c.hasLoop = hasLoop
        c.onSetLoop = onSetLoop
        c.onLoopMenu = onLoopMenu
        c.onWaveformMenu = onWaveformMenu
        view.setNeedsDisplay()
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        let bridge = XLGridMetalBridge(name: "TopChromeGrid")!
        var durationMS: Int = 0
        var pixelsPerMS: CGFloat = 0.1
        var rulerHeight: CGFloat = 24
        var waveformHeight: CGFloat = 48
        var hasAudio: Bool = false
        var peaks: [Float] = []
        var scrollOffsetX: CGFloat = 0
        var onSeek: (Int) -> Void = { _ in }
        var onPinchZoom: (CGFloat, CGFloat) -> Void = { _, _ in }
        var onUpdateScrollX: (CGFloat) -> Void = { _ in }
        var onUserInteraction: (() -> Void)?
        var panStartScrollX: CGFloat = 0
        // B39: set on `.began` when the pan started in the ruler
        // strip (y < rulerHeight); `.changed` ticks drive continuous
        // `onSeek` instead of the scroll path.
        var scrubbingFromRuler: Bool = false
        // B32 loop-region inputs + live drag state.
        var loopStartMS: Int = 0
        var loopEndMS: Int = 0
        var hasLoop: Bool = false
        var onSetLoop: ((Int, Int) -> Void)?
        var onLoopMenu: ((CGFloat) -> Void)?
        var onWaveformMenu: (() -> Void)?
        var loopDragAnchorMS: Int?
        var loopDragCurrentMS: Int?
    }
}

final class TopChromeMetalMTKView: MTKView, MTKViewDelegate {
    weak var coordinator: TopChromeMetalGridView.Coordinator?
    private var layerAttached = false

    override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device ?? MTLCreateSystemDefaultDevice())
        common()
    }
    required init(coder: NSCoder) {
        super.init(coder: coder)
        common()
    }
    private func common() {
        self.colorPixelFormat = .bgra8Unorm
        self.clearColor = MTLClearColorMake(0, 0, 0, 0)
        self.isPaused = true
        self.enableSetNeedsDisplay = true
        self.isOpaque = false
        self.delegate = self
        if let layer = self.layer as? CAMetalLayer { layer.isOpaque = false }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let c = coordinator else { return }
        if !layerAttached, let layer = self.layer as? CAMetalLayer {
            c.bridge.attach(layer)
            layerAttached = true
        }
        c.bridge.setDrawableSize(drawableSize, scale: contentScaleFactor)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        coordinator?.bridge.setDrawableSize(size, scale: view.contentScaleFactor)
    }

    private static let niceIntervals: [Int] = [
        10, 20, 50, 100, 200, 500,
        1000, 2000, 5000, 10000, 20000, 30000, 60000,
        120000, 300000, 600000, 1200000, 3600000
    ]
    private func majorIntervalMS(pixelsPerMS: CGFloat) -> Int {
        guard pixelsPerMS > 0 else { return 1000 }
        let target = Double(100 / pixelsPerMS)
        for ms in Self.niceIntervals where Double(ms) >= target { return ms }
        return Self.niceIntervals.last ?? 60000
    }
    private static func fmtTime(_ ms: Int, majorMS: Int) -> String {
        let minutes = ms / 60000
        let seconds = (ms % 60000) / 1000
        let millis  = ms % 1000
        if majorMS < 100 {
            return String(format: "%d:%02d.%03d", minutes, seconds, millis)
        } else if majorMS < 1000 {
            return String(format: "%d:%02d.%02d", minutes, seconds, millis / 10)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    func draw(in view: MTKView) {
        guard let c = coordinator else { return }
        guard c.bridge.beginFrame() else { return }
        let size = bounds.size
        let bridge = c.bridge

        // Backgrounds.
        bridge.beginFilledRectBatch()
        bridge.appendFilledRectX(0, y: 0, w: size.width, h: c.rulerHeight,
                                  r: 0, g: 0, b: 0, a: 0.2)
        if c.hasAudio {
            bridge.appendFilledRectX(0, y: c.rulerHeight,
                                      w: size.width, h: c.waveformHeight,
                                      r: 0, g: 0, b: 0, a: 0.3)
        } else {
            bridge.appendFilledRectX(0, y: c.rulerHeight,
                                      w: size.width, h: c.waveformHeight,
                                      r: 0.08, g: 0.08, b: 0.08, a: 1.0)
        }
        bridge.flushFilledRectBatch()

        // B32 loop-region highlight. Draws whichever of the
        // persisted region or the in-flight drag range is active.
        let activeLoopStart: Int?
        let activeLoopEnd: Int?
        if let a = c.loopDragAnchorMS, let b = c.loopDragCurrentMS {
            activeLoopStart = min(a, b)
            activeLoopEnd = max(a, b)
        } else if c.hasLoop {
            activeLoopStart = c.loopStartMS
            activeLoopEnd = c.loopEndMS
        } else {
            activeLoopStart = nil
            activeLoopEnd = nil
        }
        if let ls = activeLoopStart, let le = activeLoopEnd, le > ls,
           c.pixelsPerMS > 0 {
            let x1 = CGFloat(ls) * c.pixelsPerMS - c.scrollOffsetX
            let x2 = CGFloat(le) * c.pixelsPerMS - c.scrollOffsetX
            let totalH = c.rulerHeight + c.waveformHeight
            bridge.beginFilledRectBatch()
            // Soft blue band across the whole strip.
            bridge.appendFilledRectX(x1, y: 0, w: max(1, x2 - x1), h: totalH,
                                      r: 0.35, g: 0.60, b: 1.0, a: 0.18)
            bridge.flushFilledRectBatch()
            // Boundary lines at the edges for clarity.
            bridge.beginLineBatch()
            let bc: (CGFloat, CGFloat, CGFloat) = (0.45, 0.70, 1.0)
            bridge.appendLineX1(x1, y1: 0, x2: x1, y2: totalH,
                                 r: bc.0, g: bc.1, b: bc.2, a: 0.95)
            bridge.appendLineX1(x2, y1: 0, x2: x2, y2: totalH,
                                 r: bc.0, g: bc.1, b: bc.2, a: 0.95)
            bridge.flushLineBatch()
        }

        // Ruler ticks + labels.
        if c.pixelsPerMS > 0 && c.durationMS > 0 {
            let major = majorIntervalMS(pixelsPerMS: c.pixelsPerMS)
            let minor = max(1, major / 2)
            bridge.beginLineBatch()
            var labels: [(CGFloat, String)] = []
            let startMS = max(0, (Int(c.scrollOffsetX / c.pixelsPerMS) / minor) * minor)
            var ms = startMS
            while ms <= c.durationMS {
                let x = CGFloat(ms) * c.pixelsPerMS - c.scrollOffsetX
                if x > size.width + 60 { break }
                if x >= -1 {
                    let isMajor = ms % major == 0
                    let tickH: CGFloat = isMajor ? 15 : 8
                    bridge.appendLineX1(x, y1: c.rulerHeight - tickH,
                                         x2: x, y2: c.rulerHeight,
                                         r: 0.5, g: 0.5, b: 0.5, a: 1.0)
                    if isMajor {
                        labels.append((x, Self.fmtTime(ms, majorMS: major)))
                    }
                }
                ms += minor
            }
            bridge.flushLineBatch()
            for lp in labels {
                bridge.drawText(lp.1, atX: lp.0 + 2, y: 2, fontSize: 9,
                                 r: 0.5, g: 0.5, b: 0.5, a: 1.0)
            }
        }

        // Waveform fill + outline.
        if c.hasAudio && c.peaks.count >= 4 {
            let numBuckets = c.peaks.count / 2
            let centerY = c.rulerHeight + c.waveformHeight / 2
            let scale = (c.waveformHeight / 2) * 0.9
            let timelineW = CGFloat(c.durationMS) * c.pixelsPerMS
            if timelineW > 0 {
                let visMinX = c.scrollOffsetX - 4
                let visMaxX = c.scrollOffsetX + size.width + 4
                let firstB = max(0, Int((visMinX / timelineW) * CGFloat(numBuckets)) - 1)
                let lastB = min(numBuckets - 1,
                                 Int((visMaxX / timelineW) * CGFloat(numBuckets)) + 1)
                if firstB <= lastB {
                    for i in firstB..<lastB {
                        let xi = (CGFloat(i)/CGFloat(numBuckets)) * timelineW - c.scrollOffsetX
                        let xj = (CGFloat(i+1)/CGFloat(numBuckets)) * timelineW - c.scrollOffsetX
                        let yiMin = centerY - CGFloat(c.peaks[i*2]) * scale
                        let yiMax = centerY - CGFloat(c.peaks[i*2+1]) * scale
                        let yjMin = centerY - CGFloat(c.peaks[(i+1)*2]) * scale
                        let yjMax = centerY - CGFloat(c.peaks[(i+1)*2+1]) * scale
                        bridge.fillTriangleX1(xi, y1: yiMin,
                                              x2: xi, y2: yiMax,
                                              x3: xj, y3: yjMax,
                                              r: 130/255, g: 178/255, b: 207/255, a: 1.0)
                        bridge.fillTriangleX1(xi, y1: yiMin,
                                              x2: xj, y2: yjMax,
                                              x3: xj, y3: yjMin,
                                              r: 130/255, g: 178/255, b: 207/255, a: 1.0)
                    }
                    bridge.beginLineBatch()
                    var pX: CGFloat = 0
                    var pY: CGFloat = 0
                    for (k, i) in (firstB...lastB).enumerated() {
                        let x = (CGFloat(i)/CGFloat(numBuckets)) * timelineW - c.scrollOffsetX
                        let yMin = centerY - CGFloat(c.peaks[i*2]) * scale
                        if k > 0 {
                            bridge.appendLineX1(pX, y1: pY, x2: x, y2: yMin,
                                                 r: 1, g: 1, b: 1, a: 1)
                        }
                        pX = x; pY = yMin
                    }
                    for (k, i) in (firstB...lastB).reversed().enumerated() {
                        let x = (CGFloat(i)/CGFloat(numBuckets)) * timelineW - c.scrollOffsetX
                        let yMax = centerY - CGFloat(c.peaks[i*2+1]) * scale
                        if k > 0 {
                            bridge.appendLineX1(pX, y1: pY, x2: x, y2: yMax,
                                                 r: 1, g: 1, b: 1, a: 1)
                        }
                        pX = x; pY = yMax
                    }
                    bridge.flushLineBatch()
                }
            }
        }
        bridge.endFrame()
    }

    func installGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.allowedScrollTypesMask = .all   // B95: trackpad + scroll-wheel scroll
        addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        addGestureRecognizer(pinch)
        // B32 loop region: long-press on the ruler establishes a
        // loop region; dragging extends it. Over an existing loop
        // band, a plain long-press pops the loop context menu.
        let lp = UILongPressGestureRecognizer(target: self,
                                                action: #selector(onLongPressLoop(_:)))
        lp.minimumPressDuration = 0.5
        // Allow drag during long-press so the finger can sweep out
        // the region without cancelling the gesture.
        lp.allowableMovement = 1_000
        addGestureRecognizer(lp)
    }

    @objc func onLongPressLoop(_ g: UILongPressGestureRecognizer) {
        guard let c = coordinator, c.pixelsPerMS > 0 else { return }
        let p = g.location(in: self)
        // B41: long-press in the waveform strip (below the ruler)
        // surfaces the filter-variant menu on .began. Only ruler
        // presses proceed to the loop-region path below.
        if p.y >= c.rulerHeight {
            if g.state == .began, c.hasAudio {
                c.onWaveformMenu?()
            }
            return
        }
        let ms = max(0, min(c.durationMS,
                             Int((p.x + c.scrollOffsetX) / c.pixelsPerMS)))
        switch g.state {
        case .began:
            // If the press lands inside the existing loop band AND
            // the finger hasn't moved yet, defer to the .changed
            // tick to decide between menu vs re-drag. Desktop
            // equivalent: shift-click to set vs right-click to get
            // menu — iPad collapses both to long-press so we use
            // drag-distance as the discriminator.
            c.loopDragAnchorMS = ms
            c.loopDragCurrentMS = ms
            setNeedsDisplay()
        case .changed:
            c.loopDragCurrentMS = ms
            if let anchor = c.loopDragAnchorMS {
                let lo = min(anchor, ms), hi = max(anchor, ms)
                if hi > lo {
                    c.onSetLoop?(lo, hi)
                }
            }
            setNeedsDisplay()
        case .ended:
            defer {
                c.loopDragAnchorMS = nil
                c.loopDragCurrentMS = nil
                setNeedsDisplay()
            }
            if let anchor = c.loopDragAnchorMS,
               let current = c.loopDragCurrentMS {
                let lo = min(anchor, current), hi = max(anchor, current)
                // Tiny drags count as "just a long-press" — surface
                // the menu if the press landed on the loop band.
                let dragPx = CGFloat(abs(current - anchor)) * c.pixelsPerMS
                if dragPx < 6, c.hasLoop,
                   ms >= c.loopStartMS, ms <= c.loopEndMS {
                    c.onLoopMenu?(p.x)
                } else if hi > lo {
                    c.onSetLoop?(lo, hi)
                }
            }
        case .cancelled, .failed:
            c.loopDragAnchorMS = nil
            c.loopDragCurrentMS = nil
            setNeedsDisplay()
        default:
            break
        }
    }

    @objc func onTap(_ g: UITapGestureRecognizer) {
        guard let c = coordinator, c.pixelsPerMS > 0 else { return }
        let p = g.location(in: self)
        let ms = max(0, min(c.durationMS, Int((p.x + c.scrollOffsetX) / c.pixelsPerMS)))
        c.onSeek(ms)
    }

    @objc func onPan(_ g: UIPanGestureRecognizer) {
        guard let c = coordinator else { return }
        switch g.state {
        case .began:
            let p = g.location(in: self)
            // B39: drag starting in the ruler strip continuously
            // updates the play head; drag in the waveform area keeps
            // its existing scroll behavior.
            c.scrubbingFromRuler = (p.y < c.rulerHeight) && (c.pixelsPerMS > 0)
            if c.scrubbingFromRuler {
                let ms = max(0, min(c.durationMS,
                                     Int((p.x + c.scrollOffsetX) / c.pixelsPerMS)))
                c.onSeek(ms)
            } else {
                c.panStartScrollX = c.scrollOffsetX
            }
            c.onUserInteraction?()
        case .changed:
            let p = g.location(in: self)
            if c.scrubbingFromRuler, c.pixelsPerMS > 0 {
                let ms = max(0, min(c.durationMS,
                                     Int((p.x + c.scrollOffsetX) / c.pixelsPerMS)))
                c.onSeek(ms)
            } else {
                let t = g.translation(in: self)
                c.onUpdateScrollX(max(0, c.panStartScrollX - t.x))
            }
            c.onUserInteraction?()
        case .ended, .cancelled, .failed:
            c.scrubbingFromRuler = false
        default: break
        }
    }

    @objc func onPinch(_ g: UIPinchGestureRecognizer) {
        guard let c = coordinator else { return }
        switch g.state {
        case .began:
            pinchAnchorX = g.location(in: self).x + c.scrollOffsetX
            pinchLastScale = 1
            c.onUserInteraction?()
        case .changed:
            let delta = g.scale / pinchLastScale
            pinchLastScale = g.scale
            c.onPinchZoom(delta, pinchAnchorX)
            c.onUserInteraction?()
        default: break
        }
    }
    private var pinchAnchorX: CGFloat = 0
    private var pinchLastScale: CGFloat = 1
}
