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
/// route for the duration of a call.
///
/// Two modes:
///   * AUTO (default): no external device → built-in LOUDSPEAKER; an external
///     device connected (Bluetooth / wired / USB / CarPlay / AirPlay) → use it.
///   * MANUAL: the app picked an explicit target via [setRoute]; honoured until the
///     app changes it or selects `auto`.
///
/// It re-evaluates on every route change. Lifecycle: [activate] on call-connected,
/// [deactivate] on call-disconnected (restores the launch-time session config so
/// the separate LiveKit/avatar path is unaffected). All work runs on the main thread.
final class AudioRouteManager {

    /// Whether routing is currently being managed (a call is active).
    private var isActive = false

    /// App-selected output (Dart `AudioOutput` name); `auto` means automatic policy.
    private var manualTarget = "auto"

    /// The app configures this category/mode at launch for the LiveKit/avatar path;
    /// [deactivate] restores it so that path keeps hardware echo cancellation.
    private static let restoreMode: AVAudioSession.Mode = .videoChat
    private static let restoreOptions: AVAudioSession.CategoryOptions = [
        .allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker,
    ]

    /// Base category options applied DURING a call (Bluetooth / AirPlay allowed).
    /// `.defaultToSpeaker` is added on top except when the manual target is the
    /// earpiece, where it must be omitted so audio routes to the receiver.
    private static let baseCallOptions: AVAudioSession.CategoryOptions = [
        .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay,
    ]

    /// Output port types that represent an EXTERNAL device the user explicitly
    /// connected. When the current route already uses one of these we must NOT force
    /// the speaker — the external device wins.
    static let externalOutputs: Set<AVAudioSession.Port> = [
        .bluetoothA2DP, .bluetoothHFP, .bluetoothLE,
        .headphones, .headsetMic,
        .usbAudio, .carAudio, .airPlay, .lineOut, .HDMI,
    ]

    /// Bluetooth output port types.
    private static let bluetoothOutputs: Set<AVAudioSession.Port> = [
        .bluetoothA2DP, .bluetoothHFP, .bluetoothLE,
    ]

    /// Wired output port types.
    private static let wiredOutputs: Set<AVAudioSession.Port> = [
        .headphones, .headsetMic, .usbAudio,
    ]

    /// Pure routing decision: returns true when the call should be forced to the
    /// built-in LOUDSPEAKER — i.e. NONE of the current [outputPortTypes] is an
    /// external device. Extracted so the policy is unit-testable without a live
    /// `AVAudioSession`.
    static func shouldRouteToSpeaker(outputPortTypes: [AVAudioSession.Port]) -> Bool {
        return !outputPortTypes.contains { externalOutputs.contains($0) }
    }

    /// Pure helper: the selectable target names for the given output port types.
    /// Always offers `auto`/`speaker`/`earpiece`; adds `bluetooth`/`wiredHeadset`
    /// when such a device is present. Unit-testable without a live session.
    static func availableTargets(outputPortTypes: [AVAudioSession.Port]) -> [String] {
        var targets = ["auto", "speaker", "earpiece"]
        if outputPortTypes.contains(where: { bluetoothOutputs.contains($0) }) {
            targets.append("bluetooth")
        }
        if outputPortTypes.contains(where: { wiredOutputs.contains($0) }) {
            targets.append("wiredHeadset")
        }
        return targets
    }

    /// Pure helper: the external target name (`bluetooth`/`wiredHeadset`) currently
    /// in use, or `nil` when only built-ins are active.
    static func externalTargetName(outputPortTypes: [AVAudioSession.Port]) -> String? {
        if outputPortTypes.contains(where: { bluetoothOutputs.contains($0) }) { return "bluetooth" }
        if outputPortTypes.contains(where: { wiredOutputs.contains($0) }) { return "wiredHeadset" }
        return nil
    }

    /// Selects an explicit output by its Dart target name (`auto` / `speaker` /
    /// `earpiece` / `bluetooth` / `wiredHeadset`); `auto` resumes automatic routing.
    func setRoute(_ target: String?) {
        dispatchPrecondition(condition: .onQueue(.main))
        manualTarget = Self.normalize(target)
        applyPreferredRoute()
    }

