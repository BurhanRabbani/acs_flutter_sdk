package com.burhanrabbani.acs_flutter_sdk

import android.media.AudioDeviceInfo

/**
 * Pure decision logic for in-call audio output routing, extracted from
 * [AudioRouteController] so it can be unit-tested without an `AudioManager`.
 *
 * Rule: if ANY connected output device is an external device the user explicitly
 * connected (Bluetooth / wired / USB / hearing aid), route to that device
 * ([RouteTarget.EXTERNAL]); otherwise force the built-in loudspeaker
 * ([RouteTarget.SPEAKER]).
 */
object AudioRoutePolicy {

    /** Where in-call audio should go. */
    enum class RouteTarget { EXTERNAL, SPEAKER }

    /**
     * `AudioDeviceInfo.TYPE_*` values that represent an external output device.
     * These are compile-time constants (compileSdk includes them), so referencing
     * the newer ones requires no runtime version guard.
     */
    val externalTypes: Set<Int> = setOf(
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE,
        AudioDeviceInfo.TYPE_HEARING_AID,
        AudioDeviceInfo.TYPE_BLE_HEADSET,
    )

    /** True if [type] is an external output device. */
    fun isExternal(type: Int): Boolean = externalTypes.contains(type)

    /**
     * Decides the route from the set of currently-connected output device types:
     * [RouteTarget.EXTERNAL] when any external device is present, else
     * [RouteTarget.SPEAKER] (the built-in loudspeaker).
     */
    fun decide(connectedOutputTypes: Set<Int>): RouteTarget {
        return if (connectedOutputTypes.any { isExternal(it) }) {
            RouteTarget.EXTERNAL
        } else {
            RouteTarget.SPEAKER
        }
    }

    // ---- Explicit (app-selected) routing -------------------------------------
    // The values mirror the Dart `AudioOutput` enum names exactly so the method
    // channel can pass them as plain strings.

    /** An explicitly selectable in-call audio output. */
    enum class AudioTarget { AUTO, SPEAKER, EARPIECE, BLUETOOTH, WIRED }

    /** `AudioDeviceInfo.TYPE_*` values treated as a Bluetooth output. */
    val bluetoothTypes: Set<Int> = setOf(
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLE_HEADSET,
        AudioDeviceInfo.TYPE_HEARING_AID,
    )

    /** `AudioDeviceInfo.TYPE_*` values treated as a wired output. */
    val wiredTypes: Set<Int> = setOf(
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE,
    )

    /** Parses a [AudioTarget] from a Dart enum name; unknown/null → [AudioTarget.AUTO]. */
    fun targetFromName(name: String?): AudioTarget = when (name) {
        "speaker" -> AudioTarget.SPEAKER
        "earpiece" -> AudioTarget.EARPIECE
        "bluetooth" -> AudioTarget.BLUETOOTH
        "wiredHeadset" -> AudioTarget.WIRED
        else -> AudioTarget.AUTO
    }

    /** The Dart enum name for [target] (inverse of [targetFromName]). */
    fun targetName(target: AudioTarget): String = when (target) {
        AudioTarget.AUTO -> "auto"
        AudioTarget.SPEAKER -> "speaker"
        AudioTarget.EARPIECE -> "earpiece"
        AudioTarget.BLUETOOTH -> "bluetooth"
        AudioTarget.WIRED -> "wiredHeadset"
    }

    /**
     * Targets selectable for the given connected output device types. Always
     * offers [AudioTarget.AUTO] and [AudioTarget.SPEAKER]; adds EARPIECE/BLUETOOTH/
     * WIRED only when the matching device is present.
     */
    fun availableTargets(connectedOutputTypes: Set<Int>): List<AudioTarget> {
        val targets = mutableListOf(AudioTarget.AUTO, AudioTarget.SPEAKER)
        if (connectedOutputTypes.contains(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE)) {
            targets.add(AudioTarget.EARPIECE)
        }
        if (connectedOutputTypes.any { it in bluetoothTypes }) {
            targets.add(AudioTarget.BLUETOOTH)
        }
        if (connectedOutputTypes.any { it in wiredTypes }) {
            targets.add(AudioTarget.WIRED)
        }
        return targets
    }

    /**
     * The concrete `AudioDeviceInfo.TYPE_*` to select for [target] given the
     * connected output types, or `null` when the target is [AudioTarget.AUTO] or
     * the requested external device is not currently present (caller should then
     * fall back to automatic routing via [decide]).
     */
    fun deviceTypeForTarget(target: AudioTarget, connectedOutputTypes: Set<Int>): Int? =
        when (target) {
            AudioTarget.AUTO -> null
            AudioTarget.SPEAKER -> AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
            AudioTarget.EARPIECE -> AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
            AudioTarget.BLUETOOTH -> connectedOutputTypes.firstOrNull { it in bluetoothTypes }
            AudioTarget.WIRED -> connectedOutputTypes.firstOrNull { it in wiredTypes }
        }
}
