import AzureCommunicationCalling
import UIKit

/// Debug logging helper - only prints in DEBUG builds
@inline(__always)
private func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    NSLog("%@", message())
    #endif
}

/// Custom container view that properly propagates layout changes to its subviews
/// This is critical for Flutter platform view integration where frame updates come from Flutter
/// iOS-26 freeze fix (OPTION B): ACSVideoStreamRendererView.scaleVideoCALayer does not
/// converge when the renderer lays out at small/fractional bounds — it re-arms layout
/// forever and pins the main thread. So we NEVER resize the renderer: `embedRenderer(_:)`
/// pins it inside a fixed-size `scaler` (a known-converging full-screen size), and
/// `layoutSubviews` only scales/repositions that scaler with a CGAffineTransform to fit the
/// actual tile. A transform/center change does not trigger layoutSubviews, so the loop can
/// never form, and the video stays live at every tile size (grid tile or PiP self-tile).
/// `final` + internal so the per-participant tile path (AcsVideoViewFactory) reuses it.
final class VideoContainerView: UIView {
    private let containerName: String

    // [ACSDIAG] layout-loop instrumentation (logarithmic schedule; nearly silent in normal
    // use, but a runaway view spams at 100/1000/... — kept while we validate the fix).
    private var layoutPassCount: Int = 0
    private var redundantPassRun: Int = 0
    private var lastLaidOutBounds: CGRect = .zero

    init(name: String) {
        self.containerName = name
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        self.containerName = "unknown"
        super.init(coder: coder)
    }