    /// The Dart target name of the output currently in effect.
    func currentRoute() -> String {
        if manualTarget != "auto" { return manualTarget }
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.portType }
        return Self.externalTargetName(outputPortTypes: outputs) ?? "speaker"
    }

    /// The Dart target names selectable right now.
    func availableRoutes() -> [String] {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.portType }
        return Self.availableTargets(outputPortTypes: outputs)
    }

    /// The selectable outputs with their OS-reported names, as dictionaries of
    /// `type` (Dart target name) and `name` (`NSNull` when unknown).
    ///
    /// Invariant: the `type` values and their order equal [availableRoutes] for the
    /// same device state, because both come from [availableTargets]. `auto` has no
    /// name. Names are `AVAudioSessionPortDescription.portName` from the current
    /// route's outputs; `earpiece` is only named while the receiver is the active
    /// output (iOS does not expose an inactive built-in port's name).
    func availableRouteDevices() -> [[String: Any]] {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let targets = Self.availableTargets(outputPortTypes: outputs.map { $0.portType })
        return targets.map { target in
            let name = Self.portName(forTarget: target, outputs: outputs)
            return ["type": target, "name": name.map { $0 as Any } ?? NSNull()]
        }
    }

    /// Pure helper: the name of the first of [outputs] that belongs to [target],
    /// or `nil` for `auto` / when no matching output is active or the name is blank.
    static func portName(
        forTarget target: String,
        outputs: [AVAudioSessionPortDescription]
    ) -> String? {
        let match: (AVAudioSessionPortDescription) -> Bool
        switch target {
        case "speaker": match = { $0.portType == .builtInSpeaker }
        case "earpiece": match = { $0.portType == .builtInReceiver }
        case "bluetooth": match = { bluetoothOutputs.contains($0.portType) }
        case "wiredHeadset": match = { wiredOutputs.contains($0.portType) }
        default: return nil
        }
        guard let name = outputs.first(where: match)?.portName, !name.isEmpty else { return nil }
        return name
    }

    /// Begins managing the call audio route: configures the session for a call,
    /// applies the preferred route, and starts observing route changes.
    func activate() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isActive else {
            applyPreferredRoute()
            return
        }
        isActive = true
        manualTarget = "auto"

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )

        applyPreferredRoute()
    }

    /// Stops managing the route, removes the observer, and restores the app's
    /// launch-time session config so the LiveKit/avatar path is unaffected.
    func deactivate() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard isActive else { return }
        isActive = false
        manualTarget = "auto"

        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )

        let session = AVAudioSession.sharedInstance()
        do {
            try session.overrideOutputAudioPort(.none)
            try session.setCategory(.playAndRecord, mode: Self.restoreMode, options: Self.restoreOptions)
        } catch {
            NSLog("[ACS][AudioRoute] restore on deactivate failed: %@", error.localizedDescription)
        }
    }

    /// Category options for the current target: the base call options, plus
    /// `.defaultToSpeaker` unless the manual target is the earpiece (where the
    /// receiver must be the default).
    private func categoryOptionsForTarget() -> AVAudioSession.CategoryOptions {
        if manualTarget == "earpiece" { return Self.baseCallOptions }
        return Self.baseCallOptions.union(.defaultToSpeaker)
    }

    /// Re-asserts the call category then applies the output override for the current
    /// target: `speaker`→`.speaker`; `earpiece`/external→`.none`; `auto`→speaker when
    /// nothing external is connected, else `.none`.
    private func applyPreferredRoute() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard isActive else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: categoryOptionsForTarget())
        } catch {
            NSLog("[ACS][AudioRoute] setCategory(call) failed: %@", error.localizedDescription)
        }

        let override: AVAudioSession.PortOverride
        switch manualTarget {
        case "speaker":
            override = .speaker
        case "earpiece", "bluetooth", "wiredHeadset":
            // `.none` honours the receiver (earpiece) or the connected external device.
            override = .none
        default:
            let useSpeaker = Self.shouldRouteToSpeaker(
                outputPortTypes: session.currentRoute.outputs.map { $0.portType }
            )
            override = useSpeaker ? .speaker : .none
        }
        do {
            try session.overrideOutputAudioPort(override)
            audioRouteDebugLog("[ACS][AudioRoute] applied target=\(manualTarget) override=\(override.rawValue)")
        } catch {
            NSLog("[ACS][AudioRoute] overrideOutputAudioPort failed: %@", error.localizedDescription)
        }
    }

    /// Route-change handler: re-apply the preferred route on connect/disconnect.
    @objc private func handleRouteChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isActive else { return }
            self.applyPreferredRoute()
        }
    }

    /// Normalizes an inbound target name to a known value, defaulting to `auto`.
    private static func normalize(_ target: String?) -> String {
        switch target {
        case "speaker", "earpiece", "bluetooth", "wiredHeadset": return target!
        default: return "auto"
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
