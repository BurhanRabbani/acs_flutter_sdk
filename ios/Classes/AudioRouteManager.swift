import AVFoundation
import Foundation

/// Debug logging helper — only prints in DEBUG builds.
@inline(__always)
private func audioRouteDebugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    NSLog("%@", message())
    #endif
}

/// Drives the call's audio OUTPUT route on iOS.
///
/// Why this exists: the ACS calling SDK activates its own `AVAudioSession`
/// configuration when a call connects, which defaults incoming audio to the
/// built-in RECEIVER (the quiet earpiece). This manager re-asserts the desired
/// policy for the duration of a call:
///
///   * No external device connected → route to the built-in LOUDSPEAKER.
///   * An external device IS connected (Bluetooth / wired headset / USB / CarPlay
///     / AirPlay) → use that device, never force the speaker.
///
/// It also re-evaluates on every route change, so plugging in headphones switches
/// to them and unplugging reverts to the loudspeaker mid-call.
///
/// Lifecycle: [activate] on call-connected, [deactivate] on call-disconnected.
/// [deactivate] restores the app's launch-time session config so the separate
/// LiveKit/avatar audio path (which prefers `.videoChat`) is unaffected after a
/// call. All work runs on the main thread.
final class AudioRouteManager {

    /// Whether routing is currently being managed (a call is active). Guards against
    /// duplicate activate/deactivate and ignores route-change events outside a call.
    private var isActive = false

    /// The app configures this category/mode at launch for the LiveKit/avatar path;
    /// [deactivate] restores it so that path keeps hardware echo cancellation.
    private static let restoreMode: AVAudioSession.Mode = .videoChat
    private static let restoreOptions: AVAudioSession.CategoryOptions = [
        .allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker,
    ]

    /// Category options applied DURING a call: loudspeaker by default, but any
    /// connected external device (Bluetooth / wired / AirPlay) takes over.
    private static let callOptions: AVAudioSession.CategoryOptions = [
        .defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay,
    ]

    /// Output port types that represent an EXTERNAL device the user explicitly
    /// connected. When the current route already uses one of these we must NOT force
    /// the speaker — the external device wins.
    static let externalOutputs: Set<AVAudioSession.Port> = [
        .bluetoothA2DP, .bluetoothHFP, .bluetoothLE,
        .headphones, .headsetMic,
        .usbAudio, .carAudio, .airPlay, .lineOut, .HDMI,
    ]

    /// Pure routing decision: returns true when the call should be forced to the
    /// built-in LOUDSPEAKER — i.e. NONE of the current [outputPortTypes] is an
    /// external device. When any external output is present this returns false so
    /// the external device is used instead. Extracted so the policy is unit-testable
    /// without a live `AVAudioSession`.
    static func shouldRouteToSpeaker(outputPortTypes: [AVAudioSession.Port]) -> Bool {
        return !outputPortTypes.contains { externalOutputs.contains($0) }
    }

    /// Begins managing the call audio route: configures the session for a call,
    /// applies the preferred route, and starts observing route changes.
    func activate() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isActive else {
            // Already active (e.g. a connected→reconnecting→connected bounce). Just
            // re-apply in case the SDK reset the route on the transition.
            applyPreferredRoute()
            return
        }
        isActive = true

        let session = AVAudioSession.sharedInstance()
        do {
            // `.voiceChat` is the standard mode for a 1:1/group call; `.defaultToSpeaker`
            // makes the loudspeaker (not the receiver) the default when no external
            // route is present, while `.allowBluetooth*` lets headsets take over.
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: Self.callOptions)
        } catch {
            NSLog("[ACS][AudioRoute] setCategory(call) failed: %@", error.localizedDescription)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )

        applyPreferredRoute()
    }

    /// Stops managing the route, removes the observer, and restores the app's
    /// launch-time session config so the LiveKit/avatar path is unaffected.
    func deactivate() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard isActive else { return }
        isActive = false

        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )

        let session = AVAudioSession.sharedInstance()
        do {
            // Clear any speaker override and restore the launch config.
            try session.overrideOutputAudioPort(.none)
            try session.setCategory(.playAndRecord, mode: Self.restoreMode, options: Self.restoreOptions)
        } catch {
            NSLog("[ACS][AudioRoute] restore on deactivate failed: %@", error.localizedDescription)
        }
    }

    /// Re-evaluates and applies the output route: speaker when nothing external is
    /// connected, otherwise the external device. Safe to call repeatedly.
    private func applyPreferredRoute() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard isActive else { return }
        let session = AVAudioSession.sharedInstance()
        let useSpeaker = Self.shouldRouteToSpeaker(
            outputPortTypes: session.currentRoute.outputs.map { $0.portType }
        )
        do {
            // `.speaker` forces the loudspeaker over the receiver when only built-ins
            // are present; `.none` lets the system honour the connected external device.
            try session.overrideOutputAudioPort(useSpeaker ? .speaker : .none)
            audioRouteDebugLog("[ACS][AudioRoute] applied route speaker=\(useSpeaker) outputs=\(session.currentRoute.outputs.map { $0.portType.rawValue })")
        } catch {
            NSLog("[ACS][AudioRoute] overrideOutputAudioPort failed: %@", error.localizedDescription)
        }
    }

    /// Route-change handler: a device was connected/disconnected (or the system
    /// re-routed), so re-apply the preferred route. The ACS SDK can also reset the
    /// category on some transitions, so re-assert the call options first.
    @objc private func handleRouteChange(_ notification: Notification) {
        // Notifications can arrive off the main thread; hop to main for session work.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isActive else { return }
            let session = AVAudioSession.sharedInstance()
            // Re-assert the call category options in case the SDK clobbered them.
            if !session.categoryOptions.contains(.defaultToSpeaker) {
                try? session.setCategory(.playAndRecord, mode: .voiceChat, options: Self.callOptions)
            }
            self.applyPreferredRoute()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