    /// Embeds an Azure renderer view at a FIXED size; `layoutSubviews` then scales it to fit
    /// this container. Removes any previously embedded renderer first. Main-thread only.
    func embedRenderer(_ view: UIView) {
        dispatchPrecondition(condition: .onQueue(.main))
        subviews.forEach { $0.removeFromSuperview() }

        let fixed = VideoContainerView.fixedRenderSize
        // `scaler` is a plain UIView WE own. Its bounds are fixed and never change, so the
        // renderer inside it never re-lays-out. translatesAutoresizingMaskIntoConstraints ==
        // true marks it as the manually-managed child layoutSubviews scales (no autoresizing).
        let scaler = UIView(frame: CGRect(origin: .zero, size: fixed))
        scaler.clipsToBounds = true
        scaler.backgroundColor = .clear
        scaler.translatesAutoresizingMaskIntoConstraints = true
        scaler.autoresizingMask = []

        // Renderer fills the scaler with a FIXED frame and NO autoresizing → its bounds never
        // change → its layoutSubviews/scaleVideoCALayer runs once at a converging size.
        view.frame = scaler.bounds
        view.autoresizingMask = []
        view.clipsToBounds = true
        scaler.addSubview(view)

        addSubview(scaler)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // [ACSDIAG] Count passes and detect the redundant-relayout loop signature.
        layoutPassCount += 1
        let sameBounds = bounds.equalTo(lastLaidOutBounds)
        if sameBounds {
            redundantPassRun += 1
        } else {
            redundantPassRun = 0
            lastLaidOutBounds = bounds
        }
        // Emit only at 1, 10, 100, 1000... total passes, OR whenever a run of
        // same-bounds passes crosses a power of ten (the actual loop alarm). Integer
        // format only — no %f/floats and no per-pass logging, so this stays cheap.
        #if DEBUG
        // Debug-only layout-loop tripwire: if a future change reintroduces the iOS-26
        // renderer loop, this logs the runaway. Zero cost in release.
        if acsDiagIsPowerOfTen(layoutPassCount) || acsDiagIsPowerOfTen(redundantPassRun) {
            NSLog("[ACSDIAG] VideoContainerView(%@).layoutSubviews pass=%ld redundantRun=%ld bounds=%dx%d",
                  containerName, layoutPassCount, redundantPassRun,
                  Int(bounds.width), Int(bounds.height))
        }
        #endif

        // OPTION B — scale the fixed-size renderer to fit; never resize it. embedRenderer()
        // pinned the renderer inside a fixed-size `scaler`; here we ONLY apply a transform +
        // center so the renderer's bounds never change and its scaleVideoCALayer cannot loop.
        // (Verified the loop exists in every Azure build — 2.15.0 / 2.16.0-beta.1 /
        // 2.18.0-beta.1 / 2.18.2 — so the cure must be to never hand it a small/changing size.)
        // Aspect-FILL the tile; the container clips the overflow.
        let fixedSize = VideoContainerView.fixedRenderSize
        guard bounds.width > 0, bounds.height > 0,
              fixedSize.width > 0, fixedSize.height > 0 else { return }
        let scale = max(bounds.width / fixedSize.width, bounds.height / fixedSize.height)
        for scaler in subviews where scaler.translatesAutoresizingMaskIntoConstraints {
            scaler.transform = CGAffineTransform(scaleX: scale, y: scale)
            scaler.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    /// A stable, known-converging size to pin the local renderer's bounds to. Full-screen
    /// sizes lay out cleanly (Azure's scaleVideoCALayer only fails to converge at small /
    /// fractional sizes), so the device screen size is used; the renderer is then scaled to
    /// fit each actual tile via a layer transform. Falls back to a portrait constant if the
    /// screen bounds are unavailable.
    static var fixedRenderSize: CGSize {
        let s = UIScreen.main.bounds.size
        return (s.width >= 1 && s.height >= 1) ? s : CGSize(width: 405, height: 877)
    }

    // NOTE: no `frame`/`bounds` didSet overrides. UIKit already invokes
    // `layoutSubviews` when a view's bounds change, so a custom observer calling
    // `setNeedsLayout()` was redundant — and it re-armed layout on every size
    // change, which is what closed the infinite-layout loop above.
}

/// [ACSDIAG] True only for 1, 10, 100, 1000, ... Used to log layout-pass / invocation
/// counts on a logarithmic schedule so a runaway loop is visible while normal operation
/// (a handful of passes) stays nearly silent. File-private so both VideoContainerView
/// and VideoViewManager can share it.
private func acsDiagIsPowerOfTen(_ n: Int) -> Bool {
    guard n >= 1 else { return false }
    var v = n
    while v % 10 == 0 { v /= 10 }
    return v == 1
}

/// Manages local and remote video views for ACS calls on iOS.
/// All public methods must be called from the main thread.
class VideoViewManager {
    // Concrete VideoContainerView type so the OPTION B embedRenderer(_:) is callable.
    // (Still a UIView — callers that expect UIView are unaffected.)
    let localContainer = VideoContainerView(name: "local")
    let remoteContainer = VideoContainerView(name: "remote")

    private var previewRenderer: VideoStreamRenderer?

    init() {
        // Container appearance is set in VideoContainerView.init; nothing to do here.
    }

    func showLocalPreview(stream: LocalVideoStream) throws {
        dispatchPrecondition(condition: .onQueue(.main))

        debugLog("[ACS][VideoViewManager] showLocalPreview called")

        if previewRenderer != nil {
            debugLog("[ACS][VideoViewManager] showLocalPreview - previewRenderer already exists, returning")
            return
        }

        let renderer = try VideoStreamRenderer(localVideoStream: stream)
        // Let the SDK own video scaling via CreateViewOptions(scalingMode:). Do NOT
        // also set `view.contentMode` — the SDK scales by transforming its own CALayer
        // inside `scaleVideoCALayer` (driven from its `layoutSubviews`), and imposing a
        // UIView contentMode on top makes UIKit and the SDK fight for the geometry: each
        // re-dirties the layer the other just settled, so a single CoreAnimation commit
        // never converges and `layoutSubviews` re-fires without bound (measured: ~1e6
        // same-bounds passes per toggle, main thread pinned, memory ballooning). The
        // remote path already embeds this way (see RemoteVideoRenderManager); the local
        // preview must match it.
        // scalingMode .crop: the SDK fills the (fixed-size) renderer bounds with video. The
        // tile-fit happens in VideoContainerView via a layer transform, not by resizing this
        // view — see embedRenderer/layoutSubviews (OPTION B, the iOS-26 freeze fix).
        let options = CreateViewOptions(scalingMode: .crop)
        let view = try renderer.createView(withOptions: options)

        // Unified OPTION B embedding for ALL renderer views (local, single-remote, and the
        // per-participant grid tiles) — the container pins the renderer at a fixed size and
        // scales it to fit, so the renderer never lays out at a small/changing size.
        localContainer.embedRenderer(view)

        previewRenderer = renderer
        debugLog("[ACS][VideoViewManager] showLocalPreview - view embedded")
    }

    func clearLocalPreview() {
        dispatchPrecondition(condition: .onQueue(.main))

        // embedRenderer() owns the local container's subtree (scaler + renderer view).
        localContainer.subviews.forEach { $0.removeFromSuperview() }
        previewRenderer?.dispose()
        previewRenderer = nil
    }

    func addRemote(view: UIView, streamId: Int) {
        dispatchPrecondition(condition: .onQueue(.main))

        // [ACSFREEZE] diagnostic: shared single-feed attach (single-remote / takeover path).
        NSLog("[ACSFREEZE] iOS VideoViewManager.addRemote ENTER streamId=%d main=%@",
              streamId, Thread.isMainThread ? "Y" : "N")
        defer { NSLog("[ACSFREEZE] iOS VideoViewManager.addRemote EXIT streamId=%d", streamId) }
        debugLog("[ACS][VideoViewManager] addRemote called for streamId=\(streamId)")

        view.tag = streamId
        // Unified OPTION B embedding: fixed-size renderer scaled to fit by the container
        // (no edge constraints, the renderer is never resized) — see embedRenderer. This is
        // the single-remote path; embedRenderer removes any previously embedded stream first.
        remoteContainer.embedRenderer(view)
        debugLog("[ACS][VideoViewManager] addRemote - view embedded")
    }

    func removeRemote(streamId: Int) {
        dispatchPrecondition(condition: .onQueue(.main))

        // [ACSFREEZE] diagnostic: shared single-feed detach (DROP / takeover path).
        NSLog("[ACSFREEZE] iOS VideoViewManager.removeRemote ENTER streamId=%d main=%@",
              streamId, Thread.isMainThread ? "Y" : "N")
        defer { NSLog("[ACSFREEZE] iOS VideoViewManager.removeRemote EXIT streamId=%d", streamId) }
        // Single-remote path shows one stream; clear the whole subtree (scaler + renderer).
        remoteContainer.subviews.forEach { $0.removeFromSuperview() }
    }

    func removeAllRemote() {
        dispatchPrecondition(condition: .onQueue(.main))

        for subview in remoteContainer.subviews {
            subview.removeFromSuperview()
        }
    }

    // [ACSDIAG] Counts how many times forceLayoutUpdate is invoked. If this climbs
    // fast during a single mic/camera toggle, the Dart/method-channel side is the
    // loop driver (re-arming setNeedsLayout on the renderer view every state emit);
    // if it stays low while layout passes explode, the loop is inside UIKit/Azure.
    private var forceLayoutUpdateCount: Int = 0

    /// Forces a layout update on all video views.
    func forceLayoutUpdate() {
        dispatchPrecondition(condition: .onQueue(.main))

        #if DEBUG
        // [ACSDIAG] Debug-only: log on a logarithmic schedule to expose a runaway
        // invocation rate without per-call logging overhead. Zero cost in release.
        forceLayoutUpdateCount += 1
        if acsDiagIsPowerOfTen(forceLayoutUpdateCount) {
            NSLog("[ACSDIAG] VideoViewManager.forceLayoutUpdate invoked count=%ld remoteSubviews=%ld",
                  forceLayoutUpdateCount, remoteContainer.subviews.count)
        }
        #endif

        debugLog("[ACS][VideoViewManager] forceLayoutUpdate called")
        debugLog("[ACS][VideoViewManager] forceLayoutUpdate - remoteContainer.frame=\(remoteContainer.frame)")
        debugLog("[ACS][VideoViewManager] forceLayoutUpdate - subviews.count=\(remoteContainer.subviews.count)")

        // Request layout/redisplay only. NO synchronous `layoutIfNeeded()` anywhere here:
        // these containers are Flutter-mounted platform views, and a forced layout pass on
        // the platform thread can deadlock against the raster thread during a tile mount
        // (the 2nd-participant-join hard-freeze). Marked views resolve on the next pass.
        remoteContainer.setNeedsLayout()
        localContainer.setNeedsLayout()

        for (index, subview) in remoteContainer.subviews.enumerated() {
            debugLog("[ACS][VideoViewManager] forceLayoutUpdate - subview[\(index)] frame=\(subview.frame), isHidden=\(subview.isHidden)")
            subview.setNeedsLayout()
            subview.setNeedsDisplay()
            subview.isHidden = false
            subview.alpha = 1.0

            if let sublayers = subview.layer.sublayers {
                for sublayer in sublayers {
                    sublayer.setNeedsLayout()
                    sublayer.setNeedsDisplay()
                }
            }
        }

        for subview in localContainer.subviews {
            subview.setNeedsLayout()
            subview.setNeedsDisplay()
        }

        debugLog("[ACS][VideoViewManager] forceLayoutUpdate completed")
    }
}
